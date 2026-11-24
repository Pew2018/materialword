import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/github_sync_provider.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/sync/webdav_sync_provider.dart';

/// SYNC10 – SYNC12: GitHub SHA conflicts, WebDAV ETag conflicts, and the
/// authentication / timeout / offline paths. Everything runs against a mock HTTP
/// client — no real credentials are used and no request leaves the machine.
void main() {
  final InMemoryCredentialStore credentials = InMemoryCredentialStore(
    <String, String>{
      CredentialKeys.githubToken: 'ghp_test_token',
      CredentialKeys.webdavUsername: 'user',
      CredentialKeys.webdavPassword: 'pass',
    },
  );

  Map<String, Object?> dataset() => <String, Object?>{
    'schemaVersion': 2,
    'kind': 'materialword-backup',
    'words': <Object?>[],
    'wordBooks': <Object?>[],
    'entries': <Object?>[],
    'reviewEvents': <Object?>[],
    'settings': <String, Object?>{},
  };

  group('SYNC10 GitHub Contents API', () {
    late String remoteSha;
    late Map<String, Object?> remoteJson;
    late int putCount;

    setUp(() {
      remoteSha = 'sha-1';
      remoteJson = dataset();
      putCount = 0;
    });

    MockClient buildClient({
      int? forcedStatus,
      bool rateLimited = false,
      bool publicRepo = false,
    }) {
      return MockClient((http.Request request) async {
        final String path = request.url.path;
        if (forcedStatus == 401) {
          return http.Response('{"message":"Bad credentials"}', 401);
        }
        if (rateLimited) {
          return http.Response(
            '{"message":"API rate limit exceeded"}',
            403,
            headers: <String, String>{
              'x-ratelimit-remaining': '0',
              'x-ratelimit-reset':
                  '${DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60}',
            },
          );
        }
        if (request.method == 'GET' && path == '/repos/owner/repo') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'private': !publicRepo,
              'permissions': <String, bool>{'push': true},
            }),
            200,
          );
        }
        if (request.method == 'GET' && path.contains('/contents/')) {
          if (remoteJson.isEmpty) {
            return http.Response('{"message":"Not Found"}', 404);
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'sha': remoteSha,
              'content': base64Encode(utf8.encode(jsonEncode(remoteJson))),
              'encoding': 'base64',
            }),
            200,
          );
        }
        if (request.method == 'PUT' && path.contains('/contents/')) {
          putCount++;
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          final String? sha = body['sha'] as String?;
          if (sha == null || sha != remoteSha) {
            return http.Response('{"message":"sha does not match"}', 409);
          }
          remoteJson = jsonDecode(
            utf8.decode(base64Decode(body['content'] as String)),
          ) as Map<String, Object?>;
          remoteSha = 'sha-${putCount + 1}';
          return http.Response(
            jsonEncode(<String, Object?>{
              'content': <String, Object?>{'sha': remoteSha},
            }),
            200,
          );
        }
        return http.Response('{"message":"unexpected"}', 500);
      });
    }

    test('连接测试报告仓库可见性与写权限', () async {
      final provider = GitHubSyncProvider(
        owner: 'owner',
        repo: 'repo',
        credentials: credentials,
        client: buildClient(),
      );
      final result = await provider.testConnection();
      expect(result.ok, isTrue);
      expect(result.details.join(' '), contains('私有'));
      expect(result.supportsConditionalWrites, isTrue);
    });

    test('公开仓库会给出隐私提醒', () async {
      final provider = GitHubSyncProvider(
        owner: 'owner',
        repo: 'repo',
        credentials: credentials,
        client: buildClient(publicRepo: true),
      );
      final result = await provider.testConnection();
      expect(result.ok, isTrue);
      expect(result.details.join(' '), contains('公开'));
    });

    test('下载返回内容与 SHA 作为版本', () async {
      final provider = GitHubSyncProvider(
        owner: 'owner',
        repo: 'repo',
        credentials: credentials,
        client: buildClient(),
      );
      final payload = await provider.download();
      expect(payload, isNotNull);
      expect(payload!.revision, 'sha-1');
      expect(payload.dataset['schemaVersion'], 2);
    });

    test('SHA 冲突被识别为可重试的冲突而不是覆盖', () async {
      final provider = GitHubSyncProvider(
        owner: 'owner',
        repo: 'repo',
        credentials: credentials,
        client: buildClient(),
      );
      await expectLater(
        provider.upload(dataset(), ifRevision: 'sha-stale'),
        throwsA(isA<SyncConflictException>()),
      );
    });

    test('携带正确 SHA 时上传成功并返回新版本', () async {
      final provider = GitHubSyncProvider(
        owner: 'owner',
        repo: 'repo',
        credentials: credentials,
        client: buildClient(),
      );
      final result = await provider.upload(dataset(), ifRevision: 'sha-1');
      expect(result.ok, isTrue);
      expect(result.revision, 'sha-2');
      expect(putCount, 1);
    });

    test('认证失败给出可操作的提示', () async {
      final provider = GitHubSyncProvider(
        owner: 'owner',
        repo: 'repo',
        credentials: credentials,
        client: buildClient(forcedStatus: 401),
      );
      final result = await provider.testConnection();
      expect(result.ok, isFalse);
      expect(result.message, contains('Token'));
      await expectLater(provider.download(), throwsA(isA<SyncException>()));
    });

    test('限流被标记为可重试', () async {
      final provider = GitHubSyncProvider(
        owner: 'owner',
        repo: 'repo',
        credentials: credentials,
        client: buildClient(rateLimited: true),
      );
      try {
        await provider.download();
        fail('expected SyncException');
      } on SyncException catch (e) {
        expect(e.retryable, isTrue);
        expect(e.message, contains('限流'));
      }
    });

    test('网络异常被包装为可重试的同步错误', () async {
      final provider = GitHubSyncProvider(
        owner: 'owner',
        repo: 'repo',
        credentials: credentials,
        client: MockClient((http.Request request) async {
          throw const SocketException('offline');
        }),
      );
      try {
        await provider.download();
        fail('expected SyncException');
      } on SyncException catch (e) {
        expect(e.retryable, isTrue);
      }
    });

    test('缺少配置时不会发起请求', () async {
      final provider = GitHubSyncProvider(
        owner: '',
        repo: '',
        credentials: credentials,
        client: buildClient(),
      );
      final result = await provider.testConnection();
      expect(result.ok, isFalse);
      expect(putCount, 0);
    });
  });

  group('SYNC11 WebDAV ETag 条件写入', () {
    late String? etag;
    late Map<String, Object?> fileContent;

    setUp(() {
      etag = 'abc123';
      fileContent = dataset();
    });

    MockClient buildClient({
      bool noEtag = false,
      int? forcedStatus,
      String? redirectTo,
    }) {
      return MockClient((http.Request request) async {
        if (forcedStatus == 401) {
          return http.Response('unauthorized', 401);
        }
        if (redirectTo != null) {
          return http.Response(
            '',
            302,
            headers: <String, String>{'location': redirectTo},
          );
        }
        final String method = request.method;
        if (method == 'PROPFIND') {
          final bool isFile = request.url.path.endsWith('.json');
          final String body = isFile && !noEtag && etag != null
              ? '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:"><d:response>'
                    '<d:propstat><d:prop><d:getetag>"$etag"</d:getetag>'
                    '</d:prop></d:propstat></d:response></d:multistatus>'
              : '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:"/>';
          return http.Response(body, 207);
        }
        if (method == 'GET') {
          return http.Response(
            jsonEncode(fileContent),
            200,
            headers: <String, String>{
              if (!noEtag && etag != null) 'etag': '"$etag"',
            },
          );
        }
        if (method == 'PUT') {
          final String? ifMatch = request.headers['if-match'];
          final String? ifNoneMatch = request.headers['if-none-match'];
          if (ifMatch != null && ifMatch != etag) {
            return http.Response('precondition failed', 412);
          }
          if (ifNoneMatch == '*' && etag != null) {
            return http.Response('precondition failed', 412);
          }
          fileContent = jsonDecode(
            utf8.decode(request.bodyBytes),
          ) as Map<String, Object?>;
          etag = noEtag
              ? null
              : 'etag-${DateTime.now().microsecondsSinceEpoch}';
          return http.Response(
            '',
            201,
            headers: <String, String>{if (etag != null) 'etag': '"$etag"'},
          );
        }
        if (method == 'MKCOL') return http.Response('', 201);
        return http.Response('unexpected', 500);
      });
    }

    WebDavSyncProvider provider(MockClient client) => WebDavSyncProvider(
      baseUrl: 'https://dav.example.com/remote/',
      remoteDir: 'materialword',
      credentials: credentials,
      client: client,
    );

    test('连接测试识别 ETag 能力', () async {
      final result = await provider(buildClient()).testConnection();
      expect(result.ok, isTrue);
      expect(result.supportsConditionalWrites, isTrue);
      expect(result.details.join(' '), contains('ETag'));
    });

    test('服务器不返回 ETag 时明确限制自动同步', () async {
      final result = await provider(buildClient(noEtag: true)).testConnection();
      expect(result.ok, isTrue);
      expect(result.supportsConditionalWrites, isFalse);
      expect(result.details.join(' '), contains('NO_CONDITIONAL_WRITE'));
    });

    test('下载返回 ETag，上传使用 If-Match', () async {
      final p = provider(buildClient());
      final payload = await p.download();
      expect(payload!.revision, 'abc123');
      final result = await p.upload(dataset(), ifRevision: 'abc123');
      expect(result.ok, isTrue);
      expect(result.revision, isNotNull);
    });

    test('过期 ETag 触发 412 冲突', () async {
      final p = provider(buildClient());
      await expectLater(
        p.upload(dataset(), ifRevision: 'stale-etag'),
        throwsA(isA<SyncConflictException>()),
      );
    });

    test('首次创建使用 If-None-Match', () async {
      etag = null;
      final p = provider(buildClient());
      final result = await p.upload(dataset(), ifRevision: null);
      expect(result.ok, isTrue);
    });

    test('认证失败与跨域重定向被拒绝', () async {
      final unauthorised = provider(buildClient(forcedStatus: 401));
      final result = await unauthorised.testConnection();
      expect(result.ok, isFalse);
      expect(result.message, contains('认证'));

      final redirected = provider(
        buildClient(redirectTo: 'https://evil.example.com/steal'),
      );
      try {
        await redirected.download();
        fail('expected SyncException');
      } on SyncException catch (e) {
        expect(e.message, contains('重定向'));
      }
    });

    test('非 HTTPS 地址被拒绝', () async {
      final insecure = WebDavSyncProvider(
        baseUrl: 'http://dav.example.com/',
        credentials: credentials,
        client: buildClient(),
      );
      final result = await insecure.testConnection();
      expect(result.ok, isFalse);
      expect(result.message, contains('HTTPS'));
    });
  });
}
