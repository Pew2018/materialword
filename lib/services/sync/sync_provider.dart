/// Transport-agnostic sync contract.
///
/// All providers exchange the same versioned JSON document produced by
/// `BackupService.buildDataset` and merged by `BackupService.mergeDataset`, so
/// GitHub, WebDAV and a local file cannot drift into three different protocols.
library;

/// Result of a connectivity check. [details] carries non-fatal findings such as
/// "this repository is public" or "the server returns no ETag".
class SyncTestResult {
  const SyncTestResult({
    required this.ok,
    required this.message,
    this.details = const <String>[],
  });

  final bool ok;
  final String message;
  final List<String> details;

  /// Remote is reachable and usable for *automatic* bidirectional sync
  /// (i.e. conditional writes are supported).
  bool get supportsConditionalWrites =>
      details.every((String d) => !d.startsWith('NO_CONDITIONAL_WRITE'));
}

/// A dataset downloaded from a provider.
class SyncPayload {
  const SyncPayload({
    required this.dataset,
    this.revision,
    this.updatedAt,
    this.contentHash,
    this.rawLength,
  });

  final Map<String, Object?> dataset;

  /// Opaque version token: GitHub blob SHA, WebDAV ETag, file content hash.
  final String? revision;
  final DateTime? updatedAt;
  final String? contentHash;
  final int? rawLength;
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
  const SyncException(this.message, {this.retryable = false});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

/// The remote changed between our download and our upload.
class SyncConflictException extends SyncException {
  const SyncConflictException([super.message = '远程数据已被其他设备修改'])
    : super(retryable: true);
}

/// The remote document itself is unusable (corrupt, wrong kind, too new).
class SyncDataException extends SyncException {
  const SyncDataException(super.message, {this.remoteVersion});

  final int? remoteVersion;
}

abstract class SyncProvider {
  String get id;

  String get label;

  /// False for providers that are declared but not wired to a transport.
  bool get isImplemented;

  String get description;

  /// True when any operation needs the network (used to keep the app usable
  /// offline: start-up sync is skipped instead of blocking).
  bool get requiresNetwork;

  /// True when [upload] rejects a stale `ifRevision`. Providers that cannot
  /// guarantee this must not be offered as safe automatic sync.
  bool get supportsConditionalWrites;

  Future<SyncTestResult> testConnection();

  /// Returns the remote dataset, or null when the remote has no data yet.
  Future<SyncPayload?> download();

  /// Uploads [dataset]. [ifRevision] is the revision we based our merge on:
  /// providers with optimistic concurrency must reject the upload when the
  /// remote changed in the meantime (`SyncConflictException`).
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  });
}

/// Helper for tests and for the "not implemented" placeholders.
class UnimplementedSyncProvider implements SyncProvider {
  const UnimplementedSyncProvider({
    required this.id,
    required this.label,
    required this.description,
  });

  @override
  final String id;

  @override
  final String label;

  @override
  final String description;

  @override
  bool get isImplemented => false;

  @override
  bool get requiresNetwork => false;

  @override
  bool get supportsConditionalWrites => false;

  Never _fail() => throw SyncException('$label 未配置：请先在「数据同步」页面填写连接信息。');

  @override
  Future<SyncPayload?> download() async => _fail();

  @override
  Future<SyncTestResult> testConnection() async => _fail();

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async => _fail();
}
