import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/local_file_sync_provider.dart';
import 'package:materialword/services/sync/github_sync_provider.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/sync/webdav_sync_provider.dart';

import 'helpers/test_env.dart';

void main() {
  test(
    'SYNC invalid local paths reject every operation before filesystem access',
    () async {
      for (final path in [
        '',
        '   ',
        'content://provider/file/12',
        './relative.json',
      ]) {
        final provider = LocalFileSyncProvider(filePath: path);
        expect((await provider.testConnection()).ok, isFalse);
        await expectLater(provider.download(), throwsA(isA<SyncException>()));
        await expectLater(provider.upload({}), throwsA(isA<SyncException>()));
        expect(provider.supportsConditionalWrites, isFalse);
      }
    },
  );

  test(
    'SYNC shared plan converges without overriding device preferences',
    () async {
      final a = await TestEnv.create();
      final b = await TestEnv.create();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.seedBook(words: ['alpha']);
      await b.seedBook(words: ['beta']);
      await a.settings.save(
        dailyNewTarget: 42,
        dailyReviewLimit: 123,
        studyMode: StudyMode.reviewOnly,
      );
      await b.settings.save(theme: ThemePreference.dark, ttsRate: 77);
      final data = await a.backup.buildDataset(now: a.clock.now());
      await b.backup.mergeDataset(data, now: b.clock.now());
      final settings = await b.settings.load();
      expect(settings.dailyNewTarget, 42);
      expect(settings.dailyReviewLimit, 123);
      expect(settings.studyMode, 'review');
      expect(settings.themeMode, 'dark');
      expect(settings.ttsRate, 77);
      await b.settings.save(dailyNewTarget: 56);
      await a.backup.mergeDataset(
        await b.backup.buildDataset(now: b.clock.now()),
        now: a.clock.now(),
      );
      expect((await a.settings.load()).dailyNewTarget, 56);
      await b.backup.mergeDataset(data, now: b.clock.now());
      expect(
        (await b.settings.load()).dailyNewTarget,
        56,
        reason: 'Old backup cannot overwrite newer plan',
      );
    },
  );

  test(
    'SYNC three devices with independent UUIDs converge to one logical hash',
    () async {
      final devices = [
        await TestEnv.create(),
        await TestEnv.create(),
        await TestEnv.create(),
      ];
      for (final e in devices) {
        addTearDown(e.dispose);
        await e.seedBook(words: ['alpha']);
      }
      for (int i = 0; i < devices.length; i++) {
        final e = devices[i];
        final word = (await e.words.listWords()).single.word;
        await e.study.recordAnswer(
          wordId: word.id,
          result: AnswerResult.values[i],
          type: ReviewType.study,
          eventId: 'answer-$i',
          deviceId: 'device-$i',
          now: e.clock.now(),
        );
      }
      for (int round = 0; round < 3; round++) {
        for (int i = 0; i < devices.length; i++) {
          final a = devices[i], b = devices[(i + 1) % devices.length];
          await b.backup.mergeDataset(
            await a.backup.buildDataset(now: a.clock.now()),
            now: b.clock.now(),
          );
        }
      }
      final hashes = <String>{};
      for (final e in devices) {
        final data = await e.backup.buildDataset(now: e.clock.now());
        hashes.add(BackupService.contentHashOf(data));
        expect(data['reviewEvents'] as List, hasLength(3));
        expect(data['words'] as List, hasLength(1));
        expect(data['entries'] as List, hasLength(1));
      }
      expect(hashes, hasLength(1));
    },
  );

  WebDavSyncProvider dav(MockClient client) => WebDavSyncProvider(
    baseUrl: 'https://example.com/dav',
    credentials: InMemoryCredentialStore(),
    client: client,
  );

  test(
    'SYNC strong validators retain quotes and weak validators never reach PUT',
    () async {
      for (final tag in ['W/"a"', 'abc', '"a"\r\nInjected: true']) {
        int calls = 0;
        final p = dav(
          MockClient((_) async {
            calls++;
            return http.Response('', 200);
          }),
        );
        await expectLater(
          p.upload({}, ifRevision: tag),
          throwsA(isA<SyncException>()),
        );
        expect(calls, 0);
      }
      final p = dav(
        MockClient((request) async {
          expect(request.headers['if-match'], '"a"');
          return http.Response('', 204, headers: {'etag': '"b"'});
        }),
      );
      expect((await p.upload({}, ifRevision: '"a"')).revision, '"b"');
    },
  );

  test('SYNC namespace/entity XML fallback pairs a validator with conditional GET bytes', () async {
    int gets = 0;
    final p = dav(
      MockClient((request) async {
        if (request.method == 'PROPFIND') {
          return http.Response(
            '<x:multistatus xmlns:x="DAV:"><x:response><x:propstat><x:prop>'
            '<x:getetag>&quot;a&amp;b&quot;</x:getetag></x:prop><x:status>HTTP/1.1 200 OK</x:status>'
            '</x:propstat></x:response></x:multistatus>',
            207,
          );
        }
        gets++;
        if (gets == 2) expect(request.headers['if-match'], '"a&b"');
        return http.Response(jsonEncode({'generation': gets}), 200);
      }),
    );
    final result = (await p.download())!;
    expect(gets, 2);
    expect(result.revision, '"a&b"');
    expect(result.dataset['generation'], 2);
  });

  test(
    'SYNC same-host downgrade and port redirects cannot receive credentials',
    () async {
      for (final location in [
        'http://example.com/steal',
        'https://example.com:444/steal',
      ]) {
        int calls = 0;
        final p = dav(
          MockClient((_) async {
            calls++;
            return http.Response('', 302, headers: {'location': location});
          }),
        );
        await expectLater(p.download(), throwsA(isA<SyncException>()));
        expect(calls, 1);
      }
    },
  );
  test('SYNC GitHub large files use immutable SHA raw bytes rather than empty base64', () async {
    final content = jsonEncode({
      'schemaVersion': 3,
      'words': [],
      'wordBooks': [],
      'entries': [],
      'reviewEvents': [],
      'padding': 'x' * (2 * 1024 * 1024),
    });
    int rawCalls = 0;
    final provider = GitHubSyncProvider(
      owner: 'owner',
      repo: 'data',
      credentials: InMemoryCredentialStore({
        CredentialKeys.githubToken: 'test-only-token',
      }),
      client: MockClient((request) async {
        if (request.url.path.contains('/contents/')) {
          return http.Response(
            jsonEncode({
              'sha': 'immutable-sha',
              'size': content.length,
              'encoding': 'none',
              'content': '',
            }),
            200,
          );
        }
        expect(request.url.path, '/repos/owner/data/git/blobs/immutable-sha');
        expect(request.headers['accept'], 'application/vnd.github.raw+json');
        expect(request.followRedirects, isFalse);
        rawCalls++;
        return http.Response(content, 200);
      }),
    );
    final downloaded = (await provider.download())!;
    expect(downloaded.revision, 'immutable-sha');
    expect(downloaded.dataset['schemaVersion'], 3);
    expect(downloaded.rawLength, greaterThan(1024 * 1024));
    expect(rawCalls, 1);
    expect(
      GitHubSyncProvider(owner: 'Pew2018', repo: 'materialword').isConfigured,
      isFalse,
    );
  });
}
