import '../wordbooks/library_page.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/time_utils.dart';
import '../../l10n/backup_labels.dart';
import '../../l10n/error_labels.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/classic_select.dart';
import '../../shared/widgets/common.dart';
import '../../services/backup_files.dart';
import '../../services/cloud_backup/cloud_backup_coordinator.dart';
import '../../services/cloud_backup/cloud_backup_provider.dart';
import '../../services/cloud_backup/cloud_backup_repository.dart';
import '../sync/sync_settings_page.dart';

String _stageLabel(AppLocalizations l10n, CloudBackupStage stage) =>
    switch (stage) {
      CloudBackupStage.deleting => l10n.cloudBackupDeleting,
      CloudBackupStage.uploading => l10n.cloudBackupUploadProgress,
      CloudBackupStage.verifying => l10n.cloudBackupVerifyProgress,
      CloudBackupStage.downloading => l10n.cloudBackupDownloadProgress,
      CloudBackupStage.listing => l10n.cloudBackupListing,
      CloudBackupStage.validating => l10n.cloudBackupValidating,
      CloudBackupStage.exporting => l10n.cloudBackupPreparing,
      _ => l10n.cloudBackupPreparing,
    };

class CloudBackupDialog extends ConsumerStatefulWidget {
  const CloudBackupDialog({super.key});
  @override
  ConsumerState<CloudBackupDialog> createState() => _CloudBackupDialogState();
}

class _CloudBackupDialogState extends ConsumerState<CloudBackupDialog> {
  List<CloudBackupConfig>? configs;
  String? selected;
  Map<String, dynamic>? last;
  String? error;

  /// Monotonic token for the "last successful backup" lookup.
  ///
  /// Switching S3 → WebDAV → S3 fires three overlapping queries; without this
  /// a slow answer for the first one could land last and show the wrong
  /// target's history under the current one.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(cloudBackupRepositoryProvider);
    final values = await repository.configured();
    final preferred = await repository.preferred();
    if (!mounted) return;
    setState(() {
      configs = values;
      selected = values.any((c) => c.providerId == selected)
          ? selected
          : values.any((c) => c.providerId == preferred)
          ? preferred
          : values.firstOrNull?.providerId;
    });
    await _last();
  }

  Future<void> _last({int? generation}) async {
    final int token = generation ?? ++_generation;
    final String? id = selected;
    final config = configs?.where((c) => c.providerId == id).firstOrNull;
    final value = config == null
        ? null
        : await ref.read(cloudBackupRepositoryProvider).lastSuccess(config);
    if (!mounted || token != _generation || id != selected) return;
    setState(() => last = value);
  }

  Future<void> _selectTarget(String value) async {
    final int token = ++_generation;
    setState(() {
      selected = value;
      last = null;
      error = null;
    });
    // The preference is per device and independent of the sync configuration.
    await ref.read(cloudBackupRepositoryProvider).setPreferred(value);
    if (!mounted || token != _generation) return;
    await _last(generation: token);
  }

  Future<void> _upload() async {
    final id = selected;
    if (id == null) return;
    setState(() => error = null);
    try {
      await ref.read(cloudBackupCoordinatorProvider).upload(id);
      await _last();
    } catch (e) {
      if (mounted) {
        setState(() => error = describeCloudBackupError(context.l10n, e));
      }
    }
  }

  Future<void> _configure() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const SyncSettingsPage()));
    _load();
  }

  void _browse(CloudBackupConfig config) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CloudBackupBrowser(providerId: config.providerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(cloudBackupCoordinatorProvider);
    return AnimatedBuilder(
      animation: coordinator,
      builder: (context, _) {
        final AppLocalizations l10n = context.l10n;
        final bool running = coordinator.isRunning;
        final CloudBackupConfig? config = configs
            ?.where((c) => c.providerId == selected)
            .firstOrNull;
        final CloudBackupStage stage = coordinator.progress.stage;
        final CloudBackupReceipt? receipt = coordinator.lastUploadReceipt;
        // A success badge must belong to *this* target and *this* operation:
        // an old receipt from the other provider is not this backup's result.
        final bool succeeded =
            !running &&
            stage == CloudBackupStage.completed &&
            receipt != null &&
            receipt.operationId == coordinator.progress.operationId &&
            receipt.providerId == selected;

        return AlertDialog(
          title: Text(l10n.cloudBackupManual),
          scrollable: false,
          // A 40dp inset leaves a 360dp phone with a 280dp dialog; 24dp keeps
          // the form usable without turning the dialog into a sheet.
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          content: SizedBox(
            width: 390,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (configs == null) ...<Widget>[
                    const LinearProgressIndicator(),
                    AppSpacing.h8,
                    Text(l10n.cloudBackupListing),
                  ] else if (configs!.isEmpty) ...<Widget>[
                    Text(
                      l10n.cloudBackupNotConfigured,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    AppSpacing.h12,
                    NoticeBanner(message: l10n.cloudBackupIndependentHint),
                  ] else ...<Widget>[
                    ClassicSelect<String>(
                      label: l10n.cloudBackupTarget,
                      value: selected ?? '',
                      enabled: !running,
                      options: <ClassicOption<String>>[
                        for (final CloudBackupConfig value in configs!)
                          ClassicOption<String>(
                            value: value.providerId,
                            label: cloudBackupTargetLabel(value),
                          ),
                      ],
                      onChanged: running ? null : _selectTarget,
                    ),
                    AppSpacing.h16,
                    Text(
                      l10n.cloudBackupLastSuccess,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    AppSpacing.h4,
                    if (last == null)
                      Text(
                        l10n.cloudBackupNever,
                        style: Theme.of(context).textTheme.bodyLarge,
                      )
                    else
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.check_circle,
                            size: AppDimens.iconSizeSmall,
                            color: AppColors.known,
                          ),
                          AppSpacing.w8,
                          Expanded(
                            child: Text(
                              cloudBackupTime(l10n, last?['completedAt']),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    if (running) ...<Widget>[
                      AppSpacing.h16,
                      const LinearProgressIndicator(),
                      AppSpacing.h8,
                      Text(_stageLabel(l10n, stage)),
                      AppSpacing.h4,
                      Text(
                        l10n.cloudBackupRunningHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (succeeded) ...<Widget>[
                      AppSpacing.h16,
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.check_circle,
                            size: AppDimens.iconSizeSmall,
                            color: AppColors.known,
                          ),
                          AppSpacing.w8,
                          Expanded(
                            child: Text(
                              l10n.cloudBackupSucceeded,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.known),
                            ),
                          ),
                        ],
                      ),
                    ],
                    AppSpacing.h16,
                    Text(
                      l10n.cloudBackupIndependentHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (error != null) ...<Widget>[
                    AppSpacing.h12,
                    ErrorBanner(message: error!),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[_buildActions(running: running, config: config)],
        );
      },
    );
  }

  /// Primary actions on their own area, auxiliary actions on a quieter line.
  ///
  /// Four `TextButton`s in `AlertDialog.actions` were laid out by the
  /// `OverflowBar` into a right-aligned column once the labels did not fit on
  /// one run, which is what made the dialog tall and the hierarchy unclear.
  Widget _buildActions({
    required bool running,
    required CloudBackupConfig? config,
  }) {
    final AppLocalizations l10n = context.l10n;
    final Widget close = TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(l10n.commonClose),
    );
    final Widget configure = TextButton(
      onPressed: running ? null : _configure,
      child: Text(l10n.cloudBackupConfigure),
    );

    if (configs == null) {
      return SizedBox(
        width: double.infinity,
        child: Align(alignment: Alignment.centerRight, child: close),
      );
    }

    if (configs!.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ElevatedButton(
              onPressed: running ? null : _configure,
              child: Text(l10n.cloudBackupConfigure),
            ),
            AppSpacing.h4,
            Align(alignment: Alignment.centerRight, child: close),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _primaryActions(running: running, config: config),
          AppSpacing.h4,
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[configure, close],
          ),
        ],
      ),
    );
  }

  Widget _primaryActions({
    required bool running,
    required CloudBackupConfig? config,
  }) {
    final AppLocalizations l10n = context.l10n;
    final Widget download = OutlinedButton(
      onPressed: running || config == null ? null : () => _browse(config),
      child: Text(
        l10n.cloudBackupDownload,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final Widget upload = ElevatedButton(
      onPressed: running || config == null ? null : _upload,
      child: Text(
        l10n.cloudBackupUpload,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    // Two columns need ~150dp each plus the gap; below a 400dp window (a 360dp
    // phone, a large font, a narrow macOS window) the pair stacks full width
    // instead of shrinking the labels to nothing. The width comes from the
    // window rather than a `LayoutBuilder`: `AlertDialog` measures its actions
    // with intrinsics, which a layout builder cannot answer.
    final bool stack = MediaQuery.sizeOf(context).width < 400;
    if (stack) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[download, AppSpacing.h8, upload],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: download),
        AppSpacing.w8,
        Expanded(child: upload),
      ],
    );
  }
}

class CloudBackupBrowser extends ConsumerStatefulWidget {
  const CloudBackupBrowser({required this.providerId, super.key});
  final String providerId;
  @override
  ConsumerState<CloudBackupBrowser> createState() => _CloudBackupBrowserState();
}

class _CloudBackupBrowserState extends ConsumerState<CloudBackupBrowser> {
  final entries = <CloudBackupEntry>[];
  final tokens = <String>{};
  String? next;
  String? error;

  /// The object currently being downloaded, so a second tap on the same (or
  /// another) row cannot start an overlapping transfer or open a second
  /// "downloaded" dialog.
  String? downloading;
  bool loading = false;
  bool deleting = false;
  bool confirming = false;
  String? deletionStatus;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false, bool preserveError = false}) async {
    if (loading || deleting || confirming) return;
    setState(() {
      loading = true;
      if (!preserveError) error = null;
      if (reset) {
        entries.clear();
        tokens.clear();
        next = null;
      }
    });
    try {
      final page = await ref
          .read(cloudBackupCoordinatorProvider)
          .list(widget.providerId, continuationToken: next);
      if (page.continuationToken != null &&
          !tokens.add(page.continuationToken!)) {
        throw const CloudBackupException('Repeated listing token');
      }
      if (!mounted) return;
      setState(() {
        final seen = entries.map((e) => e.objectName).toSet();
        entries.addAll(page.entries.where((e) => seen.add(e.objectName)));
        entries.sort((a, b) {
          final order = (b.createdAt ?? b.lastModified ?? DateTime(0))
              .compareTo(a.createdAt ?? a.lastModified ?? DateTime(0));
          return order != 0 ? order : b.objectName.compareTo(a.objectName);
        });
        next = page.continuationToken;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = describeCloudBackupError(context.l10n, e));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _download(CloudBackupEntry entry) async {
    if (downloading != null) return;
    setState(() {
      downloading = entry.objectName;
      error = null;
    });
    try {
      final result = await ref
          .read(cloudBackupCoordinatorProvider)
          .download(entry);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _DownloadedBackupDialog(download: result),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = describeCloudBackupError(context.l10n, e));
      }
    } finally {
      if (mounted) setState(() => downloading = null);
    }
  }

  Future<void> _delete({CloudBackupEntry? entry}) async {
    if (loading || deleting || confirming || downloading != null) return;
    final coordinator = ref.read(cloudBackupCoordinatorProvider);
    setState(() {
      deleting = true;
      error = null;
      deletionStatus = null;
    });
    try {
      CloudBackupCleanupPlan? plan;
      if (entry == null) {
        plan = await coordinator.prepareCleanup(widget.providerId);
        if (!mounted) return;
        if (plan.remove.isEmpty) {
          setState(
            () => deletionStatus = context.l10n.cloudBackupNothingToClean,
          );
          return;
        }
      }
      if (!mounted) return;
      final message = entry != null
          ? '${entry.objectName}\n${_entryTitle(entry)}\n${context.l10n.cloudBackupDeleteWarning}'
          : '${context.l10n.cloudBackupRetain}\n${plan!.keep.map((e) => '${_entryTitle(e)}\n${e.objectName}').join('\n\n')}\n\n'
                '${context.l10n.cloudBackupCleanupCount(plan.remove.length, cloudBackupFileSize(context.l10n, plan.totalBytes))}';
      setState(() {
        deleting = false;
        confirming = true;
      });
      final ok = await confirmDialog(
        context,
        title: entry == null
            ? context.l10n.cloudBackupCleanup
            : context.l10n.commonDelete,
        message: '$message\n\n${context.l10n.s3DeleteMarkerNote}',
        confirmLabel: context.l10n.commonDelete,
        destructive: true,
      );
      if (!ok) return;
      if (mounted) {
        setState(() {
          confirming = false;
          deleting = true;
        });
      }
      final result = entry != null
          ? await coordinator.deleteOne(entry)
          : await coordinator.executeCleanup(plan!);
      if (!mounted) return;
      setState(() {
        deletionStatus = context.l10n.cloudBackupDeletionResult(
          result.removed.length,
          result.failed.length,
          result.unknown.length,
        );
        if (result.targetChanged) {
          error = context.l10n.cloudBackupTargetChanged;
        } else if (!result.complete) {
          error = {
            if (result.unknown.isNotEmpty)
              context.l10n.cloudBackupDeleteUnknown,
            for (final problem in result.failed.values)
              describeCloudBackupError(context.l10n, problem),
          }.join('\n');
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = describeCloudBackupError(context.l10n, e));
      }
    } finally {
      if (mounted) {
        setState(() {
          deleting = false;
          confirming = false;
        });
        await _load(reset: true, preserveError: true);
      }
    }
  }

  /// The timestamp a backup is known by, or the raw object name when the
  /// listing carried no usable date. Nothing here changes which object is
  /// downloaded: the entry is passed through untouched.
  String _entryTitle(CloudBackupEntry entry) {
    final DateTime? when = entry.createdAt ?? entry.lastModified;
    return when == null ? entry.objectName : formatDateTime(when);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: ClassicAppBar(
        title: Text(l10n.cloudBackupBrowse),
        actions: <Widget>[
          IconButton(
            onPressed: loading || deleting || confirming
                ? null
                : () => _load(reset: true),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.commonRefresh,
          ),
        ],
      ),
      body: ContentColumn(
        child: ListView(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppDimens.gutter),
              child: Text(l10n.cloudBackupSelectFile),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.gutter),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed:
                      loading || deleting || confirming || downloading != null
                      ? null
                      : () => _delete(),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(l10n.cloudBackupCleanup),
                ),
              ),
            ),
            if (deletionStatus != null)
              Padding(
                padding: const EdgeInsets.all(AppDimens.gutter),
                child: Text(deletionStatus!),
              ),
            if (loading || deleting) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.gutter,
                ),
                child: ErrorBanner(
                  message: error!,
                  onRetry: () => _load(reset: true),
                ),
              ),
            if (!loading && error == null && entries.isEmpty)
              ListTile(title: Text(l10n.cloudBackupNoFiles)),
            for (final CloudBackupEntry entry in entries)
              ListTile(
                // The object name is a timestamp plus a UUID; as a title it was
                // both unreadable and unbounded. The readable time leads, the
                // size and provider follow, and the exact name stays available
                // as a tooltip.
                title: Tooltip(
                  message: entry.objectName,
                  child: Text(
                    _entryTitle(entry),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                subtitle: Text(
                  '${cloudBackupFileSize(l10n, entry.byteLength)} · '
                  '${entry.providerId == 's3' ? 'S3' : 'WebDAV'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                trailing: downloading == entry.objectName
                    ? const SizedBox(
                        width: AppDimens.iconSize,
                        height: AppDimens.iconSize,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.download),
                            tooltip: l10n.cloudBackupDownload,
                            onPressed:
                                loading ||
                                    deleting ||
                                    confirming ||
                                    downloading != null
                                ? null
                                : () => _download(entry),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l10n.commonDelete,
                            color: theme.colorScheme.error,
                            onPressed:
                                loading ||
                                    deleting ||
                                    confirming ||
                                    downloading != null
                                ? null
                                : () => _delete(entry: entry),
                          ),
                        ],
                      ),
                onTap: loading || deleting || confirming || downloading != null
                    ? null
                    : () => _download(entry),
              ),
            if (next != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextButton(
                  onPressed: loading || deleting || confirming ? null : _load,
                  child: Text(l10n.commonContinue),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DownloadedBackupDialog extends ConsumerStatefulWidget {
  const _DownloadedBackupDialog({required this.download});
  final CloudBackupDownload download;
  @override
  ConsumerState<_DownloadedBackupDialog> createState() =>
      _DownloadedBackupDialogState();
}

class _DownloadedBackupDialogState
    extends ConsumerState<_DownloadedBackupDialog> {
  bool busy = false;
  String? error;

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await BackupFiles(ref.read(backupServiceProvider)).exportWithJson(
        utf8.decode(widget.download.bytes),
        fileName: widget.download.entry.objectName,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = describeCloudBackupError(context.l10n, e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore({required bool snapshot}) async {
    final manager = ref.read(backupManagerProvider);
    final sync = ref.read(syncCoordinatorProvider);
    if (sync.isRunning) {
      setState(() => error = context.l10n.cloudBackupSyncRunning);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          snapshot
              ? context.l10n.cloudBackupSnapshotRestore
              : context.l10n.cloudBackupMergeRestore,
        ),
        content: Text(
          snapshot
              ? context.l10n.restoreSnapshotConfirm(
                  '${context.l10n.cloudBackupWords}: '
                  '${(widget.download.dataset['words'] as List?)?.length ?? 0}, '
                  '${context.l10n.cloudBackupBooks}: '
                  '${(widget.download.dataset['wordBooks'] as List?)?.length ?? 0}',
                  cloudBackupTime(
                    context.l10n,
                    widget.download.dataset['exportedAt'],
                  ),
                )
              : context.l10n.mergeRestoreConfirm(
                  '${context.l10n.cloudBackupWords}: '
                  '${(widget.download.dataset['words'] as List?)?.length ?? 0}, '
                  '${context.l10n.cloudBackupBooks}: '
                  '${(widget.download.dataset['wordBooks'] as List?)?.length ?? 0}',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonRestore),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    File? file;
    try {
      final dir = await BackupPaths.appDirectory();
      file = File(
        '${dir.path}/.cloud-download-${DateTime.now().microsecondsSinceEpoch}.json',
      );
      await file.writeAsBytes(widget.download.bytes, flush: true);
      if (snapshot) {
        await manager.restoreSnapshot(file);
      } else {
        await manager.restoreMerge(file);
      }
      if (mounted) {
        await showMissingDictionaryNotice(context, ref);
      }
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(statisticsProvider);
      ref.invalidate(todayProgressProvider);
      ref.invalidate(pausedSessionProvider);
      if (snapshot && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.restoreNextStepTitle),
            content: Text(context.l10n.restoreNextStepBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.keepLocalState),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = describeCloudBackupError(context.l10n, e));
      }
    } finally {
      if (file != null) {
        try {
          await file.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => busy = false);
    }
  }

  String _downloadedTitle(AppLocalizations l10n) {
    final CloudBackupEntry entry = widget.download.entry;
    final DateTime? when = entry.createdAt ?? entry.lastModified;
    return when == null ? entry.objectName : formatDateTime(when);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Map<String, Object?> d = widget.download.dataset;
    return AlertDialog(
      title: Text(l10n.cloudBackupDownloaded),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      content: SizedBox(
        width: 390,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_downloadedTitle(l10n), style: theme.textTheme.titleMedium),
              AppSpacing.h4,
              Text(
                '${cloudBackupFileSize(l10n, widget.download.entry.byteLength)} · '
                '${widget.download.entry.providerId == 's3' ? 'S3' : 'WebDAV'}',
                style: theme.textTheme.bodySmall,
              ),
              AppSpacing.h4,
              Tooltip(
                message: widget.download.entry.objectName,
                child: Text(
                  widget.download.entry.objectName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              AppSpacing.h12,
              const Divider(height: 1),
              AppSpacing.h12,
              Text(
                l10n.backupInfoSummary(
                  (d['words'] as List?)?.length ?? 0,
                  (d['wordBooks'] as List?)?.length ?? 0,
                  (d['entries'] as List?)?.length ?? 0,
                  (d['reviewEvents'] as List?)?.length ?? 0,
                ),
                style: theme.textTheme.bodyMedium,
              ),
              AppSpacing.h4,
              Text(
                l10n.schemaVersionLine((d['schemaVersion'] as int?) ?? 0),
                style: theme.textTheme.bodySmall,
              ),
              AppSpacing.h4,
              Text(
                l10n.createdAtLine(cloudBackupTime(l10n, d['exportedAt'])),
                style: theme.textTheme.bodySmall,
              ),
              AppSpacing.h12,
              Text(
                l10n.cloudBackupRestoreHint,
                style: theme.textTheme.bodySmall,
              ),
              if (busy) ...<Widget>[
                AppSpacing.h12,
                const LinearProgressIndicator(),
              ],
              if (error != null) ...<Widget>[
                AppSpacing.h12,
                ErrorBanner(message: error!),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: busy ? null : _save,
                icon: const Icon(Icons.save_alt, size: AppDimens.iconSizeSmall),
                label: Text(
                  l10n.cloudBackupSaveFile,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.h8,
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.cloudBackupRestoreSection,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: <Widget>[
                  TextButton(
                    onPressed: busy ? null : () => _restore(snapshot: false),
                    child: Text(l10n.cloudBackupMergeRestore),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => _restore(snapshot: true),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: Text(l10n.cloudBackupSnapshotRestore),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: Text(l10n.commonClose),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
