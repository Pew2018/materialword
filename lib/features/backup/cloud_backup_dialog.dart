import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/common.dart';
import '../../services/backup_files.dart';
import '../../services/cloud_backup/cloud_backup_coordinator.dart';
import '../../services/cloud_backup/cloud_backup_provider.dart';
import '../../services/cloud_backup/cloud_backup_repository.dart';
import '../sync/sync_settings_page.dart';

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

  Future<void> _last() async {
    final config = configs?.where((c) => c.providerId == selected).firstOrNull;
    final value = config == null
        ? null
        : await ref.read(cloudBackupRepositoryProvider).lastSuccess(config);
    if (mounted && config?.providerId == selected) {
      setState(() => last = value);
    }
  }

  Future<void> _upload() async {
    final id = selected;
    if (id == null) return;
    try {
      await ref.read(cloudBackupCoordinatorProvider).upload(id);
      await _last();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _configure() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const SyncSettingsPage()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(cloudBackupCoordinatorProvider);
    return AnimatedBuilder(
      animation: coordinator,
      builder: (context, _) {
        final running = coordinator.isRunning;
        final config = configs
            ?.where((c) => c.providerId == selected)
            .firstOrNull;
        final stage = coordinator.progress.stage;
        return AlertDialog(
          title: Text(context.l10n.cloudBackupManual),
          content: SizedBox(
            width: 390,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (configs == null)
                  const LinearProgressIndicator()
                else if (configs!.isEmpty) ...[
                  Text(context.l10n.cloudBackupNotConfigured),
                  const SizedBox(height: 8),
                  Text(context.l10n.cloudBackupIndependentHint),
                ] else ...[
                  Text(context.l10n.cloudBackupTarget),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    items: [
                      for (final c in configs!)
                        DropdownMenuItem(
                          value: c.providerId,
                          child: Text(
                            c.providerId == 's3'
                                ? 'S3 · ${c.bucket}'
                                : 'WebDAV · ${Uri.tryParse(c.endpoint)?.host ?? ''}',
                          ),
                        ),
                    ],
                    onChanged: running
                        ? null
                        : (value) async {
                            if (value == null) return;
                            setState(() {
                              selected = value;
                              last = null;
                              error = null;
                            });
                            await ref
                                .read(cloudBackupRepositoryProvider)
                                .setPreferred(value);
                            _last();
                          },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${context.l10n.cloudBackupLastSuccess}: '
                    '${last?['completedAt'] ?? context.l10n.cloudBackupNever}',
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.cloudBackupIndependentHint),
                  if (running) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    Text(switch (stage) {
                      CloudBackupStage.uploading =>
                        context.l10n.cloudBackupUploadProgress,
                      CloudBackupStage.verifying =>
                        context.l10n.cloudBackupVerifyProgress,
                      CloudBackupStage.downloading =>
                        context.l10n.cloudBackupDownloadProgress,
                      CloudBackupStage.listing =>
                        context.l10n.cloudBackupListing,
                      CloudBackupStage.validating =>
                        context.l10n.cloudBackupValidating,
                      _ => context.l10n.cloudBackupPreparing,
                    }),
                  ],
                  if (!running &&
                      stage == CloudBackupStage.completed &&
                      coordinator.lastUploadReceipt?.operationId ==
                          coordinator.progress.operationId &&
                      coordinator.lastUploadReceipt?.providerId == selected)
                    Text(context.l10n.cloudBackupSucceeded),
                ],
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonClose),
            ),
            TextButton(
              onPressed: running ? null : _configure,
              child: Text(context.l10n.cloudBackupConfigure),
            ),
            if (config != null) ...[
              TextButton(
                onPressed: running
                    ? null
                    : () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              CloudBackupBrowser(providerId: config.providerId),
                        ),
                      ),
                child: Text(context.l10n.cloudBackupDownload),
              ),
              FilledButton(
                onPressed: running ? null : _upload,
                child: Text(context.l10n.cloudBackupUpload),
              ),
            ],
          ],
        );
      },
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
  bool loading = false;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
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
        entries.sort(
          (a, b) => (b.createdAt ?? b.lastModified ?? DateTime(0)).compareTo(
            a.createdAt ?? a.lastModified ?? DateTime(0),
          ),
        );
        next = page.continuationToken;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _download(CloudBackupEntry entry) async {
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
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.cloudBackupBrowse),
      actions: [
        IconButton(
          onPressed: loading ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh),
          tooltip: context.l10n.commonRefresh,
        ),
      ],
    ),
    body: ContentColumn(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.cloudBackupSelectFile),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            ListTile(
              title: Text(error!),
              trailing: TextButton(
                onPressed: () => _load(),
                child: Text(context.l10n.commonRetry),
              ),
            ),
          if (!loading && error == null && entries.isEmpty)
            ListTile(title: Text(context.l10n.cloudBackupNoFiles)),
          for (final entry in entries)
            ListTile(
              title: Text(entry.objectName),
              subtitle: Text(
                '${entry.createdAt?.toLocal() ?? entry.lastModified?.toLocal() ?? ''}'
                ' · ${entry.byteLength ?? '?'} B',
              ),
              trailing: const Icon(Icons.download),
              onTap: loading ? null : () => _download(entry),
            ),
          if (next != null)
            TextButton(
              onPressed: loading ? null : _load,
              child: Text(context.l10n.commonContinue),
            ),
        ],
      ),
    ),
  );
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
      if (mounted) setState(() => error = e.toString());
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
                  '${widget.download.dataset['exportedAt'] ?? context.l10n.createdUnknown}',
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
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (file != null) {
        try {
          await file.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.download.dataset;
    return AlertDialog(
      title: Text(context.l10n.cloudBackupDownloaded),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.download.entry.objectName),
          Text(
            context.l10n.backupInfoSummary(
              (d['words'] as List?)?.length ?? 0,
              (d['wordBooks'] as List?)?.length ?? 0,
              (d['entries'] as List?)?.length ?? 0,
              (d['reviewEvents'] as List?)?.length ?? 0,
            ),
          ),
          Text(
            context.l10n.schemaVersionLine((d['schemaVersion'] as int?) ?? 0),
          ),
          Text(
            context.l10n.createdAtLine(
              '${d['exportedAt'] ?? context.l10n.createdUnknown}',
            ),
          ),
          if (error != null) Text(error!),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(context.l10n.commonClose),
        ),
        TextButton(
          onPressed: busy ? null : _save,
          child: Text(context.l10n.cloudBackupSaveFile),
        ),
        TextButton(
          onPressed: busy ? null : () => _restore(snapshot: false),
          child: Text(context.l10n.cloudBackupMergeRestore),
        ),
        TextButton(
          onPressed: busy ? null : () => _restore(snapshot: true),
          child: Text(context.l10n.cloudBackupSnapshotRestore),
        ),
      ],
    );
  }
}
