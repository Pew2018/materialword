import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_coordinator.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_provider.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_repository.dart';

import 'helpers/test_env.dart';

class History implements CloudBackupProvider {
  History(this.config, this.content);
  final CloudBackupConfig config;
  final List<int> content;
  final files = <String, List<int>>{};
  final denied = <String>{};
  bool failListing = false;
  bool repeatToken = false;
  bool failUpload = false;
  bool loseDeleteResponse = false;
  int pages = 0;
  void Function()? afterDelete;
  String name(int n) =>
      'materialword-backup-20261126T120000000Z-00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}.json';
  void seed(int n) {
    for (var i = 0; i < n; i++) {
      files[name(i)] = content;
    }
  }

  CloudBackupEntry entry(String name) => CloudBackupEntry(
    providerId: config.providerId,
    objectName: name,
    targetFingerprint: config.fingerprint,
    createdAt: name.startsWith('materialword-backup-20261127')
        ? DateTime.utc(2026, 11, 27)
        : DateTime.utc(2026, 11, 26, 12),
    byteLength: files[name]?.length,
  );
  @override
  Future<CloudBackupPage> listBackups({String? continuationToken}) async {
    pages++;
    if (failListing) throw const CloudBackupException('connection failed');
    final all = files.keys.where(cloudBackupName.hasMatch).toList()..sort();
    final start = int.parse(continuationToken ?? '0');
    final end = (start + 2).clamp(0, all.length);
    return CloudBackupPage(
      all.sublist(start, end).map(entry).toList(),
      continuationToken: repeatToken ? '0' : (end < all.length ? '$end' : null),
    );
  }

  @override
  Future<void> deleteBackup(String name) async {
    if (denied.contains(name)) {
      throw const CloudBackupException('permission denied', status: 403);
    }
    files.remove(name);
    afterDelete?.call();
    if (loseDeleteResponse) throw const CloudBackupException('outcome unknown');
  }

  @override
  Future<List<int>> downloadBackup(String name) async => files[name]!;
  @override
  Future<CloudBackupObjectState> inspectObject(String name) async =>
      files.containsKey(name)
      ? CloudBackupObjectState.exists
      : CloudBackupObjectState.missing;
  @override
  Future<void> uploadBackup(String name, List<int> bytes) async {
    files[name] = failUpload ? [0] : bytes;
    if (failUpload) throw const CloudBackupException('outcome unknown');
  }

  @override
  Future<void> ensureDirectory() async {}
  @override
  Future<void> deleteProbe(String name) async {}
  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final id in ['s3', 'webdav']) {
    test(
      '$id full pagination, stable ties, retain two, explicit newest deletion',
      () async {
        final env = await TestEnv.create();
        addTearDown(env.dispose);
        final repo = CloudBackupRepository(env.settings, env.credentials);
        final config = await repo.save(
          CloudBackupConfig(
            providerId: id,
            endpoint: 'https://example.test',
            directory: 'backups/',
            region: id == 's3' ? 'us-east-1' : '',
            bucket: id == 's3' ? 'test-bucket' : '',
            credentialEpoch: '',
          ),
          firstSecret: 'x',
          secondSecret: 'y',
        );
        final history = History(
          config,
          utf8.encode(await env.backup.exportToJson(now: env.clock.now())),
        )..seed(7);
        history.files['sync.json'] = [1];
        history.files['unrelated.json'] = [2];
        final coordinator = CloudBackupCoordinator(
          repository: repo,
          backup: env.backup,
          clock: env.clock,
          factory: (_, _, _) => history,
        );
        final plan = await coordinator.prepareCleanup(id);
        expect(history.pages, 4);
        expect(plan.keep.map((e) => e.objectName), [
          history.name(6),
          history.name(5),
        ]);
        expect(plan.remove, hasLength(5));
        expect((await coordinator.executeCleanup(plan)).removed, hasLength(5));
        expect(
          history.files.keys,
          containsAll([
            history.name(6),
            history.name(5),
            'sync.json',
            'unrelated.json',
          ]),
        );
        expect(
          (await coordinator.deleteOne(history.entry(history.name(6))))
              .complete,
          isTrue,
        );
        final nothing = await coordinator.prepareCleanup(id);
        expect(nothing.remove, isEmpty);
        expect((await coordinator.executeCleanup(nothing)).removed, isEmpty);
      },
    );
  }

  test('partial permission failures, response loss, uncertain verification and retry', () async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    final repo = CloudBackupRepository(env.settings, env.credentials);
    final config = await repo.save(
      const CloudBackupConfig(
        providerId: 's3',
        endpoint: 'https://example.test',
        directory: 'backups/',
        region: 'us-east-1',
        bucket: 'test-bucket',
        credentialEpoch: '',
      ),
      firstSecret: 'x',
      secondSecret: 'y',
    );
    final history = History(
      config,
      utf8.encode(await env.backup.exportToJson(now: env.clock.now())),
    )..seed(5);
    final c = CloudBackupCoordinator(
      repository: repo,
      backup: env.backup,
      clock: env.clock,
      factory: (_, _, _) => history,
    );
    history.denied.add(history.name(1));
    var result = await c.executeCleanup(await c.prepareCleanup('s3'));
    expect(result.removed, hasLength(2));
    expect(result.failed.keys, [history.name(1)]);
    expect(c.progress.stage, CloudBackupStage.partial);
    history.denied.clear();
    history.loseDeleteResponse = true;
    result = await c.deleteOne(history.entry(history.name(1)));
    expect(result.removed, [history.name(1)]);
    history.afterDelete = () => history.failListing = true;
    result = await c.deleteOne(history.entry(history.name(4)));
    expect(result.unknown, [history.name(4)]);
    expect(c.progress.stage, CloudBackupStage.outcomeUnknown);
  });

  test('stale target/list, bad newest upload, repeated pagination stop all deletion', () async {
    final env = await TestEnv.create(now: DateTime.utc(2026, 11, 27));
    addTearDown(env.dispose);
    final repo = CloudBackupRepository(env.settings, env.credentials);
    final config = await repo.save(
      const CloudBackupConfig(
        providerId: 's3',
        endpoint: 'https://example.test',
        directory: 'backups/',
        region: 'us-east-1',
        bucket: 'test-bucket',
        credentialEpoch: '',
      ),
      firstSecret: 'x',
      secondSecret: 'y',
    );
    final h = History(
      config,
      utf8.encode(await env.backup.exportToJson(now: env.clock.now())),
    )..seed(4);
    final c = CloudBackupCoordinator(
      repository: repo,
      backup: env.backup,
      clock: env.clock,
      factory: (_, _, _) => h,
    );
    final plan = await c.prepareCleanup('s3');
    h.files[h.name(99)] = h.content;
    await expectLater(
      c.executeCleanup(plan),
      throwsA(isA<CloudBackupException>()),
    );
    h.files.remove(h.name(99));
    h.repeatToken = true;
    await expectLater(
      c.prepareCleanup('s3'),
      throwsA(isA<CloudBackupException>()),
    );
    h.repeatToken = false;
    h.failUpload = true;
    await expectLater(c.upload('s3'), throwsA(isA<CloudBackupException>()));
    await expectLater(c.prepareCleanup('s3'), throwsA(anything));
    expect(
      h.files.keys,
      containsAll([h.name(0), h.name(1), h.name(2), h.name(3)]),
    );
    await repo.remove('s3');
    await expectLater(
      c.deleteOne(h.entry(h.name(0))),
      throwsA(isA<CloudBackupException>()),
    );
  });

  test('providers issue scoped DELETE with no S3 versionId and reject unrelated paths', () async {
    for (final id in ['s3', 'webdav']) {
      final config = CloudBackupConfig(
        providerId: id,
        endpoint: 'https://example.test',
        directory: 'backups/',
        region: 'us-east-1',
        bucket: 'test-bucket',
        credentialEpoch: 'epoch',
      );
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      });
      final CloudBackupProvider provider = id == 's3'
          ? S3BackupProvider(config, 'x', 'y', client: client)
          : WebDavBackupProvider(config, 'x', 'y', client: client);
      await provider.deleteBackup(
        'materialword-backup-20261126T120000000Z-00000000-0000-4000-8000-000000000000.json',
      );
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.queryParameters, isNot(contains('versionId')));
      expect(
        requests.single.url.path,
        contains('/backups/materialword-backup-'),
      );
      await expectLater(
        provider.deleteBackup('../sync.json'),
        throwsA(isA<CloudBackupException>()),
      );
      expect(requests, hasLength(1));
      client.close();
    }
  });

  test('WebDAV declared list truncation fails closed', () async {
    final client = MockClient(
      (_) async => http.Response(
        '<d:multistatus xmlns:d="DAV:"><d:response><d:status>HTTP/1.1 507 Insufficient Storage</d:status></d:response></d:multistatus>',
        207,
      ),
    );
    final p = WebDavBackupProvider(
      const CloudBackupConfig(
        providerId: 'webdav',
        endpoint: 'https://example.test',
        directory: 'backups',
        credentialEpoch: 'epoch',
      ),
      'x',
      'y',
      client: client,
    );
    await expectLater(p.listBackups(), throwsA(isA<CloudBackupException>()));
    client.close();
  });
}
