import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/sync/webdav_sync_provider.dart';

import 'helpers/test_env.dart';
import 'helpers/webdav_server.dart';

void main() {
  final credentials = InMemoryCredentialStore({
    CredentialKeys.webdavUsername: 'test',
    CredentialKeys.webdavPassword: 'local-only',
  });
  WebDavSyncProvider provider(WebDavServer server) => WebDavSyncProvider(
    baseUrl: server.baseUrl,
    credentials: credentials,
    client: server.client,
  );
  SyncCoordinator coordinator(TestEnv env) => SyncCoordinator(
    db: env.db,
    backup: env.backup,
    study: env.study,
    settings: env.settings,
    credentials: credentials,
    clock: env.clock,
  );

  test('HTTPS conditional probe verifies actual 412, update/readback and cleanup without touching data', () async {
    final server = await WebDavServer.start();
    addTearDown(server.close);
    server.replace('{"original":true}');
    final result = await provider(server).testConnection();
    expect(result.ok, isTrue);
    expect(result.supportsConditionalWrites, isTrue);
    expect(server.dataset, '{"original":true}');
    expect(server.dataWrites, 0);
    expect(server.probeCount, 0);
    expect(
      server.requests.where((r) => r.method == 'PUT' && r.match != null),
      isNotEmpty,
    );
    expect(
      server.requests.where((r) => r.method == 'PUT' && r.none == '*').length,
      2,
    );
  });

  for (final mode in ['ignores-conditions', 'weak', 'none']) {
    test(
      'HTTPS $mode cannot enter bidirectional sync or modify the real document',
      () async {
        final server = await WebDavServer.start(
          obeysConditions: mode != 'ignores-conditions',
          etagMode: mode == 'ignores-conditions' ? 'strong' : mode,
        );
        addTearDown(server.close);
        final env = await TestEnv.create();
        addTearDown(env.dispose);
        server.replace(
          jsonEncode(await env.backup.buildDataset(now: env.clock.now())),
        );
        final original = server.dataset;
        final p = provider(server);
        final result = await p.testConnection();
        expect(result.ok, isTrue);
        expect(result.supportsConditionalWrites, isFalse);
        await expectLater(
          coordinator(env).sync(p, skipConnectionTest: true),
          throwsA(isA<SyncException>()),
        );
        expect(server.dataset, original);
        expect(server.dataWrites, 0);
        expect(server.probeCount, 0);
      },
    );
  }

  test('HTTPS initial create, no-op and 412 merge retry converge with real transport', () async {
    final server = await WebDavServer.start();
    addTearDown(server.close);
    final a = await TestEnv.create();
    final b = await TestEnv.create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.seedBook(words: ['alpha']);
    await b.seedBook(words: ['beta']);
    final aSync = coordinator(a);
    final p = provider(server);
    final first = await aSync.sync(p);
    expect(first.uploaded, isTrue);
    expect(server.dataWrites, 1);
    final same = await aSync.sync(p);
    expect(same.skipped, isTrue);
    expect(server.dataWrites, 1);
    server.conflictOnce = true;
    server.concurrentBody = await b.backup.exportToJson(now: b.clock.now());
    await a.words.ensureWord(text: 'gamma', now: a.clock.now());
    final retried = await aSync.sync(p);
    expect(retried.attempts, 2);
    final remote = a.backup.decodeDataset(server.dataset!);
    expect(remote['words'] as List, hasLength(3));
    expect(
      BackupService.contentHashOf(remote),
      BackupService.contentHashOf(
        await a.backup.buildDataset(now: a.clock.now()),
      ),
    );
    expect(server.probeCount, 0);
  });

  test('HTTPS an answer written during upload stays locally pending and is sent next time', () async {
    final server = await WebDavServer.start();
    addTearDown(server.close);
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(words: ['alpha']);
    final word = (await env.words.listWords()).single.word;
    await env.settings.setSyncConfig({
      'provider': 'webdav',
      'url': server.baseUrl,
      'dir': 'materialword',
      'file': 'materialword-data.json',
    });
    server.beforeDataWrite = () async {
      await env.study.recordAnswer(
        wordId: word.id,
        result: AnswerResult.known,
        type: ReviewType.study,
        eventId: 'during-upload',
        deviceId: 'local-device',
        now: env.clock.now(),
      );
    };
    final sync = coordinator(env);
    await sync.sync(provider(server));
    expect(await sync.hasLocalChanges(), isTrue);
    expect((jsonDecode(server.dataset!) as Map)['reviewEvents'], isEmpty);
    await sync.sync(provider(server));
    expect(await sync.hasLocalChanges(), isFalse);
    expect((jsonDecode(server.dataset!) as Map)['reviewEvents'], hasLength(1));
  });

  test(
    'HTTPS default client rejects the untrusted loopback certificate',
    () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);
      final p = WebDavSyncProvider(
        baseUrl: server.baseUrl,
        credentials: credentials,
      );
      addTearDown(p.close);
      await expectLater(p.download(), throwsA(isA<SyncException>()));
      expect(
        server.requests,
        isEmpty,
        reason: 'TLS rejection happens before HTTP or credentials',
      );
    },
  );
}
