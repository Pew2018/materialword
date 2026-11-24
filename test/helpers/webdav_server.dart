import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/io_client.dart';

/// Loopback HTTPS server. Runtime-generated certificate is explicitly trusted by
/// the test client; neither production TLS checks nor badCertificateCallback change.
class WebDavServer {
  WebDavServer._(
    this.server,
    this.directory,
    this.client, {
    required this.obeysConditions,
    required this.etagMode,
  });
  final HttpServer server;
  final Directory directory;
  final IOClient client;
  final bool obeysConditions;
  final String etagMode;
  final files = <String, ({String body, int revision})>{};
  final requests =
      <({String method, String path, String? match, String? none})>[];
  int dataWrites = 0;
  bool conflictOnce = false;
  String? concurrentBody;
  Future<void> Function()? beforeDataWrite;
  static const dataPath = '/dav/materialword/materialword-data.json';
  String get baseUrl => 'https://127.0.0.1:${server.port}/dav';
  String? get dataset => files[dataPath]?.body;
  int get probeCount =>
      files.keys.where((key) => key.contains('.materialword-probe-')).length;

  static Future<WebDavServer> start({
    bool obeysConditions = true,
    String etagMode = 'strong',
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
      );
      server.listen(result._handle);
      return result;
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  void replace(String body) {
    files[dataPath] = (
      body: body,
      revision: (files[dataPath]?.revision ?? 0) + 1,
    );
  }

  String? _tag(int revision) => switch (etagMode) {
    'none' => null,
    'weak' => 'W/"r$revision"',
    _ => '"r$revision"',
  };

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final match = request.headers.value('if-match');
    final none = request.headers.value('if-none-match');
    requests.add((
      method: request.method,
      path: path,
      match: match,
      none: none,
    ));
    final response = request.response;
    final body = await utf8.decoder.bind(request).join();
    if (request.headers.value('authorization') !=
        'Basic ${base64Encode(utf8.encode('test:local-only'))}') {
      response.statusCode = 401;
      await response.close();
      return;
    }
    if (request.method == 'PROPFIND') {
      final file = files[path];
      if (path.endsWith('/') || file != null) {
        response.statusCode = 207;
        response.headers.contentType = ContentType('application', 'xml');
        final tag = file == null ? null : _tag(file.revision);
        response.write(
          '<d:multistatus xmlns:d="DAV:"><d:response><d:href>$path</d:href>'
          '<d:propstat><d:prop>${tag == null ? '' : '<d:getetag>${const HtmlEscape().convert(tag)}</d:getetag>'}'
          '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
        );
      } else {
        response.statusCode = 404;
      }
      await response.close();
      return;
    }
    if (request.method == 'MKCOL') {
      response.statusCode = 201;
      await response.close();
      return;
    }
    if (request.method == 'PUT' && path == dataPath) {
      if (beforeDataWrite != null) {
        final action = beforeDataWrite!;
        beforeDataWrite = null;
        await action();
      }
      if (conflictOnce) {
        conflictOnce = false;
        replace(concurrentBody!);
        response.statusCode = 412;
        await response.close();
        return;
      }
    }
    final file = files[path];
    if (obeysConditions &&
        ((match != null &&
                (file == null ||
                    (match != '*' && match != _tag(file.revision)))) ||
            (none == '*' && file != null))) {
      response.statusCode = 412;
      await response.close();
      return;
    }
    if (request.method == 'PUT') {
      final next = (body: body, revision: (file?.revision ?? 0) + 1);
      files[path] = next;
      if (path == dataPath) dataWrites++;
      final tag = _tag(next.revision);
      if (tag != null) response.headers.set('etag', tag);
      response.statusCode = file == null ? 201 : 204;
    } else if (request.method == 'GET') {
      if (file == null) {
        response.statusCode = 404;
      } else {
        response.headers.contentType = ContentType.json;
        final tag = _tag(file.revision);
        if (tag != null) response.headers.set('etag', tag);
        response.write(file.body);
      }
    } else if (request.method == 'DELETE') {
      files.remove(path);
      response.statusCode = 204;
    } else {
      response.statusCode = 405;
    }
    await response.close();
  }

  Future<void> close() async {
    client.close();
    await server.close(force: true);
    await directory.delete(recursive: true);
  }
}
