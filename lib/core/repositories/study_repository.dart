import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/row_mappers.dart';
import '../models/enums.dart';
import '../models/study_models.dart';
import '../repositories/word_repository.dart';
import '../../services/study_scheduler.dart';

/// All read/write access to learning data. Scheduling decisions are delegated
/// to [StudyScheduler] (pure); this class only persists their outcome.
class StudyRepository {
  StudyRepository(this.db, {this.scheduler = const StudyScheduler()});

  final AppDatabase db;
  final StudyScheduler scheduler;

  // ---------------------------------------------------------------- queues

  static const String _stateJoin =
      'LEFT JOIN learning_states ls ON ls.word_id = w.id';

  String _bookFilter({required String alias, required bool active}) => active
      ? 'AND EXISTS (SELECT 1 FROM word_book_entries e WHERE e.word_book_id = ? AND e.word_id = w.id)'
      : '';

  /// Words never answered, highest frequency first, then alphabetical.
  Future<List<WordWithState>> newWords({
    String? bookId,
    int limit = 30,
    int offset = 0,
  }) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    final String bookClause = _bookFilter(alias: 'e', active: bookId != null);
    if (bookId != null) variables.add(Variable<String>(bookId));
    variables.add(Variable<int>(limit));
    variables.add(Variable<int>(offset));
    final List<QueryRow> rows = await db
        .customSelect(
          '''
SELECT $wordColumnsWithState
  FROM words w
  $_stateJoin
 WHERE w.deleted_at IS NULL
   AND (ls.stage IS NULL OR ls.stage = 0)
   $bookClause
 ORDER BY CASE WHEN w.frq_rank = 0 THEN 999999 ELSE w.frq_rank END,
          CASE WHEN w.bnc_rank = 0 THEN 999999 ELSE w.bnc_rank END,
          w.normalized
 LIMIT ? OFFSET ?''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .get();
    return _toWordWithState(rows);
  }

  /// Words whose next review is due at or before [now]. Ordering puts the most
  /// overdue words first and, inside the same due date, the words the user got
  /// wrong most often. A word can only appear once per day because answering it
  /// pushes `next_review_at` into the future — so a "hard" word can never
  /// permanently occupy the queue.
  Future<List<WordWithState>> dueWords({
    required DateTime now,
    String? bookId,
    int limit = 100,
    int offset = 0,
  }) async {
    final List<Variable<Object>> variables = <Variable<Object>>[
      Variable<int>(now.millisecondsSinceEpoch),
    ];
    final String bookClause = _bookFilter(alias: 'e', active: bookId != null);
    if (bookId != null) variables.add(Variable<String>(bookId));
    variables.add(Variable<int>(limit));
    variables.add(Variable<int>(offset));
    final List<QueryRow> rows = await db
        .customSelect(
          '''
SELECT $wordColumnsWithState
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL
   AND ls.stage != 0
   AND ls.next_review_at IS NOT NULL
   AND ls.next_review_at <= ?
   $bookClause
 ORDER BY ls.next_review_at ASC,
          (ls.wrong_count * 2 + ls.hazy_count) DESC,
          w.normalized
 LIMIT ? OFFSET ?''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .get();
    return _toWordWithState(rows);
  }

  Future<int> dueCount({required DateTime now, String? bookId}) async {
    final List<Variable<Object>> variables = <Variable<Object>>[
      Variable<int>(now.millisecondsSinceEpoch),
    ];
    final String bookClause = _bookFilter(alias: 'e', active: bookId != null);
    if (bookId != null) variables.add(Variable<String>(bookId));
    final QueryRow row = await db
        .customSelect(
          '''
SELECT COUNT(*) AS c
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL
   AND ls.stage != 0
   AND ls.next_review_at IS NOT NULL
   AND ls.next_review_at <= ?
   $bookClause''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  Future<int> newWordCount({String? bookId}) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    final String bookClause = _bookFilter(alias: 'e', active: bookId != null);
    if (bookId != null) variables.add(Variable<String>(bookId));
    final QueryRow row = await db
        .customSelect(
          '''
SELECT COUNT(*) AS c
  FROM words w
  $_stateJoin
 WHERE w.deleted_at IS NULL
   AND (ls.stage IS NULL OR ls.stage = 0)
   $bookClause''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// Builds today's queue. [newLimit] / [reviewLimit] are the *remaining*
  /// allowance after today's finished cards.
  Future<StudyQueue> buildQueue({
    required DateTime now,
    required int newLimit,
    required int reviewLimit,
    String? bookId,
    StudyMode mode = StudyMode.mixed,
  }) async {
    final int dueTotal = await dueCount(now: now, bookId: bookId);
    final int newTotal = mode == StudyMode.reviewOnly
        ? 0
        : await newWordCount(bookId: bookId);

    final List<StudyCard> cards = <StudyCard>[];

    if (mode != StudyMode.reviewOnly && newLimit > 0) {
      final List<WordWithState> fresh = await newWords(
        bookId: bookId,
        limit: newLimit,
      );
      cards.addAll(
        fresh.map(
          (WordWithState w) =>
              StudyCard(word: w.word, withState: w, type: ReviewType.study),
        ),
      );
    }

    final int allowedReviews = reviewLimit.clamp(0, 1 << 30);
    if (mode != StudyMode.newOnly && allowedReviews > 0 && dueTotal > 0) {
      final List<WordWithState> due = await dueWords(
        now: now,
        bookId: bookId,
        limit: allowedReviews,
      );
      cards.addAll(
        due.map(
          (WordWithState w) =>
              StudyCard(word: w.word, withState: w, type: ReviewType.review),
        ),
      );
    }

    return StudyQueue(
      cards: cards,
      newAvailable: newTotal,
      reviewAvailable: dueTotal,
      backlog: (dueTotal - allowedReviews) > 0 ? dueTotal - allowedReviews : 0,
    );
  }

  // ----------------------------------------------------------- persistence

  /// Writes one answer atomically: raw event + derived state.
  ///
  /// [eventId] makes the operation idempotent — submitting the same id twice
  /// (double tap, retried future) never creates a second event.
  Future<AnswerRecord> recordAnswer({
    required String wordId,
    required AnswerResult result,
    required ReviewType type,
    required String eventId,
    required String deviceId,
    required DateTime now,
  }) {
    return db.transaction(() async {
      final ReviewEvent? existing = await (db.select(
        db.reviewEvents,
      )..where((t) => t.id.equals(eventId))).getSingleOrNull();
      if (existing != null) {
        return AnswerRecord(
          eventId: eventId,
          duplicate: true,
          stage: StudyStage.fromCode(existing.stageBefore),
          nextReviewAt: now,
          intervalDays: existing.intervalDaysAfter,
          repeatInSession: false,
        );
      }

      final LearningState? state = await (db.select(
        db.learningStates,
      )..where((t) => t.wordId.equals(wordId))).getSingleOrNull();

      final LearningSnapshot snapshot = state == null
          ? const LearningSnapshot.empty()
          : LearningSnapshot(
              stage: StudyStage.fromCode(state.stage),
              correctCount: state.correctCount,
              hazyCount: state.hazyCount,
              wrongCount: state.wrongCount,
              streak: state.streak,
              intervalDays: state.intervalDays,
            );

      final ScheduleOutcome outcome = scheduler.schedule(
        current: snapshot,
        result: result,
        now: now,
        type: type,
      );

      await db
          .into(db.reviewEvents)
          .insert(
            ReviewEventsCompanion.insert(
              id: eventId,
              wordId: wordId,
              deviceId: deviceId,
              answeredAt: now.millisecondsSinceEpoch,
              localDay: _dayKey(now),
              result: result.code,
              type: type.code,
              stageBefore: Value<int>(snapshot.stage.code),
              intervalDaysAfter: Value<int>(outcome.intervalDays),
              algoVersion: Value<int>(StudyScheduler.algorithmVersion),
            ),
          );

      await db
          .into(db.learningStates)
          .insertOnConflictUpdate(
            LearningStatesCompanion.insert(
              wordId: wordId,
              stage: Value<int>(outcome.stage.code),
              correctCount: Value<int>(outcome.correctCount),
              hazyCount: Value<int>(outcome.hazyCount),
              wrongCount: Value<int>(outcome.wrongCount),
              streak: Value<int>(outcome.streak),
              intervalDays: Value<int>(outcome.intervalDays),
              lastStudiedAt: Value<int>(now.millisecondsSinceEpoch),
              nextReviewAt: Value<int?>(
                outcome.nextReviewAt.millisecondsSinceEpoch,
              ),
              updatedAt: now.millisecondsSinceEpoch,
            ),
          );

      return AnswerRecord(
        eventId: eventId,
        duplicate: false,
        stage: outcome.stage,
        nextReviewAt: outcome.nextReviewAt,
        intervalDays: outcome.intervalDays,
        repeatInSession: outcome.repeatInSession,
      );
    });
  }

  /// Replays the whole history of [wordId] to recompute its state. Used after
  /// merging an imported backup, where the event log is authoritative.
  Future<void> rebuildStateFromEvents(String wordId) async {
    final List<ReviewEvent> events =
        await (db.select(db.reviewEvents)
              ..where((t) => t.wordId.equals(wordId))
              ..orderBy(<OrderClauseGenerator<$ReviewEventsTable>>[
                (t) => OrderingTerm(expression: t.answeredAt),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    if (events.isEmpty) {
      await (db.delete(
        db.learningStates,
      )..where((t) => t.wordId.equals(wordId))).go();
      return;
    }
    LearningSnapshot snapshot = const LearningSnapshot.empty();
    DateTime? lastStudiedAt;
    DateTime? nextReviewAt;
    for (final ReviewEvent event in events) {
      final ScheduleOutcome outcome = scheduler.schedule(
        current: snapshot,
        result: AnswerResult.fromCode(event.result),
        now: DateTime.fromMillisecondsSinceEpoch(event.answeredAt, isUtc: true),
        type: ReviewType.fromCode(event.type),
      );
      snapshot = LearningSnapshot(
        stage: outcome.stage,
        correctCount: outcome.correctCount,
        hazyCount: outcome.hazyCount,
        wrongCount: outcome.wrongCount,
        streak: outcome.streak,
        intervalDays: outcome.intervalDays,
      );
      lastStudiedAt = DateTime.fromMillisecondsSinceEpoch(
        event.answeredAt,
        isUtc: true,
      );
      nextReviewAt = outcome.nextReviewAt;
    }
    await db
        .into(db.learningStates)
        .insertOnConflictUpdate(
          LearningStatesCompanion.insert(
            wordId: wordId,
            stage: Value<int>(snapshot.stage.code),
            correctCount: Value<int>(snapshot.correctCount),
            hazyCount: Value<int>(snapshot.hazyCount),
            wrongCount: Value<int>(snapshot.wrongCount),
            streak: Value<int>(snapshot.streak),
            intervalDays: Value<int>(snapshot.intervalDays),
            lastStudiedAt: Value<int?>(lastStudiedAt?.millisecondsSinceEpoch),
            nextReviewAt: Value<int?>(nextReviewAt?.millisecondsSinceEpoch),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  // ------------------------------------------------------------- progress

  Future<int> todayCount({
    required DateTime now,
    required ReviewType type,
  }) async {
    final QueryRow row = await db
        .customSelect(
          'SELECT COUNT(DISTINCT word_id) AS c FROM review_events WHERE local_day = ? AND type = ?',
          variables: <Variable<Object>>[
            Variable<String>(_dayKey(now)),
            Variable<String>(type.code),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.reviewEvents,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  Future<TodayProgress> todayProgress({
    required DateTime now,
    required int newTarget,
    required int reviewLimit,
    String? bookId,
  }) async {
    final int newDone = await todayCount(now: now, type: ReviewType.study);
    final int reviewDone = await todayCount(now: now, type: ReviewType.review);
    final int due = await dueCount(now: now, bookId: bookId);
    final int remainingLimit = (reviewLimit - reviewDone).clamp(0, reviewLimit);
    return TodayProgress(
      newDone: newDone,
      newTarget: newTarget,
      reviewDone: reviewDone,
      reviewLimit: reviewLimit,
      dueNow: due,
      backlog: (due - remainingLimit) > 0 ? due - remainingLimit : 0,
      learnedWords: await learnedCount(bookId: bookId),
      totalWords: await totalCount(bookId: bookId),
      hardWords: await hardWordCount(bookId: bookId),
    );
  }

  Future<int> totalCount({String? bookId}) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    final String bookClause = _bookFilter(alias: 'e', active: bookId != null);
    if (bookId != null) variables.add(Variable<String>(bookId));
    final QueryRow row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM words w WHERE w.deleted_at IS NULL $bookClause',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.wordBookEntries,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  Future<int> learnedCount({String? bookId}) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    final String bookClause = _bookFilter(alias: 'e', active: bookId != null);
    if (bookId != null) variables.add(Variable<String>(bookId));
    final QueryRow row = await db
        .customSelect(
          '''
SELECT COUNT(*) AS c
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL AND ls.stage != 0
   $bookClause''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  Future<int> hardWordCount({String? bookId}) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    final String bookClause = _bookFilter(alias: 'e', active: bookId != null);
    if (bookId != null) variables.add(Variable<String>(bookId));
    final QueryRow row = await db
        .customSelect(
          '''
SELECT COUNT(*) AS c
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL AND (ls.wrong_count + ls.hazy_count) >= 2
   $bookClause''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  Future<List<WordWithState>> hardWords({
    String? bookId,
    int limit = 30,
  }) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    final String bookClause = _bookFilter(alias: 'e', active: bookId != null);
    if (bookId != null) variables.add(Variable<String>(bookId));
    variables.add(Variable<int>(limit));
    final List<QueryRow> rows = await db
        .customSelect(
          '''
SELECT $wordColumnsWithState
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL
   AND (ls.wrong_count > 0 OR ls.hazy_count > 0)
   $bookClause
 ORDER BY ls.wrong_count DESC, ls.hazy_count DESC, w.normalized
 LIMIT ?''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .get();
    return _toWordWithState(rows);
  }

  Future<StudyStatistics> statistics({
    required DateTime now,
    String? bookId,
  }) async {
    final QueryRow totals = await db
        .customSelect(
          '''
SELECT COALESCE(SUM(ls.correct_count), 0) AS correct,
       COALESCE(SUM(ls.hazy_count), 0)    AS hazy,
       COALESCE(SUM(ls.wrong_count), 0)   AS wrong
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL''',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
          },
        )
        .getSingle();

    final QueryRow lastDay = await db
        .customSelect(
          'SELECT MAX(local_day) AS day FROM review_events',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.reviewEvents,
          },
        )
        .getSingle();

    return StudyStatistics(
      totalWords: await totalCount(bookId: bookId),
      learnedWords: await learnedCount(bookId: bookId),
      todayNew: await todayCount(now: now, type: ReviewType.study),
      todayReview: await todayCount(now: now, type: ReviewType.review),
      correctCount: totals.read<int>('correct'),
      hazyCount: totals.read<int>('hazy'),
      wrongCount: totals.read<int>('wrong'),
      hardWords: await hardWords(bookId: bookId, limit: 30),
      lastStudyDay: lastDay.readNullable<String>('day'),
    );
  }

  String _dayKey(DateTime moment) {
    final DateTime local = moment.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  List<WordWithState> _toWordWithState(List<QueryRow> rows) {
    return rows
        .map((QueryRow row) {
          final LearningState? state = learningStateFromRow(row);
          return WordWithState(
            word: wordFromRow(row),
            state: state,
            bookCount: 1,
            lastAnsweredAt: state?.lastStudiedAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    state!.lastStudiedAt!,
                    isUtc: true,
                  ).toLocal(),
          );
        })
        .toList(growable: false);
  }
}
