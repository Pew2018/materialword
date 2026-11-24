/// The exact schema phase 1 shipped, dumped from a real user database
/// (`PRAGMA user_version = 1`). Kept literal on purpose: if a future migration
/// assumes a column that phase 1 never created, this test fails.
const String phase1Schema = '''
CREATE TABLE "words" (
  "id" TEXT NOT NULL, "word" TEXT NOT NULL, "normalized" TEXT NOT NULL,
  "phonetic" TEXT NOT NULL DEFAULT '', "part_of_speech" TEXT NOT NULL DEFAULT '',
  "translation" TEXT NOT NULL DEFAULT '', "definition" TEXT NOT NULL DEFAULT '',
  "example" TEXT NOT NULL DEFAULT '', "phrase" TEXT NOT NULL DEFAULT '',
  "note" TEXT NOT NULL DEFAULT '', "source" TEXT NOT NULL DEFAULT 'manual',
  "exam_tags" TEXT NOT NULL DEFAULT '', "bnc_rank" INTEGER NOT NULL DEFAULT 0,
  "frq_rank" INTEGER NOT NULL DEFAULT 0,
  "customized" INTEGER NOT NULL DEFAULT 0 CHECK ("customized" IN (0, 1)),
  "revision" INTEGER NOT NULL DEFAULT 1,
  "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL,
  "deleted_at" INTEGER NULL, PRIMARY KEY ("id"));

CREATE TABLE "word_books" (
  "id" TEXT NOT NULL, "name" TEXT NOT NULL,
  "description" TEXT NOT NULL DEFAULT '',
  "source_type" TEXT NOT NULL DEFAULT 'manual',
  "source_url" TEXT NOT NULL DEFAULT '',
  "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL,
  "deleted_at" INTEGER NULL, PRIMARY KEY ("id"));

CREATE TABLE "word_book_entries" (
  "word_book_id" TEXT NOT NULL REFERENCES word_books (id) ON DELETE CASCADE,
  "word_id" TEXT NOT NULL REFERENCES words (id) ON DELETE CASCADE,
  "added_at" INTEGER NOT NULL, PRIMARY KEY ("word_book_id", "word_id"));

CREATE TABLE "learning_states" (
  "word_id" TEXT NOT NULL REFERENCES words (id) ON DELETE CASCADE,
  "stage" INTEGER NOT NULL DEFAULT 0, "correct_count" INTEGER NOT NULL DEFAULT 0,
  "hazy_count" INTEGER NOT NULL DEFAULT 0,
  "wrong_count" INTEGER NOT NULL DEFAULT 0,
  "streak" INTEGER NOT NULL DEFAULT 0,
  "interval_days" INTEGER NOT NULL DEFAULT 0,
  "last_studied_at" INTEGER NULL, "next_review_at" INTEGER NULL,
  "updated_at" INTEGER NOT NULL, PRIMARY KEY ("word_id"));

CREATE TABLE "review_events" (
  "id" TEXT NOT NULL,
  "word_id" TEXT NOT NULL REFERENCES words (id) ON DELETE CASCADE,
  "device_id" TEXT NOT NULL, "answered_at" INTEGER NOT NULL,
  "local_day" TEXT NOT NULL, "result" INTEGER NOT NULL, "type" TEXT NOT NULL,
  "stage_before" INTEGER NOT NULL DEFAULT 0,
  "interval_days_after" INTEGER NOT NULL DEFAULT 0,
  "algo_version" INTEGER NOT NULL DEFAULT 1, PRIMARY KEY ("id"));

CREATE TABLE "study_settings" (
  "id" INTEGER NOT NULL DEFAULT 1,
  "daily_new_target" INTEGER NOT NULL DEFAULT 30,
  "daily_review_limit" INTEGER NOT NULL DEFAULT 100,
  "current_word_book_id" TEXT NULL,
  "study_mode" TEXT NOT NULL DEFAULT 'mixed',
  "theme_mode" TEXT NOT NULL DEFAULT 'system', PRIMARY KEY ("id"));

CREATE TABLE "app_meta" (
  "key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"));

CREATE UNIQUE INDEX idx_words_normalized ON words (normalized);
CREATE INDEX idx_wordbooks_deleted ON word_books (deleted_at);
CREATE INDEX idx_entries_word ON word_book_entries (word_id);
CREATE INDEX idx_learning_due ON learning_states (next_review_at);
CREATE INDEX idx_learning_stage ON learning_states (stage);
CREATE INDEX idx_events_word_time ON review_events (word_id, answered_at);
CREATE INDEX idx_events_day ON review_events (local_day, type);
''';

/// Additive statements from the released Schema 2 migration, not current tables.
const String phase2Schema =
    """
$phase1Schema
ALTER TABLE word_books ADD COLUMN revision INTEGER NOT NULL DEFAULT 1;
ALTER TABLE word_book_entries ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE word_book_entries ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0;
ALTER TABLE word_book_entries ADD COLUMN deleted_at INTEGER NULL;
ALTER TABLE review_events ADD COLUMN mode TEXT NOT NULL DEFAULT 'normal';
ALTER TABLE study_settings ADD COLUMN accent_color TEXT NOT NULL DEFAULT '#1565C0';
ALTER TABLE study_settings ADD COLUMN tts_voice TEXT NOT NULL DEFAULT '';
ALTER TABLE study_settings ADD COLUMN tts_locale TEXT NOT NULL DEFAULT 'en-US';
ALTER TABLE study_settings ADD COLUMN tts_rate INTEGER NOT NULL DEFAULT 50;
ALTER TABLE study_settings ADD COLUMN tts_auto_speak INTEGER NOT NULL DEFAULT 0;
CREATE INDEX idx_entries_book ON word_book_entries(word_book_id, deleted_at);
""";
