import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/features/word_management/quick_add_page.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/import_service.dart';
import 'package:materialword/services/word_intake_service.dart';

import 'helpers/test_dictionary.dart';
import 'helpers/test_env.dart';

/// Phase 5B acceptance: ADD01–ADD14.
///
/// Every one of these drives the *real* service and the real database; nothing
/// here asserts on a mock that could hide a broken write path.
void main() {
  late TestEnv env;

  setUp(() async {
    env = await TestEnv.create();
  });

  tearDown(() async {
    await env.dispose();
  });

  Future<Word> add(
    String text, {
    String? bookId,
    String? translation,
    String? note,
    String? phonetic,
    String source = 'manual',
    bool allowRevive = true,
    Map<String, String> dictionary = const <String, String>{},
    Map<String, String> content = const <String, String>{},
  }) async {
    final WordIntakeResult result = await env.intake.add(
      WordIntakeRequest(
        text: text,
        user: WordContent(
          translation: translation,
          note: note,
          phonetic: phonetic,
        ),
        content: WordContent(
          translation: content['translation'],
          definition: content['definition'],
          example: content['example'],
        ),
        dictionary: WordContent(
          translation: dictionary['translation'],
          phonetic: dictionary['phonetic'],
          definition: dictionary['definition'],
        ),
        source: source,
        allowRevive: allowRevive,
      ),
      bookId: bookId,
      now: env.clock.now(),
    );
    return result.word;
  }

  test('ADD01 首次新增写入内容、自定义标记与词书关联', () async {
    final WordBook book = await env.books.create(
      name: 'B1',
      now: env.clock.now(),
    );
    final WordIntakeResult result = await env.intake.add(
      const WordIntakeRequest(
        text: 'Apple ',
        user: WordContent(translation: '苹果', phonetic: 'ˈæpl', note: '我的笔记'),
      ),
      bookId: book.id,
      now: env.clock.now(),
    );

    expect(result.kind, IntakeKind.created);
    expect(result.linkAdded, isTrue);
    expect(result.word.word, 'Apple', reason: '保存去掉首尾空格，保留大小写');
    expect(result.word.normalized, 'apple');
    expect(result.word.translation, '苹果');
    expect(result.word.note, '我的笔记');
    expect(result.word.customized, isTrue, reason: '用户手写内容必须标记为自定义');
    expect(await env.books.wordCount(book.id), 1);
  });

  test('ADD02 重复新增不生成重复词条', () async {
    final WordBook book = await env.books.create(
      name: 'B1',
      now: env.clock.now(),
    );
    final Word first = await add('apple', bookId: book.id, translation: '苹果');
    final WordIntakeResult second = await env.intake.add(
      const WordIntakeRequest(text: 'APPLE'),
      bookId: book.id,
      now: env.clock.now(),
    );

    expect(second.kind, IntakeKind.unchanged);
    expect(second.word.id, first.id);
    expect(second.linkAdded, isFalse);
    expect(second.alreadyLinked, isTrue);
    expect(await env.words.countWords(), 1);
    expect(await env.books.wordCount(book.id), 1);
  });

  test('ADD03 新增至另一个词书只增加关联', () async {
    final WordBook a = await env.books.create(name: 'A', now: env.clock.now());
    final WordBook b = await env.books.create(name: 'B', now: env.clock.now());
    final Word word = await add('apple', bookId: a.id, translation: '苹果');
    final WordIntakeResult linked = await env.intake.add(
      const WordIntakeRequest(text: 'apple'),
      bookId: b.id,
      now: env.clock.now(),
    );

    expect(linked.word.id, word.id);
    expect(linked.kind, IntakeKind.unchanged);
    expect(linked.linkAdded, isTrue);
    expect(await env.books.wordCount(a.id), 1);
    expect(await env.books.wordCount(b.id), 1);
    expect((await env.words.bookIdsForWord(word.id)), <String>{a.id, b.id});
  });

  test('ADD04 删除后手动重新新增恢复同一身份', () async {
    final WordBook book = await env.books.create(
      name: 'B',
      now: env.clock.now(),
    );
    final Word word = await add('apple', bookId: book.id, translation: '苹果');
    await env.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'evt-add04',
      deviceId: 'device-a',
      now: env.clock.now(),
    );
    await env.books.removeWord(book.id, word.id, now: env.clock.now());
    await env.words.softDelete(word.id, now: env.clock.now());
    expect((await env.words.byNormalized('apple')), isNull);

    final WordIntakeResult restored = await env.intake.add(
      const WordIntakeRequest(
        text: 'apple',
        user: WordContent(translation: '我重新填的释义'),
      ),
      bookId: book.id,
      now: env.clock.now(),
    );

    expect(restored.kind, IntakeKind.revived);
    expect(restored.word.id, word.id, reason: 'UUID 必须保留');
    expect(restored.word.deletedAt, isNull);
    expect(restored.word.createdAt, word.createdAt);
    expect(restored.word.note, word.note);
    expect(restored.word.translation, '我重新填的释义');
    expect(restored.linkAdded, isTrue, reason: '先前被移出的词书关联要恢复');
    expect(await env.books.wordCount(book.id), 1);
    expect(await env.words.countWords(), 1, reason: '不能产生重复词条');
    expect(await env.words.eventsForWord(word.id), hasLength(1));
  });

  test('ADD05 删除后通过文件导入重新新增', () async {
    final WordBook book = await env.books.create(
      name: 'B',
      now: env.clock.now(),
    );
    final Word word = await add('abandon', bookId: book.id, translation: '放弃');
    await env.words.softDelete(word.id, now: env.clock.now());

    final ImportService service = env.importService();
    final ImportPreview preview = service.parseContent(
      'abandon\tv. 遗弃\n',
      format: 'txt',
      name: 'again.txt',
    );
    final ImportOutcome outcome = await service.commit(
      preview: preview,
      bookId: book.id,
      now: env.clock.now(),
    );

    expect(outcome.revived, 1);
    expect(outcome.created, 0);
    final Word? reloaded = await env.words.byNormalized('abandon');
    expect(reloaded, isNotNull);
    expect(reloaded!.id, word.id);
    expect(reloaded.translation, '放弃', reason: '恢复时不覆盖已有内容');
    expect(await env.books.wordCount(book.id), 1);
  });

  test('ADD06 删除后通过批量粘贴重新新增', () async {
    final WordBook book = await env.books.create(
      name: 'B',
      now: env.clock.now(),
    );
    final Word word = await add('benefit', bookId: book.id);
    await env.words.softDelete(word.id, now: env.clock.now());

    final ImportService service = env.importService();
    final ImportPreview preview = service.parseContent(
      'benefit\ncurious\n',
      format: 'txt',
      name: '批量添加',
    );
    final ImportOutcome outcome = await service.commit(
      preview: preview,
      bookId: book.id,
      now: env.clock.now(),
    );

    expect(outcome.revived, 1);
    expect(outcome.created, 1);
    expect(await env.books.wordCount(book.id), 2);
    expect((await env.words.byNormalized('benefit'))!.id, word.id);
  });

  test('ADD07 恢复后保留学习状态、历史与字段版本', () async {
    final Word word = await add('gamma', translation: '伽马');
    for (int i = 0; i < 2; i++) {
      await env.study.recordAnswer(
        wordId: word.id,
        result: AnswerResult.known,
        type: i == 0 ? ReviewType.study : ReviewType.review,
        eventId: 'evt-$i',
        deviceId: 'device-a',
        now: env.clock.now(),
      );
      env.clock.advance(const Duration(minutes: 1));
    }
    final LearningState stateBefore = (await env.words.stateFor(word.id))!;
    await env.words.softDelete(word.id, now: env.clock.now());
    final WordIntakeResult restored = await env.intake.add(
      const WordIntakeRequest(text: 'gamma'),
      now: env.clock.now(),
    );

    expect(restored.kind, IntakeKind.revived);
    final LearningState stateAfter = (await env.words.stateFor(word.id))!;
    expect(stateAfter.stage, stateBefore.stage);
    expect(stateAfter.correctCount, stateBefore.correctCount);
    expect(stateAfter.nextReviewAt, stateBefore.nextReviewAt);
    expect(await env.words.eventsForWord(word.id), hasLength(2));

    final Map<String, Map<String, Object?>> versions =
        await ContentVersionReader(env).of(word.id);
    expect(versions['deletedAt']!['version'], greaterThan(1));
    expect(versions['deletedAt']!['updatedAt'], isNot(0));
  });

  test('ADD08 重新新增后跨设备同步收敛', () async {
    final TestEnv other = await TestEnv.create();
    try {
      final WordBook book = await env.books.create(
        name: '共享词书',
        now: env.clock.now(),
      );
      final Word word = await add('apple', bookId: book.id, translation: '苹果');
      Map<String, Object?> snapshot = await env.backup.buildDataset(
        now: env.clock.now(),
      );
      await other.backup.mergeDataset(snapshot, now: other.clock.now());
      expect((await other.words.byNormalized('apple'))!.deletedAt, isNull);

      // Device A deletes, then explicitly restores.
      await env.words.softDelete(word.id, now: env.clock.now());
      await other.backup.mergeDataset(
        await env.backup.buildDataset(now: env.clock.now()),
        now: other.clock.now(),
      );
      expect((await other.words.byNormalized('apple')), isNull);

      env.clock.advance(const Duration(minutes: 5));
      await env.intake.add(
        const WordIntakeRequest(
          text: 'apple',
          user: WordContent(note: '恢复'),
        ),
        bookId: book.id,
        now: env.clock.now(),
      );
      snapshot = await env.backup.buildDataset(now: env.clock.now());
      await other.backup.mergeDataset(snapshot, now: other.clock.now());

      final Word? remote = await other.words.byNormalized('apple');
      expect(remote, isNotNull, reason: '恢复必须同步到另一台设备');
      expect(remote!.deletedAt, isNull);
      expect(remote.note, '恢复');

      // Both sides converge to the same logical content.
      final String hashA = await BackupServiceHash.of(env);
      final String hashB = await BackupServiceHash.of(other);
      expect(hashB, hashA);
    } finally {
      await other.dispose();
    }
  });

  test('ADD09 旧备份不会复活已删除的词条', () async {
    final WordBook book = await env.books.create(
      name: 'B',
      now: env.clock.now(),
    );
    final Word word = await add('curious', bookId: book.id, translation: '好奇的');
    final Map<String, Object?> old = await env.backup.buildDataset(
      now: env.clock.now(),
    );

    env.clock.advance(const Duration(minutes: 1));
    await env.words.softDelete(word.id, now: env.clock.now());
    await env.backup.mergeDataset(old, now: env.clock.now());

    final Word? after = await env.words.byId(word.id);
    expect(after!.deletedAt, isNotNull, reason: '旧快照不能撤销删除墓碑');
    expect(await env.words.byNormalized('curious'), isNull);
  });

  test('ADD10 批量新增中途失败时完整回滚', () async {
    final WordBook book = await env.books.create(
      name: 'B',
      now: env.clock.now(),
    );
    await expectLater(
      env.intake.addAll(
        const <WordIntakeRequest>[
          WordIntakeRequest(text: 'valid'),
          WordIntakeRequest(text: '   '), // rejected: empty word
        ],
        bookId: book.id,
        now: env.clock.now(),
      ),
      throwsA(isA<WordIntakeException>()),
    );
    expect(await env.words.countWords(), 0);
    expect(await env.books.wordCount(book.id), 0);
  });

  test('ADD11 同步快照与新增/编辑并发不丢失用户输入', () async {
    final Word word = await add('apple', translation: '旧释义');
    final Map<String, Object?> stale = await env.backup.buildDataset(
      now: env.clock.now(),
    );

    env.clock.advance(const Duration(minutes: 1));
    await env.intake.add(
      const WordIntakeRequest(
        text: 'apple',
        user: WordContent(translation: '本机新释义', note: '本机笔记'),
      ),
      now: env.clock.now(),
    );
    // A stale snapshot (another device that has not seen the edit) merges in.
    await env.backup.mergeDataset(stale, now: env.clock.now());

    final Word after = (await env.words.byId(word.id))!;
    expect(after.translation, '本机新释义');
    expect(after.note, '本机笔记');
  });

  test('ADD12 首次手填释义不会被词典覆盖', () async {
    final Word word = await add('apple', translation: '我自己写的');
    expect(word.customized, isTrue);

    final Word enriched = await env.words.applyDictionaryInfo(
      word: word,
      phonetic: 'ˈæpl',
      translation: '词典释义',
      definition: 'fruit',
      now: env.clock.now(),
    );
    expect(enriched.translation, '我自己写的');
    expect(enriched.phonetic, 'ˈæpl', reason: '空字段仍可由词典补全');

    // A word imported with file content is also protected.
    final ImportService service = env.importService();
    final ImportPreview preview = service.parseContent(
      'word,translation\nbenefit,好处\n',
      format: 'csv',
      name: 'x.csv',
    );
    await service.commit(
      preview: preview,
      newBookName: '导入',
      now: env.clock.now(),
    );
    final Word imported = (await env.words.byNormalized('benefit'))!;
    expect(imported.customized, isTrue);
    final Word refreshed = await env.words.applyDictionaryInfo(
      word: imported,
      translation: '词典的好处',
      now: env.clock.now(),
    );
    expect(refreshed.translation, '好处');
  });

  test('ADD13 显式清空与未提供字段正确区分', () async {
    final Word word = await add(
      'apple',
      translation: '苹果',
      note: '笔记',
      phonetic: 'ˈæpl',
    );
    final WordIntakeResult cleared = await env.intake.add(
      const WordIntakeRequest(
        text: 'apple',
        user: WordContent(translation: ''),
      ),
      now: env.clock.now(),
    );
    expect(cleared.kind, IntakeKind.updated);
    expect(cleared.word.translation, '', reason: '空串表示用户主动清空');
    expect(cleared.word.note, '笔记', reason: 'null 表示未提供，必须保留');
    expect(cleared.word.phonetic, 'ˈæpl');
    expect(cleared.changedFields, <String>['translation']);
    expect(cleared.word.id, word.id);
  });

  test('ADD14 目标词书被删除时安全拒绝保存', () async {
    final WordBook book = await env.books.create(
      name: 'B',
      now: env.clock.now(),
    );
    await env.books.softDelete(book.id, now: env.clock.now());

    await expectLater(
      env.intake.add(
        const WordIntakeRequest(text: 'apple'),
        bookId: book.id,
        now: env.clock.now(),
      ),
      throwsA(
        isA<WordIntakeException>().having(
          (WordIntakeException e) => e.message,
          'message',
          contains('词书已被删除'),
        ),
      ),
    );
    expect(await env.words.countWords(), 0);

    // The same guard applies to import, and nothing is written.
    final ImportService service = env.importService();
    final ImportPreview preview = service.parseContent(
      'apple\n',
      format: 'txt',
      name: 'a.txt',
    );
    await expectLater(
      service.commit(preview: preview, bookId: book.id, now: env.clock.now()),
      throwsA(isA<WordIntakeException>()),
    );
    expect(await env.words.countWords(), 0);
  });

  testWidgets('ADD04-UI 快速添加页可以重新添加已删除单词', (WidgetTester tester) async {
    final TestDictionary dictionary = TestDictionary.create(
      <String, ({String translation, String definition, String phonetic})>{
        'apple': (translation: 'n. 苹果', definition: 'fruit', phonetic: 'ˈæpl'),
      },
    );
    addTearDown(dictionary.dispose);
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final TestEnv local = await TestEnv.create();
    addTearDown(local.dispose);
    final WordBook book = await local.books.create(
      name: 'B',
      now: local.clock.now(),
    );
    final Word word = (await local.intake.add(
      const WordIntakeRequest(
        text: 'apple',
        user: WordContent(translation: '苹果'),
      ),
      bookId: book.id,
      now: local.clock.now(),
    )).word;
    await local.words.softDelete(word.id, now: local.clock.now());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(local.db),
          clockProvider.overrideWithValue(local.clock),
          dictionaryProvider.overrideWith(
            (Ref ref) async => dictionary.service,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: QuickAddPage(initialBookId: book.id),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).first, 'apple');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Word? restored = await local.words.byNormalized('apple');
    expect(restored, isNotNull, reason: '重新添加必须恢复而不是报错');
    expect(restored!.id, word.id);
    expect(restored.deletedAt, isNull);
    expect(await local.books.wordCount(book.id), 1);
  });
}

/// Reads per-field versions through the public repository API.
class ContentVersionReader {
  ContentVersionReader(this.env);

  final TestEnv env;

  Future<Map<String, Map<String, Object?>>> of(String wordId) async {
    final query = env.db.select(env.db.contentVersions)
      ..where((t) => t.kind.equals('word'));
    query.where((t) => t.entityId.equals(wordId));
    final List<ContentVersionRow> rows = await query.get();
    return <String, Map<String, Object?>>{
      for (final ContentVersionRow row in rows)
        row.field: <String, Object?>{
          'version': row.version,
          'updatedAt': row.updatedAt,
          'deviceId': row.deviceId,
        },
    };
  }
}

/// Convenience wrapper so tests read the same logical hash the sync layer uses.
class BackupServiceHash {
  static Future<String> of(TestEnv env) async {
    final Map<String, Object?> dataset = await env.backup.buildDataset(
      now: env.clock.now(),
    );
    return BackupService.contentHashOf(dataset);
  }
}
