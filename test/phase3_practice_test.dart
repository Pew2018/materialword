import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/models/study_models.dart';
import 'package:materialword/services/practice_session.dart';

import 'helpers/test_env.dart';

/// Practice drills: real questions from real rows, real events in the log, and
/// no pretence that a drill is a long-term recall measurement.
void main() {
  late TestEnv env;

  setUp(() async {
    env = await TestEnv.create();
  });

  tearDown(() async {
    await env.dispose();
  });

  Future<PracticeSession> sessionFor(
    PracticeKind kind, {
    String? bookId,
    int limit = 20,
  }) async {
    final PracticeSession session = PracticeSession(
      env.study,
      env.settings,
      env.clock,
    );
    await session.load(kind: kind, bookId: bookId, limit: limit);
    return session;
  }

  test('spelling grades case and whitespace but never a different word', () {
    expect(PracticeSession.matches('recognize', ' Recognize '), isTrue);
    expect(PracticeSession.matches('take off', '  TAKE   OFF '), isTrue);
    expect(PracticeSession.matches('recognize', 'recognise'), isFalse);
    expect(PracticeSession.matches('form', 'from'), isFalse);
  });

  test(
    'spelling drill asks with the Chinese meaning and keeps the answer',
    () async {
      final WordBook book = await env.seedBook(
        words: <String>['alpha', 'beta'],
      );
      final PracticeSession session = await sessionFor(
        PracticeKind.spelling,
        bookId: book.id,
      );
      addTearDown(session.dispose);
      expect(session.current, isNotNull);
      final PracticeQuestion question = session.current!;
      expect(question.prompt, contains('释义'));
      expect(question.answer, isNotEmpty);
      expect(question.options, isEmpty);
    },
  );

  test(
    'a drill answer is recorded but never moves the long-term interval',
    () async {
      final WordBook book = await env.seedBook(
        words: <String>['alpha', 'beta'],
      );
      final PracticeSession session = await sessionFor(
        PracticeKind.spelling,
        bookId: book.id,
      );
      addTearDown(session.dispose);
      final PracticeQuestion question = session.current!;

      // Study the word properly first, so it owns a real ladder position.
      await env.study.recordAnswer(
        wordId: question.word.id,
        result: AnswerResult.known,
        type: ReviewType.study,
        eventId: 'seed-${question.word.id}',
        deviceId: 'test-device',
        now: env.clock.now(),
      );
      final LearningState before = await env.study
          .managedWord(question.word.id)
          .then((ManagedWord? row) => row!.state!);

      final PracticeOutcome? outcome = await session.submitTyped(
        question.answer.toUpperCase(),
      );
      expect(outcome, isNotNull);
      expect(outcome!.correct, isTrue);

      final ManagedWord after = (await env.study.managedWord(
        question.word.id,
      ))!;
      expect(after.state!.stage, before.stage);
      expect(after.state!.intervalDays, before.intervalDays);
      expect(after.state!.nextReviewAt, before.nextReviewAt);
      expect(after.state!.correctCount, before.correctCount + 1);

      final List<ReviewEvent> events = await env.db
          .select(env.db.reviewEvents)
          .get();
      final ReviewEvent practice = events.firstWhere(
        (ReviewEvent e) =>
            e.mode == ReviewEventMode.forPractice(PracticeKind.spelling),
      );
      expect(practice.result, AnswerResult.known.code);

      // Deterministic replay reaches the same conclusion.
      await env.study.rebuildStateFromEvents(question.word.id);
      final ManagedWord replayed = (await env.study.managedWord(
        question.word.id,
      ))!;
      expect(replayed.state!.intervalDays, before.intervalDays);
      expect(replayed.state!.nextReviewAt, before.nextReviewAt);
      expect(replayed.state!.correctCount, before.correctCount + 1);
    },
  );

  test(
    'a wrong drill answer counts as a mistake without scheduling relearning',
    () async {
      final WordBook book = await env.seedBook(
        words: <String>['alpha', 'beta'],
      );
      final PracticeSession session = await sessionFor(
        PracticeKind.spelling,
        bookId: book.id,
      );
      addTearDown(session.dispose);
      final PracticeQuestion question = session.current!;
      await env.study.recordAnswer(
        wordId: question.word.id,
        result: AnswerResult.known,
        type: ReviewType.study,
        eventId: 'seed-${question.word.id}',
        deviceId: 'test-device',
        now: env.clock.now(),
      );
      final LearningState before = (await env.study.managedWord(
        question.word.id,
      ))!.state!;

      final PracticeOutcome? outcome = await session.submitTyped(
        'not-the-word',
      );
      expect(outcome!.correct, isFalse);

      final LearningState after = (await env.study.managedWord(
        question.word.id,
      ))!.state!;
      expect(after.stage, before.stage);
      expect(after.intervalDays, before.intervalDays);
      expect(after.nextReviewAt, before.nextReviewAt);
      expect(after.wrongCount, before.wrongCount + 1);
      // The summary surfaces the word for review, it is not silently dropped.
      expect(session.summary().wrongWords, contains(question.answer));
    },
  );

  test('drills do not consume the daily new/review allowance', () async {
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    final PracticeSession session = await sessionFor(
      PracticeKind.spelling,
      bookId: book.id,
    );
    addTearDown(session.dispose);
    await session.submitTyped(session.current!.answer);

    expect(
      await env.study.todayCount(now: env.clock.now(), type: ReviewType.review),
      0,
    );
    expect(
      await env.study.todayCount(now: env.clock.now(), type: ReviewType.study),
      0,
    );
    final StudyStatistics stats = await env.study.statistics(
      now: env.clock.now(),
    );
    expect(stats.breakdown.practice, greaterThan(0));
  });

  test('undo writes a real undo event and rolls the drill back', () async {
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    final PracticeSession session = await sessionFor(
      PracticeKind.spelling,
      bookId: book.id,
    );
    addTearDown(session.dispose);
    final PracticeQuestion question = session.current!;
    await session.submitTyped('definitely-wrong');
    // Phase 4B-03: a saved answer shows feedback on the *same* question; the
    // cursor only moves when the user asks for the next one. The previous
    // assertion (`position == 1` right after submit) encoded the old bug where
    // the session had already moved on while the page still showed feedback.
    expect(session.phase, PracticePhase.feedback);
    expect(session.position, 0);
    expect(session.current!.word.id, question.word.id);
    expect(session.canUndo, isTrue);

    expect(await session.undo(), isTrue);
    expect(session.phase, PracticePhase.question);
    expect(session.position, 0);
    expect(session.current!.word.id, question.word.id);
    expect(session.outcome, isNull);

    final StudyStatistics stats = await env.study.statistics(
      now: env.clock.now(),
    );
    expect(stats.breakdown.practice, 0);
  });

  test('the cursor moves only when the user advances', () async {
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    final PracticeSession session = await sessionFor(
      PracticeKind.spelling,
      bookId: book.id,
    );
    addTearDown(session.dispose);
    final String first = session.current!.word.id;
    await session.submitTyped(session.current!.answer);
    expect(session.position, 0);
    expect(session.phase, PracticePhase.feedback);
    // Skipping is rejected while feedback is on screen: it used to silently
    // skip the *next* question and skew the counters.
    expect(session.skip(), isFalse);
    expect(session.skippedCount, 0);

    expect(session.advance(), isTrue);
    expect(session.position, 1);
    expect(session.phase, PracticePhase.question);
    expect(session.current!.word.id, isNot(first));
    // Advancing without feedback is impossible, so a stray tap cannot skip.
    expect(session.advance(), isFalse);

    // The last question keeps its feedback before the summary appears.
    await session.submitTyped(session.current!.answer);
    expect(session.isFinished, isFalse);
    expect(session.phase, PracticePhase.feedback);
    expect(session.isLastQuestion, isTrue);
    expect(session.outcome, isNotNull);
    expect(session.advance(), isTrue);
    expect(session.isFinished, isTrue);
    expect(session.position, 2);
    expect(session.answeredCount, 2);
    expect(session.correctCount, 2);
  });

  test('a second submit while one is in flight is ignored', () async {
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    final PracticeSession session = await sessionFor(
      PracticeKind.spelling,
      bookId: book.id,
    );
    addTearDown(session.dispose);
    final PracticeQuestion question = session.current!;
    // Fired without awaiting: exactly what a double tap or a keyboard "done"
    // racing the submit button does.
    final Future<PracticeOutcome?> first = session.submitTyped(question.answer);
    final Future<PracticeOutcome?> second = session.submitTyped(
      question.answer,
    );
    expect(await first, isNotNull);
    expect(await second, isNull);
    expect(session.answeredCount, 1);
    final List<ReviewEvent> events = await env.db
        .select(env.db.reviewEvents)
        .get();
    expect(
      events.where((ReviewEvent e) => ReviewEventMode.isPractice(e.mode)),
      hasLength(1),
    );
  });

  test(
    'a question whose word changed is refused instead of graded on old text',
    () async {
      final WordBook book = await env.seedBook(words: <String>['alpha']);
      final PracticeSession session = await sessionFor(
        PracticeKind.spelling,
        bookId: book.id,
      );
      addTearDown(session.dispose);
      final PracticeQuestion question = session.current!;
      // Simulate a sync merge / another page editing the row underneath us.
      await env.words.updateContent(
        question.word.id,
        translation: '完全不同的释义',
        now: env.clock.now(),
      );

      final PracticeOutcome? outcome = await session.submitTyped(
        question.answer,
      );
      expect(outcome, isNull);
      expect(session.answeredCount, 0);
      expect(session.phase, PracticePhase.question);
      expect(session.error, contains('已更新'));
      expect(await env.db.select(env.db.reviewEvents).get(), isEmpty);
    },
  );

  test('a question whose word was removed from the book is refused', () async {
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    final PracticeSession session = await sessionFor(
      PracticeKind.spelling,
      bookId: book.id,
    );
    addTearDown(session.dispose);
    final PracticeQuestion question = session.current!;
    await env.books.removeWords(book.id, <String>[
      question.word.id,
    ], now: env.clock.now());

    expect(await session.submitTyped(question.answer), isNull);
    expect(session.error, contains('移出'));
    expect(await env.db.select(env.db.reviewEvents).get(), isEmpty);
  });

  test('a deleted word is refused instead of graded', () async {
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    final PracticeSession session = await sessionFor(
      PracticeKind.spelling,
      bookId: book.id,
    );
    addTearDown(session.dispose);
    final PracticeQuestion question = session.current!;
    await env.words.softDelete(question.word.id, now: env.clock.now());

    expect(await session.submitTyped(question.answer), isNull);
    expect(session.error, contains('删除'));
    expect(await env.db.select(env.db.reviewEvents).get(), isEmpty);
  });

  test(
    'multiple choice offers distinct options that include the answer',
    () async {
      final WordBook book = await env.seedBook(
        words: <String>['alpha', 'beta', 'gamma', 'delta', 'epsilon'],
      );
      final PracticeSession session = await sessionFor(
        PracticeKind.choice,
        bookId: book.id,
      );
      addTearDown(session.dispose);
      final PracticeQuestion question = session.current!;
      expect(question.options.length, greaterThanOrEqualTo(2));
      expect(question.options, contains(question.answer));
      expect(question.options.toSet().length, question.options.length);
      expect(question.correctIndex, isNotNull);

      final PracticeOutcome? correct = await session.submitChoice(
        question.correctIndex!,
      );
      expect(correct!.correct, isTrue);
    },
  );

  test(
    'multiple choice skips a word it cannot build fair options for',
    () async {
      final WordBook book = await env.seedBook(words: <String>['alpha']);
      final PracticeSession session = await sessionFor(
        PracticeKind.choice,
        bookId: book.id,
      );
      addTearDown(session.dispose);
      // One word = no distractor. The drill must not invent a fake question.
      expect(session.isEmpty, isTrue);
    },
  );

  test('cloze only uses an example that really contains the word', () async {
    final WordBook book = await env.books.create(
      name: '例句',
      now: env.clock.now(),
    );
    final Word withExample = await env.words.ensureWord(
      text: 'harvest',
      translation: '收获',
      example: 'The harvest was good this year.',
      now: env.clock.now(),
    );
    final Word withoutExample = await env.words.ensureWord(
      text: 'meadow',
      translation: '草地',
      now: env.clock.now(),
    );
    await env.books.addWords(book.id, <String>[
      withExample.id,
      withoutExample.id,
    ], now: env.clock.now());

    final PracticeSession session = await sessionFor(
      PracticeKind.cloze,
      bookId: book.id,
    );
    addTearDown(session.dispose);
    expect(session.total, 1);
    final PracticeQuestion question = session.current!;
    expect(question.word.word, 'harvest');
    expect(question.prompt, contains('____'));
    expect(question.prompt.toLowerCase(), isNot(contains('harvest')));

    final PracticeOutcome? outcome = await session.submitTyped('Harvest');
    expect(outcome!.correct, isTrue);
  });

  test('dictation hides the word and keeps the typed answer', () async {
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    final PracticeSession session = await sessionFor(
      PracticeKind.dictation,
      bookId: book.id,
    );
    addTearDown(session.dispose);
    final PracticeQuestion question = session.current!;
    expect(question.prompt, isEmpty);
    expect(question.kind.isTyped, isTrue);
    final PracticeOutcome? outcome = await session.submitTyped(question.answer);
    expect(outcome!.correct, isTrue);
  });

  test('skipping records nothing at all', () async {
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    final PracticeSession session = await sessionFor(
      PracticeKind.spelling,
      bookId: book.id,
    );
    addTearDown(session.dispose);
    session.skip();
    expect(session.answeredCount, 0);
    expect(await env.db.select(env.db.reviewEvents).get(), isEmpty);
    expect(session.summary().skipped, 1);
  });
}
