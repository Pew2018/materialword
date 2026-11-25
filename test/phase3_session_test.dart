import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/repositories/study_repository.dart';
import 'package:materialword/core/repositories/settings_repository.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/study_session.dart';

import 'helpers/test_env.dart';

void main() {
  test(
    'STUDY changed question refreshes without recording stale revealed answer',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: ['alpha', 'beta']);
      final session = env.session();
      addTearDown(session.dispose);
      await session.load(newLimit: 2, reviewLimit: 10);
      final id = session.current!.word.id;
      session.reveal();
      await env.words.updateContent(
        id,
        text: 'renamed',
        translation: '新的释义',
        now: env.clock.now(),
      );
      expect(await session.submit(AnswerResult.known), isNull);
      expect(session.current!.word.word, 'renamed');
      expect(session.current!.word.translation, '新的释义');
      expect(session.isRevealed, isFalse);
      expect(await env.words.eventsForWord(id), isEmpty);
      session.reveal();
      expect(await session.submit(AnswerResult.known), isNotNull);
      expect(await env.words.eventsForWord(id), hasLength(1));
    },
  );

  for (final restore in [false, true]) {
    for (final offset in [Duration.zero, const Duration(hours: -1)]) {
      test(
        'STUDY ${restore ? 'restored' : 'active'} skips remote answer despite clock offset $offset',
        () async {
          final env = await TestEnv.create();
          addTearDown(env.dispose);
          await env.seedBook(words: ['alpha', 'beta']);
          final id = (await env.words.byNormalized('alpha'))!.id;
          final beta = (await env.words.byNormalized('beta'))!.id;
          await env.study.recordAnswer(
            wordId: id,
            result: AnswerResult.unknown,
            type: ReviewType.review,
            eventId: 'prior-answer',
            deviceId: 'this-device',
            now: env.clock.now(),
          );
          final first = env.session();
          await first.load(
            newLimit: 2,
            reviewLimit: 10,
            special: SpecialReview.sessionMistakes,
            focusedWordIds: [id, beta],
          );
          expect(first.current!.word.id, id);
          // The prior timestamp is already equal to or later than the arrival.
          await env.study.recordAnswer(
            wordId: id,
            result: AnswerResult.known,
            type: ReviewType.review,
            eventId: 'remote-clock-answer',
            deviceId: 'other-device',
            now: env.clock.now().add(offset),
          );
          if (restore) {
            first.dispose();
            final second = env.session();
            addTearDown(second.dispose);
            await second.load(
              newLimit: 2,
              reviewLimit: 10,
              special: SpecialReview.sessionMistakes,
              focusedWordIds: [id, beta],
            );
            expect(second.current!.word.id, isNot(id));
          } else {
            addTearDown(first.dispose);
            first.reveal();
            expect(await first.submit(AnswerResult.known), isNull);
            expect(first.current!.word.id, isNot(id));
          }
          expect(await env.words.eventsForWord(id), hasLength(2));
        },
      );
    }
  }

  test('STUDY another answer invalidates pending repeats while own answer and undo remain valid', () async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(words: ['alpha', 'beta']);
    final first = env.session();
    await first.load(newLimit: 2, reviewLimit: 10);
    final id = first.current!.word.id;
    first.reveal();
    await first.submit(AnswerResult.unknown);
    first.dispose();
    await env.study.recordAnswer(
      wordId: id,
      result: AnswerResult.known,
      type: ReviewType.review,
      eventId: 'remote-after-own',
      deviceId: 'other-device',
      now: env.clock.now(),
    );
    final second = env.session();
    addTearDown(second.dispose);
    await second.load(newLimit: 2, reviewLimit: 10);
    expect(
      second.totalCards,
      2,
    ); // answered original and beta; stale repeat removed
    expect(second.canUndo, isFalse);
    expect(second.current!.word.id, isNot(id));
    second.reveal();
    expect(await second.submit(AnswerResult.known), isNotNull);
    expect(second.isFinished, isTrue);
  });

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
  test('STUDY undo snapshot failure rolls back event, state, queue and retry remains legal', () async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(words: ['alpha']);
    final session = env.session();
    addTearDown(session.dispose);
    await session.load(newLimit: 1, reviewLimit: 10);
    final id = session.current!.word.id;
    session.reveal();
    await session.submit(AnswerResult.unknown);
    await env.db.customStatement(
      "CREATE TRIGGER fail_session_update BEFORE UPDATE ON app_meta WHEN NEW.key='active_study_session_v1' BEGIN SELECT RAISE(ABORT, 'injected'); END",
    );
    expect(await session.undo(), isFalse);
    expect(session.position, 1);
    expect(session.totalCards, 2);
    expect(session.canUndo, isTrue);
    expect((await env.words.eventsForWord(id)), hasLength(1));
    expect((await env.words.stateFor(id))!.wrongCount, 1);
    await env.db.customStatement('DROP TRIGGER fail_session_update');
    expect(await session.undo(), isTrue);
    expect(session.position, 0);
    expect(session.totalCards, 1);
    expect(await env.words.stateFor(id), isNull);
  });

  test(
    'STUDY a deleted active card is skipped without recording an answer',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: ['alpha', 'beta']);
      final session = env.session();
      addTearDown(session.dispose);
      await session.load(newLimit: 2, reviewLimit: 10);
      final id = session.current!.word.id;
      session.reveal();
      await env.words.softDelete(id, now: env.clock.now());
      expect(await session.submit(AnswerResult.known), isNull);
      expect(session.current!.word.id, isNot(id));
      expect(session.newAnswered, 0);
      expect((await env.words.eventsForWord(id)), isEmpty);
      expect(await session.skip(), isTrue);
      expect(session.isEmpty, isTrue);
      expect(await env.db.readMeta(StudySession.persistenceKey), isNull);
    },
  );
  test('STUDY file database reopening restores an interrupted session and exactly one event', () async {
    final env = await TestEnv.create(file: true);
    addTearDown(() => File(env.filePath!).parent.delete(recursive: true));
    await env.seedBook(words: ['alpha', 'beta']);
    final first = env.session();
    await first.load(newLimit: 2, reviewLimit: 10);
    first.reveal();
    await first.submit(AnswerResult.unknown);
    final current = first.current!.word.id;
    first.dispose();
    await env.db.close();
    final reopened = AppDatabase(NativeDatabase(File(env.filePath!)));
    addTearDown(reopened.close);
    final resumed = StudySession(
      StudyRepository(reopened),
      SettingsRepository(reopened),
      env.clock,
    );
    addTearDown(resumed.dispose);
    await resumed.load(newLimit: 1, reviewLimit: 10);
    expect(resumed.current!.word.id, current);
    expect(resumed.position, 1);
    expect(resumed.repeatCards, 1);
    expect(resumed.newAnswered, 1);
    expect(await reopened.select(reopened.reviewEvents).get(), hasLength(1));
  });
}
