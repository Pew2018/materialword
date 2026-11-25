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

  bool _enabled = false;
  final List<DiagnosticsEntry> _entries = <DiagnosticsEntry>[];
  String? _lastError;

  bool get enabled => _enabled;
  List<DiagnosticsEntry> get entries =>
      List<DiagnosticsEntry>.unmodifiable(_entries);
  String? get lastError => _lastError;

  /// Reads the persisted switch. Called once at start-up and after toggling.
  Future<bool> load(AppDatabase db) async {
    final row = await (db.select(
      db.appMeta,
    )..where((AppMeta t) => t.key.equals(enabledKey))).getSingleOrNull();
    _enabled = row?.value == '1';
    return _enabled;
  }

  Future<void> setEnabled(AppDatabase db, bool value) async {
    _enabled = value;
    await db
        .into(db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion.insert(key: enabledKey, value: value ? '1' : '0'),
        );
    if (!value) _entries.clear();
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
    _entries.add(
      DiagnosticsEntry(
        at: DateTime.now(),
        category: category,
        message: safe,
        isError: error,
      ),
    );
    _prune();
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
    _lastError = null;
  }

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
  static final RegExp _longOpaque = RegExp(r'\b[A-Za-z0-9_\-]{32,}\b');

  /// Removes anything that could be a credential. Kept deliberately aggressive:
  /// a false positive only costs a diagnostic line, a false negative leaks a
  /// secret into a file the user shares.
  static String redact(String text) {
    return text
        .replaceAllMapped(_urlCredentials, (Match m) => '${m[1]}<redacted>@')
        .replaceAll(_authorization, 'authorization=<redacted>')
        .replaceAll(_tokenLike, '<redacted-token>')
        .replaceAllMapped(_keyValueSecret, (Match m) => '${m[1]}=<redacted>')
        .replaceAll(_longOpaque, '<redacted>');
  }

  /// Builds the redacted report. [runtime] lets the caller add build metadata
  /// (version, commit, host) without this class importing Flutter.
  Future<String> buildReport(
    AppDatabase db, {
    Map<String, Object?> runtime = const <String, Object?>{},
  }) async {
    final Map<String, Object?> report = <String, Object?>{
      'generatedAt': DateTime.now().toIso8601String(),
      'runtime': <String, Object?>{
        ...runtime,
        'operatingSystem': Platform.operatingSystem,
        'operatingSystemVersion': redact(Platform.operatingSystemVersion),
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
    String text = const JsonEncoder.withIndent('  ').convert(report);
    if (text.length > maxReportChars) {
      text = '${text.substring(0, maxReportChars)}\n… (truncated)';
    }
    // Final safety net: the encoded payload goes through the same redaction.
    return redact(text);
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
