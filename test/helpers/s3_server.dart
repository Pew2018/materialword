import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/io_client.dart';

/// Quirks an S3-compatible endpoint can show, and which the provider must
/// classify correctly instead of collapsing into "sync failed".
class S3Options {
  const S3Options({
    this.obeysIfMatch = true,
    this.obeysIfNoneMatch = true,
    this.omitPutEtag = false,
    this.omitHeadEtag = false,
    this.omitGetEtag = false,
    this.bucketMissing = false,
    this.denyAll = false,
    this.hideMissingAsForbidden = false,
    this.regionMismatchRegion,
    this.accessKeyId = 'AKIDEXAMPLE',
    this.secretAccessKey = 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
  });

  final bool obeysIfMatch;
  final bool obeysIfNoneMatch;

  /// PUT answers 200 without an ETag header (some gateways do this).
  final bool omitPutEtag;

  /// HEAD answers 200 without an ETag header.
  final bool omitHeadEtag;

  /// GET answers 200 without an ETag header (a proxy stripping validators).
  final bool omitGetEtag;

  /// Every request answers 404 `NoSuchBucket`.
  final bool bucketMissing;

  /// Every request answers 403 `AccessDenied` (policy denies the key).
  final bool denyAll;

  /// A missing object answers 403 instead of 404, like a key without
  /// `s3:ListBucket`. The provider must call this "cannot confirm", never
  /// "missing".
  final bool hideMissingAsForbidden;

  /// When set, every request answers 301 with `x-amz-bucket-region` pointing
  /// at this region.
  final String? regionMismatchRegion;

  final String accessKeyId;
  final String secretAccessKey;
}

/// Loopback HTTPS server that speaks the subset of the S3 REST API the sync
/// provider uses, and — importantly — **verifies the SigV4 signature itself**
/// from the bytes it actually received.
///
/// That verification is what proves the property the provider depends on: the
/// path that was signed, the path that was sent and the object key that was
/// configured are the same. A client that signs `/a%2Bb` but sends `/a+b` gets
/// `403 SignatureDoesNotMatch` here, exactly like on AWS.
class S3Server {
  S3Server._(
    this.server,
    this.directory,
    this.client, {
    required this.bucket,
    required this.options,
  });

  final HttpServer server;
  final Directory directory;
  final IOClient client;
  final String bucket;
  final S3Options options;

  /// path (`/bucket/key`) → object. Revision changes on every write.
  final Map<String, ({List<int> body, int revision})> objects =
      <String, ({List<int> body, int revision})>{};

  /// `METHOD path -> status` in order, for assertions about sequencing.
  final List<String> traffic = <String>[];

  /// Every request the server authenticated successfully.
  final List<S3SeenRequest> requests = <S3SeenRequest>[];
  final List<S3SeenRequest> rejected = <S3SeenRequest>[];

  int dataWrites = 0;

  /// Commit the write, then drop the connection without answering — the
  /// "upload actually landed but the response was lost" case.
  bool loseNextUploadResponse = false;

  /// Answer 409 `ConditionalRequestConflict` once instead of handling the
  /// conditional write.
  bool conflictOnce = false;

  /// Fail the next N reads with a 500.
  int failNextReads = 0;

  /// Run before a write is applied (used to interleave two devices).
  Future<void> Function()? beforeWrite;

  String get endpoint => 'https://127.0.0.1:${server.port}';

  bool get hasLeftoverProbe =>
      objects.keys.any((String path) => path.contains('materialword-probe-'));

  List<String> get objectPaths => objects.keys.toList()..sort();

  static Future<S3Server> start({
    String bucket = 'mw-test',
    S3Options options = const S3Options(),
  }) async {
    final Directory directory = await Directory.systemTemp.createTemp('mw_s3_');
    try {
      final String cert = '${directory.path}/cert.pem';
      final String key = '${directory.path}/key.pem';
      final ProcessResult generated = await Process.run('openssl', <String>[
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
      final SecurityContext context = SecurityContext()
        ..useCertificateChain(cert)
        ..usePrivateKey(key);
      final HttpServer server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      final SecurityContext trust = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(cert);
      final IOClient client = IOClient(HttpClient(context: trust));
      final S3Server result = S3Server._(
        server,
        directory,
        client,
        bucket: bucket,
        options: options,
      );
      server.listen(result._handle);
      return result;
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  void seed(String key, List<int> body) {
    objects['/$bucket/$key'] = (body: body, revision: 1);
  }

  void seedJson(String key, String body) => seed(key, utf8.encode(body));

  List<int>? bodyOf(String key) => objects['/$bucket/$key']?.body;

  String? textOf(String key) {
    final List<int>? body = bodyOf(key);
    return body == null ? null : utf8.decode(body, allowMalformed: true);
  }

  String? etagOf(String key) {
    final entry = objects['/$bucket/$key'];
    if (entry == null) return null;
    return _etag(entry.revision);
  }

  void remove(String key) => objects.remove('/$bucket/$key');

  static String _etag(int revision) =>
      '"${sha256.convert(utf8.encode('object-$revision')).toString().substring(0, 32)}"';

  Future<void> _handle(HttpRequest request) async {
    final String path = request.uri.path;
    final List<int> body = await request.fold<List<int>>(
      <int>[],
      (List<int> all, List<int> chunk) => all..addAll(chunk),
    );
    final S3SeenRequest seen = S3SeenRequest(
      method: request.method,
      path: path,
      query: request.uri.query,
      headers: <String, String>{
        for (final String name in _requestHeaderNames(request))
          name: request.headers.value(name) ?? '',
      },
      body: body,
    );

    Future<void> finish(
      int status, {
      String? code,
      Map<String, String>? extra,
    }) async {
      final HttpResponse response = request.response;
      response.statusCode = status;
      traffic.add('${request.method} $path -> $status');
      if (extra != null) {
        extra.forEach(response.headers.set);
      }
      if (code != null) {
        response.headers.contentType = ContentType('application', 'xml');
        response.write(
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<Error><Code>$code</Code><Message>$code</Message>'
          '<RequestId>test</RequestId></Error>',
        );
      }
      await response.close();
    }

    if (options.regionMismatchRegion != null) {
      return finish(
        301,
        code: 'PermanentRedirect',
        extra: <String, String>{
          'x-amz-bucket-region': options.regionMismatchRegion!,
        },
      );
    }
    if (options.bucketMissing) {
      return finish(404, code: 'NoSuchBucket');
    }

    final S3SeenRequest? authFailure = _authenticate(request, seen);
    if (authFailure != null) {
      // Record the reason, not just the request: the caller asserts on why the
      // server refused it.
      rejected.add(authFailure);
      return finish(authFailure.status ?? 403, code: authFailure.code);
    }
    requests.add(seen);

    if (options.denyAll) {
      return finish(403, code: 'AccessDenied');
    }

    // `HEAD /bucket` — bucket existence only.
    if (path == '/$bucket' || path == '/$bucket/') {
      return finish(
        request.method == 'HEAD' || request.method == 'GET' ? 200 : 405,
      );
    }
    if (!path.startsWith('/$bucket/')) {
      return finish(404, code: 'NoSuchBucket');
    }

    switch (request.method) {
      case 'HEAD':
        return _head(request, path, seen, finish);
      case 'GET':
        return _get(request, path, seen, finish);
      case 'PUT':
        return _put(request, path, seen, body, finish);
      case 'DELETE':
        return _delete(request, path, seen, finish);
      default:
        return finish(405, code: 'MethodNotAllowed');
    }
  }

  Future<void> _head(
    HttpRequest request,
    String path,
    S3SeenRequest seen,
    Future<void> Function(int, {String? code, Map<String, String>? extra})
    finish,
  ) async {
    final entry = objects[path];
    if (entry == null) {
      if (options.hideMissingAsForbidden) {
        return finish(403, code: 'AccessDenied');
      }
      return finish(404, code: 'NoSuchKey');
    }
    final Map<String, String> extra = <String, String>{
      'content-length': '${entry.body.length}',
      if (!options.omitHeadEtag) 'etag': _etag(entry.revision),
    };
    return finish(200, extra: extra);
  }

  Future<void> _get(
    HttpRequest request,
    String path,
    S3SeenRequest seen,
    Future<void> Function(int, {String? code, Map<String, String>? extra})
    finish,
  ) async {
    if (failNextReads > 0) {
      failNextReads--;
      return finish(500, code: 'InternalError');
    }
    final entry = objects[path];
    if (entry == null) {
      if (options.hideMissingAsForbidden) {
        return finish(403, code: 'AccessDenied');
      }
      return finish(404, code: 'NoSuchKey');
    }
    final String? match = request.headers.value('if-match');
    if (options.obeysIfMatch &&
        match != null &&
        match != '*' &&
        match != _etag(entry.revision)) {
      return finish(412, code: 'PreconditionFailed');
    }
    final HttpResponse response = request.response;
    response.statusCode = 200;
    response.headers.contentType = ContentType('application', 'json');
    if (!options.omitGetEtag) {
      response.headers.set('etag', _etag(entry.revision));
    }
    response.headers.set('content-length', '${entry.body.length}');
    response.add(entry.body);
    traffic.add('GET $path -> 200');
    await response.close();
  }

  Future<void> _put(
    HttpRequest request,
    String path,
    S3SeenRequest seen,
    List<int> body,
    Future<void> Function(int, {String? code, Map<String, String>? extra})
    finish,
  ) async {
    if (beforeWrite != null) {
      final Future<void> Function() action = beforeWrite!;
      beforeWrite = null;
      await action();
    }
    if (conflictOnce) {
      conflictOnce = false;
      return finish(409, code: 'ConditionalRequestConflict');
    }
    final current = objects[path];
    final String? match = request.headers.value('if-match');
    final String? none = request.headers.value('if-none-match');
    if (none == '*' && options.obeysIfNoneMatch && current != null) {
      return finish(412, code: 'PreconditionFailed');
    }
    if (options.obeysIfMatch &&
        match != null &&
        match != '*' &&
        (current == null || match != _etag(current.revision))) {
      return finish(412, code: 'PreconditionFailed');
    }

    final int revision = (current?.revision ?? 0) + 1;
    objects[path] = (body: body, revision: revision);
    if (path.endsWith('/materialword-data.json')) dataWrites++;

    if (loseNextUploadResponse) {
      loseNextUploadResponse = false;
      traffic.add('PUT $path -> committed_without_response');
      // Commit happened; drop the socket so the client sees a network error.
      final Socket socket = await request.response.detachSocket(
        writeHeaders: false,
      );
      socket.destroy();
      return;
    }
    return finish(
      200,
      extra: <String, String>{
        if (!options.omitPutEtag) 'etag': _etag(revision),
      },
    );
  }

  Future<void> _delete(
    HttpRequest request,
    String path,
    S3SeenRequest seen,
    Future<void> Function(int, {String? code, Map<String, String>? extra})
    finish,
  ) async {
    final current = objects[path];
    if (current == null) return finish(204);
    final String? match = request.headers.value('if-match');
    if (match != null && match != '*' && match != _etag(current.revision)) {
      return finish(412, code: 'PreconditionFailed');
    }
    objects.remove(path);
    return finish(204);
  }

  /// Independent SigV4 verification, written from the specification against the
  /// bytes that actually arrived.
  S3SeenRequest? _authenticate(HttpRequest request, S3SeenRequest seen) {
    final String? header = request.headers.value('authorization');
    if (header == null) {
      return S3SeenRequest(
        method: request.method,
        path: seen.path,
        query: seen.query,
        headers: seen.headers,
        body: seen.body,
        status: 403,
        code: 'AccessDenied',
      );
    }
    final RegExp pattern = RegExp(
      r'^AWS4-HMAC-SHA256 Credential=([^/]+)/(\d{8})/([^/]+)/s3/aws4_request, '
      r'SignedHeaders=([^,]+), Signature=([0-9a-f]{64})$',
    );
    final Match? match = pattern.firstMatch(header.trim());
    if (match == null) {
      return S3SeenRequest(
        method: request.method,
        path: seen.path,
        query: seen.query,
        headers: seen.headers,
        body: seen.body,
        status: 400,
        code: 'AuthorizationHeaderMalformed',
      );
    }
    final String accessKeyId = match.group(1)!;
    final String dateStamp = match.group(2)!;
    final String region = match.group(3)!;
    final List<String> signedNames = match.group(4)!.split(';');
    final String signature = match.group(5)!;

    final String amzDate = request.headers.value('x-amz-date') ?? '';
    final String payloadHash =
        request.headers.value('x-amz-content-sha256') ?? '';
    String expectedSignature = '';
    if (accessKeyId != options.accessKeyId) {
      return S3SeenRequest(
        method: request.method,
        path: seen.path,
        query: seen.query,
        headers: seen.headers,
        body: seen.body,
        status: 403,
        code: 'InvalidAccessKeyId',
      );
    }
    if (payloadHash != sha256.convert(seen.body).toString()) {
      // The signed payload hash must describe the bytes that arrived.
      return S3SeenRequest(
        method: request.method,
        path: seen.path,
        query: seen.query,
        headers: seen.headers,
        body: seen.body,
        status: 400,
        code: 'XAmzContentSHA256Mismatch',
      );
    }

    final StringBuffer canonical = StringBuffer()
      ..writeln(request.method)
      ..writeln(seen.path.isEmpty ? '/' : seen.path)
      ..writeln(_canonicalQuery(seen.query));
    for (final String name in signedNames) {
      final String value = name == 'host'
          ? (request.headers.value('host') ?? '')
          : (request.headers.value(name) ?? '');
      canonical.writeln(
        '$name:${value.trim().replaceAll(RegExp(r'\s+'), ' ')}',
      );
    }
    canonical
      ..writeln()
      ..writeln(signedNames.join(';'))
      ..write(payloadHash);

    final String scope = '$dateStamp/$region/s3/aws4_request';
    final String stringToSign = <String>[
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonical.toString())).toString(),
    ].join('\n');
    expectedSignature = _signature(
      secret: options.secretAccessKey,
      dateStamp: dateStamp,
      region: region,
      stringToSign: stringToSign,
    );
    if (expectedSignature != signature) {
      return S3SeenRequest(
        method: request.method,
        path: seen.path,
        query: seen.query,
        headers: seen.headers,
        body: seen.body,
        status: 403,
        code: 'SignatureDoesNotMatch',
        detail: 'expected=$expectedSignature',
      );
    }
    return null;
  }

  static String _canonicalQuery(String query) {
    if (query.isEmpty) return '';
    final List<String> parts = query.split('&')..sort();
    return parts.join('&');
  }

  static String _signature({
    required String secret,
    required String dateStamp,
    required String region,
    required String stringToSign,
  }) {
    List<int> hmac(List<int> key, String data) =>
        Hmac(sha256, key).convert(utf8.encode(data)).bytes;
    final List<int> kDate = hmac(utf8.encode('AWS4$secret'), dateStamp);
    final List<int> kRegion = hmac(kDate, region);
    final List<int> kService = hmac(kRegion, 's3');
    final List<int> kSigning = hmac(kService, 'aws4_request');
    return Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();
  }

  static Iterable<String> _requestHeaderNames(HttpRequest request) sync* {
    for (final String name in <String>[
      'authorization',
      'content-type',
      'etag',
      'host',
      'if-match',
      'if-none-match',
      'x-amz-content-sha256',
      'x-amz-date',
      'x-amz-security-token',
    ]) {
      if (request.headers.value(name) != null) yield name;
    }
  }

  Future<void> close() async {
    client.close();
    await server.close(force: true);
    await directory.delete(recursive: true);
  }
}

class S3SeenRequest {
  const S3SeenRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
    this.status,
    this.code,
    this.detail,
  });

  final String method;
  final String path;
  final String query;
  final Map<String, String> headers;
  final List<int> body;
  final int? status;
  final String? code;
  final String? detail;

  String? get ifMatch => headers['if-match'];
  String? get ifNoneMatch => headers['if-none-match'];
  String? get signedHeaders => headers['authorization'];

  @override
  String toString() => '$method $path';
}
