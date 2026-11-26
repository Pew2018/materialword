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

part 'webdav_snapshot_store.dart';

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

class WebDavSyncProvider
    implements SyncProvider, VerifiableSyncProvider, SessionScopedSyncProvider {
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
  @override
  SyncCapability? lastCapability;

  @override
  Future<void> captureCredentials() => CredentialStore.exclusive(() async {
    clearCapturedCredentials();
    _capturedAuth = await _auth();
  });

  @override
  void clearCapturedCredentials() {
    _capturedAuth = null;
    lastCapability = null;
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

  @override
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
  @override
  Future<String> capabilityFingerprint() async {
    final WebDavPaths? p = paths;
    final String user = (await _auth()).username ?? '';
    final String digest = sha256
        .convert(utf8.encode(user))
        .toString()
        .substring(0, 16);
    final String identity = jsonEncode(<Object?>[
      'webdav-cap-2',
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
    final String probeName = uri.pathSegments.lastOrNull ?? '';
    final bool probeResource = probeName.startsWith('materialword-probe-');
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
          roundId: trace.roundId,
          stage: stage,
          method: method,
          host: current.host,
          path: stage == WebDavStage.snapshotTransfer
              ? '/<snapshot>'
              : WebDavTrace.maskNonce(current.path),
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
              : etagKind(response.headers['etag']),
          etagSource: switch (method) {
            'PUT' => 'put_header',
            'GET' => 'get_header',
            'HEAD' => 'head_header',
            _ => null,
          },
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
      } on http.ClientException {
        record(null, 'network_error');
        throw const SyncException('网络请求失败：请检查网络后重试', retryable: true);
      } catch (e) {
        if (e is SyncException) {
          record(null, 'network_error');
          rethrow;
        }
        record(null, 'network_error');
        throw const SyncException('网络请求失败：请检查网络后重试', retryable: true);
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
        if (stage == WebDavStage.snapshotTransfer && next != uri) {
          record(response, 'snapshot_redirect_rejected');
          throw const SyncException('WebDAV 重定向改变了快照请求的目标');
        }
        if (probeResource &&
            (next.pathSegments.lastOrNull != probeName ||
                next.hasQuery ||
                next.hasFragment)) {
          record(response, 'probe_redirect_rejected');
          throw const SyncException('WebDAV 重定向改变了临时探测文件的目标');
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
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
        reasonPhrase: response.reasonPhrase,
      );
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
    if (status == 429) {
      throw const SyncException('WebDAV 请求过于频繁，请稍后重试', retryable: true);
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
      ?preferred,
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
          if (stage == WebDavStage.snapshotTransfer)
            'Cache-Control': 'no-cache',
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

  // RFC 9110 entity-tag. A comma is legal inside the quoted opaque value.
  static final RegExp _entityTag = RegExp(
    r'^(?:W/)?"[\x21\x23-\x7E\x80-\xFF]*"$',
  );

  static String etagKind(String? value) {
    if (value == null) return 'absent';
    final String tag = value.trim();
    if (!_entityTag.hasMatch(tag)) return 'malformed';
    return tag.startsWith('W/') ? 'weak' : 'strong';
  }

  static String? strongEtag(String? value) =>
      etagKind(value) == 'strong' ? value!.trim() : null;

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

  static String _multistatusBody(http.Response response) {
    final String contentType = response.headers['content-type'] ?? '';
    if (RegExp(
      r';\s*charset\s*=',
      caseSensitive: false,
    ).hasMatch(contentType)) {
      return response.body;
    }
    // WebDAV XML is commonly UTF-8 with no HTTP charset parameter.
    return utf8.decode(response.bodyBytes);
  }

  ({String? tag, String kind, String match, String propstat}) _fileEtag(
    String body,
    Uri requested,
  ) {
    final XmlElement root = XmlDocument.parse(body).rootElement;
    Iterable<XmlElement> davChildren(XmlElement parent, String name) => parent
        .childElements
        .where((e) => e.name.local == name && e.namespaceUri == 'DAV:');
    const missing = (
      tag: null,
      kind: 'absent',
      match: 'missing',
      propstat: 'missing',
    );
    const ambiguous = (
      tag: null,
      kind: 'absent',
      match: 'ambiguous',
      propstat: 'missing',
    );
    if (root.name.local != 'multistatus' || root.namespaceUri != 'DAV:') {
      return missing;
    }
    final matches = <XmlElement>[];
    for (final element in davChildren(root, 'response')) {
      final hrefs = davChildren(element, 'href').toList();
      final int matched = hrefs.where((href) {
        final String raw = href.innerText.trim();
        return WebDavPaths.matchesFileHref(raw, requested);
      }).length;
      if (matched == 0) continue;
      if (hrefs.length != 1) return ambiguous;
      matches.add(element);
    }
    if (matches.isEmpty) return missing;
    if (matches.length != 1) return ambiguous;
    final properties = <({int? status, String value})>[];
    for (final propstat in davChildren(matches.single, 'propstat')) {
      final statuses = davChildren(propstat, 'status').toList();
      final int? status = statuses.length == 1
          ? int.tryParse(
              RegExp(r'^HTTP/\d+(?:\.\d+)?\s+(\d{3})(?:\s|$)')
                      .firstMatch(statuses.single.innerText.trim())
                      ?.group(1) ??
                  '',
            )
          : null;
      for (final prop in davChildren(propstat, 'prop')) {
        for (final etag in davChildren(prop, 'getetag')) {
          properties.add((status: status, value: etag.innerText));
        }
      }
    }
    if (properties.isEmpty) {
      return (tag: null, kind: 'absent', match: 'matched', propstat: 'missing');
    }
    if (properties.length != 1) return ambiguous;
    final property = properties.single;
    final int? code = property.status;
    return (
      tag: code != null && code >= 200 && code < 300
          ? strongEtag(property.value)
          : null,
      kind: etagKind(property.value),
      match: 'matched',
      propstat: switch (code) {
        200 => '200',
        404 => '404',
        null => 'missing',
        _ => 'other',
      },
    );
  }

  /// `Depth: 0` by default; `Depth: 1` for browsing.
  Future<({int status, Uri uri, String? etag, int? length, String body})>
  _propfind(
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
    final Uri requested = response.request?.url ?? uri;
    WebDavDirectoryEntry? self;
    String? fileTag;
    String body = '';
    if (response.statusCode == 207 || response.statusCode == 200) {
      final bool fileMetadata =
          resolvedProfile == WebDavPropfindProfile.fileMetadata;
      try {
        body = _multistatusBody(response);
        self = _parseMultistatus(
          body,
          requested,
        ).where((WebDavDirectoryEntry e) => e.uri == requested).firstOrNull;
      } on FormatException {
        if (!fileMetadata) {
          throw const SyncDataException('WebDAV 返回了无法解码的 XML');
        }
        body = '';
      } on SyncDataException {
        if (!fileMetadata) rethrow;
        body = '';
      }
      if (fileMetadata) {
        final evidence = body.isEmpty
            ? (tag: null, kind: 'absent', match: 'missing', propstat: 'missing')
            : _fileEtag(body, requested);
        fileTag = evidence.tag;
        trace.add(
          WebDavTraceEntry(
            requestId: trace.nextRequestId(),
            roundId: trace.roundId,
            stage: stage,
            method: 'PROPFIND',
            host: requested.host,
            path: WebDavTrace.maskNonce(requested.path),
            status: response.statusCode,
            durationMs: 0,
            etagSource: 'propfind_self_xml',
            etagKind: evidence.kind,
            selfMatch: evidence.match,
            getetagPropstat: evidence.propstat,
          ),
        );
      }
    }
    return (
      status: response.statusCode,
      uri: requested,
      etag: fileTag,
      length: self?.size,
      body: body,
    );
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
  @override
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
          probe.cleanedUp &&
          probe.supportsStrongEtag &&
          probe.supportsIfMatch &&
          probe.supportsIfNoneMatch;
      SyncCapabilityStatus status;
      if (!probe.canCreate || !probe.canUpdate) {
        status = SyncCapabilityStatus.readOnly;
      } else if (conditionalOk) {
        status = SyncCapabilityStatus.safeConditionalWrite;
      } else {
        status = SyncCapabilityStatus.basicReadWrite;
      }
      if (!conditionalOk &&
          !probe.supportsStrongEtag &&
          probe.duplicateOverwrote &&
          listingSupported &&
          probe.canCreate &&
          probe.canRead) {
        try {
          await WebDavSnapshotStore(this).verifyAccess();
          status = SyncCapabilityStatus.safeSnapshotWrite;
        } on SyncException {
          // Retain the negative single-file result if the alternate transport
          // cannot be verified. Never write the shared legacy file.
        }
      }
      return baseCapability.copyWith(
        status: status,
        canRead: probe.canRead || baseCapability.canRead,
        canCreate: probe.canCreate,
        canUpdate: probe.canUpdate,
        canDelete: probe.canDelete,
        supportsStrongEtag: probe.supportsStrongEtag,
        supportsConditionalRead: probe.supportsConditionalRead && conditionalOk,
        supportsIfMatch: probe.supportsIfMatch,
        supportsIfNoneMatch: probe.supportsIfNoneMatch,
        probeCleanedUp: probe.cleanedUp,
        failureStage: probe.duplicateOverwrote
            ? 'duplicate_create_probe'
            : probe.issue == null
            ? null
            : 'basic_write_probe',
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
    Uri? ownedTarget;
    String? tag;

    Future<http.Response> get(WebDavStage stage, {String? match}) => _send(
      'GET',
      uri,
      headers: <String, String>{...common, 'If-Match': ?match},
      stage: stage,
    );

    Future<http.Response> put(
      WebDavStage stage,
      List<int> bytes,
      Map<String, String> condition,
    ) => _send(
      'PUT',
      uri,
      headers: <String, String>{...common, ...condition},
      body: bytes,
      stage: stage,
    );

    void outcome(
      WebDavStage stage,
      String method,
      String status, {
      bool? etagChanged,
      String? probeContent,
    }) {
      trace.add(
        WebDavTraceEntry(
          requestId: trace.nextRequestId(),
          roundId: trace.roundId,
          stage: stage,
          method: method,
          host: uri.host,
          path: WebDavTrace.maskNonce(uri.path),
          status: null,
          durationMs: 0,
          conditionOutcome: status,
          etagChanged: etagChanged,
          probeContent: probeContent,
        ),
      );
    }

    bool matches(http.Response response, String expected) =>
        response.statusCode == 200 && response.body == expected;

    final String bogus = '"materialword-stale-$nonce"';
    Future<String?> boundTag(
      WebDavStage stage,
      http.Response read,
      http.Response write,
      String expected,
      ({int status, Uri uri, String? etag, int? length, String body}) metadata,
    ) async {
      if (!matches(read, expected)) return null;
      final String? header = strongEtag(read.headers['etag']);
      if (header != null) return header;

      final Uri? target = read.request?.url;
      if (target == null) return null;
      final String? candidate =
          (metadata.uri == target ? metadata.etag : null) ??
          await _headEtag(uri, target, stage) ??
          (write.request?.url == target
              ? strongEtag(write.headers['etag'])
              : null);
      if (candidate == null || candidate == bogus) return null;

      final http.Response stale = await get(stage, match: bogus);
      final http.Response paired = await get(stage, match: candidate);
      final bool verified =
          stale.statusCode == 412 &&
          stale.request?.url == target &&
          paired.request?.url == target &&
          matches(paired, expected) &&
          _consistentWithTag(paired, candidate);
      outcome(stage, 'GET', verified ? 'passed' : 'rejected');
      if (!verified) return null;
      result.supportsConditionalRead = true;
      return candidate;
    }

    try {
      final http.Response created = await put(
        WebDavStage.conditionalCreateProbe,
        initialBytes,
        const <String, String>{'If-None-Match': '*'},
      );
      if (created.statusCode == 401) {
        throw const SyncException('WebDAV 认证失败：用户名或密码错误');
      }
      if (!_isSuccess(created.statusCode)) {
        return result
          ..issue = '无法创建临时测试文件（HTTP ${created.statusCode}）'
          ..issueMethod = 'PUT'
          ..issueStatus = created.statusCode;
      }

      final http.Response read = await get(WebDavStage.basicWriteProbe);
      owned =
          matches(read, initial) && read.request?.url == created.request?.url;
      if (!owned) {
        return result..issue = '写入后无法确认临时测试文件的内容与归属';
      }
      ownedTarget = read.request?.url;
      result
        ..canCreate = true
        ..canRead = true;
      final metadata = await _propfind(uri, stage: WebDavStage.basicWriteProbe);
      tag = await boundTag(
        WebDavStage.basicWriteProbe,
        read,
        created,
        initial,
        metadata,
      );
      result.supportsStrongEtag = tag != null;

      final http.Response duplicate = await put(
        WebDavStage.conditionalExistingCreateProbe,
        changedBytes,
        const <String, String>{'If-None-Match': '*'},
      );
      final http.Response afterDuplicate = await get(
        WebDavStage.conditionalExistingCreateProbe,
      );
      final bool sameTarget =
          afterDuplicate.request?.url == ownedTarget &&
          duplicate.request?.url == ownedTarget;
      final bool duplicateUnchanged =
          sameTarget && matches(afterDuplicate, initial);
      final bool duplicateOverwroteProbe =
          sameTarget && matches(afterDuplicate, changed);
      result.duplicateOverwrote = duplicateOverwroteProbe;
      result.supportsIfNoneMatch =
          duplicate.statusCode == 412 && duplicateUnchanged;
      outcome(
        WebDavStage.conditionalExistingCreateProbe,
        'PUT',
        result.supportsIfNoneMatch
            ? 'passed'
            : duplicateOverwroteProbe
            ? 'ignored'
            : 'rejected',
        probeContent: duplicateUnchanged
            ? 'unchanged'
            : duplicateOverwroteProbe
            ? 'overwritten'
            : 'unverified',
      );
      String beforeUpdate = initial;
      String afterUpdate = changed;
      List<int> updateBytes = changedBytes;
      if (!result.supportsIfNoneMatch) {
        result
          ..issue = '服务器未通过已有文件防覆盖验证'
          ..issueMethod = 'PUT'
          ..issueStatus = duplicate.statusCode;
        if (duplicateOverwroteProbe) {
          // The overwrite itself demonstrated basic I/O. Independently test
          // If-Match against the version now present on our own probe.
          result.canUpdate = true;
          beforeUpdate = changed;
          afterUpdate = initial;
          updateBytes = initialBytes;
          final currentMetadata =
              strongEtag(afterDuplicate.headers['etag']) == null
              ? await _propfind(
                  uri,
                  stage: WebDavStage.conditionalExistingCreateProbe,
                )
              : metadata;
          tag = await boundTag(
            WebDavStage.conditionalExistingCreateProbe,
            afterDuplicate,
            duplicate,
            beforeUpdate,
            currentMetadata,
          );
          result.supportsStrongEtag = tag != null;
        } else if (!duplicateUnchanged) {
          outcome(WebDavStage.conditionalStaleUpdateProbe, 'PUT', 'skipped');
          outcome(WebDavStage.conditionalValidUpdateProbe, 'PUT', 'skipped');
          return result;
        }
      }

      if (tag == null || tag == bogus) {
        outcome(WebDavStage.conditionalStaleUpdateProbe, 'PUT', 'skipped');
        outcome(WebDavStage.conditionalValidUpdateProbe, 'PUT', 'skipped');
        result.issue ??= _etagIssue;
        if (result.canUpdate) return result;
        // Only our own verified file is used to confirm basic update support.
        final http.Response updated = await put(
          WebDavStage.basicWriteProbe,
          updateBytes,
          const <String, String>{},
        );
        final http.Response after = await get(WebDavStage.basicWriteProbe);
        result.canUpdate =
            _isSuccess(updated.statusCode) &&
            matches(after, afterUpdate) &&
            updated.request?.url == ownedTarget &&
            after.request?.url == ownedTarget;
        return result;
      }

      final http.Response stale = await put(
        WebDavStage.conditionalStaleUpdateProbe,
        updateBytes,
        <String, String>{'If-Match': bogus},
      );
      final http.Response afterStale = await get(
        WebDavStage.conditionalStaleUpdateProbe,
      );
      final bool staleUnchanged =
          matches(afterStale, beforeUpdate) &&
          afterStale.request?.url == ownedTarget &&
          stale.request?.url == ownedTarget &&
          _consistentWithTag(afterStale, tag);
      result.supportsIfMatch = stale.statusCode == 412 && staleUnchanged;
      outcome(
        WebDavStage.conditionalStaleUpdateProbe,
        'PUT',
        result.supportsIfMatch
            ? 'passed'
            : _isSuccess(stale.statusCode) || !staleUnchanged
            ? 'ignored'
            : 'rejected',
      );
      if (!result.supportsIfMatch) {
        outcome(WebDavStage.conditionalValidUpdateProbe, 'PUT', 'skipped');
        return result
          ..canUpdate = matches(afterStale, afterUpdate)
          ..issue ??= '服务器未通过过期版本防覆盖验证'
          ..issueMethod = 'PUT'
          ..issueStatus = stale.statusCode;
      }

      final http.Response update = await put(
        WebDavStage.conditionalValidUpdateProbe,
        updateBytes,
        <String, String>{'If-Match': tag},
      );
      final http.Response after = await get(
        WebDavStage.conditionalValidUpdateProbe,
      );
      result.canUpdate =
          _isSuccess(update.statusCode) &&
          matches(after, afterUpdate) &&
          after.request?.url == update.request?.url &&
          after.request?.url == read.request?.url;
      final nextMetadata =
          (result.canUpdate && strongEtag(after.headers['etag']) == null)
          ? await _propfind(uri, stage: WebDavStage.conditionalValidUpdateProbe)
          : metadata;
      final String? nextTag = result.canUpdate
          ? await boundTag(
              WebDavStage.conditionalValidUpdateProbe,
              after,
              update,
              afterUpdate,
              nextMetadata,
            )
          : null;
      final bool tagChanged = nextTag != null && nextTag != tag;
      if (tagChanged && result.supportsConditionalRead) {
        final http.Response previous = await get(
          WebDavStage.conditionalValidUpdateProbe,
          match: tag,
        );
        result.supportsConditionalRead =
            previous.statusCode == 412 &&
            previous.request?.url == read.request?.url;
        outcome(
          WebDavStage.conditionalValidUpdateProbe,
          'GET',
          result.supportsConditionalRead ? 'passed' : 'ignored',
        );
        if (!result.supportsConditionalRead) result.supportsStrongEtag = false;
      }
      outcome(
        WebDavStage.conditionalValidUpdateProbe,
        'PUT',
        tagChanged ? 'passed' : 'rejected',
        etagChanged: tagChanged,
      );
      if (!tagChanged) {
        result
          ..supportsStrongEtag = false
          ..issue = '更新后的内容无法关联到不同的强 ETag'
          ..issueMethod = 'PUT'
          ..issueStatus = update.statusCode;
      } else if (strongEtag(after.headers['etag']) == null &&
          nextMetadata.etag != nextTag &&
          await _headEtag(
                uri,
                ownedTarget!,
                WebDavStage.conditionalValidUpdateProbe,
              ) !=
              nextTag) {
        result.supportsStrongEtag = false;
        result.issue ??= '只能在写入响应取得强 ETag，无法安全读取远程版本';
      } else if (!result.supportsStrongEtag) {
        result.issue = '服务器未通过过期版本的条件读取验证';
      }
    } finally {
      if (owned) {
        result.cleanedUp = false;
        try {
          final http.Response current = await get(WebDavStage.probeCleanup);
          if (current.request?.url == ownedTarget &&
              current.statusCode == 404) {
            result.cleanedUp = true;
          } else if (current.request?.url == ownedTarget &&
              (matches(current, initial) || matches(current, changed))) {
            final http.Response removed = await _send(
              'DELETE',
              ownedTarget!,
              headers: <String, String>{
                ...common,
                'If-Match': strongEtag(current.headers['etag']) ?? '*',
              },
              stage: WebDavStage.probeCleanup,
            );
            result.cleanedUp =
                removed.request?.url == ownedTarget &&
                (_isSuccess(removed.statusCode) || removed.statusCode == 404);
          }
        } catch (_) {
          // The trace keeps the request outcome without embedding response data.
        }
        outcome(
          WebDavStage.probeCleanup,
          'DELETE',
          result.cleanedUp ? 'passed' : 'rejected',
        );
        result.canDelete = result.cleanedUp;
        if (!result.cleanedUp) {
          result.issue ??= '未能确认临时探测文件已清理';
        }
      }
    }
    return result;
  }

  /// A HEAD validator is only a candidate. Callers must bind it to the
  /// downloaded representation with a verified conditional GET.
  Future<String?> _headEtag(Uri uri, Uri target, WebDavStage stage) async {
    final http.Response response = await _send(
      'HEAD',
      uri,
      headers: await _headers(
        extra: const <String, String>{'Accept': 'application/json'},
      ),
      stage: stage,
    );
    return response.statusCode == 200 && response.request?.url == target
        ? strongEtag(response.headers['etag'])
        : null;
  }

  static bool _consistentWithTag(http.Response response, String tag) {
    final String? header = strongEtag(response.headers['etag']);
    return header == null || header == tag;
  }

  String get _etagIssue => '无法确认与文件内容对应的强 ETag，无法安全同步';

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
      if (capability.status == SyncCapabilityStatus.safeSnapshotWrite) {
        details.add('已验证独立同步快照可以发布、列出和读取');
      } else if (capability.safeBidirectionalSync) {
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
          capability.safeBidirectionalSync ||
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
      _multistatusBody(response),
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
    if (etag == null && lastCapability?.supportsConditionalRead == true) {
      final probe = await _propfind(
        p.fileUri,
        stage: WebDavStage.datasetDownload,
      );
      final Uri target = response.request!.url;
      etag =
          (probe.uri == target ? probe.etag : null) ??
          await _headEtag(p.fileUri, target, WebDavStage.datasetDownload);
      if (etag != null) {
        // Pair the bytes with this validator. A PROPFIND after an unconditional
        // GET may describe a newer document we have never read.
        final http.Response paired = await _send(
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
        if (paired.statusCode != 200) {
          _raise(
            paired,
            '读取数据',
            stage: WebDavStage.datasetDownload,
            method: 'GET',
          );
        }
        if (paired.request?.url != target ||
            !_consistentWithTag(paired, etag)) {
          throw const SyncConflictException('无法确认远程内容对应的版本');
        }
        response = paired;
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
      final String? etag = strongEtag(response.headers['etag']);
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

  bool duplicateOverwrote = false;
  bool canRead = false;
  bool canCreate = false;
  bool canUpdate = false;
  bool canDelete = false;
  bool supportsStrongEtag = false;
  bool supportsConditionalRead = false;
  bool supportsIfMatch = false;
  bool supportsIfNoneMatch = false;
  bool cleanedUp = true;
  String? issue;
  String? issueMethod;
  int? issueStatus;
}
