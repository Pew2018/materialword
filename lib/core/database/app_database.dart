import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../text/dictionary_text.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// User data database. The bundled dictionary lives in a *separate* read-only
/// SQLite file (see `DictionaryService`) so user progress and dictionary data
/// can be updated independently.
///
/// Schema history:
///  * v1 — phase 1: words / books / entries / states / events / settings.
///  * v2 — phase 2: sync tombstones and versions (`word_book_entries.deleted_at`,
///    `version`, `updated_at`, `word_books.revision`), theme accent colour, TTS
///    options and the review `mode` column. The upgrade is additive: no column
///    is dropped and no row is deleted, so user data survives untouched.
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

  static const int currentSchemaVersion = 2;

  /// Meta key guarding the one-off repair of dictionary text that was stored
  /// with literal `\n` escapes before the normaliser existed.
  static const String dictionaryRepairKey = 'dictionary_text_repaired_v2';

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // --- sync metadata -------------------------------------------------
        await m.addColumn(wordBooks, wordBooks.revision);
        await m.addColumn(wordBookEntries, wordBookEntries.version);
        await m.addColumn(wordBookEntries, wordBookEntries.updatedAt);
        await m.addColumn(wordBookEntries, wordBookEntries.deletedAt);

        // Existing links never had a version; treat them as freshly created so
        // that a local "already in book" wins over an older remote tombstone.
        await customStatement(
          'UPDATE word_book_entries SET updated_at = added_at WHERE updated_at = 0',
        );

        // --- theme + TTS ---------------------------------------------------
        await m.addColumn(studySettings, studySettings.accentColor);
        await m.addColumn(studySettings, studySettings.ttsVoice);
        await m.addColumn(studySettings, studySettings.ttsLocale);
        await m.addColumn(studySettings, studySettings.ttsRate);
        await m.addColumn(studySettings, studySettings.ttsAutoSpeak);

        // --- review mode ---------------------------------------------------
        await m.addColumn(reviewEvents, reviewEvents.mode);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.wasCreated || details.hadUpgrade) {
        await repairDictionaryText();
      }
    },
  );

  /// Rewrites rows that still contain literal escape sequences in
  /// dictionary-owned fields. Notes are never touched. Runs once per database
  /// (guarded by [dictionaryRepairKey]) and is idempotent, so an interrupted
  /// run simply repeats.
  Future<int> repairDictionaryText() async {
    final String? done = await readMeta(dictionaryRepairKey);
    if (done == 'true') return 0;

    final List<Word> rows =
        await (select(words)..where(
              (t) =>
                  t.translation.like(r'%\n%') |
                  t.translation.like(r'%\r%') |
                  t.definition.like(r'%\n%') |
                  t.definition.like(r'%\r%') |
                  t.example.like(r'%\n%') |
                  t.example.like(r'%\r%') |
                  t.phrase.like(r'%\n%') |
                  t.phrase.like(r'%\r%'),
            ))
            .get();

    int repaired = 0;
    for (final Word row in rows) {
      final String translation = normalizeDictionaryText(row.translation);
      final String definition = normalizeDictionaryText(row.definition);
      final String example = normalizeDictionaryText(row.example);
      final String phrase = normalizeDictionaryText(row.phrase);
      if (translation == row.translation &&
          definition == row.definition &&
          example == row.example &&
          phrase == row.phrase) {
        continue;
      }
      // Content repair is *not* a user edit: keep revision/updatedAt so the
      // change cannot win a conflict against a real edit on another device.
      await (update(words)..where((t) => t.id.equals(row.id))).write(
        WordsCompanion(
          translation: Value<String>(translation),
          definition: Value<String>(definition),
          example: Value<String>(example),
          phrase: Value<String>(phrase),
        ),
      );
      repaired++;
    }
    await writeMeta(dictionaryRepairKey, 'true');
    return repaired;
  }

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

  Future<void> deleteMeta(String key) async {
    await (delete(appMeta)..where((AppMeta t) => t.key.equals(key))).go();
  }
}
