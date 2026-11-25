import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/row_mappers.dart';
import '../models/enums.dart';
import '../models/study_models.dart';
import '../repositories/word_repository.dart';
import '../text/dictionary_text.dart';
import '../time_utils.dart';
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
      'JOIN word_books scope_book ON scope_book.id = e.word_book_id AND scope_book.deleted_at IS NULL '
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
    if (kind == SpecialReview.favorites) {
      final rows = await managedWords(
        bookId: bookId,
        favoritesOnly: true,
        sort: ManagedSort.alpha,
        limit: limit,
      );
      return rows
          .map(
            (r) => WordWithState(
              word: r.word,
              state: r.state,
              bookCount: r.bookCount,
            ),
          )
          .toList();
    }
    if (kind == SpecialReview.none) {
      return const <WordWithState>[];
    }
    final List<Variable<Object>> variables = <Variable<Object>>[];
    String filter;
    String order;
    switch (kind) {
      case SpecialReview.hard:
        filter = 'AND (ls.wrong_count + ls.hazy_count) > 0';
        order = 'ORDER BY ls.wrong_count DESC, ls.hazy_count DESC, w.normalized, w.id';
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
            'WHERE re2.word_id = w.id AND re2.result = 0) DESC, w.normalized, w.id';
      case SpecialReview.inBook:
        filter = 'AND ls.stage != 0';
        order = 'ORDER BY ls.next_review_at ASC, w.normalized, w.id';
      case SpecialReview.none:
      case SpecialReview.favorites:
      case SpecialReview.sessionMistakes:
      case SpecialReview.sprint:
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

  /// Candidate words for a practice drill, plus a distractor pool.
  ///
  /// Only words with a Chinese meaning can be drilled (it is the prompt), and a
  /// cloze exercise additionally requires the word to appear in its own example
  /// sentence — examples are never invented to fill a gap. Words the user has
  /// already answered come first (most recent, then hardest); never-answered
  /// words fill up the rest so a fresh library is not a dead end.
  Future<PracticeBatch> practiceBatch({
    required DateTime now,
    String? bookId,
    PracticeKind kind = PracticeKind.spelling,
    int limit = 20,
  }) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    if (bookId != null) variables.add(Variable<String>(bookId));
    variables.add(Variable<int>(math.max(limit * 6, 60)));
    final List<QueryRow> rows = await db
        .customSelect(
          '''
SELECT $wordColumnsWithState
  FROM words w
  $_stateJoin
 WHERE w.deleted_at IS NULL
   AND w.translation != ''
   ${_bookFilter(active: bookId != null)}
 ORDER BY CASE WHEN ls.last_studied_at IS NULL THEN 1 ELSE 0 END,
          ls.last_studied_at DESC,
          (COALESCE(ls.wrong_count, 0) * 2 + COALESCE(ls.hazy_count, 0)) DESC,
          w.normalized
 LIMIT ?''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .get();
    final pool = _toWordWithState(rows).map((row) => row.word).toList();
    final eligible = kind == PracticeKind.cloze
        ? pool.where((Word w) => clozeSentenceFor(w) != null).toList()
        : pool;
    final words = eligible.take(limit).toList();
    // The distractor pool is the whole candidate set: a word that is drilled
    // later in the same round is still a perfectly good wrong option now.
    return PracticeBatch(kind: kind, words: words, pool: pool);
  }

  /// The sentence used by a cloze drill: the word's own example if it really
  /// contains the word (word-boundary, case-insensitive). Returns null when
  /// there is no usable example, in which case the drill skips the word instead
  /// of fabricating data.
  static String? clozeSentenceFor(Word word) {
    final String example = word.example.trim();
    if (example.isEmpty || word.word.trim().isEmpty) return null;
    final RegExp pattern = RegExp(
      '(?<![A-Za-z])${RegExp.escape(word.word.trim())}(?![A-Za-z])',
      caseSensitive: false,
    );
    return pattern.hasMatch(example) ? example : null;
  }

  Future<DateTime?> nextDueAfter(DateTime now) async {
    final row = await db
        .customSelect(
          'SELECT MIN(ls.next_review_at) AS due '
          'FROM learning_states ls JOIN words w ON w.id = ls.word_id '
          'WHERE w.deleted_at IS NULL AND ls.stage != 0 AND ls.next_review_at > ?',
          variables: [Variable<int>(now.millisecondsSinceEpoch)],
          readsFrom: {db.words, db.learningStates},
        )
        .getSingle();
    final millis = row.readNullable<int>('due');
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
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

  Future<int> _nextCausalOrder(String wordId) async {
    final column = db.reviewEvents.causalOrder.max();
    final query = db.selectOnly(db.reviewEvents)
      ..addColumns([column])
      ..where(db.reviewEvents.wordId.equals(wordId));
    return ((await query.getSingle()).read(column) ?? 0) + 1;
  }

  Future<bool> hasManualMastery(String wordId) async {
    final event =
        await (db.select(db.reviewEvents)
              ..where(
                (t) =>
                    t.wordId.equals(wordId) &
                    t.mode.isIn([
                      ReviewEventMode.manualMastered,
                      ReviewEventMode.manualUnmastered,
                      ReviewEventMode.reset,
                    ]),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.causalOrder),
                (t) => OrderingTerm.desc(t.answeredAt),
                (t) => OrderingTerm.desc(t.deviceId),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    return event?.mode == ReviewEventMode.manualMastered;
  }

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

      final word =
          await (db.select(db.words)
                ..where((t) => t.id.equals(wordId) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (word == null) throw StateError('词条已删除，请返回列表刷新');

      final LearningState? state = await (db.select(
        db.learningStates,
      )..where((t) => t.wordId.equals(wordId))).getSingleOrNull();

      final LearningSnapshot snapshot = _snapshotOf(state);

      final ScheduleOutcome outcome = _scheduleEvent(
        current: snapshot,
        result: result,
        now: now,
        type: type,
        mode: mode,
        algorithmVersion: StudyScheduler.algorithmVersion,
        dayStart: startOfLocalDay(now),
        previousNext: state?.nextReviewAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                state!.nextReviewAt!,
                isUtc: true,
              ),
      );

      final causalOrder = await _nextCausalOrder(wordId);
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
              causalOrder: Value(causalOrder),
              dayStartUtc: Value(startOfLocalDay(now).millisecondsSinceEpoch),
              dayStartSource: const Value('authored'),
            ),
          );

      if (ReviewEventMode.isManagement(mode)) {
        await rebuildStateFromEvents(wordId);
        final restored = await (db.select(
          db.learningStates,
        )..where((t) => t.wordId.equals(wordId))).getSingleOrNull();
        return AnswerRecord(
          eventId: eventId,
          duplicate: false,
          stage: StudyStage.fromCode(restored?.stage ?? 0),
          nextReviewAt: restored?.nextReviewAt == null
              ? now
              : DateTime.fromMillisecondsSinceEpoch(
                  restored!.nextReviewAt!,
                  isUtc: true,
                ),
          intervalDays: restored?.intervalDays ?? 0,
          repeatInSession: false,
        );
      }
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

  Future<void> unmarkMastered({
    required String wordId,
    required String deviceId,
    required DateTime now,
    required String eventId,
  }) async {
    await recordAnswer(
      wordId: wordId,
      deviceId: deviceId,
      now: now,
      eventId: eventId,
      result: AnswerResult.known,
      type: ReviewType.review,
      mode: ReviewEventMode.manualUnmastered,
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
              causalOrder: Value(await _nextCausalOrder(wordId)),
              dayStartUtc: Value(startOfLocalDay(now).millisecondsSinceEpoch),
              dayStartSource: const Value('authored'),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await rebuildStateFromEvents(wordId);
    });
  }

  /// Replays the whole history of [wordId] to recompute its state. Used after
  /// merging an imported backup, where the event log is authoritative.
  ///
  /// Ordering is deterministic: `(causalOrder, answeredAt, deviceId, id)`. Two devices can
  /// produce the same millisecond timestamp; without a total order a rebuild
  /// could produce different results on each device.
  Future<void> rebuildStateFromEvents(String wordId) async {
    final List<ReviewEvent> events =
        await (db.select(db.reviewEvents)
              ..where((t) => t.wordId.equals(wordId))
              ..orderBy(<OrderClauseGenerator<$ReviewEventsTable>>[
                (t) => OrderingTerm(expression: t.causalOrder),
                (t) => OrderingTerm(expression: t.answeredAt),
                (t) => OrderingTerm(expression: t.deviceId),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();

    LearningSnapshot snapshot = const LearningSnapshot.empty();
    DateTime? lastStudiedAt;
    DateTime? nextReviewAt;
    bool hasProgress = false;

    final Set<String> undone = events
        .where((e) => e.mode.startsWith(ReviewEventMode.undoPrefix))
        .map((e) => e.mode.substring(ReviewEventMode.undoPrefix.length))
        .toSet();
    final revokedMastery = <String>{};
    final pendingMastery = <String>{};
    for (final event in events) {
      if (undone.contains(event.id)) continue;
      if (event.mode == ReviewEventMode.manualMastered) {
        pendingMastery.add(event.id);
      }
      if (event.mode == ReviewEventMode.manualUnmastered) {
        revokedMastery.addAll(pendingMastery);
        pendingMastery.clear();
      }
    }
    for (final ReviewEvent event in events) {
      if (undone.contains(event.id) ||
          revokedMastery.contains(event.id) ||
          event.mode == ReviewEventMode.manualUnmastered ||
          event.mode.startsWith(ReviewEventMode.undoPrefix)) {
        continue;
      }
      if (event.mode == ReviewEventMode.manualMastered) {
        snapshot = LearningSnapshot(
          stage: StudyStage.review,
          correctCount: snapshot.correctCount,
          hazyCount: snapshot.hazyCount,
          wrongCount: snapshot.wrongCount,
          streak: snapshot.streak,
          intervalDays: 30,
        );
        nextReviewAt = DateTime.fromMillisecondsSinceEpoch(
          event.answeredAt,
          isUtc: true,
        ).add(const Duration(days: 30));
        hasProgress = true;
        continue;
      }
      if (ReviewEventMode.isReset(event.mode)) {
        snapshot = const LearningSnapshot.empty();
        lastStudiedAt = null;
        nextReviewAt = null;
        hasProgress = false;
        continue;
      }
      final ScheduleOutcome outcome = _scheduleEvent(
        current: snapshot,
        result: AnswerResult.fromCode(event.result),
        now: DateTime.fromMillisecondsSinceEpoch(event.answeredAt, isUtc: true),
        type: ReviewType.fromCode(event.type),
        mode: event.mode,
        algorithmVersion: event.algoVersion,
        dayStart: event.dayStartUtc == null
            ? DateTime.fromMillisecondsSinceEpoch(
                event.answeredAt ~/ 86400000 * 86400000,
                isUtc: true,
              )
            : DateTime.fromMillisecondsSinceEpoch(
                event.dayStartUtc!,
                isUtc: true,
              ),
        previousNext: nextReviewAt,
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
      now: DateTime.fromMillisecondsSinceEpoch(
        events.last.answeredAt,
        isUtc: true,
      ),
    );
  }

  ScheduleOutcome _scheduleEvent({
    required LearningSnapshot current,
    required AnswerResult result,
    required DateTime now,
    required ReviewType type,
    required String mode,
    required int algorithmVersion,
    DateTime? previousNext,
    DateTime? dayStart,
  }) {
    if (mode == ReviewEventMode.manualMastered) {
      return ScheduleOutcome(
        stage: StudyStage.review,
        correctCount: current.correctCount,
        hazyCount: current.hazyCount,
        wrongCount: current.wrongCount,
        streak: current.streak,
        intervalDays: 30,
        nextReviewAt: now.add(const Duration(days: 30)),
        repeatInSession: false,
      );
    }
    if (ReviewEventMode.isPractice(mode)) {
      // A drill is a real answer — recorded, undoable, synced and counted — but
      // it must not act as a long-term recall measurement. Stage, interval and
      // next-review date stay exactly as they were; only the per-result counters
      // move, so accuracy and the hard-word ranking still reflect what happened.
      return ScheduleOutcome(
        stage: current.stage,
        correctCount:
            current.correctCount + (result == AnswerResult.known ? 1 : 0),
        hazyCount: current.hazyCount + (result == AnswerResult.hazy ? 1 : 0),
        wrongCount:
            current.wrongCount + (result == AnswerResult.unknown ? 1 : 0),
        streak: current.streak,
        intervalDays: current.intervalDays,
        nextReviewAt: previousNext ?? now,
        repeatInSession: false,
      );
    }
    final outcome = scheduler.schedule(
      current: current,
      result: result,
      now: now,
      type: type,
      dayStart: dayStart,
    );
    final practice =
        mode == ReviewEventMode.repeat ||
        mode.startsWith('special-') ||
        mode.startsWith('practice-') ||
        mode == 'sprint';
    if (algorithmVersion >= 2 &&
        practice &&
        result == AnswerResult.known &&
        current.intervalDays > 0) {
      return ScheduleOutcome(
        stage: current.stage,
        correctCount: outcome.correctCount,
        hazyCount: outcome.hazyCount,
        wrongCount: outcome.wrongCount,
        streak: current.streak,
        intervalDays: current.intervalDays,
        nextReviewAt: previousNext ?? outcome.nextReviewAt,
        repeatInSession: false,
      );
    }
    return outcome;
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

  static String _realAnswer(String alias) =>
      "$alias.mode NOT IN ('reset', 'manual-mastered', 'manual-unmastered') "
      "AND $alias.mode NOT LIKE 'undo:%' "
      "AND NOT EXISTS (SELECT 1 FROM review_events undo "
      "WHERE undo.mode = 'undo:' || $alias.id AND undo.word_id = $alias.word_id)";

  static String realAnswerFilter(String alias) => _realAnswer(alias);

  Future<void> undoAnswer({
    required String eventId,
    required String undoId,
    required String deviceId,
    required DateTime now,
  }) async {
    await db.transaction(() async {
      final event = await (db.select(
        db.reviewEvents,
      )..where((t) => t.id.equals(eventId))).getSingleOrNull();
      if (event == null || ReviewEventMode.isManagement(event.mode)) {
        throw StateError('没有可撤销的作答');
      }
      await db
          .into(db.reviewEvents)
          .insert(
            ReviewEventsCompanion.insert(
              id: undoId,
              wordId: event.wordId,
              deviceId: deviceId,
              answeredAt: now.millisecondsSinceEpoch,
              localDay: _dayKey(now),
              result: 0,
              type: event.type,
              mode: Value('undo:$eventId'),
              causalOrder: Value(await _nextCausalOrder(event.wordId)),
              algoVersion: const Value(StudyScheduler.algorithmVersion),
              dayStartUtc: Value(startOfLocalDay(now).millisecondsSinceEpoch),
              dayStartSource: const Value('authored'),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await rebuildStateFromEvents(event.wordId);
    });
  }

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
   AND ${_realAnswer('re')}
   AND (re.mode = ? OR (re.type = 'review' AND re.mode LIKE 'special-%'))''',
          variables: <Variable<Object>>[
            Variable<String>(_dayKey(now)),
            Variable<String>(type.code),
            const Variable<String>(ReviewEventMode.normal),
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
SELECT COALESCE(SUM(CASE WHEN re.result = 2 THEN 1 ELSE 0 END), 0) AS correct,
       COALESCE(SUM(CASE WHEN re.result = 1 THEN 1 ELSE 0 END), 0) AS hazy,
       COALESCE(SUM(CASE WHEN re.result = 0 THEN 1 ELSE 0 END), 0) AS wrong
  FROM words w
  JOIN review_events re ON re.word_id = w.id
 WHERE w.deleted_at IS NULL AND ${_realAnswer('re')}
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

    // Real answers split by source: normal sessions, the explicit special
    // queues, the practice drills and same-round repeats. Management events and
    // undone answers are excluded by `_realAnswer`.
    final List<QueryRow> modeRows = await db
        .customSelect(
          '''
SELECT CASE
         WHEN re.mode LIKE 'practice-%' THEN 'practice'
         WHEN re.mode = 'repeat' THEN 'repeat'
         WHEN re.mode LIKE 'special-%' THEN 'special'
         ELSE 'normal'
       END AS bucket,
       re.mode AS mode,
       COUNT(*) AS total
  FROM words w
  JOIN review_events re ON re.word_id = w.id
 WHERE w.deleted_at IS NULL AND ${_realAnswer('re')}
 $bookClause
 GROUP BY bucket, re.mode''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.reviewEvents,
          },
        )
        .get();
    int normal = 0, special = 0, practice = 0, repeat = 0;
    final Map<PracticeKind, int> practiceByKind = <PracticeKind, int>{};
    for (final QueryRow row in modeRows) {
      final int total = row.read<int>('total');
      switch (row.read<String>('bucket')) {
        case 'practice':
          practice += total;
          final String mode = row.read<String>('mode');
          final PracticeKind kind = PracticeKind.fromCode(
            mode.substring(ReviewEventMode.practicePrefix.length),
          );
          practiceByKind[kind] = (practiceByKind[kind] ?? 0) + total;
        case 'repeat':
          repeat += total;
        case 'special':
          special += total;
        default:
          normal += total;
      }
    }

    final QueryRow distinctRow = await db
        .customSelect(
          '''
SELECT COUNT(DISTINCT re.word_id) AS c
  FROM words w
  JOIN review_events re ON re.word_id = w.id
 WHERE w.deleted_at IS NULL AND ${_realAnswer('re')}
 $bookClause''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.reviewEvents,
          },
        )
        .getSingle();

    final QueryRow undoRow = await db
        .customSelect(
          '''
SELECT COUNT(*) AS c
  FROM words w
  JOIN review_events undo ON undo.word_id = w.id
 WHERE w.deleted_at IS NULL AND undo.mode LIKE 'undo:%'
 $bookClause''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.reviewEvents,
          },
        )
        .getSingle();

    final List<Variable<Object>> trendVariables = <Variable<Object>>[
      ...variables,
    ];
    trendVariables.insert(
      0,
      Variable<String>(_dayKey(now.subtract(const Duration(days: 29)))),
    );
    final List<QueryRow> trendRows = await db
        .customSelect(
          '''
SELECT re.local_day AS day,
       COUNT(*) AS answers,
       COALESCE(SUM(CASE WHEN re.result = 2 THEN 1 ELSE 0 END), 0) AS correct
  FROM words w
  JOIN review_events re ON re.word_id = w.id
 WHERE w.deleted_at IS NULL AND ${_realAnswer('re')}
   AND re.local_day >= ?
 $bookClause
 GROUP BY re.local_day
 ORDER BY re.local_day''',
          variables: trendVariables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.reviewEvents,
          },
        )
        .get();
    final List<DailyAnswers> trend30 = <DailyAnswers>[
      for (final QueryRow row in trendRows)
        DailyAnswers(
          day: row.read<String>('day'),
          answers: row.read<int>('answers'),
          correct: row.read<int>('correct'),
        ),
    ];
    final Set<String> lastSeven = <String>{
      for (int i = 0; i < 7; i++) _dayKey(now.subtract(Duration(days: 6 - i))),
    };

    final QueryRow todayRow = await db
        .customSelect(
          '''
SELECT COUNT(*) AS answers,
       COALESCE(SUM(CASE WHEN re.result = 2 THEN 1 ELSE 0 END), 0) AS correct
  FROM words w
  JOIN review_events re ON re.word_id = w.id
 WHERE w.deleted_at IS NULL AND ${_realAnswer('re')}
   AND re.local_day = ?
 $bookClause''',
          variables: <Variable<Object>>[
            Variable<String>(_dayKey(now)),
            ...variables,
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
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
      todayAnswers: todayRow.read<int>('answers'),
      todayCorrect: todayRow.read<int>('correct'),
      distinctAnsweredWords: distinctRow.read<int>('c'),
      undoneAnswers: undoRow.read<int>('c'),
      breakdown: AnswerBreakdown(
        normal: normal,
        special: special,
        practice: practice,
        repeat: repeat,
        practiceByKind: practiceByKind,
      ),
      trend30: trend30,
      trend7: trend30
          .where((DailyAnswers d) => lastSeven.contains(d.day))
          .toList(),
      dueForecast: await _dueForecast(now: now, bookId: bookId),
    );
  }

  /// Words falling due on each of the next seven local days (today included).
  /// Local-day buckets are computed in Dart from the stored UTC instants so a
  /// timezone change cannot shift a whole column sideways.
  Future<List<DueForecastDay>> _dueForecast({
    required DateTime now,
    String? bookId,
  }) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    if (bookId != null) variables.add(Variable<String>(bookId));
    final List<QueryRow> rows = await db
        .customSelect(
          '''
SELECT ls.next_review_at AS due
  FROM words w
  JOIN learning_states ls ON ls.word_id = w.id
 WHERE w.deleted_at IS NULL AND ls.stage != 0 AND ls.next_review_at IS NOT NULL
 ${_bookFilter(active: bookId != null)}''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.words,
            db.learningStates,
            db.wordBookEntries,
          },
        )
        .get();
    final DateTime start = startOfLocalDay(now);
    final List<DueForecastDay> forecast = <DueForecastDay>[
      for (int i = 0; i < 7; i++)
        DueForecastDay(day: _dayKey(start.add(Duration(days: i))), count: 0),
    ];
    final Map<String, int> index = <String, int>{
      for (int i = 0; i < forecast.length; i++) forecast[i].day: i,
    };
    for (final QueryRow row in rows) {
      final int due = row.read<int>('due');
      final int? slot =
          index[_dayKey(DateTime.fromMillisecondsSinceEpoch(due))];
      if (slot == null) continue;
      forecast[slot] = DueForecastDay(
        day: forecast[slot].day,
        count: forecast[slot].count + 1,
      );
    }
    return forecast;
  }

  // ------------------------------------------------------ word management

  String _managedWhere({
    required String? search,
    required String? bookId,
    bool favoritesOnly = false,
    String? tagId,
    required ManagedStageFilter stage,
    required List<Variable<Object>> variables,
  }) {
    final StringBuffer where = StringBuffer('w.deleted_at IS NULL');
    if (bookId != null) {
      where.write(' AND $_activeEntry');
      variables.add(Variable<String>(bookId));
    }
    if (favoritesOnly) {
      where.write(
        ' AND EXISTS (SELECT 1 FROM word_favorites f WHERE f.word_id = w.id AND f.value = 1)',
      );
    }
    if (tagId != null) {
      where.write(
        ' AND EXISTS (SELECT 1 FROM word_tags wt JOIN user_tags t ON t.id = wt.tag_id WHERE wt.word_id = w.id AND wt.tag_id = ? AND wt.deleted_at IS NULL AND t.deleted_at IS NULL)',
      );
      variables.add(Variable<String>(tagId));
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
        ' AND (w.normalized LIKE ? OR w.translation LIKE ? OR w.note LIKE ?'
        ' OR EXISTS (SELECT 1 FROM word_tags wt JOIN user_tags t ON t.id = wt.tag_id'
        ' WHERE wt.word_id = w.id AND wt.deleted_at IS NULL AND t.deleted_at IS NULL AND t.normalized LIKE ?))',
      );
      variables
        ..add(Variable<String>(like))
        ..add(Variable<String>(like))
        ..add(Variable<String>(like))
        ..add(Variable<String>(like));
    }
    return where.toString();
  }

  String _managedOrder(ManagedSort sort) => switch (sort) {
    ManagedSort.addedDesc => 'ORDER BY w.created_at DESC, w.normalized, w.id',
    ManagedSort.alpha => 'ORDER BY w.normalized, w.id',
    ManagedSort.wrongDesc =>
      'ORDER BY (COALESCE(ls.wrong_count, 0) + COALESCE(ls.hazy_count, 0)) DESC, '
          'w.normalized, w.id',
    ManagedSort.lastStudiedDesc =>
      'ORDER BY CASE WHEN ls.last_studied_at IS NULL THEN -1 '
          'ELSE ls.last_studied_at END DESC, w.normalized, w.id',
  };

  /// One page of the word-management list (user words, not the dictionary).
  Future<List<ManagedWord>> managedWords({
    String? bookId,
    bool favoritesOnly = false,
    String? tagId,
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
      favoritesOnly: favoritesOnly,
      tagId: tagId,
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
            db.wordFavorites,
            db.userTags,
            db.wordTags,
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

  /// IDs only: selecting a filtered library never loads definitions or event history.
  Future<List<String>> managedWordIds({
    String? bookId,
    bool favoritesOnly = false,
    String? tagId,
    String search = '',
    ManagedStageFilter stage = ManagedStageFilter.all,
  }) async {
    final variables = <Variable<Object>>[];
    final where = _managedWhere(
      search: search,
      bookId: bookId,
      favoritesOnly: favoritesOnly,
      tagId: tagId,
      stage: stage,
      variables: variables,
    );
    final rows = await db
        .customSelect(
          'SELECT w.id FROM words w $_stateJoin WHERE $where ORDER BY w.id',
          variables: variables,
          readsFrom: {
            db.words,
            db.learningStates,
            db.wordBookEntries,
            db.wordFavorites,
            db.userTags,
            db.wordTags,
          },
        )
        .get();
    return rows.map((row) => row.read<String>('id')).toList(growable: false);
  }

  Future<int> managedCount({
    String? bookId,
    bool favoritesOnly = false,
    String? tagId,
    String search = '',
    ManagedStageFilter stage = ManagedStageFilter.all,
  }) async {
    final List<Variable<Object>> variables = <Variable<Object>>[];
    final String where = _managedWhere(
      search: search,
      bookId: bookId,
      favoritesOnly: favoritesOnly,
      tagId: tagId,
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
            db.wordFavorites,
            db.userTags,
            db.wordTags,
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
    return db.transaction(() async {
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
    });
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
