import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_coordinator.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_provider.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_repository.dart';
import 'package:materialword/services/sync/aws_signature_v4.dart';
import 'package:materialword/services/sync/credential_store.dart';

import 'helpers/s3_server.dart';
import 'helpers/test_env.dart';
import 'helpers/webdav_mock_client.dart';

class _FailingStore extends InMemoryCredentialStore {
  _FailingStore(super.initial);
  int writes = 0;
  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (writes == 2) throw const CredentialStoreUnavailable('test failure');
    await super.write(key, value);
  }
}

void main() {
  test('configs and credentials are independent of sync settings', () async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    final repo = CloudBackupRepository(env.settings, env.credentials);
    await env.settings.setSyncConfig(<String, Object?>{'provider': 'github'});
    final s3 = await repo.save(
      CloudBackupConfig(
        providerId: 's3',
        endpoint: 'https://s3.test',
        directory: 'materialword-backups/',
        region: 'us-east-1',
        bucket: 'test-bucket',
        credentialEpoch: '',
      ),
      firstSecret: 'key',
      secondSecret: 'secret',
    );
    final dav = await repo.save(
      CloudBackupConfig(
        providerId: 'webdav',
        endpoint: 'https://dav.test/dav/',
        directory: 'materialword-backups',
        credentialEpoch: '',
      ),
      firstSecret: 'user',
      secondSecret: 'password',
    );
    expect(await repo.configured(), hasLength(2));
    expect(await repo.readSecrets(s3), ('key', 'secret'));
    expect(await repo.readSecrets(dav), ('user', 'password'));
    expect((await env.settings.syncConfig())?['provider'], 'github');
    await repo.remove('s3');
    expect(await repo.readSecrets(dav), ('user', 'password'));
  });

  test('failed keychain write preserves the active backup config', () async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    final originalRepo = CloudBackupRepository(env.settings, env.credentials);
    final active = await originalRepo.save(
      const CloudBackupConfig(
        providerId: 'webdav',
        endpoint: 'https://dav.test/dav/',
        directory: 'materialword-backups',
        credentialEpoch: '',
      ),
      firstSecret: 'old-user',
      secondSecret: 'old-password',
    );
    final failing = _FailingStore(env.credentials.snapshot);
    final repo = CloudBackupRepository(env.settings, failing);
    await expectLater(
      repo.save(
        const CloudBackupConfig(
          providerId: 'webdav',
          endpoint: 'https://dav.test/new/',
          directory: 'materialword-backups',
          credentialEpoch: '',
        ),
        firstSecret: 'new-user',
        secondSecret: 'new-password',
      ),
      throwsA(isA<CredentialStoreUnavailable>()),
    );
    expect((await repo.load('webdav'))?.fingerprint, active.fingerprint);
    expect(await repo.readSecrets(active), ('old-user', 'old-password'));
  });

  test('S3 backup works when conditional writes are ignored', () async {
    final server = await S3Server.start(
      options: const S3Options(obeysIfNoneMatch: false),
    );
    addTearDown(server.close);
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    final repo = CloudBackupRepository(env.settings, env.credentials);
    await repo.save(
      CloudBackupConfig(
        providerId: 's3',
        endpoint: server.endpoint,
        directory: 'materialword-backups/',
        region: 'us-east-1',
        bucket: server.bucket,
        credentialEpoch: '',
      ),
      firstSecret: server.options.accessKeyId,
      secondSecret: server.options.secretAccessKey,
    );
    final coordinator = CloudBackupCoordinator(
      repository: repo,
      backup: env.backup,
      clock: env.clock,
      client: server.client,
    );
    final first = await coordinator.upload('s3');
    final second = await coordinator.upload('s3');
    expect(first.objectName, isNot(second.objectName));
    expect(
      server.bodyOf('materialword-backups/${first.objectName}'),
      isNotNull,
    );
    expect(
      server.bodyOf('materialword-backups/${second.objectName}'),
      isNotNull,
    );
    expect(
      server.traffic
          .where(
            (line) =>
                line.startsWith('GET /${server.bucket}/materialword-backups/'),
          )
          .length,
      greaterThanOrEqualTo(4),
    );
    final listed = await coordinator.list('s3');
    expect(
      listed.entries.map((e) => e.objectName),
      containsAll([first.objectName, second.objectName]),
    );
    final downloaded = await coordinator.download(listed.entries.first);
    expect(downloaded.dataset['schemaVersion'], isNotNull);
    expect(await env.settings.lastSyncAt(), isNull);
    expect(await env.settings.lastSyncResult(), isNull);
  });

  test('WebDAV backup works without ETags', () async {
    final mock = WebDavMock(etagMode: 'none', obeysConditions: false);
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    final repo = CloudBackupRepository(env.settings, env.credentials);
    await repo.save(
      const CloudBackupConfig(
        providerId: 'webdav',
        endpoint: 'https://dav.test/dav/',
        directory: 'materialword-backups',
        credentialEpoch: '',
      ),
      firstSecret: 'user',
      secondSecret: 'password',
    );
    final coordinator = CloudBackupCoordinator(
      repository: repo,
      backup: env.backup,
      clock: env.clock,
      client: mock.client,
    );
    final receipt = await coordinator.upload('webdav');
    final listed = await coordinator.list('webdav');
    expect(
      listed.entries.map((e) => e.objectName),
      contains(receipt.objectName),
    );
    final download = await coordinator.download(listed.entries.single);
    expect(download.bytes, isNotEmpty);
    expect(
      mock.traffic.where((line) => line.startsWith('GET ')).length,
      greaterThanOrEqualTo(3),
    );
  });

  test('S3 history uses signed pagination and excludes unrelated keys', () async {
    final server = await S3Server.start();
    addTearDown(server.close);
    final config = CloudBackupConfig(
      providerId: 's3',
      endpoint: server.endpoint,
      directory: 'materialword-backups/',
      region: 'us-east-1',
      bucket: server.bucket,
      credentialEpoch: 'epoch',
    );
    for (var i = 0; i < 1001; i++) {
      final name =
          'materialword-backup-20261126T023100123Z-'
          '${i.toRadixString(16).padLeft(8, '0')}-0000-4000-8000-000000000000.json';
      server.seed('materialword-backups/$name', [1]);
    }
    server.seed('materialword-backups/unrelated.json', [2]);
    final provider = S3BackupProvider(
      config,
      server.options.accessKeyId,
      server.options.secretAccessKey,
      client: server.client,
    );
    final first = await provider.listBackups();
    expect(first.entries, hasLength(1000));
    expect(first.continuationToken, isNotNull);
    final second = await provider.listBackups(
      continuationToken: first.continuationToken,
    );
    expect(second.entries, hasLength(1));
    expect(second.continuationToken, isNull);
    // The mock authenticates the actual URI. It need not understand this
    // opaque token to prove its signature survives the wire encoding.
    await provider.listBackups(continuationToken: 'A+B/中%');
    expect(server.rejected, isEmpty);
  });

  test('readback mismatch cannot create a success receipt', () async {
    final server = await S3Server.start();
    addTearDown(server.close);
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    final repo = CloudBackupRepository(env.settings, env.credentials);
    final config = await repo.save(
      CloudBackupConfig(
        providerId: 's3',
        endpoint: server.endpoint,
        directory: 'materialword-backups/',
        region: 'us-east-1',
        bucket: server.bucket,
        credentialEpoch: '',
      ),
      firstSecret: server.options.accessKeyId,
      secondSecret: server.options.secretAccessKey,
    );
    server.corruptNextExistingRead = true;
    final coordinator = CloudBackupCoordinator(
      repository: repo,
      backup: env.backup,
      clock: env.clock,
      client: server.client,
    );
    await expectLater(
      coordinator.upload('s3'),
      throwsA(isA<CloudBackupException>()),
    );
    expect(await repo.lastSuccess(config), isNull);
  });

  test('lost S3 PUT response is recovered by GET of the same object', () async {
    final server = await S3Server.start();
    addTearDown(server.close);
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    final repo = CloudBackupRepository(env.settings, env.credentials);
    await repo.save(
      CloudBackupConfig(
        providerId: 's3',
        endpoint: server.endpoint,
        directory: 'materialword-backups/',
        region: 'us-east-1',
        bucket: server.bucket,
        credentialEpoch: '',
      ),
      firstSecret: server.options.accessKeyId,
      secondSecret: server.options.secretAccessKey,
    );
    server.loseNextUploadResponse = true;
    final coordinator = CloudBackupCoordinator(
      repository: repo,
      backup: env.backup,
      clock: env.clock,
      client: server.client,
    );
    final receipt = await coordinator.upload('s3');
    expect(
      server.bodyOf('materialword-backups/${receipt.objectName}'),
      isNotNull,
    );
    expect(
      server.traffic.where(
        (line) => line.contains("committed_without_response"),
      ),
      hasLength(1),
    );
  });

  test('WebDAV history rejects external and escaping hrefs', () async {
    const name =
        'materialword-backup-20261126T023100123Z-'
        '00000000-0000-4000-8000-000000000000.json';
    final config = CloudBackupConfig(
      providerId: 'webdav',
      endpoint: 'https://dav.test/dav/',
      directory: 'materialword-backups',
      credentialEpoch: 'epoch',
    );
    String response(String href) =>
        '<d:response><d:href>$href</d:href>'
        '<d:propstat><d:prop><d:getcontentlength>42</d:getcontentlength>'
        '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>'
        '</d:response>';
    final xml =
        '<d:multistatus xmlns:d="DAV:">'
        '${response('/dav/materialword-backups/$name')}'
        '${response('https://evil.test/dav/materialword-backups/$name')}'
        '${response('/dav/other/$name')}'
        '${response('/dav/materialword-backups/%2e%2e/$name')}'
        '</d:multistatus>';
    final provider = WebDavBackupProvider(
      config,
      'user',
      'password',
      client: MockClient((request) async => http.Response(xml, 207)),
    );
    final page = await provider.listBackups();
    expect(page.entries.map((e) => e.objectName), [name]);
  });

  test('unknown object state never triggers a write', () async {
    final server = await S3Server.start(
      options: const S3Options(hideMissingAsForbidden: true),
    );
    addTearDown(server.close);
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    final repo = CloudBackupRepository(env.settings, env.credentials);
    await repo.save(
      CloudBackupConfig(
        providerId: 's3',
        endpoint: server.endpoint,
        directory: 'materialword-backups/',
        region: 'us-east-1',
        bucket: server.bucket,
        credentialEpoch: '',
      ),
      firstSecret: server.options.accessKeyId,
      secondSecret: server.options.secretAccessKey,
    );
    final coordinator = CloudBackupCoordinator(
      repository: repo,
      backup: env.backup,
      clock: env.clock,
      client: server.client,
    );
    await expectLater(
      coordinator.upload('s3'),
      throwsA(isA<CloudBackupException>()),
    );
    expect(server.dataWrites, 0);
  });

  test('SigV4 canonical query preserves duplicates and opaque tokens', () {
    final uri = Uri.parse(
      'https://s3.test/bucket?z=&a=2&a=1&token=A%2BB%2FC%3D%25%E4%B8%AD',
    );
    expect(
      AwsV4Signer.canonicalQuery(uri),
      'a=1&a=2&token=A%2BB%2FC%3D%25%E4%B8%AD&z=',
    );
    final signed = const AwsV4Signer(
      credentials: AwsCredentials(accessKeyId: 'a', secretAccessKey: 'b'),
      region: 'us-east-1',
    ).sign(method: 'GET', url: uri, now: DateTime.utc(2026, 11, 26));
    expect(signed.canonicalRequest, contains(AwsV4Signer.canonicalQuery(uri)));
  });
}
