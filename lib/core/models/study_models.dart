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
  });

  const StudyQueue.empty()
    : cards = const <StudyCard>[],
      newAvailable = 0,
      reviewAvailable = 0,
      backlog = 0;

  final List<StudyCard> cards;

  /// How many new words were available today (before applying the target).
  final int newAvailable;

  /// How many words were due (before applying the daily review limit).
  final int reviewAvailable;

  /// Due words that did not fit into today's review limit.
  final int backlog;

  bool get isEmpty => cards.isEmpty;
}

/// Numbers shown on the dashboard.
class TodayProgress {
  const TodayProgress({
    required this.newDone,
    required this.newTarget,
    required this.reviewDone,
    required this.reviewLimit,
    required this.dueNow,
    required this.backlog,
    required this.learnedWords,
    required this.totalWords,
    required this.hardWords,
  });

  const TodayProgress.empty()
    : newDone = 0,
      newTarget = 30,
      reviewDone = 0,
      reviewLimit = 100,
      dueNow = 0,
      backlog = 0,
      learnedWords = 0,
      totalWords = 0,
      hardWords = 0;

  final int newDone;
  final int newTarget;
  final int reviewDone;
  final int reviewLimit;

  /// Words due right now (independent of today's limit).
  final int dueNow;

  /// Due words beyond today's review limit that carry over to tomorrow.
  final int backlog;

  final int learnedWords;
  final int totalWords;
  final int hardWords;

  int get newRemaining => (newTarget - newDone).clamp(0, newTarget);
  int get reviewRemaining => (reviewLimit - reviewDone).clamp(0, reviewLimit);
  double get newRatio => newTarget == 0 ? 0 : (newDone / newTarget).clamp(0, 1);
  double get reviewRatio =>
      reviewLimit == 0 ? 0 : (reviewDone / reviewLimit).clamp(0, 1);
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
      lastStudyDay = null;

  final int totalWords;
  final int learnedWords;
  final int todayNew;
  final int todayReview;
  final int correctCount;
  final int hazyCount;
  final int wrongCount;
  final List<WordWithState> hardWords;
  final String? lastStudyDay;

  int get unlearnedWords => (totalWords - learnedWords).clamp(0, totalWords);
  int get totalAnswers => correctCount + hazyCount + wrongCount;

  /// Share of "known" answers over all answers (0..1).
  double get accuracy => totalAnswers == 0 ? 0 : correctCount / totalAnswers;
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
