import 'dart:convert';

import '../services/backup_service.dart';
import '../services/sync/sync_coordinator.dart';
import '../services/sync/sync_provider.dart';
import 'backup_labels.dart';
import 'l10n.dart';

/// Sync status, stage and result as sentences.
///
/// The sync layer reports typed values ([SyncStage], [SyncCapabilityStatus],
/// [SyncOutcome]); only this file turns them into text, so a status can never be
/// stored or compared as a translated string.

String syncStageLabel(AppLocalizations l10n, SyncStage stage) =>
    switch (stage) {
      SyncStage.idle => l10n.syncStageIdle,
      SyncStage.validating => l10n.syncStageValidating,
      SyncStage.downloading => l10n.syncStageDownloading,
      SyncStage.merging => l10n.syncStageMerging,
      SyncStage.rebuilding => l10n.syncStageRebuilding,
      SyncStage.uploading => l10n.syncStageUploading,
      SyncStage.verifying => l10n.syncStageVerifying,
      SyncStage.done => l10n.syncStageDone,
      SyncStage.mergedNotUploaded => l10n.syncStageMergedNotUploaded,
      SyncStage.waitingBackoff => l10n.syncStageWaitingBackoff,
      SyncStage.authFailed => l10n.syncStageAuthFailed,
      SyncStage.remoteMissing => l10n.syncStageRemoteMissing,
      SyncStage.remoteCorrupt => l10n.syncStageRemoteCorrupt,
      SyncStage.configChanged => l10n.syncStageConfigChanged,
      SyncStage.pausedAfterRestore => l10n.syncStagePausedAfterRestore,
      SyncStage.failed => l10n.syncStageFailed,
    };

/// The one-line verdict for a connection test.
String syncCapabilityLabel(
  AppLocalizations l10n,
  SyncCapabilityStatus status,
) => switch (status) {
  SyncCapabilityStatus.unknown => l10n.syncCapabilityUnknown,
  SyncCapabilityStatus.connectionFailed => l10n.syncCapabilityConnectionFailed,
  SyncCapabilityStatus.authenticationFailed => l10n.syncCapabilityAuthFailed,
  SyncCapabilityStatus.requestRejected => l10n.syncCapabilityRequestRejected,
  SyncCapabilityStatus.directoryUnavailable => l10n.syncCapabilityNoFolder,
  SyncCapabilityStatus.readOnly => l10n.syncCapabilityReadOnly,
  SyncCapabilityStatus.basicReadWrite => l10n.syncCapabilityUnsafe,
  SyncCapabilityStatus.safeConditionalWrite => l10n.syncCapabilitySafe,
  SyncCapabilityStatus.safeSnapshotWrite => l10n.syncCapabilitySnapshot,
};

String syncCapabilitySummary(
  AppLocalizations l10n,
  SyncCapability capability,
) => syncCapabilityLabel(l10n, capability.status);

/// What a finished (or partially finished) run achieved.
String describeSyncReport(AppLocalizations l10n, SyncReport report) {
  final MergeReport? merge = report.merge;
  return switch (report.outcome) {
    SyncOutcome.synced =>
      merge == null || !merge.hasChanges
          ? l10n.syncResultSynced
          : l10n.syncResultSyncedWith(mergeSummary(l10n, merge)),
    SyncOutcome.unchanged => l10n.syncResultUnchanged,
    SyncOutcome.remoteHasData => l10n.syncResultRemoteHasData,
    SyncOutcome.initialised => l10n.syncResultInitialised,
    SyncOutcome.partialUpload => l10n.syncResultPartial,
    SyncOutcome.failed => l10n.syncResultFailed,
    SyncOutcome.legacy =>
      report.message.isEmpty ? l10n.syncResultUnknown : report.message,
  };
}

/// The stored "last sync result".
///
/// New builds persist `{"outcome": "...", "addedEvents": 3, ...}`. A value
/// written by an older build is a Chinese sentence: it is shown verbatim rather
/// than dropped, so an upgrading user keeps their history (and a language
/// switch never breaks it).
String describeStoredSyncResult(AppLocalizations l10n, String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final String value = raw.trim();
  if (!value.startsWith('{')) return value;
  final Object? decoded;
  try {
    decoded = jsonDecode(value);
  } catch (_) {
    return value;
  }
  if (decoded is! Map<String, Object?>) return value;
  final String name = decoded['outcome'] as String? ?? '';
  final SyncOutcome outcome = SyncOutcome.values.firstWhere(
    (SyncOutcome value) => value.name == name,
    orElse: () => SyncOutcome.legacy,
  );
  if (outcome == SyncOutcome.legacy) return value;
  if (outcome != SyncOutcome.synced) {
    return switch (outcome) {
      SyncOutcome.unchanged => l10n.syncResultUnchanged,
      SyncOutcome.remoteHasData => l10n.syncResultRemoteHasData,
      SyncOutcome.initialised => l10n.syncResultInitialised,
      SyncOutcome.partialUpload => l10n.syncResultPartial,
      SyncOutcome.failed => l10n.syncResultFailed,
      _ => l10n.syncResultUnknown,
    };
  }
  final int added = (decoded['addedEvents'] as int?) ?? 0;
  final int newWords = (decoded['newWords'] as int?) ?? 0;
  final int updated = (decoded['updatedWords'] as int?) ?? 0;
  final int deleted = (decoded['deletedWords'] as int?) ?? 0;
  final int removed = (decoded['removedEntries'] as int?) ?? 0;
  if (added == 0 &&
      newWords == 0 &&
      updated == 0 &&
      deleted == 0 &&
      removed == 0) {
    return l10n.syncResultUnchanged;
  }
  final List<String> parts = <String>[
    if (added > 0) l10n.mergeSummaryEvents(added),
    if (newWords > 0) l10n.mergeSummaryNewWords(newWords),
    if (updated > 0) l10n.mergeSummaryUpdatedWords(updated),
    if (deleted > 0) l10n.mergeSummaryDeletedWords(deleted),
    if (removed > 0) l10n.mergeSummaryRemovedEntries(removed),
  ];
  return l10n.syncResultSyncedWith(parts.join(l10n.importOutcomeSeparator));
}

/// The headline of a connection test.
String describeSyncTestResult(AppLocalizations l10n, SyncTestResult result) {
  final SyncCapability? capability = result.capability;
  if (capability != null) return syncCapabilitySummary(l10n, capability);
  return result.ok ? l10n.syncTestOk : l10n.syncTestFailed;
}
