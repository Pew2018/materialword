import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/sync/webdav_sync_provider.dart';

void main() {
  test('A strong ETag on the first GET can prove safe writes', () async {
    final server = _Dav();
    final result = await server.provider.testConnection();
    expect(result.capability!.safeBidirectionalSync, isTrue);
    expect(server.body, isNull);
    expect(server.details, contains('etag_source=get_header'));
    expect(server.details, contains('condition_outcome=passed'));
  });

  for (final (header, kind) in <(String?, String)>[
    ('W/"opaque"', 'weak'),
    ('opaque-without-quotes', 'malformed'),
    (null, 'absent'),
  ]) {
    test('GET classifies $kind without granting write safety', () async {
      final server = _Dav()..getHeader = ((_) => header);
      final result = await server.provider.testConnection();
      expect(result.capability!.status, SyncCapabilityStatus.basicReadWrite);
      expect(result.capability!.supportsIfNoneMatch, isTrue);
      expect(result.capability!.supportsIfMatch, isFalse);
      expect(result.capability!.safeBidirectionalSync, isFalse);
      expect(server.details, matches('etag_source=get_header[^\n]*etag=$kind'));
      expect(server.details, contains('condition_outcome=skipped'));
      expect(
        server.requests.where(
          (r) =>
              r.method == 'PUT' && !r.url.path.contains('materialword-probe-'),
        ),
        isEmpty,
      );
      expect(server.body, isNull);
    });
  }

  for (final href in <String Function(Uri)>[
    (uri) => uri.path,
    (uri) => uri.toString(),
    (uri) => uri.pathSegments.last,
  ]) {
    test('XML matches the probe after unrelated responses', () async {
      final server = _Dav()
        ..getHeader = ((_) => null)
        ..xml = (uri, tag) =>
            _response('/dav/another.json', '"unrelated"') +
            _response(href(uri), tag);
      final result = await server.provider.testConnection();
      expect(result.capability!.safeBidirectionalSync, isTrue);
      expect(result.capability!.supportsConditionalRead, isTrue);
      expect(server.details, contains('self_match=matched'));
      expect(server.details, contains('getetag_propstat=200'));
    });
  }

  for (final (name, output, match)
      in <(String, String Function(Uri, String), String)>[
        ('missing href', (_, tag) => _response(null, tag), 'missing'),
        ('bad escape', (uri, tag) => _response('${uri.path}%', tag), 'missing'),
        (
          'other origin',
          (uri, tag) => _response('https://other.test${uri.path}', tag),
          'missing',
        ),
        (
          'trailing slash',
          (uri, tag) => _response('${uri.path}/', tag),
          'missing',
        ),
        (
          'duplicate self',
          (uri, tag) =>
              _response(uri.path, tag) + _response(uri.path, '"other-version"'),
          'ambiguous',
        ),
        (
          'failed propstat',
          (uri, tag) => _response(uri.path, tag, code: 404),
          'matched',
        ),
      ]) {
    test('XML rejects $name as a version source', () async {
      final server = _Dav()
        ..getHeader = ((_) => null)
        ..xml = (uri, tag) =>
            _response('/dav/another.json', '"unrelated"') + output(uri, tag);
      final result = await server.provider.testConnection();
      expect(result.capability!.safeBidirectionalSync, isFalse);
      expect(server.details, contains('self_match=$match'));
      if (name == 'failed propstat') {
        expect(server.details, contains('getetag_propstat=404'));
      }
    });
  }

  test(
    'A change after PROPFIND cannot pair old bytes with a newer tag',
    () async {
      final server = _Dav()
        ..getHeader = ((_) => null)
        ..xml = (uri, tag) => _response(uri.path, tag);
      final result = await server.provider.testConnection();
      expect(result.capability!.supportsConditionalRead, isTrue);
      server
        ..dataset = '{"version":1}'
        ..raceOnDatasetConditionalGet = true;
      await expectLater(
        server.provider.fetchRemote(),
        throwsA(isA<SyncConflictException>()),
      );
      expect(server.dataset, '{"version":2}');
      expect(
        server.requests.where(
          (r) =>
              r.method == 'PUT' &&
              r.url.path.endsWith('materialword-data.json'),
        ),
        isEmpty,
      );
    },
  );

  for (final condition in <String>['If-Match', 'If-None-Match']) {
    test('Ignoring $condition prevents safe sync', () async {
      final server = _Dav()..ignoredPutCondition = condition;
      final result = await server.provider.testConnection();
      expect(result.capability!.safeBidirectionalSync, isFalse);
      expect(server.details, contains('condition_outcome=ignored'));
      expect(server.body, isNull);
    });
  }

  test('XML ETag cannot be trusted if conditional GET is ignored', () async {
    final server = _Dav()
      ..getHeader = ((_) => null)
      ..ignoreConditionalGet = true
      ..xml = (uri, tag) => _response(uri.path, tag);
    final result = await server.provider.testConnection();
    expect(result.capability!.safeBidirectionalSync, isFalse);
    expect(result.capability!.supportsConditionalRead, isFalse);
  });

  test(
    'A 412 on the initial create leaves the existing resource alone',
    () async {
      final server = _Dav()..body = 'existing-file';
      final result = await server.provider.testConnection();
      expect(result.capability!.safeBidirectionalSync, isFalse);
      expect(server.body, 'existing-file');
      expect(server.requests.where((r) => r.method == 'PUT'), hasLength(1));
      expect(server.requests.where((r) => r.method == 'DELETE'), isEmpty);
    },
  );

  test('Trace records only classified ETag and probe evidence', () async {
    final server = _Dav();
    await server.provider.testConnection();
    expect(server.details, contains('materialword-probe-<nonce>'));
    expect(server.details, contains('etag_changed=true'));
    expect(server.details, isNot(contains('test-password')));
    expect(server.details, isNot(contains('test-username')));
    expect(server.details, isNot(contains('private-validator')));
    expect(server.details, isNot(contains('secret-query')));
    expect(server.details, isNot(contains('"probe"')));
    expect(server.details, isNot(contains('<multistatus')));
  });
}

String _response(String? href, String tag, {int code = 200}) =>
    '<response>'
    '${href == null ? '' : '<href>$href</href>'}'
    '<propstat><prop><getetag>$tag</getetag></prop>'
    '<status>HTTP/1.1 $code Status</status></propstat>'
    '</response>';

class _Dav {
  final List<http.Request> requests = <http.Request>[];
  String? body;
  String? dataset;
  int revision = 0;
  int datasetRevision = 1;
  bool raceOnDatasetConditionalGet = false;
  bool ignoreConditionalGet = false;
  String? ignoredPutCondition;
  String? Function(String) getHeader = (tag) => tag;
  String Function(Uri, String) xml = (_, _) => '';

  late final WebDavSyncProvider provider = WebDavSyncProvider(
    baseUrl: 'https://dav.test/dav/',
    remoteDir: '我的 坚果云',
    usernameOverride: 'test-username',
    passwordOverride: 'test-password',
    traceDiagnostics: false,
    client: MockClient(_respond),
  );

  String get details =>
      provider.trace.entries.map((entry) => entry.format()).join('\n');

  Future<http.Response> _respond(http.Request request) async {
    requests.add(request);
    final Uri uri = request.url;
    final bool probe = uri.path.contains('materialword-probe-');
    final bool realFile = uri.path.endsWith('materialword-data.json');
    final String? current = probe ? body : dataset;
    final String tag =
        '"private-validator-${probe ? revision : datasetRevision}"';
    final String? match = request.headers['if-match'];
    final String? none = request.headers['if-none-match'];
    switch (request.method) {
      case 'PROPFIND':
        if (realFile && dataset == null) return http.Response('', 404);
        if (uri.path == '/dav/' && !uri.hasQuery) {
          return http.Response(
            '',
            307,
            headers: {'location': '/dav/?secret-query=1'},
          );
        }
        return http.Response(
          '<multistatus xmlns="DAV:">'
          '${probe || realFile ? xml(uri, tag) : '<response><href>${uri.path}</href>'
                    '<propstat><prop><resourcetype><collection/></resourcetype></prop>'
                    '<status>HTTP/1.1 200 OK</status></propstat></response>'}'
          '</multistatus>',
          207,
        );
      case 'PUT':
        if (!probe) return http.Response('', 500);
        if (ignoredPutCondition != 'If-None-Match' &&
            none == '*' &&
            body != null) {
          return http.Response('', 412);
        }
        if (ignoredPutCondition != 'If-Match' &&
            match != null &&
            match != tag) {
          return http.Response('', 412);
        }
        body = request.body;
        revision++;
        return http.Response('', current == null ? 201 : 204);
      case 'GET':
        if (current == null) return http.Response('', 404);
        if (realFile && match != null && raceOnDatasetConditionalGet) {
          dataset = '{"version":2}';
          datasetRevision++;
          return http.Response('', 412);
        }
        if (!ignoreConditionalGet && match != null && match != tag) {
          return http.Response('', 412);
        }
        return http.Response(current, 200, headers: {'etag': ?getHeader(tag)});
      case 'DELETE':
        if (!probe || (match != '*' && match != tag)) {
          return http.Response('', 412);
        }
        body = null;
        return http.Response('', 204);
      default:
        return http.Response('', 405);
    }
  }
}
