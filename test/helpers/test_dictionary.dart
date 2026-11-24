import 'dart:io';

import 'package:materialword/services/dictionary_service.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

/// Builds a tiny read-only dictionary file with the same schema as the bundled
/// ECDICT subset, so tests can exercise real lookups without shipping the 6 MB
/// asset (which is not available to `flutter test`).
class TestDictionary {
  TestDictionary._(this.directory, this.service);

  final Directory directory;
  final DictionaryService service;

  static TestDictionary create(
    Map<String, ({String translation, String definition, String phonetic})>
    entries,
  ) {
    final Directory dir = Directory.systemTemp.createTempSync('mw_dict');
    final String path = '${dir.path}/dictionary.db';
    final sql.Database db = sql.sqlite3.open(path);
    db.execute('''
CREATE TABLE dictionary (
  word        TEXT PRIMARY KEY,
  display     TEXT NOT NULL,
  phonetic    TEXT,
  pos         TEXT,
  translation TEXT,
  definition  TEXT,
  tag         TEXT,
  bnc         INTEGER NOT NULL DEFAULT 0,
  frq         INTEGER NOT NULL DEFAULT 0,
  collins     INTEGER NOT NULL DEFAULT 0,
  oxford      INTEGER NOT NULL DEFAULT 0
)''');
    final sql.PreparedStatement insert = db.prepare(
      'INSERT INTO dictionary (word, display, phonetic, pos, translation, '
      'definition, tag, bnc, frq) VALUES (?,?,?,?,?,?,?,?,?)',
    );
    for (final MapEntry<
          String,
          ({String translation, String definition, String phonetic})
        >
        entry
        in entries.entries) {
      insert.execute(<Object?>[
        entry.key,
        entry.key,
        entry.value.phonetic,
        'n.',
        entry.value.translation,
        entry.value.definition,
        'cet6',
        1000,
        1000,
      ]);
    }
    insert.dispose();
    db.execute('PRAGMA user_version = 1');
    db.dispose();

    return TestDictionary._(dir, DictionaryService.openFile(path));
  }

  void dispose() {
    service.close();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}
