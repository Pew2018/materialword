import '../core/models/enums.dart';
import '../core/time_utils.dart';

/// Immutable snapshot of what the scheduler needs to know about a word.
class LearningSnapshot {
  const LearningSnapshot({
    required this.stage,
    required this.correctCount,
    required this.hazyCount,
    required this.wrongCount,
    required this.streak,
    required this.intervalDays,
  });

  const LearningSnapshot.empty()
    : stage = StudyStage.newWord,
      correctCount = 0,
      hazyCount = 0,
      wrongCount = 0,
      streak = 0,
      intervalDays = 0;

  final StudyStage stage;
  final int correctCount;
  final int hazyCount;
  final int wrongCount;
  final int streak;
  final int intervalDays;
}

/// Result of applying one answer. Pure data, no database access.
class ScheduleOutcome {
  const ScheduleOutcome({
    required this.stage,
    required this.correctCount,
    required this.hazyCount,
    required this.wrongCount,
    required this.streak,
    required this.intervalDays,
    required this.nextReviewAt,
    required this.repeatInSession,
  });

  final StudyStage stage;
  final int correctCount;
  final int hazyCount;
  final int wrongCount;
  final int streak;
  final int intervalDays;
  final DateTime nextReviewAt;

  /// True when the word should be repeated later in the *current* session.
  final bool repeatInSession;
}

/// Deterministic, dependency-free spaced repetition scheduler.
///
/// It is intentionally simpler than FSRS: a five step ladder
/// (1 / 3 / 7 / 14 / 30 days) that moves one step up on every "known" answer,
/// one step down on "hazy", and back to the start on "unknown". Every rule is
/// covered by unit tests in `test/study_scheduler_test.dart` and described in
/// `docs/study-scheduler.md`.
///
/// Long intervals are scheduled on **local day boundaries** so that "1 day"
/// always means "tomorrow" regardless of what time it is now. Very short
/// intervals ("repeat in this session") use exact durations.
class StudyScheduler {
  const StudyScheduler();

  /// Stored with every ReviewEvent so that history stays interpretable after
  /// the algorithm changes.
  static const int algorithmVersion = 2;

  static const List<int> ladderDays = <int>[1, 3, 7, 14, 30];

  /// "不认识" comes back later in the same session and again in 30 minutes.
  static const Duration unknownDelay = Duration(minutes: 30);

  /// "模糊" comes back later in the same session and again in 6 hours.
  static const Duration hazyDelay = Duration(hours: 6);

  /// A single word may be repeated at most this many extra times per session.
  static const int maxSessionRepeats = 2;

  ScheduleOutcome schedule({
    required LearningSnapshot? current,
    required AnswerResult result,
    required DateTime now,
    required ReviewType type,
  }) {
    final LearningSnapshot snapshot = current ?? const LearningSnapshot.empty();
    final int step = _stepIndex(snapshot.intervalDays);
    final int correct =
        snapshot.correctCount + (result == AnswerResult.known ? 1 : 0);
    final int hazy = snapshot.hazyCount + (result == AnswerResult.hazy ? 1 : 0);
    final int wrong =
        snapshot.wrongCount + (result == AnswerResult.unknown ? 1 : 0);

    switch (result) {
      case AnswerResult.known:
        final int nextStep = (step + 1).clamp(0, ladderDays.length - 1);
        final int interval = ladderDays[nextStep];
        // First successful answer keeps the word on the short "learning" stage;
        // from the second one onwards it joins the long term ladder.
        final StudyStage stage = nextStep >= 1
            ? StudyStage.review
            : StudyStage.learning;
        return ScheduleOutcome(
          stage: stage,
          correctCount: correct,
          hazyCount: hazy,
          wrongCount: wrong,
          streak: snapshot.streak + 1,
          intervalDays: interval,
          nextReviewAt: localDayStartPlus(now, interval),
          repeatInSession: false,
        );

      case AnswerResult.hazy:
        final int nextStep = (step - 1).clamp(0, ladderDays.length - 1);
        final int interval = ladderDays[nextStep];
        return ScheduleOutcome(
          stage: snapshot.stage == StudyStage.review
              ? StudyStage.review
              : StudyStage.learning,
          correctCount: correct,
          hazyCount: hazy,
          wrongCount: wrong,
          streak: 0,
          intervalDays: interval,
          nextReviewAt: now.add(hazyDelay),
          repeatInSession: true,
        );

      case AnswerResult.unknown:
        return ScheduleOutcome(
          stage: StudyStage.relearning,
          correctCount: correct,
          hazyCount: hazy,
          wrongCount: wrong,
          streak: 0,
          intervalDays: ladderDays.first,
          nextReviewAt: now.add(unknownDelay),
          repeatInSession: true,
        );
    }
  }

  /// Rebuilds learning state from scratch out of the raw answer history.
  /// Used after importing a backup so merged history always wins over stale
  /// state rows.
  LearningSnapshot replay(
    List<({AnswerResult result, DateTime at, ReviewType type})> events,
  ) {
    LearningSnapshot snapshot = const LearningSnapshot.empty();
    for (final ({AnswerResult result, DateTime at, ReviewType type}) event
        in events) {
      final ScheduleOutcome outcome = schedule(
        current: snapshot,
        result: event.result,
        now: event.at,
        type: event.type,
      );
      snapshot = LearningSnapshot(
        stage: outcome.stage,
        correctCount: outcome.correctCount,
        hazyCount: outcome.hazyCount,
        wrongCount: outcome.wrongCount,
        streak: outcome.streak,
        intervalDays: outcome.intervalDays,
      );
    }
    return snapshot;
  }

  /// Returns the ladder index for [intervalDays], or -1 when the word has not
  /// climbed onto the ladder yet (brand new word, interval 0).
  int _stepIndex(int intervalDays) {
    if (intervalDays <= 0) return -1;
    final int index = ladderDays.indexOf(intervalDays);
    if (index >= 0) return index;
    // Interval from an older algorithm: snap to the closest ladder step at or
    // below the stored value so we never jump more than one step.
    int best = 0;
    for (int i = 0; i < ladderDays.length; i++) {
      if (ladderDays[i] <= intervalDays) best = i;
    }
    return best;
  }
}
