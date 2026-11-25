/// Structured, redacted request tracing for WebDAV.
///
/// The old `_raise()` collapsed every 403 into "请检查目录权限", which told the
/// user nothing and told us less: the same status is returned by PROPFIND on a
/// base collection, MKCOL on `/dav/`, and PUT inside a read-only folder.
///
/// Every request now records *which stage* produced it, so a failure can be
/// attributed without guessing (`stage=directory_creation method=MKCOL
/// path=/dav/ status=403`).
library;

import 'package:uuid/uuid.dart';

import '../diagnostics_service.dart';

/// Ordered pipeline stages. The wire names are what appears in a log file and
/// what the documentation and tests refer to.
enum WebDavStage {
  baseCollectionProbe('base_collection_probe'),
  targetDirectoryProbe('target_directory_probe'),
  directoryCreation('directory_creation'),
  directoryListing('directory_listing'),
  dataFileProbe('data_file_probe'),
  basicWriteProbe('basic_write_probe'),
  conditionalCreateProbe('conditional_create_probe'),
  conditionalStaleUpdateProbe('conditional_stale_update_probe'),
  conditionalExistingCreateProbe('conditional_existing_create_probe'),
  conditionalValidUpdateProbe('conditional_valid_update_probe'),
  probeCleanup('probe_cleanup'),
  datasetDownload('dataset_download'),
  datasetUpload('dataset_upload'),
  datasetVerification('dataset_verification');

  const WebDavStage(this.wire);

  final String wire;
}

/// One HTTP round trip, already stripped of anything secret.
class WebDavTraceEntry {
  const WebDavTraceEntry({
    required this.requestId,
    this.roundId,
    required this.stage,
    required this.method,
    required this.host,
    required this.path,
    this.hasQuery = false,
    this.hasFragment = false,
    this.depth,
    this.propfindProfile,
    this.compatibilityMode,
    this.serverErrorCode,
    required this.status,
    required this.durationMs,
    this.redirects = 0,
    this.conditional,
    this.etagSource,
    this.selfMatch,
    this.getetagPropstat,
    this.conditionOutcome,
    this.etagChanged,
    this.etagKind,
    this.responseContentType,
    this.result = 'ok',
  });

  final String requestId;
  final String? roundId;
  final WebDavStage stage;
  final String method;

  /// Host only — never the user info, never a query string.
  final String host;
  final String path;
  final bool hasQuery;
  final bool hasFragment;
  final String? depth;
  final String? propfindProfile;
  final String? compatibilityMode;
  final String? serverErrorCode;
  final int? status;
  final int durationMs;
  final int redirects;

  /// `If-Match` / `If-None-Match` / null. The *value* is never recorded beyond
  /// the fact that a stale-test tag was synthetic.
  final String? conditional;
  final String? etagSource;
  final String? selfMatch;
  final String? getetagPropstat;
  final String? conditionOutcome;
  final bool? etagChanged;
  final String? etagKind;
  final String? responseContentType;
  final String result;

  String format() {
    final StringBuffer out = StringBuffer('[WebDAV] ');
    out
      ..write('request=${requestId.isEmpty ? '-' : requestId} ')
      ..write('stage=${stage.wire} ')
      ..write('method=$method ')
      ..write('host=$host ')
      ..write('path=$path ');
    if (roundId != null) out.write('round=$roundId ');
    if (hasQuery) out.write('has_query=true ');
    if (hasFragment) out.write('has_fragment=true ');
    if (depth != null) out.write('depth=$depth ');
    if (propfindProfile != null) out.write('profile=$propfindProfile ');
    if (compatibilityMode != null) {
      out.write('compatibility=$compatibilityMode ');
    }
    if (serverErrorCode != null) {
      out.write(
        'server_error=${serverErrorCode!.replaceAll(RegExp(r'[\\r\\n\\s]+'), ' ')} ',
      );
    }
    if (status != null) out.write('status=$status ');
    if (redirects > 0) out.write('redirects=$redirects ');
    if (conditional != null) out.write('conditional=$conditional ');
    if (etagSource != null) out.write('etag_source=$etagSource ');
    if (selfMatch != null) out.write('self_match=$selfMatch ');
    if (getetagPropstat != null) {
      out.write('getetag_propstat=$getetagPropstat ');
    }
    if (conditionOutcome != null) {
      out.write('condition_outcome=$conditionOutcome ');
    }
    if (etagChanged != null) out.write('etag_changed=$etagChanged ');
    if (etagKind != null) out.write('etag=$etagKind ');
    if (responseContentType != null) {
      out.write('content_type=$responseContentType ');
    }
    out.write('duration_ms=$durationMs ');
    out.write('result=$result');
    return out.toString();
  }
}

/// Collects entries for one provider instance and mirrors them to the app
/// diagnostics log (which is off by default and redacts everything).
class WebDavTrace {
  WebDavTrace({this.mirror = true, this.capacity = 64});

  /// When false nothing leaves this object — used by unit tests that assert on
  /// [entries] only.
  final bool mirror;
  final int capacity;
  final String roundId = const Uuid().v4().substring(0, 12);

  final List<WebDavTraceEntry> entries = <WebDavTraceEntry>[];
  int _seq = 0;

  String nextRequestId() => 'r${++_seq}';

  void add(WebDavTraceEntry entry) {
    final String line = entry.format();
    final bool failed =
        entry.result != 'ok' || (entry.status != null && entry.status! >= 500);
    // Buffer first (bounded), then mirror: a diagnostic failure must never
    // break a sync.
    if (entries.length >= capacity) entries.removeAt(0);
    entries.add(entry);
    if (mirror) {
      try {
        DiagnosticsService.instance.log('webdav', line, error: failed);
      } catch (_) {
        // DiagnosticsService is best-effort by contract.
      }
    }
  }

  /// Replaces the probe nonce with a stable token so an exported report stays
  /// readable without echoing a file name that only exists for one second.
  static String maskNonce(String path) => path.replaceAllMapped(
    RegExp(r'materialword-probe-[0-9a-fA-F-]{8,}'),
    (Match _) => 'materialword-probe-<nonce>',
  );

  /// The last `count` lines, for attaching to an error message or a report.
  List<String> tail({int count = 8}) => entries
      .skip(entries.length > count ? entries.length - count : 0)
      .map((WebDavTraceEntry e) => e.format())
      .toList(growable: false);
}
