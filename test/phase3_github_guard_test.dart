import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/services/sync/github_sync_provider.dart';
import 'package:materialword/services/sync/sync_provider.dart';

void main() {
  for (final failure in [
    'public',
    'missing-visibility',
    'read-only',
    'missing-branch',
    'branch-forbidden',
  ]) {
    test('GitHub $failure blocks standalone upload before any write', () async {
      int writes = 0;
      int contents = 0;
      final p = GitHubSyncProvider(
        owner: 'owner',
        repo: 'data',
        tokenOverride: 'synthetic-test-token',
        client: MockClient((r) async {
          if (r.method == 'PUT') writes++;
          if (r.url.path.contains('/contents/')) contents++;
          if (r.url.path == '/repos/owner/data') {
            return http.Response(
              jsonEncode({
                if (failure != 'missing-visibility')
                  'private': failure != 'public',
                'permissions': {'push': failure != 'read-only'},
              }),
              200,
            );
          }
          return http.Response(
            '{"message":"Not Found"}',
            failure == 'branch-forbidden' ? 403 : 404,
          );
        }),
      );
      expect((await p.testConnection()).ok, isFalse);
      await expectLater(p.upload({'words': []}), throwsA(isA<SyncException>()));
      await expectLater(p.download(), throwsA(isA<SyncException>()));
      expect(writes, 0);
      expect(contents, 0);
    });
  }

  test(
    'GitHub target visibility is rechecked immediately before upload',
    () async {
      bool public = false;
      int writes = 0;
      final p = GitHubSyncProvider(
        owner: 'owner',
        repo: 'data',
        branch: 'sync/mobile',
        tokenOverride: 'synthetic-test-token',
        client: MockClient((r) async {
          if (r.url.path == '/repos/owner/data') {
            return http.Response(jsonEncode({'private': !public}), 200);
          }
          if (r.url.path.contains('/branches/')) {
            expect(r.url.pathSegments.last, 'sync/mobile');
            expect(r.followRedirects, isFalse);
            return http.Response(
              '{"name":"sync/mobile","commit":{"sha":"head"}}',
              200,
            );
          }
          if (r.method == 'PUT') writes++;
          return http.Response('', 404);
        }),
      );
      expect(await p.download(), isNull);
      public = true;
      await expectLater(p.upload({}), throwsA(isA<SyncException>()));
      expect(writes, 0);
    },
  );

  test('GitHub connection reports read-only verification and refuses content permission errors', () async {
    int fileStatus = 404;
    int writes = 0;
    final p = GitHubSyncProvider(
      owner: 'owner',
      repo: 'data',
      tokenOverride: 'synthetic-test-token',
      client: MockClient((r) async {
        if (r.method != 'GET') writes++;
        if (r.url.path == '/repos/owner/data') {
          return http.Response(
            '{"private":true,"permissions":{"push":true}}',
            200,
          );
        }
        if (r.url.path.contains('/branches/')) {
          return http.Response('{"name":"main","commit":{"sha":"head"}}', 200);
        }
        return http.Response('{}', fileStatus);
      }),
    );
    final result = await p.testConnection();
    expect(result.ok, isTrue);
    expect(result.details.join(), contains('仅验证读取'));
    expect(result.details.join(), isNot(contains('Token 具备写入权限')));
    fileStatus = 403;
    expect((await p.testConnection()).ok, isFalse);
    expect(writes, 0);
  });

  test('GitHub validation 422 is only a conflict when a first-create race has a real SHA', () async {
    int fileStatus = 404;
    final p = GitHubSyncProvider(
      owner: 'owner',
      repo: 'data',
      tokenOverride: 'synthetic-test-token',
      client: MockClient((r) async {
        if (r.url.path == '/repos/owner/data') {
          return http.Response('{"private":true}', 200);
        }
        if (r.url.path.contains('/branches/')) {
          return http.Response('{"name":"main","commit":{"sha":"head"}}', 200);
        }
        if (r.method == 'PUT') {
          return http.Response('{"message":"Validation Failed"}', 422);
        }
        return http.Response('{"sha":"created-by-other"}', fileStatus);
      }),
    );
    await expectLater(
      p.upload({}),
      throwsA(
        isA<SyncException>().having(
          (e) => e is SyncConflictException,
          'conflict',
          isFalse,
        ),
      ),
    );
    fileStatus = 200;
    await expectLater(p.upload({}), throwsA(isA<SyncConflictException>()));
    await expectLater(
      p.upload({}, ifRevision: 'old-sha'),
      throwsA(
        isA<SyncException>().having(
          (e) => e is SyncConflictException,
          'conflict',
          isFalse,
        ),
      ),
    );
  });
}
