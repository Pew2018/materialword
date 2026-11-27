import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/backup_manager.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/import_service.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/word_intake_service.dart';
import 'package:materialword/services/wordbook_export.dart';

import 'helpers/test_env.dart';

/// Phase 5H-02: the full data loop, end to end, on real services.
///
/// new book → add word → batch import → edit → study/practice → export →
/// import into a second database → full backup → delete some data → restore →
/// sync to another device → verify → sync again and check convergence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('E2E 数据闭环：新增、导入、学习、导出、备份、恢复、同步', () async {
    final TestEnv phone = await TestEnv.create(now: DateTime(2026, 11, 24, 9));
    final TestEnv tablet = await TestEnv.create(
      now: DateTime(2026, 11, 24, 10),
    );
    final TestEnv other = await TestEnv.create(now: DateTime(2026, 11, 24, 11));
    addTearDown(phone.dispose);
    addTearDown(tablet.dispose);
    addTearDown(other.dispose);

    // 1. New book.
    final WordBook book = await phone.books.create(
      name: '闭环词书',
      description: '端到端验证',
      now: phone.clock.now(),
    );

    // 2. Manual add.
    final WordIntakeResult manual = await phone.intake.add(
      const WordIntakeRequest(
        text: 'abandon',
        user: WordContent(
          phonetic: 'əˈbændən',
          partOfSpeech: 'v.',
          translation: '放弃',
          example: 'They abandoned the plan.\nHe abandoned hope.',
          phrase: 'abandon oneself to',
          note: '手动笔记',
        ),
        examTags: 'cet6',
      ),
      bookId: book.id,
      now: phone.clock.now(),
    );
    expect(manual.kind, IntakeKind.created);

    // 3. Batch import.
    final ImportService importer = phone.importService();
    final ImportOutcome imported = await importer.commit(
      preview: importer.parseContent(
        'word,translation,examTags\nbenefit,好处,cet4\ncurious,好奇的,cet6\n',
        format: 'csv',
        name: 'batch.csv',
      ),
      bookId: book.id,
      now: phone.clock.now(),
    );
    expect(imported.created, 2);
    expect(await phone.books.wordCount(book.id), 3);

    // 4. Edit a meaning and a note.
    final Word benefit = (await phone.words.byNormalized('benefit'))!;
    await phone.intake.add(
      const WordIntakeRequest(
        text: 'benefit',
        user: WordContent(translation: '好处；受益', note: '编辑后的笔记'),
      ),
      now: phone.clock.now(),
    );

    // 5. Study and practice.
    phone.clock.advance(const Duration(minutes: 10));
    await phone.study.recordAnswer(
      wordId: benefit.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'e2e-study-1',
      deviceId: 'phone',
      now: phone.clock.now(),
    );
    phone.clock.advance(const Duration(minutes: 1));
    await phone.study.recordAnswer(
      wordId: benefit.id,
      result: AnswerResult.hazy,
      type: ReviewType.review,
      eventId: 'e2e-practice-1',
      deviceId: 'phone',
      mode: 'practice-choice',
      now: phone.clock.now(),
    );
    final LearningState studied = (await phone.words.stateFor(benefit.id))!;
    expect(studied.stage, greaterThan(0));

    // 6. Export the book, then import it into an independent database.
    final List<Word> bookWords = await phone.books.wordsInBook(book.id);
    final String body = WordBookExporter.encodeBook(
      WordBookExport(book: book, words: bookWords),
      WordBookExportFormat.json,
      exportedAt: phone.clock.now(),
    );
    final ImportService otherImporter = tablet.importService();
    final ImportOutcome roundTrip = await otherImporter.commit(
      preview: otherImporter.parseContent(
        body,
        format: 'json',
        name: 'book.json',
      ),
      now: tablet.clock.now(),
    );
    expect(roundTrip.created, 3);
    final Word copied = (await tablet.words.byNormalized('abandon'))!;
    expect(copied.translation, '放弃');
    expect(copied.note, '手动笔记');
    expect(copied.example, contains('\n'));
    expect(copied.phrase, 'abandon oneself to');
    expect(copied.examTags, 'cet6');
    expect(
      await tablet.words.eventsForWord(copied.id),
      isEmpty,
      reason: '词书导出不含学习历史',
    );

    // A fresh database cannot have the phone's learning progress: a book export
    // is content, not a backup. The full backup below is what carries it.

    // 7. Full backup.
    final File backup = await phone.backups.createBackup();
    final BackupInfo info = await phone.backups.inspect(backup);
    expect(info.valid, isTrue);
    expect(info.words, 3);
    expect(info.events, 2);

    // 8. Delete part of the data (book link + one word), then restore.
    await phone.books.removeWord(book.id, copied.id, now: phone.clock.now());
    final Word curious = (await phone.words.byNormalized('curious'))!;
    await phone.words.softDelete(curious.id, now: phone.clock.now());
    expect(await phone.books.wordCount(book.id), 2);

    phone.clock.advance(const Duration(hours: 1));
    final RestoreOutcome restored = await phone.backups.restoreSnapshot(backup);
    expect(restored.clearedWords, 3);
    expect(await phone.books.wordCount(book.id), 3);
    expect(await phone.words.byNormalized('curious'), isNotNull);
    expect(await phone.settings.syncPaused(), isTrue);

    // Learning history survived the restore (rebuilt from the event log).
    final LearningState afterRestore = (await phone.words.stateFor(
      benefit.id,
    ))!;
    expect(afterRestore.stage, studied.stage);
    expect(afterRestore.hazyCount, studied.hazyCount);

    // 9. Cross-device sync: the restore paused it, so it must be explicit.
    final ScriptedSyncProvider remote = ScriptedSyncProvider();
    await expectLater(
      phone.coordinator.sync(remote, skipConnectionTest: true),
      throwsA(isA<Object>()),
    );
    await phone.settings.setSyncPaused(false);
    final SyncReport first = await phone.coordinator.sync(
      remote,
      skipConnectionTest: true,
      resumeAfterRestore: true,
    );
    expect(first.ok, isTrue);
    final SyncReport pulled = await tablet.coordinator.sync(
      remote,
      skipConnectionTest: true,
    );
    expect(pulled.ok, isTrue);

    // 10. Verify content, history, tombstones, identities and hash.
    final Word remoteBenefit = (await tablet.words.byNormalized('benefit'))!;
    expect(remoteBenefit.translation, '好处；受益');
    expect(await tablet.words.eventsForWord(remoteBenefit.id), hasLength(2));
    expect(
      (await tablet.words.stateFor(remoteBenefit.id))!.correctCount,
      afterRestore.correctCount,
    );
    // The book was created by the import on that device, so it has its own id;
    // match by name, exactly like the merge does.
    final WordBook tabletBook = (await tablet.books.listBooks()).firstWhere(
      (WordBook candidate) => candidate.name == '闭环词书',
    );
    expect(await tablet.books.wordCount(tabletBook.id), 3);
    expect(tabletBook.description, '端到端验证');
    // Identity survives: the tablet's rows keep their own canonical ids (the
    // device that created them) and remember the phone's id as an alias, so a
    // later rename or re-import can never fork the word.
    final Map<String, Object?> phoneDataset = await phone.backup.buildDataset(
      now: phone.clock.now(),
    );
    final Map<String, dynamic> phoneAbandon =
        (phoneDataset['words'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .firstWhere((Map<String, dynamic> row) => row['word'] == 'abandon');
    final Map<String, Object?> tabletDataset = await tablet.backup.buildDataset(
      now: tablet.clock.now(),
    );
    final Map<String, dynamic> tabletAbandon =
        (tabletDataset['words'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .firstWhere((Map<String, dynamic> row) => row['word'] == 'abandon');
    expect(
      (tabletAbandon['aliases'] as List<dynamic>?) ?? const <dynamic>[],
      contains(phoneAbandon['id']),
    );
    // Note: the two hashes converge after a *full* round (see step 11), because
    // the merge keeps the larger updatedAt — a device that just pulled is one
    // upload behind until the other side pulls back.

    // 11. One more full round trip keeps everything stable (idempotent).
    for (final TestEnv device in <TestEnv>[phone, tablet, phone, tablet]) {
      await device.coordinator.sync(remote, skipConnectionTest: true);
    }
    final String hashPhone2 = BackupService.contentHashOf(
      await phone.backup.buildDataset(now: phone.clock.now()),
    );
    expect(
      BackupService.contentHashOf(
        await tablet.backup.buildDataset(now: tablet.clock.now()),
      ),
      hashPhone2,
    );

    // 12. A third device joining late converges to the same hash too.
    await other.coordinator.sync(remote, skipConnectionTest: true);
    expect(
      BackupService.contentHashOf(
        await other.backup.buildDataset(now: other.clock.now()),
      ),
      hashPhone2,
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('E2E 数据库 Schema 为 4，备份与同步协议升级为 6', () async {
    expect(AppDatabase.currentSchemaVersion, 4);
    expect(syncSchemaVersion, 6);
    expect(backupSchemaVersion, 6);
  });
}
