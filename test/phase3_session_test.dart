import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/study_session.dart';

import 'helpers/test_env.dart';

void main() {
  test(
    'STUDY queue, cursor and pending repeats restore without duplicate events',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook();
      final first = env.session();
      await first.load(newLimit: 3, reviewLimit: 10);
      final word = first.current!.word.id;
      first.reveal();
      await first.submit(AnswerResult.unknown);
      expect(first.position, 1);
      expect(first.repeatCards, 1);
      final currentId = first.current!.word.id;
      first.dispose();
      final restored = env.session();
      addTearDown(restored.dispose);
      await restored.load(newLimit: 2, reviewLimit: 10);
      expect(restored.current!.word.id, currentId);
      expect(restored.position, 1);
      expect(restored.repeatCards, 1);
      expect(restored.totalCards, 4);
      expect(restored.newAnswered, 1);
      expect((await env.words.eventsForWord(word)).length, 1);
      expect(restored.canUndo, isTrue);
      expect(await restored.undo(), isTrue);
      expect(restored.position, 0);
      expect(restored.totalCards, 3);
      expect(restored.current!.word.id, word);
      expect(restored.newAnswered, 0);
      expect(await env.words.stateFor(word), isNull);
    },
  );

  test('STUDY same-day repeat counts as answer but never accelerates long interval', () async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(words: ['alpha']);
    final session = env.session();
    addTearDown(session.dispose);
    await session.load(newLimit: 1, reviewLimit: 10);
    final id = session.current!.word.id;
    session.reveal();
    await session.submit(AnswerResult.unknown);
    final due = (await env.words.stateFor(id))!.nextReviewAt;
    session.reveal();
    await session.submit(AnswerResult.known);
    final state = (await env.words.stateFor(id))!;
    expect(state.intervalDays, 1);
    expect(state.nextReviewAt, due);
    expect(session.newAnswered, 1);
    expect(
      await env.study.todayCount(now: env.clock.now(), type: ReviewType.study),
      1,
    );
    expect((await env.study.statistics(now: env.clock.now())).correctCount, 1);
    await env.study.rebuildStateFromEvents(id);
    expect((await env.words.stateFor(id))!.nextReviewAt, due);
  });

  test(
    'STUDY restore ignores deleted cards and cannot undo a changed queue',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook();
      final first = env.session();
      await first.load(newLimit: 3, reviewLimit: 10);
      final id = first.current!.word.id;
      first.dispose();
      await env.words.softDelete(id, now: env.clock.now());
      final second = env.session();
      addTearDown(second.dispose);
      await second.load(newLimit: 3, reviewLimit: 10);
      expect(second.totalCards, 2);
      expect(second.current!.word.id, isNot(id));
      expect(second.canUndo, isFalse);
    },
  );

  test(
    'STUDY day and goal changes rebuild queues under current allowance',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook();
      final first = env.session();
      await first.load(newLimit: 3, reviewLimit: 10);
      first.dispose();
      env.clock.nextDay();
      final second = env.session();
      await second.load(newLimit: 1, reviewLimit: 10);
      expect(second.totalCards, 1);
      second.dispose();
      await env.settings.save(dailyNewTarget: 2);
      final third = env.session();
      addTearDown(third.dispose);
      await third.load(newLimit: 2, reviewLimit: 10);
      expect(third.totalCards, 2);
      expect(await env.db.readMeta(StudySession.persistenceKey), isNotNull);
    },
  );
}
