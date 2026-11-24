import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/local_file_sync_provider.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';

import 'helpers/test_env.dart';

/// SYNC01 – SYNC09, SYNC13 – SYNC15: identity mapping, tombstones, idempotency,
/// interrupted sync recovery and the local-file transport.
void main() {
  Future<void> answer(
    TestEnv env,
    String wordId,
    String eventId, {
    AnswerResult result = AnswerResult.known,
    ReviewType type = ReviewType.study,
    String device = 'dev',
    DateTime? at,
  }) {
    return env.study.recordAnswer(
      wordId: wordId,
      result: result,
      type: type,
      eventId: eventId,
      deviceId: device,
      now: at ?? env.clock.now(),
    );
  }

  group('SYNC01/02 词条身份映射', () {
    test('两台设备独立创建同一单词，学习记录全部保留且只留一个词条', () async {
      final TestEnv phone = await TestEnv.create();
      final TestEnv laptop = await TestEnv.create();

      // Both devices independently create "apple" (different UUIDs).
      final bookA = await phone.seedBook(
        name: '手机词书',
        words: <String>['apple', 'beta'],
      );
      final bookB = await laptop.seedBook(
        name: '电脑词书',
        words: <String>['apple', 'gamma'],
      );
      final phoneApple = (await phone.words.listWords(bookId: bookA.id))
          .firstWhere((w) => w.word.word == 'apple')
          .word;
      final laptopApple = (await laptop.words.listWords(bookId: bookB.id))
          .firstWhere((w) => w.word.word == 'apple')
          .word;
      expect(phoneApple.id, isNot(laptopApple.id));

      // Each device studies its own copy.
      await answer(phone, phoneApple.id, 'phone-1');
      await answer(
        laptop,
        laptopApple.id,
        'laptop-1',
        result: AnswerResult.unknown,
        device: 'laptop',
      );

      // Round 1: laptop → phone.
      final fromLaptop = await laptop.backup.buildDataset(
        now: laptop.clock.now(),
      );
      final report = await phone.backup.mergeDataset(
        fromLaptop,
        now: phone.clock.now(),
      );

      expect(report.newWords, 1, reason: 'beta/gamma are new on the phone');
      final apples = await phone.words.watchSearch('apple').first;
      expect(
        apples.where((w) => w.word.word.toLowerCase() == 'apple').length,
        1,
        reason: 'normalised identity must dedupe the two copies',
      );
      final mergedApple = apples.singleWhere(
        (w) => w.word.word.toLowerCase() == 'apple',
      );
      expect(mergedApple.word.id, phoneApple.id, reason: 'canonical id kept');

      // Both devices' events survived, attached to the canonical word.
      final events = await phone.words.eventsForWord(phoneApple.id);
      expect(events.map((e) => e.id).toSet(), <String>{'phone-1', 'laptop-1'});
      final state = await phone.words.stateFor(phoneApple.id);
      expect(state, isNotNull);
      expect(state!.wrongCount, 1, reason: 'remote "unknown" was replayed');
      expect(state.correctCount, 1);

      // The phone book and the laptop book both contain the shared word.
      expect(await phone.study.totalCount(bookId: bookA.id), 2);

      // Round 2: phone → laptop; no duplicates anywhere.
      final fromPhone = await phone.backup.buildDataset(now: phone.clock.now());
      await laptop.backup.mergeDataset(fromPhone, now: laptop.clock.now());
      expect((await laptop.words.watchSearch('apple').first).length, 1);
      expect((await laptop.words.eventsForWord(laptopApple.id)).length, 2);

      // Round 3: idempotent.
      final secondMerge = await laptop.backup.mergeDataset(
        fromPhone,
        now: laptop.clock.now(),
      );
      expect(secondMerge.newWords, 0);
      expect(secondMerge.addedEvents, 0);
      expect(secondMerge.newEntries, 0);

      await phone.dispose();
      await laptop.dispose();
    });
  });

  group('SYNC03/04 词书关联删除', () {
    test('移出词书不会被旧备份复活', () async {
      final TestEnv a = await TestEnv.create();
      final TestEnv b = await TestEnv.create();
      final book = await a.seedBook(words: <String>['apple']);
      final wordId = (await a.words.listWords(bookId: book.id)).single.word.id;

      final oldDataset = await a.backup.buildDataset(now: a.clock.now());
      await b.backup.mergeDataset(oldDataset, now: b.clock.now());

      // Remove on A (tombstone), then A's snapshot travels to B.
      a.clock.advance(const Duration(minutes: 5));
      await a.books.removeWord(book.id, wordId, now: a.clock.now());
      final removedDataset = await a.backup.buildDataset(now: a.clock.now());
      await b.backup.mergeDataset(removedDataset, now: b.clock.now());
      expect(await b.books.wordCount(book.id), 0);

      // The stale snapshot must not resurrect the link.
      a.clock.advance(const Duration(minutes: 5));
      final staleMerge = await b.backup.mergeDataset(
        oldDataset,
        now: b.clock.now(),
      );
      expect(staleMerge.newEntries, 0);
      expect(await b.books.wordCount(book.id), 0);
      await a.dispose();
      await b.dispose();
    });

    test('删除后重新加入，旧备份不会再次删除它', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(words: <String>['apple']);
      final wordId = (await env.words.listWords(bookId: book.id))
          .single
          .word
          .id;

      final firstAdd = await env.backup.buildDataset(now: env.clock.now());
      env.clock.advance(const Duration(minutes: 1));
      await env.books.removeWord(book.id, wordId, now: env.clock.now());
      env.clock.advance(const Duration(minutes: 1));
      await env.books.addWords(book.id, <String>[wordId], now: env.clock.now());
      expect(await env.books.wordCount(book.id), 1);

      await env.backup.mergeDataset(firstAdd, now: env.clock.now());
      expect(
        await env.books.wordCount(book.id),
        1,
        reason: 'the re-added link has a newer version',
      );

      final entries = await env.db.select(env.db.wordBookEntries).get();
      expect(entries.single.deletedAt, isNull);
      expect(entries.single.version, 3);
      await env.dispose();
    });
  });

  group('SYNC05/06 幂等与往返一致', () {
    test('重复导入同一份数据不产生任何变化', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(words: <String>['alpha', 'beta']);
      final rows = await env.words.listWords(bookId: book.id);
      await answer(env, rows.first.word.id, 'e1');

      final dataset = await env.backup.buildDataset(now: env.clock.now());
      final first = await env.backup.mergeDataset(
        dataset,
        now: env.clock.now(),
      );
      final second = await env.backup.mergeDataset(
        dataset,
        now: env.clock.now(),
      );
      expect(first.addedEvents, 0, reason: 'same events already present');
      expect(second.addedEvents, 0);
      expect(second.newWords, 0);
      expect(second.newEntries, 0);
      expect(second.duplicateEvents, 1);
      await env.dispose();
    });

    test('多次往返同步达到稳定状态（内容哈希一致）', () async {
      final TestEnv a = await TestEnv.create();
      final TestEnv b = await TestEnv.create();
      final bookA = await a.seedBook(name: 'A', words: <String>['alpha']);
      await b.seedBook(name: 'B', words: <String>['beta']);
      final alphaId = (await a.words.listWords(bookId: bookA.id))
          .single
          .word
          .id;
      await answer(a, alphaId, 'a1', device: 'a');

      for (int round = 0; round < 3; round++) {
        final fromA = await a.backup.buildDataset(now: a.clock.now());
        await b.backup.mergeDataset(fromA, now: b.clock.now());
        final fromB = await b.backup.buildDataset(now: b.clock.now());
        await a.backup.mergeDataset(fromB, now: a.clock.now());
      }

      final hashA = BackupService.contentHashOf(
        await a.backup.buildDataset(now: a.clock.now()),
      );
      final hashB = BackupService.contentHashOf(
        await b.backup.buildDataset(now: b.clock.now()),
      );
      expect(hashA, hashB, reason: 'both devices converge on the same content');
      expect(await a.study.totalCount(), 2);
      expect(await b.study.totalCount(), 2);
      await a.dispose();
      await b.dispose();
    });
  });

  group('SYNC07/08 中断与并发写入', () {
    test('pending 标记可以修复被中断的重建', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(words: <String>['alpha']);
      final wordId = (await env.words.listWords(bookId: book.id))
          .single
          .word
          .id;
      await answer(env, wordId, 'e1');

      final coordinator = SyncCoordinator(
        db: env.db,
        backup: env.backup,
        study: env.study,
        settings: env.settings,
        credentials: InMemoryCredentialStore(),
        clock: env.clock,
      );
      await coordinator.markPendingRebuild(<String>[wordId]);
      // Simulate the crash: the state row is gone but the marker remains.
      await (env.db.delete(
        env.db.learningStates,
      )..where((t) => t.wordId.equals(wordId))).go();
      expect(await env.words.stateFor(wordId), isNull);

      final repaired = await coordinator.recoverPendingRebuild();
      expect(repaired, 1);
      final state = await env.words.stateFor(wordId);
      expect(state, isNotNull, reason: 'state rebuilt from the event log');
      expect(state!.stage, isNot(0));
      expect(
        await coordinator.recoverPendingRebuild(),
        0,
        reason: 'marker cleared after recovery',
      );
      await env.dispose();
    });

    test('同步期间新增的本地学习记录不会被合并覆盖', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(words: <String>['alpha']);
      final wordId = (await env.words.listWords(bookId: book.id))
          .single
          .word
          .id;
      final remote = await env.backup.buildDataset(now: env.clock.now());

      await answer(env, wordId, 'during-sync');
      await env.backup.mergeDataset(remote, now: env.clock.now());

      final events = await env.words.eventsForWord(wordId);
      expect(events.map((e) => e.id), contains('during-sync'));
      expect((await env.words.stateFor(wordId))!.correctCount, 1);
      await env.dispose();
    });
  });

  group('SYNC09 损坏数据与不兼容版本', () {
    test('版本过新被拒绝且不改动本地数据', () async {
      final TestEnv env = await TestEnv.create();
      await env.seedBook(words: <String>['alpha']);
      final dataset = <String, Object?>{
        'schemaVersion': 99,
        'kind': backupKind,
        'words': <Object?>[],
      };
      expect(
        () => env.backup.mergeDataset(dataset, now: env.clock.now()),
        throwsA(isA<BackupException>()),
      );
      expect(await env.study.totalCount(), 1);
      await env.dispose();
    });

    test('损坏的 JSON 被识别为数据错误', () async {
      final TestEnv env = await TestEnv.create();
      expect(
        () => env.backup.decodeDataset('{not json'),
        throwsA(isA<BackupException>()),
      );
      expect(
        () => env.backup.decodeDataset('{"kind":"other"}'),
        throwsA(isA<BackupException>()),
      );
      await env.dispose();
    });

    test('字段类型错误的数组被拒绝', () async {
      final TestEnv env = await TestEnv.create();
      expect(
        () => env.backup.validateDataset(<String, Object?>{
          'schemaVersion': 2,
          'kind': backupKind,
          'words': <String, Object?>{'not': 'a list'},
        }),
        throwsA(isA<BackupException>()),
      );
      await env.dispose();
    });
  });

  group('SYNC13 凭据不进入备份', () {
    test('备份 JSON 不包含 Token 或密码', () async {
      final TestEnv env = await TestEnv.create();
      await env.seedBook(words: <String>['alpha']);
      final store = InMemoryCredentialStore(<String, String>{
        CredentialKeys.githubToken: 'ghp_secret_token_value',
        CredentialKeys.webdavPassword: 'super-secret-password',
      });
      expect(store.snapshot.length, 2);

      final json = await env.backup.exportToJson(now: env.clock.now());
      expect(json.contains('ghp_secret_token_value'), isFalse);
      expect(json.contains('super-secret-password'), isFalse);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.containsKey('token'), isFalse);
      expect(decoded.containsKey('password'), isFalse);
      await env.dispose();
    });
  });

  group('SYNC14 无变化不重复上传', () {
    test('远程与本地一致时跳过上传', () async {
      final TestEnv env = await TestEnv.create();
      await env.seedBook(words: <String>['alpha']);
      final dataset = await env.backup.buildDataset(now: env.clock.now());
      final provider = ScriptedSyncProvider(initial: dataset);
      final coordinator = SyncCoordinator(
        db: env.db,
        backup: env.backup,
        study: env.study,
        settings: env.settings,
        credentials: InMemoryCredentialStore(),
        clock: env.clock,
      );
      final report = await coordinator.sync(provider);
      expect(report.ok, isTrue);
      expect(report.skipped, isTrue);
      expect(provider.uploadCalls, 0);
      await env.dispose();
    });

    test('有本地变化时上传一次并校验', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(words: <String>['alpha']);
      final wordId = (await env.words.listWords(bookId: book.id))
          .single
          .word
          .id;
      final empty = await env.backup.buildDataset(
        now: env.clock.now(),
        includeEvents: true,
      );
      final provider = ScriptedSyncProvider(
        initial: <String, Object?>{
          ...empty,
          'words': <Object?>[],
          'wordBooks': <Object?>[],
          'entries': <Object?>[],
          'reviewEvents': <Object?>[],
        },
      );
      await answer(env, wordId, 'e1');
      final coordinator = SyncCoordinator(
        db: env.db,
        backup: env.backup,
        study: env.study,
        settings: env.settings,
        credentials: InMemoryCredentialStore(),
        clock: env.clock,
      );
      final report = await coordinator.sync(provider);
      expect(report.ok, isTrue);
      expect(provider.uploadCalls, 1);
      expect(provider.lastIfRevision, 'rev-0');
      expect(report.uploaded, isTrue);
      final remoteEvents =
          (provider.lastUploaded!['reviewEvents'] as List<dynamic>).length;
      expect(remoteEvents, 1);
      await env.dispose();
    });

    test('上传冲突会重新拉取、合并并重试', () async {
      final TestEnv env = await TestEnv.create();
      await env.seedBook(words: <String>['alpha']);
      final initial = await env.backup.buildDataset(now: env.clock.now());
      final provider = ScriptedSyncProvider(
        initial: initial,
        conflictOnce: true,
      );
      final coordinator = SyncCoordinator(
        db: env.db,
        backup: env.backup,
        study: env.study,
        settings: env.settings,
        credentials: InMemoryCredentialStore(),
        clock: env.clock,
      );
      // The remote is identical, so the run is skipped before any upload; make
      // the local side differ so an upload is actually attempted.
      final book = await env.seedBook(name: 'second', words: <String>['beta']);
      expect(await env.books.wordCount(book.id), 1);

      final report = await coordinator.sync(provider);
      expect(report.ok, isTrue);
      expect(provider.uploadCalls, 2, reason: 'one conflict + one retry');
      expect(report.attempts, 2);
      await env.dispose();
    });
  });

  group('SYNC15 本地同步文件', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('materialword_sync');
    });

    tearDown(() {
      try {
        Process.runSync('chmod', <String>['755', dir.path]);
      } catch (_) {}
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('写入失败时旧文件仍然有效', () async {
      final String path = '${dir.path}/data.json';
      final provider = LocalFileSyncProvider(filePath: path);
      final TestEnv env = await TestEnv.create();
      await env.seedBook(words: <String>['alpha']);
      final first = await env.backup.buildDataset(now: env.clock.now());
      await provider.upload(first);
      final before = File(path).readAsStringSync();

      // Make the directory unwritable so the temp file cannot be created.
      final ProcessResult chmod = Process.runSync('chmod', <String>[
        '555',
        dir.path,
      ]);
      expect(chmod.exitCode, 0);

      final second = await env.backup.buildDataset(now: env.clock.now());
      var failed = false;
      try {
        await provider.upload(second, ifRevision: null);
      } on SyncException {
        failed = true;
      }
      // Running as root would bypass the permission bits; either way the file
      // must never be left truncated.
      if (failed) {
        expect(File(path).readAsStringSync(), before);
      }
      Process.runSync('chmod', <String>['755', dir.path]);
      await env.dispose();
    });

    test('内容哈希作为版本，且保留上一版本备份', () async {
      final String path = '${dir.path}/data.json';
      final provider = LocalFileSyncProvider(filePath: path);
      final TestEnv env = await TestEnv.create();
      await env.seedBook(words: <String>['alpha']);
      final first = await env.backup.buildDataset(now: env.clock.now());
      final result = await provider.upload(first);
      expect(result.revision, startsWith('v1:'));

      final payload = await provider.download();
      expect(payload, isNotNull);
      expect(payload!.revision, result.revision);

      await provider.upload(
        await env.backup.buildDataset(now: env.clock.now()),
        ifRevision: result.revision,
      );
      expect(File(provider.backupPath).existsSync(), isTrue);

      // A stale revision is rejected.
      expect(
        () => provider.upload(first, ifRevision: 'v1:stale'),
        throwsA(isA<SyncConflictException>()),
      );
      await env.dispose();
    });

    test('损坏的同步文件被识别', () async {
      final String path = '${dir.path}/broken.json';
      File(path).writeAsStringSync('{"broken":');
      final provider = LocalFileSyncProvider(filePath: path);
      expect(() => provider.download(), throwsA(isA<SyncDataException>()));
    });
  });
}
