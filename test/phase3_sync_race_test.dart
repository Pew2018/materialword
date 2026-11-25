import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/github_sync_provider.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/sync/webdav_sync_provider.dart';

import 'helpers/test_env.dart';

class _HookProvider extends ScriptedSyncProvider {
  _HookProvider({this.hook, this.target = 'target-a'});
  Future<void> Function()? hook;
  final String target;
  @override
  String get id => target;
  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async {
    final action = hook;
    hook = null;
    await action?.call();
    return super.upload(dataset, ifRevision: ifRevision);
  }
}

void main() {
  SyncCoordinator coordinator(TestEnv e) => SyncCoordinator(
    db: e.db,
    backup: e.backup,
    study: e.study,
    settings: e.settings,
    credentials: InMemoryCredentialStore(),
    clock: e.clock,
  );

  test('SYNC shared settings edited during upload stay pending then upload next time', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha']);
    final initial = await e.settings.load();
    final p = _HookProvider(hook: () => e.settings.save(dailyNewTarget: 87));
    final sync = coordinator(e);
    await sync.sync(p);
    expect(
      (p.lastUploaded!['settings'] as Map)['dailyNewTarget'],
      initial.dailyNewTarget,
    );
    expect((await e.settings.load()).dailyNewTarget, 87);
    final marker = jsonDecode(
      (await e.db.readMeta('sync_target:${SyncCoordinator.targetKey(p)}'))!,
    ) as Map;
    expect(
      marker['hash'],
      isNot(
        BackupService.contentHashOf(
          await e.backup.buildDataset(now: e.clock.now()),
        ),
      ),
    );
    await sync.sync(p);
    expect((p.lastUploaded!['settings'] as Map)['dailyNewTarget'], 87);
    expect((await e.settings.load()).dailyNewTarget, 87);
  });

  test(
    'SYNC old target completion cannot replace new configuration status',
    () async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha']);
      await e.settings.setSyncConfig({'provider': 'target-a'});
      final p = _HookProvider(
        hook: () async {
          await e.settings.setSyncConfig({'provider': 'target-b'});
          await e.settings.setLastSyncResult('new target has not synced');
        },
      );
      final sync = coordinator(e);
      final report = await sync.sync(p);
      expect(report.ok, isTrue);
      expect((await e.settings.syncConfig())!['provider'], 'target-b');
      expect(await e.settings.lastSyncResult(), 'new target has not synced');
      expect(await e.settings.lastSyncAt(), isNull);
      expect(await sync.hasSyncedTarget(p), isTrue);
      expect(
        await sync.hasSyncedTarget(_HookProvider(target: 'target-b')),
        isFalse,
      );
    },
  );

  test('SYNC GitHub credentials stay captured until run ends and next capture refreshes', () async {
    final store = InMemoryCredentialStore();
    await store.write(CredentialKeys.githubToken, 'old-test-token');
    final headers = <String?>[];
    final p = GitHubSyncProvider(
      owner: 'test-user',
      repo: 'data',
      credentials: store,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/data')) {
          return http.Response('{"private":true}', 200);
        }
        if (request.url.path.endsWith('/branches/main')) {
          return http.Response('{"name":"main","commit":{"sha":"head"}}', 200);
        }
        headers.add(request.headers['Authorization']);
        return http.Response('', 404);
      }),
    );
    await p.captureCredentials();
    await store.write(CredentialKeys.githubToken, 'new-test-token');
    await p.download();
    await p.download();
    expect(headers, ['Bearer old-test-token', 'Bearer old-test-token']);
    p.clearCapturedCredentials();
    await p.captureCredentials();
    await p.download();
    expect(headers.last, 'Bearer new-test-token');
    p.clearCapturedCredentials();
  });

  test('SYNC WebDAV credentials do not change halfway through a run', () async {
    final store = InMemoryCredentialStore();
    await store.write(CredentialKeys.webdavUsername, 'old-test-user');
    await store.write(CredentialKeys.webdavPassword, 'old-test-password');
    final headers = <String?>[];
    final p = WebDavSyncProvider(
      baseUrl: 'https://example.test',
      credentials: store,
      client: MockClient((request) async {
        headers.add(request.headers['Authorization']);
        return http.Response('', 404);
      }),
    );
    await p.captureCredentials();
    await store.write(CredentialKeys.webdavUsername, 'new-test-user');
    await store.write(CredentialKeys.webdavPassword, 'new-test-password');
    await p.download();
    await p.download();
    final old =
        'Basic ${base64Encode(utf8.encode('old-test-user:old-test-password'))}';
    expect(headers, [old, old]);
    p.clearCapturedCredentials();
    await p.captureCredentials();
    await p.download();
    expect(
      headers.last,
      'Basic ${base64Encode(utf8.encode('new-test-user:new-test-password'))}',
    );
    p.clearCapturedCredentials();
  });

  test(
    'SYNC a stamp without its field value is rejected before inserting rows',
    () async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha']);
      final data = await e.backup.buildDataset(now: e.clock.now());
      final row = (data['words'] as List).single as Map;
      row.remove('note');
      row['fieldVersions'] = {
        'note': {'version': 999, 'updatedAt': 0, 'deviceId': 'a'},
      };
      final target = await TestEnv.create();
      addTearDown(target.dispose);
      await expectLater(
        target.backup.mergeDataset(data, now: e.clock.now()),
        throwsA(isA<BackupException>()),
      );
      expect(await target.db.select(target.db.words).get(), isEmpty);
    },
  );
  test('SYNC credential batch and capture cannot mix account fields', () async {
    final store = InMemoryCredentialStore();
    await store.write(CredentialKeys.webdavUsername, 'old-user');
    await store.write(CredentialKeys.webdavPassword, 'old-pass');
    final entered = Completer<void>(), finish = Completer<void>();
    final write = CredentialStore.exclusive(() async {
      await store.write(CredentialKeys.webdavUsername, 'new-user');
      entered.complete();
      await finish.future;
      await store.write(CredentialKeys.webdavPassword, 'new-pass');
    });
    await entered.future;
    final auth = <String?>[];
    final p = WebDavSyncProvider(
      baseUrl: 'https://example.test',
      credentials: store,
      client: MockClient((request) async {
        auth.add(request.headers['Authorization']);
        return http.Response('', 404);
      }),
    );
    bool captured = false;
    final capture = p.captureCredentials().then((_) => captured = true);
    await Future<void>.delayed(Duration.zero);
    expect(captured, isFalse);
    finish.complete();
    await write;
    await capture;
    await p.download();
    expect(
      auth.single,
      'Basic ${base64Encode(utf8.encode('new-user:new-pass'))}',
    );
    p.clearCapturedCredentials();
  });

  test('SYNC credential epoch requires new manual confirmation for the same endpoint', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    final sync = coordinator(e);
    final a = GitHubSyncProvider(
      owner: 'test-user',
      repo: 'data',
      identityEpoch: 'old-epoch',
    );
    final b = GitHubSyncProvider(
      owner: 'test-user',
      repo: 'data',
      identityEpoch: 'new-epoch',
    );
    await e.db.writeMeta('sync_target:${SyncCoordinator.targetKey(a)}', '{}');
    expect(await sync.hasSyncedTarget(a), isTrue);
    expect(await sync.hasSyncedTarget(b), isFalse);
  });
}
