/// Stable, language-independent error codes.
///
/// Business logic (sessions, services, pages) may branch on these values.
/// Localised text is resolved only at the UI boundary — see
/// `lib/l10n/error_labels.dart` — so changing a message, or switching the app
/// language, can never change what the app *does*.
enum AppErrorCode {
  generic,
  loadFailed,
  saveFailed,
  undoFailed,
  skipFailed,
  wordRemoved,
  stateChanged,
  contentUpdated,
  sprintChanged,
  reviewLimitReached,
  practiceLoadFailed,
  practiceSaveFailed,
  practiceWordDeleted,
  practiceContentUpdated,
  practiceWordUnlinked,
  networkUnavailable,
  timeout,
  authenticationFailed,
  permissionDenied,
  remoteFileMissing,
  invalidBackup,
  sprintVersionUnsupported,
  sprintInvalidSwitch,
  sprintInvalidDate,
  sprintInvalidBook,
  sprintInvalidRoundSize,
  sprintIncomplete,
  protectiveBackupFailed,
  wordListDeleted,
  wordNotFound,
  wordEmpty,
  wordTooLong,
}

/// An error carrying a code plus a technical detail.
///
/// [detail] is for diagnostics only and is never rendered in a normal page: it
/// may contain a path, a stack trace or a raw server response.
class AppError implements Exception {
  const AppError(this.code, {this.detail});

  final AppErrorCode code;
  final String? detail;

  @override
  String toString() =>
      'AppError(${code.name}${detail == null ? '' : ': $detail'})';
}
