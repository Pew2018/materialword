import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/sync/webdav_paths.dart';
import 'package:materialword/services/sync/webdav_sync_provider.dart';

import 'helpers/webdav_server.dart';

void main() {
  test(
    'DAV-R03 sends the exact collection request target over HTTPS',
    () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);
      final provider = WebDavSyncProvider(
        baseUrl: server.baseUrl,
        usernameOverride: 'test',
        passwordOverride: 'local-only',
        client: server.client,
        traceDiagnostics: false,
      );

      await provider.listDirectories();

      expect(server.requestTargets, <String>['/dav/']);
    },
  );

  test(
    'DAV-R01 through R04 base URI preserves trailing slash without query',
    () {
      final WebDavPaths paths = WebDavPaths.resolve(
        baseUrl: 'https://dav.jianguoyun.com/dav/',
        remoteDir: '',
        fileName: 'materialword-data.json',
      )!;
      expect(paths.base.toString(), 'https://dav.jianguoyun.com/dav/');
      expect(paths.base.hasQuery, isFalse);
      expect(paths.base.hasFragment, isFalse);
      expect(paths.directoryUri.toString(), 'https://dav.jianguoyun.com/dav/');
      expect(
        paths.fileUri.toString(),
        'https://dav.jianguoyun.com/dav/materialword-data.json',
      );
    },
  );

  test('DAV-R04 paths encode once and remain under the base collection', () {
    for (final String name in <String>[
      'MaterialWord',
      '/MaterialWord',
      '/MaterialWord/',
      'Material%20Word',
      '中文目录',
      '空格 目录',
    ]) {
      final WebDavPaths paths = WebDavPaths.resolve(
        baseUrl: 'https://dav.jianguoyun.com/dav/',
        remoteDir: name,
        fileName: 'materialword-data.json',
      )!;
      expect(paths.directoryUri.hasQuery, isFalse);
      expect(paths.directoryUri.hasFragment, isFalse);
      expect(paths.directoryUri.path, startsWith('/dav/'));
      expect(paths.directoryUri.toString(), isNot(contains('%2520')));
      expect(paths.directoryUri.path, isNot(contains('//')));
    }
  });

  test(
    'collection probe negotiates Depth and reuses the successful mode',
    () async {
      final attempts = <String>[];
      final client = MockClient((http.Request request) async {
        expect(request.method, 'PROPFIND');
        final String depth = request.headers['depth']!;
        final String? type = request.headers['content-type'];
        attempts.add('$depth $type');
        if (request.url.path.endsWith('.json')) return http.Response('', 404);
        if (depth == '0' || type != 'text/xml; charset=utf-8') {
          return http.Response('', 400);
        }
        return http.Response(
          '<d:multistatus xmlns:d="DAV:"><d:response>'
          '<d:href>/dav/</d:href><d:propstat><d:prop>'
          '<d:resourcetype><d:collection/></d:resourcetype>'
          '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>'
          '</d:response></d:multistatus>',
          207,
        );
      });
      addTearDown(client.close);
      final provider = WebDavSyncProvider(
        baseUrl: 'https://dav.test/dav/',
        remoteDir: '',
        usernameOverride: 'test',
        passwordOverride: 'local-only',
        client: client,
        traceDiagnostics: false,
      );
      expect(
        (await provider.probeCapability(deep: false)).directoryAccessible,
        isTrue,
      );
      expect(
        attempts,
        containsAllInOrder(<String>[
          '0 application/xml; charset=utf-8',
          '0 text/xml; charset=utf-8',
          '0 null',
          '1 application/xml; charset=utf-8',
          '1 text/xml; charset=utf-8',
        ]),
      );
      attempts.clear();
      await provider.probeCapability(deep: false);
      expect(attempts.first, '1 text/xml; charset=utf-8');
    },
  );

  test(
    'request rejection does not claim authentication or folder access',
    () async {
      final client = MockClient((http.Request request) async {
        expect(request.method, 'PROPFIND');
        return http.Response(
          '<d:error xmlns:d="DAV:" xmlns:s="urn:server">'
          '<s:exception>OperationNotAllowed</s:exception>'
          '<s:message>private-password</s:message></d:error>',
          400,
        );
      });
      addTearDown(client.close);
      final provider = WebDavSyncProvider(
        baseUrl: 'https://dav.test/dav/',
        usernameOverride: 'private-user',
        passwordOverride: 'private-password',
        client: client,
        traceDiagnostics: false,
      );

      final result = await provider.testConnection();
      expect(result.capability!.status, SyncCapabilityStatus.requestRejected);
      expect(result.capability!.authenticated, isFalse);
      expect(result.capability!.directoryAccessible, isFalse);
      expect(result.details.join(), isNot(contains('目录可访问')));
      final trace = provider.trace.tail().join();
      expect(trace, contains('OperationNotAllowed'));
      expect(trace, isNot(contains('private-password')));
      expect(trace, isNot(contains('private-user')));
    },
  );

  test('metadata uses the requested resource even when it is listed second', () async {
    final client = MockClient((http.Request request) async {
      String entry(String href, String etag) =>
          '<d:response>$href<d:propstat><d:prop><d:getetag>"$etag"</d:getetag>'
          '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
      return http.Response(
        '<d:multistatus xmlns:d="DAV:">'
        '${entry('', 'missing-href')}'
        '${entry('<d:href>/dav/other.json</d:href>', 'other')}'
        '${entry('<d:href>${request.url.path}</d:href>', 'self')}'
        '</d:multistatus>',
        207,
      );
    });
    addTearDown(client.close);
    final provider = WebDavSyncProvider(
      baseUrl: 'https://dav.test/dav/',
      remoteDir: '',
      usernameOverride: 'test',
      passwordOverride: 'local-only',
      client: client,
      traceDiagnostics: false,
    );

    expect((await provider.probeRemote()).revision, '"self"');
  });
}
