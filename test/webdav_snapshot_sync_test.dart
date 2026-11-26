import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/sync/webdav_sync_provider.dart';

import 'helpers/test_env.dart';
import 'helpers/webdav_mock_client.dart';

void main() {
  bool isSnapshotMarker(String path) =>
      path.split('/').last.startsWith('done-');

  test('Two ETag-less clients publishing concurrently converge', () async {
    final a = await TestEnv.create();
    final b = await TestEnv.create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final server = WebDavMock(etagMode: 'none', obeysConditions: false);
    WebDavSyncProvider provider() => WebDavSyncProvider(
      baseUrl: server.baseUrl,
      credentials: InMemoryCredentialStore(),
      remoteDir: 'materialword',
      client: server.client,
    );
    await a.seedBook(words: ['alpha']);
    await b.seedBook(words: ['beta']);

    await Future.wait([
      a.coordinator.sync(provider()),
      b.coordinator.sync(provider()),
    ]);
    expect(server.files.keys.where(isSnapshotMarker), hasLength(2));

    for (final env in [a, b]) {
      await env.coordinator.sync(provider());
      expect(
        (await env.words.listWords()).map((w) => w.word.normalized),
        unorderedEquals(['alpha', 'beta']),
      );
      expect((await env.coordinator.sync(provider())).uploaded, isFalse);
    }
    expect(server.files.keys.where(isSnapshotMarker), hasLength(2));
    expect(server.traffic, isNot(contains('PUT ${server.dataPath}')));

    server.files.remove(server.files.keys.firstWhere(isSnapshotMarker));
    await expectLater(
      a.coordinator.sync(provider()),
      throwsA(isA<SyncDataException>()),
    );
  });

  test(
    'Lost write response resumes publication under the same snapshot ID',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      final server = WebDavMock(etagMode: 'none', obeysConditions: false);
      await env.seedBook(words: ['retry']);
      bool disconnect = true;
      WebDavSyncProvider provider() => WebDavSyncProvider(
        baseUrl: server.baseUrl,
        credentials: InMemoryCredentialStore(),
        remoteDir: 'materialword',
        client: MockClient((request) async {
          final forwarded = http.Request(request.method, request.url)
            ..headers.addAll(request.headers)
            ..bodyBytes = request.bodyBytes;
          final response = await http.Response.fromStream(
            await server.client.send(forwarded),
          );
          if (disconnect &&
              request.method == 'PUT' &&
              isSnapshotMarker(request.url.path)) {
            disconnect = false;
            throw http.ClientException('connection lost after commit');
          }
          return response;
        }),
      );
      await expectLater(
        env.coordinator.sync(provider()),
        throwsA(isA<SyncException>()),
      );
      final marker = server.files.keys.singleWhere(isSnapshotMarker);
      expect((await env.coordinator.sync(provider())).uploaded, isTrue);
      expect(server.files.keys.where(isSnapshotMarker), [marker]);
      expect(
        server.traffic.where((line) => line == 'PUT $marker'),
        hasLength(1),
      );
      expect((await env.coordinator.sync(provider())).uploaded, isFalse);
    },
  );

  test(
    'Empty legacy file is preserved and corrupt snapshots cannot merge',
    () async {
      final source = await TestEnv.create();
      final receiver = await TestEnv.create();
      addTearDown(source.dispose);
      addTearDown(receiver.dispose);
      final server = WebDavMock(etagMode: 'none', obeysConditions: false)
        ..seedEmptyDocument();
      WebDavSyncProvider provider() => WebDavSyncProvider(
        baseUrl: server.baseUrl,
        credentials: InMemoryCredentialStore(),
        remoteDir: 'materialword',
        client: server.client,
      );
      await source.seedBook(words: ['existing']);
      await source.coordinator.sync(provider());
      expect(server.dataset, isEmpty);
      expect(server.traffic, isNot(contains('PUT ${server.dataPath}')));

      final path = server.files.keys.singleWhere(
        (file) => file.split('/').last.startsWith('data-'),
      );
      final original = server.files[path]!;
      server.files[path] = (body: '{}', revision: original.revision);
      await expectLater(
        receiver.coordinator.sync(provider()),
        throwsA(isA<SyncDataException>()),
      );
      expect(await receiver.words.listWords(), isEmpty);
      server.files[path] = original;
      await receiver.coordinator.sync(provider());
      expect(
        (await receiver.words.listWords()).single.word.normalized,
        'existing',
      );
    },
  );
}
