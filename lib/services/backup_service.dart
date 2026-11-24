import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/study_repository.dart';
import '../core/repositories/word_repository.dart';

const Uuid _uuid = Uuid();
const int backupSchemaVersion = 1;
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
    this.rebuiltStates = 0,
    this.skippedEntries = 0,
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
  final int rebuiltStates;
  final int skippedEntries;
  final bool settingsKept;

  String get summary {
    final List<String> parts = <String>[
      '新增学习记录 $addedEvents 条',
      if (duplicateEvents > 0) '重复记录 $duplicateEvents 条已忽略',
      if (newWords > 0) '新增词条 $newWords 个',
      if (updatedWords > 0) '更新词条 $updatedWords 个',
      if (deletedWords > 0) '同步删除 $deletedWords 个',
      if (newBooks > 0) '新增词书 $newBooks 个',
      if (newEntries > 0) '新增词书关联 $newEntries 条',
      if (rebuiltStates > 0) '重算学习状态 $rebuiltStates 个',
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
///  * review events are immutable and de-duplicated by id, which makes repeated
///    imports idempotent;
///  * word content resolves conflicts by (revision, updatedAt);
///  * learning state is *recomputed* from the merged event log;
///  * a failed import aborts the transaction and leaves data untouched.
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

  Future<Map<String, Object?>> buildDataset({
    required DateTime now,
    bool includeEvents = true,
  }) async {
    final String deviceId = await settings.deviceId();
    final List<Word> wordRows =
        await (db.select(db.words)..orderBy(<OrderClauseGenerator<$WordsTable>>[
              (t) => OrderingTerm(expression: t.normalized),
            ]))
            .get();
    final List<WordBook> bookRows =
        await (db.select(db.wordBooks)
              ..orderBy(<OrderClauseGenerator<$WordBooksTable>>[
                (t) => OrderingTerm(expression: t.createdAt),
              ]))
            .get();
    final List<WordBookEntry> entryRows = await db
        .select(db.wordBookEntries)
        .get();
    final List<ReviewEvent> eventRows = includeEvents
        ? await (db.select(db.reviewEvents)
                ..orderBy(<OrderClauseGenerator<$ReviewEventsTable>>[
                  (t) => OrderingTerm(expression: t.answeredAt),
                ]))
              .get()
        : const <ReviewEvent>[];
    final StudySettingsRow current = await settings.load();

    return <String, Object?>{
      'schemaVersion': backupSchemaVersion,
      'kind': backupKind,
      'exportedAt': now.toUtc().toIso8601String(),
      'datasetId': _uuid.v4(),
      'deviceId': deviceId,
      'appVersion': '1.0.0',
      'words': wordRows.map(_wordToJson).toList(growable: false),
      'wordBooks': bookRows.map(_bookToJson).toList(growable: false),
      'entries': entryRows
          .map(
            (WordBookEntry e) => <String, Object?>{
              'wordBookId': e.wordBookId,
              'wordId': e.wordId,
              'addedAt': _iso(e.addedAt),
            },
          )
          .toList(growable: false),
      'reviewEvents': eventRows.map(_eventToJson).toList(growable: false),
      'settings': <String, Object?>{
        'dailyNewTarget': current.dailyNewTarget,
        'dailyReviewLimit': current.dailyReviewLimit,
        'currentWordBookId': current.currentWordBookId,
        'studyMode': current.studyMode,
        'themeMode': current.themeMode,
      },
    };
  }

  Future<String> exportToJson({
    required DateTime now,
    bool pretty = true,
  }) async {
    final Map<String, Object?> dataset = await buildDataset(now: now);
    return const JsonEncoder.withIndent('  ').convert(dataset);
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
    return decodeDataset(raw);
  }

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
    final Object? version = decoded['schemaVersion'];
    if (version is! int) {
      throw const BackupException('缺少 schemaVersion');
    }
    if (version > backupSchemaVersion) {
      throw BackupException('备份文件版本过新（$version），请升级应用');
    }
    final Object? kind = decoded['kind'];
    if (kind != null && kind != backupKind) {
      throw const BackupException('不是 MaterialWord 备份文件');
    }
    for (final String field in <String>[
      'words',
      'wordBooks',
      'entries',
      'reviewEvents',
    ]) {
      if (decoded[field] != null && decoded[field] is! List<dynamic>) {
        throw BackupException('字段 $field 必须是数组');
      }
    }
    return decoded;
  }

  Future<MergeReport> importFromFile(String path) async {
    final Map<String, Object?> dataset = await readDataset(path);
    return mergeDataset(dataset, now: DateTime.now());
  }

  /// Merges [dataset] into the local database in a single transaction.
  Future<MergeReport> mergeDataset(
    Map<String, Object?> dataset, {
    required DateTime now,
  }) async {
    final List<dynamic> rawWords =
        (dataset['words'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawBooks =
        (dataset['wordBooks'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawEntries =
        (dataset['entries'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawEvents =
        (dataset['reviewEvents'] as List<dynamic>?) ?? const <dynamic>[];

    int addedEvents = 0;
    int duplicateEvents = 0;
    int newWords = 0;
    int updatedWords = 0;
    int deletedWords = 0;
    int newBooks = 0;
    int updatedBooks = 0;
    int newEntries = 0;
    int skipped = 0;
    final Set<String> touchedWords = <String>{};

    await db.transaction(() async {
      // ---- words
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
          final Word? idClash = await words.byId(id);
          if (idClash != null) id = _uuid.v4();
          await db.into(db.words).insert(incoming.copyWith(id: id));
          newWords++;
          continue;
        }
        final bool incomingNewer =
            incoming.revision > local.revision ||
            (incoming.revision == local.revision &&
                incoming.updatedAt > local.updatedAt);
        if (!incomingNewer) continue;
        final Word merged = local.copyWith(
          word: incoming.word,
          phonetic: incoming.phonetic,
          partOfSpeech: incoming.partOfSpeech,
          translation: incoming.translation,
          definition: incoming.definition,
          example: incoming.example,
          phrase: incoming.phrase,
          note: incoming.note,
          source: incoming.source,
          examTags: incoming.examTags,
          bncRank: incoming.bncRank,
          frqRank: incoming.frqRank,
          customized: incoming.customized,
          revision: incoming.revision,
          updatedAt: incoming.updatedAt,
          deletedAt: Value<int?>(incoming.deletedAt),
        );
        await db.update(db.words).replace(merged);
        if (incoming.deletedAt != null && local.deletedAt == null) {
          deletedWords++;
        } else {
          updatedWords++;
        }
      }

      // ---- books
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
        if (local == null) {
          await db.into(db.wordBooks).insert(incoming);
          newBooks++;
          continue;
        }
        if (incoming.updatedAt > local.updatedAt) {
          await db.update(db.wordBooks).replace(incoming);
          updatedBooks++;
        }
      }

      // ---- entries (only when both sides exist)
      for (final dynamic node in rawEntries) {
        if (node is! Map<String, dynamic>) {
          skipped++;
          continue;
        }
        final String? bookId = node['wordBookId'] as String?;
        final String? wordId = node['wordId'] as String?;
        if (bookId == null || wordId == null) {
          skipped++;
          continue;
        }
        final Word? wordRow = await words.byId(wordId);
        final WordBook? bookRow = await (db.select(
          db.wordBooks,
        )..where((t) => t.id.equals(bookId))).getSingleOrNull();
        if (wordRow == null || bookRow == null) {
          skipped++;
          continue;
        }
        final int addedAt =
            _parseTime(node['addedAt'])?.millisecondsSinceEpoch ??
            now.millisecondsSinceEpoch;
        final List<WordBookEntry> existing =
            await (db.select(db.wordBookEntries)..where(
                  (t) => t.wordBookId.equals(bookId) & t.wordId.equals(wordId),
                ))
                .get();
        if (existing.isNotEmpty) continue;
        await db
            .into(db.wordBookEntries)
            .insert(
              WordBookEntriesCompanion.insert(
                wordBookId: bookId,
                wordId: wordId,
                addedAt: addedAt,
              ),
            );
        newEntries++;
      }

      // ---- review events (idempotent by primary key)
      for (final dynamic node in rawEvents) {
        if (node is! Map<String, dynamic>) {
          skipped++;
          continue;
        }
        final ReviewEvent? incoming = _eventFromJson(node);
        if (incoming == null) {
          skipped++;
          continue;
        }
        final ReviewEvent? local = await (db.select(
          db.reviewEvents,
        )..where((t) => t.id.equals(incoming.id))).getSingleOrNull();
        if (local != null) {
          duplicateEvents++;
          continue;
        }
        final Word? wordRow = await words.byId(incoming.wordId);
        if (wordRow == null) {
          skipped++;
          continue;
        }
        await db.into(db.reviewEvents).insert(incoming);
        addedEvents++;
        touchedWords.add(incoming.wordId);
      }
    });

    // Recomputing state outside the merge transaction keeps that transaction
    // short; each word is recalculated from its full merged history.
    for (final String wordId in touchedWords) {
      await study.rebuildStateFromEvents(wordId);
    }

    return MergeReport(
      addedEvents: addedEvents,
      duplicateEvents: duplicateEvents,
      newWords: newWords,
      updatedWords: updatedWords,
      deletedWords: deletedWords,
      newBooks: newBooks,
      updatedBooks: updatedBooks,
      newEntries: newEntries,
      rebuiltStates: touchedWords.length,
      skippedEntries: skipped,
    );
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
      phonetic: _str(node['phonetic']),
      partOfSpeech: _str(node['partOfSpeech']),
      translation: _str(node['translation']),
      definition: _str(node['definition']),
      example: _str(node['example']),
      phrase: _str(node['phrase']),
      note: _str(node['note']),
      source: _str(node['source'], fallback: 'import'),
      examTags: _str(node['examTags']),
      bncRank: _int(node['bncRank']),
      frqRank: _int(node['frqRank']),
      customized: node['customized'] == true,
      revision: _int(node['revision'], fallback: 1),
      createdAt:
          _parseTime(node['createdAt'])?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          _parseTime(node['updatedAt'])?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      deletedAt: _parseTime(node['deletedAt'])?.millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> _bookToJson(WordBook b) => <String, Object?>{
    'id': b.id,
    'name': b.name,
    'description': b.description,
    'sourceType': b.sourceType,
    'sourceUrl': b.sourceUrl,
    'createdAt': _iso(b.createdAt),
    'updatedAt': _iso(b.updatedAt),
    'deletedAt': b.deletedAt == null ? null : _iso(b.deletedAt!),
  };

  WordBook? _bookFromJson(Map<String, dynamic> node) {
    final String? id = node['id'] as String?;
    final String? name = node['name'] as String?;
    if (id == null || name == null) return null;
    return WordBook(
      id: id,
      name: name,
      description: _str(node['description']),
      sourceType: _str(node['sourceType'], fallback: 'import'),
      sourceUrl: _str(node['sourceUrl']),
      createdAt:
          _parseTime(node['createdAt'])?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          _parseTime(node['updatedAt'])?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
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
  };

  ReviewEvent? _eventFromJson(Map<String, dynamic> node) {
    final String? id = node['id'] as String?;
    final String? wordId = node['wordId'] as String?;
    final DateTime? answeredAt = _parseTime(node['answeredAt']);
    if (id == null || wordId == null || answeredAt == null) return null;
    final Object? result = node['result'];
    final int resultCode = result is int
        ? result
        : int.tryParse('$result') ?? 0;
    if (resultCode < 0 || resultCode > 2) return null;
    final String type = (node['type'] as String?) == 'review'
        ? 'review'
        : 'study';
    final DateTime local = answeredAt.toLocal();
    return ReviewEvent(
      id: id,
      wordId: wordId,
      deviceId: _str(node['deviceId'], fallback: 'unknown'),
      answeredAt: answeredAt.millisecondsSinceEpoch,
      localDay: _str(node['localDay']).isEmpty
          ? '${local.year.toString().padLeft(4, '0')}-'
                '${local.month.toString().padLeft(2, '0')}-'
                '${local.day.toString().padLeft(2, '0')}'
          : _str(node['localDay']),
      result: resultCode,
      type: type,
      stageBefore: _int(node['stageBefore']),
      intervalDaysAfter: _int(node['intervalDaysAfter']),
      algoVersion: _int(node['algoVersion'], fallback: 1),
    );
  }

  String _iso(int millis) => DateTime.fromMillisecondsSinceEpoch(
    millis,
    isUtc: true,
  ).toIso8601String();

  DateTime? _parseTime(Object? value) {
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
