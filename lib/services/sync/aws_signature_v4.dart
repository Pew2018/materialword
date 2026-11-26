import 'dart:convert';

import 'package:crypto/crypto.dart';

/// AWS Signature Version 4 for `service = s3`.
///
/// Signing is kept in one place, with no HTTP knowledge, so the three things
/// that must agree can be produced from a single input: the path that is
/// signed, the path that is sent, and the object key that was configured.
/// Signing a path that differs from the transmitted one is the classic S3
/// interoperability bug (`SignatureDoesNotMatch`), so [sign] takes the final
/// [Uri] and derives the canonical URI from `uri.path` — the same value the
/// HTTP client puts on the wire.
///
/// The hash of the body is signed as `x-amz-content-sha256`, and every
/// conditional header (`If-Match`, `If-None-Match`) is part of the signature:
/// a request whose condition is stripped or altered in transit no longer
/// verifies on the server.
class AwsCredentials {
  const AwsCredentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
  });

  final String accessKeyId;
  final String secretAccessKey;
  final String? sessionToken;

  bool get isComplete => accessKeyId.isNotEmpty && secretAccessKey.isNotEmpty;
}

/// A signature plus the headers that must accompany it.
class SignedRequestHeaders {
  const SignedRequestHeaders({
    required this.headers,
    required this.canonicalRequest,
    required this.stringToSign,
    required this.signature,
    required this.signedHeaders,
  });

  /// Headers to send, including `authorization`, `x-amz-date` and
  /// `x-amz-content-sha256`. Values are already final — callers must not
  /// rewrite them.
  final Map<String, String> headers;

  /// Kept for diagnostics and for the signature regression tests.
  final String canonicalRequest;
  final String stringToSign;
  final String signature;
  final String signedHeaders;
}

class AwsV4Signer {
  const AwsV4Signer({
    required this.credentials,
    required this.region,
    this.service = 's3',
  });

  final AwsCredentials credentials;

  /// The region the bucket really lives in. Signing with the wrong one is the
  /// most common `403 SignatureDoesNotMatch` on AWS, so it is an explicit
  /// parameter and never guessed from the host name.
  final String region;
  final String service;

  /// Headers that are signed when present. Names are lowercase and sorted,
  /// which is exactly what `SignedHeaders=` must list.
  ///
  /// `host` is derived from the URI rather than taken from a caller-supplied
  /// header so a mismatched `Host` cannot silently invalidate the signature.
  static const List<String> signableHeaders = <String>[
    'content-type',
    'host',
    'if-match',
    'if-none-match',
    'x-amz-content-sha256',
    'x-amz-date',
    'x-amz-security-token',
  ];

  /// SHA-256 of an empty body, used by GET/HEAD/DELETE.
  static final String emptyPayloadHash = sha256
      .convert(const <int>[])
      .toString();

  /// Returns the headers to send for [method] on [url].
  ///
  /// [headers] holds the caller's additional headers (content type and
  /// conditional headers); every one of them that is part of
  /// [signableHeaders] is covered by the signature.
  SignedRequestHeaders sign({
    required String method,
    required Uri url,
    required DateTime now,
    Map<String, String> headers = const <String, String>{},
    List<int>? body,
  }) {
    final DateTime utc = now.toUtc();
    final String stamp = amzDate(utc);
    final String dateStamp = stamp.substring(0, 8);
    final String payloadHash = body == null
        ? emptyPayloadHash
        : sha256.convert(body).toString();

    final Uri effective = withoutDefaultPort(url);
    final String host = hostHeader(effective);

    final Map<String, String> explicit = <String, String>{
      for (final MapEntry<String, String> entry in headers.entries)
        entry.key.toLowerCase(): entry.value,
    };
    explicit['host'] = host;
    explicit['x-amz-date'] = stamp;
    explicit['x-amz-content-sha256'] = payloadHash;
    final String? token = credentials.sessionToken;
    if (token != null && token.isNotEmpty) {
      explicit['x-amz-security-token'] = token;
    }

    final List<String> names =
        explicit.keys.where(signableHeaders.contains).toList()..sort();
    final String canonicalHeaders = names
        .map((String name) => '$name:${trimAll(explicit[name]!)}\n')
        .join();
    final String signedHeaders = names.join(';');

    final String canonicalRequest = <String>[
      method.toUpperCase(),
      canonicalPath(effective),
      canonicalQuery(effective),
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final String scope = '$dateStamp/$region/$service/aws4_request';
    final String stringToSign = <String>[
      'AWS4-HMAC-SHA256',
      stamp,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final String signature = _signature(
      secretAccessKey: credentials.secretAccessKey,
      dateStamp: dateStamp,
      region: region,
      service: service,
      stringToSign: stringToSign,
    );

    final Map<String, String> outgoing = <String, String>{
      ...headers,
      'x-amz-date': stamp,
      'x-amz-content-sha256': payloadHash,
      if (token != null && token.isNotEmpty) 'x-amz-security-token': token,
      'authorization':
          'AWS4-HMAC-SHA256 '
          'Credential=${credentials.accessKeyId}/$scope, '
          'SignedHeaders=$signedHeaders, Signature=$signature',
    };

    return SignedRequestHeaders(
      headers: outgoing,
      canonicalRequest: canonicalRequest,
      stringToSign: stringToSign,
      signature: signature,
      signedHeaders: signedHeaders,
    );
  }

  static String amzDate(DateTime utc) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  /// Exposed so the test suite can recompute a signature from a captured
  /// canonical request, exactly like a server does.
  static String signatureOf({
    required String secretAccessKey,
    required String dateStamp,
    required String region,
    required String stringToSign,
    String service = 's3',
  }) => _signature(
    secretAccessKey: secretAccessKey,
    dateStamp: dateStamp,
    region: region,
    service: service,
    stringToSign: stringToSign,
  );

  static String _signature({
    required String secretAccessKey,
    required String dateStamp,
    required String region,
    required String service,
    required String stringToSign,
  }) {
    List<int> hmac(List<int> key, String data) =>
        Hmac(sha256, key).convert(utf8.encode(data)).bytes;
    final List<int> dateKey = hmac(
      utf8.encode('AWS4$secretAccessKey'),
      dateStamp,
    );
    final List<int> regionKey = hmac(dateKey, region);
    final List<int> serviceKey = hmac(regionKey, service);
    final List<int> signingKey = hmac(serviceKey, 'aws4_request');
    return Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign)).toString();
  }

  /// Canonical URI: the URI-encoded path exactly as it is sent, with an empty
  /// path meaning `/`. S3 must **not** re-encode an already encoded path.
  static String canonicalPath(Uri url) {
    final String path = url.path;
    return path.isEmpty ? '/' : path;
  }

  /// Canonicalise each raw query component exactly once. `Uri.queryParameters`
  /// loses duplicate keys and treats `+` as a space, both of which invalidate
  /// ListObjectsV2 signatures with opaque continuation tokens.
  static String canonicalQuery(Uri url) {
    if (!url.hasQuery || url.query.isEmpty) return '';
    final pairs = <(String, String)>[];
    for (final part in url.query.split('&')) {
      final separator = part.indexOf('=');
      final rawName = separator < 0 ? part : part.substring(0, separator);
      final rawValue = separator < 0 ? '' : part.substring(separator + 1);
      pairs.add((
        encodeComponent(Uri.decodeComponent(rawName)),
        encodeComponent(Uri.decodeComponent(rawValue)),
      ));
    }
    pairs.sort((a, b) {
      final byName = a.$1.compareTo(b.$1);
      return byName != 0 ? byName : a.$2.compareTo(b.$2);
    });
    return pairs.map((pair) => '${pair.$1}=${pair.$2}').join('&');
  }

  static Uri withoutDefaultPort(Uri url) {
    final bool defaultPort =
        (url.scheme == 'https' && url.port == 443) ||
        (url.scheme == 'http' && url.port == 80);
    return defaultPort ? url.replace(port: null) : url;
  }

  static String hostHeader(Uri url) =>
      url.hasPort ? '${url.host}:${url.port}' : url.host;

  static String trimAll(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// RFC 3986 unreserved set, percent-encoded from UTF-8. `/` is a separator
  /// and is handled by [encodeKey] segment by segment.
  static String encodeComponent(String value) {
    const String unreserved =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~';
    final StringBuffer out = StringBuffer();
    for (final int byte in utf8.encode(value)) {
      final String char = String.fromCharCode(byte);
      if (byte < 0x80 && unreserved.contains(char)) {
        out.write(char);
      } else {
        out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  /// Encodes an object key for the request path, keeping `/` as the separator.
  static String encodeKey(String key) =>
      key.split('/').map(encodeComponent).join('/');
}
