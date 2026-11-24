import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/time_utils.dart';
import '../../services/backup_service.dart';
import '../../shared/widgets/common.dart';
import '../sync/sync_settings_page.dart';

/// Local backup / restore / merge. Cross-device sync has its own page so this
/// one stays a simple "export / import" screen.
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  String? _status;
  String? _lastBackup;
  String? _error;

  static const String _lastBackupKey = 'last_backup_at';

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final String? value = await ref
        .read(databaseProvider)
        .readMeta(_lastBackupKey);
    if (!mounted) return;
    setState(() => _lastBackup = value);
  }

  Future<String> _appDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docs.path}/MaterialWord');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<void> _export({required bool chooseLocation}) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final DateTime now = ref.read(clockProvider).now();
      final BackupService service = ref.read(backupServiceProvider);
      final String json = await service.exportToJson(now: now);
      String message;
      if (chooseLocation) {
        final Uri? target = await FilePicker.saveFile(
          fileName: 'materialword-backup.json',
          bytes: utf8.encode(json),
          mimeType: 'application/json',
          dialogTitle: '保存备份文件',
        );
        if (target == null) {
          setState(() => _busy = false);
          return;
        }
        message = '已导出到 ${target.toFilePath()}';
      } else {
        final Directory dir = Directory(await _appDirectory());
        final File file = await service.writeBackupFile(
          directory: dir,
          now: now,
        );
        message = '已导出到 ${file.path}';
      }
      await ref
          .read(databaseProvider)
          .writeMeta(_lastBackupKey, now.toIso8601String());
      await _loadLastBackup();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '导出失败：$e';
      });
    }
  }

  Future<void> _import() async {
    setState(() {
      _error = null;
      _status = null;
    });
    final List<PlatformFile> files = await FilePicker.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (files.isEmpty) return;
    final String? path = files.first.path;
    if (path == null) {
      setState(() => _error = '无法读取该文件');
      return;
    }
    setState(() => _busy = true);
    try {
      final MergeReport report = await ref
          .read(backupServiceProvider)
          .importFromFile(path);
      ref.invalidate(todayProgressProvider);
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(statisticsProvider);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = report.summary;
      });
    } on BackupException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '${e.message}（本地数据未被修改）';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '导入失败：$e（本地数据未被修改）';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ErrorBanner(message: _error!),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          SectionHeader(title: '本地备份（JSON）'),
          SettingsGroup(
            children: <Widget>[
              SettingsTile(
                leading: const Icon(Icons.save_alt),
                title: '导出到…',
                subtitle: '通过系统文件选择器保存到任意位置',
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _export(chooseLocation: true),
              ),
              SettingsTile(
                leading: const Icon(Icons.folder_outlined),
                title: '导出到应用目录',
                subtitle: '保存在应用文档目录，便于再同步或手动拷贝',
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _export(chooseLocation: false),
              ),
              SettingsTile(
                leading: const Icon(Icons.restore),
                title: '导入并合并',
                subtitle: '不会覆盖本地数据：按单词与作答记录去重后合并',
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _import,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '备份是带版本号（schemaVersion 2）的 JSON 文件，包含词条、词书、'
                  '词书关联（含删除标记）、作答历史和学习目标。'
                  '不包含 Token、密码、主题或设备 ID。',
                  style: theme.textTheme.bodySmall,
                ),
                if (_lastBackup != null) ...<Widget>[
                  AppSpacing.h8,
                  Text(
                    '上次导出：${formatDateTime(DateTime.parse(_lastBackup!))}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (_status != null) ...<Widget>[
                  AppSpacing.h8,
                  Text(_status!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          SectionHeader(title: '跨设备同步'),
          SettingsGroup(
            children: <Widget>[
              SettingsTile(
                leading: const Icon(Icons.sync),
                title: '打开数据同步',
                subtitle: 'GitHub 私有仓库 / WebDAV / 本地文件',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const SyncSettingsPage(),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '合并规则：作答记录按全局 ID 去重，学习状态由合并后的历史重新计算；'
              '词书关联带版本与删除标记，因此旧备份不会让已移除的单词复活；'
              '同一份数据重复导入不会重复计入统计。',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
