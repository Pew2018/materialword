import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/models/study_models.dart';
import 'package:materialword/services/practice_session.dart';

import 'helpers/test_env.dart';

/// Statistics must describe what really happened: real answers only, practice
/// separated from scheduled study, and no 0% accuracy before any answer exists.
void main() {
  late TestEnv env;

  setUp(() async {
    env = await TestEnv.create();
  });

  tearDown(() async {
    await env.dispose();
  });

  test('no answers means no accuracy instead of 0%', () async {
    await env.seedBook();
    final StudyStatistics stats = await env.study.statistics(
      now: env.clock.now(),
    );
    expect(stats.hasAnswers, isFalse);
    expect(stats.accuracyOrNull, isNull);
    expect(stats.todayAnswers, 0);
    expect(stats.breakdown.total, 0);
    expect(stats.distinctAnsweredWords, 0);
    expect(stats.undoneAnswers, 0);
    expect(stats.dueForecast.length, 7);
  });

  test('answers are separated by source and only real ones count', () async {
    final book = await env.seedBook(words: <String>['alpha', 'beta', 'gamma']);
    final List<String> ids = await env.db
        .customSelect('SELECT id FROM words ORDER BY normalized')
        .map((row) => row.read<String>('id'))
        .get();

    // One ordinary review answer.
    await env.study.recordAnswer(
      wordId: ids[0],
      result: AnswerResult.known,
      type: ReviewType.review,
      eventId: 'normal-1',
      deviceId: 'device',
      now: env.clock.now(),
    );
    // One practice answer (spelling drill).
    final PracticeSession practice = PracticeSession(
      env.study,
      env.settings,
      env.clock,
    );
    await practice.load(kind: PracticeKind.spelling, bookId: book.id);
    addTearDown(practice.dispose);
    await practice.submitTyped(practice.current!.answer);
    // One manual management event: must never be counted as an answer.
    await env.study.markMastered(
      wordId: ids[1],
      deviceId: 'device',
      now: env.clock.now(),
      eventId: 'mastered-1',
    );

    StudyStatistics stats = await env.study.statistics(now: env.clock.now());
    expect(stats.breakdown.normal, 1);
    expect(stats.breakdown.practice, 1);
    expect(stats.breakdown.practiceByKind[PracticeKind.spelling], 1);
    expect(stats.breakdown.practiceByKind[PracticeKind.choice], isNull);
    expect(stats.breakdown.total, 2);
    expect(stats.todayAnswers, 2);
    expect(stats.distinctAnsweredWords, greaterThanOrEqualTo(1));
    expect(stats.trend7, isNotEmpty);
    expect(stats.trend7.last.answers, 2);

    // Undo the practice answer: it disappears from every count, but the undo
    // event itself is reported.
    expect(await practice.undo(), isTrue);
    stats = await env.study.statistics(now: env.clock.now());
    expect(stats.breakdown.practice, 0);
    expect(stats.undoneAnswers, 1);
    expect(stats.accuracyOrNull, 1.0);
  });

  test('the due forecast buckets words by local day', () async {
    final book = await env.seedBook(words: <String>['alpha', 'beta']);
    final ids = await env.db
        .customSelect('SELECT id FROM words ORDER BY normalized')
        .map((row) => row.read<String>('id'))
        .get();
    await env.study.recordAnswer(
      wordId: ids.first,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'first-answer',
      deviceId: 'device',
      now: env.clock.now(),
    );
    final StudyStatistics stats = await env.study.statistics(
      now: env.clock.now(),
      bookId: book.id,
    );
    expect(stats.dueForecast.length, 7);
    final int total = stats.dueForecast.fold<int>(
      0,
      (int sum, DueForecastDay day) => sum + day.count,
    );
    expect(total, 1, reason: 'the answered word becomes due once');
    // A word answered today is due on a later local day, never "today" twice.
    expect(stats.dueForecast.first.count, 0);
  });

  test('book scope and overall scope stay separate', () async {
    final first = await env.seedBook(name: '书一', words: <String>['alpha']);
    await env.seedBook(name: '书二', words: <String>['beta']);
    final StudyStatistics scoped = await env.study.statistics(
      now: env.clock.now(),
      bookId: first.id,
    );
    final StudyStatistics all = await env.study.statistics(
      now: env.clock.now(),
    );
    expect(scoped.totalWords, 1);
    expect(all.totalWords, 2);
    expect(scoped.scopedToBook, isTrue);
    expect(all.scopedToBook, isFalse);
  });
}
