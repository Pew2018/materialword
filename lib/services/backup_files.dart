import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'backup_service.dart';

/// A picked Android document is handled by the plugin, never as a raw content URI.
/// No long-lived SAF grant or security-scoped bookmark is claimed by this manual workflow.
class BackupFiles {
  const BackupFiles(this.backup);
  final BackupService backup;

  Future<bool> export({required DateTime now}) async {
    final json = await backup.exportToJson(now: now);
    final result = await FilePicker.saveFile(
      fileName: 'materialword-backup.json',
      bytes: utf8.encode(json),
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
