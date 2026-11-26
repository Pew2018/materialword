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
    this.capability,
  });

  final bool ok;
  final String message;
  final List<String> details;

  /// Structured capability report, when the provider produces one.
  ///
  /// A `SyncTestResult` with `ok == true` used to mean "safe to sync", which
  /// was wrong: a 0-byte probe failure still returned `ok`. [capability] is the
  /// only thing automatic sync may rely on.
  final SyncCapability? capability;

  /// Remote is reachable and usable for *automatic* bidirectional sync
  /// (i.e. conditional writes are supported).
  ///
  /// For providers without a [capability] report this keeps the historical
  /// detail-string heuristic, but now additionally requires [ok] — a failed
  /// test can never count as "supports conditional writes".
  bool get supportsConditionalWrites {
    final SyncCapability? cap = capability;
    if (cap != null) return ok && cap.safeBidirectionalSync;
    return ok &&
        details.every((String d) => !d.startsWith('NO_CONDITIONAL_WRITE'));
  }
}

/// Everything a sync target can be proven to do, kept apart on purpose.
///
/// "The connection works" and "this server can protect two devices writing at
/// the same time" are different statements; collapsing them is what produced a
/// green check next to "服务器不支持安全双向同步".
enum SyncCapabilityStatus {
  /// Nothing has been proven yet.
  unknown,

  /// TCP/TLS/DNS failed.
  connectionFailed,

  /// The server answered, but rejected the credentials.
  authenticationFailed,

  /// The server rejected the WebDAV request format; authentication is unknown.
  requestRejected,

  /// Authenticated, but the configured collection cannot be reached/created.
  directoryUnavailable,

  /// Proven: files can be read, but not written.
  readOnly,

  /// Proven: plain PUT/GET/DELETE work, conditional requests do not.
  basicReadWrite,

  /// Proven: strong ETag + If-Match + If-None-Match all behave.
  safeConditionalWrite,

  /// Verified publication of immutable, separately named snapshots.
  safeSnapshotWrite,
}

class SyncCapability {
  const SyncCapability({
    required this.status,
    this.reachable = false,
    this.authenticated = false,
    this.directoryAccessible = false,
    this.canRead = false,
    this.canCreate = false,
    this.canUpdate = false,
    this.canDelete = false,
    this.supportsStrongEtag = false,
    this.supportsConditionalRead = false,
    this.supportsIfMatch = false,
    this.supportsIfNoneMatch = false,
    this.probeCleanedUp = true,
    this.baseCollectionProbed = false,
    this.directoryListingSupported = false,
    this.failureStage,
    this.failureMethod,
    this.failureStatus,
    this.detail,
  });

  final SyncCapabilityStatus status;
  final bool reachable;
  final bool authenticated;
  final bool directoryAccessible;
  final bool canRead;
  final bool canCreate;
  final bool canUpdate;
  final bool canDelete;
  final bool supportsStrongEtag;
  final bool supportsConditionalRead;
  final bool supportsIfMatch;
  final bool supportsIfNoneMatch;

  /// True when the provider removed every temporary resource it created.
  final bool probeCleanedUp;

  /// True when the configured base collection itself answered PROPFIND.
  final bool baseCollectionProbed;

  /// True when `PROPFIND Depth: 1` returned a parseable listing.
  final bool directoryListingSupported;

  /// Diagnostic pointers. [failureStage] uses the same wire names as the trace
  /// log (`directory_creation`, `basic_write_probe`, …).
  final String? failureStage;
  final String? failureMethod;
  final int? failureStatus;

  /// Human-readable, already redacted explanation of the failed check.
  final String? detail;

  /// The only property automatic bidirectional sync may depend on.
  bool get safeBidirectionalSync =>
      directoryAccessible &&
      canRead &&
      canCreate &&
      ((status == SyncCapabilityStatus.safeSnapshotWrite &&
              directoryListingSupported) ||
          (status == SyncCapabilityStatus.safeConditionalWrite &&
              canUpdate &&
              supportsStrongEtag &&
              supportsIfMatch &&
              supportsIfNoneMatch));

  /// Sync is possible at all (manual merge at minimum).
  bool get usable => directoryAccessible && canRead;

  // The user-facing verdict lives in `lib/l10n/sync_labels.dart`.

  SyncCapability copyWith({
    SyncCapabilityStatus? status,
    bool? canRead,
    bool? canCreate,
    bool? canUpdate,
    bool? canDelete,
    bool? supportsStrongEtag,
    bool? supportsConditionalRead,
    bool? supportsIfMatch,
    bool? supportsIfNoneMatch,
    bool? probeCleanedUp,
    String? failureStage,
    String? failureMethod,
    int? failureStatus,
    String? detail,
  }) => SyncCapability(
    status: status ?? this.status,
    reachable: reachable,
    authenticated: authenticated,
    directoryAccessible: directoryAccessible,
    canRead: canRead ?? this.canRead,
    canCreate: canCreate ?? this.canCreate,
    canUpdate: canUpdate ?? this.canUpdate,
    canDelete: canDelete ?? this.canDelete,
    supportsStrongEtag: supportsStrongEtag ?? this.supportsStrongEtag,
    supportsConditionalRead:
        supportsConditionalRead ?? this.supportsConditionalRead,
    supportsIfMatch: supportsIfMatch ?? this.supportsIfMatch,
    supportsIfNoneMatch: supportsIfNoneMatch ?? this.supportsIfNoneMatch,
    probeCleanedUp: probeCleanedUp ?? this.probeCleanedUp,
    baseCollectionProbed: baseCollectionProbed,
    directoryListingSupported: directoryListingSupported,
    failureStage: failureStage ?? this.failureStage,
    failureMethod: failureMethod ?? this.failureMethod,
    failureStatus: failureStatus ?? this.failureStatus,
    detail: detail ?? this.detail,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.name,
    'reachable': reachable,
    'authenticated': authenticated,
    'directoryAccessible': directoryAccessible,
    'canRead': canRead,
    'canCreate': canCreate,
    'canUpdate': canUpdate,
    'canDelete': canDelete,
    'supportsStrongEtag': supportsStrongEtag,
    'supportsConditionalRead': supportsConditionalRead,
    'supportsIfMatch': supportsIfMatch,
    'supportsIfNoneMatch': supportsIfNoneMatch,
    'probeCleanedUp': probeCleanedUp,
    'baseCollectionProbed': baseCollectionProbed,
    'directoryListingSupported': directoryListingSupported,
    'failureStage': failureStage,
    'failureMethod': failureMethod,
    'failureStatus': failureStatus,
    'detail': detail,
  };

  static SyncCapability? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? status = raw['status'];
    final SyncCapabilityStatus? parsed = status is String
        ? SyncCapabilityStatus.values
              .where((SyncCapabilityStatus s) => s.name == status)
              .firstOrNull
        : null;
    if (parsed == null) return null;
    bool flag(String key) => raw[key] == true;
    return SyncCapability(
      status: parsed,
      reachable: flag('reachable'),
      authenticated: flag('authenticated'),
      directoryAccessible: flag('directoryAccessible'),
      canRead: flag('canRead'),
      canCreate: flag('canCreate'),
      canUpdate: flag('canUpdate'),
      canDelete: flag('canDelete'),
      supportsStrongEtag: flag('supportsStrongEtag'),
      supportsConditionalRead: flag('supportsConditionalRead'),
      supportsIfMatch: flag('supportsIfMatch'),
      supportsIfNoneMatch: flag('supportsIfNoneMatch'),
      probeCleanedUp: raw['probeCleanedUp'] != false,
      baseCollectionProbed: flag('baseCollectionProbed'),
      directoryListingSupported: flag('directoryListingSupported'),
      failureStage: raw['failureStage'] as String?,
      failureMethod: raw['failureMethod'] as String?,
      failureStatus: raw['failureStatus'] as int?,
      detail: raw['detail'] as String?,
    );
  }
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

/// What the remote collection actually contains.
///
/// `SyncPayload?` could only say "there is a dataset" or "there is nothing",
/// and a 0-byte file was forced into the second bucket or blew up as a JSON
/// error. `null` must keep meaning **the document is definitely not there**:
/// treating an existing (but empty) file as missing is what makes a user's
/// hand-made file look like a brand-new remote.
enum RemoteDatasetState {
  /// No such document.
  missing,

  /// The document exists and has a revision, but no content (0 bytes).
  empty,

  /// Parsed and shaped like a dataset (validated later by the coordinator).
  valid,
}

class RemoteDataset {
  const RemoteDataset.missing()
    : state = RemoteDatasetState.missing,
      payload = null,
      revision = null,
      rawLength = 0;

  const RemoteDataset.empty({this.revision, this.rawLength = 0})
    : state = RemoteDatasetState.empty,
      payload = null;

  // Not const: the revision is derived from [payload]. Kept as a normal
  // constructor so callers do not have to repeat the token.
  RemoteDataset.valid(SyncPayload this.payload)
    : state = RemoteDatasetState.valid,
      revision = payload.revision,
      rawLength = payload.rawLength;

  final RemoteDatasetState state;
  final SyncPayload? payload;

  /// Version token of the document as it was read. For [RemoteDatasetState.empty]
  /// this is the ETag of the empty file, which the initialization write must
  /// send as `If-Match`.
  final String? revision;
  final int? rawLength;

  bool get isMissing => state == RemoteDatasetState.missing;
  bool get isEmpty => state == RemoteDatasetState.empty;
  bool get isValid => state == RemoteDatasetState.valid;
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

/// What a sync run actually achieved.
///
/// Stable and language-independent: the page localises it, and the last result
/// is persisted as this code (plus counts) instead of a translated sentence, so
/// switching the app language does not leave Chinese text in the history.
enum SyncOutcome {
  /// A full run finished: pulled, merged and pushed.
  synced,

  /// Nothing to upload: both sides already match.
  unchanged,

  /// The remote already contained everything this device has.
  remoteHasData,

  /// A previously empty remote file was initialised from this device.
  initialised,

  /// The local merge succeeded but the upload did not finish.
  partialUpload,

  /// The run failed.
  failed,

  /// Written by a build that stored a sentence; shown verbatim.
  legacy,
}

class SyncCapabilityException extends SyncException {
  SyncCapabilityException(this.capability)
    : super(
        'WebDAV capability ${capability.status.name}: ${capability.detail ?? ''}',
      );

  final SyncCapability capability;
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

/// The merge was applied locally but the upload/verification did not finish.
///
/// This exists so a partial run can never be reported as "nothing happened":
/// the local database *did* change, and the user must know the remote is behind.
class SyncPartialException extends SyncException {
  const SyncPartialException(
    super.message, {
    this.mergeSummary = '',
    this.localChanged = false,
    this.uploaded = false,
  }) : super(retryable: true);

  final String mergeSummary;
  final bool localChanged;
  final bool uploaded;
}

/// The remote dataset is missing although this target was synced before.
class SyncRemoteMissingException extends SyncException {
  const SyncRemoteMissingException([super.message = '远程数据文件已被删除，已停止自动同步']);
}

/// The remote document itself is unusable (corrupt, wrong kind, too new).
class SyncDataException extends SyncException {
  const SyncDataException(super.message, {this.remoteVersion});

  final int? remoteVersion;
}

/// The remote document exists but holds no data (0 bytes).
///
/// This is *not* "the remote is missing": the file is there, it has a revision,
/// and overwriting it needs an explicit user decision plus `If-Match` on that
/// revision. See `docs/phase6.2-webdav-compatibility.md` §空文件初始化.
class SyncEmptyRemoteException extends SyncException {
  const SyncEmptyRemoteException([
    super.message = '远程同步文件为空（0 字节）',
    this.previouslySynced = false,
  ]);

  /// True when this target already completed a sync, so an empty file means the
  /// remote data was truncated rather than never written. The UI must not offer
  /// "initialize" casually in that case.
  final bool previouslySynced;
}

enum RemoteProbeKind {
  /// The remote exists and its revision token was read.
  revision,

  /// The remote document is definitively **not there**.
  missing,

  /// This provider cannot answer without transferring the dataset, or it is not
  /// configured yet. Unknown is *not* the same as "missing".
  unsupported,
}

/// Result of a cheap "has the remote changed?" probe.
///
/// [SyncProvider.remoteRevision] returned `null` both for "no such file" and for
/// "I cannot tell", which made the foreground check treat a deleted remote as
/// "nothing changed" and stay silent forever. This type keeps the two apart.
class RemoteProbe {
  const RemoteProbe.revision(String this.revision)
    : kind = RemoteProbeKind.revision;

  const RemoteProbe.missing() : kind = RemoteProbeKind.missing, revision = null;

  const RemoteProbe.unsupported()
    : kind = RemoteProbeKind.unsupported,
      revision = null;

  final RemoteProbeKind kind;
  final String? revision;

  bool get isMissing => kind == RemoteProbeKind.missing;
  bool get isUnsupported => kind == RemoteProbeKind.unsupported;
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

  /// Cheap "has the remote changed?" probe used by the foreground check.
  ///
  /// Implementations must not transfer the dataset: a polling loop that
  /// re-downloads 40 MB every few minutes is not acceptable. Providers that
  /// cannot answer must return [RemoteProbe.unsupported], and providers that
  /// learn the document is gone must return [RemoteProbe.missing] so the caller
  /// can stop instead of silently assuming "no change".
  Future<RemoteProbe> probeRemote() async => const RemoteProbe.unsupported();

  /// Revision-only form of [probeRemote], kept for callers that do not care
  /// about the missing/unsupported distinction.
  Future<String?> remoteRevision() async => (await probeRemote()).revision;

  /// Returns the remote dataset, or null when the remote has no data yet.
  ///
  /// Implementations that can tell an empty document from a missing one should
  /// override [fetchRemote] instead; callers use that in preference.
  Future<SyncPayload?> download();

  /// Rich form of [download]: keeps "missing" (`null`), "exists but empty" and
  /// "has a dataset" apart.
  ///
  /// The default implementation preserves the old two-state behaviour for
  /// providers that have no empty file to worry about (GitHub, local file).
  Future<RemoteDataset> fetchRemote() async {
    final SyncPayload? payload = await download();
    return payload == null
        ? const RemoteDataset.missing()
        : RemoteDataset.valid(payload);
  }

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
  Future<RemoteProbe> probeRemote() async => const RemoteProbe.unsupported();

  @override
  Future<RemoteDataset> fetchRemote() async => _fail();

  @override
  Future<String?> remoteRevision() async => null;

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
