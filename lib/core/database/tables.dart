import 'package:drift/drift.dart';

/// A single vocabulary entry. All free-text fields default to an empty string
/// rather than null so the UI never has to wrestle with two "empty" states.
///
/// Timestamps are stored as milliseconds since epoch (UTC) in `IntColumn`s;
/// that keeps ordering, indexing and JSON export trivially portable.
///
/// Sync-relevant columns: `revision` (monotonic per row edit), `updatedAt`
/// (last mutation, used as the tie-breaker) and `deletedAt` (tombstone). A row
/// is never physically removed during a merge, otherwise a stale backup could
/// resurrect it.
@TableIndex(name: 'idx_words_normalized', columns: {#normalized}, unique: true)
@DataClassName('Word')
class Words extends Table {
  TextColumn get id => text()();
  TextColumn get word => text()();
  TextColumn get normalized => text()();
  TextColumn get phonetic => text().withDefault(const Constant(''))();
  TextColumn get partOfSpeech => text().withDefault(const Constant(''))();
  TextColumn get translation => text().withDefault(const Constant(''))();
  TextColumn get definition => text().withDefault(const Constant(''))();
  TextColumn get example => text().withDefault(const Constant(''))();
  TextColumn get phrase => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get examTags => text().withDefault(const Constant(''))();
  IntColumn get bncRank => integer().withDefault(const Constant(0))();
  IntColumn get frqRank => integer().withDefault(const Constant(0))();
  BoolColumn get customized => boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_wordbooks_deleted', columns: {#deletedAt})
@DataClassName('WordBook')
class WordBooks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get sourceType => text().withDefault(const Constant('manual'))();
  TextColumn get sourceUrl => text().withDefault(const Constant(''))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Many-to-many relation between books and words. A word can live in several
/// books; learning state is always stored per word, never per book.
///
/// Removing a word from a book writes a **tombstone** (`deletedAt`) instead of
/// deleting the row: without it a merge could not tell "removed on device A"
/// apart from "never existed on device B", and the link would come back on the
/// next sync. `version` / `updatedAt` order concurrent edits deterministically.
@TableIndex(name: 'idx_entries_word', columns: {#wordId})
@TableIndex(name: 'idx_entries_book', columns: {#wordBookId, #deletedAt})
@DataClassName('WordBookEntry')
class WordBookEntries extends Table {
  TextColumn get wordBookId =>
      text().references(WordBooks, #id, onDelete: KeyAction.cascade)();
  TextColumn get wordId =>
      text().references(Words, #id, onDelete: KeyAction.cascade)();
  IntColumn get addedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {wordBookId, wordId};
}

/// Current learning state per word (exactly one row per word).
///
/// This table is *derived*: it can always be rebuilt from [ReviewEvents].
@TableIndex(name: 'idx_learning_due', columns: {#nextReviewAt})
@TableIndex(name: 'idx_learning_stage', columns: {#stage})
@DataClassName('LearningState')
class LearningStates extends Table {
  TextColumn get wordId =>
      text().references(Words, #id, onDelete: KeyAction.cascade)();
  IntColumn get stage => integer().withDefault(const Constant(0))();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get hazyCount => integer().withDefault(const Constant(0))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get streak => integer().withDefault(const Constant(0))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get lastStudiedAt => integer().nullable()();
  IntColumn get nextReviewAt => integer().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {wordId};
}

/// Immutable log of every answer. This is the source of truth: learning state
/// can always be rebuilt from these rows.
///
/// `eventId` is a client-generated UUID, so double taps, retries and repeated
/// imports all collapse into one row.
@TableIndex(name: 'idx_events_word_time', columns: {#wordId, #answeredAt})
@TableIndex(name: 'idx_events_day', columns: {#localDay, #type})
@DataClassName('ReviewEvent')
class ReviewEvents extends Table {
  TextColumn get id => text()();
  TextColumn get wordId =>
      text().references(Words, #id, onDelete: KeyAction.cascade)();
  TextColumn get deviceId => text()();
  IntColumn get answeredAt => integer()();
  TextColumn get localDay => text()();
  IntColumn get result => integer()();
  TextColumn get type => text()();
  IntColumn get stageBefore => integer().withDefault(const Constant(0))();
  IntColumn get intervalDaysAfter => integer().withDefault(const Constant(0))();
  IntColumn get algoVersion => integer().withDefault(const Constant(1))();
  TextColumn get mode => text().withDefault(const Constant('normal'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Single-row table (`id == 1`) holding user preferences.
///
/// Settings are split into two groups (see `docs/sync-protocol.md`):
///  * **shared** — learning goals that should follow the user across devices:
///    `dailyNewTarget`, `dailyReviewLimit`, `studyMode`.
///  * **device-specific** — `themeMode`, `accentColor`, TTS options,
///    `currentWordBookId` and every sync credential: these describe *this*
///    device and are never applied from an incoming dataset.
@TableIndex(name: 'idx_settings_id', columns: {#id})
@DataClassName('StudySettingsRow')
class StudySettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get dailyNewTarget => integer().withDefault(const Constant(30))();
  IntColumn get dailyReviewLimit =>
      integer().withDefault(const Constant(100))();
  TextColumn get currentWordBookId => text().nullable()();
  TextColumn get studyMode => text().withDefault(const Constant('mixed'))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  TextColumn get accentColor => text().withDefault(const Constant('#1565C0'))();
  TextColumn get ttsVoice => text().withDefault(const Constant(''))();
  TextColumn get ttsLocale => text().withDefault(const Constant('en-US'))();
  IntColumn get ttsRate => integer().withDefault(const Constant(50))();
  BoolColumn get ttsAutoSpeak => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Small key/value store: device id, sync bookkeeping, dictionary version…
@DataClassName('AppMetaRow')
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
