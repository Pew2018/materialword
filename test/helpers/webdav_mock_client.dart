import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory WebDAV endpoint used by widget tests.
///
/// Widget tests run inside a fake-async zone, where a real loopback socket never
/// completes. This mock speaks the same subset as [WebDavServer] but resolves
/// through microtasks, so a page can be driven end to end without any real I/O.
///
/// The behaviour mirrors a commercial service on purpose:
///  * `/dav/` is the mount point and is not writable;
///  * a missing collection answers 404, so the provider has to create it;
///  * `MKCOL /dav/` answers 403;
///  * ETags, `If-Match` and `If-None-Match` are honoured unless a quirk says
///    otherwise.
class WebDavMock {
  WebDavMock({
    this.etagMode = 'strong',
    this.obeysConditions = true,
    this.rejectMkcol = false,
    this.rejectDataPut = false,
    this.basePath = '/dav/',
  }) {
    collections.add(basePath);
  }

  final String etagMode;
  final bool obeysConditions;
  final bool rejectMkcol;
  final bool rejectDataPut;
  final String basePath;

  final Map<String, ({String body, int revision})> files =
      <String, ({String body, int revision})>{};
  final Set<String> collections = <String>{};
  final List<String> traffic = <String>[];

  String get baseUrl => 'https://dav.test/dav';
  String get dataPath => '${basePath}materialword/materialword-data.json';
  String? get dataset => files[dataPath]?.body;
  int get probeCount => files.keys
      .where((String key) => key.contains('materialword-probe-'))
      .length;

  late final http.Client client = MockClient(_handle);

  void seedEmptyDocument() {
    collections.add('${basePath}materialword/');
    files[dataPath] = (body: '', revision: 1);
  }

  void seed(String path, String body) {
    collections.add(_parentOf(path));
    files[path] = (body: body, revision: 1);
  }

  void addCollection(String path) => collections.add(_normalize(path));

  static String _normalize(String path) => path.endsWith('/') ? path : '$path/';

  static String _parentOf(String path) {
    final String trimmed = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final int index = trimmed.lastIndexOf('/');
    return index <= 0 ? '/' : trimmed.substring(0, index + 1);
  }

  String _lastSegment(String path) =>
      path.split('/').where((String s) => s.isNotEmpty).lastOrNull ?? '';

  String? _tag(int revision) => switch (etagMode) {
    'none' => null,
    'weak' => 'W/"r$revision"',
    _ => '"r$revision"',
  };

  List<String> _childrenOf(String collection) {
    bool direct(String candidate) {
      if (candidate == collection || !candidate.startsWith(collection)) {
        return false;
      }
      String rest = candidate.substring(collection.length);
      if (rest.endsWith('/')) rest = rest.substring(0, rest.length - 1);
      return rest.isNotEmpty && !rest.contains('/');
    }

    return <String>[...collections.where(direct), ...files.keys.where(direct)]
      ..sort();
  }

  String _multistatus(List<String> targets) {
    const String ns = 'd';
    final StringBuffer out = StringBuffer(
      '<?xml version="1.0" encoding="utf-8"?>'
      '<$ns:multistatus xmlns:$ns="DAV:">',
    );
    for (final String target in targets) {
      final bool isCollection = target.endsWith('/');
      final file = files[target];
      out.write(
        '<$ns:response><$ns:href>${const HtmlEscape().convert(target)}</$ns:href>',
      );
      out.write('<$ns:propstat><$ns:prop>');
      if (isCollection) {
        out.write('<$ns:resourcetype><$ns:collection/></$ns:resourcetype>');
        out.write(
          '<$ns:displayname>${const HtmlEscape().convert(_lastSegment(target))}'
          '</$ns:displayname>',
        );
      } else {
        out.write('<$ns:resourcetype/>');
      }
      if (file != null) {
        final String? tag = _tag(file.revision);
        if (tag != null) {
          out.write(
            '<$ns:getetag>${const HtmlEscape().convert(tag)}</$ns:getetag>',
          );
        }
        out.write(
          '<$ns:getcontentlength>${utf8.encode(file.body).length}'
          '</$ns:getcontentlength>',
        );
      }
      out.write('</$ns:prop><$ns:status>HTTP/1.1 200 OK</$ns:status>');
      out.write('</$ns:propstat></$ns:response>');
    }
    out.write('</$ns:multistatus>');
    return out.toString();
  }

  Future<http.Response> _handle(http.Request request) async {
    final String path = request.url.path;
    final String? match = request.headers['if-match'];
    final String? none = request.headers['if-none-match'];
    traffic.add('${request.method} $path');

    switch (request.method) {
      case 'PROPFIND':
        final bool isCollection = path.endsWith('/');
        final bool exists = isCollection
            ? collections.contains(path)
            : files.containsKey(path);
        if (!exists) return http.Response('', 404);
        final bool deep = (request.headers['depth'] ?? '0') == '1';
        final List<String> targets = <String>[
          path,
          if (deep && isCollection) ..._childrenOf(path),
        ];
        return http.Response(_multistatus(targets), 207, headers: _xmlHeaders);

      case 'MKCOL':
        final String target = _normalize(path);
        if (target == basePath) return http.Response('', 403);
        if (rejectMkcol) return http.Response('', 403);
        if (collections.contains(target) || files.containsKey(path)) {
          return http.Response('', 405);
        }
        if (!collections.contains(_parentOf(target))) {
          return http.Response('', 409);
        }
        collections.add(target);
        return http.Response('', 201);

      case 'PUT':
        if (path.endsWith('/')) return http.Response('', 405);
        if (path == dataPath && rejectDataPut) return http.Response('', 403);
        final String parent = _parentOf(path);
        if (parent == basePath) return http.Response('', 403);
        if (!collections.contains(parent)) return http.Response('', 404);
        final current = files[path];
        final String? tag = current == null ? null : _tag(current.revision);
        if (obeysConditions && match != null) {
          if (current == null || (match != '*' && match != tag)) {
            return http.Response('', 412);
          }
        }
        if (obeysConditions && none == '*' && current != null) {
          return http.Response('', 412);
        }
        final next = (
          body: request.body,
          revision: (current?.revision ?? 0) + 1,
        );
        files[path] = next;
        final String? nextTag = _tag(next.revision);
        return http.Response(
          '',
          current == null ? 201 : 204,
          headers: <String, String>{'etag': ?nextTag},
        );

      case 'GET':
      case 'HEAD':
        final file = files[path];
        if (file == null) return http.Response('', 404);
        final String? tag = _tag(file.revision);
        if (obeysConditions && match != null && match != '*' && match != tag) {
          return http.Response('', 412);
        }
        return http.Response(
          request.method == 'HEAD' ? '' : file.body,
          200,
          headers: <String, String>{'etag': ?tag},
        );

      case 'DELETE':
        final file = files[path];
        if (file == null) return http.Response('', 404);
        if (obeysConditions &&
            match != null &&
            match != '*' &&
            match != _tag(file.revision)) {
          return http.Response('', 412);
        }
        files.remove(path);
        return http.Response('', 204);

      default:
        return http.Response('', 405);
    }
  }

  static const Map<String, String> _xmlHeaders = <String, String>{
    'content-type': 'application/xml; charset=utf-8',
  };
}
