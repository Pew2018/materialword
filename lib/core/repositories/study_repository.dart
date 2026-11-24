import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/row_mappers.dart';
import '../models/enums.dart';
import '../models/study_models.dart';
import '../repositories/word_repository.dart';
import '../text/dictionary_text.dart';
import '../../services/study_scheduler.dart';

/// All read/write access to learning data. Scheduling decisions are delegated
/// to [StudyScheduler] (pure); this class only persists their outcome.
///
/// Two invariants hold everywhere in this file:
///  1. deleted words (`words.deleted_at IS NOT NULL`) and removed book links
///     (`word_book_entries.deleted_at IS NOT NULL`) never influence a count,
///     a queue or a statistic;
///  2. `learning_states` is derived from `review_events` and can always be
///     rebuilt — including manual "mark as mastered" / "reset progress".
class StudyRepository {
  StudyRepository(this.db, {this.scheduler = const StudyScheduler()});

  final AppDatabase db;
  final StudyScheduler scheduler;

  /// Recent-mistake windows used by the special review queue.
  static const Duration recentMistakeWindow = Duration(days: 14);

  // ---------------------------------------------------------------- queues

  static const String _stateJoin =
      'LEFT JOIN learning_states ls ON ls.word_id = w.id';

  /// Only *live* links count. A tombstoned link means "this word used to be in
  /// that book"; treating it as a member would resurrect removed words.
  static const String _activeEntry =
      'EXISTS (SELECT 1 FROM word_book_entries e '
      'WHERE e.word_book_id = ? AND e.word_id = w.id AND e.deleted_at IS NULL)';

  String _bookFilter({required bool active}) =>
      active ? 'AND $_activeEntry' : '';

  /// Words never answered, highest frequency first, then alphabetical.
  Future<List<WordWithState>> newWords({
    String? bookId,
    int limit = 30,
    int offset = 0,
  }) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
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
   ${_bookFilter(active: bookId != null)}
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
   ${_bookFilter(active: bookId != null)}
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

  /// Queue for the special review modes. These are *explicit* modes: they never
  /// silently replace the normal due queue, and they are only reachable from
  /// dedicated entry points in the UI.
  Future<List<WordWithState>> specialWords({
    required SpecialReview kind,
    required DateTime now,
    String? bookId,
    int limit = 30,
  }) async {
    if (kind == SpecialReview.none) {
      return const <WordWithState>[];
    }
    final List<Variable<Object>> variables = <Variable<Object>>[];
    String filter;
    String order;
    switch (kind) {
      case SpecialReview.hard:
        filter = 'AND (ls.wrong_count + ls.hazy_count) > 0';
        order =
            'ORDER BY ls.wrong_count DESC, ls.hazy_count DESC, w.normalized';
      case SpecialReview.recentMistakes:
        variables.add(
          Variable<int>(
            now.subtract(recentMistakeWindow).millisecondsSinceEpoch,
          ),
        );
        filter =
            'AND EXISTS (SELECT 1 FROM review_events re '
            'WHERE re.word_id = w.id AND re.result = 0 AND re.answered_at >= ?)';
        order =
            'ORDER BY (SELECT COUNT(*) FROM review_events re2 '
            'WHERE re2.word_id = w.id AND re2.result = 0) DESC, w.normalized';
      case SpecialReview.inBook:
        filter = 'AND ls.stage != 0';
        order = 'ORDER BY ls.next_review_at ASC, w.normalized';
      case SpecialReview.none:
        return const <WordWithState>[];
    }
    if (bookId != null) {
      variables.add(Variable<String>(bookId));
    } else if (kind == SpecialReview.inBook) {
      // "In book" without a book makes no sense.
      return const <WordWithState>[];
    }
    variables.add(Variable<int>(limit));
    final List<QueryRow> rows = await db
        .customSelect(
          '''
SELECT $wordColumnsWithState
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL
   AND ls.stage != 0
   $filter
   ${_bookFilter(active: bookId != null)}
 $order
 LIMIT ?''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
            db.reviewEvents,
          },
        )
        .get();
    return _toWordWithState(rows);
  }

  Future<int> dueCount({required DateTime now, String? bookId}) async {
    final List<Variable<Object>> variables = <Variable<Object>>[
      Variable<int>(now.millisecondsSinceEpoch),
    ];
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
   ${_bookFilter(active: bookId != null)}''',
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
    if (bookId != null) variables.add(Variable<String>(bookId));
    final QueryRow row = await db
        .customSelect(
          '''
SELECT COUNT(*) AS c
  FROM words w
  $_stateJoin
 WHERE w.deleted_at IS NULL
   AND (ls.stage IS NULL OR ls.stage = 0)
   ${_bookFilter(active: bookId != null)}''',
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
    SpecialReview special = SpecialReview.none,
  }) async {
    if (special != SpecialReview.none) {
      final List<WordWithState> words = await specialWords(
        kind: special,
        now: now,
        bookId: bookId,
        limit: reviewLimit <= 0 ? 1 : reviewLimit,
      );
      return StudyQueue(
        cards: words
            .map(
              (WordWithState w) => StudyCard(
                word: w.word,
                withState: w,
                type: ReviewType.review,
              ),
            )
            .toList(growable: true),
        newAvailable: 0,
        newQueued: 0,
        reviewAvailable: words.length,
        backlog: 0,
        mode: StudyMode.special,
      );
    }

    final int dueTotal = await dueCount(now: now, bookId: bookId);
    final int unlearnedTotal = await newWordCount(bookId: bookId);
    final int newQuota = mode == StudyMode.reviewOnly
        ? 0
        : math.min(newLimit.clamp(0, 1 << 30), unlearnedTotal);

    final List<StudyCard> cards = <StudyCard>[];

    if (mode != StudyMode.reviewOnly && newQuota > 0) {
      final List<WordWithState> fresh = await newWords(
        bookId: bookId,
        limit: newQuota,
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
      newAvailable: unlearnedTotal,
      newQueued: newQuota,
      reviewAvailable: dueTotal,
      backlog: math.max(0, dueTotal - allowedReviews),
      mode: mode,
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
    String mode = ReviewEventMode.normal,
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

      final LearningSnapshot snapshot = _snapshotOf(state);

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
              mode: Value<String>(mode),
            ),
          );

      await _writeState(
        wordId: wordId,
        snapshot: _snapshotOfOutcome(outcome),
        lastStudiedAt: now,
        nextReviewAt: outcome.nextReviewAt,
        now: now,
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

  /// Manual "mark as mastered": recorded as an explicit `known` review event so
  /// the action is syncable and survives a later rebuild. It is never a direct
  /// write to the derived state — a merge would otherwise revert it.
  Future<void> markMastered({
    required String wordId,
    required String deviceId,
    required DateTime now,
    required String eventId,
  }) async {
    await recordAnswer(
      wordId: wordId,
      result: AnswerResult.known,
      type: ReviewType.review,
      eventId: eventId,
      deviceId: deviceId,
      now: now,
      mode: ReviewEventMode.manualMastered,
    );
  }

  /// Manual "reset progress": records a reset event and rebuilds the state from
  /// the remaining history. The reset event itself carries no answer, so replay
  /// starts from a blank snapshot at that timestamp.
  Future<void> resetProgress({
    required String wordId,
    required String deviceId,
    required DateTime now,
    required String eventId,
  }) async {
    await db.transaction(() async {
      await db
          .into(db.reviewEvents)
          .insert(
            ReviewEventsCompanion.insert(
              id: eventId,
              wordId: wordId,
              deviceId: deviceId,
              answeredAt: now.millisecondsSinceEpoch,
              localDay: _dayKey(now),
              result: AnswerResult.unknown.code,
              type: ReviewType.study.code,
              algoVersion: Value<int>(StudyScheduler.algorithmVersion),
              mode: const Value<String>(ReviewEventMode.reset),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await rebuildStateFromEvents(wordId);
    });
  }

  /// Replays the whole history of [wordId] to recompute its state. Used after
  /// merging an imported backup, where the event log is authoritative.
  ///
  /// Ordering is deterministic: `(answeredAt, deviceId, id)`. Two devices can
  /// produce the same millisecond timestamp; without a total order a rebuild
  /// could produce different results on each device.
  Future<void> rebuildStateFromEvents(String wordId) async {
    final List<ReviewEvent> events =
        await (db.select(db.reviewEvents)
              ..where((t) => t.wordId.equals(wordId))
              ..orderBy(<OrderClauseGenerator<$ReviewEventsTable>>[
                (t) => OrderingTerm(expression: t.answeredAt),
                (t) => OrderingTerm(expression: t.deviceId),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();

    LearningSnapshot snapshot = const LearningSnapshot.empty();
    DateTime? lastStudiedAt;
    DateTime? nextReviewAt;
    bool hasProgress = false;

    for (final ReviewEvent event in events) {
      if (ReviewEventMode.isReset(event.mode)) {
        snapshot = const LearningSnapshot.empty();
        lastStudiedAt = null;
        nextReviewAt = null;
        hasProgress = false;
        continue;
      }
      final ScheduleOutcome outcome = scheduler.schedule(
        current: snapshot,
        result: AnswerResult.fromCode(event.result),
        now: DateTime.fromMillisecondsSinceEpoch(event.answeredAt, isUtc: true),
        type: ReviewType.fromCode(event.type),
      );
      snapshot = _snapshotOfOutcome(outcome);
      lastStudiedAt = DateTime.fromMillisecondsSinceEpoch(
        event.answeredAt,
        isUtc: true,
      );
      nextReviewAt = outcome.nextReviewAt;
      hasProgress = true;
    }

    if (!hasProgress) {
      await (db.delete(
        db.learningStates,
      )..where((t) => t.wordId.equals(wordId))).go();
      return;
    }

    await _writeState(
      wordId: wordId,
      snapshot: snapshot,
      lastStudiedAt: lastStudiedAt,
      nextReviewAt: nextReviewAt,
      now: DateTime.now(),
    );
  }

  Future<void> _writeState({
    required String wordId,
    required LearningSnapshot snapshot,
    required DateTime? lastStudiedAt,
    required DateTime? nextReviewAt,
    required DateTime now,
  }) async {
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
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
  }

  LearningSnapshot _snapshotOf(LearningState? state) => state == null
      ? const LearningSnapshot.empty()
      : LearningSnapshot(
          stage: StudyStage.fromCode(state.stage),
          correctCount: state.correctCount,
          hazyCount: state.hazyCount,
          wrongCount: state.wrongCount,
          streak: state.streak,
          intervalDays: state.intervalDays,
        );

  LearningSnapshot _snapshotOfOutcome(ScheduleOutcome outcome) =>
      LearningSnapshot(
        stage: outcome.stage,
        correctCount: outcome.correctCount,
        hazyCount: outcome.hazyCount,
        wrongCount: outcome.wrongCount,
        streak: outcome.streak,
        intervalDays: outcome.intervalDays,
      );

  // ------------------------------------------------------------- progress

  Future<int> todayCount({
    required DateTime now,
    required ReviewType type,
  }) async {
    final QueryRow row = await db
        .customSelect(
          '''
SELECT COUNT(DISTINCT re.word_id) AS c
  FROM review_events re
  JOIN words w ON w.id = re.word_id
 WHERE re.local_day = ? AND re.type = ? AND w.deleted_at IS NULL
   AND re.mode != ?''',
          variables: <Variable<Object>>[
            Variable<String>(_dayKey(now)),
            Variable<String>(type.code),
            const Variable<String>(ReviewEventMode.reset),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.reviewEvents,
            db.words,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// Everything the dashboard needs, derived from real rows only.
  Future<TodayProgress> todayProgress({
    required DateTime now,
    required int newTarget,
    required int reviewLimit,
    String? bookId,
  }) async {
    final int newDone = await todayCount(now: now, type: ReviewType.study);
    final int reviewDone = await todayCount(now: now, type: ReviewType.review);
    final int unlearned = await newWordCount(bookId: bookId);
    final int due = await dueCount(now: now, bookId: bookId);

    final int newAllowance = math.max(0, newTarget - newDone);
    final int reviewAllowance = math.max(0, reviewLimit - reviewDone);

    return TodayProgress(
      newGoal: newTarget,
      newDone: newDone,
      newRemainingAllowance: newAllowance,
      unlearnedTotal: unlearned,
      newAvailableToday: math.min(newAllowance, unlearned),
      reviewGoal: reviewLimit,
      reviewDone: reviewDone,
      reviewRemainingAllowance: reviewAllowance,
      dueTotal: due,
      reviewAvailableToday: math.min(reviewAllowance, due),
      backlog: math.max(0, due - reviewAllowance),
      learnedWords: await learnedCount(bookId: bookId),
      totalWords: await totalCount(bookId: bookId),
      hardWords: await hardWordCount(bookId: bookId),
      scopedToBook: bookId != null,
    );
  }

  Future<int> totalCount({String? bookId}) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    if (bookId != null) variables.add(Variable<String>(bookId));
    final QueryRow row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM words w '
          'WHERE w.deleted_at IS NULL ${_bookFilter(active: bookId != null)}',
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
    if (bookId != null) variables.add(Variable<String>(bookId));
    final QueryRow row = await db
        .customSelect(
          '''
SELECT COUNT(*) AS c
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL AND ls.stage != 0
   ${_bookFilter(active: bookId != null)}''',
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
    if (bookId != null) variables.add(Variable<String>(bookId));
    final QueryRow row = await db
        .customSelect(
          '''
SELECT COUNT(*) AS c
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL AND (ls.wrong_count + ls.hazy_count) >= 2
   ${_bookFilter(active: bookId != null)}''',
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
   ${_bookFilter(active: bookId != null)}
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
    final List<Variable<Object>> variables = <Variable<Object>>[];
    String bookClause = '';
    if (bookId != null) {
      bookClause = 'AND $_activeEntry';
      variables.add(Variable<String>(bookId));
    }
    final QueryRow totals = await db
        .customSelect(
          '''
SELECT COALESCE(SUM(ls.correct_count), 0) AS correct,
       COALESCE(SUM(ls.hazy_count), 0)    AS hazy,
       COALESCE(SUM(ls.wrong_count), 0)   AS wrong
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL
 $bookClause''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
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
      scopedToBook: bookId != null,
    );
  }

  // ------------------------------------------------------ word management

  String _managedWhere({
    required String? search,
    required String? bookId,
    required ManagedStageFilter stage,
    required List<Variable<Object>> variables,
  }) {
    final StringBuffer where = StringBuffer('w.deleted_at IS NULL');
    if (bookId != null) {
      where.write(' AND $_activeEntry');
      variables.add(Variable<String>(bookId));
    }
    switch (stage) {
      case ManagedStageFilter.all:
        break;
      case ManagedStageFilter.unlearned:
        where.write(' AND (ls.stage IS NULL OR ls.stage = 0)');
      case ManagedStageFilter.learning:
        where.write(' AND ls.stage = ${StudyStage.learning.code}');
      case ManagedStageFilter.review:
        where.write(' AND ls.stage = ${StudyStage.review.code}');
      case ManagedStageFilter.relearning:
        where.write(' AND ls.stage = ${StudyStage.relearning.code}');
      case ManagedStageFilter.hard:
        where.write(' AND (ls.wrong_count + ls.hazy_count) > 0');
      case ManagedStageFilter.mastered:
        where.write(
          ' AND ls.stage != 0 AND ls.interval_days >= '
          '${StudyScheduler.ladderDays.last}',
        );
    }
    final String needle = (search ?? '').trim();
    if (needle.isNotEmpty) {
      final String like = '%${needle.toLowerCase()}%';
      where.write(
        ' AND (w.normalized LIKE ? OR w.translation LIKE ? OR w.note LIKE ?)',
      );
      variables
        ..add(Variable<String>(like))
        ..add(Variable<String>(like))
        ..add(Variable<String>(like));
    }
    return where.toString();
  }

  String _managedOrder(ManagedSort sort) => switch (sort) {
    ManagedSort.addedDesc => 'ORDER BY w.created_at DESC, w.normalized',
    ManagedSort.alpha => 'ORDER BY w.normalized',
    ManagedSort.wrongDesc =>
      'ORDER BY (COALESCE(ls.wrong_count, 0) + COALESCE(ls.hazy_count, 0)) DESC, '
          'w.normalized',
    ManagedSort.lastStudiedDesc =>
      'ORDER BY CASE WHEN ls.last_studied_at IS NULL THEN -1 '
          'ELSE ls.last_studied_at END DESC, w.normalized',
  };

  /// One page of the word-management list (user words, not the dictionary).
  Future<List<ManagedWord>> managedWords({
    String? bookId,
    String search = '',
    ManagedStageFilter stage = ManagedStageFilter.all,
    ManagedSort sort = ManagedSort.addedDesc,
    int limit = 200,
    int offset = 0,
  }) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    final String where = _managedWhere(
      search: search,
      bookId: bookId,
      stage: stage,
      variables: variables,
    );
    variables
      ..add(Variable<int>(limit))
      ..add(Variable<int>(offset));
    final List<QueryRow> rows = await db
        .customSelect(
          '''
SELECT $wordColumnsWithState,
       (SELECT COUNT(*) FROM word_book_entries e
         WHERE e.word_id = w.id AND e.deleted_at IS NULL) AS book_count
  FROM words w
  $_stateJoin
 WHERE $where
 ${_managedOrder(sort)}
 LIMIT ? OFFSET ?''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .get();
    return rows
        .map((QueryRow row) {
          final LearningState? state = learningStateFromRow(row);
          final int answers =
              (state?.correctCount ?? 0) +
              (state?.hazyCount ?? 0) +
              (state?.wrongCount ?? 0);
          return ManagedWord(
            word: wordFromRow(row),
            state: state,
            bookCount: row.read<int>('book_count'),
            answerCount: answers,
            errorRate: answers == 0 ? null : (state!.wrongCount / answers),
            nextReviewAt: state?.nextReviewAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    state!.nextReviewAt!,
                    isUtc: true,
                  ).toLocal(),
            lastStudiedAt: state?.lastStudiedAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    state!.lastStudiedAt!,
                    isUtc: true,
                  ).toLocal(),
          );
        })
        .toList(growable: false);
  }

  Future<int> managedCount({
    String? bookId,
    String search = '',
    ManagedStageFilter stage = ManagedStageFilter.all,
  }) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    final String where = _managedWhere(
      search: search,
      bookId: bookId,
      stage: stage,
      variables: variables,
    );
    final QueryRow row = await db
        .customSelect(
          '''
SELECT COUNT(*) AS c
  FROM words w
  $_stateJoin
 WHERE $where''',
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

  Future<ManagedWord?> managedWord(String wordId) async {
    final List<QueryRow> rows = await db
        .customSelect(
          '''
SELECT $wordColumnsWithState,
       (SELECT COUNT(*) FROM word_book_entries e
         WHERE e.word_id = w.id AND e.deleted_at IS NULL) AS book_count
  FROM words w
  $_stateJoin
 WHERE w.id = ? AND w.deleted_at IS NULL
 LIMIT 1''',
          variables: <Variable<Object>>[Variable<String>(wordId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .get();
    if (rows.isEmpty) return null;
    final QueryRow row = rows.first;
    final LearningState? state = learningStateFromRow(row);
    final int answers =
        (state?.correctCount ?? 0) +
        (state?.hazyCount ?? 0) +
        (state?.wrongCount ?? 0);
    return ManagedWord(
      word: wordFromRow(row),
      state: state,
      bookCount: row.read<int>('book_count'),
      answerCount: answers,
      errorRate: answers == 0 ? null : (state!.wrongCount / answers),
      nextReviewAt: state?.nextReviewAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              state!.nextReviewAt!,
              isUtc: true,
            ).toLocal(),
      lastStudiedAt: state?.lastStudiedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              state!.lastStudiedAt!,
              isUtc: true,
            ).toLocal(),
    );
  }

  /// Clears progress for [wordIds] by appending one reset event per word, then
  /// rebuilding. Keeps the answer history (auditable) while the word goes back
  /// to "unlearned".
  Future<int> resetProgressBatch({
    required Iterable<String> wordIds,
    required String deviceId,
    required DateTime now,
    required String Function(String wordId) eventIdFor,
  }) async {
    int count = 0;
    for (final String wordId in wordIds.toList(growable: false)) {
      await resetProgress(
        wordId: wordId,
        deviceId: deviceId,
        now: now,
        eventId: eventIdFor(wordId),
      );
      count++;
    }
    return count;
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

/// Exposed for tests that need to assert the normalisation rule without
/// importing the text helper directly.
bool studyTextNeedsNormalization(String value) =>
    needsDictionaryNormalization(value);
