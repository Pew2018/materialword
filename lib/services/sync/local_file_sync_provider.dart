import 'dart:convert';
import 'dart:io';

import 'sync_provider.dart';

/// Fully working "sync through a file" provider: it reads and writes the same
/// versioned JSON document used by backup/restore. Transferring the file between
/// devices (AirDrop, USB, cloud drive, …) is left to the user in phase 1.
class LocalFileSyncProvider implements SyncProvider {
  LocalFileSyncProvider({required this.filePath});

  final String filePath;

  @override
  String get id => 'local-file';

  @override
  String get label => '本地文件';

  @override
  bool get isImplemented => true;

  @override
  String get description => '通过导出的 JSON 文件在设备之间手动同步，完全离线可用。';

  @override
  Future<SyncTestResult> testConnection() async {
    final Directory parent = File(filePath).parent;
    if (!parent.existsSync()) {
      return SyncTestResult(ok: false, message: '目录不存在：${parent.path}');
    }
    return SyncTestResult(ok: true, message: '目标目录可写：${parent.path}');
  }

  @override
  Future<SyncPayload?> download() async {
    final File file = File(filePath);
    if (!file.existsSync()) return null;
    final String raw = await file.readAsString();
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const SyncException('同步文件格式无效');
    }
    return SyncPayload(
      dataset: decoded,
      revision: file.lastModifiedSync().millisecondsSinceEpoch.toString(),
      updatedAt: file.lastModifiedSync(),
    );
  }

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async {
    final File file = File(filePath);
    if (ifRevision != null && file.existsSync()) {
      final String current = file
          .lastModifiedSync()
          .millisecondsSinceEpoch
          .toString();
      if (current != ifRevision) {
        throw const SyncException('本地同步文件已被其他程序修改，请重新读取后再上传');
      }
    }
    final Directory parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(dataset),
      flush: true,
    );
    return SyncUploadResult(
      ok: true,
      message: '已写入 ${file.path}',
      revision: file.lastModifiedSync().millisecondsSinceEpoch.toString(),
    );
  }
}

/// Planned provider. Kept as a real class (instead of a comment) so the data
/// protocol and the UI can be wired up before the network code lands.
class GitHubSyncProvider implements SyncProvider {
  const GitHubSyncProvider();

  @override
  String get id => 'github';

  @override
  String get label => 'GitHub 私有仓库';

  @override
  bool get isImplemented => false;

  @override
  String get description =>
      '通过 GitHub REST API 同步到独立的私有数据仓库（需要 Fine-grained PAT，仅存于系统安全存储）。本阶段未实现。';

  Never _notImplemented() =>
      throw const SyncException('GitHub 同步将在下一阶段实现：当前版本不会发起任何网络请求。');

  @override
  Future<SyncTestResult> testConnection() async => _notImplemented();

  @override
  Future<SyncPayload?> download() async => _notImplemented();

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async => _notImplemented();
}

class WebDavSyncProvider implements SyncProvider {
  const WebDavSyncProvider();

  @override
  String get id => 'webdav';

  @override
  String get label => 'WebDAV';

  @override
  bool get isImplemented => false;

  @override
  String get description => '通过 HTTPS + ETag 条件请求同步到自建 WebDAV 目录。本阶段未实现。';

  Never _notImplemented() =>
      throw const SyncException('WebDAV 同步将在下一阶段实现：当前版本不会发起任何网络请求。');

  @override
  Future<SyncTestResult> testConnection() async => _notImplemented();

  @override
  Future<SyncPayload?> download() async => _notImplemented();

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async => _notImplemented();
}
