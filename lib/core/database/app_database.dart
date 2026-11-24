import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// User data database. The bundled dictionary lives in a *separate* read-only
/// SQLite file (see `DictionaryService`) so user progress and dictionary data
/// can be updated independently.
@DriftDatabase(
  tables: [
    Words,
    WordBooks,
    WordBookEntries,
    LearningStates,
    ReviewEvents,
    StudySettings,
    AppMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Production constructor: file stored in the platform application-support
  /// directory (never inside the project, never synced as a raw file).
  AppDatabase.open() : super(driftDatabase(name: 'materialword'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Phase 1 only ships schema version 1. Future migrations are added here,
      // e.g. if (from < 2) await m.addColumn(words, words.someNewColumn);
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Convenience helpers used by repositories.
  Future<String?> readMeta(String key) async {
    final AppMetaRow? row = await (select(
      appMeta,
    )..where((AppMeta t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> writeMeta(String key, String value) async {
    await into(
      appMeta,
    ).insertOnConflictUpdate(AppMetaCompanion.insert(key: key, value: value));
  }
}
