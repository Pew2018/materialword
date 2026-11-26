import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../backup_service.dart' show decodeDatasetJson;
import 'credential_store.dart';
import 'sync_provider.dart';

/// Sync through the GitHub REST **Contents API** into a dedicated private data
/// repository.
///
/// Concurrency: the file's blob `sha` is used as the revision. An upload always
/// carries the `sha` it was based on, so GitHub rejects a stale write with
/// 409 instead of letting one device silently overwrite another. A 422 is a
/// validation failure; an existing file discovered after a create race is
/// separately identified by reading its current SHA.
///
/// Security: complete syncs capture one in-memory credential snapshot and clear
/// it afterwards. Standalone calls read secure storage; secrets never enter
/// SQLite, the backup JSON or logs.
class GitHubSyncProvider implements SyncProvider, SessionScopedSyncProvider {
  GitHubSyncProvider({
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.path = 'materialword-data.json',
    this.identityEpoch = '',
    CredentialStore? credentials,
    http.Client? client,
    String? tokenOverride,
  }) : _credentials = credentials ?? SecureCredentialStore(),
       _client = client,
       _tokenOverride = tokenOverride;

  GitHubSyncProvider.fromConfig(
    Map<String, Object?> config, {
    CredentialStore? credentials,
    http.Client? client,
  }) : this(
         owner: (config['owner'] as String?) ?? '',
         repo: (config['repo'] as String?) ?? '',
         branch: (config['branch'] as String?) ?? 'main',
         path: (config['path'] as String?) ?? 'materialword-data.json',
         identityEpoch: (config['credentialEpoch'] as String?) ?? '',
         credentials: credentials,
         client: client,
       );

  GitHubSyncProvider.placeholder()
    : this(owner: '', repo: '', credentials: InMemoryCredentialStore());

  final String owner;
  final String repo;
  final String branch;
  final String path;
  final String identityEpoch;

  final CredentialStore _credentials;
  final http.Client? _client;
  http.Client? _ownedClient;
  final String? _tokenOverride;
  String? _capturedToken;
  bool _hasCapturedToken = false;

  @override
  Future<void> captureCredentials() => CredentialStore.exclusive(() async {
    clearCapturedCredentials();
    _capturedToken = await _token();
    _hasCapturedToken = true;
  });

  @override
  void clearCapturedCredentials() {
    _capturedToken = null;
    _hasCapturedToken = false;
  }

  /// Contents API is documented for files up to 100 MB, but anything above a
  /// few MB is a bad idea for a JSON document that is rewritten every sync.
  static const int maxPayloadBytes = 90 * 1024 * 1024;

  static Uri get apiRoot => Uri.parse('https://api.github.com');

  @override
  String get id => 'github';

  @override
  String get label => 'GitHub 私有仓库';

  @override
  bool get isImplemented => true;

  @override
  bool get requiresNetwork => true;

  @override
  bool get supportsConditionalWrites => true;

  @override
  String get description =>
      '通过 GitHub Contents API 同步到独立的私有数据仓库（Fine-grained PAT，仅存系统安全存储）。';

  bool get isConfigured =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]*$').hasMatch(owner) &&
      RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(repo) &&
      repo != '.' &&
      repo != '..' &&
      branch.trim().isNotEmpty &&
      !RegExp(r'[\r\n]').hasMatch(branch) &&
      path.trim().isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains('\\') &&
      !path
          .split('/')
          .any(
            (segment) => segment.isEmpty || segment == '.' || segment == '..',
          ) &&
      !RegExp(r'[\r\n]').hasMatch(path) &&
      !(owner.toLowerCase() == 'pew2018' &&
          repo.toLowerCase() == 'materialword');

  http.Client get _http => _client ?? (_ownedClient ??= http.Client());

  @override
  void close() {
    _ownedClient?.close();
    _ownedClient = null;
  }

  Future<http.Response> _get(Uri uri, String token) =>
      _send(http.Request('GET', uri)..headers.addAll(_headers(token)));

  Future<http.Response> _send(http.Request request) => _guard(() {
    request.followRedirects = false;
    return (() async {
      return http.Response.fromStream(await _http.send(request));
    })().timeout(const Duration(seconds: 60));
  });

  /// No write probe: creating/deleting a GitHub file leaves permanent commits.
  /// Metadata push permission describes repository access, not the PAT's scope.
  Future<void> _validateTarget(String token) async {
    final repository = await _get(_repoUri, token);
    if (repository.statusCode != 200) _raise(repository, '检查私有仓库');
    final Object? info;
    try {
      info = jsonDecode(repository.body);
    } on FormatException {
      throw const SyncDataException('GitHub 仓库信息无效');
    }
    if (info is! Map<String, dynamic> || info['private'] is! bool) {
      throw const SyncDataException('GitHub 未提供可靠的仓库可见性信息');
    }
    if (info['private'] != true) {
      throw const SyncException('拒绝同步到公开仓库：请使用独立的私有数据仓库');
    }
    final permissions = info['permissions'];
    if (permissions is Map && permissions['push'] == false) {
      throw const SyncException('GitHub 仓库账号只有只读权限，请检查仓库授权');
    }
    final branchResponse = await _get(
      Uri.parse(
        'https://api.github.com/repos/$owner/$repo/branches/'
        '${Uri.encodeComponent(branch)}',
      ),
      token,
    );
    if (branchResponse.statusCode == 404) {
      throw const SyncException('GitHub 分支不存在或无权读取，请先创建并授权目标分支');
    }
    if (branchResponse.statusCode != 200) {
      _raise(branchResponse, '检查目标分支');
    }
    try {
      final Object? branchInfo = jsonDecode(branchResponse.body);
      if (branchInfo is! Map<String, dynamic> ||
          branchInfo['name'] != branch ||
          branchInfo['commit'] is! Map ||
          branchInfo['commit']['sha'] is! String ||
          (branchInfo['commit']['sha'] as String).isEmpty) {
        throw const SyncDataException('GitHub 分支信息无效，请检查分支配置');
      }
    } on FormatException {
      throw const SyncDataException('GitHub 分支信息无效');
    }
  }

  /// Maps transport failures onto [SyncException] so the coordinator and the
  /// UI can distinguish "network problem, retry later" from "your token is
  /// wrong".
  Future<http.Response> _guard(Future<http.Response> Function() call) async {
    try {
      return await call();
    } on TimeoutException {
      throw const SyncException('网络超时：请检查网络后重试', retryable: true);
    } on http.ClientException {
      throw const SyncException('网络请求失败：请检查网络后重试', retryable: true);
    } catch (e) {
      if (e is SyncException) rethrow;
      throw const SyncException('网络请求失败：请检查网络后重试', retryable: true);
    }
  }

  Future<String?> _token() async {
    if (_hasCapturedToken) return _capturedToken;
    if (_tokenOverride != null && _tokenOverride.isNotEmpty) {
      return _tokenOverride;
    }
    try {
      final String? stored = await _credentials.read(
        CredentialKeys.githubToken,
      );
      return (stored == null || stored.trim().isEmpty) ? null : stored.trim();
    } on CredentialStoreUnavailable catch (e) {
      // Turn a Keychain refusal into an actionable message instead of a
      // mysterious 401, and never fall back to a plain-text token.
      throw SyncException('${e.reason}，请到「数据同步」页重新输入 GitHub Token。');
    }
  }

  Map<String, String> _headers(String token) => <String, String>{
    'Authorization': 'Bearer $token',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'MaterialWord',
  };

  Uri get _contentsUri {
    final String encodedPath = path
        .split('/')
        .where((String s) => s.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return Uri.parse(
      'https://api.github.com/repos/$owner/'
      '$repo/contents/$encodedPath',
    );
  }

  Uri get _repoUri => Uri.parse(
    'https://api.github.com/repos/$owner/'
    '$repo',
  );

  /// Turns a GitHub error into a message a user can act on.
  Never _raise(http.Response response, String action) {
    final int status = response.statusCode;
    if (status == 401) {
      throw const SyncException('GitHub Token 无效或已过期，请重新生成并填写');
    }
    if (status == 403 || status == 429) {
      final String remaining = response.headers['x-ratelimit-remaining'] ?? '';
      if (remaining == '0' || status == 429) {
        final String reset = response.headers['x-ratelimit-reset'] ?? '';
        final DateTime? when = reset.isEmpty
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (int.tryParse(reset) ?? 0) * 1000,
              ).toLocal();
        throw SyncException(
          '触发 GitHub API 限流${when == null ? '' : '（约 ${when.hour}:${when.minute.toString().padLeft(2, '0')} 重置）'}，请稍后重试',
          retryable: true,
        );
      }
      throw const SyncException('GitHub 权限不足：Token 需要目标仓库的 Contents 读写权限');
    }
    if (status == 404) {
      throw const SyncException('GitHub 仓库或数据文件不存在，请检查 owner/repo/分支/路径');
    }
    if (status == 422) {
      throw const SyncException(
        'GitHub 写入校验失败（HTTP 422）：请检查路径、分支、Contents 写权限及仓库规则',
      );
    }
    if (status == 409) {
      throw SyncConflictException('GitHub 拒绝了本次写入（并发冲突）：远程文件已变更，将重新拉取并合并');
    }
    if (status >= 500) {
      throw SyncException(
        'GitHub 服务暂时不可用（HTTP $status），请稍后重试',
        retryable: true,
      );
    }
    throw SyncException('GitHub $action 失败（HTTP $status），请检查仓库配置与访问权限');
  }

  @override
  Future<SyncTestResult> testConnection() async {
    if (!isConfigured) {
      return const SyncTestResult(
        ok: false,
        message: '请先填写仓库 owner / repo / 分支 / 数据文件路径',
      );
    }
    final String? token = await _token();
    if (token == null) {
      return const SyncTestResult(ok: false, message: '尚未保存 GitHub Token');
    }
    try {
      await _validateTarget(token);
      final details = <String>[
        '仓库为私有，目标分支可读取',
        '连接测试仅验证读取；Token 的 Contents 写权限需在实际条件上传时确认',
      ];
      final fileResponse = await _get(
        _contentsUri.replace(queryParameters: {'ref': branch}),
        token,
      );
      if (fileResponse.statusCode == 200) {
        details.add('远程数据文件已存在');
      } else if (fileResponse.statusCode == 404) {
        details.add('远程数据文件尚未创建，首次同步会写入');
      } else {
        _raise(fileResponse, '检查数据文件');
      }

      return SyncTestResult(
        ok: true,
        message: '已连接 $owner/$repo（$branch）',
        details: details,
      );
    } on SyncException catch (e) {
      return SyncTestResult(ok: false, message: e.message);
    } on TimeoutException {
      return const SyncTestResult(ok: false, message: 'GitHub 请求超时，请检查网络');
    } catch (_) {
      return const SyncTestResult(ok: false, message: 'GitHub 返回无效响应，请重试');
    }
  }

  /// Metadata-only probe: the Contents API response carries the blob `sha`
  /// without the base64 payload when the file is small, and for a large file the
  /// same request still returns the `sha` plus `encoding: none`. Either way this
  /// is a few hundred bytes instead of the whole dataset.
  @override
  Future<RemoteProbe> probeRemote() async {
    // Not configured / no token: we cannot tell, which is not "missing".
    if (!isConfigured) return const RemoteProbe.unsupported();
    final String? token = await _token();
    if (token == null) return const RemoteProbe.unsupported();
    final response = await _get(
      _contentsUri.replace(queryParameters: {'ref': branch}),
      token,
    );
    if (response.statusCode == 404) {
      // The path (or the whole branch) is gone. A previous successful sync
      // treats that as a remote deletion, not as "unchanged".
      return const RemoteProbe.missing();
    }
    if (response.statusCode != 200) _raise(response, '检查远程版本');
    try {
      final Object? node = jsonDecode(response.body);
      if (node is Map<String, dynamic>) {
        final Object? sha = node['sha'];
        if (sha is String && sha.isNotEmpty) return RemoteProbe.revision(sha);
      }
      return const RemoteProbe.unsupported();
    } on FormatException {
      throw const SyncDataException('GitHub 返回的版本信息无效');
    }
  }

  @override
  Future<String?> remoteRevision() async => (await probeRemote()).revision;

  @override
  Future<RemoteDataset> fetchRemote() async {
    final SyncPayload? payload = await download();
    return payload == null
        ? const RemoteDataset.missing()
        : RemoteDataset.valid(payload);
  }

  @override
  Future<SyncPayload?> download() async {
    if (!isConfigured) {
      throw const SyncException('GitHub 同步尚未配置完整');
    }
    final String? token = await _token();
    if (token == null) throw const SyncException('尚未保存 GitHub Token');
    await _validateTarget(token);
    final response = await _get(
      _contentsUri.replace(queryParameters: {'ref': branch}),
      token,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _raise(response, '读取数据');
    final Map<String, dynamic> node =
        jsonDecode(response.body) as Map<String, dynamic>;
    final String? sha = node['sha'] as String?;
    final int? size = node['size'] as int?;
    if (size != null && size > maxPayloadBytes) {
      throw const SyncDataException('远程备份超过 90 MB，请改用 WebDAV 或手动备份');
    }
    final String? encoded = node['content'] as String?;
    final List<int> bytes;
    if (node['encoding'] == 'none' ||
        encoded == null ||
        (encoded.isEmpty && (size ?? 0) > 0)) {
      if (sha == null || sha.isEmpty) {
        throw const SyncDataException('GitHub 未提供文件 SHA');
      }
      final rawUri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/git/blobs/${Uri.encodeComponent(sha)}',
      );
      final request = http.Request('GET', rawUri)
        ..followRedirects = false
        ..headers.addAll({
          ..._headers(token),
          'Accept': 'application/vnd.github.raw+json',
        });
      final raw = await _send(request);
      if (raw.statusCode != 200) _raise(raw, '读取大文件');
      bytes = raw.bodyBytes;
    } else {
      try {
        bytes = base64Decode(encoded.replaceAll('\n', ''));
      } on FormatException {
        throw const SyncDataException('GitHub 返回了无效的 Base64 内容');
      }
    }
    if (bytes.length > maxPayloadBytes) {
      throw const SyncDataException('远程备份超过 90 MB，请改用 WebDAV 或手动备份');
    }
    Object? decoded;
    try {
      decoded = await decodeDatasetJson(utf8.decode(bytes));
    } on FormatException {
      throw const SyncDataException('远程数据文件不是合法 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const SyncDataException('远程数据文件根节点必须是对象');
    }
    return SyncPayload(
      dataset: decoded,
      revision: sha,
      contentHash: sha,
      rawLength: bytes.length,
    );
  }

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async {
    if (!isConfigured) {
      throw const SyncException('GitHub 同步尚未配置完整');
    }
    final String? token = await _token();
    if (token == null) throw const SyncException('尚未保存 GitHub Token');
    await _validateTarget(token);

    final List<int> bytes = utf8.encode(jsonEncode(dataset));
    if (bytes.length > maxPayloadBytes) {
      throw SyncDataException(
        '数据集过大（${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB），'
        '本应用 GitHub 备份上限为 90 MB。请使用 WebDAV 或手动备份，保留学习记录。',
      );
    }

    final Map<String, Object?> body = <String, Object?>{
      'message': 'MaterialWord sync',
      'content': base64Encode(bytes),
      'branch': branch,
      if (ifRevision != null && ifRevision.isNotEmpty) 'sha': ifRevision,
    };

    final response = await _send(
      http.Request('PUT', _contentsUri)
        ..headers.addAll({
          ..._headers(token),
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      Map<String, dynamic> node = <String, dynamic>{};
      try {
        node = jsonDecode(response.body) as Map<String, dynamic>;
      } on FormatException {
        // Fall through: the write succeeded, we just cannot read the new sha.
      }
      final Map<String, dynamic>? content =
          node['content'] as Map<String, dynamic>?;
      return SyncUploadResult(
        ok: true,
        message: '已写入 $owner/$repo/$path',
        revision: content?['sha'] as String?,
      );
    }
    if (response.statusCode == 409) {
      throw const SyncConflictException('远程文件已被其他设备修改');
    }
    if (response.statusCode == 422 &&
        (ifRevision == null || ifRevision.isEmpty)) {
      // A racing first writer can turn create into a validation failure
      // (missing sha). Retry only when a file with an actual SHA now exists.
      final existing = await _get(
        _contentsUri.replace(queryParameters: {'ref': branch}),
        token,
      );
      if (existing.statusCode == 200) {
        try {
          final Object? node = jsonDecode(existing.body);
          if (node is Map &&
              node['sha'] is String &&
              (node['sha'] as String).isNotEmpty) {
            throw const SyncConflictException('远程文件已由另一设备创建，将重新拉取并合并');
          }
        } on FormatException {
          // Report the original validation failure below.
        }
      } else if (existing.statusCode != 404) {
        _raise(existing, '检查首次写入冲突');
      }
    }
    _raise(response, '写入数据');
  }
}
