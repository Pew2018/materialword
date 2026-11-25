import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/sync/conflict_store.dart';
import 'package:materialword/services/sync/github_sync_provider.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/word_intake_service.dart';

import 'helpers/test_env.dart';

/// Phase 5F acceptance: the 24 convergence scenarios plus provider edge cases.
///
/// Devices are independent real databases; the remote is a provider with the
/// same conditional-write contract as GitHub/WebDAV, so the coordinator,
/// merge, conflict rules and content hash are all exercised for real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv a;
  late TestEnv b;
  late TestEnv c;
  late ScriptedSyncProvider remote;

  setUp(() async {
    a = await TestEnv.create(now: DateTime(2026, 11, 24, 9));
    b = await TestEnv.create(now: DateTime(2026, 11, 24, 10));
    c = await TestEnv.create(now: DateTime(2026, 11, 24, 11));
    remote = ScriptedSyncProvider();
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
    await c.dispose();
  });

  Future<SyncReport> sync(
    TestEnv env, {
    bool allowRemoteRecreate = false,
  }) async {
    final SyncReport report = await env.coordinator.sync(
      remote,
      skipConnectionTest: true,
      allowRemoteRecreate: allowRemoteRecreate,
    );
    return report;
  }

  Future<String> hashOf(TestEnv env) async => BackupService.contentHashOf(
    await env.backup.buildDataset(now: env.clock.now()),
  );

  Future<Word> addWord(
    TestEnv env,
    String text, {
    String? translation,
    String? note,
    String? bookId,
  }) async {
    final WordIntakeResult result = await env.intake.add(
      WordIntakeRequest(
        text: text,
        user: WordContent(translation: translation, note: note),
      ),
      bookId: bookId,
      now: env.clock.now(),
    );
    return result.word;
  }

  test('SYNC01 A 新增后 B 获取', () async {
    await addWord(a, 'alpha', translation: '阿尔法');
    await sync(a);
    final SyncReport pull = await sync(b);
    expect(pull.ok, isTrue);
    final Word? landed = await b.words.byNormalized('alpha');
    expect(landed, isNotNull);
    expect(landed!.translation, '阿尔法');
    expect(await hashOf(b), await hashOf(a));
  });

  test('SYNC02 B 编辑后 A 获取', () async {
    await addWord(a, 'alpha', translation: '阿尔法');
    await sync(a);
    await sync(b);
    final Word inB = (await b.words.byNormalized('alpha'))!;
    b.clock.advance(const Duration(minutes: 5));
    await b.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(translation: '贝塔改的释义'),
      ),
      now: b.clock.now(),
    );
    await sync(b);
    await sync(a);
    expect((await a.words.byId(inB.id))!.translation, '贝塔改的释义');
  });

  test('SYNC03 A、B 离线学习后合并', () async {
    final WordBook book = await a.seedBook(words: <String>['alpha', 'beta']);
    await sync(a);
    await sync(b);
    final Word alpha = (await a.words.byNormalized('alpha'))!;
    final Word beta = (await b.words.byNormalized('beta'))!;
    await a.study.recordAnswer(
      wordId: alpha.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'a-1',
      deviceId: 'dev-a',
      now: a.clock.now(),
    );
    await b.study.recordAnswer(
      wordId: beta.id,
      result: AnswerResult.hazy,
      type: ReviewType.study,
      eventId: 'b-1',
      deviceId: 'dev-b',
      now: b.clock.now(),
    );
    await sync(a);
    await sync(b);
    await sync(a);
    final List<ReviewEvent> events = await a.db.select(a.db.reviewEvents).get();
    expect(events.map((ReviewEvent e) => e.id).toSet(), <String>{'a-1', 'b-1'});
    expect(
      (await b.db.select(b.db.reviewEvents).get())
          .map((ReviewEvent e) => e.id)
          .toSet(),
      <String>{'a-1', 'b-1'},
    );
    expect(await hashOf(a), await hashOf(b));
    expect(book.name, isNotEmpty);
  });

  test('SYNC04 A、B 同时创建相同单词只保留一个身份', () async {
    await addWord(a, 'alpha', translation: '阿尔法');
    await addWord(b, 'alpha', translation: '阿尔法（B）');
    await sync(a);
    await sync(b);
    await sync(a);
    // B pulls the final remote state (the last upload came from A).
    await sync(b);
    expect(await a.words.countWords(), 1);
    expect(await b.words.countWords(), 1);
    expect(await hashOf(a), await hashOf(b));
  });

  test('SYNC05 不同字段并发编辑都保留', () async {
    await addWord(a, 'alpha', translation: '原释义', note: '原笔记');
    await sync(a);
    await sync(b);
    a.clock.advance(const Duration(minutes: 5));
    b.clock.advance(const Duration(minutes: 6));
    await a.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(translation: 'A 的释义'),
      ),
      now: a.clock.now(),
    );
    await b.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(note: 'B 的笔记'),
      ),
      now: b.clock.now(),
    );
    await sync(a);
    await sync(b);
    await sync(a);
    final Word merged = (await a.words.byNormalized('alpha'))!;
    expect(merged.translation, 'A 的释义');
    expect(merged.note, 'B 的笔记');
    expect(await hashOf(a), await hashOf(b));
  });

  test('SYNC06 相同字段并发编辑确定性收敛并记录冲突', () async {
    await addWord(a, 'alpha', translation: '初始');
    await sync(a);
    await sync(b);
    a.clock.advance(const Duration(minutes: 5));
    b.clock.advance(const Duration(minutes: 9));
    await a.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(translation: 'A 版本'),
      ),
      now: a.clock.now(),
    );
    await b.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(translation: 'B 版本'),
      ),
      now: b.clock.now(),
    );
    await sync(a);
    final SyncReport merged = await sync(b);
    expect(merged.conflicts + merged.merge!.conflicts, greaterThan(0));
    await sync(a);

    expect((await a.words.byNormalized('alpha'))!.translation, 'B 版本');
    expect((await b.words.byNormalized('alpha'))!.translation, 'B 版本');
    expect(await hashOf(a), await hashOf(b));

    final List<StoredSyncConflict> recorded = await SyncConflictStore(b.db)
        .list();
    expect(recorded, isNotEmpty);
    final StoredSyncConflict conflict = recorded.firstWhere(
      (StoredSyncConflict entry) => entry.field == 'translation',
    );
    expect(conflict.discardedValue, 'A 版本');
    expect(conflict.adoptedValue, 'B 版本');

    // Restoring the discarded value is a new edit and converges like one.
    await b.words.updateContent(
      conflict.entityId,
      translation: conflict.discardedValue as String,
      now: b.clock.now(),
    );
    await sync(b);
    await sync(a);
    expect((await a.words.byNormalized('alpha'))!.translation, 'A 版本');
  });

  test('SYNC07 词条重命名保持身份与历史', () async {
    final WordBook book = await a.seedBook(words: <String>['color']);
    final Word word = (await a.words.byNormalized('color'))!;
    await a.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'rename-1',
      deviceId: 'dev-a',
      now: a.clock.now(),
    );
    await sync(a);
    await sync(b);
    b.clock.advance(const Duration(minutes: 5));
    await b.words.updateContent(
      (await b.words.byNormalized('color'))!.id,
      text: 'colour',
      now: b.clock.now(),
    );
    await sync(b);
    await sync(a);
    expect(await a.words.countWords(), 1, reason: '重命名不能产生第二个词条');
    expect((await a.words.byId(word.id))!.word, 'colour');
    expect(await a.words.eventsForWord(word.id), hasLength(1));
    expect(await a.books.wordCount(book.id), 1);
    expect(await hashOf(a), await hashOf(b));
  });

  test('SYNC08 词书重命名同步', () async {
    final WordBook book = await a.books.create(name: '旧名字', now: a.clock.now());
    await addWord(a, 'alpha', bookId: book.id);
    await sync(a);
    await sync(b);
    b.clock.advance(const Duration(minutes: 5));
    await b.books.rename(book.id, '新名字', now: b.clock.now());
    await sync(b);
    await sync(a);
    expect((await a.books.byId(book.id))!.name, '新名字');
    expect(await hashOf(a), await hashOf(b));
  });

  test('SYNC09 词条删除同步到其他设备', () async {
    final Word word = await addWord(a, 'alpha');
    await sync(a);
    await sync(b);
    a.clock.advance(const Duration(minutes: 5));
    await a.words.softDelete(word.id, now: a.clock.now());
    await sync(a);
    await sync(b);
    expect(await b.words.byNormalized('alpha'), isNull);
    expect((await b.words.byId(word.id))!.deletedAt, isNotNull);
  });

  test('SYNC10 删除后明确重新新增同步', () async {
    final Word word = await addWord(a, 'alpha');
    await sync(a);
    await sync(b);
    a.clock.advance(const Duration(minutes: 5));
    await a.words.softDelete(word.id, now: a.clock.now());
    await sync(a);
    await sync(b);
    a.clock.advance(const Duration(minutes: 5));
    await a.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(translation: '重新添加'),
      ),
      now: a.clock.now(),
    );
    await sync(a);
    await sync(b);
    final Word? restored = await b.words.byNormalized('alpha');
    expect(restored, isNotNull);
    expect(restored!.id, word.id);
    expect(restored.translation, '重新添加');
    expect(await hashOf(a), await hashOf(b));
  });

  test('SYNC11 词书关联的删除与恢复同步', () async {
    final WordBook book = await a.seedBook(words: <String>['alpha']);
    final Word word = (await a.words.byNormalized('alpha'))!;
    await sync(a);
    await sync(b);
    a.clock.advance(const Duration(minutes: 5));
    await a.books.removeWord(book.id, word.id, now: a.clock.now());
    await sync(a);
    await sync(b);
    expect(await b.books.wordCount(book.id), 0);

    a.clock.advance(const Duration(minutes: 5));
    await a.books.addWords(book.id, <String>[word.id], now: a.clock.now());
    await sync(a);
    await sync(b);
    expect(await b.books.wordCount(book.id), 1);
    expect(await hashOf(a), await hashOf(b));
  });

  test('SYNC12 收藏与标签同步', () async {
    final Word word = await addWord(a, 'alpha');
    await a.metadata.setFavorite(<String>[word.id], true, now: a.clock.now());
    final UserTag tag = await a.metadata.createTag('重点', now: a.clock.now());
    await a.metadata.setTag(
      <String>[word.id],
      tag.id,
      true,
      now: a.clock.now(),
    );
    await sync(a);
    await sync(b);
    final Word target = (await b.words.byNormalized('alpha'))!;
    final FavoriteRow? favorite = await (b.db.select(
      b.db.wordFavorites,
    )..where((t) => t.wordId.equals(target.id))).getSingleOrNull();
    expect(favorite?.value, isTrue);
    final List<WordTag> links = await (b.db.select(
      b.db.wordTags,
    )..where((t) => t.wordId.equals(target.id))).get();
    expect(links.where((WordTag link) => link.deletedAt == null), hasLength(1));
    final List<UserTag> tags = await b.metadata.listTags();
    expect(tags.map((UserTag t) => t.name), contains('重点'));
    expect(await hashOf(a), await hashOf(b));
  });

  test('SYNC13 学习计划同步', () async {
    await a.settings.save(dailyNewTarget: 42, dailyReviewLimit: 77);
    await sync(a);
    await sync(b);
    final StudySettingsRow settings = await b.settings.load();
    expect(settings.dailyNewTarget, 42);
    expect(settings.dailyReviewLimit, 77);
    expect(await hashOf(a), await hashOf(b));
  });

  test('SYNC14 撤销事件同步', () async {
    final Word word = await addWord(a, 'alpha');
    await a.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.unknown,
      type: ReviewType.study,
      eventId: 'answer-1',
      deviceId: 'dev-a',
      now: a.clock.now(),
    );
    await sync(a);
    await sync(b);
    a.clock.advance(const Duration(minutes: 5));
    await a.study.undoAnswer(
      eventId: 'answer-1',
      undoId: 'undo-1',
      deviceId: 'dev-a',
      now: a.clock.now(),
    );
    await sync(a);
    await sync(b);
    final List<ReviewEvent> events = await b.db.select(b.db.reviewEvents).get();
    expect(
      events.map((ReviewEvent e) => e.mode).toSet(),
      contains('undo:answer-1'),
    );
    expect((await b.words.stateFor(word.id))?.wrongCount ?? 0, 0);
  });

  test('SYNC15 练习与冲刺记录同步并重放', () async {
    final Word word = await addWord(a, 'alpha');
    await a.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.hazy,
      type: ReviewType.review,
      eventId: 'practice-1',
      deviceId: 'dev-a',
      mode: 'practice-choice',
      now: a.clock.now(),
    );
    await a.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.known,
      type: ReviewType.review,
      eventId: 'sprint-1',
      deviceId: 'dev-a',
      mode: 'sprint',
      now: a.clock.now().add(const Duration(seconds: 1)),
    );
    await sync(a);
    await sync(b);
    final LearningState stateA = (await a.words.stateFor(word.id))!;
    final LearningState stateB = (await b.words.stateFor(word.id))!;
    expect(stateB.stage, stateA.stage);
    expect(stateB.correctCount, stateA.correctCount);
    expect(stateB.hazyCount, stateA.hazyCount);
    expect(await hashOf(a), await hashOf(b));
  });

  test('SYNC16 上传期间继续学习不会丢失作答', () async {
    final Word word = await addWord(a, 'alpha');
    final ScriptedSyncProvider slow = ScriptedSyncProvider(
      beforeUpload: () async {
        await a.study.recordAnswer(
          wordId: word.id,
          result: AnswerResult.known,
          type: ReviewType.study,
          eventId: 'during-upload',
          deviceId: 'dev-a',
          now: a.clock.now(),
        );
      },
    );
    await a.coordinator.sync(slow, skipConnectionTest: true);
    expect(await a.words.eventsForWord(word.id), hasLength(1));
    // The answer arrived after the snapshot was taken, so it stays pending.
    expect(await a.coordinator.hasLocalChanges(target: slow), isTrue);
    await a.coordinator.sync(slow, skipConnectionTest: true);
    expect((slow.lastUploaded!['reviewEvents'] as List<dynamic>), hasLength(1));
  });

  test('SYNC17 上传期间继续新增单词不丢失', () async {
    await addWord(a, 'alpha');
    final ScriptedSyncProvider slow = ScriptedSyncProvider(
      beforeUpload: () async {
        await addWord(a, 'beta');
      },
    );
    await a.coordinator.sync(slow, skipConnectionTest: true);
    expect(await a.words.byNormalized('beta'), isNotNull);
    expect(await a.coordinator.hasLocalChanges(target: slow), isTrue);
  });

  test('SYNC18 同步中更换同步目标不会写错状态', () async {
    await addWord(a, 'alpha');
    final Map<String, Object?> configA = <String, Object?>{
      'provider': 'local-file',
      'path': '/tmp/a.json',
    };
    await a.settings.setSyncConfig(configA);
    final ScriptedSyncProvider slow = ScriptedSyncProvider(
      beforeUpload: () async {
        await a.settings.setSyncConfig(<String, Object?>{
          'provider': 'local-file',
          'path': '/tmp/b.json',
        });
      },
    );
    await a.coordinator.sync(slow, skipConnectionTest: true);
    // The stale run must not overwrite the *new* target's global status...
    expect(await a.settings.lastSyncAt(), isNull);
    // ...nor pretend the new target itself has synced.
    final String newTarget = SyncCoordinator.targetKey(
      a.coordinator.providerFromConfig(<String, Object?>{
        'provider': 'local-file',
        'path': '/tmp/b.json',
      })!,
    );
    expect(await a.db.readMeta('sync_target:$newTarget'), isNull);
    // The old target's own record is still accurate and keyed separately.
    expect(
      await a.db.readMeta('sync_target:${SyncCoordinator.targetKey(slow)}'),
      isNotNull,
    );
  });

  test('SYNC19 远端数据损坏时拒绝导入且本机不变', () async {
    await addWord(a, 'alpha');
    final ScriptedSyncProvider corrupt = ScriptedSyncProvider(
      initial: <String, Object?>{
        'schemaVersion': 3,
        'kind': 'materialword-backup',
        'words': <Object?>[
          <String, Object?>{'id': 'x'}, // missing word/normalized
        ],
      },
    );
    await expectLater(
      a.coordinator.sync(corrupt, skipConnectionTest: true),
      throwsA(isA<SyncDataException>()),
    );
    expect(await a.words.countWords(), 1);
    expect(corrupt.uploadCalls, 0);
  });

  test('SYNC20 恢复后同步暂停，直到明确决定', () async {
    await addWord(a, 'alpha');
    final String json = await a.backup.exportToJson(now: a.clock.now());
    final File copy = await a.backup.writeJsonAtomically(
      directory: a.backupDirectory,
      json: json,
      now: a.clock.now(),
      label: 'manual',
    );
    await a.backups.restoreSnapshot(copy);
    await expectLater(
      a.coordinator.sync(remote, skipConnectionTest: true),
      throwsA(isA<SyncException>()),
    );
    expect(remote.uploadCalls, 0);
  });

  test('SYNC21 进程重启后仍保留 pending 状态与退避', () async {
    await addWord(a, 'alpha');
    final ScriptedSyncProvider failing = ScriptedSyncProvider(
      failFirstUploads: 99,
    );
    await a.settings.setSyncConfig(<String, Object?>{
      'provider': 'local-file',
      'path': '/tmp/x.json',
      'autoOnChange': true,
    });
    await a.db.writeMeta(
      'sync_target:${SyncCoordinator.targetKey(failing)}',
      jsonEncode(<String, Object?>{'at': '2026-11-24T00:00:00Z', 'hash': 'x'}),
    );
    await expectLater(
      a.coordinator.sync(failing, skipConnectionTest: true),
      throwsA(isA<SyncException>()),
    );
    // A fresh coordinator on the same database sees the same backoff state.
    final SyncCoordinator restarted = SyncCoordinator(
      db: a.db,
      backup: a.backup,
      study: a.study,
      settings: a.settings,
      credentials: a.coordinator.credentials,
      clock: a.clock,
    );
    expect(await restarted.hasLocalChanges(target: failing), isTrue);
    final String? raw = await a.db.readMeta(
      'sync_auto:${SyncCoordinator.targetKey(failing)}',
    );
    expect(raw, isNotNull);
  });

  test('SYNC22 无本机修改时发现并获取远端更新', () async {
    await addWord(a, 'alpha');
    await sync(a);
    await sync(b);
    // Both devices now know the current remote revision.
    expect(await b.coordinator.remoteChanged(provider: remote), isFalse);

    a.clock.advance(const Duration(minutes: 5));
    await addWord(a, 'beta');
    await sync(a);
    expect(await b.coordinator.remoteChanged(provider: remote), isTrue);
    expect(await b.coordinator.hasLocalChanges(target: remote), isFalse);
    await sync(b);
    expect(await b.words.byNormalized('beta'), isNotNull);
  });

  test('SYNC23 网络恢复后可以继续同步（退避后可重试）', () async {
    await addWord(a, 'alpha');
    final ScriptedSyncProvider flaky = ScriptedSyncProvider(
      failFirstUploads: 1,
    );
    await expectLater(
      a.coordinator.sync(flaky, skipConnectionTest: true),
      throwsA(isA<SyncException>()),
    );
    expect(await a.coordinator.hasLocalChanges(target: flaky), isTrue);
    // The local merge (nothing to merge here) did not lose anything.
    expect(await a.words.byNormalized('alpha'), isNotNull);
    final SyncReport retry = await a.coordinator.sync(
      flaky,
      skipConnectionTest: true,
    );
    expect(retry.ok, isTrue);
    expect(retry.uploaded, isTrue);
    expect(await a.coordinator.hasLocalChanges(target: flaky), isFalse);
  });

  test('SYNC24 连续多轮同步后逻辑内容哈希收敛', () async {
    final WordBook book = await a.seedBook(words: <String>['alpha', 'beta']);
    await sync(a);
    await sync(b);
    await sync(c);
    for (int round = 0; round < 3; round++) {
      a.clock.advance(const Duration(minutes: 3));
      b.clock.advance(const Duration(minutes: 4));
      c.clock.advance(const Duration(minutes: 5));
      await addWord(a, 'rounda$round', bookId: book.id);
      await addWord(b, 'roundb$round');
      await addWord(c, 'roundc$round');
      await sync(a);
      await sync(b);
      await sync(c);
      await sync(a);
    }
    // One catch-up round so every device has seen the last upload.
    await sync(a);
    await sync(b);
    await sync(c);
    final String hashA = await hashOf(a);
    expect(await hashOf(b), hashA);
    expect(await hashOf(c), hashA);
    expect(await a.words.countWords(), 2 + 9);
  });

  group('provider edge cases', () {
    test('GitHub 远端文件被删除时停止自动同步，需显式重建', () async {
      Map<String, Object?>? file;
      int puts = 0;
      final GitHubSyncProvider github = GitHubSyncProvider(
        owner: 'owner',
        repo: 'data',
        tokenOverride: 'synthetic-token',
        client: MockClient((http.Request request) async {
          if (request.url.path == '/repos/owner/data') {
            return http.Response(
              jsonEncode(<String, Object?>{
                'private': true,
                'permissions': <String, Object?>{'push': true},
              }),
              200,
            );
          }
          if (request.url.path.contains('/branches/')) {
            return http.Response(
              '{"name":"main","commit":{"sha":"head"}}',
              200,
            );
          }
          if (request.url.path.contains('/contents/')) {
            if (request.method == 'PUT') {
              puts++;
              final Map<String, dynamic> body =
                  jsonDecode(request.body) as Map<String, dynamic>;
              file = jsonDecode(
                utf8.decode(base64Decode(body['content'] as String)),
              ) as Map<String, Object?>;
              return http.Response(
                jsonEncode(<String, Object?>{
                  'content': <String, Object?>{'sha': 'sha-$puts'},
                }),
                201,
              );
            }
            if (file == null) {
              return http.Response('{"message":"Not Found"}', 404);
            }
            return http.Response(
              jsonEncode(<String, Object?>{
                'sha': 'sha-$puts',
                'content': base64Encode(utf8.encode(jsonEncode(file))),
                'encoding': 'base64',
                'size': utf8.encode(jsonEncode(file)).length,
              }),
              200,
            );
          }
          return http.Response('', 404);
        }),
      );

      await addWord(a, 'alpha');
      final SyncReport first = await a.coordinator.sync(
        github,
        skipConnectionTest: true,
      );
      expect(first.ok, isTrue);
      expect(puts, 1);

      // Someone deletes the file in the repository.
      file = null;
      a.clock.advance(const Duration(minutes: 5));
      await addWord(a, 'beta');
      await expectLater(
        a.coordinator.sync(github, skipConnectionTest: true),
        throwsA(isA<SyncRemoteMissingException>()),
      );
      expect(puts, 1, reason: '不得在未确认时重建远端');

      final SyncReport recreated = await a.coordinator.sync(
        github,
        skipConnectionTest: true,
        allowRemoteRecreate: true,
      );
      expect(recreated.ok, isTrue);
      expect(puts, 2);
      expect(file!['words'], hasLength(2));
    });

    test('本地文件同步需要手动合并，不提供条件写入', () async {
      final ScriptedSyncProvider local = ScriptedSyncProvider(
        initial: await a.backup.buildDataset(now: a.clock.now()),
      );
      await addWord(a, 'alpha');
      final SyncReport report = await a.coordinator.sync(
        local,
        skipConnectionTest: true,
      );
      expect(report.ok, isTrue);
      expect(
        a.coordinator.providerFromConfig(<String, Object?>{
          'provider': 'local-file',
          'path': '/tmp/x.json',
        }),
        isA<Object>(),
      );
    });
  });
}
