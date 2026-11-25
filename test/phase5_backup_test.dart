import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:materialword/core/errors/app_error.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/backup_manager.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/word_intake_service.dart';

import 'helpers/test_env.dart';

/// Phase 5E acceptance: BAK01–BAK20.
void main() {
  late TestEnv env;

  setUp(() async {
    env = await TestEnv.create();
  });

  tearDown(() async {
    await env.dispose();
  });

  Future<WordBook> seed() async {
    final WordBook book = await env.seedBook(
      words: <String>['alpha', 'beta', 'gamma'],
    );
    final Word alpha = (await env.words.byNormalized('alpha'))!;
    await env.study.recordAnswer(
      wordId: alpha.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'evt-1',
      deviceId: 'dev-a',
      now: env.clock.now(),
    );
    return book;
  }

  group('atomic writing', () {
    test('BAK01 恢复副本包含完整数据', () async {
      final WordBook book = await seed();
      final Word beta = (await env.words.byNormalized('beta'))!;
      await env.books.removeWord(book.id, beta.id, now: env.clock.now());
      await env.words.softDelete(beta.id, now: env.clock.now());

      final File file = await env.backups.createBackup();
      final BackupInfo info = await env.backups.inspect(file);
      expect(info.valid, isTrue);
      expect(info.words, 3);
      expect(info.books, 1);
      expect(info.entries, 3, reason: '删除标记也要保留');
      expect(info.events, 1);
      expect(info.schemaVersion, backupSchemaVersion);
      expect(info.hasDeviceSettings, isTrue);

      final Map<String, Object?> dataset = await env.backup.readDataset(
        file.path,
      );
      expect(dataset['kind'], backupKind);
      expect(dataset['favorites'], isNotNull);
      expect(dataset['tags'], isNotNull);
      expect(dataset['datasetId'], isNotNull);
      final Map<String, dynamic> betaRow = (dataset['words'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((Map<String, dynamic> row) => row['word'] == 'beta');
      expect(betaRow['deletedAt'], isNotNull);
      expect(betaRow['fieldVersions'], isNotNull);
    });

    test('BAK02 写入后没有残留临时文件且名称唯一', () async {
      await seed();
      final File first = await env.backups.createBackup();
      final File second = await env.backups.createBackup();
      expect(first.path, isNot(second.path));
      expect(first.existsSync(), isTrue);
      final List<String> temps = env.backupDirectory
          .listSync()
          .map((FileSystemEntity e) => e.uri.pathSegments.last)
          .where((String name) => name.endsWith('.tmp'))
          .toList();
      expect(temps, isEmpty);
      expect(
        BackupService.cleanupTempFiles(env.backupDirectory),
        0,
        reason: '没有可清理的残留',
      );
    });

    test('BAK03 写入失败时不会破坏已有备份', () async {
      await seed();
      final File good = await env.backups.createBackup();
      final int sizeBefore = good.lengthSync();

      // Make the directory read-only: the new write must fail cleanly.
      final ProcessResult chmod = Process.runSync('chmod', <String>[
        '500',
        env.backupDirectory.path,
      ]);
      expect(chmod.exitCode, 0);
      try {
        await expectLater(
          env.backups.createBackup(),
          throwsA(isA<BackupException>()),
        );
      } finally {
        Process.runSync('chmod', <String>['700', env.backupDirectory.path]);
      }
      expect(good.existsSync(), isTrue);
      expect(good.lengthSync(), sizeBefore);
      final BackupInfo info = await env.backups.inspect(good);
      expect(info.valid, isTrue);
      final List<String> temps = env.backupDirectory
          .listSync()
          .map((FileSystemEntity e) => e.uri.pathSegments.last)
          .where((String name) => name.endsWith('.tmp'))
          .toList();
      expect(temps, isEmpty, reason: '失败后必须清理临时文件');
    });

    test('BAK04 同一秒内多次备份不会互相覆盖', () async {
      await seed();
      final Set<String> names = <String>{};
      for (int i = 0; i < 5; i++) {
        final File file = await env.backups.createBackup();
        names.add(file.uri.pathSegments.last);
      }
      expect(names, hasLength(5));
      expect(env.backupDirectory.listSync().whereType<File>(), hasLength(5));
    });

    test('BAK05 损坏的副本被拒绝读取', () async {
      final File broken = File('${env.backupDirectory.path}/broken.json');
      await broken.writeAsString('{"kind":"materialword-backup"');
      final BackupInfo info = await env.backups.inspect(broken);
      expect(info.valid, isFalse);
      expect(info.problem, isNotNull);
      await expectLater(
        env.backups.restoreMerge(broken),
        throwsA(isA<BackupException>()),
      );
      await expectLater(
        env.backups.restoreSnapshot(broken),
        throwsA(isA<BackupException>()),
      );
      expect(await env.words.countWords(), 0);
    });

    test('BAK06 备份不包含同步凭据', () async {
      final InMemoryCredentialStore store = InMemoryCredentialStore();
      await store.write(CredentialKeys.githubToken, 'ghp_super_secret_token');
      await store.write(CredentialKeys.webdavPassword, 'webdav-secret');
      await seed();
      final File file = await env.backups.createBackup();
      final String raw = await file.readAsString();
      expect(raw, isNot(contains('ghp_super_secret_token')));
      expect(raw, isNot(contains('webdav-secret')));
      expect(raw.toLowerCase(), isNot(contains('"token"')));
      expect(raw.toLowerCase(), isNot(contains('"password"')));
    });
  });

  group('automatic backups', () {
    test('BAK07 到期后创建，且没有变化时不重复创建', () async {
      await seed();
      final AutoBackupResult first = await env.backups.autoBackupIfDue();
      expect(first.created, isTrue);
      expect(await env.settings.lastAutoBackupAt(), isNotNull);

      final AutoBackupResult immediate = await env.backups.autoBackupIfDue();
      expect(immediate.created, isFalse);

      env.clock.advance(const Duration(hours: 25));
      final AutoBackupResult unchanged = await env.backups.autoBackupIfDue();
      expect(unchanged.created, isFalse, reason: '数据没变就不创建新副本');
      expect(unchanged.skippedReason, contains('没有变化'));
      expect(await env.backups.list(), hasLength(1));

      env.clock.advance(const Duration(hours: 25));
      await env.intake.add(
        const WordIntakeRequest(text: 'delta'),
        now: env.clock.now(),
      );
      final AutoBackupResult changed = await env.backups.autoBackupIfDue();
      expect(changed.created, isTrue);
      expect(await env.backups.list(), hasLength(2));
    });

    test('BAK08 自动备份保留最近 5 份', () async {
      await env.settings.setAutoBackupRetention(5);
      for (int i = 0; i < 8; i++) {
        env.clock.advance(const Duration(hours: 25));
        await env.intake.add(
          WordIntakeRequest(text: 'word${String.fromCharCode(97 + i)}'),
          now: env.clock.now(),
        );
        await env.backups.autoBackupIfDue();
      }
      final List<BackupEntry> automatic = (await env.backups.list())
          .where((BackupEntry entry) => entry.kind == BackupKind.automatic)
          .toList();
      expect(automatic, hasLength(5));
    });

    test('BAK09 自动备份失败不更新时间戳也不删除旧备份', () async {
      await seed();
      final File first = await env.backups.createBackup(
        kind: BackupKind.automatic,
      );
      env.clock.advance(const Duration(hours: 25));
      await env.intake.add(
        const WordIntakeRequest(text: 'delta'),
        now: env.clock.now(),
      );
      final DateTime? before = await env.settings.lastAutoBackupAt();

      Process.runSync('chmod', <String>['500', env.backupDirectory.path]);
      try {
        final AutoBackupResult failed = await env.backups.autoBackupIfDue();
        expect(failed.created, isFalse);
        expect(failed.error, isNotNull);
      } finally {
        Process.runSync('chmod', <String>['700', env.backupDirectory.path]);
      }
      expect(await env.settings.lastAutoBackupAt(), before);
      expect(first.existsSync(), isTrue);
    });

    test('BAK10 只在开启时自动备份', () async {
      await seed();
      await env.settings.setAutoBackupEnabled(false);
      final AutoBackupResult result = await env.backups.autoBackupIfDue();
      expect(result.created, isFalse);
      expect(result.skippedReason, contains('关闭'));
      expect(await env.backups.list(), isEmpty);
    });
  });

  group('protective copies', () {
    test('BAK11 高风险操作前创建保护性备份', () async {
      await seed();
      final File file = await env.backups.createProtectiveBackup(
        reason: '批量删除词条',
      );
      final BackupInfo info = await env.backups.inspect(file);
      expect(info.valid, isTrue);
      final List<BackupEntry> entries = await env.backups.list();
      expect(entries.single.kind, BackupKind.protective);
      expect(entries.single.name, contains('protective'));
    });

    test('BAK12 保护性备份失败时阻止操作', () async {
      await seed();
      Process.runSync('chmod', <String>['500', env.backupDirectory.path]);
      AppErrorCode? failure;
      try {
        failure = await env.backups.protectiveBackupFailure(
          'delete-words-batch',
        );
      } finally {
        Process.runSync('chmod', <String>['700', env.backupDirectory.path]);
      }
      // A stable code, not a sentence: the page localises it.
      expect(failure, AppErrorCode.protectiveBackupFailed);
      // The caller would abort here; the data is untouched.
      expect(await env.words.countWords(), 3);
    });

    test('BAK13 保护性备份有独立且有限的保留策略', () async {
      await seed();
      for (int i = 0; i < 6; i++) {
        env.clock.advance(const Duration(seconds: 1));
        await env.backups.createProtectiveBackup(reason: 'op $i');
      }
      final List<BackupEntry> protective = (await env.backups.list())
          .where((BackupEntry entry) => entry.kind == BackupKind.protective)
          .toList();
      expect(protective, hasLength(BackupManager.protectiveRetention));
    });
  });

  group('restore', () {
    test('BAK14 内部副本可以直接合并恢复', () async {
      await seed();
      final File copy = await env.backups.createBackup();
      await env.intake.add(
        const WordIntakeRequest(text: 'delta'),
        now: env.clock.now(),
      );
      await env.intake.add(
        const WordIntakeRequest(text: 'epsilon'),
        now: env.clock.now(),
      );
      expect(await env.words.countWords(), 5);

      final MergeReport report = await env.backups.restoreMerge(copy);
      expect(report.addedEvents, 0);
      expect(await env.words.countWords(), 5, reason: '合并恢复不删除本机词条');
      expect(await env.words.byNormalized('delta'), isNotNull);
    });

    test('BAK15 指定版本恢复替换本机数据并保留保护性备份', () async {
      final WordBook book = await seed();
      final File copy = await env.backups.createBackup();
      env.clock.advance(const Duration(days: 1));
      await env.intake.add(
        const WordIntakeRequest(text: 'delta'),
        bookId: book.id,
        now: env.clock.now(),
      );
      expect(await env.words.countWords(), 4);

      final RestoreOutcome outcome = await env.backups.restoreSnapshot(copy);
      expect(outcome.clearedWords, 4);
      expect(outcome.syncPaused, isTrue);
      expect(outcome.protectiveBackup.existsSync(), isTrue);
      expect(await env.words.countWords(), 3);
      expect(await env.words.byNormalized('delta'), isNull);
      expect(
        await env.words.eventsForWord(
          (await env.words.byNormalized('alpha'))!.id,
        ),
        hasLength(1),
      );
      final BackupInfo protective = await env.backups.inspect(
        outcome.protectiveBackup,
      );
      expect(protective.valid, isTrue);
      expect(protective.words, 4);
    });

    test('BAK16 恢复中断后整体回滚', () async {
      final WordBook book = await seed();
      final File copy = await env.backups.createBackup();
      env.clock.advance(const Duration(days: 1));
      await env.intake.add(
        const WordIntakeRequest(text: 'delta'),
        bookId: book.id,
        now: env.clock.now(),
      );

      await expectLater(
        env.backups.restoreSnapshot(
          copy,
          afterClear: () async => throw StateError('simulated crash'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await env.words.countWords(), 4, reason: '清除后崩溃必须回滚');
      expect(await env.words.byNormalized('delta'), isNotNull);
      final WordBook? reloaded = await env.books.byId(book.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.deletedAt, isNull);
      expect(await env.settings.syncPaused(), isFalse);
    });

    test('BAK17 恢复后同步保持暂停且不会自动上传', () async {
      await seed();
      final File copy = await env.backups.createBackup();
      await env.backups.restoreSnapshot(copy);
      expect(await env.settings.syncPaused(), isTrue);

      final ScriptedSyncProvider remote = ScriptedSyncProvider(
        initial: await env.backup.buildDataset(now: env.clock.now()),
      );
      final SyncCoordinator coordinator = SyncCoordinator(
        db: env.db,
        backup: env.backup,
        study: env.study,
        settings: env.settings,
        credentials: InMemoryCredentialStore(),
        clock: env.clock,
      );
      await expectLater(
        coordinator.sync(remote),
        throwsA(
          isA<SyncException>().having(
            (SyncException e) => e.message,
            'message',
            contains('已暂停'),
          ),
        ),
      );
      expect(remote.uploadCalls, 0);
      expect(remote.downloadCalls, 0);
      // Automatic sync is a no-op while paused.
      expect(await coordinator.autoSync(trigger: 'start'), isNull);
    });

    test('BAK18 恢复会清理活动会话与同步记账', () async {
      await seed();
      final File copy = await env.backups.createBackup();
      await env.db.writeMeta('active_study_session_v1', '{"version":1}');
      await env.db.writeMeta('active_practice_session_v1', '{"version":1}');
      await env.db.writeMeta('sync_target:abc', '{"hash":"x"}');
      await env.db.writeMeta('last_sync_local_hash', 'sha256:x');

      await env.backups.restoreSnapshot(copy);
      expect(await env.db.readMeta('active_study_session_v1'), isNull);
      expect(await env.db.readMeta('active_practice_session_v1'), isNull);
      expect(await env.db.readMeta('sync_target:abc'), isNull);
      expect(await env.db.readMeta('last_sync_local_hash'), isNull);
    });

    test('BAK19 设备设置只在备份中迁移，不进入共享同步', () async {
      await env.settings.save(
        theme: ThemePreference.dark,
        accentColor: '#FF0000',
      );
      final Map<String, Object?> syncPayload = await env.backup.buildDataset(
        now: env.clock.now(),
      );
      expect(syncPayload['schemaVersion'], syncSchemaVersion);
      expect(syncPayload.containsKey('deviceSettings'), isFalse);

      final Map<String, Object?> backup = await env.backup.buildDataset(
        now: env.clock.now(),
        includeDeviceSettings: true,
      );
      expect(backup['schemaVersion'], backupSchemaVersion);
      expect(backup['deviceSettings'], isA<Map<String, Object?>>());

      // Merging a backup into another device must not change its theme.
      final TestEnv other = await TestEnv.create();
      addTearDown(other.dispose);
      await other.settings.save(theme: ThemePreference.light);
      await other.backup.mergeDataset(backup, now: other.clock.now());
      expect(
        (await other.settings.load()).themeMode,
        ThemePreference.light.code,
      );
    });

    test('BAK20 v1 / v2 / v3 历史备份仍然可以导入', () async {
      // v1: no entries tombstones, no favourites/tags.
      final Map<String, Object?> v1 = <String, Object?>{
        'schemaVersion': 1,
        'words': <Object?>[
          <String, Object?>{
            'id': 'w1',
            'word': 'legacyone',
            'normalized': 'legacyone',
            'translation': '旧版',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'updatedAt': '2024-01-01T00:00:00.000Z',
          },
        ],
        'wordBooks': <Object?>[
          <String, Object?>{
            'id': 'b1',
            'name': '旧词书',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'updatedAt': '2024-01-01T00:00:00.000Z',
          },
        ],
        'entries': <Object?>[
          <String, Object?>{
            'wordBookId': 'b1',
            'wordId': 'w1',
            'addedAt': '2024-01-01T00:00:00.000Z',
          },
        ],
        'reviewEvents': <Object?>[],
      };
      final MergeReport first = await env.backup.mergeDataset(
        v1,
        now: env.clock.now(),
      );
      expect(first.newWords, 1);
      expect(await env.words.byNormalized('legacyone'), isNotNull);
      expect(await env.books.wordCount('b1'), 1);

      for (final int version in <int>[2, 3]) {
        final Map<String, Object?> older = <String, Object?>{
          'schemaVersion': version,
          'kind': backupKind,
          'words': <Object?>[
            <String, Object?>{
              'id': 'w$version',
              'word': 'version$version',
              'normalized': 'version$version',
              'translation': 'v$version',
              'revision': 1,
              'createdAt': '2024-02-01T00:00:00.000Z',
              'updatedAt': '2024-02-01T00:00:00.000Z',
              'deletedAt': null,
            },
          ],
          'wordBooks': <Object?>[],
          'entries': <Object?>[],
          'reviewEvents': <Object?>[],
        };
        await env.backup.mergeDataset(older, now: env.clock.now());
        expect(await env.words.byNormalized('version$version'), isNotNull);
      }

      // A future version is refused instead of guessed at.
      await expectLater(
        env.backup.mergeDataset(<String, Object?>{
          'schemaVersion': backupSchemaVersion + 1,
          'words': <Object?>[],
        }, now: env.clock.now()),
        throwsA(isA<BackupException>()),
      );
    });
  });

  test('BAK21 备份列表按类型分组且可删除', () async {
    await seed();
    await env.backups.createBackup(kind: BackupKind.manual);
    await env.backups.createBackup(kind: BackupKind.protective);
    await env.backups.createBackup(kind: BackupKind.automatic);
    final List<BackupEntry> entries = await env.backups.list();
    expect(entries.map((BackupEntry e) => e.kind).toSet(), <BackupKind>{
      BackupKind.manual,
      BackupKind.protective,
      BackupKind.automatic,
    });
    await env.backups.delete(entries.first.file);
    expect(await env.backups.list(), hasLength(2));
  });
}
