import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../backup_service.dart' show decodeDatasetJson, encodeDatasetJson;

import 'credential_store.dart';
import 'sync_provider.dart';
import 'webdav_paths.dart';
import 'webdav_trace.dart';

/// A folder or file listed by `PROPFIND Depth: 1`.
class WebDavDirectoryEntry {
  const WebDavDirectoryEntry({
    required this.name,
    required this.path,
    required this.uri,
    required this.isCollection,
    this.size,
    this.etag,
  });

  /// Display name: `<d:displayname>` when the server sends one, otherwise the
  /// last decoded path segment.
  final String name;

  /// Decoded path relative to the configured base collection (`''` = base).
  final String path;
  final Uri uri;
  final bool isCollection;
  final int? size;
  final String? etag;

  @override
  String toString() => '${isCollection ? 'dir' : 'file'}:$path';
}

/// Sync through a plain WebDAV collection.
///
/// Three things stay strictly apart here, because mixing them is what made the
/// 坚果云 test fail:
///
/// 1. **the base collection** (`https://dav.jianguoyun.com/dav/`) — the server's
///    own mount point. It is probed and never created;
/// 2. **the user directory** (`MaterialWord`) — created one missing level at a
///    time, only below the base collection;
/// 3. **the data file** — written with a conditional request, never used as a
///    probe.
///
/// Concurrency still uses HTTP conditional requests: `If-Match: <etag>` when
/// updating, `If-None-Match: *` when creating. A 412 means "someone else wrote
/// first" and is reported as a conflict so the coordinator re-downloads.
///
/// The provider never claims more than it proved: [probeCapability] reports each
/// capability separately, and only `safeConditionalWrite` allows automatic
/// bidirectional sync.
enum WebDavPropfindProfile { collectionProbe, directoryListing, fileMetadata }

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
    this.traceDiagnostics = true,
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

  /// Mirrors request lines into the app diagnostics log (off by default there).
  /// Tests that assert on [trace] set this to false to stay independent.
  final bool traceDiagnostics;

  final CredentialStore _credentials;
  final http.Client? _client;
  final String? _usernameOverride;
  final String? _passwordOverride;
  ({String? username, String? password})? _capturedAuth;

  /// Requests of the most recent operation, redacted and bounded.
  WebDavTrace trace = WebDavTrace();

  /// Capability report of the most recent [probeCapability]/[testConnection].
  SyncCapability? lastCapability;

  Future<void> captureCredentials() => CredentialStore.exclusive(() async {
    _capturedAuth = null;
    _capturedAuth = await _auth();
  });

  void clearCapturedCredentials() {
    _capturedAuth = null;
    _propfindModes.clear();
    _collectionDepthOne = false;
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

  /// Resolved path model, or null when the configuration cannot describe a
  /// safe location (bad scheme, credentials in the URL, `..`, control chars…).
  WebDavPaths? get paths => WebDavPaths.resolve(
    baseUrl: baseUrl,
    remoteDir: remoteDir,
    fileName: fileName,
  );

  bool get isConfigured => paths != null;

  bool get isSecure => baseUrl.trim().toLowerCase().startsWith('https://');

  /// `https://host/dav/MaterialWord/`
  Uri? get directoryUri => paths?.directoryUri;

  /// `https://host/dav/MaterialWord/materialword-data.json`
  Uri? get fileUri => paths?.fileUri;

  /// Stable identity of everything a capability result depends on.
  ///
  /// Bound to the *normalised* address, the directory and file, the credential
  /// epoch and a hash of the user name — never the password, never the
  /// Authorization header. Used as the cache fingerprint, so changing any of
  /// them invalidates a previously verified capability.
  Future<String> capabilityFingerprint() async {
    final WebDavPaths? p = paths;
    final String user = (await _auth()).username ?? '';
    final String digest = sha256
        .convert(utf8.encode(user))
        .toString()
        .substring(0, 16);
    final String identity = jsonEncode(<Object?>[
      'webdav-cap-1',
      p?.base.toString() ?? baseUrl.trim(),
      p?.segments ?? const <String>[],
      p?.fileName ?? fileName,
      identityEpoch,
      digest,
    ]);
    return sha256.convert(utf8.encode(identity)).toString();
  }

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

  static String? _conditionalOf(Map<String, String> headers) {
    for (final MapEntry<String, String> entry in headers.entries) {
      final String key = entry.key.toLowerCase();
      if (key == 'if-match') return 'If-Match';
      if (key == 'if-none-match') return 'If-None-Match';
    }
    return null;
  }

  /// Manual redirect handling: credentials are only forwarded to the *same*
  /// origin, so a misconfigured server cannot leak them to a third party.
  ///
  /// Every round trip is recorded in [trace] with its stage, so a failure can be
  /// attributed to a specific request instead of being flattened into "403".
  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    List<int>? body,
    WebDavStage stage = WebDavStage.baseCollectionProbe,
    String? depth,
    String? propfindProfile,
    String? compatibilityMode,
  }) async {
    final String requestId = trace.nextRequestId();
    final String? conditional = _conditionalOf(headers);
    final Stopwatch watch = Stopwatch()..start();
    int redirects = 0;
    Uri current = uri;
    void record(http.Response? response, String result) {
      watch.stop();
      trace.add(
        WebDavTraceEntry(
          requestId: requestId,
          stage: stage,
          method: method,
          host: current.host,
          path: WebDavTrace.maskNonce(current.path),
          hasQuery: current.hasQuery,
          hasFragment: current.hasFragment,
          depth: depth,
          propfindProfile: propfindProfile,
          compatibilityMode: compatibilityMode,
          serverErrorCode: response != null && response.statusCode >= 400
              ? _serverErrorCode(response.body)
              : null,
          status: response?.statusCode,
          durationMs: watch.elapsedMilliseconds,
          redirects: redirects,
          conditional: conditional,
          etagKind: response == null
              ? null
              : strongEtag(response.headers['etag']) != null
              ? 'strong'
              : response.headers['etag'] != null
              ? 'weak'
              : null,
          responseContentType: response?.headers['content-type'],
          result: result,
        ),
      );
    }

    for (int hop = 0; hop <= maxRedirects; hop++) {
      final http.Request request = http.Request(method, current)
        ..followRedirects = false
        ..headers.addAll(headers);
      if (body != null) request.bodyBytes = body;
      http.StreamedResponse streamed;
      try {
        streamed = await _http
            .send(request)
            .timeout(const Duration(seconds: 45));
      } on TimeoutException {
        record(null, 'timeout');
        throw const SyncException('网络超时：请检查网络后重试', retryable: true);
      } on http.ClientException catch (e) {
        record(null, 'network_error');
        throw SyncException('网络请求失败：${e.message}', retryable: true);
      } catch (e) {
        if (e is SyncException) {
          record(null, 'network_error');
          rethrow;
        }
        record(null, 'network_error');
        throw SyncException('网络请求失败：$e', retryable: true);
      }
      final http.Response response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 45));
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final String? location = response.headers['location'];
        if (location == null) {
          record(response, 'ok');
          return response;
        }
        final Uri next = current.resolve(location);
        if (next.origin != current.origin || next.userInfo.isNotEmpty) {
          record(response, 'cross_origin_redirect');
          throw const SyncException('WebDAV 服务器重定向到其他主机，已拒绝携带认证信息继续请求');
        }
        record(response, 'redirect');
        watch
          ..reset()
          ..start();
        redirects++;
        current = next;
        continue;
      }
      record(response, response.statusCode >= 400 ? 'http_error' : 'ok');
      return response;
    }
    record(null, 'too_many_redirects');
    throw const SyncException('WebDAV 重定向次数过多');
  }

  /// Maps a status to a message that keeps the stage, the method and the path.
  Never _raise(
    http.Response response,
    String action, {
    WebDavStage? stage,
    String? method,
  }) {
    final int status = response.statusCode;
    final String where = stage == null
        ? ''
        : '（${stage.wire}${method == null ? '' : ' $method'}）';
    if (status == 401) {
      throw const SyncException('WebDAV 认证失败：用户名或密码错误');
    }
    if (status == 403) {
      throw SyncException(
        '服务器拒绝访问（HTTP 403$where）：$action 被拒绝，请检查账号权限、'
        '该文件夹是否只读，或服务商是否限制了此操作',
      );
    }
    if (status == 404) {
      throw SyncException('请求的路径不存在（HTTP 404$where）：$action');
    }
    if (status == 412) {
      throw const SyncConflictException('远程文件已被其他设备修改');
    }
    if (status == 507) {
      throw const SyncException('WebDAV 服务器存储空间不足');
    }
    if (status >= 500) {
      throw SyncException('WebDAV 服务器错误（HTTP $status$where）', retryable: true);
    }
    throw SyncException('WebDAV $action 失败（HTTP $status$where）');
  }

  static String _propfindBody(WebDavPropfindProfile profile) {
    final String properties = switch (profile) {
      WebDavPropfindProfile.collectionProbe => '<d:resourcetype/>',
      WebDavPropfindProfile.directoryListing =>
        '<d:resourcetype/><d:displayname/>',
      WebDavPropfindProfile.fileMetadata =>
        '<d:getetag/><d:getcontentlength/><d:getlastmodified/>',
    };
    return '<?xml version="1.0" encoding="utf-8"?>'
        '<d:propfind xmlns:d="DAV:"><d:prop>$properties'
        '</d:prop></d:propfind>';
  }

  final Map<WebDavPropfindProfile, String> _propfindModes =
      <WebDavPropfindProfile, String>{};
  bool _collectionDepthOne = false;

  static bool _requestRejected(int status) =>
      status == 400 || status == 405 || status == 415;

  Future<http.Response> _sendPropfind(
    Uri uri, {
    required String depth,
    required WebDavPropfindProfile profile,
    required WebDavStage stage,
  }) async {
    final String? preferred = _propfindModes[profile];
    final Set<String> modes = <String>{
      if (preferred != null) preferred,
      'application/xml',
      'text/xml',
      'no_body',
    };
    final authHeaders = await _headers();
    for (final String mode in modes) {
      final http.Response response = await _send(
        'PROPFIND',
        uri,
        headers: <String, String>{
          ...authHeaders,
          'Depth': depth,
          if (mode != 'no_body') 'Content-Type': '$mode; charset=utf-8',
        },
        body: mode == 'no_body' ? null : utf8.encode(_propfindBody(profile)),
        stage: stage,
        depth: depth,
        propfindProfile: profile.name,
        compatibilityMode: mode,
      );
      if (response.statusCode == 200 || response.statusCode == 207) {
        _propfindModes[profile] = mode;
      }
      if (!_requestRejected(response.statusCode) || mode == modes.last) {
        return response;
      }
    }
    throw StateError('Unreachable PROPFIND mode');
  }

  /// Extracts the ETag from a header or PROPFIND response.
  static String? strongEtag(String? value) {
    if (value == null) return null;
    final String tag = value.trim();
    // RFC 9110 entity-tag: retain the quotes; weak validators cannot protect PUT.
    return RegExp(r'^"[\x21\x23-\x7E\x80-\xFF]*"$').hasMatch(tag) ? tag : null;
  }

  static String? _serverErrorCode(String body) {
    if (!body.trimLeft().startsWith('<')) return null;
    try {
      final XmlDocument xml = XmlDocument.parse(body);
      const Set<String> knownCodes = <String>{
        'OperationNotAllowed',
        'valid-sync-token',
        'lock-token-submitted',
        'no-conflicting-lock',
      };
      for (final XmlElement element
          in xml.descendants.whereType<XmlElement>()) {
        final String code = element.name.local == 'exception'
            ? element.innerText.trim()
            : element.name.local;
        if (knownCodes.contains(code)) return code;
      }
      if (xml.rootElement.name.local == 'error') return 'dav_xml_error';
    } on XmlException {
      return null;
    }
    return null;
  }

  static String? _childText(XmlElement parent, String localName) => parent
      .childElements
      .where((XmlElement e) => e.name.local == localName)
      .map((XmlElement e) => e.innerText.trim())
      .where((String text) => text.isNotEmpty)
      .firstOrNull;

  /// Parses a `multistatus` body. Only `propstat` blocks with a 2xx status are
  /// trusted, so a per-property 404 cannot masquerade as a value.
  List<WebDavDirectoryEntry> _parseMultistatus(String body, Uri requested) {
    XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException {
      throw const SyncDataException('WebDAV 返回了无效的 XML');
    }
    final List<WebDavDirectoryEntry> entries = <WebDavDirectoryEntry>[];
    final WebDavPaths? model = paths;
    for (final XmlElement response
        in document.descendants.whereType<XmlElement>().where(
          (XmlElement e) => e.name.local == 'response',
        )) {
      final String? hrefText = _childText(response, 'href');
      if (hrefText == null) continue;
      final Uri? href = model?.resolveHref(hrefText, requested);
      if (href == null ||
          href.origin != requested.origin ||
          href.userInfo.isNotEmpty ||
          href.hasQuery ||
          href.hasFragment) {
        continue;
      }
      bool collection = false;
      int? size;
      String? displayName;
      String? etag;
      for (final XmlElement propstat in response.childElements.where(
        (XmlElement e) => e.name.local == 'propstat',
      )) {
        final String status = _childText(propstat, 'status') ?? '';
        if (!RegExp(r'\s2\d\d(?:\s|$)').hasMatch(status)) continue;
        for (final XmlElement prop in propstat.childElements.where(
          (XmlElement e) => e.name.local == 'prop',
        )) {
          final XmlElement? resourceType = prop.childElements
              .where((XmlElement e) => e.name.local == 'resourcetype')
              .firstOrNull;
          if (resourceType != null &&
              resourceType.descendants.whereType<XmlElement>().any(
                (XmlElement e) => e.name.local == 'collection',
              )) {
            collection = true;
          }
          etag ??= strongEtag(_childText(prop, 'getetag'));
          final String? length = _childText(prop, 'getcontentlength');
          if (length != null) size = int.tryParse(length);
          final String? name = _childText(prop, 'displayname');
          if (name != null) displayName = name;
        }
      }
      final String relative = model?.relativePathOf(href) ?? '';
      entries.add(
        WebDavDirectoryEntry(
          name: displayName ?? '',
          path: relative,
          uri: href,
          isCollection: collection,
          size: size,
          etag: etag,
        ),
      );
    }
    return entries;
  }

  /// `Depth: 0` by default; `Depth: 1` for browsing.
  Future<({int status, String? etag, int? length, String body})> _propfind(
    Uri uri, {
    String depth = '0',
    WebDavStage stage = WebDavStage.targetDirectoryProbe,
    WebDavPropfindProfile? profile,
  }) async {
    final WebDavPropfindProfile resolvedProfile =
        profile ??
        switch (stage) {
          WebDavStage.baseCollectionProbe ||
          WebDavStage.targetDirectoryProbe ||
          WebDavStage.directoryCreation =>
            WebDavPropfindProfile.collectionProbe,
          WebDavStage.directoryListing =>
            WebDavPropfindProfile.directoryListing,
          _ => WebDavPropfindProfile.fileMetadata,
        };
    final bool collection =
        resolvedProfile == WebDavPropfindProfile.collectionProbe;
    final String firstDepth = collection && _collectionDepthOne ? '1' : depth;
    Future<http.Response> send(String depth) => _sendPropfind(
      uri,
      depth: depth,
      profile: resolvedProfile,
      stage: stage,
    );
    http.Response response = await send(firstDepth);
    if (collection &&
        firstDepth == '0' &&
        (response.statusCode == 400 || response.statusCode == 405)) {
      response = await send('1');
      _collectionDepthOne =
          response.statusCode == 200 || response.statusCode == 207;
    }
    WebDavDirectoryEntry? self;
    if (response.statusCode == 207 || response.statusCode == 200) {
      final Uri requested = response.request?.url ?? uri;
      self = _parseMultistatus(
        response.body,
        requested,
      ).where((WebDavDirectoryEntry e) => e.uri == requested).firstOrNull;
    }
    return (
      status: response.statusCode,
      etag: self?.etag,
      length: self?.size,
      body: response.body,
    );
  }

  /// Reads the ETag of [uri] via PROPFIND (used when PUT does not echo one).
  Future<String?> _etagViaPropfind(Uri uri, WebDavStage stage) async {
    final probe = await _propfind(uri, stage: stage);
    if (probe.status == 404 || probe.status == 401 || probe.status == 403) {
      return null;
    }
    return probe.etag;
  }

  static bool _isSuccess(int status) =>
      status == 200 || status == 201 || status == 204;

  /// Creates the missing levels of [p] below the base collection.
  ///
  /// The base collection itself (`/dav/`) is *never* a MKCOL target: it belongs
  /// to the server's configuration, and asking for it is what produced
  /// `MKCOL /dav/ → 403 OperationNotAllowed` on 坚果云.
  ///
  /// Each level is checked with PROPFIND first, so an existing folder is never
  /// re-created, and every creation is verified before the next level starts.
  Future<void> _ensureDirectory(WebDavPaths p) async {
    if (p.segments.isEmpty) return;
    for (int depth = 1; depth <= p.segments.length; depth++) {
      final Uri target = p.directoryAt(depth);
      final existing = await _propfind(
        target,
        stage: WebDavStage.directoryCreation,
      );
      if (existing.status == 200 || existing.status == 207) continue;
      if (existing.status == 401) {
        throw const SyncException('WebDAV 认证失败：用户名或密码错误');
      }
      if (existing.status == 403) {
        throw SyncException(
          '服务器拒绝访问（HTTP 403，directory_creation PROPFIND）：'
          '无法读取 ${target.path}，请检查账号权限',
        );
      }
      if (existing.status == 404 || existing.status == 405) {
        // 404: this level is missing. 405: the server hides PROPFIND here but
        // may still accept MKCOL — try it, then verify.
      } else if (existing.status >= 500) {
        throw SyncException(
          'WebDAV 服务器错误（HTTP ${existing.status}，directory_creation PROPFIND）',
          retryable: true,
        );
      }

      final http.Response created = await _send(
        'MKCOL',
        target,
        headers: await _headers(),
        stage: WebDavStage.directoryCreation,
      );
      switch (created.statusCode) {
        case 200:
        case 201:
        case 204:
          break;
        case 405:
          // Already exists: fall through to the verification PROPFIND.
          break;
        case 401:
          throw const SyncException('WebDAV 认证失败：用户名或密码错误');
        case 403:
          throw SyncException(
            '服务器拒绝创建文件夹（HTTP 403，directory_creation MKCOL）：'
            '${target.path} 可能只读，或服务商不允许在基础目录下创建文件夹',
          );
        case 404:
        case 409:
          throw SyncException(
            '无法创建文件夹（HTTP ${created.statusCode}，directory_creation MKCOL）：'
            '${target.path} 的上级目录不存在，请检查服务器地址是否包含完整的服务路径',
          );
        case 507:
          throw const SyncException('WebDAV 服务器存储空间不足');
        default:
          if (created.statusCode >= 500) {
            throw SyncException(
              'WebDAV 服务器错误（HTTP ${created.statusCode}，directory_creation MKCOL）',
              retryable: true,
            );
          }
          throw SyncException(
            '创建文件夹失败（HTTP ${created.statusCode}，directory_creation MKCOL）：'
            '${target.path}',
          );
      }

      final verified = await _propfind(
        target,
        stage: WebDavStage.directoryCreation,
      );
      if (verified.status != 200 && verified.status != 207) {
        throw SyncException(
          '文件夹创建后仍无法访问（HTTP ${verified.status}，directory_creation PROPFIND）：'
          '${target.path}',
        );
      }
    }
  }

  /// Fills in everything that can be checked without writing.
  Future<SyncCapability> probeCapability({bool deep = true}) async {
    trace = WebDavTrace(mirror: traceDiagnostics);
    final WebDavPaths? p = paths;
    if (p == null) {
      return const SyncCapability(
        status: SyncCapabilityStatus.connectionFailed,
        detail: '服务器地址无效：需要 HTTPS 地址，且不能包含账号密码或 .. 路径',
      );
    }
    if (!isSecure) {
      return const SyncCapability(
        status: SyncCapabilityStatus.connectionFailed,
        detail: '只允许 HTTPS 地址（不会关闭 TLS 证书校验）',
      );
    }

    bool reachable = false;
    bool authenticated = false;
    bool directoryAccessible = false;
    bool baseProbed = false;
    bool listingSupported = false;

    try {
      // 1. The server's own base collection. Never created, never written.
      final base = await _propfind(
        p.base,
        stage: WebDavStage.baseCollectionProbe,
      );
      if (base.status == 401) {
        return const SyncCapability(
          status: SyncCapabilityStatus.authenticationFailed,
          reachable: true,
          failureStage: 'base_collection_probe',
          failureMethod: 'PROPFIND',
          failureStatus: 401,
          detail: '用户名或密码不正确',
        );
      }
      if (base.status >= 500) {
        return SyncCapability(
          status: SyncCapabilityStatus.connectionFailed,
          reachable: true,
          failureStage: 'base_collection_probe',
          failureMethod: 'PROPFIND',
          failureStatus: base.status,
          detail: '服务器返回 HTTP ${base.status}',
        );
      }
      if (base.status != 200 && base.status != 207) {
        return SyncCapability(
          status: _requestRejected(base.status)
              ? SyncCapabilityStatus.requestRejected
              : SyncCapabilityStatus.directoryUnavailable,
          reachable: true,
          failureStage: 'base_collection_probe',
          failureMethod: 'PROPFIND',
          failureStatus: base.status,
          detail: _requestRejected(base.status)
              ? '服务器无法处理当前 WebDAV 请求（HTTP ${base.status}）'
              : '服务器地址中的基础路径 ${p.basePath} 不存在或不可访问',
        );
      }
      reachable = true;
      authenticated = true;
      baseProbed = true;

      // 2. The user's directory, created level by level below the base.
      if (p.segments.isEmpty) {
        directoryAccessible = true;
      } else {
        var target = await _propfind(
          p.directoryUri,
          stage: WebDavStage.targetDirectoryProbe,
        );
        if (target.status == 404) {
          await _ensureDirectory(p);
          target = await _propfind(
            p.directoryUri,
            stage: WebDavStage.targetDirectoryProbe,
          );
        }
        if (target.status == 401) {
          return const SyncCapability(
            status: SyncCapabilityStatus.authenticationFailed,
            reachable: true,
            failureStage: 'target_directory_probe',
            failureMethod: 'PROPFIND',
            failureStatus: 401,
            detail: '用户名或密码不正确',
          );
        }
        if (target.status == 403) {
          return SyncCapability(
            status: SyncCapabilityStatus.directoryUnavailable,
            reachable: true,
            authenticated: true,
            failureStage: 'target_directory_probe',
            failureMethod: 'PROPFIND',
            failureStatus: 403,
            detail: '无权访问 ${p.directoryPath}，请检查账号权限或改用其他目录',
          );
        }
        if (target.status != 200 && target.status != 207) {
          return SyncCapability(
            status:
                target.status == 400 ||
                    target.status == 405 ||
                    target.status == 415
                ? SyncCapabilityStatus.requestRejected
                : SyncCapabilityStatus.directoryUnavailable,
            reachable: true,
            authenticated: target.status == 404,
            failureStage: 'target_directory_probe',
            failureMethod: 'PROPFIND',
            failureStatus: target.status,
            detail: '文件夹 ${p.directoryPath} 不可用（HTTP ${target.status}）',
          );
        }
        directoryAccessible = true;
      }

      // A Depth: 1 listing is optional for syncing but required for the folder
      // picker, so it is recorded instead of being treated as a failure.
      final listing = await _propfind(
        p.directoryUri,
        depth: '1',
        stage: WebDavStage.directoryListing,
      );
      listingSupported = listing.status == 207 || listing.status == 200;

      // 3. The data file: presence, size and ETag. Read-only here.
      final fileProbe = await _propfind(
        p.fileUri,
        stage: WebDavStage.dataFileProbe,
      );

      SyncCapability baseCapability = SyncCapability(
        status: deep
            ? SyncCapabilityStatus.readOnly
            : SyncCapabilityStatus.unknown,
        reachable: reachable,
        authenticated: authenticated,
        directoryAccessible: directoryAccessible,
        canRead: fileProbe.status == 200 || fileProbe.status == 207,
        baseCollectionProbed: baseProbed,
        directoryListingSupported: listingSupported,
      );

      if (!deep) return baseCapability;

      // 4 + 5. Write probes on a resource we own.
      final _WriteProbe probe = await _probeWrites(p);
      final bool conditionalOk =
          probe.supportsStrongEtag &&
          probe.supportsIfMatch &&
          probe.supportsIfNoneMatch;
      final SyncCapabilityStatus status;
      if (!probe.canCreate || !probe.canUpdate) {
        status = SyncCapabilityStatus.readOnly;
      } else if (conditionalOk) {
        status = SyncCapabilityStatus.safeConditionalWrite;
      } else {
        status = SyncCapabilityStatus.basicReadWrite;
      }
      return baseCapability.copyWith(
        status: status,
        canRead: probe.canRead || baseCapability.canRead,
        canCreate: probe.canCreate,
        canUpdate: probe.canUpdate,
        canDelete: probe.canDelete,
        supportsStrongEtag: probe.supportsStrongEtag,
        supportsIfMatch: probe.supportsIfMatch,
        supportsIfNoneMatch: probe.supportsIfNoneMatch,
        probeCleanedUp: probe.cleanedUp,
        failureStage: probe.issue == null ? null : 'basic_write_probe',
        failureMethod: probe.issueMethod,
        failureStatus: probe.issueStatus,
        detail: probe.issue,
      );
    } on SyncException catch (e) {
      final WebDavTraceEntry? last = trace.entries.isEmpty
          ? null
          : trace.entries.last;
      final bool authFailure = last?.status == 401;
      return SyncCapability(
        status: authFailure
            ? SyncCapabilityStatus.authenticationFailed
            : reachable
            ? SyncCapabilityStatus.directoryUnavailable
            : SyncCapabilityStatus.connectionFailed,
        reachable: reachable,
        authenticated: authenticated,
        directoryAccessible: directoryAccessible,
        baseCollectionProbed: baseProbed,
        directoryListingSupported: listingSupported,
        failureStage: last?.stage.wire,
        failureMethod: last?.method,
        failureStatus: last?.status,
        detail: e.message,
      );
    }
  }

  /// One owned probe resource: conditional create first, plain PUT as fallback.
  ///
  /// The file is a *normal* `.json` name with a random nonce — hidden files and
  /// `.txt` extensions are rejected by some commercial services for reasons that
  /// have nothing to do with WebDAV, and they made a working server look broken.
  Future<_WriteProbe> _probeWrites(WebDavPaths p) async {
    final String nonce = const Uuid().v4();
    final Uri uri = p.directoryUri.replace(
      path: '${p.directoryUri.path}materialword-probe-$nonce.json',
    );
    if (uri == p.fileUri) {
      // Defensive: a probe must never be the real document.
      return _WriteProbe()..issue = '探测路径与数据文件冲突，已跳过写入测试';
    }
    const String contentType = 'application/json; charset=utf-8';
    final Map<String, String> common = await _headers(
      extra: <String, String>{'Content-Type': contentType},
    );
    final String initial = jsonEncode(<String, Object?>{
      'probe': nonce,
      'revision': 1,
    });
    final String changed = jsonEncode(<String, Object?>{
      'probe': nonce,
      'revision': 2,
    });
    final List<int> initialBytes = utf8.encode(initial);
    final List<int> changedBytes = utf8.encode(changed);

    final _WriteProbe result = _WriteProbe();
    bool owned = false;
    String? tag;

    Future<void> cleanup() async {
      final String? deleteTag =
          tag ?? await _etagViaPropfind(uri, WebDavStage.probeCleanup);
      final http.Response removed = await _send(
        'DELETE',
        uri,
        headers: <String, String>{...common, 'If-Match': deleteTag ?? '*'},
        stage: WebDavStage.probeCleanup,
      );
      if (removed.statusCode == 200 ||
          removed.statusCode == 204 ||
          removed.statusCode == 404 ||
          removed.statusCode == 412) {
        // 412 on cleanup means somebody else changed our probe; a second plain
        // DELETE would be safe, but the resource is not the user's data either
        // way and we prefer not to force it.
        result.cleanedUp = true;
        return;
      }
      result.cleanedUp = false;
      result.cleanupIssue =
          '临时探测文件清理失败（HTTP ${removed.statusCode}，probe_cleanup）：'
          '请手动删除 ${p.directoryPath} 下以 materialword-probe- 开头的文件';
    }

    try {
      // --- conditional create -------------------------------------------------
      final http.Response created = await _send(
        'PUT',
        uri,
        headers: <String, String>{...common, 'If-None-Match': '*'},
        body: initialBytes,
        stage: WebDavStage.conditionalCreateProbe,
      );
      if (created.statusCode == 401) {
        throw const SyncException('WebDAV 认证失败：用户名或密码错误');
      }
      if (_isSuccess(created.statusCode)) {
        owned = true;
        result.canCreate = true;
        tag =
            strongEtag(created.headers['etag']) ??
            await _etagViaPropfind(uri, WebDavStage.conditionalCreateProbe);
        result.supportsStrongEtag = tag != null;
        if (tag == null) {
          result.issue = _etagIssue;
        }
      } else if (created.statusCode == 412) {
        result.issue = '服务器拒绝了 If-None-Match 创建（HTTP 412），无法保证并发安全';
        result.issueMethod = 'PUT';
        result.issueStatus = 412;
      } else if (created.statusCode == 403) {
        result.issue = '服务器拒绝在该文件夹创建文件（HTTP 403）';
        result.issueMethod = 'PUT';
        result.issueStatus = 403;
      } else if (created.statusCode == 404) {
        result.issue = '服务器拒绝在该文件夹创建文件（HTTP 404）：路径不存在或该目录不允许写入文件';
        result.issueMethod = 'PUT';
        result.issueStatus = 404;
      } else {
        result.issue = '条件创建失败（HTTP ${created.statusCode}），无法保证并发安全';
        result.issueMethod = 'PUT';
        result.issueStatus = created.statusCode;
      }

      // --- plain write fallback ----------------------------------------------
      // Only ever on this throwaway resource: it distinguishes "cannot write"
      // from "cannot write conditionally", which is the difference between
      // "unsupported server" and "permission problem".
      if (!owned) {
        final http.Response plain = await _send(
          'PUT',
          uri,
          headers: common,
          body: initialBytes,
          stage: WebDavStage.basicWriteProbe,
        );
        if (plain.statusCode == 401) {
          throw const SyncException('WebDAV 认证失败：用户名或密码错误');
        }
        if (_isSuccess(plain.statusCode)) {
          owned = true;
          result.canCreate = true;
          tag =
              strongEtag(plain.headers['etag']) ??
              await _etagViaPropfind(uri, WebDavStage.basicWriteProbe);
          result.supportsStrongEtag = tag != null;
        } else if (plain.statusCode == 403) {
          result.issue ??= '服务器拒绝写入该文件夹（HTTP 403），账号可能只有只读权限';
          result.issueMethod = 'PUT';
          result.issueStatus = 403;
        } else if (plain.statusCode == 404) {
          result.issue ??= '服务器拒绝在该文件夹创建文件（HTTP 404）：路径不存在或该目录不允许写入文件';
          result.issueMethod = 'PUT';
          result.issueStatus = 404;
        } else {
          result.issue ??= '无法创建临时测试文件（HTTP ${plain.statusCode}）';
          result.issueMethod = 'PUT';
          result.issueStatus = plain.statusCode;
        }
      }

      if (!owned) return result;

      // --- read back ---------------------------------------------------------
      final http.Response read = await _send(
        'GET',
        uri,
        headers: common,
        stage: WebDavStage.basicWriteProbe,
      );
      if (read.statusCode == 200) {
        result.canRead = true;
        if (read.body != initial) {
          result.issue ??= '写入后读回的内容不一致，服务器可能未保存文件内容';
        }
      } else {
        result.issue ??= '写入后无法读回文件（HTTP ${read.statusCode}）';
      }

      // --- conditional semantics --------------------------------------------
      if (tag != null) {
        final http.Response stale = await _send(
          'PUT',
          uri,
          headers: <String, String>{
            ...common,
            'If-Match': '"materialword-stale-$nonce"',
          },
          body: changedBytes,
          stage: WebDavStage.conditionalStaleUpdateProbe,
        );
        result.supportsIfMatch = stale.statusCode == 412;
        if (!result.supportsIfMatch) {
          result.issue ??=
              '服务器未拒绝过期的 If-Match（HTTP ${stale.statusCode}），无法检测并发修改';
          result.issueMethod = 'PUT';
          result.issueStatus = stale.statusCode;
        }

        // Read the bytes back *before* the next experiment: the If-None-Match
        // test is expected to be rejected, yet a server that ignores it will
        // overwrite the probe, which would look like "If-Match did not hold".
        final http.Response unchanged = await _send(
          'GET',
          uri,
          headers: common,
          stage: WebDavStage.conditionalStaleUpdateProbe,
        );
        if (unchanged.statusCode != 200 ||
            unchanged.body != initial ||
            strongEtag(unchanged.headers['etag']) != tag) {
          result.issue ??= '条件请求失败后探测文件仍被修改，服务器未真正执行条件写入';
          result.supportsIfMatch = false;
        }

        final http.Response exists = await _send(
          'PUT',
          uri,
          headers: <String, String>{...common, 'If-None-Match': '*'},
          body: changedBytes,
          stage: WebDavStage.conditionalExistingCreateProbe,
        );
        result.supportsIfNoneMatch = exists.statusCode == 412;
        if (!result.supportsIfNoneMatch) {
          result.issue ??=
              '服务器未拒绝已存在文件的 If-None-Match（HTTP ${exists.statusCode}），首次写入无法防止覆盖';
          result.issueMethod = 'PUT';
          result.issueStatus = exists.statusCode;
        }

        final http.Response update = await _send(
          'PUT',
          uri,
          headers: <String, String>{...common, 'If-Match': tag},
          body: changedBytes,
          stage: WebDavStage.conditionalValidUpdateProbe,
        );
        if (_isSuccess(update.statusCode)) {
          final http.Response after = await _send(
            'GET',
            uri,
            headers: common,
            stage: WebDavStage.conditionalValidUpdateProbe,
          );
          final String? nextTag = strongEtag(after.headers['etag']);
          if (after.statusCode == 200 &&
              after.body == changed &&
              nextTag != null &&
              nextTag != tag) {
            result.canUpdate = true;
            tag = nextTag;
          } else {
            result.issue ??= result.endlesslySameEtag(nextTag, tag)
                ? '更新后 ETag 没有变化，服务器未维护版本标识'
                : '更新内容或强 ETag 校验失败';
            result.supportsStrongEtag =
                result.supportsStrongEtag && nextTag != null;
          }
        } else {
          result.issue ??= '服务器拒绝有效的 If-Match 更新（HTTP ${update.statusCode}）';
          result.issueMethod = 'PUT';
          result.issueStatus = update.statusCode;
        }
      } else {
        // No usable validator: at least prove that plain updates work, so the
        // report can say "read/write works, concurrency does not".
        final http.Response plainUpdate = await _send(
          'PUT',
          uri,
          headers: common,
          body: changedBytes,
          stage: WebDavStage.basicWriteProbe,
        );
        if (_isSuccess(plainUpdate.statusCode)) {
          final http.Response after = await _send(
            'GET',
            uri,
            headers: common,
            stage: WebDavStage.basicWriteProbe,
          );
          result.canUpdate = after.statusCode == 200 && after.body == changed;
          tag = strongEtag(after.headers['etag']) ?? tag;
        }
      }
    } finally {
      if (owned) {
        try {
          await cleanup();
        } catch (e) {
          result.cleanedUp = false;
          result.cleanupIssue ??= '临时探测文件清理失败：$e';
        }
      }
    }

    if (owned) result.canDelete = result.cleanedUp;
    if (result.cleanupIssue != null) {
      result.issue = result.issue == null
          ? result.cleanupIssue
          : '${result.issue}；${result.cleanupIssue}';
    }
    return result;
  }

  String get _etagIssue => '服务器没有返回强 ETag（只会返回弱 ETag 或不返回），无法检测并发修改';

  @override
  Future<SyncTestResult> testConnection() async {
    if (!isConfigured) {
      return SyncTestResult(
        ok: false,
        message: '请填写 WebDAV 服务器地址',
        capability: const SyncCapability(
          status: SyncCapabilityStatus.connectionFailed,
          detail: '地址无效',
        ),
      );
    }
    if (!isSecure) {
      return SyncTestResult(
        ok: false,
        message: '只允许 HTTPS 地址（不会关闭 TLS 证书校验）',
        capability: const SyncCapability(
          status: SyncCapabilityStatus.connectionFailed,
          detail: '不是 HTTPS 地址',
        ),
      );
    }
    try {
      final SyncCapability capability = await probeCapability(deep: true);
      lastCapability = capability;
      final List<String> details = <String>[];
      final WebDavPaths? p = paths;
      if (p != null && capability.directoryAccessible) {
        details.add('目录可访问：${p.directoryPath}');
      }
      if (capability.canRead &&
          capability.status == SyncCapabilityStatus.safeConditionalWrite) {
        details.add('数据文件可读取，强 ETag 可用');
      }
      if (capability.canRead &&
          capability.canCreate &&
          capability.canUpdate &&
          capability.canDelete) {
        details.add('基础读写验证通过：创建、读回、更新、删除');
      }
      if (capability.safeBidirectionalSync) {
        details.add('已验证 If-Match、If-None-Match、更新与读回 ETag');
      } else if (capability.status == SyncCapabilityStatus.basicReadWrite) {
        details.add(
          'NO_CONDITIONAL_WRITE:${capability.detail ?? '服务器无法验证条件写入'}，'
          '请使用手动文件备份',
        );
      }
      if (capability.detail != null &&
          capability.status != SyncCapabilityStatus.safeConditionalWrite &&
          !details.any((String d) => d.contains(capability.detail!))) {
        details.add('诊断：${capability.detail!}');
      }
      if (capability.directoryListingSupported) {
        details.add('支持浏览远程文件夹');
      }
      final bool connected =
          capability.status == SyncCapabilityStatus.safeConditionalWrite ||
          capability.status == SyncCapabilityStatus.basicReadWrite ||
          capability.status == SyncCapabilityStatus.readOnly;
      return SyncTestResult(
        ok: connected,
        message: connected
            ? capability.status.name
            : '${capability.status.name}: ${capability.detail ?? ''}'.trim(),
        details: details,
        capability: capability,
      );
    } on SyncException catch (e) {
      lastCapability = SyncCapability(
        status: SyncCapabilityStatus.connectionFailed,
        detail: e.message,
      );
      return SyncTestResult(ok: false, message: e.message);
    } on TimeoutException {
      return const SyncTestResult(ok: false, message: 'WebDAV 请求超时，请检查网络');
    } catch (e) {
      return SyncTestResult(ok: false, message: '连接失败：$e');
    }
  }

  /// `PROPFIND Depth: 1` — the folder browser.
  ///
  /// [path] is decoded and relative to the configured base collection ('' is
  /// the base itself). Entries outside the base collection and links to another
  /// origin are dropped, so a hostile or broken server cannot redirect the
  /// browser (or the credentials) somewhere else.
  Future<List<WebDavDirectoryEntry>> listDirectories({String path = ''}) async {
    final WebDavPaths? p = paths;
    if (p == null || !isSecure) {
      throw const SyncException('请先填写有效的 HTTPS WebDAV 地址');
    }
    final Uri? target = p.collectionForPath(path);
    if (target == null) {
      throw const SyncException('目录名无效：不能包含 .. 或控制字符');
    }
    trace = WebDavTrace(mirror: traceDiagnostics);
    final http.Response response = await _sendPropfind(
      target,
      depth: '1',
      profile: WebDavPropfindProfile.directoryListing,
      stage: WebDavStage.directoryListing,
    );
    if (response.statusCode == 401) {
      throw const SyncException('WebDAV 认证失败：用户名或密码错误');
    }
    if (response.statusCode == 403) {
      throw SyncException(
        '服务器拒绝读取该文件夹（HTTP 403，directory_listing PROPFIND）：${target.path}',
      );
    }
    if (response.statusCode == 404) {
      throw SyncException('文件夹不存在（HTTP 404）：${target.path}');
    }
    if (response.statusCode != 207 && response.statusCode != 200) {
      _raise(
        response,
        '浏览目录',
        stage: WebDavStage.directoryListing,
        method: 'PROPFIND',
      );
    }

    final String selfPath = p.relativePathOf(target) ?? '';
    final List<WebDavDirectoryEntry> entries = <WebDavDirectoryEntry>[];
    for (final WebDavDirectoryEntry entry in _parseMultistatus(
      response.body,
      response.request?.url ?? target,
    )) {
      if (entry.uri.origin != p.base.origin) continue;
      if (p.relativePathOf(entry.uri) == null) continue;
      final String prefix = selfPath.isEmpty ? '' : '$selfPath/';
      if (!entry.path.startsWith(prefix)) continue;
      final String child = entry.path.substring(prefix.length);
      if (child.isEmpty || child.contains('/')) continue;
      final String segment =
          entry.path.split('/').where((String s) => s.isNotEmpty).lastOrNull ??
          '';
      if (segment.isEmpty) continue;
      entries.add(
        WebDavDirectoryEntry(
          name: entry.name.isEmpty ? segment : entry.name,
          path: entry.path,
          uri: entry.uri,
          isCollection: entry.isCollection,
          size: entry.size,
        ),
      );
    }
    entries.sort((WebDavDirectoryEntry a, WebDavDirectoryEntry b) {
      if (a.isCollection != b.isCollection) return a.isCollection ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// Creates one collection below the base (used by the folder picker).
  Future<void> createDirectory(String path) async {
    final WebDavPaths? p = paths;
    if (p == null || !isSecure) {
      throw const SyncException('请先填写有效的 HTTPS WebDAV 地址');
    }
    final Uri? target = p.collectionForPath(path);
    if (target == null || target.path == p.basePath) {
      throw const SyncException('不能在服务器基础路径上创建文件夹');
    }
    trace = WebDavTrace(mirror: traceDiagnostics);
    final http.Response response = await _send(
      'MKCOL',
      target,
      headers: await _headers(),
      stage: WebDavStage.directoryCreation,
    );
    if (response.statusCode == 201 ||
        response.statusCode == 200 ||
        response.statusCode == 204) {
      return;
    }
    if (response.statusCode == 405) return; // already exists
    if (response.statusCode == 401) {
      throw const SyncException('WebDAV 认证失败：用户名或密码错误');
    }
    if (response.statusCode == 403) {
      throw SyncException(
        '服务器拒绝创建文件夹（HTTP 403，directory_creation MKCOL）：${target.path}',
      );
    }
    if (response.statusCode == 409 || response.statusCode == 404) {
      throw SyncException(
        '无法创建文件夹（HTTP ${response.statusCode}，directory_creation MKCOL）：'
        '上级目录不存在',
      );
    }
    _raise(
      response,
      '创建目录',
      stage: WebDavStage.directoryCreation,
      method: 'MKCOL',
    );
  }

  /// PROPFIND only: returns the strong ETag without transferring the document.
  @override
  Future<RemoteProbe> probeRemote() async {
    if (!isConfigured || !isSecure) return const RemoteProbe.unsupported();
    final p = paths!;
    final probe = await _propfind(p.fileUri, stage: WebDavStage.dataFileProbe);
    if (probe.status == 404) return const RemoteProbe.missing();
    if (probe.status != 207 && probe.status != 200) {
      _raise(
        http.Response('', probe.status),
        '检查远程版本',
        stage: WebDavStage.dataFileProbe,
        method: 'PROPFIND',
      );
    }
    final String? etag = probe.etag;
    // A server without strong ETags cannot support conditional writes, so it
    // also cannot answer "did it change" — that is unknown, not unchanged.
    return etag == null
        ? const RemoteProbe.unsupported()
        : RemoteProbe.revision(etag);
  }

  @override
  Future<String?> remoteRevision() async => (await probeRemote()).revision;

  @override
  Future<RemoteDataset> fetchRemote() async {
    final WebDavPaths? p = paths;
    if (p == null || !isSecure) {
      throw const SyncException('请配置有效的 HTTPS WebDAV 地址');
    }
    trace = WebDavTrace(mirror: traceDiagnostics);
    http.Response response = await _send(
      'GET',
      p.fileUri,
      headers: await _headers(
        extra: <String, String>{'Accept': 'application/json'},
      ),
      stage: WebDavStage.datasetDownload,
    );
    if (response.statusCode == 404) return const RemoteDataset.missing();
    if (response.statusCode != 200) {
      _raise(
        response,
        '读取数据',
        stage: WebDavStage.datasetDownload,
        method: 'GET',
      );
    }
    String? etag = strongEtag(response.headers['etag']);
    if (etag == null) {
      final probe = await _propfind(
        p.fileUri,
        stage: WebDavStage.datasetDownload,
      );
      etag = probe.etag;
      if (etag != null) {
        // Pair the bytes with this validator. A PROPFIND after an unconditional
        // GET may describe a newer document we have never read.
        response = await _send(
          'GET',
          p.fileUri,
          headers: await _headers(
            extra: <String, String>{
              'Accept': 'application/json',
              'If-Match': etag,
            },
          ),
          stage: WebDavStage.datasetDownload,
        );
        if (response.statusCode != 200) {
          _raise(
            response,
            '读取数据',
            stage: WebDavStage.datasetDownload,
            method: 'GET',
          );
        }
      }
    }
    final List<int> bytes = response.bodyBytes;
    final String text = utf8.decode(bytes, allowMalformed: true);
    if (text.trim().isEmpty) {
      // A file the user created by hand (or that another tool truncated). It
      // exists and has a revision — it is not the same as "no file yet".
      return RemoteDataset.empty(revision: etag, rawLength: bytes.length);
    }
    Object? decoded;
    try {
      decoded = await decodeDatasetJson(text);
    } on FormatException {
      throw const SyncDataException('远程数据文件不是合法 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const SyncDataException('远程数据文件根节点必须是对象');
    }
    return RemoteDataset.valid(
      SyncPayload(
        dataset: decoded,
        revision: etag,
        contentHash: etag,
        rawLength: bytes.length,
      ),
    );
  }

  @override
  Future<SyncPayload?> download() async {
    final RemoteDataset remote = await fetchRemote();
    return switch (remote.state) {
      RemoteDatasetState.missing => null,
      RemoteDatasetState.empty => throw SyncEmptyRemoteException(
        remote.revision == null
            ? '远程同步文件为空（0 字节），且服务器未返回 ETag，无法安全初始化'
            : '远程同步文件为空（0 字节）',
      ),
      RemoteDatasetState.valid => remote.payload,
    };
  }

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async {
    final WebDavPaths? p = paths;
    if (p == null || !isSecure) {
      throw const SyncException('请配置有效的 HTTPS WebDAV 地址');
    }
    if (ifRevision != null &&
        ifRevision.isNotEmpty &&
        strongEtag(ifRevision) == null) {
      throw const SyncException('服务器未提供强 ETag，请使用手动备份');
    }
    trace = WebDavTrace(mirror: traceDiagnostics);
    final List<int> bytes = utf8.encode(await encodeDatasetJson(dataset));
    final Map<String, String> conditional =
        ifRevision != null && ifRevision.isNotEmpty
        ? <String, String>{'If-Match': ifRevision}
        : <String, String>{'If-None-Match': '*'};

    Future<http.Response> put() async => _send(
      'PUT',
      p.fileUri,
      headers: await _headers(
        extra: <String, String>{
          ...conditional,
          'Content-Type': 'application/json; charset=utf-8',
        },
      ),
      body: bytes,
      stage: WebDavStage.datasetUpload,
    );

    http.Response response = await put();
    if (response.statusCode == 409 || response.statusCode == 404) {
      // Directory missing: create it and retry exactly once. The data file is
      // still written with the same condition, so this cannot overwrite anyone.
      await _ensureDirectory(p);
      response = await put();
    }
    if (response.statusCode == 412) {
      throw const SyncConflictException('远程文件已被其他设备修改');
    }
    if (_isSuccess(response.statusCode)) {
      String? etag = strongEtag(response.headers['etag']);
      if (etag == null || etag.isEmpty) {
        final probe = await _propfind(
          p.fileUri,
          stage: WebDavStage.datasetVerification,
        );
        etag = probe.etag;
      }
      return SyncUploadResult(
        ok: true,
        message: '已写入 ${p.fileUri.path}',
        revision: etag,
      );
    }
    _raise(response, '写入数据', stage: WebDavStage.datasetUpload, method: 'PUT');
  }
}

/// Mutable probe accumulator.
class _WriteProbe {
  _WriteProbe();

  bool canRead = false;
  bool canCreate = false;
  bool canUpdate = false;
  bool canDelete = false;
  bool supportsStrongEtag = false;
  bool supportsIfMatch = false;
  bool supportsIfNoneMatch = false;
  bool cleanedUp = true;
  String? issue;
  String? issueMethod;
  int? issueStatus;
  String? cleanupIssue;

  /// True when the update produced a *new* strong ETag — i.e. the server really
  /// tracks versions instead of echoing the old validator.
  bool endlesslySameEtag(String? next, String? current) =>
      next != null && current != null && next == current;
}
