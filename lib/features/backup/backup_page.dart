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

/// Local backup / restore / merge plus the (planned) sync providers.
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
      appBar: AppBar(title: const Text('备份与同步')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.gutter),
        children: <Widget>[
          ContentWidth(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_error != null) ErrorBanner(message: _error!),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                SectionCard(
                  title: '本地备份',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '备份是带版本号的 JSON 文件，包含词条、词书、作答历史和学习设置。'
                        '不包含任何 Token 或密码。',
                        style: theme.textTheme.bodySmall,
                      ),
                      AppSpacing.h16,
                      Wrap(
                        spacing: AppDimens.compactGutter,
                        runSpacing: AppDimens.compactGutter,
                        children: <Widget>[
                          ElevatedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _export(chooseLocation: true),
                            icon: const Icon(Icons.save_alt),
                            label: const Text('导出到…'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _export(chooseLocation: false),
                            icon: const Icon(Icons.folder_outlined),
                            label: const Text('导出到应用目录'),
                          ),
                          TextButton.icon(
                            onPressed: _busy ? null : _import,
                            icon: const Icon(Icons.restore),
                            label: const Text('导入并合并'),
                          ),
                        ],
                      ),
                      if (_lastBackup != null) ...<Widget>[
                        AppSpacing.h12,
                        Text(
                          '上次导出：${formatDateTime(DateTime.parse(_lastBackup!))}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (_status != null) ...<Widget>[
                        AppSpacing.h12,
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.06,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radius,
                            ),
                          ),
                          child: Text(
                            _status!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AppSpacing.h16,
                SectionCard(
                  title: '同步方式',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _ProviderRow(
                        label: '本地文件',
                        description: '导出 / 导入 JSON 文件，第一版完全可用。',
                        implemented: true,
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      const _ProviderRow(
                        label: 'GitHub 私有仓库',
                        description: '计划中：REST API + Fine-grained PAT（仅存安全存储）+ SHA 并发处理。',
                        implemented: false,
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      const _ProviderRow(
                        label: 'WebDAV',
                        description: '计划中：HTTPS + ETag 条件请求，禁止关闭证书校验。',
                        implemented: false,
                      ),
                      AppSpacing.h16,
                      Text(
                        '合并规则：作答记录按全局 ID 去重，学习状态由合并后的历史重新计算，'
                        '同一份备份重复导入不会重复计入统计。',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                AppSpacing.h24,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.label,
    required this.description,
    required this.implemented,
  });

  final String label;
  final String description;
  final bool implemented;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            implemented ? Icons.check_circle_outline : Icons.construction,
            size: AppDimens.iconSizeSmall,
            color: implemented ? AppColors.known : theme.disabledColor,
          ),
          AppSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$label${implemented ? '' : '（未实现）'}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
