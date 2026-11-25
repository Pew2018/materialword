import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/time_utils.dart';
import '../../services/backup_manager.dart';
import '../../services/backup_service.dart';
import '../../services/backup_files.dart';
import '../../l10n/backup_labels.dart';
import '../../l10n/sync_labels.dart';
import '../../l10n/l10n.dart';
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
      setState(
        () => _status = saved
            ? context.l10n.backupExportedShort
            : context.l10n.exportCanceled,
      );
      return;
    }
    final File file = await manager.createBackup();
    await _reload();
    if (!mounted) return;
    setState(
      () => _status = context.l10n.backupSavedAs(file.uri.pathSegments.last),
    );
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
      title: context.l10n.mergeBackup,
      message: context.l10n.mergeConfirmBody(
        words,
        books,
        events,
        '${data['exportedAt'] ?? context.l10n.timeNotRecorded}',
      ),
      confirmLabel: context.l10n.merge,
    );
    if (!ok || !mounted) return;
    final MergeReport report = await service.mergeDataset(
      data,
      now: ref.read(clockProvider).now(),
    );
    _refreshData();
    if (!mounted) return;
    setState(() => _status = mergeSummary(context.l10n, report));
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
        title: Text(
          verify ? context.l10n.checkBackup : context.l10n.backupInfo,
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(entry.name, style: Theme.of(context).textTheme.bodySmall),
            AppSpacing.h8,
            if (info.valid) ...<Widget>[
              Text(backupInfoSummary(context.l10n, info)),
              AppSpacing.h8,
              Text(context.l10n.schemaVersionLine(info.schemaVersion)),
              if (info.exportedAt != null)
                Text(
                  context.l10n.createdAtLine(formatDateTime(info.exportedAt!)),
                ),
              if (info.appVersion.isNotEmpty)
                Text(context.l10n.appVersionLine(info.appVersion)),
              Text(
                context.l10n.hasDeviceSettingsLine(
                  info.hasDeviceSettings ? context.l10n.yes : context.l10n.no,
                ),
              ),
              AppSpacing.h8,
              Text(
                verify
                    ? context.l10n.integrityPassed
                    : context.l10n.integrityUnchecked,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              Text(
                info.problem ?? context.l10n.cannotReadBackup,
                style: TextStyle(color: AppColors.unknown),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.close),
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
      setState(
        () => _error = context.l10n.backupUnreadable(
          info.problem ?? context.l10n.unknownReason,
        ),
      );
      return;
    }
    if (!mounted) return;
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.mergeRestore,
      message: context.l10n.mergeRestoreConfirm(
        backupInfoSummary(context.l10n, info),
      ),
      confirmLabel: context.l10n.merge,
    );
    if (!ok || !mounted) return;
    final MergeReport report = await ref
        .read(backupManagerProvider)
        .restoreMerge(entry.file);
    _refreshData();
    if (!mounted) return;
    setState(
      () => _status = context.l10n.mergeCompleteWith(
        mergeSummary(context.l10n, report),
      ),
    );
  });

  Future<void> _restoreSnapshot(BackupEntry entry) => _run(() async {
    final BackupManager manager = ref.read(backupManagerProvider);
    final BackupInfo info = await manager.inspect(entry.file);
    if (!info.valid) {
      if (!mounted) return;
      setState(
        () => _error = context.l10n.backupUnreadable(
          info.problem ?? context.l10n.unknownReason,
        ),
      );
      return;
    }
    if (!mounted) return;
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.restoreVersionTitle,
      message: context.l10n.restoreSnapshotConfirm(
        backupInfoSummary(context.l10n, info),
        info.exportedAt == null
            ? context.l10n.createdUnknown
            : formatDateTime(info.exportedAt!),
      ),
      confirmLabel: context.l10n.restore,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final RestoreOutcome outcome = await manager.restoreSnapshot(entry.file);
    _refreshData();
    await _reload();
    if (!mounted) return;
    setState(
      () => _status = context.l10n.restoreDoneWith(
        restoreSummary(context.l10n, outcome),
        outcome.protectiveBackup.uri.pathSegments.last,
      ),
    );
    await _askAfterRestore();
  });

  Future<void> _askAfterRestore() async {
    if (!mounted) return;
    final String? choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.l10n.restoreNextStepTitle),
        content: Text(context.l10n.restoreNextStepBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop('stay'),
            child: Text(context.l10n.keepLocalState),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('new-target'),
            child: Text(context.l10n.useNewTarget),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('merge-remote'),
            child: Text(context.l10n.mergeRemoteData),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'stay') {
      setState(() => _status = context.l10n.syncPausedRemoteUnchanged);
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
        setState(() => _error = context.l10n.noSyncTargetHint);
        return;
      }
      final report = await ref
          .read(syncCoordinatorProvider)
          .sync(provider, resumeAfterRestore: true);
      _refreshData();
      if (!mounted) return;
      setState(() => _status = describeSyncReport(context.l10n, report));
      await _reload();
    });
  }

  Future<void> _clearPauseIfTargetChanged() async {
    final bool paused = await ref.read(settingsRepositoryProvider).syncPaused();
    if (paused && mounted) {
      setState(() => _status = context.l10n.syncStillPausedUntilTarget);
      await _reload();
    }
  }

  Future<void> _delete(BackupEntry entry) async {
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.deleteBackupTitle,
      message: context.l10n.deleteBackupBody(entry.name),
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(backupManagerProvider).delete(entry.file);
      await _reload();
      if (!mounted) return;
      setState(() => _status = context.l10n.backupDeleted);
    });
  }

  Future<void> _exportCopy(BackupEntry entry) => _run(() async {
    final bool saved = await ref
        .read(backupManagerProvider)
        .exportCopy(entry.file);
    if (!mounted) return;
    setState(
      () => _status = saved
          ? context.l10n.backupExportedShort
          : context.l10n.exportCanceled,
    );
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: ClassicAppBar(title: Text(context.l10n.backupAndRestore)),
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
                          Text(
                            context.l10n.syncPausedBanner,
                            style: theme.textTheme.titleSmall,
                          ),
                          AppSpacing.h4,
                          Text(
                            context.l10n.syncPausedBannerBody,
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
                            child: Text(context.l10n.handleSync),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SectionHeader(title: context.l10n.autoBackupLocal),
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
                    title: Text(context.l10n.autoBackupDaily),
                    subtitle: Text(
                      context.l10n.autoBackupHintCount(_retention),
                    ),
                  ),
                  SettingsTile(
                    leading: const Icon(Icons.history_toggle_off),
                    title: context.l10n.lastAutoBackup,
                    subtitle: _lastAuto == null
                        ? context.l10n.noAutoBackupYet
                        : formatDateTime(_lastAuto!),
                  ),
                ],
              ),
              SectionHeader(title: context.l10n.manualBackupJson),
              SettingsGroup(
                children: <Widget>[
                  SettingsTile(
                    leading: const Icon(Icons.save_alt),
                    title: context.l10n.exportTo,
                    subtitle: context.l10n.exportToHint,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () => _createBackup(chooseLocation: true),
                  ),
                  SettingsTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: context.l10n.saveBackupNow,
                    subtitle: context.l10n.saveBackupNowHint,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () => _createBackup(chooseLocation: false),
                  ),
                  SettingsTile(
                    leading: const Icon(Icons.restore),
                    title: context.l10n.importAndMerge,
                    subtitle: context.l10n.importAndMergeHint,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : _importMerge,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  context.l10n.backupContentsNote,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(_status!, style: theme.textTheme.bodyMedium),
                ),
              SectionHeader(title: context.l10n.localBackups),
              if (_backups.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    context.l10n.noLocalBackups,
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
                          tooltip: context.l10n.backupActions,
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
                              <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'info',
                                  child: Text(context.l10n.viewInfo),
                                ),
                                PopupMenuItem<String>(
                                  value: 'verify',
                                  child: Text(context.l10n.checkIntegrity),
                                ),
                                PopupMenuItem<String>(
                                  value: 'merge',
                                  child: Text(context.l10n.mergeRestoreSafe),
                                ),
                                PopupMenuItem<String>(
                                  value: 'restore',
                                  child: Text(context.l10n.restoreThisVersion),
                                ),
                                PopupMenuItem<String>(
                                  value: 'export',
                                  child: Text(context.l10n.exportTo),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text(context.l10n.commonDelete),
                                ),
                              ],
                        ),
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  context.l10n.restoreModesNote,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SectionHeader(title: context.l10n.crossDeviceSync),
              SettingsGroup(
                children: <Widget>[
                  SettingsTile(
                    leading: const Icon(Icons.sync),
                    title: context.l10n.openSync,
                    subtitle: context.l10n.syncTargetsHint,
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
                  context.l10n.mergeNeverOverwrites,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              ExpansionTile(
                title: Text(
                  context.l10n.mergeRulesAdvanced,
                  style: theme.textTheme.bodyMedium,
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: <Widget>[
                  Text(
                    context.l10n.mergeRulesBody,
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
