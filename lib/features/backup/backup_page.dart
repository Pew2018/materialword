import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/time_utils.dart';
import '../../services/backup_manager.dart';
import '../../services/backup_service.dart';
import '../../services/backup_files.dart';
import '../../shared/widgets/common.dart';
import '../sync/sync_settings_page.dart';

/// Backup, automatic recovery copies, and both restore modes.
///
/// The page only renders and confirms: every operation lives in
/// `BackupManager`, so it can be tested without a widget tree.
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  String? _status;
  String? _error;
  List<BackupEntry> _backups = const <BackupEntry>[];
  bool _autoEnabled = true;
  DateTime? _lastAuto;
  bool _syncPaused = false;
  int _retention = 5;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final BackupManager manager = ref.read(backupManagerProvider);
    final List<BackupEntry> entries = await manager.list();
    final bool autoEnabled = await ref
        .read(settingsRepositoryProvider)
        .autoBackupEnabled();
    final DateTime? lastAuto = await ref
        .read(settingsRepositoryProvider)
        .lastAutoBackupAt();
    final int retention = await ref
        .read(settingsRepositoryProvider)
        .autoBackupRetention();
    final bool paused = await ref.read(settingsRepositoryProvider).syncPaused();
    if (!mounted) return;
    setState(() {
      _backups = entries;
      _autoEnabled = autoEnabled;
      _lastAuto = lastAuto;
      _retention = retention;
      _syncPaused = paused;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBackup({required bool chooseLocation}) => _run(() async {
    final BackupManager manager = ref.read(backupManagerProvider);
    if (chooseLocation) {
      final String json = await ref
          .read(backupServiceProvider)
          .exportToJson(now: ref.read(clockProvider).now());
      final bool saved = await BackupFiles(ref.read(backupServiceProvider))
          .exportWithJson(json);
      if (!mounted) return;
      setState(() => _status = saved ? '备份已导出' : '已取消导出');
      return;
    }
    final File file = await manager.createBackup();
    await _reload();
    if (!mounted) return;
    setState(() => _status = '恢复副本已保存：${file.uri.pathSegments.last}');
  });

  Future<void> _importMerge() => _run(() async {
    final BackupService service = ref.read(backupServiceProvider);
    final Map<String, Object?>? data = await BackupFiles(service).pick();
    if (data == null || !mounted) return;
    final int words = (data['words'] as List?)?.length ?? 0;
    final int books = (data['wordBooks'] as List?)?.length ?? 0;
    final int events = (data['reviewEvents'] as List?)?.length ?? 0;
    final bool ok = await confirmDialog(
      context,
      title: '合并备份',
      message:
          '词条 $words 个，词书 $books 个，学习记录 $events 条。\n'
          '备份时间：${data['exportedAt'] ?? '未记录'}\n'
          '将合并到本机，保留现有学习历史；不会删除本机任何数据。',
      confirmLabel: '合并',
    );
    if (!ok || !mounted) return;
    final MergeReport report = await service.mergeDataset(
      data,
      now: ref.read(clockProvider).now(),
    );
    _refreshData();
    if (!mounted) return;
    setState(() => _status = report.summary);
  });

  void _refreshData() {
    ref.invalidate(todayProgressProvider);
    ref.invalidate(bookSummariesProvider);
    ref.invalidate(statisticsProvider);
    ref.invalidate(pausedSessionProvider);
  }

  Future<void> _showInfo(BackupEntry entry, {bool verify = false}) async {
    final BackupInfo info = await ref
        .read(backupManagerProvider)
        .inspect(entry.file);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(verify ? '校验恢复副本' : '恢复副本信息'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(entry.name, style: Theme.of(context).textTheme.bodySmall),
            AppSpacing.h8,
            if (info.valid) ...<Widget>[
              Text(info.summary),
              AppSpacing.h8,
              Text('数据格式：v${info.schemaVersion}'),
              if (info.exportedAt != null)
                Text('创建时间：${formatDateTime(info.exportedAt!)}'),
              if (info.appVersion.isNotEmpty) Text('应用版本：${info.appVersion}'),
              Text('包含设备设置：${info.hasDeviceSettings ? '是' : '否'}'),
              AppSpacing.h8,
              Text(
                verify ? '完整性校验通过：文件可以安全读取。' : '完整性：未校验（点「校验」可读取并验证）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              Text(
                info.problem ?? '无法读取',
                style: TextStyle(color: AppColors.unknown),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _mergeRestore(BackupEntry entry) => _run(() async {
    final BackupInfo info = await ref
        .read(backupManagerProvider)
        .inspect(entry.file);
    if (!info.valid) {
      if (!mounted) return;
      setState(() => _error = '该副本无法读取：${info.problem}');
      return;
    }
    if (!mounted) return;
    final bool ok = await confirmDialog(
      context,
      title: '合并恢复',
      message:
          '${info.summary}\n\n合并只补充本机缺少的词条与学习记录，'
          '保留现有数据与学习进度。这是默认的安全恢复方式。',
      confirmLabel: '合并',
    );
    if (!ok || !mounted) return;
    final MergeReport report = await ref
        .read(backupManagerProvider)
        .restoreMerge(entry.file);
    _refreshData();
    if (!mounted) return;
    setState(() => _status = '合并完成：${report.summary}');
  });

  Future<void> _restoreSnapshot(BackupEntry entry) => _run(() async {
    final BackupManager manager = ref.read(backupManagerProvider);
    final BackupInfo info = await manager.inspect(entry.file);
    if (!info.valid) {
      if (!mounted) return;
      setState(() => _error = '该副本无法读取：${info.problem}');
      return;
    }
    if (!mounted) return;
    final bool ok = await confirmDialog(
      context,
      title: '恢复到该历史版本？',
      message:
          '${info.summary}\n创建时间：${info.exportedAt == null ? '未知' : formatDateTime(info.exportedAt!)}'
          '\n\n这会用该备份**替换**本机当前数据：'
          '此后的学习记录、编辑和删除都会丢失。'
          '操作前会自动保存一份保护性备份，失败时整体回滚。'
          '恢复后同步会暂停，直到你决定如何处理远端数据。',
      confirmLabel: '恢复',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final RestoreOutcome outcome = await manager.restoreSnapshot(entry.file);
    _refreshData();
    await _reload();
    if (!mounted) return;
    setState(
      () => _status =
          '${outcome.summary}；恢复前状态已保存为 ${outcome.protectiveBackup.uri.pathSegments.last}',
    );
    await _askAfterRestore();
  });

  Future<void> _askAfterRestore() async {
    if (!mounted) return;
    final String? choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('恢复完成：如何使用远端数据？'),
        content: const Text(
          '本机已恢复为所选历史版本，同步保持暂停。请选择下一步：\n\n'
          '· 保持本机状态：暂不同步，稍后可在「数据同步」页处理。\n'
          '· 合并远端数据：把远端设备的数据并回本机（只增不减）。\n'
          '· 使用新的同步目标：为恢复后的数据换一个远端位置。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop('stay'),
            child: const Text('保持本机状态'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('new-target'),
            child: const Text('使用新的同步目标'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('merge-remote'),
            child: const Text('合并远端数据'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'stay') {
      setState(() => _status = '同步保持暂停：远端数据未被修改');
      return;
    }
    if (choice == 'new-target') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const SyncSettingsPage(),
        ),
      );
      await _clearPauseIfTargetChanged();
      return;
    }
    // Explicit, user-confirmed: un-pause, then merge the remote into this device.
    await _run(() async {
      await ref.read(settingsRepositoryProvider).setSyncPaused(false);
      final Map<String, Object?>? config = await ref
          .read(settingsRepositoryProvider)
          .syncConfig();
      final provider = ref
          .read(syncCoordinatorProvider)
          .providerFromConfig(config);
      if (!mounted) return;
      if (provider == null) {
        setState(() => _error = '尚未配置同步目标，可在「数据同步」页设置');
        return;
      }
      final report = await ref
          .read(syncCoordinatorProvider)
          .sync(provider, resumeAfterRestore: true);
      _refreshData();
      if (!mounted) return;
      setState(() => _status = '远端数据已合并：${report.message}');
      await _reload();
    });
  }

  Future<void> _clearPauseIfTargetChanged() async {
    final bool paused = await ref.read(settingsRepositoryProvider).syncPaused();
    if (paused && mounted) {
      setState(() => _status = '同步仍暂停：在新目标完成一次同步后会解除');
      await _reload();
    }
  }

  Future<void> _delete(BackupEntry entry) async {
    final bool ok = await confirmDialog(
      context,
      title: '删除这份恢复副本？',
      message: '${entry.name}\n\n只会删除这个本机文件；数据库里的学习数据不受影响。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(backupManagerProvider).delete(entry.file);
      await _reload();
      if (!mounted) return;
      setState(() => _status = '已删除恢复副本');
    });
  }

  Future<void> _exportCopy(BackupEntry entry) => _run(() async {
    final bool saved = await ref
        .read(backupManagerProvider)
        .exportCopy(entry.file);
    if (!mounted) return;
    setState(() => _status = saved ? '已导出恢复副本' : '已取消导出');
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: ClassicAppBar(title: const Text('备份与恢复')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ContentColumn(
          child: ListView(
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
              if (_syncPaused)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Material(
                    color: AppColors.hazy.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('同步已暂停', style: theme.textTheme.titleSmall),
                          AppSpacing.h4,
                          Text(
                            '本机数据来自历史恢复，尚未与远端核对。'
                            '在「数据同步」页确认如何处理远端数据前，自动同步不会运行。',
                            style: theme.textTheme.bodySmall,
                          ),
                          AppSpacing.h8,
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    await Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (BuildContext context) =>
                                            const SyncSettingsPage(),
                                      ),
                                    );
                                    await _reload();
                                  },
                            child: const Text('处理同步'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SectionHeader(title: '自动备份（本机）'),
              SettingsGroup(
                children: <Widget>[
                  SwitchListTile(
                    value: _autoEnabled,
                    onChanged: (bool value) async {
                      await ref
                          .read(settingsRepositoryProvider)
                          .setAutoBackupEnabled(value);
                      await _reload();
                    },
                    title: const Text('每天自动备份'),
                    subtitle: Text(
                      '启动、恢复前台与停留前台期间检查；只有数据变化才创建新副本，'
                      '保留最近 $_retention 份。',
                    ),
                  ),
                  SettingsTile(
                    leading: const Icon(Icons.history_toggle_off),
                    title: '上次自动备份',
                    subtitle: _lastAuto == null
                        ? '还没有自动备份'
                        : formatDateTime(_lastAuto!),
                  ),
                ],
              ),
              SectionHeader(title: '手动备份（JSON）'),
              SettingsGroup(
                children: <Widget>[
                  SettingsTile(
                    leading: const Icon(Icons.save_alt),
                    title: '导出到…',
                    subtitle: '通过系统文件选择器保存到任意位置（含设备设置）',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () => _createBackup(chooseLocation: true),
                  ),
                  SettingsTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: '立即保存恢复副本',
                    subtitle: '保存在本机；可直接从下方列表恢复',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () => _createBackup(chooseLocation: false),
                  ),
                  SettingsTile(
                    leading: const Icon(Icons.restore),
                    title: '导入并合并',
                    subtitle: '不会覆盖本地数据：按单词与作答记录去重后合并',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : _importMerge,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '备份包含词条、词书、关联（含删除标记）、作答历史、收藏、标签、'
                  '学习目标与设备设置。不包含账号、密码或任何同步凭据。',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(_status!, style: theme.textTheme.bodyMedium),
                ),
              SectionHeader(title: '恢复副本（本机）'),
              if (_backups.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    '还没有恢复副本。自动备份或「立即保存恢复副本」会在此列出。',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                SettingsGroup(
                  children: <Widget>[
                    for (final BackupEntry entry in _backups)
                      SettingsTile(
                        leading: Icon(switch (entry.kind) {
                          BackupKind.automatic => Icons.schedule,
                          BackupKind.protective => Icons.shield_outlined,
                          BackupKind.manual => Icons.history,
                        }),
                        title: formatDateTime(entry.modified),
                        subtitle:
                            '${entry.kind.label} · '
                            '${(entry.bytes / 1024 / 1024).toStringAsFixed(1)} MB · '
                            '${entry.name}',
                        trailing: PopupMenuButton<String>(
                          tooltip: '恢复副本操作',
                          onSelected: (String value) {
                            switch (value) {
                              case 'info':
                                _showInfo(entry);
                              case 'verify':
                                _showInfo(entry, verify: true);
                              case 'merge':
                                _mergeRestore(entry);
                              case 'restore':
                                _restoreSnapshot(entry);
                              case 'export':
                                _exportCopy(entry);
                              case 'delete':
                                _delete(entry);
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              const <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'info',
                                  child: Text('查看信息'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'verify',
                                  child: Text('校验备份'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'merge',
                                  child: Text('合并恢复（安全）'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'restore',
                                  child: Text('恢复到该版本…'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'export',
                                  child: Text('导出到…'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                        ),
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '合并恢复：只补充缺失内容，幂等、可重复执行。\n'
                  '指定版本恢复：原子替换本机数据，先自动保存保护性备份，'
                  '并暂停同步直到你决定远端如何处理。',
                  style: theme.textTheme.bodySmall,
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
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              const SyncSettingsPage(),
                        ),
                      );
                      await _reload();
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '合并只会补充缺失的内容，不会覆盖已有的单词和学习记录；'
                  '同一份文件重复导入也不会重复计数。',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              ExpansionTile(
                title: Text('合并规则（高级）', style: theme.textTheme.bodyMedium),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: <Widget>[
                  Text(
                    '作答记录按全局 ID 去重，学习状态由合并后的历史重新计算；'
                    '词书关联带版本与删除标记，因此旧备份不会让已移除的单词复活。',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
