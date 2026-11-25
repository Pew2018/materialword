import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:uuid/uuid.dart';

import '../backup_service.dart' show encodeDatasetJson, decodeDatasetJson;

import 'credential_store.dart';
import 'sync_provider.dart';

/// Sync through a plain WebDAV collection.
///
/// Concurrency uses HTTP conditional requests: `If-Match: <etag>` when we are
/// updating an existing file, `If-None-Match: *` when we are creating it. A 412
/// means "someone else wrote first" and is reported as a conflict so the
/// coordinator re-downloads and merges.
///
/// The provider never claims more than the server can do: if the server does not
/// return an ETag, conditional writes cannot work, and the sync page refuses to
/// enable *automatic* sync for that account (see `SyncTestResult.details`).
class WebDavSyncProvider implements SyncProvider {
  WebDavSyncProvider({
    required this.baseUrl,
    this.remoteDir = 'materialword',
    this.fileName = 'materialword-data.json',
    this.identityEpoch = '',
    CredentialStore? credentials,
    http.Client? client,
    String? usernameOverride,
    String? passwordOverride,
  }) : _credentials = credentials ?? SecureCredentialStore(),
       _client = client,
       _usernameOverride = usernameOverride,
       _passwordOverride = passwordOverride;

  WebDavSyncProvider.fromConfig(
    Map<String, Object?> config, {
    CredentialStore? credentials,
    http.Client? client,
    String? usernameOverride,
    String? passwordOverride,
  }) : this(
         baseUrl: (config['url'] as String?) ?? '',
         remoteDir: (config['dir'] as String?) ?? '',
         fileName: (config['file'] as String?) ?? 'materialword-data.json',
         identityEpoch: (config['credentialEpoch'] as String?) ?? '',
         credentials: credentials,
         client: client,
         usernameOverride: usernameOverride,
         passwordOverride: passwordOverride,
       );

  WebDavSyncProvider.placeholder()
    : this(baseUrl: '', credentials: InMemoryCredentialStore());

  final String baseUrl;
  final String remoteDir;
  final String fileName;
  final String identityEpoch;

  final CredentialStore _credentials;
  final http.Client? _client;
  final String? _usernameOverride;
  final String? _passwordOverride;
  ({String? username, String? password})? _capturedAuth;

  Future<void> captureCredentials() => CredentialStore.exclusive(() async {
    _capturedAuth = null;
    _capturedAuth = await _auth();
  });

  void clearCapturedCredentials() {
    _capturedAuth = null;
  }

  static const int maxRedirects = 3;

  @override
  String get id => 'webdav';

  @override
  String get label => 'WebDAV';

  @override
  bool get isImplemented => true;

  @override
  bool get requiresNetwork => true;

  @override
  bool get supportsConditionalWrites => true;

  @override
  String get description => '通过 HTTPS + ETag 条件请求同步到自建 WebDAV 目录。';

  http.Client? _ownedClient;
  http.Client get _http => _client ?? (_ownedClient ??= http.Client());

  void close() {
    _ownedClient?.close();
    _ownedClient = null;
  }

  bool get isConfigured {
    final Uri? uri = Uri.tryParse(baseUrl.trim());
    return uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        fileName.isNotEmpty &&
        fileName != '.' &&
        fileName != '..' &&
        !fileName.contains('/') &&
        !fileName.contains('\\') &&
        !remoteDir.split('/').any((part) => part == '.' || part == '..') &&
        !RegExp(r'[\r\n]').hasMatch(remoteDir + fileName);
  }

  bool get isSecure => baseUrl.trim().toLowerCase().startsWith('https://');

  Uri get _base => Uri.parse(baseUrl.trim());

  Uri get _directoryUri {
    final String base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final String dir = remoteDir
        .split('/')
        .where((String s) => s.trim().isNotEmpty)
        .map((String s) => Uri.encodeComponent(s.trim()))
        .join('/');
    return Uri.parse(dir.isEmpty ? '$base/' : '$base/$dir/');
  }

  Uri get _fileUri =>
      _directoryUri.replace(path: '${_directoryUri.path}$fileName');

  Future<({String? username, String? password})> _auth() async {
    if (_capturedAuth != null) return _capturedAuth!;
    try {
      final String? username =
          _usernameOverride ??
          await _credentials.read(CredentialKeys.webdavUsername);
      final String? password =
          _passwordOverride ??
          await _credentials.read(CredentialKeys.webdavPassword);
      return (username: username, password: password);
    } on CredentialStoreUnavailable catch (e) {
      // Same as GitHub: the Keychain refused, so ask for the password again
      // instead of sending an unauthenticated request.
      throw SyncException('${e.reason}，请到「数据同步」页重新输入 WebDAV 账号密码。');
    }
  }

  Future<Map<String, String>> _headers({
    bool withAuth = true,
    Map<String, String> extra = const <String, String>{},
  }) async {
    final auth = await _auth();
    final Map<String, String> headers = <String, String>{
      'User-Agent': 'MaterialWord',
      ...extra,
    };
    if (withAuth && auth.username != null && auth.password != null) {
      headers['Authorization'] =
          'Basic ${base64Encode(utf8.encode('${auth.username}:${auth.password}'))}';
    }
    return headers;
  }

  /// Manual redirect handling: credentials are only forwarded to the *same*
  /// host, so a misconfigured server cannot leak them to a third party.
  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    List<int>? body,
  }) async {
    Uri current = uri;
    bool keepAuth = true;
    for (int hop = 0; hop <= maxRedirects; hop++) {
      final http.Request request = http.Request(method, current)
        ..followRedirects = false
        ..headers.addAll(
          keepAuth
              ? headers
              : (Map<String, String>.from(headers)..remove('Authorization')),
        );
      if (body != null) request.bodyBytes = body;
      http.StreamedResponse streamed;
      try {
        streamed = await _http
            .send(request)
            .timeout(const Duration(seconds: 45));
      } on TimeoutException {
        throw const SyncException('网络超时：请检查网络后重试', retryable: true);
      } on http.ClientException catch (e) {
        throw SyncException('网络请求失败：${e.message}', retryable: true);
      } catch (e) {
        if (e is SyncException) rethrow;
        throw SyncException('网络请求失败：$e', retryable: true);
      }
      final http.Response response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 45));
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final String? location = response.headers['location'];
        if (location == null) return response;
        final Uri next = current.resolve(location);
        if (next.origin != current.origin) {
          throw const SyncException('WebDAV 服务器重定向到其他主机，已拒绝携带认证信息继续请求');
        }
        keepAuth = true;
        current = next;
        continue;
      }
      return response;
    }
    throw const SyncException('WebDAV 重定向次数过多');
  }

  Never _raise(http.Response response, String action) {
    final int status = response.statusCode;
    if (status == 401) {
      throw const SyncException('WebDAV 认证失败：用户名或密码错误');
    }
    if (status == 403) {
      throw const SyncException('WebDAV 拒绝访问：请检查目录权限');
    }
    if (status == 404) {
      throw SyncException('WebDAV 路径不存在：$remoteDir');
    }
    if (status == 412) {
      throw const SyncConflictException('远程文件已被其他设备修改');
    }
    if (status == 507) {
      throw const SyncException('WebDAV 服务器存储空间不足');
    }
    if (status >= 500) {
      throw SyncException('WebDAV 服务器错误（HTTP $status）', retryable: true);
    }
    throw SyncException('WebDAV $action 失败（HTTP $status）');
  }

  static const String _propfindBody =
      '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:"><d:prop>'
      '<d:getetag/><d:getcontentlength/><d:getlastmodified/><d:resourcetype/>'
      '</d:prop></d:propfind>';

  /// Extracts the ETag from a PROPFIND response.
  static String? strongEtag(String? value) {
    if (value == null) return null;
    final String tag = value.trim();
    // RFC 9110 entity-tag: retain the quotes; weak validators cannot protect PUT.
    return RegExp(r'^"[\x21\x23-\x7E\x80-\xFF]*"$').hasMatch(tag) ? tag : null;
  }

  String? _etagOf(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      for (final response in document.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'response' && e.namespaceUri == 'DAV:',
      )) {
        for (final propstat in response.childElements.where(
          (e) => e.name.local == 'propstat',
        )) {
          final status =
              propstat.childElements
                  .where((e) => e.name.local == 'status')
                  .firstOrNull
                  ?.innerText ??
              '';
          if (!RegExp(r'HTTP/\S+ 200(?: |$)').hasMatch(status)) continue;
          for (final tag in propstat.descendants.whereType<XmlElement>().where(
            (e) => e.name.local == 'getetag' && e.namespaceUri == 'DAV:',
          )) {
            final value = strongEtag(tag.innerText);
            if (value != null) return value;
          }
        }
      }
      return null;
    } on XmlException {
      throw const SyncDataException('WebDAV 返回了无效的 XML');
    }
  }

  Future<({int status, String? etag, String body})> _propfind(
    Uri uri,
    String method,
  ) async {
    final http.Response response = await _send(
      method,
      uri,
      headers: await _headers(
        extra: <String, String>{
          'Depth': '0',
          'Content-Type': 'application/xml; charset=utf-8',
        },
      ),
      body: utf8.encode(_propfindBody),
    );
    return (
      status: response.statusCode,
      etag: response.statusCode == 207 || response.statusCode == 200
          ? _etagOf(response.body)
          : null,
      body: response.body,
    );
  }

  /// Creates [dir] and every missing parent. 405 (already exists) is fine.
  Future<void> _ensureDirectory(Uri dir) async {
    final List<String> segments = dir.pathSegments
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
    final StringBuffer path = StringBuffer('/');
    for (int i = 0; i < segments.length; i++) {
      path.write(segments[i]);
      path.write('/');
      final Uri target = dir.replace(path: path.toString());
      final http.Response response = await _send(
        'MKCOL',
        target,
        headers: await _headers(),
      );
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 405 ||
          response.statusCode == 301) {
        continue;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        _raise(response, '创建目录');
      }
      // 409 = parent missing (retry next loop), anything else is tolerated so a
      // server that hides MKCOL still gets a chance to serve the PUT.
    }
  }

  /// Exercise conditionals on an owned, unguessable temporary resource. Never
  /// test a broken server's conditional support by touching the user's dataset.
  Future<String?> _verifyConditionalWrites() async {
    final nonce = const Uuid().v4();
    final uri = _directoryUri.replace(
      path: '${_directoryUri.path}.materialword-probe-$nonce.txt',
    );
    final initial = 'MaterialWord probe $nonce';
    final changed = 'MaterialWord probe updated $nonce';
    bool created = false;
    String? issue;
    String? cleanupTag;
    // Resolve credentials once, but keep all redirects origin-checked in _send.
    final headers = await _headers(
      extra: {'Content-Type': 'text/plain; charset=utf-8'},
    );
    Future<http.Response> write(
      String content,
      Map<String, String> condition,
    ) => _send(
      'PUT',
      uri,
      headers: {...headers, ...condition},
      body: utf8.encode(content),
    );
    Future<String?> check() async {
      final first = await write(initial, {'If-None-Match': '*'});
      if (first.statusCode == 401 || first.statusCode == 403) {
        _raise(first, '条件写入测试');
      }
      if (![200, 201, 204].contains(first.statusCode)) {
        return '无法创建临时测试文件（HTTP ${first.statusCode}）';
      }
      created = true;
      cleanupTag = strongEtag(first.headers['etag']);
      if (cleanupTag == null) {
        final read = await _send('GET', uri, headers: headers);
        cleanupTag = strongEtag(read.headers['etag']);
      }
      final tag = cleanupTag;
      if (tag == null) return '服务器没有返回强 ETag';
      final stale = await write('must not be accepted', {
        'If-Match': '"materialword-stale-$nonce"',
      });
      if (stale.statusCode != 412) return '服务器未拒绝过期 If-Match';
      final exists = await write('must not be accepted', {
        'If-None-Match': '*',
      });
      if (exists.statusCode != 412) return '服务器未拒绝已存在文件的 If-None-Match';
      final before = await _send('GET', uri, headers: headers);
      if (before.statusCode != 200 ||
          before.body != initial ||
          strongEtag(before.headers['etag']) != tag) {
        return '条件请求失败后测试文件仍被修改';
      }
      final update = await write(changed, {'If-Match': tag});
      if (![200, 201, 204].contains(update.statusCode)) {
        return '服务器拒绝有效的 If-Match 更新';
      }
      final after = await _send('GET', uri, headers: headers);
      cleanupTag = strongEtag(after.headers['etag']);
      if (after.statusCode != 200 ||
          after.body != changed ||
          cleanupTag == null ||
          cleanupTag == tag) {
        return '更新内容或强 ETag 校验失败';
      }
      return null;
    }

    try {
      issue = await check();
    } finally {
      if (created) {
        try {
          final current = await _send('GET', uri, headers: headers);
          final tag = strongEtag(current.headers['etag']);
          final removed = await _send(
            'DELETE',
            uri,
            headers: {...headers, 'If-Match': tag ?? '*'},
          );
          if (![200, 204, 404].contains(removed.statusCode)) {
            issue ??= '服务器无法清理临时测试文件';
          }
        } catch (_) {
          issue ??= '临时测试文件清理失败，请检查目录权限';
        }
      }
    }
    return issue;
  }

  @override
  Future<SyncTestResult> testConnection() async {
    if (!isConfigured) {
      return const SyncTestResult(ok: false, message: '请填写 WebDAV 服务器地址');
    }
    if (!isSecure) {
      return const SyncTestResult(
        ok: false,
        message: '只允许 HTTPS 地址（不会关闭 TLS 证书校验）',
      );
    }
    try {
      final List<String> details = <String>[];
      final probe = await _propfind(_directoryUri, 'PROPFIND');
      if (probe.status == 404) {
        await _ensureDirectory(_directoryUri);
        details.add('已建立同步目录');
      } else if (probe.status != 207 && probe.status != 200) {
        _raise(http.Response('', probe.status), '连接测试');
      } else {
        details.add('目录可访问：${_directoryUri.path}');
      }

      final fileProbe = await _propfind(_fileUri, 'PROPFIND');
      if (fileProbe.status == 207 || fileProbe.status == 200) {
        if (fileProbe.etag == null) {
          details.add('NO_CONDITIONAL_WRITE:服务器未返回 ETag，无法检测并发修改');
        } else {
          details.add('数据文件已存在并返回强 ETag');
        }
      } else if (fileProbe.status == 404) {
        details.add('数据文件尚未创建，首次同步会写入并读取服务器返回的 ETag');
      }
      final issue = await _verifyConditionalWrites();
      if (issue != null) {
        details.add('NO_CONDITIONAL_WRITE:$issue，请使用手动文件备份');
      } else {
        details.add('已验证 If-Match、If-None-Match、更新与读回 ETag');
      }
      return SyncTestResult(
        ok: true,
        message: issue == null ? '已连接 ${_base.host}' : '服务器不支持安全双向同步',
        details: details,
      );
    } on SyncException catch (e) {
      return SyncTestResult(ok: false, message: e.message);
    } on TimeoutException {
      return const SyncTestResult(ok: false, message: 'WebDAV 请求超时，请检查网络');
    } catch (e) {
      return SyncTestResult(ok: false, message: '连接失败：$e');
    }
  }

  /// PROPFIND only: returns the strong ETag without transferring the document.
  @override
  Future<String?> remoteRevision() async {
    if (!isConfigured || !isSecure) return null;
    final probe = await _propfind(_fileUri, 'PROPFIND');
    if (probe.status == 404) return null;
    if (probe.status != 207 && probe.status != 200) {
      _raise(http.Response('', probe.status), '检查远程版本');
    }
    return probe.etag;
  }

  @override
  Future<SyncPayload?> download() async {
    if (!isConfigured || !isSecure) {
      throw const SyncException('请配置有效的 HTTPS WebDAV 地址');
    }
    http.Response response = await _send(
      'GET',
      _fileUri,
      headers: await _headers(
        extra: <String, String>{'Accept': 'application/json'},
      ),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _raise(response, '读取数据');
    String? etag = strongEtag(response.headers['etag']);
    if (etag == null) {
      final probe = await _propfind(_fileUri, 'PROPFIND');
      etag = probe.etag;
      if (etag != null) {
        // Pair the bytes with this validator. A PROPFIND after an unconditional
        // GET may describe a newer document we have never read.
        response = await _send(
          'GET',
          _fileUri,
          headers: await _headers(
            extra: {'Accept': 'application/json', 'If-Match': etag},
          ),
        );
        if (response.statusCode != 200) _raise(response, '读取数据');
      }
    }
    Object? decoded;
    try {
      decoded = await decodeDatasetJson(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const SyncDataException('远程数据文件不是合法 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const SyncDataException('远程数据文件根节点必须是对象');
    }
    return SyncPayload(
      dataset: decoded,
      revision: etag,
      contentHash: etag,
      rawLength: response.bodyBytes.length,
    );
  }

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async {
    if (!isConfigured || !isSecure) {
      throw const SyncException('请配置有效的 HTTPS WebDAV 地址');
    }
    if (ifRevision != null && strongEtag(ifRevision) == null) {
      throw const SyncException('服务器未提供强 ETag，请使用手动备份');
    }
    final List<int> bytes = utf8.encode(await encodeDatasetJson(dataset));
    final Map<String, String> conditional =
        ifRevision != null && ifRevision.isNotEmpty
        ? <String, String>{'If-Match': ifRevision}
        : <String, String>{'If-None-Match': '*'};

    Future<http.Response> put() async => _send(
      'PUT',
      _fileUri,
      headers: await _headers(
        extra: <String, String>{
          ...conditional,
          'Content-Type': 'application/json; charset=utf-8',
        },
      ),
      body: bytes,
    );

    http.Response response = await put();
    if (response.statusCode == 409 || response.statusCode == 404) {
      // Directory missing: create it and retry exactly once.
      await _ensureDirectory(_directoryUri);
      response = await put();
    }
    if (response.statusCode == 412) {
      throw const SyncConflictException('远程文件已被其他设备修改');
    }
    if (response.statusCode == 201 ||
        response.statusCode == 204 ||
        response.statusCode == 200) {
      String? etag = strongEtag(response.headers['etag']);
      if (etag == null || etag.isEmpty) {
        final probe = await _propfind(_fileUri, 'PROPFIND');
        etag = probe.etag;
      }
      return SyncUploadResult(
        ok: true,
        message: '已写入 ${_fileUri.path}',
        revision: etag,
      );
    }
    _raise(response, '写入数据');
  }
}
