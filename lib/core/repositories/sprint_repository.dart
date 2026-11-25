import 'dart:isolate';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/sprint_plan.dart';
import 'settings_repository.dart';
import 'study_repository.dart';

class SprintRepository {
  SprintRepository(this.db);
  final AppDatabase db;

  Future<SprintOverview> overview(SprintPlan plan, DateTime now) async {
    final snapshot = await db.transaction(() async {
      final book = plan.bookId == null
          ? null
          : await (db.select(
              db.wordBooks,
            )..where((t) => t.id.equals(plan.bookId!))).getSingleOrNull();
      if (book == null || book.deletedAt != null) {
        return (rows: <Map<String, Object?>>[], allowance: 0, available: false);
      }
      final study = StudyRepository(db),
          settings = await SettingsRepository(db).load();
      final reviewed = await study.todayCount(
        now: now,
        type: ReviewType.review,
      );
      final rows = await db
          .customSelect(
            '''
WITH ranked AS (
 SELECT re.word_id, re.result, re.answered_at,
   ROW_NUMBER() OVER (PARTITION BY re.word_id ORDER BY re.causal_order DESC,
     re.answered_at DESC, re.device_id DESC, re.id DESC) AS position
 FROM review_events re JOIN words sw ON sw.id = re.word_id AND sw.deleted_at IS NULL
 WHERE EXISTS (SELECT 1 FROM word_book_entries se WHERE se.word_id = re.word_id
   AND se.word_book_id = ? AND se.deleted_at IS NULL)
   AND ${StudyRepository.realAnswerFilter('re')}
), errors AS (
 SELECT word_id, MAX(CASE WHEN result = 0 THEN answered_at END) AS last_wrong,
   MIN(CASE WHEN result != 0 THEN position END) AS first_nonwrong,
   COUNT(*) AS event_count,
   MAX(CASE WHEN position = 1 THEN result END) AS last_result
 FROM ranked GROUP BY word_id
)
SELECT w.id, w.normalized, COALESCE(ls.stage, 0) AS stage,
 COALESCE(ls.correct_count, 0) AS correct_count,
 COALESCE(ls.hazy_count, 0) AS hazy_count,
 COALESCE(ls.wrong_count, 0) AS wrong_count,
 COALESCE(ls.interval_days, 0) AS interval_days,
 ls.last_studied_at, ls.next_review_at, errors.last_wrong, errors.last_result,
 COALESCE(errors.first_nonwrong - 1, errors.event_count, 0) AS consecutive_wrong
FROM words w JOIN word_book_entries e ON e.word_id = w.id
 AND e.word_book_id = ? AND e.deleted_at IS NULL
LEFT JOIN learning_states ls ON ls.word_id = w.id
LEFT JOIN errors ON errors.word_id = w.id
WHERE w.deleted_at IS NULL''',
            variables: [Variable(plan.bookId!), Variable(plan.bookId!)],
            readsFrom: {
              db.words,
              db.wordBooks,
              db.wordBookEntries,
              db.learningStates,
              db.reviewEvents,
            },
          )
          .get();
      return (
        rows: rows.map((r) => Map<String, Object?>.from(r.data)).toList(),
        allowance: math.max(0, settings.dailyReviewLimit - reviewed),
        available: true,
      );
    });
    if (!snapshot.available) {
      return const SprintOverview(
        total: 0,
        unlearned: 0,
        hard: 0,
        recentMistakes: 0,
        eligible: 0,
        reviewAllowance: 0,
        wordIds: [],
        bookAvailable: false,
      );
    }
    return rankSprintCandidatesAsync(
      snapshot.rows,
      plan,
      now,
      snapshot.allowance,
    );
  }
}

Future<SprintOverview> rankSprintCandidatesAsync(
  List<Map<String, Object?>> rows,
  SprintPlan plan,
  DateTime now,
  int allowance,
) => Isolate.run(() => rankSprintCandidates(rows, plan, now, allowance));

/// Smoothed error rate and bounded weights avoid ranking a single failed
/// attempt above every well-evidenced difficulty. Reserve ~20% for coverage.
SprintOverview rankSprintCandidates(
  List<Map<String, Object?>> rows,
  SprintPlan plan,
  DateTime now,
  int allowance,
) {
  final millis = now.millisecondsSinceEpoch;
  int value(Map<String, Object?> row, String key) => row[key] as int? ?? 0;
  bool recent(Map<String, Object?> row) =>
      row['last_wrong'] is int &&
      (row['last_wrong'] as int) <= millis &&
      millis - (row['last_wrong'] as int) <=
          const Duration(days: 7).inMilliseconds;
  final eligible = rows
      .where((r) => plan.includeUnlearned || value(r, 'stage') != 0)
      .toList();
  double score(Map<String, Object?> row) {
    final wrong = value(row, 'wrong_count'),
        hazy = value(row, 'hazy_count'),
        correct = value(row, 'correct_count'),
        stage = value(row, 'stage');
    final attempts = wrong + hazy + correct;
    double result = stage == StudyStage.relearning.code
        ? 4
        : stage == StudyStage.learning.code
        ? 2
        : 0;
    final due = row['next_review_at'] as int?;
    if (due != null && due <= millis) result += 6;
    if (plan.prioritizeUnmastered && value(row, 'interval_days') < 30) {
      result += 3;
    }
    if (plan.prioritizeHard) {
      result += attempts == 0
          ? 0
          : (wrong + hazy * 0.5 + 1) / (attempts + 4) * 20;
      result +=
          math.min(wrong, 10) * 0.5 +
          math.min(value(row, 'consecutive_wrong'), 5) * 1.5;
    }
    if (plan.prioritizeRecent && recent(row)) {
      result +=
          millis - (row['last_wrong'] as int) <=
              const Duration(days: 1).inMilliseconds
          ? 6
          : 3;
    }
    final last = row['last_studied_at'] as int?;
    if (row['last_result'] == AnswerResult.known.code &&
        last != null &&
        last <= millis &&
        millis - last < const Duration(minutes: 5).inMilliseconds) {
      result -= 100; // Let other candidates run before another immediate correct repeat.
    }
    return result;
  }

  int stable(Map<String, Object?> a, Map<String, Object?> b) {
    final name = (a['normalized'] as String).compareTo(
      b['normalized'] as String,
    );
    return name == 0 ? (a['id'] as String).compareTo(b['id'] as String) : name;
  }

  eligible.sort((a, b) {
    final priority = score(b).compareTo(score(a));
    return priority != 0 ? priority : stable(a, b);
  });
  final count = !plan.enabled || (plan.daysUntil(now) ?? -1) < 0
      ? 0
      : math.min(
          eligible.length,
          math.min(
            plan.roundSize,
            plan.allowOverReviewLimit ? plan.roundSize : allowance,
          ),
        );
  final priorityCount = count <= 1
      ? count
      : (count * 0.8).floor().clamp(1, count - 1);
  final selected = eligible
          .take(priorityCount)
          .map((r) => r['id'] as String)
          .toList(),
      used = <String>{};
  used.addAll(selected);
  final coverage = eligible.where((r) => !used.contains(r['id'])).toList()
    ..sort((a, b) {
      final age = ((a['last_studied_at'] as int?) ?? -1).compareTo(
        (b['last_studied_at'] as int?) ?? -1,
      );
      return age != 0 ? age : stable(a, b);
    });
  selected.addAll(
    coverage.take(count - selected.length).map((r) => r['id'] as String),
  );
  return SprintOverview(
    total: rows.length,
    unlearned: rows.where((r) => value(r, 'stage') == 0).length,
    hard: rows
        .where((r) => value(r, 'wrong_count') + value(r, 'hazy_count') > 0)
        .length,
    recentMistakes: rows.where(recent).length,
    eligible: eligible.length,
    reviewAllowance: allowance,
    wordIds: List.unmodifiable(selected),
    bookAvailable: true,
  );
}
