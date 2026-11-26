import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'backup_service.dart';

/// Where recovery copies live. One place so the page, the manager and the
/// automatic scheduler cannot disagree about the directory.
class BackupPaths {
  const BackupPaths._();

  static Future<Directory> appDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docs.path}/MaterialWord');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}

/// A picked Android document is handled by the plugin, never as a raw content URI.
/// No long-lived SAF grant or security-scoped bookmark is claimed by this manual workflow.
class BackupFiles {
  const BackupFiles(this.backup);
  final BackupService backup;

  Future<bool> export({required DateTime now}) async {
    final json = await backup.exportToJson(now: now);
    return exportWithJson(json);
  }

  /// Saves an already encoded backup document through the system dialog.
  Future<bool> exportWithJson(
    String json, {
    String fileName = 'materialword-backup.json',
  }) async {
    final portable = BackupService.portableCopy(backup.decodeDataset(json));
    final result = await FilePicker.saveFile(
      fileName: fileName,
      bytes: utf8.encode(await encodeDatasetJson(portable)),
      mimeType: 'application/json',
      dialogTitle: '保存备份文件',
    );
    return result != null;
  }

  Future<Map<String, Object?>?> pick() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty) return null;
    final path = files.first.path;
    if (path == null || (Uri.tryParse(path)?.hasScheme ?? false)) {
      throw const BackupException('无法读取所选文件，请先保存到本机后重试');
    }
    final file = File(path);
    if (await file.length() > 100 * 1024 * 1024) {
      throw const BackupException('备份超过 100 MB，请在桌面端处理');
    }
    return backup.decodeDatasetAsync(await file.readAsString());
  }
}
