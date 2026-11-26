import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../sync/aws_signature_v4.dart';
import '../sync/s3_sync_provider.dart';
import '../sync/webdav_paths.dart';
import 'cloud_backup_repository.dart';

const int cloudBackupMaxBytes = 100 * 1024 * 1024;
final RegExp cloudProbeName = RegExp(
  r'^\.materialword-backup-probe-[0-9a-fA-F-]{36}$',
);
final RegExp cloudBackupName = RegExp(
  r'^materialword-backup-\d{8}T\d{9}Z-[0-9a-fA-F-]{36}\.json$',
);

class CloudBackupEntry {
  const CloudBackupEntry({
    required this.providerId,
    required this.objectName,
    required this.targetFingerprint,
    this.createdAt,
    this.lastModified,
    this.byteLength,
  });
  final String providerId;
  final String objectName;
  final String targetFingerprint;
  final DateTime? createdAt;
  final DateTime? lastModified;
  final int? byteLength;
}

class CloudBackupPage {
  const CloudBackupPage(this.entries, {this.continuationToken});
  final List<CloudBackupEntry> entries;
  final String? continuationToken;
}

enum CloudBackupObjectState { exists, missing, unknown }

class CloudBackupException implements Exception {
  const CloudBackupException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

abstract interface class CloudBackupProvider {
  Future<CloudBackupObjectState> inspectObject(String objectName);
  Future<void> uploadBackup(String objectName, List<int> bytes);
  Future<List<int>> downloadBackup(String objectName);
  Future<CloudBackupPage> listBackups({String? continuationToken});
  Future<void> ensureDirectory();
  Future<void> deleteProbe(String objectName);
  Future<void> deleteBackup(String objectName);
  void close();
}

/// Network client is owned only when no client was injected by the caller.
abstract class _HttpBackupProvider implements CloudBackupProvider {
  _HttpBackupProvider(
    this.config,
    this.firstSecret,
    this.secondSecret, {
    http.Client? client,
  }) : _injected = client;
  final CloudBackupConfig config;
  final String firstSecret;
  final String secondSecret;
  final http.Client? _injected;
  http.Client? _owned;
  http.Client get client => _injected ?? (_owned ??= http.Client());
  @override
  void close() {
    _owned?.close();
    _owned = null;
  }

  Future<http.Response> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
    String? redirectPathPrefix,
    int redirects = 0,
  }) async {
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers.addAll(headers);
    if (body != null) request.bodyBytes = body;
    try {
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final declared = streamed.contentLength;
      if (declared != null && declared > cloudBackupMaxBytes) {
        throw const CloudBackupException('Backup exceeds 100 MB');
      }
      final bytes = <int>[];
      await for (final chunk in streamed.stream.timeout(
        const Duration(seconds: 45),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > cloudBackupMaxBytes) {
          throw const CloudBackupException('Backup exceeds 100 MB');
        }
      }
      if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
        final location = streamed.headers['location'];
        final next = location == null ? null : uri.resolve(location);
        if (redirectPathPrefix != null &&
            redirects < 3 &&
            next != null &&
            next.scheme == 'https' &&
            next.origin == uri.origin &&
            next.userInfo.isEmpty &&
            !next.hasQuery &&
            !next.hasFragment &&
            next.path.startsWith(redirectPathPrefix)) {
          return await send(
            method,
            next,
            headers: headers,
            body: body,
            redirectPathPrefix: redirectPathPrefix,
            redirects: redirects + 1,
          );
        }
        throw CloudBackupException(
          'Unsafe or unsupported redirect',
          status: streamed.statusCode,
        );
      }
      return http.Response.bytes(
        bytes,
        streamed.statusCode,
        headers: streamed.headers,
      );
    } on TimeoutException {
      throw const CloudBackupException('Cloud backup request timed out');
    } on http.ClientException {
      throw const CloudBackupException('Cloud backup connection failed');
    }
  }

  DateTime? created(String name) {
    final match = RegExp(r'materialword-backup-(\d{8})T(\d{6})(\d{3})Z-')
        .firstMatch(name);
    if (match == null) return null;
    final day = match.group(1)!;
    final time = match.group(2)!;
    final value = DateTime.tryParse(
      '${day.substring(0, 4)}-${day.substring(4, 6)}-'
      '${day.substring(6)}T${time.substring(0, 2)}:${time.substring(2, 4)}:'
      '${time.substring(4)}.${match.group(3)}Z',
    );
    if (value == null ||
        value.year != int.parse(day.substring(0, 4)) ||
        value.month != int.parse(day.substring(4, 6)) ||
        value.day != int.parse(day.substring(6)) ||
        value.hour != int.parse(time.substring(0, 2)) ||
        value.minute != int.parse(time.substring(2, 4)) ||
        value.second != int.parse(time.substring(4))) {
      return null;
    }
    return value;
  }
}

class S3BackupProvider extends _HttpBackupProvider {
  S3BackupProvider(
    super.config,
    super.firstSecret,
    super.secondSecret, {
    super.client,
  }) : target = S3Target.resolve(
         endpoint: config.endpoint,
         region: config.region,
         bucket: config.bucket,
         objectKey: '${config.directory}materialword-backup-test.json',
         addressing: switch (config.addressing) {
           'path' => S3AddressingStyle.pathStyle,
           'virtual' => S3AddressingStyle.virtualHosted,
           _ => S3AddressingStyle.auto,
         },
       )!;
  final S3Target target;

  Uri objectUri(String name) {
    if (!cloudBackupName.hasMatch(name) && !cloudProbeName.hasMatch(name)) {
      throw const CloudBackupException('Invalid backup name');
    }
    return target.uriFor('${config.directory}$name');
  }

  Future<http.Response> _signed(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) {
    final signed =
        AwsV4Signer(
          credentials: AwsCredentials(
            accessKeyId: firstSecret,
            secretAccessKey: secondSecret,
          ),
          region: config.region,
        ).sign(
          method: method,
          url: uri,
          now: DateTime.now(),
          headers: headers,
          body: body,
        );
    return send(method, uri, headers: signed.headers, body: body);
  }

  @override
  Future<void> ensureDirectory() async {}

  @override
  Future<CloudBackupObjectState> inspectObject(String name) async {
    final response = await _signed('GET', objectUri(name));
    if (response.statusCode == 200) return CloudBackupObjectState.exists;
    if (response.statusCode == 404 &&
        !utf8
            .decode(response.bodyBytes, allowMalformed: true)
            .contains('NoSuchBucket')) {
      return CloudBackupObjectState.missing;
    }
    throw CloudBackupException(
      'Could not inspect S3 object',
      status: response.statusCode,
    );
  }

  @override
  Future<void> uploadBackup(String name, List<int> bytes) async {
    var response = await _signed(
      'PUT',
      objectUri(name),
      body: bytes,
      headers: const {'content-type': 'application/json', 'if-none-match': '*'},
    );
    if (response.statusCode == 400 || response.statusCode == 501) {
      // Some compatible stores reject this header. A fresh random name and a
      // second definitive absence check allow a best-effort plain PUT.
      if (await inspectObject(name) != CloudBackupObjectState.missing) {
        throw const CloudBackupException('Backup object already exists');
      }
      response = await _signed(
        'PUT',
        objectUri(name),
        body: bytes,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw CloudBackupException(
        'S3 upload failed',
        status: response.statusCode,
      );
    }
  }

  @override
  Future<List<int>> downloadBackup(String name) async {
    final response = await _signed('GET', objectUri(name));
    if (response.statusCode != 200) {
      throw CloudBackupException(
        'S3 download failed',
        status: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<void> deleteProbe(String name) async {
    if (!cloudProbeName.hasMatch(name)) {
      throw const CloudBackupException('Invalid probe name');
    }
    final response = await _signed('DELETE', objectUri(name));
    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 404) {
      throw CloudBackupException(
        'S3 probe cleanup failed',
        status: response.statusCode,
      );
    }
  }

  @override
  Future<void> deleteBackup(String name) async {
    if (!cloudBackupName.hasMatch(name))
      throw const CloudBackupException('Invalid backup name');
    final response = await _signed('DELETE', objectUri(name));
    // No versionId: versioned buckets create a delete marker, retaining old versions.
    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 404) {
      throw CloudBackupException(
        'S3 backup deletion failed',
        status: response.statusCode,
      );
    }
  }

  @override
  Future<CloudBackupPage> listBackups({String? continuationToken}) async {
    final query = <String, String>{
      'list-type': '2',
      'prefix': config.directory,
      'max-keys': '1000',
      'continuation-token': ?continuationToken,
    };
    final uri = target.bucketUri.replace(queryParameters: query);
    final response = await _signed('GET', uri);
    if (response.statusCode != 200) {
      throw CloudBackupException(
        'S3 listing failed',
        status: response.statusCode,
      );
    }
    final XmlElement root;
    try {
      root = XmlDocument.parse(response.body).rootElement;
    } on XmlParserException {
      throw const CloudBackupException('Invalid S3 listing');
    }
    if (root.name.local != 'ListBucketResult') {
      throw const CloudBackupException('Invalid S3 listing');
    }
    String? child(XmlElement e, String name) {
      for (final c in e.childElements) {
        if (c.name.local == name) return c.innerText;
      }
      return null;
    }

    final entries = <CloudBackupEntry>[];
    final seen = <String>{};
    for (final item in root.childElements.where(
      (e) => e.name.local == 'Contents',
    )) {
      final key = child(item, 'Key');
      if (key == null || !key.startsWith(config.directory)) continue;
      final name = key.substring(config.directory.length);
      if (!cloudBackupName.hasMatch(name) || !seen.add(name)) continue;
      entries.add(
        CloudBackupEntry(
          providerId: 's3',
          objectName: name,
          targetFingerprint: config.fingerprint,
          createdAt: created(name),
          lastModified: DateTime.tryParse(child(item, 'LastModified') ?? ''),
          byteLength: int.tryParse(child(item, 'Size') ?? ''),
        ),
      );
    }
    if (!{'true', 'false'}.contains(child(root, 'IsTruncated'))) {
      throw const CloudBackupException('Incomplete S3 listing');
    }
    final truncated = child(root, 'IsTruncated') == 'true';
    final next = child(root, 'NextContinuationToken');
    if (truncated &&
        (next == null || next.isEmpty || next == continuationToken)) {
      throw const CloudBackupException('Invalid S3 pagination token');
    }
    return CloudBackupPage(entries, continuationToken: truncated ? next : null);
  }
}

class WebDavBackupProvider extends _HttpBackupProvider {
  WebDavBackupProvider(
    super.config,
    super.firstSecret,
    super.secondSecret, {
    super.client,
  }) : paths = WebDavPaths.resolve(
         baseUrl: config.endpoint,
         remoteDir: config.directory,
         fileName: 'materialword-backup-test.json',
       )!;
  final WebDavPaths paths;

  Uri objectUri(String name) {
    if (!cloudBackupName.hasMatch(name) && !cloudProbeName.hasMatch(name)) {
      throw const CloudBackupException('Invalid backup name');
    }
    return paths.directoryUri.replace(
      path: '${paths.directoryUri.path}${Uri.encodeComponent(name)}',
    );
  }

  Map<String, String> get auth => <String, String>{
    'authorization':
        'Basic ${base64.encode(utf8.encode('$firstSecret:$secondSecret'))}',
  };

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) => send(
    method,
    uri,
    headers: {...auth, ...headers},
    body: body,
    redirectPathPrefix: paths.basePath,
  );

  bool _isDirectory(http.Response response) {
    if (response.statusCode != 207 && response.statusCode != 200) return false;
    try {
      return XmlDocument.parse(response.body).descendants
          .whereType<XmlElement>()
          .any((element) => element.name.local == 'collection');
    } on XmlParserException {
      return false;
    }
  }

  @override
  Future<void> ensureDirectory() async {
    for (var i = 1; i <= paths.segments.length; i++) {
      final uri = paths.directoryAt(i);
      var response = await _send(
        'PROPFIND',
        uri,
        headers: const {'depth': '0'},
      );
      if (_isDirectory(response)) continue;
      if (response.statusCode != 404) {
        throw CloudBackupException(
          'WebDAV directory check failed',
          status: response.statusCode,
        );
      }
      response = await _send('MKCOL', uri);
      if (response.statusCode == 201) continue;
      if (response.statusCode == 405) {
        final check = await _send(
          'PROPFIND',
          uri,
          headers: const {'depth': '0'},
        );
        if (_isDirectory(check)) continue;
      }
      throw CloudBackupException(
        'WebDAV directory creation failed',
        status: response.statusCode,
      );
    }
  }

  @override
  Future<CloudBackupObjectState> inspectObject(String name) async {
    final response = await _send('GET', objectUri(name));
    if (response.statusCode == 200) return CloudBackupObjectState.exists;
    if (response.statusCode == 404) return CloudBackupObjectState.missing;
    throw CloudBackupException(
      'Could not inspect WebDAV object',
      status: response.statusCode,
    );
  }

  @override
  Future<void> uploadBackup(String name, List<int> bytes) async {
    var response = await _send(
      'PUT',
      objectUri(name),
      body: bytes,
      headers: const {'content-type': 'application/json', 'if-none-match': '*'},
    );
    if (response.statusCode == 400 || response.statusCode == 501) {
      if (await inspectObject(name) != CloudBackupObjectState.missing) {
        throw const CloudBackupException('Backup object already exists');
      }
      response = await _send(
        'PUT',
        objectUri(name),
        body: bytes,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw CloudBackupException(
        'WebDAV upload failed',
        status: response.statusCode,
      );
    }
  }

  @override
  Future<List<int>> downloadBackup(String name) async {
    final response = await _send('GET', objectUri(name));
    if (response.statusCode != 200) {
      throw CloudBackupException(
        'WebDAV download failed',
        status: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<void> deleteProbe(String name) async {
    if (!cloudProbeName.hasMatch(name)) {
      throw const CloudBackupException('Invalid probe name');
    }
    final response = await _send('DELETE', objectUri(name));
    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 404) {
      throw CloudBackupException(
        'WebDAV probe cleanup failed',
        status: response.statusCode,
      );
    }
  }

  @override
  Future<void> deleteBackup(String name) async {
    if (!cloudBackupName.hasMatch(name))
      throw const CloudBackupException('Invalid backup name');
    final response = await _send('DELETE', objectUri(name));
    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 404) {
      throw CloudBackupException(
        'WebDAV backup deletion failed',
        status: response.statusCode,
      );
    }
  }

  @override
  Future<CloudBackupPage> listBackups({String? continuationToken}) async {
    final response = await _send(
      'PROPFIND',
      paths.directoryUri,
      headers: const {'depth': '1', 'content-type': 'application/xml'},
      body: utf8.encode(
        '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/><d:getcontentlength/><d:getlastmodified/></d:prop></d:propfind>',
      ),
    );
    if (response.statusCode != 207) {
      throw CloudBackupException(
        'WebDAV listing failed',
        status: response.statusCode,
      );
    }
    final XmlElement root;
    try {
      root = XmlDocument.parse(response.body).rootElement;
    } on XmlParserException {
      throw const CloudBackupException('Invalid WebDAV listing');
    }
    if (root.name.local != 'multistatus') {
      throw const CloudBackupException('Invalid WebDAV listing');
    }
    if (response.headers.keys.any(
          (key) => {
            'x-next-page',
            'x-next-marker',
            'x-continuation-token',
          }.contains(key),
        ) ||
        (response.headers['link'] ?? '').contains('rel="next"') ||
        root.descendants.whereType<XmlElement>().any(
          (e) =>
              {
                'number-of-matches-within-limits',
                'limit',
                'next',
                'next-page',
                'continuation-token',
              }.contains(e.name.local) ||
              (e.name.local == 'status' &&
                  !RegExp(r'^HTTP/[^ ]+ 2[0-9][0-9]( |$)')
                      .hasMatch(e.innerText.trim())),
        )) {
      throw const CloudBackupException(
        'Incomplete WebDAV listing; server pagination or limits unsupported',
      );
    }
    final entries = <CloudBackupEntry>[];
    final seen = <String>{};
    for (final item in root.childElements.where(
      (e) => e.name.local == 'response',
    )) {
      final href = item.childElements
          .where((e) => e.name.local == 'href')
          .firstOrNull
          ?.innerText;
      if (href == null ||
          href.startsWith('//') ||
          href.contains('\\') ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(href)) {
        continue;
      }
      final resolved = paths.resolveHref(href, paths.directoryUri);
      if (resolved == null ||
          resolved.origin != paths.base.origin ||
          resolved.hasQuery ||
          resolved.hasFragment ||
          resolved.userInfo.isNotEmpty ||
          !resolved.path.startsWith(paths.directoryUri.path)) {
        continue;
      }
      final name = resolved.pathSegments.lastOrNull;
      if (name == null ||
          !cloudBackupName.hasMatch(name) ||
          !seen.add(name) ||
          resolved != objectUri(name)) {
        continue;
      }
      if (item.descendants.whereType<XmlElement>().any(
        (e) => e.name.local == 'collection',
      )) {
        continue;
      }
      String? property(String key) => item.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == key)
          .firstOrNull
          ?.innerText;
      entries.add(
        CloudBackupEntry(
          providerId: 'webdav',
          objectName: name,
          targetFingerprint: config.fingerprint,
          createdAt: created(name),
          lastModified: DateTime.tryParse(property('getlastmodified') ?? ''),
          byteLength: int.tryParse(property('getcontentlength') ?? ''),
        ),
      );
    }
    return CloudBackupPage(entries);
  }
}
