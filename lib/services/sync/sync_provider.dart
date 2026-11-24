/// Transport-agnostic sync contract.
///
/// Phase 1 only ships [LocalFileSyncProvider] fully working; the GitHub and
/// WebDAV implementations are declared here so the UI and the data protocol are
/// already shaped correctly, but they report `isImplemented == false` and are
/// never presented as usable in the app.
library;

/// Result of a connectivity check.
class SyncTestResult {
  const SyncTestResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}

/// A dataset downloaded from a provider.
class SyncPayload {
  const SyncPayload({required this.dataset, this.revision, this.updatedAt});

  final Map<String, Object?> dataset;

  /// Opaque version token: GitHub blob SHA, WebDAV ETag, file mtime.
  final String? revision;
  final DateTime? updatedAt;
}

class SyncUploadResult {
  const SyncUploadResult({
    required this.ok,
    required this.message,
    this.revision,
  });

  final bool ok;
  final String message;
  final String? revision;
}

class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class SyncProvider {
  String get id;

  String get label;

  /// False for providers that are planned but not implemented yet. The UI must
  /// render those as "未实现" and disable every action.
  bool get isImplemented;

  String get description;

  Future<SyncTestResult> testConnection();

  /// Returns the remote dataset, or null when the remote has no data yet.
  Future<SyncPayload?> download();

  /// Uploads [dataset]. [ifRevision] is the revision we based our merge on:
  /// providers with optimistic concurrency must reject the upload when the
  /// remote changed in the meantime (`SyncException`).
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  });
}
