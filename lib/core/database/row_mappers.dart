import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Maps a `SELECT w.*` row (optionally with `ls_*` aliases) back into the drift
/// generated [Word] class. Used by the handwritten SQL in the repositories.
Word wordFromRow(QueryRow row) {
  return Word(
    id: row.read<String>('id'),
    word: row.read<String>('word'),
    normalized: row.read<String>('normalized'),
    phonetic: row.read<String>('phonetic'),
    partOfSpeech: row.read<String>('part_of_speech'),
    translation: row.read<String>('translation'),
    definition: row.read<String>('definition'),
    example: row.read<String>('example'),
    phrase: row.read<String>('phrase'),
    note: row.read<String>('note'),
    source: row.read<String>('source'),
    examTags: row.read<String>('exam_tags'),
    bncRank: row.read<int>('bnc_rank'),
    frqRank: row.read<int>('frq_rank'),
    customized: row.read<bool>('customized'),
    revision: row.read<int>('revision'),
    createdAt: row.read<int>('created_at'),
    updatedAt: row.read<int>('updated_at'),
    deletedAt: row.readNullable<int>('deleted_at'),
  );
}

/// Reads the `ls_*` aliased learning state columns; returns null for words that
/// have never been answered.
LearningState? learningStateFromRow(QueryRow row) {
  final int? stage = row.readNullable<int>('ls_stage');
  if (stage == null) return null;
  return LearningState(
    wordId: row.read<String>('id'),
    stage: stage,
    correctCount: row.readNullable<int>('ls_correct') ?? 0,
    hazyCount: row.readNullable<int>('ls_hazy') ?? 0,
    wrongCount: row.readNullable<int>('ls_wrong') ?? 0,
    streak: row.readNullable<int>('ls_streak') ?? 0,
    intervalDays: row.readNullable<int>('ls_interval') ?? 0,
    lastStudiedAt: row.readNullable<int>('ls_last'),
    nextReviewAt: row.readNullable<int>('ls_next'),
    updatedAt: row.readNullable<int>('ls_updated') ?? 0,
  );
}

/// Column list shared by every query that selects words with their state.
const String wordColumnsWithState = '''
w.*,
ls.stage        AS ls_stage,
ls.correct_count AS ls_correct,
ls.hazy_count   AS ls_hazy,
ls.wrong_count  AS ls_wrong,
ls.streak       AS ls_streak,
ls.interval_days AS ls_interval,
ls.last_studied_at AS ls_last,
ls.next_review_at AS ls_next,
ls.updated_at   AS ls_updated
''';
