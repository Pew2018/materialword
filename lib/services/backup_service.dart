import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/models/enums.dart';
import '../core/models/sprint_plan.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/content_sync_repository.dart';
import '../core/repositories/study_repository.dart';
import '../core/repositories/word_repository.dart';
import '../core/text/dictionary_text.dart';
import 'study_scheduler.dart';
import 'dictionary_packages.dart';
import 'word_metadata_sync.dart';

const Uuid _uuid = Uuid();

/// Backup / sync document format.
///
/// * v1 — phase 1: words, books, entries, events, settings (no tombstones).
/// * v2 — phase 2: stable `datasetId`, per-row `revision`/`version`/`updatedAt`,
///   entry tombstones (`deletedAt`), review-event `mode`, shared/device
///   settings split, and a stable `contentHash` used to skip no-op uploads.
/// * v3 — phase 3: event day anchors/provenance, favourites, tags, retained
///   identities and per-field versions.
/// * v5 — complete, event-validated learningStates for backups and sync.
/// * v4 — phase 5: **backup files only** may carry `deviceSettings` (theme,
///   accent, TTS, keep-screen-on) for device migration. The sync dataset stays
///   at v3 so an older client never receives a version it cannot read, and the
///   device block never travels between devices.
const int backupSchemaVersion = 6;
const int syncSchemaVersion = 6;
const String backupKind = 'materialword-backup';

/// Summary of what an import/merge actually changed.
class MergeReport {
  const MergeReport({
    this.addedEvents = 0,
    this.duplicateEvents = 0,
    this.newWords = 0,
    this.updatedWords = 0,
    this.deletedWords = 0,
    this.newBooks = 0,
    this.updatedBooks = 0,
    this.newEntries = 0,
    this.removedEntries = 0,
    this.rebuiltStates = 0,
    this.skippedEntries = 0,
    this.conflicts = 0,
    this.settingsKept = true,
    this.metadataUpdates = 0,
    this.conflictDetails = const <FieldConflict>[],
  });

  final int addedEvents;
  final int duplicateEvents;
  final int newWords;
  final int updatedWords;
  final int deletedWords;
  final int newBooks;
  final int updatedBooks;
  final int newEntries;
  final int removedEntries;
  final int rebuiltStates;
  final int skippedEntries;

  /// Words where both sides changed the same content and the winner was chosen
  /// by (revision, updatedAt). Reported so the user knows something was merged.
  final int conflicts;
  final bool settingsKept;
  final int metadataUpdates;

  /// Which field of which entity lost a value, so the user can review and
  /// restore it (see `SyncConflictStore`).
  final List<FieldConflict> conflictDetails;

  bool get hasChanges =>
      metadataUpdates > 0 ||
      addedEvents > 0 ||
      newWords > 0 ||
      updatedWords > 0 ||
      deletedWords > 0 ||
      newBooks > 0 ||
      updatedBooks > 0 ||
      newEntries > 0 ||
      removedEntries > 0 ||
      rebuiltStates > 0;
}

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Versioned JSON backup + merge.
///
/// Design rules (see `docs/sync-protocol.md`):
///  * never replace the whole database — merge instead;
///  * the *normalised word text* is the identity: two devices that created the
///    same word independently keep one row, and every remote id is mapped to
///    the canonical local id before entries/events are written;
///  * review events are immutable and de-duplicated by id, which makes repeated
///    imports and round-trip syncs idempotent;
///  * deletions are tombstones with a version, so an old backup cannot
///    resurrect them;
///  * learning state is recomputed from the merged event log **inside the same
///    transaction**, so an interrupted merge leaves no half-rebuilt state.
class BackupService {
  BackupService({
    required this.db,
    required this.study,
    required this.words,
    required this.settings,
  });

  final AppDatabase db;
  final StudyRepository study;
  final WordRepository words;
  final SettingsRepository settings;

  // ------------------------------------------------------------- building

  Future<Map<String, Object?>> buildDataset({
    required DateTime now,
    bool includeEvents = true,
    bool includeDeviceSettings = false,
  }) => db.transaction(() async {
    final String deviceId = await settings.deviceId();
    final String datasetId = await settings.datasetId();
    final List<Word> wordRows =
        await (db.select(db.words)..orderBy(<OrderClauseGenerator<$WordsTable>>[
              (t) => OrderingTerm(expression: t.normalized),
            ]))
            .get();
    final List<WordBook> bookRows =
        await (db.select(db.wordBooks)
              ..orderBy(<OrderClauseGenerator<$WordBooksTable>>[
                (t) => OrderingTerm(expression: t.createdAt),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    final List<WordBookEntry> entryRows =
        await (db.select(db.wordBookEntries)
              ..orderBy(<OrderClauseGenerator<$WordBookEntriesTable>>[
                (t) => OrderingTerm(expression: t.wordBookId),
                (t) => OrderingTerm(expression: t.wordId),
              ]))
            .get();
    final List<ReviewEvent> eventRows = includeEvents
        ? await (db.select(db.reviewEvents)
                ..orderBy(<OrderClauseGenerator<$ReviewEventsTable>>[
                  (t) => OrderingTerm(expression: t.answeredAt),
                  (t) => OrderingTerm(expression: t.id),
                ]))
              .get()
        : const <ReviewEvent>[];
    final stateRows = includeEvents
        ? await db.select(db.learningStates).get()
        : const <LearningState>[];
    final stampRows = await db.select(db.contentVersions).get();
    final aliasRows = await db.select(db.syncAliases).get();
    final stamps = <String, Map<String, Object?>>{};
    final aliases = <String, List<String>>{};
    for (final row in stampRows) {
      (stamps['${row.kind}:${row.entityId}'] ??= {})[row.field] = {
        'version': row.version,
        'updatedAt': row.updatedAt,
        'deviceId': row.deviceId,
      };
    }
    for (final row in aliasRows) {
      (aliases['${row.kind}:${row.localId}'] ??= []).add(row.aliasId);
    }
    Map<String, Object?> withIdentity(String kind, Map<String, Object?> row) {
      final key = '$kind:${row['id']}';
      if (stamps.containsKey(key)) row['fieldVersions'] = stamps[key];
      if (aliases.containsKey(key)) row['aliases'] = aliases[key]!..sort();
      return row;
    }

    final StudySettingsRow current = await settings.load();

    return <String, Object?>{
      'schemaVersion': includeDeviceSettings
          ? backupSchemaVersion
          : syncSchemaVersion,
      'kind': backupKind,
      'datasetId': datasetId,
      'deviceId': deviceId,
      'exportedAt': now.toUtc().toIso8601String(),
      'appVersion': '1.2.0',
      'words': wordRows
          .map((w) => withIdentity('word', _wordToJson(w)))
          .toList(growable: false),
      'wordBooks': bookRows
          .map((b) => withIdentity('book', _bookToJson(b)))
          .toList(growable: false),
      'entries': entryRows.map(_entryToJson).toList(growable: false),
      'reviewEvents': eventRows.map(_eventToJson).toList(growable: false),
      'dictionaryPackages': await DictionaryPackages.snapshot(db),
      'learningStates': stateRows
          .map((s) => s.toJson())
          .toList(growable: false),
      'progressAlgorithmVersion': StudyScheduler.algorithmVersion,
      'progressEventDigest': eventDigest(eventRows.map(_eventToJson).toList()),
      ...await WordMetadataSync(db).snapshot(),
      // Only *shared* settings travel. Theme, accent, TTS and the active book
      // describe this device and must not jump between devices.
      'settings': <String, Object?>{
        'dailyNewTarget': current.dailyNewTarget,
        'dailyReviewLimit': current.dailyReviewLimit,
        'studyMode': current.studyMode,
        'sprintPlan': (await settings.loadSprintPlan()).toJson(),
        'version': await settings.sharedVersion(),
      },
    };
  });

  /// Exports shared learning data. The legacy includeDeviceSettings argument
  /// remains source-compatible but device preferences are always excluded.
  Future<String> exportToJson({
    required DateTime now,
    bool pretty = true,
    bool includeDeviceSettings = true,
  }) async {
    final Map<String, Object?> dataset = await buildDataset(
      now: now,
      includeDeviceSettings: includeDeviceSettings,
    );
    return encodeDatasetJson(dataset, pretty: pretty);
  }

  /// Writes a recovery copy **atomically**.
  ///
  /// The old implementation called `writeAsString` on the final path, so a full
  /// disk or a killed process could truncate the last good backup. Now the JSON
  /// goes to a sibling `.tmp` file, is flushed, re-read and validated, and only
  /// then renamed into place. A failure leaves every previous backup intact.
  ///
  /// The name carries milliseconds plus a random suffix: two backups in the same
  /// second can no longer overwrite each other.
  Future<File> writeBackupFile({
    required Directory directory,
    required DateTime now,
    bool includeDeviceSettings = true,
    String label = 'auto',
  }) async {
    final Map<String, Object?> dataset = await buildDataset(
      now: now,
      includeDeviceSettings: includeDeviceSettings,
    );
    final String json = await encodeDatasetJson(dataset, pretty: false);
    return writeJsonAtomically(
      directory: directory,
      json: json,
      now: now,
      label: label,
    );
  }

  /// Shared atomic writer for backups and exported snapshots.
  Future<File> writeJsonAtomically({
    required Directory directory,
    required String json,
    required DateTime now,
    String label = 'auto',
    String prefix = 'materialword-backup',
  }) async {
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    final String stamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}'
        '-${three(now.millisecond)}';
    final String random = _uuid.v4().substring(0, 6);
    final String base = '$prefix-$stamp-$label-$random';
    final File target = File('${directory.path}/$base.json');
    final File temp = File('${directory.path}/.$base.tmp');
    try {
      await temp.writeAsString(json, flush: true);
      final String readBack = await temp.readAsString();
      if (readBack.length != json.length) {
        throw const BackupException('备份写入不完整（长度校验失败）');
      }
      // Prove the file on disk is a dataset this build can actually read before
      // it becomes the newest recovery copy.
      decodeDataset(readBack);
      await temp.rename(target.path);
      return target;
    } catch (e) {
      try {
        if (temp.existsSync()) await temp.delete();
      } catch (_) {}
      if (e is BackupException) rethrow;
      throw BackupException('备份写入失败（原有备份未受影响）：$e');
    }
  }

  /// Removes leftover `.<name>.tmp` files from an interrupted write. Missing or
  /// unreadable directories are ignored: this is housekeeping, not data.
  static int cleanupTempFiles(
    Directory directory, {
    Duration maxAge = const Duration(hours: 1),
  }) {
    if (!directory.existsSync()) return 0;
    final DateTime cutoff = DateTime.now().subtract(maxAge);
    int removed = 0;
    try {
      for (final FileSystemEntity entity in directory.listSync()) {
        if (entity is! File) continue;
        final String name = entity.uri.pathSegments.last;
        if (!name.startsWith('.') || !name.endsWith('.tmp')) continue;
        try {
          if (entity.statSync().modified.isBefore(cutoff)) {
            entity.deleteSync();
            removed++;
          }
        } catch (_) {
          // Another process may be writing it; skip.
        }
      }
    } catch (_) {
      return removed;
    }
    return removed;
  }

  Future<Map<String, Object?>> readDataset(String path) async {
    final File file = File(path);
    if (!file.existsSync()) {
      throw const BackupException('备份文件不存在');
    }
    final String raw = await file.readAsString();
    return decodeDatasetAsync(raw);
  }

  Future<Map<String, Object?>> decodeDatasetAsync(String raw) =>
      decodeValidatedDatasetJson(raw);

  Future<Map<String, Object?>> validateDatasetAsync(
    Map<String, Object?> dataset,
  ) => validateDatasetInBackground(dataset);

  /// Validates structure and protocol version. Used by every entry point
  /// (file import, local file sync, GitHub, WebDAV) so a corrupt remote cannot
  /// reach the merge code.
  Map<String, Object?> decodeDataset(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const BackupException('不是合法的 JSON 文件');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupException('备份文件根节点必须是对象');
    }
    return validateDataset(decoded);
  }

  Map<String, Object?> validateDataset(Map<String, Object?> dataset) =>
      _validateDatasetCore(dataset);

  static Map<String, Object?> _validateDatasetCore(
    Map<String, Object?> dataset,
  ) {
    final Object? version = dataset['schemaVersion'];
    if (version is! int) {
      throw const BackupException('缺少 schemaVersion');
    }
    if (version > backupSchemaVersion) {
      throw BackupException('数据版本过新（$version），请升级应用后再同步');
    }
    final Object? kind = dataset['kind'];
    if (kind != null && kind != backupKind) {
      throw const BackupException('不是 MaterialWord 数据文件');
    }
    for (final String field in <String>[
      'words',
      'wordBooks',
      'entries',
      'reviewEvents',
    ]) {
      final Object? value = dataset[field];
      if (value != null && value is! List<dynamic>) {
        throw BackupException('字段 $field 必须是数组');
      }
    }
    if (version < 1) throw const BackupException('不支持的备份版本');
    for (final event in (dataset['reviewEvents'] as List?) ?? const []) {
      if (event is! Map) throw const BackupException('学习记录结构无效');
      final algorithm = event['algoVersion'];
      if (algorithm is int && algorithm > StudyScheduler.algorithmVersion) {
        throw const BackupException('学习算法版本过新，请升级应用');
      }
      final mode = event['mode'] ?? 'normal';
      if (mode is! String ||
          !(<String>{
                'normal',
                'special-hard',
                'special-mistakes',
                'special-book',
                'special-favorites',
                'special-session-mistakes',
                'special-sprint',
                'manual-mastered',
                'manual-unmastered',
                'reset',
                'repeat',
                'sprint',
                'practice-spelling',
                'practice-dictation',
                'practice-choice',
                'practice-cloze',
              }.contains(mode) ||
              (mode.startsWith('undo:') && mode.length > 5))) {
        throw const BackupException('学习记录类型不受支持，请升级应用');
      }
    }
    _validateRecords(dataset, version);
    if (version >= 5) _validateProgress(dataset);
    if (version >= 6) {
      try {
        DictionaryPackages.validate(dataset['dictionaryPackages']);
      } on FormatException {
        throw const BackupException('词典清单无效，未恢复数据');
      }
    }
    return dataset;
  }

  static void _validateRecords(Map<String, Object?> data, int protocol) {
    Never invalid(String field) =>
        throw BackupException('备份字段 $field 无效，未合并任何数据');
    List<Map<String, dynamic>> records(String field) {
      final value = data[field];
      if (value == null && protocol < 3) return [];
      if (value is! List) invalid(field);
      return value
          .map((row) {
            if (row is! Map<String, dynamic>) invalid(field);
            return row;
          })
          .toList(growable: false);
    }

    void text(Map<String, dynamic> row, String field, {bool required = false}) {
      final value = row[field];
      if (value == null && !required) return;
      if (value is! String || (required && value.trim().isEmpty)) {
        invalid(field);
      }
    }

    void number(Map<String, dynamic> row, String field, {int min = 0}) {
      final value = row[field];
      if (value != null && (value is! int || value < min)) invalid(field);
    }

    void timestamp(
      Map<String, dynamic> row,
      String field, {
      bool required = false,
    }) {
      final value = row[field];
      if (value == null && !required) return;
      if (value is! int && value is! String) invalid(field);
      try {
        if (_parseTime(value) == null) invalid(field);
        if (value is String &&
            !RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value)) {
          invalid(field);
        }
      } on RangeError {
        invalid(field);
      }
    }

    final claimed = <String, Set<String>>{};
    void identity(Map<String, dynamic> row, String kind) {
      final aliases = row['aliases'];
      if (aliases != null &&
          (aliases is! List ||
              aliases.length > 256 ||
              aliases.any((id) => id is! String || id.trim().isEmpty) ||
              aliases.toSet().length != aliases.length)) {
        invalid('aliases');
      }
      final ids = <String>{row['id'] as String, ...?aliases?.cast<String>()};
      final known = claimed.putIfAbsent(kind, () => <String>{});
      if (ids.any(known.contains)) invalid('aliases:重复身份');
      known.addAll(ids);
      final stamps = row['fieldVersions'];
      if (stamps == null) return;
      if (stamps is! Map) invalid('fieldVersions');
      for (final entry in stamps.entries) {
        if (!ContentSyncRepository.fields(kind).contains(entry.key) ||
            !row.containsKey(entry.key) ||
            entry.value is! Map) {
          invalid('fieldVersions');
        }
        final stamp = Map<String, dynamic>.from(entry.value as Map);
        if (stamp['version'] is! int ||
            stamp['updatedAt'] is! int ||
            stamp['deviceId'] is! String) {
          invalid('fieldVersions');
        }
        number(stamp, 'version');
        timestamp(stamp, 'updatedAt', required: true);
      }
    }

    final words = records('words'),
        books = records('wordBooks'),
        entries = records('entries'),
        events = records('reviewEvents');
    final wordIds = <String>{},
        normalized = <String>{},
        bookIds = <String>{},
        entryIds = <String>{};
    for (final word in words) {
      text(word, 'id', required: true);
      text(word, 'word', required: true);
      identity(word, 'word');
      final key = normalizeWordKey(word['word'] as String);
      if (word['normalized'] != null && word['normalized'] != key) {
        invalid('normalized');
      }
      if (!wordIds.add(word['id'] as String) || !normalized.add(key)) {
        invalid('words:重复身份');
      }
      for (final field in [
        'phonetic',
        'partOfSpeech',
        'translation',
        'definition',
        'example',
        'phrase',
        'note',
        'source',
        'examTags',
      ]) {
        text(word, field);
      }
      for (final field in ['createdAt', 'updatedAt', 'deletedAt']) {
        timestamp(word, field);
      }
      for (final field in ['revision', 'bncRank', 'frqRank']) {
        number(word, field);
      }
      if (word['customized'] != null && word['customized'] is! bool) {
        invalid('customized');
      }
    }
    for (final book in books) {
      text(book, 'id', required: true);
      text(book, 'name', required: true);
      identity(book, 'book');
      if (!bookIds.add(book['id'] as String)) invalid('wordBooks:重复身份');
      for (final field in ['description', 'sourceType', 'sourceUrl']) {
        text(book, field);
      }
      for (final field in ['createdAt', 'updatedAt', 'deletedAt']) {
        timestamp(book, field);
      }
      number(book, 'revision');
    }
    WordMetadataSync.validate(data, wordIds, invalid);
    for (final entry in entries) {
      text(entry, 'wordId', required: true);
      text(entry, 'wordBookId', required: true);
      if (!wordIds.contains(entry['wordId']) ||
          !bookIds.contains(entry['wordBookId'])) {
        invalid('entries:引用不存在');
      }
      if (!entryIds.add(jsonEncode([entry['wordId'], entry['wordBookId']]))) {
        invalid('entries:重复身份');
      }
      number(entry, 'version');
      for (final field in ['addedAt', 'updatedAt', 'deletedAt']) {
        timestamp(entry, field);
      }
    }
    final eventWords = <String, String>{};
    final eventById = <String, Map<String, dynamic>>{};
    for (final event in events) {
      text(event, 'id', required: true);
      text(event, 'wordId', required: true);
      if (!wordIds.contains(event['wordId']) ||
          eventWords.containsKey(event['id'])) {
        invalid('reviewEvents:引用或身份');
      }
      eventWords[event['id'] as String] = event['wordId'] as String;
      eventById[event['id'] as String] = event;
      timestamp(event, 'answeredAt', required: true);
      number(event, 'causalOrder');
      timestamp(event, 'dayStartUtc');
      if (event['dayStartSource'] != null &&
          ![
            'authored',
            'legacy-state',
            'legacy-utc',
          ].contains(event['dayStartSource'])) {
        invalid('dayStartSource');
      }
      text(event, 'deviceId');
      text(event, 'localDay');
      if (event['localDay'] != null &&
          !RegExp(r'^\d{4}-\d{2}-\d{2}$')
              .hasMatch(event['localDay'] as String)) {
        invalid('localDay');
      }
      if (event['result'] is! int || ![0, 1, 2].contains(event['result'])) {
        invalid('result');
      }
      if (!['study', 'review'].contains(event['type'])) invalid('type');
      number(event, 'stageBefore');
      number(event, 'intervalDaysAfter');
      number(event, 'algoVersion', min: 1);
      final anchor = _parseTime(event['dayStartUtc']);
      if (event['dayStartSource'] != null && anchor == null) {
        invalid('dayStartSource:缺少锚点');
      }
      final at = _parseTime(event['answeredAt'])!;
      if (anchor != null &&
          (anchor.isAfter(at) ||
              at.difference(anchor) > const Duration(hours: 26))) {
        invalid('dayStartUtc');
      }
    }
    for (final event in events) {
      final mode = (event['mode'] as String?) ?? 'normal';
      if (mode.startsWith('undo:')) {
        final target = mode.substring(5);
        if (target == event['id'] || eventWords[target] != event['wordId']) {
          invalid('undo:引用不存在');
        }
        final targetEvent = eventById[target]!;
        if (ReviewEventMode.isManagement(
          (targetEvent['mode'] as String?) ?? 'normal',
        )) {
          invalid('undo:不是作答');
        }
      }
    }
    final shared = data['settings'];
    if (shared != null) {
      if (shared is! Map<String, dynamic>) invalid('settings');
      number(shared, 'dailyNewTarget');
      number(shared, 'dailyReviewLimit');
      if (shared['sprintPlan'] != null) {
        if (shared['sprintPlan'] is! Map<String, dynamic>) {
          invalid('sprintPlan');
        }
        try {
          final plan = SprintPlan.fromJson(
            Map<String, Object?>.from(shared['sprintPlan'] as Map),
          );
          if (plan.bookId != null && !bookIds.contains(plan.bookId)) {
            invalid('sprintPlan:词书引用');
          }
        } on FormatException {
          invalid('sprintPlan');
        }
      }
      if (shared['studyMode'] != null &&
          !StudyMode.values.any((mode) => mode.code == shared['studyMode'])) {
        invalid('studyMode');
      }
      final version = shared['version'];
      if (version != null) {
        if (version is! Map<String, dynamic>) invalid('settings.version');
        number(version, 'counter');
        text(
          version,
          'deviceId',
          required: (version['counter'] as int? ?? 0) > 0,
        );
        if (version['counter'] is! int || version['deviceId'] is! String) {
          invalid('settings.version');
        }
      }
    }
  }

  /// Event identity is stable across canonical word-ID remapping.
  static String eventDigest(List events) {
    final canonical =
        events.map((raw) {
            final row = Map<String, Object?>.from(raw as Map)..remove('wordId');
            final keys = row.keys.toList()..sort();
            return {for (final key in keys) key: row[key]};
          }).toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return 'sha256:${sha256.convert(utf8.encode(jsonEncode(canonical)))}';
  }

  static void _validateProgress(Map<String, Object?> data) {
    Never invalid() => throw const BackupException('学习进度与记录不一致或已损坏，未恢复数据');
    if (data['progressAlgorithmVersion'] != StudyScheduler.algorithmVersion) {
      throw const BackupException('不支持的学习进度算法版本，请升级应用');
    }
    final events = data['reviewEvents'] as List;
    if (data['progressEventDigest'] != eventDigest(events)) invalid();
    final rawStates = data['learningStates'];
    if (rawStates is! List) invalid();
    final grouped = <String, List<ReviewEvent>>{};
    for (final raw in events) {
      final row = Map<String, dynamic>.from(raw as Map);
      final event = _eventFromJson(row, row['wordId'] as String)!;
      (grouped[event.wordId] ??= []).add(event);
    }
    final expected = <String, Map<String, Object?>>{};
    for (final entry in grouped.entries) {
      final state = StudyRepository.replayState(entry.key, entry.value);
      if (state != null) expected[entry.key] = state;
    }
    final seen = <String>{};
    for (final raw in rawStates) {
      if (raw is! Map) invalid();
      final id = raw['wordId'];
      if (id is! String || !seen.add(id) || !expected.containsKey(id)) {
        invalid();
      }
      for (final entry in expected[id]!.entries) {
        if (entry.key == 'updatedAt') {
          if (raw[entry.key] is! int || (raw[entry.key] as int) < 0) invalid();
        } else if (raw[entry.key] != entry.value) {
          invalid();
        }
      }
    }
    if (seen.length != expected.length) invalid();
  }

  /// Stable hash of the *content* of a dataset. Volatile metadata (`exportedAt`,
  /// `deviceId`, `appVersion`) is excluded, so two exports of the same data
  /// produce the same hash and a no-op sync does not upload anything.
  static String contentHashOf(Map<String, Object?> dataset) {
    final wordKeys = <String, String>{};
    final bookKeys = <String, String>{};
    List<Map<String, Object?>> rows(String field) =>
        ((dataset[field] as List?) ?? [])
            .map((e) => Map<String, Object?>.from(e as Map))
            .toList();
    final words = rows('words');
    final books = rows('wordBooks');
    for (final w in words) {
      wordKeys[w['id'] as String] = w['normalized'] as String;
    }
    for (final b in books) {
      bookKeys[b['id'] as String] = jsonEncode([b['name'], b['deletedAt']]);
    }
    for (final w in words) {
      w.remove('aliases');
      w.remove('id');
      w.remove('createdAt');
    }
    for (final b in books) {
      b.remove('aliases');
      b.remove('id');
      b.remove('createdAt');
    }
    final entries = rows('entries');
    final events = rows('reviewEvents');
    final states = rows('learningStates');
    for (final state in states) {
      state['wordId'] = wordKeys[state['wordId']] ?? state['wordId'];
    }
    final tags = rows('tags');
    final tagKeys = <String, String>{
      for (final tag in tags)
        tag['id'] as String: jsonEncode([tag['normalized'], tag['deletedAt']]),
    };
    for (final tag in tags) {
      tag.remove('id');
      tag.remove('aliases');
    }
    final favorites = rows('favorites');
    final wordTags = rows('wordTags');
    for (final row in [...favorites, ...wordTags]) {
      row['wordId'] = wordKeys[row['wordId']] ?? row['wordId'];
      if (row.containsKey('tagId')) {
        row['tagId'] = tagKeys[row['tagId']] ?? row['tagId'];
      }
    }
    for (final e in [...entries, ...events]) {
      e['wordId'] = wordKeys[e['wordId']] ?? e['wordId'];
      if (e.containsKey('wordBookId')) {
        e['wordBookId'] = bookKeys[e['wordBookId']] ?? e['wordBookId'];
      }
    }
    for (final event in events) {
      event.putIfAbsent('causalOrder', () => 0);
    }
    for (final e in entries) {
      e.remove('addedAt');
    }
    Object? canonicalize(Object? value) {
      if (value is Map) {
        final keys = value.keys.cast<String>().toList()..sort();
        return <String, Object?>{
          for (final k in keys) k: canonicalize(value[k]),
        };
      }
      if (value is List) {
        final result = value.map(canonicalize).toList();
        result.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
        return result;
      }
      return value;
    }

    final shared = Map<String, Object?>.from(
      (dataset['settings'] as Map?) ?? {},
    );
    final plan = Map<String, Object?>.from(
      (shared['sprintPlan'] as Map?) ?? const SprintPlan().toJson(),
    );
    if (plan['bookId'] != null) {
      plan['bookId'] = bookKeys[plan['bookId']] ?? plan['bookId'];
    }
    shared['sprintPlan'] = plan;
    final canonical = canonicalize(<String, Object?>{
      'schemaVersion': dataset['schemaVersion'],
      'words': words,
      'wordBooks': books,
      'entries': entries,
      'reviewEvents': events,
      'learningStates': states,
      'dictionaryPackages': dataset['dictionaryPackages'] ?? [],
      'progressAlgorithmVersion': dataset['progressAlgorithmVersion'],
      'favorites': favorites,
      'tags': tags,
      'wordTags': wordTags,
      'settings': shared,
    });
    return 'sha256:${sha256.convert(utf8.encode(jsonEncode(canonical)))}';
  }

  static Future<String> contentHashOfAsync(Map<String, Object?> dataset) =>
      Isolate.run(() => contentHashOf(dataset));

  Future<MergeReport> importFromFile(String path) async {
    final Map<String, Object?> dataset = await readDataset(path);
    return mergeDataset(dataset, now: DateTime.now());
  }

  // -------------------------------------------------------------- merging

  /// Merges [dataset] into the local database in a single transaction, then
  /// rebuilds every touched learning state **inside** that transaction.
  ///
  /// [onPhase] is a measurement hook: it reports how long each section of the
  /// merge took, so an optimisation can be justified by data instead of by
  /// guessing where 14 seconds go. It has no effect on the merged result and is
  /// null in production.
  Future<MergeReport> mergeDataset(
    Map<String, Object?> dataset, {
    required DateTime now,
    void Function(String phase, Duration elapsed)? onPhase,
    bool legacyWordMerge = false,
  }) async {
    final Map<String, Object?> valid = await validateDatasetAsync(dataset);
    return db.transaction(
      () => mergeValidatedInTransaction(
        valid,
        now: now,
        onPhase: onPhase,
        legacyWordMerge: legacyWordMerge,
      ),
    );
  }

  /// Merges an already validated dataset. The caller owns the transaction,
  /// which is what lets a point-in-time restore clear and repopulate the
  /// database in one atomic step (see `BackupManager.restoreSnapshot`).
  ///
  /// [onPhase] is a measurement hook: it reports how long each section of the
  /// merge took, so an optimisation can be justified by data instead of by
  /// guessing where the time goes. It never affects the merged result.
  Future<MergeReport> mergeValidatedInTransaction(
    Map<String, Object?> valid, {
    required DateTime now,
    void Function(String phase, Duration elapsed)? onPhase,
    bool legacyWordMerge = false,
    bool applySharedSettings = true,
    bool forceSharedSettings = false,
    List<FieldConflict>? conflictSink,
  }) async {
    final Stopwatch clock = Stopwatch()..start();
    void phase(String name) {
      if (onPhase == null) return;
      onPhase(name, clock.elapsed);
      clock.reset();
    }

    final List<dynamic> rawWords =
        (valid['words'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawBooks =
        (valid['wordBooks'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawEntries =
        (valid['entries'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawEvents =
        (valid['reviewEvents'] as List<dynamic>?) ?? const <dynamic>[];

    int addedEvents = 0;
    int duplicateEvents = 0;
    int newWords = 0;
    int updatedWords = 0;
    int deletedWords = 0;
    int newBooks = 0;
    int updatedBooks = 0;
    int newEntries = 0;
    int removedEntries = 0;
    int conflicts = 0;
    int metadataUpdates = 0;
    int skipped = 0;
    final Set<String> touchedWords = <String>{};
    final List<FieldConflict> conflictDetails = <FieldConflict>[];

    final bool originallyEmpty =
        await _countWords() == 0 && await _countEvents() == 0;
    phase('transaction-start');
    // ------------------------------------------------------------- words
    // remote id → canonical local id. Without this mapping, entries/events
    // would keep pointing at a UUID this database never had and be dropped.
    final Map<String, String> wordIdMap = <String, String>{};
    final Map<String, String> bookIdMap = <String, String>{};

    final ContentSyncRepository content = ContentSyncRepository(db);
    List<String> aliases(Map<String, dynamic> node) =>
        (node['aliases'] as List?)?.cast<String>() ?? const [];
    Map<String, Object?> presentFields(
      Map<String, dynamic> raw,
      Map<String, Object?> normalized,
    ) => {
      for (final key in raw.keys)
        if (normalized.containsKey(key))
          key: normalized[key]
        else
          key: raw[key],
    };

    final _WordMergeResult wordResult = legacyWordMerge
        ? await _mergeWordsPerRow(
            rawWords,
            content,
            wordIdMap,
            aliases: aliases,
            presentFields: presentFields,
            now: now,
            conflictDetails: conflictDetails,
          )
        : await _mergeWordsBatched(
            rawWords,
            content,
            wordIdMap,
            aliases: aliases,
            presentFields: presentFields,
            now: now,
            conflictDetails: conflictDetails,
          );
    newWords = wordResult.newWords;
    updatedWords = wordResult.updatedWords;
    deletedWords = wordResult.deletedWords;
    conflicts += wordResult.conflicts;

    phase('words');
    // IDs and retained aliases take precedence over names, so later renames
    // keep existing entries and events attached to their original identity.
    for (final dynamic raw in rawBooks) {
      final node = raw as Map<String, dynamic>;
      final incoming = _bookFromJson(node)!;
      final resolved = await content.resolve(
        'book',
        incoming.id,
        aliases(node),
      );
      WordBook? local;
      if (resolved != null) {
        local = await (db.select(
          db.wordBooks,
        )..where((t) => t.id.equals(resolved))).getSingleOrNull();
      } else {
        final candidates = await (db.select(
          db.wordBooks,
        )..where((t) => t.name.equals(incoming.name))).get();
        final compatible = candidates
            .where(
              (b) =>
                  !(b.deletedAt != null && incoming.createdAt > b.deletedAt!) &&
                  !(incoming.deletedAt != null &&
                      b.createdAt > incoming.deletedAt!),
            )
            .toList();
        if (compatible.length > 1) {
          throw const BackupException('词书同名身份不明确，未合并任何数据');
        }
        local = compatible.firstOrNull;
      }
      final id = local?.id ?? incoming.id;
      bookIdMap[incoming.id] = id;
      await content.remember('book', id, [incoming.id, ...aliases(node)]);
      if (local == null) {
        await db.into(db.wordBooks).insert(incoming);
        if (node['fieldVersions'] != null) {
          await content.saveVersions(
            'book',
            id,
            (node['fieldVersions'] as Map).map(
              (key, value) => MapEntry(
                key as String,
                Map<String, Object?>.from(value as Map),
              ),
            ),
          );
        }
        if (incoming.deletedAt == null) newBooks++;
        continue;
      }
      // `mergeWithStamps` (not `merge`) so the per-field details reach the
      // conflict log: a book rename/description/deletion conflict must be
      // restorable by the user, exactly like a word field.
      final merged = await content.mergeWithStamps(
        'book',
        id,
        _bookToJson(local),
        presentFields(node, _bookToJson(incoming)),
        await content.versions('book', id),
      );
      if (merged.changed) {
        final updated = _bookFromJson(Map<String, dynamic>.from(merged.row))!
            .copyWith(id: id, createdAt: local.createdAt);
        await db.update(db.wordBooks).replace(updated);
        updatedBooks++;
      }
      conflicts += merged.conflicts.length;
      conflictDetails.addAll(merged.conflicts);
    }

    phase('books');
    // ----------------------------------------------------------- entries
    for (final dynamic node in rawEntries) {
      if (node is! Map<String, dynamic>) {
        skipped++;
        continue;
      }
      final String? remoteBookId = node['wordBookId'] as String?;
      final String? remoteWordId = node['wordId'] as String?;
      if (remoteBookId == null || remoteWordId == null) {
        skipped++;
        continue;
      }
      final String bookId = bookIdMap[remoteBookId] ?? remoteBookId;
      final String? wordId = wordIdMap[remoteWordId];
      if (wordId == null) {
        skipped++;
        continue;
      }
      final WordBookEntry? incoming = _entryFromJson(node, bookId, wordId);
      if (incoming == null) {
        skipped++;
        continue;
      }
      final WordBookEntry? local =
          await (db.select(db.wordBookEntries)..where(
                (t) => t.wordBookId.equals(bookId) & t.wordId.equals(wordId),
              ))
              .getSingleOrNull();
      if (local == null) {
        await db
            .into(db.wordBookEntries)
            .insert(incoming, mode: InsertMode.insertOrIgnore);
        if (incoming.deletedAt == null) {
          newEntries++;
        } else {
          removedEntries++;
        }
        continue;
      }
      final order = _versionOf(
        incoming.version,
        incoming.updatedAt,
      ).compareTo(_versionOf(local.version, local.updatedAt));
      if (order < 0 ||
          (order == 0 &&
              (incoming.deletedAt == null || local.deletedAt != null))) {
        continue;
      }
      await db
          .update(db.wordBookEntries)
          .replace(
            local.copyWith(
              version: incoming.version,
              updatedAt: incoming.updatedAt,
              deletedAt: Value<int?>(incoming.deletedAt),
            ),
          );
      if (incoming.deletedAt != null) {
        removedEntries++;
      } else {
        newEntries++;
      }
    }

    phase('entries');
    metadataUpdates = await WordMetadataSync(db).merge(valid, wordIdMap);
    phase('metadata');
    // ------------------------------------------------------------ events
    // One read of the existing ids instead of a `SELECT ... WHERE id = ?`
    // per incoming event: a 100 000-event import used to issue 100 000
    // single-row reads plus 100 000 single-row inserts. Only ids are held in
    // memory, so the footprint stays proportional to the log (a few MB) and
    // not to the full row payload.
    final Set<String> knownEventIds = await _existingEventIds();
    final Map<String, ReviewEvent> pendingEvents = <String, ReviewEvent>{};
    Future<void> flushPendingEvents() async {
      if (pendingEvents.isEmpty) return;
      final List<ReviewEvent> rows = pendingEvents.values.toList(
        growable: false,
      );
      pendingEvents.clear();
      await db.batch(
        (Batch batch) => batch.insertAll(
          db.reviewEvents,
          rows,
          mode: InsertMode.insertOrIgnore,
        ),
      );
    }

    for (final dynamic node in rawEvents) {
      if (node is! Map<String, dynamic>) {
        skipped++;
        continue;
      }
      final String? remoteWordId = node['wordId'] as String?;
      if (remoteWordId == null) {
        skipped++;
        continue;
      }
      final String? wordId = wordIdMap[remoteWordId];
      if (wordId == null) {
        // The event belongs to a word that is not part of this dataset and
        // does not exist locally either; nothing sensible to attach it to.
        skipped++;
        continue;
      }
      final ReviewEvent? incoming = _eventFromJson(node, wordId);
      if (incoming == null) {
        skipped++;
        continue;
      }
      // A repeated id inside the same dataset is resolved against the pending
      // batch, exactly like a duplicate against the database.
      final ReviewEvent? local =
          pendingEvents[incoming.id] ??
          (knownEventIds.contains(incoming.id)
              ? await (db.select(
                  db.reviewEvents,
                )..where((t) => t.id.equals(incoming.id))).getSingleOrNull()
              : null);
      if (local != null) {
        if (local.wordId != incoming.wordId ||
            local.causalOrder != incoming.causalOrder ||
            local.deviceId != incoming.deviceId ||
            local.answeredAt != incoming.answeredAt ||
            local.result != incoming.result ||
            local.type != incoming.type ||
            local.mode != incoming.mode ||
            local.algoVersion != incoming.algoVersion) {
          throw const BackupException('同一学习记录 ID 的内容冲突，未合并数据');
        }
        int rank(String source) => switch (source) {
          'authored' => 3,
          'legacy-state' => 2,
          _ => 1,
        };
        final localRank = rank(local.dayStartSource),
            remoteRank = rank(incoming.dayStartSource);
        if (localRank == 3 &&
            remoteRank == 3 &&
            local.dayStartUtc != incoming.dayStartUtc) {
          throw const BackupException('同一学习记录的作者时间锚点冲突');
        }
        if (remoteRank > localRank ||
            (remoteRank == localRank &&
                incoming.dayStartUtc != null &&
                (local.dayStartUtc == null ||
                    incoming.dayStartUtc! < local.dayStartUtc!))) {
          if (pendingEvents.containsKey(incoming.id)) {
            pendingEvents[incoming.id] = local.copyWith(
              dayStartUtc: Value<int?>(incoming.dayStartUtc),
              dayStartSource: incoming.dayStartSource,
              localDay: incoming.localDay,
            );
          } else {
            await (db.update(
              db.reviewEvents,
            )..where((t) => t.id.equals(local.id))).write(
              ReviewEventsCompanion(
                dayStartUtc: Value(incoming.dayStartUtc),
                dayStartSource: Value(incoming.dayStartSource),
                localDay: Value(incoming.localDay),
              ),
            );
          }
          touchedWords.add(wordId);
        }
        duplicateEvents++;
        continue;
      }
      pendingEvents[incoming.id] = incoming;
      knownEventIds.add(incoming.id);
      addedEvents++;
      touchedWords.add(wordId);
      if (pendingEvents.length >= 500) await flushPendingEvents();
    }
    await flushPendingEvents();

    phase('events');
    // Shared settings use a Lamport counter plus a stable source-device tie break.
    //
    // [forceSharedSettings] is the point-in-time-restore case: the user asked for
    // "the device as it was at this instant", so the snapshot's values win even
    // though its counter is lower than the current one. Leaving the version rule
    // in charge there would produce a mixture — words and events from the past,
    // daily targets from the present — which is not a restore at all.
    final Object? sharedSettings = valid['settings'];
    bool settingsApplied = false;
    if (applySharedSettings && sharedSettings is Map<String, dynamic>) {
      final rawVersion = sharedSettings['version'];
      final Map<String, Object?>? incomingVersion = rawVersion is Map
          ? Map<String, Object?>.from(rawVersion)
          : null;
      if (incomingVersion != null &&
          (incomingVersion['counter'] is! int ||
              (incomingVersion['counter'] as int) < 0 ||
              incomingVersion['deviceId'] is! String)) {
        throw const BackupException('共享设置版本无效');
      }
      final localVersion = await settings.sharedVersion();
      if (forceSharedSettings ||
          (incomingVersion != null &&
              SettingsRepository.compareVersions(
                    incomingVersion,
                    localVersion,
                  ) >
                  0) ||
          (originallyEmpty && (localVersion['counter'] as int) == 0)) {
        final current = await settings.load();
        await settings.save(
          dailyNewTarget: _positiveInt(
            sharedSettings['dailyNewTarget'],
            current.dailyNewTarget,
          ),
          dailyReviewLimit: _positiveInt(
            sharedSettings['dailyReviewLimit'],
            current.dailyReviewLimit,
          ),
          studyMode: StudyMode.fromCode(sharedSettings['studyMode'] as String?),
          sprintPlan: sharedSettings['sprintPlan'] is Map
              ? SprintPlan.fromJson({
                  ...Map<String, Object?>.from(
                    sharedSettings['sprintPlan'] as Map,
                  ),
                  'bookId':
                      bookIdMap[(sharedSettings['sprintPlan']
                          as Map)['bookId']] ??
                      (sharedSettings['sprintPlan'] as Map)['bookId'],
                })
              : null,
          // A legacy snapshot may predate the version field. Forcing values
          // without a version must not *lower* the counter (that would make the
          // next merge lose every setting); keep it monotonic instead.
          importedVersion:
              incomingVersion ??
              (forceSharedSettings
                  ? null
                  : <String, Object?>{'counter': 0, 'deviceId': ''}),
        );
        settingsApplied = true;
      }
    }

    // ---- rebuild derived state inside the transaction ------------------
    // Every state row is a pure function of the merged event log, so this is
    // deterministic and cannot be left half-applied: an interruption rolls
    // the whole transaction back. The batched entry point produces exactly
    // the same rows as the per-word one, one query per chunk instead of one
    // per word.
    await study.rebuildStatesForWords(touchedWords);
    phase('replay');
    if (applySharedSettings) {
      await DictionaryPackages.merge(
        db,
        valid['dictionaryPackages'],
        replace: forceSharedSettings,
      );
    }

    conflictSink?.addAll(conflictDetails);
    return MergeReport(
      metadataUpdates: metadataUpdates,
      addedEvents: addedEvents,
      duplicateEvents: duplicateEvents,
      newWords: newWords,
      updatedWords: updatedWords,
      deletedWords: deletedWords,
      newBooks: newBooks,
      updatedBooks: updatedBooks,
      newEntries: newEntries,
      removedEntries: removedEntries,
      rebuiltStates: touchedWords.length,
      skippedEntries: skipped,
      conflicts: conflicts,
      settingsKept: !settingsApplied,
      conflictDetails: conflictDetails,
    );
  }

  /// Phase-4 implementation, kept for the equivalence test: one row at a time,
  /// one version query per word. Any optimisation of the word merge must
  /// produce exactly the same database rows as this path.
  Future<_WordMergeResult> _mergeWordsPerRow(
    List<dynamic> rawWords,
    ContentSyncRepository content,
    Map<String, String> wordIdMap, {
    required List<String> Function(Map<String, dynamic> node) aliases,
    required Map<String, Object?> Function(
      Map<String, dynamic> raw,
      Map<String, Object?> normalized,
    )
    presentFields,
    required DateTime now,
    required List<FieldConflict> conflictDetails,
  }) async {
    int newWords = 0, updatedWords = 0, deletedWords = 0, conflicts = 0;
    for (final dynamic raw in rawWords) {
      final node = raw as Map<String, dynamic>;
      final incoming = _wordFromJson(node)!;
      final resolved = await content.resolve(
        'word',
        incoming.id,
        aliases(node),
      );
      final local = resolved == null
          ? await words.byNormalized(incoming.normalized, includeDeleted: true)
          : await words.byId(resolved);
      final id = local?.id ?? incoming.id;
      wordIdMap[incoming.id] = id;
      await content.remember('word', id, [incoming.id, ...aliases(node)]);
      if (local == null) {
        await db.into(db.words).insert(incoming);
        if (node['fieldVersions'] != null) {
          await content.saveVersions(
            'word',
            id,
            (node['fieldVersions'] as Map).map(
              (key, value) => MapEntry(
                key as String,
                Map<String, Object?>.from(value as Map),
              ),
            ),
          );
        }
        newWords++;
        continue;
      }
      final merged = await content.merge(
        'word',
        id,
        _wordToJson(local),
        presentFields(node, _wordToJson(incoming)),
      );
      if (merged.changed) {
        final row = Map<String, dynamic>.from(merged.row)
          ..['normalized'] = normalizeWordKey(merged.row['word'] as String);
        final updated = _wordFromJson(row)!
            .copyWith(id: id, createdAt: local.createdAt);
        final duplicate = await words.byNormalized(
          updated.normalized,
          includeDeleted: true,
        );
        if (duplicate != null && duplicate.id != id) {
          throw const BackupException('重命名与本机已有词条冲突，未合并任何数据');
        }
        await db.update(db.words).replace(updated);
        if (updated.deletedAt != null && local.deletedAt == null) {
          deletedWords++;
        } else {
          updatedWords++;
        }
      }
      if (merged.conflict) conflicts++;
    }
    return _WordMergeResult(
      newWords: newWords,
      updatedWords: updatedWords,
      deletedWords: deletedWords,
      conflicts: conflicts,
    );
  }

  /// Batched word merge (phase 5G).
  ///
  /// The per-row path issued 3–5 single-row queries per word (`resolve` twice,
  /// `byNormalized`, `remember` twice, `versions`) and one UPDATE each. Here the
  /// whole identity map, alias map and version map are read once, writes are
  /// batched, and the in-memory maps are kept in sync so a rename/revival later
  /// in the same dataset still resolves against what this transaction already
  /// wrote.
  Future<_WordMergeResult> _mergeWordsBatched(
    List<dynamic> rawWords,
    ContentSyncRepository content,
    Map<String, String> wordIdMap, {
    required List<String> Function(Map<String, dynamic> node) aliases,
    required Map<String, Object?> Function(
      Map<String, dynamic> raw,
      Map<String, Object?> normalized,
    )
    presentFields,
    required DateTime now,
    required List<FieldConflict> conflictDetails,
  }) async {
    if (rawWords.isEmpty) return const _WordMergeResult();

    final Map<String, Word> byId = <String, Word>{};
    final Map<String, Word> byNormalized = <String, Word>{};
    for (final Word word in await db.select(db.words).get()) {
      byId[word.id] = word;
      byNormalized[word.normalized] = word;
    }
    final Map<String, String> aliasToLocal = <String, String>{};
    for (final SyncAliasRow alias in await (db.select(
      db.syncAliases,
    )..where((t) => t.kind.equals('word'))).get()) {
      aliasToLocal[alias.aliasId] = alias.localId;
    }
    final Map<String, Map<String, Map<String, Object?>>> stampsByWord =
        <String, Map<String, Map<String, Object?>>>{};
    for (final ContentVersionRow row in await (db.select(
      db.contentVersions,
    )..where((t) => t.kind.equals('word'))).get()) {
      (stampsByWord[row.entityId] ??=
          <String, Map<String, Object?>>{})[row.field] = <String, Object?>{
        'version': row.version,
        'updatedAt': row.updatedAt,
        'deviceId': row.deviceId,
      };
    }

    int newWords = 0, updatedWords = 0, deletedWords = 0, conflicts = 0;
    final List<Word> pendingInserts = <Word>[];
    final List<Word> pendingUpdates = <Word>[];
    final List<({String localId, Iterable<String> aliases})> pendingAliases =
        <({String localId, Iterable<String> aliases})>[];
    final Map<String, Map<String, Map<String, Object?>>> pendingStamps =
        <String, Map<String, Map<String, Object?>>>{};

    Future<void> flush() async {
      if (pendingInserts.isNotEmpty) {
        await db.batch(
          (Batch batch) => batch.insertAll(db.words, pendingInserts.toList()),
        );
        pendingInserts.clear();
      }
      if (pendingUpdates.isNotEmpty) {
        // `replace` instead of a batch update: only `replace` writes a NULL
        // tombstone (`toColumns(false)`), and a revival depends on that.
        for (final Word row in pendingUpdates) {
          await db.update(db.words).replace(row);
        }
        pendingUpdates.clear();
      }
      if (pendingStamps.isNotEmpty) {
        await content.saveVersionsBulk('word', pendingStamps);
        pendingStamps.clear();
      }
      if (pendingAliases.isNotEmpty) {
        await content.rememberAll('word', pendingAliases, aliasToLocal);
        pendingAliases.clear();
      }
    }

    for (final dynamic raw in rawWords) {
      final node = raw as Map<String, dynamic>;
      final incoming = _wordFromJson(node)!;
      final List<String> candidates = <String>[incoming.id, ...aliases(node)];
      final Set<String> found = <String>{
        for (final String candidate in candidates)
          if (byId.containsKey(candidate)) candidate,
        for (final String candidate in candidates)
          if (aliasToLocal[candidate] != null &&
              byId.containsKey(aliasToLocal[candidate]))
            aliasToLocal[candidate]!,
      };
      if (found.length > 1) {
        throw StateError('远程身份指向多个本机词条，请先处理重命名冲突');
      }
      Word? local = found.isEmpty ? null : byId[found.first];
      local ??= byNormalized[incoming.normalized];
      final String id = local?.id ?? incoming.id;
      wordIdMap[incoming.id] = id;
      pendingAliases.add((
        localId: id,
        aliases: <String>[incoming.id, ...aliases(node)],
      ));
      for (final String candidate in candidates) {
        final String? mapped = aliasToLocal[candidate];
        if (mapped != null && mapped != id) {
          throw StateError('词条身份冲突，已停止合并');
        }
      }

      if (local == null) {
        byId[id] = incoming;
        byNormalized[incoming.normalized] = incoming;
        pendingInserts.add(incoming);
        if (node['fieldVersions'] != null) {
          pendingStamps[id] = <String, Map<String, Object?>>{
            for (final MapEntry<dynamic, dynamic> entry
                in (node['fieldVersions'] as Map).entries)
              entry.key as String: Map<String, Object?>.from(
                entry.value as Map,
              ),
          };
        }
        newWords++;
        if (pendingInserts.length >= 400) await flush();
        continue;
      }

      final merged = await content.mergeWithStamps(
        'word',
        id,
        _wordToJson(local),
        presentFields(node, _wordToJson(incoming)),
        stampsByWord[id] ?? <String, Map<String, Object?>>{},
        persistStamps: false,
      );
      conflicts += merged.conflicts.length;
      conflictDetails.addAll(merged.conflicts);
      // `merged.changed` already includes stamp-only changes, so an untouched
      // row writes nothing — otherwise a device that merely *received* a word
      // would invent version rows the creator never had, and the two content
      // hashes would never converge.
      if (merged.changed) {
        pendingStamps[id] = merged.stamps;
        final row = Map<String, dynamic>.from(merged.row)
          ..['normalized'] = normalizeWordKey(merged.row['word'] as String);
        final updated = _wordFromJson(row)!
            .copyWith(id: id, createdAt: local.createdAt);
        final Word? duplicate = byNormalized[updated.normalized];
        if (duplicate != null && duplicate.id != id) {
          throw const BackupException('重命名与本机已有词条冲突，未合并任何数据');
        }
        if (updated.normalized != local.normalized) {
          byNormalized.remove(local.normalized);
        }
        byNormalized[updated.normalized] = updated;
        byId[id] = updated;
        if (merged.changed) {
          pendingUpdates.add(updated);
          if (updated.deletedAt != null && local.deletedAt == null) {
            deletedWords++;
          } else {
            updatedWords++;
          }
        }
        stampsByWord[id] = merged.stamps;
        if (pendingUpdates.length >= 400) await flush();
      }
    }
    await flush();
    return _WordMergeResult(
      newWords: newWords,
      updatedWords: updatedWords,
      deletedWords: deletedWords,
      conflicts: conflicts,
    );
  }

  Future<Set<String>> _existingEventIds() async {
    final List<QueryRow> rows = await db
        .customSelect(
          'SELECT id FROM review_events',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.reviewEvents,
          },
        )
        .get();
    return <String>{for (final QueryRow row in rows) row.read<String>('id')};
  }

  Future<int> _countWords() async {
    final QueryRow row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM words WHERE deleted_at IS NULL',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{db.words},
        )
        .getSingle();
    return row.read<int>('c');
  }

  Future<int> _countEvents() async {
    final QueryRow row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM review_events',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.reviewEvents,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  _Version _versionOf(int revision, int updatedAt) =>
      _Version(revision, updatedAt);

  int _positiveInt(Object? value, int fallback) {
    final int? parsed = value is int ? value : int.tryParse('${value ?? ''}');
    if (parsed == null || parsed < 0) return fallback;
    return parsed;
  }

  // ------------------------------------------------------------ (de)serialise

  Map<String, Object?> _wordToJson(Word w) => <String, Object?>{
    'id': w.id,
    'word': w.word,
    'normalized': w.normalized,
    'phonetic': w.phonetic,
    'partOfSpeech': w.partOfSpeech,
    'translation': w.translation,
    'definition': w.definition,
    'example': w.example,
    'phrase': w.phrase,
    'note': w.note,
    'source': w.source,
    'examTags': w.examTags,
    'bncRank': w.bncRank,
    'frqRank': w.frqRank,
    'customized': w.customized,
    'revision': w.revision,
    'createdAt': _iso(w.createdAt),
    'updatedAt': _iso(w.updatedAt),
    'deletedAt': w.deletedAt == null ? null : _iso(w.deletedAt!),
  };

  Word? _wordFromJson(Map<String, dynamic> node) {
    final String? word = node['word'] as String?;
    if (word == null || word.trim().isEmpty) return null;
    final String normalized =
        (node['normalized'] as String?) ?? normalizeWordKey(word);
    return Word(
      id: (node['id'] as String?) ?? _uuid.v4(),
      word: word,
      normalized: normalized,
      phonetic: normalizeDictionaryText(_str(node['phonetic'])),
      partOfSpeech: normalizeDictionaryText(_str(node['partOfSpeech'])),
      translation: normalizeDictionaryText(_str(node['translation'])),
      definition: normalizeDictionaryText(_str(node['definition'])),
      example: normalizeDictionaryText(_str(node['example'])),
      phrase: normalizeDictionaryText(_str(node['phrase'])),
      note: _str(node['note']),
      source: _str(node['source'], fallback: 'import'),
      examTags: _str(node['examTags']),
      bncRank: _int(node['bncRank']),
      frqRank: _int(node['frqRank']),
      customized: node['customized'] == true,
      revision: _int(node['revision'], fallback: 1),
      createdAt: _parseTime(node['createdAt'])?.millisecondsSinceEpoch ?? 0,
      updatedAt: _parseTime(node['updatedAt'])?.millisecondsSinceEpoch ?? 0,
      deletedAt: _parseTime(node['deletedAt'])?.millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> _bookToJson(WordBook b) => <String, Object?>{
    'id': b.id,
    'name': b.name,
    'description': b.description,
    'sourceType': b.sourceType,
    'sourceUrl': b.sourceUrl,
    'revision': b.revision,
    'createdAt': _iso(b.createdAt),
    'updatedAt': _iso(b.updatedAt),
    'deletedAt': b.deletedAt == null ? null : _iso(b.deletedAt!),
  };

  WordBook? _bookFromJson(Map<String, dynamic> node) {
    final String? id = node['id'] as String?;
    final String? name = node['name'] as String?;
    if (id == null || name == null) return null;
    final int updatedAt =
        _parseTime(node['updatedAt'])?.millisecondsSinceEpoch ?? 0;
    return WordBook(
      id: id,
      name: name,
      description: _str(node['description']),
      sourceType: _str(node['sourceType'], fallback: 'import'),
      sourceUrl: _str(node['sourceUrl']),
      revision: _int(node['revision'], fallback: 1),
      createdAt:
          _parseTime(node['createdAt'])?.millisecondsSinceEpoch ?? updatedAt,
      updatedAt: updatedAt,
      deletedAt: _parseTime(node['deletedAt'])?.millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> _entryToJson(WordBookEntry e) => <String, Object?>{
    'wordBookId': e.wordBookId,
    'wordId': e.wordId,
    'addedAt': _iso(e.addedAt),
    'version': e.version,
    'updatedAt': _iso(e.updatedAt == 0 ? e.addedAt : e.updatedAt),
    'deletedAt': e.deletedAt == null ? null : _iso(e.deletedAt!),
  };

  WordBookEntry? _entryFromJson(
    Map<String, dynamic> node,
    String bookId,
    String wordId,
  ) {
    final int addedAt =
        _parseTime(node['addedAt'])?.millisecondsSinceEpoch ?? 0;
    final int updatedAt =
        _parseTime(node['updatedAt'])?.millisecondsSinceEpoch ??
        (_int(node['version']) > 0 ? addedAt : addedAt);
    return WordBookEntry(
      wordBookId: bookId,
      wordId: wordId,
      addedAt: addedAt,
      version: _int(node['version'], fallback: 1),
      updatedAt: updatedAt,
      deletedAt: _parseTime(node['deletedAt'])?.millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> _eventToJson(ReviewEvent e) => <String, Object?>{
    'id': e.id,
    'wordId': e.wordId,
    'deviceId': e.deviceId,
    'answeredAt': _iso(e.answeredAt),
    'localDay': e.localDay,
    'result': e.result,
    'type': e.type,
    'stageBefore': e.stageBefore,
    'intervalDaysAfter': e.intervalDaysAfter,
    'algoVersion': e.algoVersion,
    'mode': e.mode,
    'causalOrder': e.causalOrder,
    'dayStartSource': e.dayStartSource,
    'dayStartUtc': _iso(
      e.dayStartUtc ??
          DateTime.fromMillisecondsSinceEpoch(
                e.answeredAt,
                isUtc: true,
              ).millisecondsSinceEpoch ~/
              86400000 *
              86400000,
    ),
  };

  static ReviewEvent? _eventFromJson(Map<String, dynamic> node, String wordId) {
    final String? id = node['id'] as String?;
    final DateTime? answeredAt = _parseTime(node['answeredAt']);
    if (id == null || answeredAt == null) return null;
    final Object? result = node['result'];
    final int resultCode = result is int
        ? result
        : int.tryParse('$result') ?? 0;
    if (resultCode < 0 || resultCode > 2) return null;
    final String type = (node['type'] as String?) == 'review'
        ? 'review'
        : 'study';
    final DateTime local = answeredAt.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return ReviewEvent(
      id: id,
      wordId: wordId,
      deviceId: _str(node['deviceId'], fallback: 'unknown'),
      answeredAt: answeredAt.millisecondsSinceEpoch,
      localDay: _str(node['localDay']).isEmpty
          ? '${local.year.toString().padLeft(4, '0')}-'
                '${two(local.month)}-${two(local.day)}'
          : _str(node['localDay']),
      result: resultCode,
      type: type,
      stageBefore: _int(node['stageBefore']),
      intervalDaysAfter: _int(node['intervalDaysAfter']),
      algoVersion: _int(node['algoVersion'], fallback: 1),
      mode: _str(node['mode'], fallback: 'normal'),
      causalOrder: _int(node['causalOrder']),
      dayStartSource: _str(
        node['dayStartSource'],
        fallback: node['dayStartUtc'] == null ? 'legacy-utc' : 'authored',
      ),
      dayStartUtc:
          _parseTime(node['dayStartUtc'])?.millisecondsSinceEpoch ??
          DateTime.utc(
            answeredAt.year,
            answeredAt.month,
            answeredAt.day,
          ).millisecondsSinceEpoch,
    );
  }

  String _iso(int millis) => DateTime.fromMillisecondsSinceEpoch(
    millis,
    isUtc: true,
  ).toIso8601String();

  static DateTime? _parseTime(Object? value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  static String _str(Object? value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// Counters from the batched (or per-row) word merge.
class _WordMergeResult {
  const _WordMergeResult({
    this.newWords = 0,
    this.updatedWords = 0,
    this.deletedWords = 0,
    this.conflicts = 0,
  });

  final int newWords;
  final int updatedWords;
  final int deletedWords;
  final int conflicts;
}

/// Total order over (revision, updatedAt) with a deterministic tie-break, so
/// clock skew between devices cannot produce different results on each device.
class _Version implements Comparable<_Version> {
  const _Version(this.revision, this.updatedAt);

  final int revision;
  final int updatedAt;

  @override
  int compareTo(_Version other) {
    if (revision != other.revision) return revision.compareTo(other.revision);
    return updatedAt.compareTo(other.updatedAt);
  }

  bool operator >(_Version other) => compareTo(other) > 0;
  bool operator >=(_Version other) => compareTo(other) >= 0;
  bool operator <(_Version other) => compareTo(other) < 0;
  bool operator <=(_Version other) => compareTo(other) <= 0;
}

/// Large JSON work runs away from the UI isolate. Only the snapshot travels.
Future<String> encodeDatasetJson(
  Map<String, Object?> dataset, {
  bool pretty = false,
}) => Isolate.run(
  () => pretty
      ? const JsonEncoder.withIndent('  ').convert(dataset)
      : jsonEncode(dataset),
);

Future<Object?> decodeDatasetJson(String raw) =>
    Isolate.run(() => jsonDecode(raw));

Future<Map<String, Object?>> validateDatasetInBackground(
  Map<String, Object?> dataset,
) => Isolate.run(() => BackupService._validateDatasetCore(dataset));

Future<Map<String, Object?>> decodeValidatedDatasetJson(String raw) =>
    Isolate.run(() {
      final Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        throw const BackupException('不是合法的 JSON 文件');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const BackupException('备份文件根节点必须是对象');
      }
      return BackupService._validateDatasetCore(decoded);
    });
