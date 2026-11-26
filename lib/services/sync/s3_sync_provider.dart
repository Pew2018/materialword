import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../backup_service.dart' show decodeDatasetJson, encodeDatasetJson;

import 'aws_signature_v4.dart';
import 'credential_store.dart';
import 'sync_provider.dart';

/// Where the document lives and how the request is addressed.
///
/// Two addressing styles exist and they are not interchangeable:
///
///  * **virtual-hosted** — `https://<bucket>.s3.eu-west-1.amazonaws.com/<key>`,
///    what AWS expects for new buckets;
///  * **path-style** — `https://<endpoint>/<bucket>/<key>`, what Cloudflare R2,
///    MinIO and most S3-compatible services accept.
///
/// [auto] chooses virtual-hosted for `*.amazonaws.com`/`*.amazonaws.com.cn`
/// endpoints and path-style everywhere else. A bucket name containing a dot
/// always uses path-style: a wildcard certificate cannot match
/// `<bucket.with.dots>.s3.amazonaws.com`, so virtual-hosted would fail TLS for
/// a reason unrelated to the credentials.
enum S3AddressingStyle { auto, pathStyle, virtualHosted }

class S3Target {
  const S3Target({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.objectKey,
    required this.addressing,
  });

  /// Normalised endpoint: `https://host[:port]`, no path, no query.
  final Uri endpoint;
  final String region;
  final String bucket;

  /// Normalised object key (`a/b/c.json`, no leading slash).
  final String objectKey;
  final S3AddressingStyle addressing;

  bool get isSecure => endpoint.scheme == 'https';

  bool get usesVirtualHost =>
      addressing == S3AddressingStyle.virtualHosted ||
      (addressing == S3AddressingStyle.auto &&
          _isAwsHost(endpoint.host) &&
          !bucket.contains('.'));

  String get _authority =>
      endpoint.hasPort ? '${endpoint.host}:${endpoint.port}' : endpoint.host;

  /// `https://bucket.s3.amazonaws.com` or `https://host/bucket`.
  Uri get bucketUri => usesVirtualHost
      ? Uri.parse('https://$bucket.$_authority')
      : Uri.parse('https://$_authority/$bucket');

  /// Fully encoded URL of one object.
  Uri uriFor(String key) {
    final String encoded = AwsV4Signer.encodeKey(key);
    return usesVirtualHost
        ? Uri.parse('https://$bucket.$_authority/$encoded')
        : Uri.parse('https://$_authority/$bucket/$encoded');
  }

  Uri get objectUri => uriFor(objectKey);

  /// A probe object next to the real one, so a probe can never be the dataset.
  Uri probeUri(String nonce) {
    final int slash = objectKey.lastIndexOf('/');
    final String prefix = slash < 0 ? '' : objectKey.substring(0, slash + 1);
    return uriFor('${prefix}materialword-probe-$nonce.json');
  }

  String get label => '${endpoint.host}/$bucket/$objectKey';

  /// Human-readable reason the configuration cannot be used, or null.
  static String? problemWith({
    required String endpoint,
    required String region,
    required String bucket,
    required String objectKey,
  }) {
    final Uri? parsed = Uri.tryParse(endpoint.trim());
    if (parsed == null || !parsed.isAbsolute) {
      return 'Endpoint 必须是完整地址，例如 https://s3.us-east-1.amazonaws.com';
    }
    if (parsed.scheme.toLowerCase() != 'https') {
      return 'S3 只允许 HTTPS Endpoint（不会关闭 TLS 证书校验）';
    }
    if (parsed.host.isEmpty) return 'Endpoint 缺少主机名';
    if (parsed.userInfo.isNotEmpty) return 'Endpoint 不能包含账号密码';
    if (parsed.hasQuery || parsed.hasFragment) {
      return 'Endpoint 不能包含查询参数或片段';
    }
    final String path = parsed.path;
    if (path.isNotEmpty && path != '/') {
      return 'Endpoint 只填服务地址，Bucket 与对象键请分别填写：不要写成 $endpoint';
    }
    if (region.trim().isEmpty) return '请填写 Region（AWS 例如 us-east-1，R2 填 auto）';
    if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(region.trim())) {
      return 'Region 只能包含小写字母、数字和连字符';
    }
    final String name = bucket.trim();
    if (name.isEmpty) return '请填写 Bucket 名称';
    if (!RegExp(r'^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$').hasMatch(name)) {
      return 'Bucket 名称需为 3–63 位小写字母、数字、点或连字符，且以字母或数字开头结尾';
    }
    if (name.contains('..')) return 'Bucket 名称不能包含连续的点';
    final String key = objectKey.trim();
    if (key.isEmpty) return '请填写对象键，例如 materialword/materialword-data.json';
    if (key.startsWith('/')) return '对象键不能以斜杠开头（Bucket 之后的部分才叫键）';
    if (key.contains('//')) return '对象键不能包含连续的斜杠';
    if (key.split('/').any((String s) => s == '.' || s == '..')) {
      return '对象键不能包含 . 或 .. 路径段';
    }
    for (final int unit in key.codeUnits) {
      if (unit < 0x20 || unit == 0x7F) return '对象键不能包含控制字符';
    }
    if (utf8.encode(key).length > 1024) return '对象键不能超过 1024 字节';
    return null;
  }

  static S3Target? resolve({
    required String endpoint,
    required String region,
    required String bucket,
    required String objectKey,
    S3AddressingStyle addressing = S3AddressingStyle.auto,
  }) {
    if (problemWith(
          endpoint: endpoint,
          region: region,
          bucket: bucket,
          objectKey: objectKey,
        ) !=
        null) {
      return null;
    }
    final Uri parsed = Uri.parse(endpoint.trim());
    final bool defaultPort =
        (parsed.scheme == 'https' && parsed.port == 443) ||
        (parsed.scheme == 'http' && parsed.port == 80);
    return S3Target(
      endpoint: parsed.replace(
        path: '',
        port: defaultPort ? null : parsed.port,
        query: null,
        fragment: null,
      ),
      region: region.trim(),
      bucket: bucket.trim(),
      objectKey: objectKey.trim(),
      addressing: addressing,
    );
  }

  static bool _isAwsHost(String host) =>
      host == 'amazonaws.com' ||
      host.endsWith('.amazonaws.com') ||
      host.endsWith('.amazonaws.com.cn');

  @override
  String toString() => 's3://$bucket/$objectKey @ ${endpoint.host} ($region)';
}

/// Why a single S3 request failed. Kept apart from the HTTP status because the
/// status alone cannot tell "no such key" from "no such bucket", nor "wrong
/// credentials" from "right credentials, no permission".
enum S3ErrorKind {
  none,
  authentication,
  permission,
  bucketMissing,
  objectMissing,
  regionMismatch,
  preconditionFailed,
  conditionalConflict,
  redirect,
  timeout,
  network,
  server,
  other,
}

class S3Failure {
  const S3Failure({required this.kind, this.status, this.code, this.detail});

  final S3ErrorKind kind;
  final int? status;

  /// Error code from the S3 XML body (`NoSuchBucket`, `AccessDenied`, …).
  final String? code;
  final String? detail;

  String get stageLabel => detail ?? '';
}

class S3SyncProvider
    implements SyncProvider, VerifiableSyncProvider, SessionScopedSyncProvider {
  S3SyncProvider({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.objectKey,
    this.identityEpoch = '',
    this.addressing = S3AddressingStyle.auto,
    CredentialStore? credentials,
    http.Client? client,
    String? accessKeyIdOverride,
    String? secretAccessKeyOverride,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 45),
  }) : _credentials = credentials ?? SecureCredentialStore(),
       _client = client,
       _accessKeyIdOverride = accessKeyIdOverride,
       _secretKeyOverride = secretAccessKeyOverride,
       _clock = clock ?? DateTime.now;

  S3SyncProvider.fromConfig(
    Map<String, Object?> config, {
    CredentialStore? credentials,
    http.Client? client,
    String? accessKeyIdOverride,
    String? secretAccessKeyOverride,
    DateTime Function()? clock,
  }) : this(
         endpoint: (config['endpoint'] as String?) ?? '',
         region: (config['region'] as String?) ?? 'us-east-1',
         bucket: (config['bucket'] as String?) ?? '',
         objectKey: (config['key'] as String?) ?? 'materialword-data.json',
         identityEpoch: (config['credentialEpoch'] as String?) ?? '',
         addressing: switch (config['addressing']) {
           'path' => S3AddressingStyle.pathStyle,
           'virtual' => S3AddressingStyle.virtualHosted,
           _ => S3AddressingStyle.auto,
         },
         credentials: credentials,
         client: client,
         accessKeyIdOverride: accessKeyIdOverride,
         secretAccessKeyOverride: secretAccessKeyOverride,
         clock: clock,
       );

  final String endpoint;
  final String region;
  final String bucket;
  final String objectKey;
  final String identityEpoch;
  final S3AddressingStyle addressing;
  final Duration timeout;

  final CredentialStore _credentials;
  final http.Client? _client;
  final String? _accessKeyIdOverride;
  final String? _secretKeyOverride;
  final DateTime Function() _clock;

  AwsCredentials? _capturedCredentials;

  @override
  SyncCapability? lastCapability;

  http.Client? _ownedClient;
  http.Client get _http => _client ?? (_ownedClient ??= http.Client());

  @override
  String get id => 's3';

  @override
  String get label => 'S3';

  @override
  bool get isImplemented => true;

  @override
  bool get requiresNetwork => true;

  @override
  bool get supportsConditionalWrites => true;

  @override
  String get description => '通过 HTTPS + AWS Signature V4 同步到 S3 兼容存储桶。';

  S3Target? get target => S3Target.resolve(
    endpoint: endpoint,
    region: region,
    bucket: bucket,
    objectKey: objectKey,
    addressing: addressing,
  );

  /// Reason the current configuration cannot be used, or null when it can.
  String? get configurationProblem => S3Target.problemWith(
    endpoint: endpoint,
    region: region,
    bucket: bucket,
    objectKey: objectKey,
  );

  bool get isConfigured => configurationProblem == null;

  @override
  Future<void> captureCredentials() => CredentialStore.exclusive(() async {
    clearCapturedCredentials();
    _capturedCredentials = await _readCredentials();
  });

  @override
  void clearCapturedCredentials() {
    _capturedCredentials = null;
    lastCapability = null;
  }

  @override
  void close() {
    _ownedClient?.close();
    _ownedClient = null;
  }

  Future<AwsCredentials?> _readCredentials() async {
    if (_capturedCredentials != null) return _capturedCredentials;
    try {
      final String? id =
          _accessKeyIdOverride ??
          await _credentials.read(CredentialKeys.s3AccessKeyId);
      final String? secret =
          _secretKeyOverride ??
          await _credentials.read(CredentialKeys.s3SecretAccessKey);
      if (id == null || id.isEmpty || secret == null || secret.isEmpty) {
        return null;
      }
      return AwsCredentials(accessKeyId: id, secretAccessKey: secret);
    } on CredentialStoreUnavailable catch (e) {
      // Never fall back to plain text: ask for the key again instead.
      throw SyncException('${e.reason}，请到「数据同步」页重新输入 S3 Access Key。');
    }
  }

  /// Stable identity of everything a capability result depends on.
  ///
  /// Bound to the normalised endpoint, region, bucket, key, addressing style,
  /// credential epoch and a digest of the access key id — never the secret,
  /// never the signature. Changing any of them invalidates a cached verdict.
  @override
  Future<String> capabilityFingerprint() async {
    final AwsCredentials? credentials = await _readCredentials();
    final String idDigest = sha256
        .convert(utf8.encode(credentials?.accessKeyId ?? ''))
        .toString()
        .substring(0, 16);
    final S3Target? t = target;
    final String identity = jsonEncode(<Object?>[
      's3-cap-1',
      t?.endpoint.toString() ?? endpoint.trim(),
      region.trim(),
      t?.bucket ?? bucket.trim(),
      t?.objectKey ?? objectKey.trim(),
      t?.usesVirtualHost ?? false,
      identityEpoch,
      idDigest,
    ]);
    return sha256.convert(utf8.encode(identity)).toString();
  }

  // ---------------------------------------------------------------- transport

  Uri get _bucketUri {
    final S3Target t = target!;
    return t.bucketUri;
  }

  Future<SignedRequestHeaders> _sign(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    List<int>? body,
  }) async {
    final AwsCredentials? credentials = await _readCredentials();
    if (credentials == null) {
      throw const SyncException(
        '缺少 S3 凭据：请重新输入 Access Key ID 与 Secret Access Key',
      );
    }
    return AwsV4Signer(credentials: credentials, region: region.trim()).sign(
      method: method,
      url: uri,
      now: _clock(),
      headers: headers,
      body: body,
    );
  }

  /// Sends one signed request. Redirects are **never** followed: the signature
  /// covers `Host`, so following one would either break the signature or hand a
  /// signed request to a different host.
  Future<_S3Response> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    List<int>? body,
  }) async {
    final SignedRequestHeaders signed = await _sign(
      method,
      uri,
      headers: headers,
      body: body,
    );
    final http.Request request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll(signed.headers);
    if (body != null) request.bodyBytes = body;

    http.StreamedResponse streamed;
    try {
      streamed = await _http.send(request).timeout(timeout);
    } on TimeoutException {
      throw const SyncException('S3 请求超时：请检查网络后重试', retryable: true);
    } on http.ClientException {
      throw const SyncException('S3 网络请求失败：请检查网络后重试', retryable: true);
    } catch (e) {
      if (e is SyncException) rethrow;
      throw const SyncException('S3 网络请求失败：请检查网络后重试', retryable: true);
    }
    final http.Response response = await http.Response.fromStream(streamed)
        .timeout(timeout);

    if (response.statusCode >= 300 && response.statusCode < 400) {
      final String? location = response.headers['location'];
      final Uri? next = location == null ? null : uri.resolve(location);
      final bool crossHost = next != null && next.host != uri.host;
      throw SyncException(
        crossHost
            ? 'S3 服务要求重定向到其他主机（${next.host}），已拒绝携带签名继续请求；'
                  '请检查 Endpoint 与 Region 是否填写正确'
            : 'S3 服务返回重定向（HTTP ${response.statusCode}），'
                  '通常是 Region 填写错误；请检查 Region（服务端提示：'
                  '${response.headers['x-amz-bucket-region'] ?? '未知'}）',
      );
    }

    return _S3Response(
      statusCode: response.statusCode,
      headers: <String, String>{
        for (final MapEntry<String, String> entry in response.headers.entries)
          entry.key.toLowerCase(): entry.value,
      },
      body: response.bodyBytes,
    );
  }

  SyncException _exceptionFor(
    S3Failure failure, {
    required String action,
    required String stage,
  }) {
    final String where =
        '（$stage${failure.status == null ? '' : ' HTTP ${failure.status}'}'
        '${failure.code == null ? '' : ' ${failure.code}'}）';
    return switch (failure.kind) {
      S3ErrorKind.authentication => SyncException(
        'S3 认证失败$where：Access Key ID 或 Secret Access Key 不正确。'
        '请到「数据同步」页重新输入。',
      ),
      S3ErrorKind.permission => SyncException(
        'S3 权限不足$where：该 Access Key 无权$action。'
        '请检查 Bucket 策略是否允许 s3:GetObject / s3:PutObject'
        '${failure.code == 'AllAccessDisabled' ? '（该存储桶已被停用）' : ''}',
      ),
      S3ErrorKind.bucketMissing => SyncException(
        'Bucket 不存在$where：请检查 Bucket 名称与 Region 是否正确。',
      ),
      S3ErrorKind.objectMissing => SyncException('S3 对象不存在$where：$action 失败。'),
      S3ErrorKind.regionMismatch => SyncException(
        'Region 与 Bucket 实际位置不一致$where：'
        '请把 Region 改为${failure.detail ?? '服务端提示的值'}。',
      ),
      S3ErrorKind.preconditionFailed => const SyncConflictException(
        '远程文件已被其他设备修改',
      ),
      S3ErrorKind.conditionalConflict => const SyncConflictException(
        '远程文件正在被其他设备写入',
      ),
      S3ErrorKind.redirect => SyncException('S3 服务返回重定向$where'),
      S3ErrorKind.timeout => const SyncException(
        'S3 请求超时：请检查网络后重试',
        retryable: true,
      ),
      S3ErrorKind.network => const SyncException(
        'S3 网络请求失败：请检查网络后重试',
        retryable: true,
      ),
      S3ErrorKind.server => SyncException(
        'S3 服务端错误$where：请稍后重试。',
        retryable: true,
      ),
      S3ErrorKind.other ||
      S3ErrorKind.none => SyncException('S3 $action 失败$where'),
    };
  }

  static String? _strongEtag(String? value) {
    final String? tag = value?.trim();
    if (tag == null || tag.length < 2) return null;
    if (tag.startsWith('W/')) return null;
    if (!tag.startsWith('"') || !tag.endsWith('"')) return null;
    return tag;
  }

  // -------------------------------------------------------------- capability

  @override
  Future<SyncCapability> probeCapability({bool deep = true}) async {
    final String? problem = configurationProblem;
    final S3Target? t = target;
    if (problem != null || t == null) {
      return SyncCapability(
        status: SyncCapabilityStatus.connectionFailed,
        failureStage: 'configuration',
        detail: problem ?? '配置无效',
      );
    }

    bool reachable = false;
    bool authenticated = false;
    bool bucketAccessible = false;

    try {
      // 1. Bucket-level HEAD: the only request that can tell "bucket missing"
      //    apart from "object missing". A 403 here is *not* fatal — a
      //    bucket-scoped token may simply not allow HeadBucket — so it is
      //    treated as inconclusive and the object probe decides.
      final _S3Response head = await _send('HEAD', _bucketUri);
      switch (head.failure.kind) {
        case S3ErrorKind.none:
          reachable = true;
          authenticated = true;
          bucketAccessible = true;
        // A HEAD answer carries no XML body, so a 404 cannot be told apart
        // from `NoSuchBucket` by its code. At the bucket level a 404 can only
        // mean the bucket is not there (or not visible to this key).
        case S3ErrorKind.bucketMissing || S3ErrorKind.objectMissing:
          return SyncCapability(
            status: SyncCapabilityStatus.directoryUnavailable,
            reachable: true,
            authenticated: true,
            failureStage: 'head_bucket',
            failureMethod: 'HEAD',
            failureStatus: head.statusCode,
            detail: 'Bucket ${t.bucket} 不存在，请检查名称与 Region',
          );
        case S3ErrorKind.authentication:
          return SyncCapability(
            status: SyncCapabilityStatus.authenticationFailed,
            reachable: true,
            failureStage: 'head_bucket',
            failureMethod: 'HEAD',
            failureStatus: head.statusCode,
            detail: 'Access Key ID 或 Secret Access Key 不正确',
          );
        case S3ErrorKind.regionMismatch:
          return SyncCapability(
            status: SyncCapabilityStatus.connectionFailed,
            reachable: true,
            failureStage: 'head_bucket',
            failureMethod: 'HEAD',
            failureStatus: head.statusCode,
            detail:
                'Region 与 Bucket 实际位置不一致：'
                '${head.headers['x-amz-bucket-region'] ?? '请核对 Region'}',
          );
        case S3ErrorKind.permission:
          // Inconclusive: continue, the object probe is authoritative.
          reachable = true;
        case S3ErrorKind.server:
          return SyncCapability(
            status: SyncCapabilityStatus.connectionFailed,
            reachable: true,
            failureStage: 'head_bucket',
            failureMethod: 'HEAD',
            failureStatus: head.statusCode,
            detail: '服务器返回 HTTP ${head.statusCode}',
          );
        default:
          break;
      }

      final _S3Probe probe = await _probeObject(t);
      final bool conditionalOk =
          probe.cleanedUp &&
          probe.supportsStrongEtag &&
          probe.supportsConditionalRead &&
          probe.supportsIfMatch &&
          probe.supportsIfNoneMatch;
      authenticated = authenticated || probe.authenticated;
      bucketAccessible = bucketAccessible || probe.canCreate || probe.canRead;

      SyncCapabilityStatus status;
      if (!probe.canCreate && !probe.canUpdate) {
        status = switch (probe.fatal) {
          S3ErrorKind.authentication =>
            SyncCapabilityStatus.authenticationFailed,
          S3ErrorKind.bucketMissing =>
            SyncCapabilityStatus.directoryUnavailable,
          _ =>
            probe.canRead
                ? SyncCapabilityStatus.readOnly
                : SyncCapabilityStatus.permissionDenied,
        };
      } else if (conditionalOk && probe.canUpdate) {
        status = SyncCapabilityStatus.safeConditionalWrite;
      } else {
        status = SyncCapabilityStatus.basicReadWrite;
      }
      return SyncCapability(
        status: status,
        reachable: true,
        authenticated: authenticated,
        directoryAccessible: bucketAccessible,
        canRead: probe.canRead,
        canCreate: probe.canCreate,
        canUpdate: probe.canUpdate,
        canDelete: probe.canDelete,
        supportsStrongEtag: probe.supportsStrongEtag,
        supportsConditionalRead: probe.supportsConditionalRead,
        supportsIfMatch: probe.supportsIfMatch,
        supportsIfNoneMatch: probe.supportsIfNoneMatch,
        probeCleanedUp: probe.cleanedUp,
        directoryListingSupported: false,
        failureStage: probe.issue == null ? null : probe.issueStage,
        failureMethod: probe.issue == null ? null : probe.issueMethod,
        failureStatus: probe.issueStatus,
        detail: probe.issue,
      );
    } on SyncException catch (e) {
      // Reached only when a request could not be sent at all (timeout, TLS,
      // DNS): every HTTP answer is classified by the branches above.
      return SyncCapability(
        status: reachable
            ? SyncCapabilityStatus.directoryUnavailable
            : SyncCapabilityStatus.connectionFailed,
        reachable: reachable,
        authenticated: authenticated,
        detail: e.message,
        failureStage: 'probe',
      );
    }
  }

  /// The conditional-write proof, on an object this device owns.
  ///
  /// The order is deliberate: create unconditionally guarded, read back, prove
  /// a second create is refused, prove a stale update is refused, then prove a
  /// correct update is accepted *and* that the ETag changed. A server that
  /// ignores the conditional headers fails one of those steps and is never
  /// reported as safe.
  Future<_S3Probe> _probeObject(S3Target t) async {
    final _S3Probe result = _S3Probe();
    final String nonce = const Uuid().v4();
    final Uri uri = t.probeUri(nonce);
    if (uri == t.objectUri) {
      return result
        ..issue = '探测对象与数据对象冲突，已跳过写入测试'
        ..issueStage = 'probe'
        ..issueMethod = 'PUT';
    }
    final String initial = jsonEncode(<String, Object?>{
      'probe': nonce,
      'revision': 1,
    });
    final String changed = jsonEncode(<String, Object?>{
      'probe': nonce,
      'revision': 2,
    });
    const String contentType = 'application/json; charset=utf-8';
    const String bogus = '"materialword-stale-probe"';

    Future<_S3Response> put(List<int> bytes, Map<String, String> condition) =>
        _send(
          'PUT',
          uri,
          headers: <String, String>{'content-type': contentType, ...condition},
          body: bytes,
        );

    Future<_S3Response> get({String? ifMatch}) =>
        _send('GET', uri, headers: <String, String>{'if-match': ?ifMatch});

    bool matches(_S3Response response, String expected) =>
        response.statusCode == 200 && response.text == expected;

    try {
      _S3Response created = await put(
        utf8.encode(initial),
        const <String, String>{'if-none-match': '*'},
      );
      if (created.statusCode == 412) {
        // Astronomically unlikely with a UUID, but a 412 means "not ours".
        created = await put(utf8.encode(initial), const <String, String>{
          'if-none-match': '*',
        });
      }
      switch (created.failure.kind) {
        case S3ErrorKind.authentication:
          result
            ..authenticated = false
            ..fatal = S3ErrorKind.authentication
            ..issue = 'Access Key ID 或 Secret Access Key 不正确'
            ..issueStage = 'conditional_create_probe'
            ..issueMethod = 'PUT'
            ..issueStatus = created.statusCode;
          return result;
        case S3ErrorKind.permission:
          result
            ..fatal = S3ErrorKind.permission
            ..issue = '该 Access Key 无权写入此 Bucket（缺少 s3:PutObject）'
            ..issueStage = 'conditional_create_probe'
            ..issueMethod = 'PUT'
            ..issueStatus = created.statusCode;
          return result;
        case S3ErrorKind.bucketMissing:
          result
            ..fatal = S3ErrorKind.bucketMissing
            ..issue = 'Bucket 不存在'
            ..issueStage = 'conditional_create_probe'
            ..issueMethod = 'PUT'
            ..issueStatus = created.statusCode;
          return result;
        case S3ErrorKind.none:
          if (created.statusCode != 200 && created.statusCode != 201) {
            result
              ..issue = '无法创建临时测试对象（HTTP ${created.statusCode}）'
              ..issueStage = 'conditional_create_probe'
              ..issueMethod = 'PUT'
              ..issueStatus = created.statusCode;
            return result;
          }
        default:
          result
            ..issue =
                '无法创建临时测试对象（HTTP ${created.statusCode}'
                '${created.code == null ? '' : ' ${created.code}'}）'
            ..issueStage = 'conditional_create_probe'
            ..issueMethod = 'PUT'
            ..issueStatus = created.statusCode;
          return result;
      }
      result
        ..authenticated = true
        ..ownObject = true
        ..canCreate = true
        ..canRead = true;

      final _S3Response read = await get();
      if (!matches(read, initial)) {
        result
          ..issue = '写入后读回的内容与预期不一致，无法确认临时对象归属'
          ..issueStage = 'basic_write_probe'
          ..issueMethod = 'GET'
          ..issueStatus = read.statusCode;
        return result;
      }
      String? tag = _strongEtag(read.headers['etag']);
      if (tag == null) {
        final _S3Response head = await _send('HEAD', uri);
        tag = _strongEtag(head.headers['etag']);
      }
      result.supportsStrongEtag = tag != null;
      if (tag == null) {
        result
          ..issue = '服务器未返回可用的 ETag（对象版本标识），无法安全地条件写入'
          ..issueStage = 'basic_write_probe'
          ..issueMethod = 'HEAD'
          ..issueStatus = read.statusCode;
        // Read/write works; it is only the version token that is missing.
        return result;
      }

      // 2. Conditional read: a matching tag returns the bytes, a stale one 412s.
      final _S3Response withTag = await get(ifMatch: tag);
      final _S3Response withStale = await get(ifMatch: bogus);
      result.supportsConditionalRead =
          withTag.statusCode == 200 &&
          matches(withTag, initial) &&
          withStale.statusCode == 412;

      // 3. A second create must be refused, and must not overwrite.
      final _S3Response duplicate = await put(
        utf8.encode(changed),
        const <String, String>{'if-none-match': '*'},
      );
      final _S3Response afterDuplicate = await get();
      final bool duplicateUnchanged = matches(afterDuplicate, initial);
      final bool duplicateOverwrote = matches(afterDuplicate, changed);
      String current = initial;
      if (duplicate.statusCode == 412 && duplicateUnchanged) {
        result.supportsIfNoneMatch = true;
      } else if (duplicateOverwrote) {
        result
          ..duplicateOverwrote = true
          ..issue =
              '服务器忽略了 If-None-Match：已存在的对象可以被无条件覆盖，'
              '两台设备同时写入会丢失数据'
          ..issueStage = 'duplicate_create_probe'
          ..issueMethod = 'PUT'
          ..issueStatus = duplicate.statusCode;
        current = changed;
        tag = _strongEtag(afterDuplicate.headers['etag']) ?? tag;
      } else {
        result
          ..issue = '无法确认重复创建是否被拒绝（HTTP ${duplicate.statusCode}）'
          ..issueStage = 'duplicate_create_probe'
          ..issueMethod = 'PUT'
          ..issueStatus = duplicate.statusCode;
        return result;
      }

      // 4. A stale If-Match must be refused, and must not overwrite.
      final _S3Response stale = await put(
        utf8.encode(initial),
        <String, String>{'if-match': bogus},
      );
      final _S3Response afterStale = await get();
      final bool staleUnchanged = matches(afterStale, current);
      if (stale.statusCode == 412 && staleUnchanged) {
        result.supportsIfMatch = true;
      } else {
        result
          ..issue ??= '服务器忽略了 If-Match：过期版本可以覆盖新数据'
          ..issueStage = 'conditional_stale_update_probe'
          ..issueMethod = 'PUT'
          ..issueStatus = stale.statusCode;
        // Whatever happened, re-read so the next step starts from the truth.
        if (!staleUnchanged) {
          current = afterStale.text;
          tag = _strongEtag(afterStale.headers['etag']) ?? tag;
        }
        return result;
      }

      // 5. A matching If-Match must be accepted and must produce a new version.
      final String next = current == initial ? changed : initial;
      final _S3Response updated = await put(utf8.encode(next), <String, String>{
        'if-match': tag,
      });
      final _S3Response afterUpdate = await get();
      result.canUpdate =
          (updated.statusCode == 200 || updated.statusCode == 204) &&
          matches(afterUpdate, next);
      final String? nextTag = _strongEtag(afterUpdate.headers['etag']);
      if (!result.canUpdate) {
        result
          ..issue = '条件更新未生效（HTTP ${updated.statusCode}），无法安全同步'
          ..issueStage = 'conditional_valid_update_probe'
          ..issueMethod = 'PUT'
          ..issueStatus = updated.statusCode;
        return result;
      }
      if (nextTag == null || nextTag == tag) {
        result
          ..supportsStrongEtag = false
          ..issue = '写入后 ETag 没有变化，无法判断远端版本'
          ..issueStage = 'conditional_valid_update_probe'
          ..issueMethod = 'PUT'
          ..issueStatus = updated.statusCode;
        return result;
      }
      tag = nextTag;

      // 6. HEAD must expose the same version the GET returned: the foreground
      //    probe relies on it and must not need to download the dataset.
      final _S3Response head = await _send('HEAD', uri);
      result.supportsConditionalRead =
          result.supportsConditionalRead &&
          head.statusCode == 200 &&
          _strongEtag(head.headers['etag']) == tag;
      return result;
    } on SyncException catch (e) {
      result
        ..issue ??= e.message
        ..issueStage ??= 'basic_write_probe';
      return result;
    } finally {
      if (result.ownObject) {
        result.cleanedUp = false;
        try {
          final _S3Response current = await get();
          if (current.statusCode == 404) {
            result.cleanedUp = true;
          } else if (current.statusCode == 200) {
            final String? tag = _strongEtag(current.headers['etag']);
            final _S3Response removed = await _send(
              'DELETE',
              uri,
              headers: <String, String>{'if-match': ?tag},
            );
            result.cleanedUp = switch (removed.failure.kind) {
              S3ErrorKind.none =>
                removed.statusCode == 204 ||
                    removed.statusCode == 200 ||
                    removed.statusCode == 404,
              S3ErrorKind.preconditionFailed => false,
              _ => false,
            };
          }
        } catch (_) {
          // The failure is already recorded in [issue]; a cleanup problem must
          // not replace the real reason the probe failed.
        }
        result.canDelete = result.cleanedUp;
        if (!result.cleanedUp) {
          result
            ..issue ??= '未能确认临时探测对象已清理'
            ..issueStage = 'probe_cleanup';
        }
      }
    }
  }

  @override
  Future<SyncTestResult> testConnection() async {
    final String? problem = configurationProblem;
    if (problem != null) {
      return SyncTestResult(
        ok: false,
        message: problem,
        capability: SyncCapability(
          status: SyncCapabilityStatus.connectionFailed,
          detail: problem,
        ),
      );
    }
    try {
      final SyncCapability capability = await probeCapability(deep: true);
      lastCapability = capability;
      final S3Target t = target!;
      final List<String> details = <String>[
        '对象地址：${t.endpoint.host}/${t.bucket}/${t.objectKey}'
            '（${t.usesVirtualHost ? 'virtual-hosted' : 'path-style'}）',
      ];
      if (capability.canCreate &&
          capability.canRead &&
          capability.canUpdate &&
          capability.canDelete) {
        details.add('基础读写验证通过：创建、读回、更新、删除');
      }
      if (capability.status == SyncCapabilityStatus.safeConditionalWrite) {
        details.add('已验证 If-None-Match: *、If-Match 与更新后的 ETag 变化');
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
      final SyncCapability capability = SyncCapability(
        status: SyncCapabilityStatus.connectionFailed,
        detail: e.message,
      );
      lastCapability = capability;
      return SyncTestResult(
        ok: false,
        message: e.message,
        capability: capability,
      );
    } catch (e) {
      return SyncTestResult(ok: false, message: '连接失败：$e');
    }
  }

  // -------------------------------------------------------------- data paths

  /// `HEAD` only: the foreground check must never transfer the dataset.
  @override
  Future<RemoteProbe> probeRemote() async {
    final S3Target? t = target;
    if (t == null) return const RemoteProbe.unsupported();
    final _S3Response head = await _send('HEAD', t.objectUri);
    return switch (head.failure.kind) {
      S3ErrorKind.none =>
        _strongEtag(head.headers['etag']) == null
            // A 200 without a usable ETag cannot answer "did it change".
            ? const RemoteProbe.unsupported()
            : RemoteProbe.revision(_strongEtag(head.headers['etag'])!),
      S3ErrorKind.objectMissing => const RemoteProbe.missing(),
      // 403 on a missing object is what a key without s3:ListBucket returns.
      // That is "cannot confirm", never "missing".
      S3ErrorKind.permission ||
      S3ErrorKind.authentication ||
      S3ErrorKind.bucketMissing ||
      S3ErrorKind.regionMismatch ||
      S3ErrorKind.redirect => const RemoteProbe.unsupported(),
      S3ErrorKind.timeout ||
      S3ErrorKind.network ||
      S3ErrorKind.server => const RemoteProbe.unsupported(),
      _ => const RemoteProbe.unsupported(),
    };
  }

  @override
  Future<String?> remoteRevision() async => (await probeRemote()).revision;

  @override
  Future<RemoteDataset> fetchRemote() async {
    final S3Target? t = target;
    if (t == null) throw SyncException(configurationProblem ?? 'S3 配置无效');
    final _S3Response response = await _send('GET', t.objectUri);
    switch (response.failure.kind) {
      case S3ErrorKind.none:
        break;
      case S3ErrorKind.objectMissing:
        return const RemoteDataset.missing();
      case S3ErrorKind.bucketMissing:
        throw _exceptionFor(
          response.failure,
          action: '读取数据',
          stage: 'dataset_download',
        );
      default:
        throw _exceptionFor(
          response.failure,
          action: '读取数据',
          stage: 'dataset_download',
        );
    }
    final String? etag = _strongEtag(response.headers['etag']);
    final List<int> bytes = response.body;
    final String text = utf8.decode(bytes, allowMalformed: true);
    if (text.trim().isEmpty) {
      // The object exists and has a version; it is not "no object yet".
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
      SyncPayload(dataset: decoded, revision: etag, rawLength: bytes.length),
    );
  }

  @override
  Future<SyncPayload?> download() async {
    final RemoteDataset remote = await fetchRemote();
    return switch (remote.state) {
      RemoteDatasetState.missing => null,
      RemoteDatasetState.empty => throw SyncEmptyRemoteException(
        remote.revision == null
            ? '远程同步对象为空（0 字节），且服务器未返回 ETag，无法安全初始化'
            : '远程同步对象为空（0 字节）',
      ),
      RemoteDatasetState.valid => remote.payload,
    };
  }

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async {
    final S3Target? t = target;
    if (t == null) throw SyncException(configurationProblem ?? 'S3 配置无效');
    final String? revision = ifRevision?.trim();
    if (revision != null &&
        revision.isNotEmpty &&
        _strongEtag(revision) == null) {
      // Never fall back to an unconditional write: an unusable version token
      // means "stop and explain", not "overwrite".
      throw SyncException(
        '远程对象的版本标识（ETag）不可用：$revision。'
        '无法确认要覆盖的是哪一版数据，已停止上传。',
      );
    }
    final List<int> bytes = utf8.encode(await encodeDatasetJson(dataset));
    final bool creating = revision == null || revision.isEmpty;
    final Map<String, String> condition = creating
        ? const <String, String>{'if-none-match': '*'}
        : <String, String>{'if-match': revision};

    final _S3Response response;
    try {
      response = await _send(
        'PUT',
        t.objectUri,
        headers: <String, String>{
          ...condition,
          'content-type': 'application/json; charset=utf-8',
        },
        body: bytes,
      );
    } on SyncException catch (e) {
      if (!e.retryable) rethrow;
      // The response was lost (timeout / dropped connection). The write may
      // still have been committed, so read the object back before deciding:
      // re-sending blindly would turn a success into a spurious conflict.
      final String? recovered = await _recoverLostUpload(t, bytes);
      if (recovered != null) {
        return SyncUploadResult(
          ok: true,
          message: '上传响应丢失，已确认远程对象内容为本机数据',
          revision: recovered,
        );
      }
      rethrow;
    }

    if (response.failure.kind == S3ErrorKind.preconditionFailed ||
        response.failure.kind == S3ErrorKind.conditionalConflict) {
      throw SyncConflictException(creating ? '远程对象已被其他设备创建' : '远程文件已被其他设备修改');
    }
    if (response.failure.kind != S3ErrorKind.none) {
      throw _exceptionFor(
        response.failure,
        action: '写入数据',
        stage: 'dataset_upload',
      );
    }
    String? etag = _strongEtag(response.headers['etag']);
    if (etag == null) {
      // Some S3-compatible services omit ETag on PUT; ask once, then report the
      // missing version instead of pretending the object is versioned.
      final _S3Response head = await _send('HEAD', t.objectUri);
      etag = _strongEtag(head.headers['etag']);
    }
    if (etag == null) {
      throw const SyncException(
        '写入成功，但服务器没有返回 ETag，无法继续安全同步。'
        '请检查服务端是否支持对象版本标识。',
      );
    }
    return SyncUploadResult(
      ok: true,
      message: '已写入 ${t.endpoint.host}/${t.bucket}/${t.objectKey}',
      revision: etag,
    );
  }

  /// Decides whether a write whose response was lost actually landed.
  ///
  /// Returns the object's revision when the remote content is byte-identical to
  /// what this device sent, and null when it is not (or cannot be read), so the
  /// caller reports a retryable failure instead of a false success.
  Future<String?> _recoverLostUpload(S3Target t, List<int> sent) async {
    try {
      final _S3Response read = await _send('GET', t.objectUri);
      if (read.statusCode != 200) return null;
      final String expected = sha256.convert(sent).toString();
      final String actual = sha256.convert(read.body).toString();
      if (expected != actual) return null;
      return _strongEtag(read.headers['etag']);
    } catch (_) {
      return null;
    }
  }
}

class _S3Response {
  _S3Response({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final List<int> body;

  String get text => utf8.decode(body, allowMalformed: true);

  /// S3 error code, parsed from the XML body when there is one.
  String? get code {
    if (body.isEmpty) return null;
    final String raw = text;
    final Match? match = RegExp(r'<Code>([^<]{1,80})</Code>').firstMatch(raw);
    return match?.group(1)?.trim();
  }

  S3Failure get failure {
    if (statusCode >= 200 && statusCode < 300) {
      return const S3Failure(kind: S3ErrorKind.none);
    }
    final String? errorCode = code;
    final S3ErrorKind kind = switch (statusCode) {
      400 => switch (errorCode) {
        'AuthorizationHeaderMalformed' ||
        'IllegalLocationConstraintException' ||
        'InvalidRegion' ||
        'PermanentRedirect' => S3ErrorKind.regionMismatch,
        'RequestTimeTooSkewed' => S3ErrorKind.other,
        _ => S3ErrorKind.other,
      },
      401 => S3ErrorKind.authentication,
      403 => switch (errorCode) {
        'InvalidAccessKeyId' ||
        'SignatureDoesNotMatch' ||
        'InvalidSecurity' ||
        'ExpiredToken' => S3ErrorKind.authentication,
        _ => S3ErrorKind.permission,
      },
      404 =>
        errorCode == 'NoSuchBucket'
            ? S3ErrorKind.bucketMissing
            : S3ErrorKind.objectMissing,
      409 => S3ErrorKind.conditionalConflict,
      412 => S3ErrorKind.preconditionFailed,
      301 || 302 || 303 || 307 || 308 => S3ErrorKind.regionMismatch,
      >= 500 => S3ErrorKind.server,
      _ => S3ErrorKind.other,
    };
    return S3Failure(
      kind: kind,
      status: statusCode,
      code: errorCode,
      detail: headers['x-amz-bucket-region'],
    );
  }
}

/// Mutable accumulator for one capability probe.
class _S3Probe {
  bool authenticated = false;

  /// A failure that makes the whole target unusable (wrong key, missing
  /// bucket, denied policy), as opposed to "writes are not conditional".
  S3ErrorKind? fatal;
  bool ownObject = false;
  bool canRead = false;
  bool canCreate = false;
  bool canUpdate = false;
  bool canDelete = false;
  bool supportsStrongEtag = false;
  bool supportsConditionalRead = false;
  bool supportsIfMatch = false;
  bool supportsIfNoneMatch = false;
  bool duplicateOverwrote = false;
  bool cleanedUp = true;
  String? issue;
  String? issueStage;
  String? issueMethod;
  int? issueStatus;
}
