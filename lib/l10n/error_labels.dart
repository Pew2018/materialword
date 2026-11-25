import '../core/errors/app_error.dart';
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
