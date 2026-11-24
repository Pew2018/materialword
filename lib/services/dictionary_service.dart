import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// One dictionary hit.
class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.display,
    required this.phonetic,
    required this.partOfSpeech,
    required this.translation,
    required this.definition,
    required this.examTags,
    required this.bncRank,
    required this.frqRank,
    required this.collins,
    required this.oxford,
  });

  final String word;
  final String display;
  final String phonetic;
  final String partOfSpeech;
  final String translation;
  final String definition;
  final String examTags;
  final int bncRank;
  final int frqRank;
  final int collins;
  final int oxford;

  /// Human readable exam tags, e.g. `CET-6 · 考研`.
  String get tagLabel {
    final Map<String, String> names = <String, String>{
      'zk': '中考',
      'gk': '高考',
      'cet4': 'CET-4',
      'cet6': 'CET-6',
      'ky': '考研',
      'toefl': 'TOEFL',
      'ielts': 'IELTS',
      'gre': 'GRE',
    };
    final List<String> labels = examTags
        .split(' ')
        .where((String t) => t.isNotEmpty)
        .map((String t) => names[t] ?? t.toUpperCase())
        .toList();
    return labels.join(' · ');
  }
}

/// Offline dictionary backed by a read-only SQLite file.
///
/// The database is generated from ECDICT (MIT) by `tool/build_dictionary.py`
/// and shipped as a Flutter asset. It is copied into the application support
/// directory once per version so queries are memory-mapped instead of being
/// re-parsed on every launch. User data lives in a *different* database file.
class DictionaryService {
  DictionaryService._(this._database, this.version);

  final Database _database;
  final int version;

  bool get isReady => true;

  /// Opens the bundled asset database, copying it out of the bundle on first
  /// use or when the asset version changes.
  static Future<DictionaryService> openBundled() async {
    const String assetPath = 'assets/dictionary/ecdict_core.db';
    final Directory support = await getApplicationSupportDirectory();
    final Directory target = Directory('${support.path}/dictionary');
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }
    final File file = File('${target.path}/ecdict_core.db');

    final ByteData data = await rootBundle.load(assetPath);
    final int assetLength = data.lengthInBytes;
    final bool needsCopy =
        !file.existsSync() || file.lengthSync() != assetLength;

    if (needsCopy) {
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, assetLength),
        flush: true,
      );
    }
    final Database db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    if (db.userVersion != 1) {
      throw StateError(
        'Unsupported dictionary schema version: ${db.userVersion}',
      );
    }
    return DictionaryService._(db, db.userVersion);
  }

  /// Test / advanced constructor: opens an arbitrary dictionary file read-only.
  static DictionaryService openFile(String path) {
    final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
    return DictionaryService._(db, db.userVersion);
  }

  Future<DictionaryEntry?> lookup(String word) async {
    final String key = _normalize(word);
    if (key.isEmpty) return null;
    final ResultSet rows = _database.select(
      'SELECT * FROM dictionary WHERE word = ? LIMIT 1',
      <Object>[key],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Prefix suggestions for the quick-add screen.
  Future<List<DictionaryEntry>> suggest(String prefix, {int limit = 8}) async {
    final String key = _normalize(prefix);
    if (key.isEmpty) return const <DictionaryEntry>[];
    final ResultSet rows = _database.select(
      'SELECT * FROM dictionary WHERE word >= ? AND word < ? ORDER BY word LIMIT ?',
      <Object>[key, '$key\u{10FFFF}', limit],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<int> count() async {
    final ResultSet rows = _database.select(
      'SELECT COUNT(*) AS c FROM dictionary',
    );
    return rows.first['c'] as int;
  }

  void close() => _database.close();

  DictionaryEntry _fromRow(Row row) {
    return DictionaryEntry(
      word: row['word'] as String,
      display: row['display'] as String? ?? row['word'] as String,
      phonetic: row['phonetic'] as String? ?? '',
      partOfSpeech: row['pos'] as String? ?? '',
      translation: row['translation'] as String? ?? '',
      definition: row['definition'] as String? ?? '',
      examTags: row['tag'] as String? ?? '',
      bncRank: (row['bnc'] as int?) ?? 0,
      frqRank: (row['frq'] as int?) ?? 0,
      collins: (row['collins'] as int?) ?? 0,
      oxford: (row['oxford'] as int?) ?? 0,
    );
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
