import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_coordinator.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_provider.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_repository.dart';

import 'helpers/test_env.dart';
import 'helpers/cloud_backup_history.dart';

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
        final history = TestBackupHistory(
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
    final history = TestBackupHistory(
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
    history.afterDelete = () async {
      history.failListing = true;
    };
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
    final h = TestBackupHistory(
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

  test('upload/delete mutual exclusion and target change during delete are explicit', () async {
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
    final history = TestBackupHistory(
      config,
      utf8.encode(await env.backup.exportToJson(now: env.clock.now())),
    )..seed(3);
    final c = CloudBackupCoordinator(
      repository: repo,
      backup: env.backup,
      clock: env.clock,
      factory: (_, _, _) => history,
    );
    final entered = Completer<void>();
    final resume = Completer<void>();
    history.afterDelete = () async {
      entered.complete();
      await resume.future;
    };
    final deletion = c.deleteOne(history.entry(history.name(0)));
    await entered.future;
    await expectLater(c.upload('s3'), throwsA(isA<CloudBackupException>()));
    await repo.remove('s3');
    resume.complete();
    final result = await deletion;
    expect(result.targetChanged, isTrue);
    expect(result.unknown, [history.name(0)]);
    expect(history.files.keys, containsAll([history.name(1), history.name(2)]));
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
