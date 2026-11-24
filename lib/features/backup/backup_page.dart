import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/time_utils.dart';
import '../../services/backup_service.dart';
import '../../services/backup_files.dart';
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
      String message;
      if (chooseLocation) {
        final bool saved = await BackupFiles(service).export(now: now);
        if (!mounted) return;
        if (!saved) {
          setState(() => _busy = false);
          return;
        }
        message = '备份已导出';
      } else {
        final Directory dir = Directory(await _appDirectory());
        final File file = await service.writeBackupFile(
          directory: dir,
          now: now,
        );
        message = '恢复副本已保存';
        final files = await dir
            .list()
            .where(
              (f) =>
                  f is File &&
                  f.path.contains('materialword-backup-') &&
                  f.path.endsWith('.json'),
            )
            .cast<File>()
            .toList();
        files.sort((a, b) => b.path.compareTo(a.path));
        for (final old in files.skip(5)) {
          await old.delete();
        }
        assert(file.existsSync());
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
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final data = await BackupFiles(service).pick();
      if (data == null || !mounted) return;
      final words = (data['words'] as List?)?.length ?? 0;
      final books = (data['wordBooks'] as List?)?.length ?? 0;
      final events = (data['reviewEvents'] as List?)?.length ?? 0;
      final ok = await confirmDialog(
        context,
        title: '合并备份',
        message:
            '词条 $words 个，词书 $books 个，学习记录 $events 条。\n'
            '备份时间：${data['exportedAt'] ?? '未记录'}\n将合并到本机，保留现有学习历史。',
        confirmLabel: '合并',
      );
      if (!ok || !mounted) return;
      final report = await service.mergeDataset(
        data,
        now: ref.read(clockProvider).now(),
      );
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
        _error = '导入失败，请检查文件并重试（本地数据未被修改）';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
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
                title: '保存恢复副本',
                subtitle: '保留最近 5 份；需要取出备份时使用「导出到…」',
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
                  '备份包含词条、词书、'
                  '词书关联（含删除标记）、作答历史和学习目标。'
                  '不包含 Token 或密码，不会覆盖本机主题和设备身份。',
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
