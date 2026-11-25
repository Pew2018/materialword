import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/database/tables.dart';
import '../core/repositories/settings_repository.dart';

/// One recorded diagnostic line.
class DiagnosticsEntry {
  DiagnosticsEntry({
    required this.at,
    required this.category,
    required this.message,
    required this.isError,
  });

  final DateTime at;
  final String category;
  final String message;
  final bool isError;

  String format() =>
      '${at.toIso8601String()} ${isError ? 'ERROR' : 'INFO '} [$category] $message';
}

/// Lightweight, opt-in diagnostics.
///
/// Rules that make this safe to ship:
///  * **off by default** — nothing but the last error message is kept until the
///    user switches it on in 设置 → 诊断;
///  * **bounded** — at most [maxEntries] lines and 24 h of retention, so it can
///    never grow into a shadow database;
///  * **redacted** — tokens, passwords, URLs with embedded credentials and
///    anything that looks like a long secret are stripped before an entry is
///    stored, so they cannot leak through an exported report;
///  * **no learning content** — the report contains counts and versions, never
///    word lists, meanings or notes.
class DiagnosticsService {
  DiagnosticsService();

  /// The app uses one shared instance; tests can create their own.
  static final DiagnosticsService instance = DiagnosticsService();

  static const int maxEntries = 400;
  static const Duration retention = Duration(hours: 24);
  static const String enabledKey = 'diagnostics_enabled';
  static const int maxReportChars = 64 * 1024;

  /// Hard cap for the on-disk trace file. It only ever holds text the user
  /// switched on, is rotated once, and never grows without bound.
  static const int maxFileBytes = 256 * 1024;

  /// How many queued lines trigger a write. Batching keeps the learning path
  /// free of per-answer disk I/O while still surviving a process kill.
  static const int flushThreshold = 20;

  bool _enabled = false;
  final List<DiagnosticsEntry> _entries = <DiagnosticsEntry>[];
  final List<DiagnosticsEntry> _pending = <DiagnosticsEntry>[];
  String? _lastError;
  File? _file;

  bool get enabled => _enabled;
  List<DiagnosticsEntry> get entries =>
      List<DiagnosticsEntry>.unmodifiable(_entries);
  String? get lastError => _lastError;

  /// Points the service at an app-private file. Absent a file (tests, or a
  /// platform without a writable directory) everything still works in memory.
  void attachFile(File file) {
    _file = file;
  }

  /// Reads the persisted switch, then restores the tail of the previous session
  /// so a crash that happened *before* the restart is still reportable.
  Future<bool> load(AppDatabase db) async {
    final row = await (db.select(
      db.appMeta,
    )..where((AppMeta t) => t.key.equals(enabledKey))).getSingleOrNull();
    _enabled = row?.value == '1';
    if (_enabled) await _restoreFromDisk();
    return _enabled;
  }

  Future<void> _restoreFromDisk() async {
    final File? file = _file;
    if (file == null) return;
    try {
      if (!await file.exists()) return;
      // The file is capped, but never read more than the cap regardless.
      final RandomAccessFile handle = await file.open();
      try {
        final int length = await handle.length();
        final int start = length > maxFileBytes ? length - maxFileBytes : 0;
        await handle.setPosition(start);
        final List<int> bytes = await handle.read(length - start);
        final String text = utf8.decode(bytes, allowMalformed: true);
        final DateTime cutoff = DateTime.now().subtract(retention);
        for (final String line in const LineSplitter().convert(text)) {
          final DiagnosticsEntry? entry = _parse(line);
          if (entry == null || entry.at.isBefore(cutoff)) continue;
          _entries.add(entry);
        }
        _prune();
      } finally {
        await handle.close();
      }
    } catch (_) {
      // A damaged trace file must never stop the app from starting.
    }
  }

  static DiagnosticsEntry? _parse(String line) {
    final int levelAt = line.indexOf(' INFO  [');
    final int errorAt = line.indexOf(' ERROR [');
    final int at = levelAt >= 0 ? levelAt : errorAt;
    if (at <= 0) return null;
    final DateTime? when = DateTime.tryParse(line.substring(0, at).trim());
    if (when == null) return null;
    final bool isError = errorAt >= 0;
    final int categoryStart = line.indexOf('[', at) + 1;
    final int categoryEnd = line.indexOf(']', categoryStart);
    if (categoryEnd <= categoryStart) return null;
    return DiagnosticsEntry(
      at: when,
      category: line.substring(categoryStart, categoryEnd),
      message: line.substring(categoryEnd + 1).trim(),
      isError: isError,
    );
  }

  Future<void> setEnabled(AppDatabase db, bool value) async {
    _enabled = value;
    await db
        .into(db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion.insert(key: enabledKey, value: value ? '1' : '0'),
        );
    if (!value) {
      _entries.clear();
      _pending.clear();
      await _deleteFile();
    }
    log('diagnostics', value ? 'enabled' : 'disabled');
  }

  /// Records one line. Ignored while diagnostics are off — except errors, of
  /// which exactly one (the most recent) is kept so a user can still turn the
  /// switch on and export something meaningful.
  void log(String category, String message, {bool error = false}) {
    final String safe = redact(message);
    if (!_enabled) {
      if (error) _lastError = safe;
      return;
    }
    final DiagnosticsEntry entry = DiagnosticsEntry(
      at: DateTime.now(),
      category: category,
      message: safe,
      isError: error,
    );
    _entries.add(entry);
    _pending.add(entry);
    _prune();
    if (_pending.length >= flushThreshold) {
      unawaited(flushToDisk());
    }
  }

  void _prune() {
    final DateTime cutoff = DateTime.now().subtract(retention);
    _entries.removeWhere((DiagnosticsEntry e) => e.at.isBefore(cutoff));
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  void clear() {
    _entries.clear();
    _pending.clear();
    _lastError = null;
    unawaited(_deleteFile());
  }

  /// Serialises every file operation so a delete cannot overtake an append.
  Future<void> _ioChain = Future<void>.value();

  Future<void> _enqueueIo(Future<void> Function() operation) {
    final Future<void> next = _ioChain.then((_) => operation());
    _ioChain = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  /// Writes buffered lines to the app-private file, rotating when it is full.
  ///
  /// Best-effort by design: a full disk or a read-only directory must not turn
  /// a diagnostic failure into an application failure.
  Future<void> flushToDisk() => _enqueueIo(() async {
    final File? file = _file;
    if (file == null || !_enabled) {
      _pending.clear();
      return;
    }
    if (_pending.isEmpty) return;
    final List<DiagnosticsEntry> batch = _pending.toList();
    _pending.clear();
    try {
      await file.parent.create(recursive: true);
      final String text = batch
          .map((DiagnosticsEntry e) => '${e.format()}\n')
          .join();
      final int existing = await file.exists() ? await file.length() : 0;
      if (existing + text.length > maxFileBytes) {
        final File rotated = File('${file.path}.1');
        if (await rotated.exists()) await rotated.delete();
        if (await file.exists()) await file.rename(rotated.path);
      }
      await file.writeAsString(text, mode: FileMode.append, flush: false);
    } catch (_) {
      // Intentionally silent: diagnostics must never break the app.
    }
  });

  Future<void> _deleteFile() => _enqueueIo(() async {
    final File? file = _file;
    if (file == null) return;
    try {
      final File rotated = File('${file.path}.1');
      if (await rotated.exists()) await rotated.delete();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Same reasoning as flushToDisk.
    }
  });

  static final RegExp _urlCredentials = RegExp(
    r'([a-zA-Z][a-zA-Z0-9+.-]*://)[^/\s@]+@',
  );
  static final RegExp _authorization = RegExp(
    r'(authorization|proxy-authorization)\s*[:=]\s*[^\n]+',
    caseSensitive: false,
  );
  static final RegExp _tokenLike = RegExp(
    r'\b(gh[pousr]_[A-Za-z0-9]{8,}|github_pat_[A-Za-z0-9_]{8,}|Bearer\s+[A-Za-z0-9._\-]{8,})\b',
  );
  static final RegExp _keyValueSecret = RegExp(
    r'''["']?(token|password|passwd|secret|apikey|api_key|authorization)["']?\s*[=:]\s*["']?[^\s,;&"'}]+''',
    caseSensitive: false,
  );

  /// The quoted form, which the unquoted rule above cannot cover because it
  /// stops at the first space: `password = "my secret pass"` used to leave
  /// ` secret pass"` behind.
  static final RegExp _quotedSecret = RegExp(
    r'''["']?(token|password|passwd|secret|apikey|api_key|authorization)["']?\s*[=:]\s*["'][^"'\n]*["']''',
    caseSensitive: false,
  );
  static final RegExp _longOpaque = RegExp(r'\b[A-Za-z0-9_\-]{32,}\b');

  /// A build commit as produced by CI (`--dart-define=GIT_COMMIT=$GITHUB_SHA`),
  /// possibly shortened for a display label.
  static final RegExp _shaLike = RegExp(r'^[0-9a-f]{7,40}$');

  /// A plain version or timestamp such as `1.2.0` or `2026-11-25T04:00:00Z`.
  static final RegExp _versionLike = RegExp(
    r'^[0-9]{1,4}([.:\-][0-9]{1,4}){0,6}([-+][A-Za-z0-9.:]{1,20})?$',
  );

  /// Runtime keys whose value may survive redaction verbatim — but only when the
  /// value itself looks like a build identifier, never merely because of its key.
  static const Set<String> trustedRuntimeKeys = <String>{
    'buildCommit',
    'commit',
    'gitCommit',
    'revision',
    'appVersion',
    'version',
    'flutterVersion',
    'buildTime',
  };

  /// Removes anything that could be a credential. Kept deliberately aggressive:
  /// a false positive only costs a diagnostic line, a false negative leaks a
  /// secret into a file the user shares.
  ///
  /// [keep] lists strings that must survive because they come from a trusted
  /// source (the build metadata). They are swapped for inert placeholders while
  /// the patterns run, so keeping a commit SHA can never weaken the rules for
  /// any other text — a token is only ever preserved if a caller passed it in
  /// as trusted build metadata, which the call sites never do.
  static String redact(String text, {Set<String> keep = const <String>{}}) {
    if (text.isEmpty) return text;
    String working = text;
    final Map<String, String> restored = <String, String>{};
    int index = 0;
    for (final String value in keep) {
      if (value.isEmpty || !working.contains(value)) continue;
      final String placeholder = '\u0000keep${index++}\u0000';
      restored[placeholder] = value;
      working = working.replaceAll(value, placeholder);
    }
    working = working
        .replaceAllMapped(_urlCredentials, (Match m) => '${m[1]}<redacted>@')
        .replaceAll(_authorization, 'authorization=<redacted>')
        .replaceAll(_tokenLike, '<redacted-token>')
        .replaceAllMapped(_quotedSecret, (Match m) => '${m[1]}=<redacted>')
        .replaceAllMapped(_keyValueSecret, (Match m) => '${m[1]}=<redacted>')
        .replaceAll(_longOpaque, '<redacted>');
    restored.forEach((String placeholder, String value) {
      working = working.replaceAll(placeholder, value);
    });
    return working;
  }

  /// Redacts every string inside a JSON-shaped structure, so the *encoder* is
  /// the only thing that ever produces text. This is what keeps the exported
  /// report parseable: the previous implementation redacted and truncated the
  /// already-encoded JSON, which produced invalid documents.
  static Object? redactStructured(
    Object? value, {
    Set<String> keep = const <String>{},
  }) {
    if (value is String) return redact(value, keep: keep);
    if (value is List) {
      return <Object?>[
        for (final Object? item in value) redactStructured(item, keep: keep),
      ];
    }
    if (value is Map) {
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          '${entry.key}': redactStructured(entry.value, keep: keep),
      };
    }
    return value;
  }

  /// Builds the redacted report. [runtime] lets the caller add build metadata
  /// (version, commit, host) without this class importing Flutter.
  Future<String> buildReport(
    AppDatabase db, {
    Map<String, Object?> runtime = const <String, Object?>{},
  }) async {
    final Map<String, Object?> trustedRuntime = <String, Object?>{};
    final Set<String> trustedValues = <String>{};
    runtime.forEach((String key, Object? value) {
      if (value is String &&
          trustedRuntimeKeys.contains(key) &&
          (_shaLike.hasMatch(value) || _versionLike.hasMatch(value))) {
        trustedRuntime[key] = value;
        trustedValues.add(value);
      } else {
        trustedRuntime[key] = value;
      }
    });
    final Map<String, Object?> report = <String, Object?>{
      'generatedAt': DateTime.now().toIso8601String(),
      'runtime': <String, Object?>{
        ...trustedRuntime,
        'operatingSystem': Platform.operatingSystem,
        'operatingSystemVersion': Platform.operatingSystemVersion,
        'dartVersion': Platform.version.split(' ').first,
      },
      'database': await _databaseSection(db),
      'traces': <String>[
        for (final DiagnosticsEntry entry in _entries) entry.format(),
      ],
      if (_lastError != null) 'lastError': _lastError,
      'notes': <String>[
        'Not included on purpose: credentials, sync configuration values, word '
            'lists, meanings, notes and any personal learning content.',
      ],
    };
    final Object? sanitized = redactStructured(report, keep: trustedValues);
    return _encodeWithinBudget(sanitized! as Map<String, Object?>);
  }

  /// Encodes [report] and, when it is too large, drops the oldest trace lines
  /// until it fits. The result is always a *complete* JSON document: truncation
  /// removes whole entries and sets `truncated: true`, it never cuts the
  /// encoded text in half.
  static String _encodeWithinBudget(Map<String, Object?> report) {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String text = encoder.convert(report);
    if (text.length <= maxReportChars) return text;

    final List<Object?> allTraces = <Object?>[
      ...(report['traces'] as List<Object?>? ?? const <Object?>[]),
    ];
    final List<Object?> traces = <Object?>[...allTraces];
    while (traces.isNotEmpty) {
      final int drop = (traces.length / 4).ceil().clamp(1, traces.length);
      traces.removeRange(0, drop);
      text = encoder.convert(<String, Object?>{
        ...report,
        'traces': traces,
        'truncated': true,
        'droppedTraceLines': allTraces.length - traces.length,
      });
      if (text.length <= maxReportChars) return text;
    }

    // Even without traces the skeleton is too big (a very long error message).
    final Object? lastError = report['lastError'];
    text = encoder.convert(<String, Object?>{
      ...report,
      'traces': const <Object?>[],
      if (lastError is String)
        'lastError': lastError.length > 2000
            ? '${lastError.substring(0, 2000)}…'
            : lastError,
      'truncated': true,
      'droppedTraceLines': allTraces.length,
      'notes': <String>['truncated to stay inside the export size budget'],
    });
    if (text.length <= maxReportChars) return text;

    // Absolute last resort: still a valid document, just far fewer fields.
    return encoder.convert(<String, Object?>{
      'generatedAt': report['generatedAt'],
      'runtime': report['runtime'],
      'truncated': true,
      'notes': <String>['truncated to stay inside the export size budget'],
    });
  }

  Future<Map<String, Object?>> _databaseSection(AppDatabase db) async {
    Future<int> count(String table) async {
      final QueryRow row = await db
          .customSelect('SELECT COUNT(*) AS c FROM $table')
          .getSingle();
      return row.read<int>('c');
    }

    final Map<String, String> meta = <String, String>{};
    for (final String key in <String>[
      SettingsRepository.lastSyncAtKey,
      SettingsRepository.lastSyncResultKey,
      SettingsRepository.pendingRebuildKey,
    ]) {
      final AppMetaRow? row = await (db.select(
        db.appMeta,
      )..where((AppMeta t) => t.key.equals(key))).getSingleOrNull();
      if (row != null) meta[key] = redact(row.value);
    }
    final AppMetaRow? config =
        await (db.select(db.appMeta)..where(
              (AppMeta t) => t.key.equals(SettingsRepository.syncConfigKey),
            ))
            .getSingleOrNull();
    String provider = 'none';
    if (config != null) {
      try {
        final Object? decoded = jsonDecode(config.value);
        if (decoded is Map && decoded['provider'] is String) {
          // Only the provider *kind* — never the URL, repository, account or
          // path it points at.
          provider = decoded['provider'] as String;
        }
      } on FormatException {
        provider = 'unreadable';
      }
    }

    return <String, Object?>{
      'schemaVersion': db.schemaVersion,
      'words': await count('words'),
      'wordBooks': await count('word_books'),
      'bookEntries': await count('word_book_entries'),
      'reviewEvents': await count('review_events'),
      'learningStates': await count('learning_states'),
      'tags': await count('user_tags'),
      'favorites': await count('word_favorites'),
      'syncProvider': provider,
      'syncBookkeeping': meta,
    };
  }
}
