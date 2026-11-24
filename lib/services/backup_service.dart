import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/models/enums.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/study_repository.dart';
import '../core/repositories/word_repository.dart';
import '../core/text/dictionary_text.dart';
import 'study_scheduler.dart';

const Uuid _uuid = Uuid();

/// Backup / sync document format.
///
/// * v1 — phase 1: words, books, entries, events, settings (no tombstones).
/// * v2 — phase 2: stable `datasetId`, per-row `revision`/`version`/`updatedAt`,
///   entry tombstones (`deletedAt`), review-event `mode`, shared/device
///   settings split, and a stable `contentHash` used to skip no-op uploads.
const int backupSchemaVersion = 3;
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

  bool get hasChanges =>
      addedEvents > 0 ||
      newWords > 0 ||
      updatedWords > 0 ||
      deletedWords > 0 ||
      newBooks > 0 ||
      updatedBooks > 0 ||
      newEntries > 0 ||
      removedEntries > 0 ||
      rebuiltStates > 0;

  String get summary {
    final List<String> parts = <String>[
      '新增学习记录 $addedEvents 条',
      if (duplicateEvents > 0) '重复记录 $duplicateEvents 条已忽略',
      if (newWords > 0) '新增词条 $newWords 个',
      if (updatedWords > 0) '更新词条 $updatedWords 个',
      if (deletedWords > 0) '同步删除 $deletedWords 个',
      if (newBooks > 0) '新增词书 $newBooks 个',
      if (newEntries > 0) '新增词书关联 $newEntries 条',
      if (removedEntries > 0) '同步移出词书 $removedEntries 条',
      if (rebuiltStates > 0) '重算学习状态 $rebuiltStates 个',
      if (conflicts > 0) '内容冲突 $conflicts 个（按更新时间保留较新版本）',
    ];
    return parts.join('，');
  }
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
    final StudySettingsRow current = await settings.load();

    return <String, Object?>{
      'schemaVersion': backupSchemaVersion,
      'kind': backupKind,
      'datasetId': datasetId,
      'deviceId': deviceId,
      'exportedAt': now.toUtc().toIso8601String(),
      'appVersion': '1.1.0',
      'words': wordRows.map(_wordToJson).toList(growable: false),
      'wordBooks': bookRows.map(_bookToJson).toList(growable: false),
      'entries': entryRows.map(_entryToJson).toList(growable: false),
      'reviewEvents': eventRows.map(_eventToJson).toList(growable: false),
      // Only *shared* settings travel. Theme, accent, TTS and the active book
      // describe this device and must not jump between devices.
      'settings': <String, Object?>{
        'dailyNewTarget': current.dailyNewTarget,
        'dailyReviewLimit': current.dailyReviewLimit,
        'studyMode': current.studyMode,
        'version': await settings.sharedVersion(),
      },
    };
  });

  Future<String> exportToJson({
    required DateTime now,
    bool pretty = true,
  }) async {
    final Map<String, Object?> dataset = await buildDataset(now: now);
    return encodeDatasetJson(dataset, pretty: pretty);
  }

  Future<File> writeBackupFile({
    required Directory directory,
    required DateTime now,
  }) async {
    final String json = await exportToJson(now: now);
    String two(int v) => v.toString().padLeft(2, '0');
    final String stamp =
        '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final File file = File('${directory.path}/materialword-backup-$stamp.json');
    await file.writeAsString(json, flush: true);
    return file;
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
      if (!bookIds.add(book['id'] as String)) invalid('wordBooks:重复身份');
      for (final field in ['description', 'sourceType', 'sourceUrl']) {
        text(book, field);
      }
      for (final field in ['createdAt', 'updatedAt', 'deletedAt']) {
        timestamp(book, field);
      }
      number(book, 'revision');
    }
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
      bookKeys[b['id'] as String] = b['name'] as String;
    }
    for (final w in words) {
      w.remove('id');
      w.remove('createdAt');
    }
    for (final b in books) {
      b.remove('id');
      b.remove('createdAt');
    }
    final entries = rows('entries');
    final events = rows('reviewEvents');
    for (final e in [...entries, ...events]) {
      e['wordId'] = wordKeys[e['wordId']] ?? e['wordId'];
      if (e.containsKey('wordBookId')) {
        e['wordBookId'] = bookKeys[e['wordBookId']] ?? e['wordBookId'];
      }
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

    final canonical = canonicalize(<String, Object?>{
      'schemaVersion': dataset['schemaVersion'],
      'words': words,
      'wordBooks': books,
      'entries': entries,
      'reviewEvents': events,
      'settings': dataset['settings'] ?? const <String, Object?>{},
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
  Future<MergeReport> mergeDataset(
    Map<String, Object?> dataset, {
    required DateTime now,
  }) async {
    final Map<String, Object?> valid = await validateDatasetAsync(dataset);
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
    int skipped = 0;
    final Set<String> touchedWords = <String>{};

    await db.transaction(() async {
      final bool originallyEmpty =
          await _countWords() == 0 && await _countEvents() == 0;
      // ------------------------------------------------------------- words
      // remote id → canonical local id. This is the fix for the phase-1 bug
      // where entries/events kept pointing at the remote UUID and were dropped.
      final Map<String, String> wordIdMap = <String, String>{};
      final Map<String, String> bookIdMap = <String, String>{};

      for (final dynamic node in rawWords) {
        if (node is! Map<String, dynamic>) {
          skipped++;
          continue;
        }
        final Word? incoming = _wordFromJson(node);
        if (incoming == null) {
          skipped++;
          continue;
        }
        final Word? local = await words.byNormalized(
          incoming.normalized,
          includeDeleted: true,
        );
        if (local == null) {
          String id = incoming.id;
          if (await words.byId(id) != null) {
            // A different word already owns this UUID on this device.
            id = _uuid.v4();
          }
          await db.into(db.words).insert(incoming.copyWith(id: id));
          wordIdMap[incoming.id] = id;
          newWords++;
          continue;
        }

        wordIdMap[incoming.id] = local.id;
        final ({bool apply, bool conflict, bool deletion}) verdict = _mergeWord(
          local,
          incoming,
        );
        if (verdict.apply) {
          await db.update(db.words).replace(_applyWord(local, incoming));
          if (verdict.deletion) {
            deletedWords++;
          } else {
            updatedWords++;
          }
        }
        if (verdict.conflict) conflicts++;
      }

      // ------------------------------------------------------------- books
      for (final dynamic node in rawBooks) {
        if (node is! Map<String, dynamic>) {
          skipped++;
          continue;
        }
        final WordBook? incoming = _bookFromJson(node);
        if (incoming == null) {
          skipped++;
          continue;
        }
        final WordBook? local = await (db.select(
          db.wordBooks,
        )..where((t) => t.id.equals(incoming.id))).getSingleOrNull();
        if (local != null) {
          bookIdMap[incoming.id] = local.id;
          if (_versionOf(incoming.revision, incoming.updatedAt) >
              _versionOf(local.revision, local.updatedAt)) {
            await db
                .update(db.wordBooks)
                .replace(
                  local.copyWith(
                    name: incoming.name,
                    description: incoming.description,
                    sourceType: incoming.sourceType,
                    sourceUrl: incoming.sourceUrl,
                    revision: incoming.revision,
                    updatedAt: incoming.updatedAt,
                    deletedAt: Value<int?>(incoming.deletedAt),
                  ),
                );
            updatedBooks++;
          }
          continue;
        }

        // Two devices independently created a book with the same name: treat
        // them as the same book instead of showing a duplicate after sync.
        if (incoming.deletedAt == null) {
          final WordBook? sameName =
              await (db.select(db.wordBooks)..where(
                    (t) => t.name.equals(incoming.name) & t.deletedAt.isNull(),
                  ))
                  .getSingleOrNull();
          if (sameName != null) {
            bookIdMap[incoming.id] = sameName.id;
            if (_versionOf(incoming.revision, incoming.updatedAt) >
                _versionOf(sameName.revision, sameName.updatedAt)) {
              await db
                  .update(db.wordBooks)
                  .replace(
                    incoming.copyWith(
                      id: sameName.id,
                      createdAt: sameName.createdAt,
                    ),
                  );
              updatedBooks++;
            }
            continue;
          }
        }
        await db
            .into(db.wordBooks)
            .insert(incoming, mode: InsertMode.insertOrIgnore);
        bookIdMap[incoming.id] = incoming.id;
        if (incoming.deletedAt == null) newBooks++;
      }

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

      // ------------------------------------------------------------ events
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
        final ReviewEvent? local = await (db.select(
          db.reviewEvents,
        )..where((t) => t.id.equals(incoming.id))).getSingleOrNull();
        if (local != null) {
          if (local.wordId != incoming.wordId ||
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
            await (db.update(
              db.reviewEvents,
            )..where((t) => t.id.equals(local.id))).write(
              ReviewEventsCompanion(
                dayStartUtc: Value(incoming.dayStartUtc),
                dayStartSource: Value(incoming.dayStartSource),
                localDay: Value(incoming.localDay),
              ),
            );
            touchedWords.add(wordId);
          }
          duplicateEvents++;
          continue;
        }
        await db
            .into(db.reviewEvents)
            .insert(incoming, mode: InsertMode.insertOrIgnore);
        addedEvents++;
        touchedWords.add(wordId);
      }

      // Shared settings use a Lamport counter plus a stable source-device tie break.
      final Object? sharedSettings = valid['settings'];
      if (sharedSettings is Map<String, dynamic>) {
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
        if ((incomingVersion != null &&
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
            studyMode: StudyMode.fromCode(
              sharedSettings['studyMode'] as String?,
            ),
            importedVersion:
                incomingVersion ??
                <String, Object?>{'counter': 0, 'deviceId': ''},
          );
        }
      }

      // ---- rebuild derived state inside the transaction ------------------
      // Every state row is a pure function of the merged event log, so this is
      // deterministic and cannot be left half-applied: an interruption rolls
      // the whole transaction back.
      for (final String wordId in touchedWords) {
        await study.rebuildStateFromEvents(wordId);
      }
    });

    return MergeReport(
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
      settingsKept: true,
    );
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

  // ----------------------------------------------------------- merge rules

  /// Merge rules for one word, in order of precedence:
  ///  1. a deletion beats an *older* edit, a newer edit revives a deletion;
  ///  2. identical content is a no-op;
  ///  3. otherwise the higher (revision, updatedAt) wins;
  ///  4. when both sides edited the *same* word (both `customized`) the change
  ///     is also reported as a conflict so the user is told that a merge
  ///     happened, instead of silently losing one side.
  ///
  /// The local row always keeps its id, so no book link or review event can be
  /// orphaned by a content merge.
  ({bool apply, bool conflict, bool deletion}) _mergeWord(
    Word local,
    Word incoming,
  ) {
    final bool localDeleted = local.deletedAt != null;
    final bool remoteDeleted = incoming.deletedAt != null;

    if (localDeleted || remoteDeleted) {
      final _Version localVersion = _versionOf(
        local.revision,
        local.deletedAt ?? local.updatedAt,
      );
      final _Version remoteVersion = _versionOf(
        incoming.revision,
        incoming.deletedAt ?? incoming.updatedAt,
      );
      if (localDeleted && !remoteDeleted) {
        // Revived on the other device: only if that edit is newer.
        return (
          apply: remoteVersion > localVersion,
          conflict: remoteVersion > localVersion,
          deletion: false,
        );
      }
      if (remoteDeleted && !localDeleted) {
        return (
          apply: remoteVersion >= localVersion,
          conflict: false,
          deletion: remoteVersion >= localVersion,
        );
      }
      return (
        apply: remoteVersion > localVersion,
        conflict: false,
        deletion: false,
      );
    }

    if (_sameWordContent(local, incoming)) {
      return (
        apply:
            _versionOf(incoming.revision, incoming.updatedAt) >
            _versionOf(local.revision, local.updatedAt),
        conflict: false,
        deletion: false,
      );
    }

    final _Version localVersion = _versionOf(local.revision, local.updatedAt);
    final _Version remoteVersion = _versionOf(
      incoming.revision,
      incoming.updatedAt,
    );
    final bool bothEdited = local.customized && incoming.customized;
    if (remoteVersion > localVersion ||
        (remoteVersion.compareTo(localVersion) == 0 &&
            _wordTieKey(incoming).compareTo(_wordTieKey(local)) > 0)) {
      return (apply: true, conflict: bothEdited, deletion: false);
    }
    return (apply: false, conflict: bothEdited, deletion: false);
  }

  String _wordTieKey(Word word) {
    final json = _wordToJson(word)
      ..remove('id')
      ..remove('createdAt');
    return jsonEncode(json);
  }

  bool _sameWordContent(Word a, Word b) =>
      a.word == b.word &&
      a.phonetic == b.phonetic &&
      a.partOfSpeech == b.partOfSpeech &&
      sameDictionaryText(a.translation, b.translation) &&
      sameDictionaryText(a.definition, b.definition) &&
      sameDictionaryText(a.example, b.example) &&
      sameDictionaryText(a.phrase, b.phrase) &&
      a.note == b.note &&
      a.examTags == b.examTags &&
      a.source == b.source &&
      a.bncRank == b.bncRank &&
      a.frqRank == b.frqRank;

  Word _applyWord(Word local, Word incoming) => local.copyWith(
    word: incoming.word,
    phonetic: normalizeDictionaryText(incoming.phonetic),
    partOfSpeech: normalizeDictionaryText(incoming.partOfSpeech),
    translation: normalizeDictionaryText(incoming.translation),
    definition: normalizeDictionaryText(incoming.definition),
    example: normalizeDictionaryText(incoming.example),
    phrase: normalizeDictionaryText(incoming.phrase),
    // Notes are user text: stored exactly as received.
    note: incoming.note,
    source: incoming.source,
    examTags: incoming.examTags,
    bncRank: incoming.bncRank,
    frqRank: incoming.frqRank,
    customized: local.customized || incoming.customized,
    revision: incoming.revision,
    updatedAt: incoming.updatedAt,
    deletedAt: Value<int?>(incoming.deletedAt),
  );

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

  ReviewEvent? _eventFromJson(Map<String, dynamic> node, String wordId) {
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

  String _str(Object? value, {String fallback = ''}) =>
      value is String ? value : fallback;

  int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
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
