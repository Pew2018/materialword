import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/io_client.dart';

/// Quirks a real commercial WebDAV endpoint shows and a naive mock does not.
class WebDavOptions {
  const WebDavOptions({
    this.allowMkcolOnBase = false,
    this.allowBaseCollectionWrite = false,
    this.allowHiddenFiles = true,
    this.allowPutWithoutParent = false,
    this.allowDelete = true,
    this.supportsDepthOne = true,
    this.supportsDisplayName = true,
    this.useAbsoluteHrefs = false,
    this.ignoreIfMatch = false,
    this.ignoreIfNoneMatch = false,
    this.ignoreDeleteConditions = false,
    this.rejectMkcol = false,
    this.rejectDataPut = false,
    this.redirectPrefix,
    this.redirectTo,
    this.crossOriginRedirectTo,
  });

  /// `MKCOL /dav/` → 403 (坚果云 answers `OperationNotAllowed`).
  final bool allowMkcolOnBase;

  /// `PUT /dav/x.json` directly into the mount point → 403.
  final bool allowBaseCollectionWrite;

  /// Dot-prefixed names rejected (some services do this for safety).
  final bool allowHiddenFiles;
  final bool allowPutWithoutParent;
  final bool allowDelete;

  /// `PROPFIND Depth: 1` supported. When false it answers 403 like a service
  /// that only allows Depth 0.
  final bool supportsDepthOne;
  final bool supportsDisplayName;

  /// hrefs as full URLs instead of absolute paths.
  final bool useAbsoluteHrefs;

  final bool ignoreIfMatch;
  final bool ignoreIfNoneMatch;
  final bool ignoreDeleteConditions;
  final bool rejectMkcol;

  /// `PUT` to the data document answers 403 (read-only account).
  final bool rejectDataPut;

  /// Same-origin redirect: any path starting with [redirectPrefix] answers 301
  /// to the same path with the prefix replaced by [redirectTo].
  final String? redirectPrefix;
  final String? redirectTo;

  /// Cross-origin redirect target; used to prove credentials are not forwarded.
  final String? crossOriginRedirectTo;
}

/// Loopback HTTPS server. Runtime-generated certificate is explicitly trusted by
/// the test client; neither production TLS checks nor badCertificateCallback change.
///
/// Unlike a "always 207" stub it tracks collections, so the tests can prove that
/// `/dav/` is never created and that a missing folder is created one level at a
/// time.
class WebDavServer {
  WebDavServer._(
    this.server,
    this.directory,
    this.client, {
    required this.obeysConditions,
    required this.etagMode,
    required this.options,
  });
  final HttpServer server;
  final Directory directory;
  final IOClient client;
  final bool obeysConditions;
  final String etagMode;
  final WebDavOptions options;

  final files = <String, ({String body, int revision})>{};

  /// Collections that exist, always with a trailing slash. `/dav/` is the
  /// server's own mount point and always exists.
  final collections = <String>{'/dav/'};

  final requests =
      <({String method, String path, String? match, String? none})>[];

  /// `METHOD path -> status` for assertions about ordering.
  final traffic = <String>[];

  /// Request bodies of every PUT, so a test can check the probe payload is
  /// ordinary JSON and never the real dataset.
  final Map<String, String> putBodies = <String, String>{};

  /// Every MKCOL target, so a test can assert `/dav/` never appears.
  final mkcolPaths = <String>[];

  int dataWrites = 0;
  bool conflictOnce = false;
  String? concurrentBody;
  Future<void> Function()? beforeDataWrite;
  static const dataPath = '/dav/materialword/materialword-data.json';
  static const probeName = 'materialword-probe-';

  String get baseUrl => 'https://127.0.0.1:${server.port}/dav';
  String? get dataset => files[dataPath]?.body;
  int get probeCount =>
      files.keys.where((key) => key.contains(probeName)).length;
  bool get baseMkcolAttempted => mkcolPaths.any((String p) => p == '/dav/');

  static Future<WebDavServer> start({
    bool obeysConditions = true,
    String etagMode = 'strong',
    WebDavOptions options = const WebDavOptions(),
  }) async {
    final directory = await Directory.systemTemp.createTemp('mw_https_');
    try {
      final cert = '${directory.path}/cert.pem';
      final key = '${directory.path}/key.pem';
      final generated = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-days',
        '1',
        '-keyout',
        key,
        '-out',
        cert,
        '-subj',
        '/CN=localhost',
        '-addext',
        'subjectAltName=DNS:localhost,IP:127.0.0.1',
        '-addext',
        'basicConstraints=critical,CA:TRUE',
        '-addext',
        'keyUsage=critical,keyCertSign,digitalSignature,keyEncipherment',
        '-addext',
        'extendedKeyUsage=serverAuth',
      ]);
      if (generated.exitCode != 0) {
        throw StateError('Could not generate the loopback test certificate');
      }
      final context = SecurityContext()
        ..useCertificateChain(cert)
        ..usePrivateKey(key);
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      final trust = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(cert);
      final client = IOClient(HttpClient(context: trust));
      final result = WebDavServer._(
        server,
        directory,
        client,
        obeysConditions: obeysConditions,
        etagMode: etagMode,
        options: options,
      );
      server.listen(result._handle);
      return result;
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  void replace(String body) {
    _ensureCollection(_parentOf(dataPath));
    files[dataPath] = (
      body: body,
      revision: (files[dataPath]?.revision ?? 0) + 1,
    );
  }

  /// Seeds a 0-byte document, exactly like the user's hand-made file.
  void seedEmptyDocument() {
    _ensureCollection(_parentOf(dataPath));
    files[dataPath] = (body: '', revision: 1);
  }

  /// Seeds a file at an arbitrary path (used by the concurrency tests).
  void seed(String path, String body) {
    _ensureCollection(_parentOf(path));
    files[path] = (body: body, revision: 1);
  }

  void addCollection(String path) => _ensureCollection(path);

  static String _parentOf(String path) {
    // For a collection the trailing slash is part of the path, not a separator:
    // the parent of `/dav/materialword/` is `/dav/`.
    final String trimmed = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final int index = trimmed.lastIndexOf('/');
    return index <= 0 ? '/' : trimmed.substring(0, index + 1);
  }

  static String _normalizeCollection(String path) =>
      path.endsWith('/') ? path : '$path/';

  void _ensureCollection(String path) {
    final String normalized = _normalizeCollection(path);
    if (normalized == '/') return;
    final List<String> parts = normalized
        .split('/')
        .where((String s) => s.isNotEmpty)
        .toList();
    final StringBuffer buffer = StringBuffer('/');
    for (final String part in parts) {
      buffer.write('$part/');
      collections.add(buffer.toString());
    }
  }

  String? _tag(int revision) => switch (etagMode) {
    'none' => null,
    'weak' => 'W/"r$revision"',
    _ => '"r$revision"',
  };

  String _href(String target) {
    if (!options.useAbsoluteHrefs) return target;
    return 'https://127.0.0.1:${server.port}$target';
  }

  String _escape(String value) => const HtmlEscape().convert(value);

  String _lastSegment(String path) =>
      path.split('/').where((String s) => s.isNotEmpty).lastOrNull ?? '';

  List<String> _childrenOf(String collection) {
    final List<String> children = <String>[];
    bool directChild(String candidate) {
      if (candidate == collection) return false;
      if (!candidate.startsWith(collection)) return false;
      String rest = candidate.substring(collection.length);
      if (rest.endsWith('/')) rest = rest.substring(0, rest.length - 1);
      return rest.isNotEmpty && !rest.contains('/');
    }

    for (final String candidate in collections) {
      if (directChild(candidate)) children.add(candidate);
    }
    for (final String candidate in files.keys) {
      if (directChild(candidate)) children.add(candidate);
    }
    children.sort();
    return children;
  }

  String _multistatus(List<String> targets) {
    const String ns = 'd';
    final StringBuffer out = StringBuffer(
      '<?xml version="1.0" encoding="utf-8"?>'
      '<$ns:multistatus xmlns:$ns="DAV:">',
    );
    void writeResource(String target) {
      final bool isCollection = target.endsWith('/');
      final file = files[target];
      out.write('<$ns:response><$ns:href>${_escape(_href(target))}</$ns:href>');
      out.write('<$ns:propstat><$ns:prop>');
      if (isCollection) {
        out.write('<$ns:resourcetype><$ns:collection/></$ns:resourcetype>');
      } else {
        out.write('<$ns:resourcetype/>');
      }
      if (file != null) {
        final String? tag = _tag(file.revision);
        if (tag != null) {
          out.write('<$ns:getetag>${_escape(tag)}</$ns:getetag>');
        }
        out.write(
          '<$ns:getcontentlength>${utf8.encode(file.body).length}'
          '</$ns:getcontentlength>',
        );
      }
      if (options.supportsDisplayName && isCollection) {
        out.write(
          '<$ns:displayname>${_escape(_lastSegment(target))}</$ns:displayname>',
        );
      }
      out.write('</$ns:prop><$ns:status>HTTP/1.1 200 OK</$ns:status>');
      out.write('</$ns:propstat></$ns:response>');
    }

    for (final String target in targets) {
      writeResource(target);
    }
    out.write('</$ns:multistatus>');
    return out.toString();
  }

  Future<void> _handle(HttpRequest request) async {
    final String path = request.uri.path;
    final String? match = request.headers.value('if-match');
    final String? none = request.headers.value('if-none-match');
    requests.add((
      method: request.method,
      path: path,
      match: match,
      none: none,
    ));
    final HttpResponse response = request.response;
    final String body = await utf8.decoder.bind(request).join();

    Future<void> finish(int status) async {
      response.statusCode = status;
      traffic.add('${request.method} $path -> $status');
      await response.close();
    }

    if (request.headers.value('authorization') !=
        'Basic ${base64Encode(utf8.encode('test:local-only'))}') {
      return finish(401);
    }

    if (options.crossOriginRedirectTo != null) {
      response.headers.set('location', options.crossOriginRedirectTo!);
      return finish(302);
    }
    final String? redirectPrefix = options.redirectPrefix;
    if (redirectPrefix != null &&
        path.startsWith(redirectPrefix) &&
        options.redirectTo != null) {
      final String target =
          '${options.redirectTo!}${path.substring(redirectPrefix.length)}';
      response.headers.set('location', _href(target));
      return finish(301);
    }

    switch (request.method) {
      case 'PROPFIND':
        return _propfind(request, path, finish);
      case 'MKCOL':
        return _mkcol(path, finish);
      case 'PUT':
        return _put(request, path, body, finish, match: match, none: none);
      case 'GET':
        return _get(response, path, finish, match);
      case 'HEAD':
        return _get(response, path, finish, match, headOnly: true);
      case 'DELETE':
        return _delete(path, finish, match);
      default:
        return finish(405);
    }
  }

  Future<void> _propfind(
    HttpRequest request,
    String path,
    Future<void> Function(int status) finish,
  ) async {
    final String depth = (request.headers.value('depth') ?? '0').toLowerCase();
    final bool isCollection = path.endsWith('/');
    final bool exists = isCollection
        ? collections.contains(path)
        : files.containsKey(path);
    if (!exists) return finish(404);
    if (depth == '1' && isCollection && !options.supportsDepthOne) {
      return finish(403);
    }
    final List<String> targets = <String>[path];
    if (depth == '1' && isCollection) {
      targets.addAll(_childrenOf(path));
    }
    final HttpResponse response = request.response;
    response.statusCode = 207;
    response.headers.contentType = ContentType('application', 'xml');
    response.write(_multistatus(targets));
    traffic.add('PROPFIND $path -> 207');
    await response.close();
  }

  Future<void> _mkcol(
    String path,
    Future<void> Function(int status) finish,
  ) async {
    final String target = _normalizeCollection(path);
    mkcolPaths.add(target);
    if (target == '/dav/' && !options.allowMkcolOnBase) return finish(403);
    if (options.rejectMkcol) return finish(403);
    if (collections.contains(target) || files.containsKey(path)) {
      return finish(405);
    }
    if (!collections.contains(_parentOf(target))) return finish(409);
    collections.add(target);
    return finish(201);
  }

  Future<void> _put(
    HttpRequest request,
    String path,
    String body,
    Future<void> Function(int status) finish, {
    required String? match,
    required String? none,
  }) async {
    if (path.endsWith('/')) return finish(405);
    final String name = _lastSegment(path);
    if (!options.allowHiddenFiles && name.startsWith('.')) return finish(403);
    if (path == dataPath && options.rejectDataPut) return finish(403);
    putBodies[path] = body;

    final String parent = _parentOf(path);
    if (parent == '/dav/' && !options.allowBaseCollectionWrite) {
      // Writing straight into the mount point is refused by 坚果云-like servers.
      return finish(403);
    }
    if (!options.allowPutWithoutParent && !collections.contains(parent)) {
      return finish(404);
    }

    final current = files[path];
    if (path == dataPath && beforeDataWrite != null) {
      final Future<void> Function() action = beforeDataWrite!;
      beforeDataWrite = null;
      await action();
    }
    if (path == dataPath && conflictOnce) {
      conflictOnce = false;
      replace(concurrentBody!);
      return finish(412);
    }

    final String? tag = current == null ? null : _tag(current.revision);
    if (obeysConditions && !options.ignoreIfMatch && match != null) {
      if (current == null || (match != '*' && match != tag)) return finish(412);
    }
    if (obeysConditions && !options.ignoreIfNoneMatch && none == '*') {
      if (current != null) return finish(412);
    }

    final next = (body: body, revision: (current?.revision ?? 0) + 1);
    files[path] = next;
    if (path == dataPath) dataWrites++;
    final String? nextTag = _tag(next.revision);
    if (nextTag != null) request.response.headers.set('etag', nextTag);
    return finish(current == null ? 201 : 204);
  }

  Future<void> _get(
    HttpResponse response,
    String path,
    Future<void> Function(int status) finish,
    String? match, {
    bool headOnly = false,
  }) async {
    final file = files[path];
    if (file == null) return finish(404);
    final String? tag = _tag(file.revision);
    if (obeysConditions &&
        !options.ignoreIfMatch &&
        match != null &&
        match != '*' &&
        match != tag) {
      return finish(412);
    }
    if (tag != null) response.headers.set('etag', tag);
    response.headers.contentType = ContentType.json;
    response.statusCode = 200;
    if (!headOnly) response.write(file.body);
    traffic.add('GET $path -> 200');
    await response.close();
  }

  Future<void> _delete(
    String path,
    Future<void> Function(int status) finish,
    String? match,
  ) async {
    final file = files[path];
    if (file == null) return finish(404);
    if (!options.allowDelete) return finish(403);
    if (obeysConditions &&
        !options.ignoreDeleteConditions &&
        match != null &&
        match != '*' &&
        match != _tag(file.revision)) {
      return finish(412);
    }
    files.remove(path);
    return finish(204);
  }

  Future<void> close() async {
    client.close();
    await server.close(force: true);
    await directory.delete(recursive: true);
  }
}
