import '../database/app_database.dart';
import '../models/enums.dart';
import '../repositories/word_repository.dart';

/// One card in a study or review session.
class StudyCard {
  const StudyCard({
    required this.word,
    required this.withState,
    required this.type,
    this.repeatCount = 0,
  });

  final Word word;
  final WordWithState withState;
  final ReviewType type;
  final int repeatCount;

  StudyCard copyWith({int? repeatCount}) => StudyCard(
    word: word,
    withState: withState,
    type: type,
    repeatCount: repeatCount ?? this.repeatCount,
  );
}

/// The queue the session will walk through.
class StudyQueue {
  const StudyQueue({
    required this.cards,
    required this.newAvailable,
    required this.reviewAvailable,
    required this.backlog,
    this.mode = StudyMode.mixed,
    this.newQueued = 0,
  });

  const StudyQueue.empty()
    : cards = const <StudyCard>[],
      newAvailable = 0,
      reviewAvailable = 0,
      backlog = 0,
      mode = StudyMode.mixed,
      newQueued = 0;

  final List<StudyCard> cards;

  /// Total number of words that have never been answered, in scope. This is the
  /// *stock* of available new words, not the number that fit into today's
  /// allowance (that is [newQueued]).
  final int newAvailable;

  /// New words actually placed in this queue after applying both the daily
  /// allowance and [newAvailable].
  final int newQueued;

  /// How many words were due (before applying the daily review limit).
  final int reviewAvailable;

  /// Due words that did not fit into today's review limit.
  final int backlog;

  final StudyMode mode;

  bool get isEmpty => cards.isEmpty;
}

/// Numbers shown on the dashboard.
///
/// The vocabulary is deliberately explicit, because "剩余新词 30" in an empty
/// library was the single most misleading number in phase 1:
///
///  * [newGoal]            — the daily new-word target (a *goal*, not a stock).
///  * [newDone]            — distinct new words already studied today.
///  * [newRemainingAllowance] — `newGoal - newDone`, floored at zero.
///  * [unlearnedTotal]     — words that have never been answered, in scope.
///  * [newAvailableToday]  — what the user can actually start now:
///                            `min(allowance, unlearnedTotal)`.
///  * [dueTotal]           — everything due right now, independent of limits.
///  * [reviewRemainingAllowance] — `reviewGoal - reviewDone`, floored at zero.
///  * [reviewAvailableToday] — `min(allowance, dueTotal)`.
///  * [backlog]            — `dueTotal - allowance` when positive: what carries
///                            over to tomorrow.
class TodayProgress {
  const TodayProgress({
    required this.newGoal,
    required this.newDone,
    required this.newRemainingAllowance,
    required this.unlearnedTotal,
    required this.newAvailableToday,
    required this.reviewGoal,
    required this.reviewDone,
    required this.reviewRemainingAllowance,
    required this.dueTotal,
    required this.reviewAvailableToday,
    required this.backlog,
    required this.learnedWords,
    required this.totalWords,
    required this.hardWords,
    this.scopedToBook = false,
  });

  const TodayProgress.empty()
    : newGoal = 30,
      newDone = 0,
      newRemainingAllowance = 30,
      unlearnedTotal = 0,
      newAvailableToday = 0,
      reviewGoal = 100,
      reviewDone = 0,
      reviewRemainingAllowance = 100,
      dueTotal = 0,
      reviewAvailableToday = 0,
      backlog = 0,
      learnedWords = 0,
      totalWords = 0,
      hardWords = 0,
      scopedToBook = false;

  final int newGoal;
  final int newDone;
  final int newRemainingAllowance;
  final int unlearnedTotal;
  final int newAvailableToday;

  final int reviewGoal;
  final int reviewDone;
  final int reviewRemainingAllowance;
  final int dueTotal;
  final int reviewAvailableToday;
  final int backlog;

  final int learnedWords;
  final int totalWords;
  final int hardWords;

  /// True when the numbers describe one book instead of the whole library.
  final bool scopedToBook;

  /// Legacy alias used by older widgets: the daily target.
  int get newTarget => newGoal;

  /// Legacy alias: what the user can actually study now (never more than the
  /// real number of unlearned words).
  int get newRemaining => newAvailableToday;

  int get reviewLimit => reviewGoal;

  /// Legacy alias: reviews that can be started now.
  int get reviewRemaining => reviewAvailableToday;

  int get dueNow => dueTotal;

  /// Something to do right now? Used to hide a dead "开始学习" entry point.
  bool get hasWork => newAvailableToday > 0 || reviewAvailableToday > 0;

  bool get canStartNew => newAvailableToday > 0;
  bool get canStartReview => reviewAvailableToday > 0;

  double get newRatio => newGoal <= 0 ? 0 : (newDone / newGoal).clamp(0, 1);
  double get reviewRatio =>
      reviewGoal <= 0 ? 0 : (reviewDone / reviewGoal).clamp(0, 1);

  String get scopeLabel => scopedToBook ? '当前词书' : '全部词书';
}

/// Aggregated numbers for the statistics screen.
class StudyStatistics {
  const StudyStatistics({
    required this.totalWords,
    required this.learnedWords,
    required this.todayNew,
    required this.todayReview,
    required this.correctCount,
    required this.hazyCount,
    required this.wrongCount,
    required this.hardWords,
    required this.lastStudyDay,
    this.scopedToBook = false,
  });

  const StudyStatistics.empty()
    : totalWords = 0,
      learnedWords = 0,
      todayNew = 0,
      todayReview = 0,
      correctCount = 0,
      hazyCount = 0,
      wrongCount = 0,
      hardWords = const <WordWithState>[],
      lastStudyDay = null,
      scopedToBook = false;

  final int totalWords;
  final int learnedWords;
  final int todayNew;
  final int todayReview;
  final int correctCount;
  final int hazyCount;
  final int wrongCount;
  final List<WordWithState> hardWords;
  final String? lastStudyDay;
  final bool scopedToBook;

  int get unlearnedWords => (totalWords - learnedWords).clamp(0, totalWords);
  int get totalAnswers => correctCount + hazyCount + wrongCount;

  /// True when the user has actually answered something. Without answers the
  /// accuracy is *unknown*, not 0%: showing 0% was actively misleading.
  bool get hasAnswers => totalAnswers > 0;

  /// Share of "known" answers over all answers (0..1), or null when there is no
  /// answer history yet.
  double? get accuracyOrNull =>
      totalAnswers == 0 ? null : correctCount / totalAnswers;

  /// Kept for callers that need a number; the UI must use [accuracyOrNull].
  double get accuracy => accuracyOrNull ?? 0;
}

/// Result of persisting one answer.
class AnswerRecord {
  const AnswerRecord({
    required this.eventId,
    required this.duplicate,
    required this.stage,
    required this.nextReviewAt,
    required this.intervalDays,
    required this.repeatInSession,
  });

  final String eventId;
  final bool duplicate;
  final StudyStage stage;
  final DateTime nextReviewAt;
  final int intervalDays;
  final bool repeatInSession;
}

/// One word in the word-management list, with the numbers that page needs.
class ManagedWord {
  const ManagedWord({
    required this.word,
    required this.state,
    required this.bookCount,
    required this.answerCount,
    required this.errorRate,
    this.nextReviewAt,
    this.lastStudiedAt,
  });

  final Word word;
  final LearningState? state;
  final int bookCount;
  final int answerCount;

  /// `wrong / answers` in 0..1, or null when the word was never answered.
  final double? errorRate;

  final DateTime? nextReviewAt;
  final DateTime? lastStudiedAt;

  int get wrongCount => state?.wrongCount ?? 0;
  int get hazyCount => state?.hazyCount ?? 0;
  int get correctCount => state?.correctCount ?? 0;
  StudyStage get stage => StudyStage.fromCode(state?.stage ?? 0);
  bool get isMastered => stage.code > 0 && (state?.intervalDays ?? 0) >= 30;
}
