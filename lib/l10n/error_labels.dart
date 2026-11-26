import '../core/errors/app_error.dart';
import '../services/cloud_backup/cloud_backup_provider.dart';
import 'l10n.dart';

/// Localised text for an [AppErrorCode].
///
/// The only place where an error code becomes a sentence. Sessions and services
/// keep the code; pages call this with the current language.
String describeAppError(AppLocalizations l10n, AppErrorCode code) =>
    switch (code) {
      AppErrorCode.generic => l10n.errorGeneric,
      AppErrorCode.loadFailed => l10n.studyLoadFailed,
      AppErrorCode.saveFailed => l10n.studySaveFailed,
      AppErrorCode.undoFailed => l10n.undoFailed,
      AppErrorCode.skipFailed => l10n.skipFailed,
      AppErrorCode.wordRemoved => l10n.wordRemovedSkipped,
      AppErrorCode.stateChanged => l10n.stateChangedSkipped,
      AppErrorCode.contentUpdated => l10n.contentUpdatedReview,
      AppErrorCode.sprintChanged => l10n.sprintChanged,
      AppErrorCode.reviewLimitReached => l10n.reviewLimitReached,
      AppErrorCode.practiceLoadFailed => l10n.practiceLoadFailed,
      AppErrorCode.practiceSaveFailed => l10n.practiceSaveFailed,
      AppErrorCode.practiceWordDeleted => l10n.practiceWordDeleted,
      AppErrorCode.practiceContentUpdated => l10n.practiceContentUpdated,
      AppErrorCode.practiceWordUnlinked => l10n.practiceWordUnlinked,
      AppErrorCode.networkUnavailable => l10n.errorNetwork,
      AppErrorCode.timeout => l10n.errorTimeout,
      AppErrorCode.authenticationFailed => l10n.errorAuthFailed,
      AppErrorCode.permissionDenied => l10n.errorPermission,
      AppErrorCode.remoteFileMissing => l10n.errorRemoteFileMissing,
      AppErrorCode.invalidBackup => l10n.errorInvalidBackup,
      AppErrorCode.sprintVersionUnsupported => l10n.sprintVersionUnsupported,
      AppErrorCode.sprintInvalidSwitch => l10n.sprintInvalidSwitch,
      AppErrorCode.sprintInvalidDate => l10n.sprintInvalidDate,
      AppErrorCode.sprintInvalidBook => l10n.sprintInvalidBook,
      AppErrorCode.sprintInvalidRoundSize => l10n.sprintInvalidRoundSize,
      AppErrorCode.sprintIncomplete => l10n.sprintIncomplete,
      AppErrorCode.protectiveBackupFailed => l10n.protectiveBackupFailed,
      AppErrorCode.wordListDeleted => l10n.listDeleted,
      AppErrorCode.wordNotFound => l10n.wordNotFound,
      AppErrorCode.wordEmpty => l10n.wordEmpty,
      AppErrorCode.wordTooLong => l10n.wordTooLong,
    };

/// User-facing text for a cloud-backup failure.
///
/// The provider layer raises `CloudBackupException` with an English diagnostic
/// message (`'Backup object already exists'`, `'Invalid S3 listing'`…). Those
/// strings belong in the log, not on a dialog: they are untranslated, they
/// sometimes carry a request detail, and a user cannot act on them. This maps
/// the machine-readable part — the HTTP status, plus the few message markers
/// the services use — onto the same sentences the rest of the app shows.
String describeCloudBackupError(AppLocalizations l10n, Object error) {
  if (error is AppError) return describeAppError(l10n, error.code);
  final String detail = error is CloudBackupException
      ? error.message.toLowerCase()
      : error.toString().toLowerCase();
  final int? status = error is CloudBackupException ? error.status : null;
  if (status == 401) return l10n.errorAuthFailed;
  if (status == 403) return l10n.errorPermission;
  if (status == 404) return l10n.errorRemoteFileMissing;
  if (detail.contains('timed out') || detail.contains('timeout')) {
    return l10n.errorTimeout;
  }
  if (detail.contains('connection') || detail.contains('socket')) {
    return l10n.errorNetwork;
  }
  if (detail.contains('target changed')) return l10n.cloudBackupTargetChanged;
  if (detail.contains('incomplete') ||
      detail.contains('pagination') ||
      detail.contains('list changed')) {
    return l10n.cloudBackupListUncertain;
  }
  if (detail.contains('outcome unknown')) return l10n.cloudBackupDeleteUnknown;
  if (detail.contains('busy')) return l10n.cloudBackupBusy;
  if (detail.contains('not configured')) return l10n.cloudBackupNotConfigured;
  if (detail.contains('exceeds 100 mb')) return l10n.cloudBackupTooLarge;
  if (detail.contains('checksum') ||
      detail.contains('invalid backup') ||
      detail.contains('outcome unknown')) {
    return l10n.errorInvalidBackup;
  }
  return l10n.errorGeneric;
}
