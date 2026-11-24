import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/study_scheduler.dart';

void main() {
  const StudyScheduler scheduler = StudyScheduler();
  final DateTime now = DateTime(2026, 11, 24, 21, 30);

  LearningSnapshot after(ScheduleOutcome outcome) => LearningSnapshot(
    stage: outcome.stage,
    correctCount: outcome.correctCount,
    hazyCount: outcome.hazyCount,
    wrongCount: outcome.wrongCount,
    streak: outcome.streak,
    intervalDays: outcome.intervalDays,
  );

  group('T06 三个作答等级', () {
    test('认识：新词进入学习阶段并安排 1 天后复习', () {
      final ScheduleOutcome outcome = scheduler.schedule(
        current: null,
        result: AnswerResult.known,
        now: now,
        type: ReviewType.study,
      );
      expect(outcome.stage, StudyStage.learning);
      expect(outcome.intervalDays, 1);
      expect(outcome.correctCount, 1);
      expect(outcome.nextReviewAt, DateTime(2026, 11, 25));
      expect(outcome.repeatInSession, isFalse);
    });

    test('模糊：缩短间隔、清零连续正确、当天再来一次', () {
      final ScheduleOutcome outcome = scheduler.schedule(
        current: const LearningSnapshot(
          stage: StudyStage.review,
          correctCount: 4,
          hazyCount: 0,
          wrongCount: 0,
          streak: 4,
          intervalDays: 7,
        ),
        result: AnswerResult.hazy,
        now: now,
        type: ReviewType.review,
      );
      expect(outcome.hazyCount, 1);
      expect(outcome.streak, 0);
      expect(outcome.intervalDays, 3, reason: '从 7 天下调一档');
      expect(outcome.nextReviewAt, now.add(StudyScheduler.hazyDelay));
      expect(outcome.repeatInSession, isTrue);
    });

    test('不认识：回到重学阶段并安排 30 分钟后再来', () {
      final ScheduleOutcome outcome = scheduler.schedule(
        current: const LearningSnapshot(
          stage: StudyStage.review,
          correctCount: 10,
          hazyCount: 1,
          wrongCount: 2,
          streak: 5,
          intervalDays: 14,
        ),
        result: AnswerResult.unknown,
        now: now,
        type: ReviewType.review,
      );
      expect(outcome.stage, StudyStage.relearning);
      expect(outcome.wrongCount, 3);
      expect(outcome.intervalDays, 1);
      expect(outcome.nextReviewAt, now.add(StudyScheduler.unknownDelay));
      expect(outcome.repeatInSession, isTrue);
    });
  });

  group('T07 连续错误', () {
    test('连续答错保持重学阶段且始终安排短期复习', () {
      LearningSnapshot snapshot = const LearningSnapshot.empty();
      DateTime moment = now;
      for (int i = 0; i < 3; i++) {
        final ScheduleOutcome outcome = scheduler.schedule(
          current: snapshot,
          result: AnswerResult.unknown,
          now: moment,
          type: ReviewType.study,
        );
        expect(outcome.stage, StudyStage.relearning);
        expect(outcome.wrongCount, i + 1);
        expect(
          outcome.nextReviewAt.difference(moment),
          StudyScheduler.unknownDelay,
        );
        snapshot = after(outcome);
        moment = outcome.nextReviewAt.add(const Duration(minutes: 1));
      }
    });
  });

  group('T08 连续正确', () {
    test('间隔按 1 / 3 / 7 / 14 / 30 天递增并封顶', () {
      LearningSnapshot snapshot = const LearningSnapshot.empty();
      DateTime moment = now;
      final List<int> intervals = <int>[];
      for (int i = 0; i < 7; i++) {
        final ScheduleOutcome outcome = scheduler.schedule(
          current: snapshot,
          result: AnswerResult.known,
          now: moment,
          type: i == 0 ? ReviewType.study : ReviewType.review,
        );
        intervals.add(outcome.intervalDays);
        snapshot = after(outcome);
        moment = outcome.nextReviewAt.add(const Duration(hours: 9));
      }
      expect(intervals, <int>[1, 3, 7, 14, 30, 30, 30]);
      expect(snapshot.streak, 7);
      expect(snapshot.stage, StudyStage.review);
    });

    test('答错之后重新爬升', () {
      LearningSnapshot snapshot = const LearningSnapshot(
        stage: StudyStage.review,
        correctCount: 5,
        hazyCount: 0,
        wrongCount: 0,
        streak: 5,
        intervalDays: 30,
      );
      final ScheduleOutcome wrong = scheduler.schedule(
        current: snapshot,
        result: AnswerResult.unknown,
        now: now,
        type: ReviewType.review,
      );
      expect(wrong.intervalDays, 1);
      snapshot = after(wrong);
      final ScheduleOutcome known = scheduler.schedule(
        current: snapshot,
        result: AnswerResult.known,
        now: now.add(const Duration(days: 1)),
        type: ReviewType.review,
      );
      expect(known.intervalDays, 3);
      expect(known.stage, StudyStage.review);
    });
  });

  test('replay 可以从历史重建状态', () {
    final LearningSnapshot snapshot = scheduler.replay(
      <({AnswerResult result, DateTime at, ReviewType type})>[
        (
          result: AnswerResult.known,
          at: DateTime(2026, 11, 1, 9),
          type: ReviewType.study,
        ),
        (
          result: AnswerResult.known,
          at: DateTime(2026, 11, 2, 9),
          type: ReviewType.review,
        ),
        (
          result: AnswerResult.unknown,
          at: DateTime(2026, 11, 5, 9),
          type: ReviewType.review,
        ),
        (
          result: AnswerResult.known,
          at: DateTime(2026, 11, 6, 9),
          type: ReviewType.review,
        ),
      ],
    );
    expect(snapshot.correctCount, 3);
    expect(snapshot.wrongCount, 1);
    expect(snapshot.stage, StudyStage.review);
    expect(snapshot.intervalDays, 3);
  });
}
