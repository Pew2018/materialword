import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'sync_provider.dart';
import '../backup_service.dart' show decodeDatasetJson, encodeDatasetJson;

/// "Sync through a file" provider: it reads and writes the same versioned JSON
/// document as backup/restore.
///
/// Safety properties:
///  * the revision is a **content hash**, not an mtime — a file copied around by
///    AirDrop/USB/cloud drives often keeps a meaningless timestamp, and phase 1
///    compared mtimes, which both missed real changes and produced false
///    conflicts;
///  * uploads write to a temporary file in the same directory and then rename,
///    so a crash or a full disk can never truncate the last good copy;
///  * the previous valid file is kept as `<name>.bak`.
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
  bool get requiresNetwork => false;

  @override
  bool get supportsConditionalWrites => false;

  @override
  String get description => '通过导出的 JSON 文件在设备之间手动同步，完全离线可用。';

  String get backupPath => '$filePath.bak';

  void _validatePath() {
    final String path = filePath.trim();
    if (path.isEmpty) throw const SyncException('请先选择备份文件');
    if (Uri.tryParse(path)?.hasScheme ?? false) {
      throw const SyncException('请使用系统文件选择器导入或导出文件');
    }
    if (!File(path).isAbsolute) throw const SyncException('请选择完整的文件路径');
  }

  @override
  Future<SyncTestResult> testConnection() async {
    try {
      _validatePath();
    } on SyncException catch (e) {
      return SyncTestResult(ok: false, message: e.message);
    }
    final File file = File(filePath);
    final Directory parent = file.parent;
    if (!parent.existsSync()) {
      return SyncTestResult(ok: false, message: '目录不存在：${parent.path}');
    }
    try {
      final File probe = File('${parent.path}/.materialword-write-probe-$pid');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
    } catch (e) {
      return SyncTestResult(ok: false, message: '目录不可写：$e');
    }
    final List<String> details = <String>[
      'NO_CONDITIONAL_WRITE:本地文件仅支持手动合并，不保证跨进程并发安全',
    ];
    if (file.existsSync()) {
      details.add('现有文件 ${await file.length()} 字节');
    } else {
      details.add('文件尚未创建，首次同步会写入');
    }
    if (File(backupPath).existsSync()) {
      details.add('保留上一版本：$backupPath');
    }
    return SyncTestResult(
      ok: true,
      message: '目标目录可写：${parent.path}',
      details: details,
    );
  }

  /// `v1:<sha256>` over the raw bytes. Deterministic and independent of mtime.
  static String revisionOf(List<int> bytes) => 'v1:${sha256.convert(bytes)}';

  @override
  Future<SyncPayload?> download() async {
    _validatePath();
    final File file = File(filePath);
    if (!file.existsSync()) return null;
    List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      throw SyncDataException('读取同步文件失败：$e');
    }
    if (bytes.isEmpty) {
      throw const SyncDataException('同步文件为空');
    }
    Object? decoded;
    try {
      decoded = await decodeDatasetJson(utf8.decode(bytes));
    } on FormatException {
      throw const SyncDataException('同步文件不是合法 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const SyncDataException('同步文件根节点必须是对象');
    }
    return SyncPayload(
      dataset: decoded,
      revision: revisionOf(bytes),
      updatedAt: file.lastModifiedSync(),
      contentHash: revisionOf(bytes),
      rawLength: bytes.length,
    );
  }

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async {
    _validatePath();
    final File file = File(filePath);
    if (ifRevision == null && file.existsSync()) {
      throw const SyncConflictException('同步文件已存在，请先读取并合并');
    }
    if (ifRevision != null) {
      if (!file.existsSync()) {
        throw const SyncConflictException('同步文件已被删除，请重新读取后再上传');
      }
      final String current = revisionOf(await file.readAsBytes());
      if (current != ifRevision) {
        throw const SyncConflictException('同步文件已被其他设备修改，已重新读取并合并');
      }
    }

    final String json = await encodeDatasetJson(dataset, pretty: true);
    final Directory parent = file.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }

    // Keep the last known-good copy before replacing anything.
    if (file.existsSync()) {
      try {
        await file.copy(backupPath);
      } catch (_) {
        // A missing backup must not block the write; the temp+rename below is
        // the actual durability guarantee.
      }
    }

    final File temp = File('$filePath.tmp-$pid');
    try {
      await temp.writeAsString(json, flush: true);
      await temp.rename(filePath);
    } catch (e) {
      if (temp.existsSync()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
      throw SyncException('写入同步文件失败（原文件保持不变）：$e');
    }

    final List<int> written = await file.readAsBytes();
    return SyncUploadResult(
      ok: true,
      message: '已写入 ${file.path}',
      revision: revisionOf(written),
    );
  }
}
