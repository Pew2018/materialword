import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/models/study_models.dart';
import 'package:materialword/core/repositories/study_repository.dart';
import 'package:materialword/core/repositories/word_repository.dart';
import 'package:materialword/services/study_session.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;
  setUp(() async {
    env = await TestEnv.create();
  });
  tearDown(() async {
    await env.dispose();
  });

  Future<AnswerRecord> answer(
    String wordId,
    AnswerResult result, {
    ReviewType type = ReviewType.study,
    String? id,
  }) {
    return env.study.recordAnswer(
      wordId: wordId,
      result: result,
      type: type,
      eventId: id ?? 'evt_${env.clock.now().microsecondsSinceEpoch}_$wordId',
      deviceId: 'device-a',
      now: env.clock.now(),
    );
  }

  test('T06 三个作答等级都正确写入历史并更新状态', () async {
    final Word a = await env.words.ensureWord(
      text: 'alpha',
      now: env.clock.now(),
    );
    final Word b = await env.words.ensureWord(
      text: 'beta',
      now: env.clock.now(),
    );
    final Word c = await env.words.ensureWord(
      text: 'gamma',
      now: env.clock.now(),
    );

    await answer(a.id, AnswerResult.known);
    await answer(b.id, AnswerResult.hazy);
    await answer(c.id, AnswerResult.unknown);

    final LearningState known = (await env.words.stateFor(a.id))!;
    expect(known.correctCount, 1);
    expect(known.stage, StudyStage.learning.code);

    final LearningState hazy = (await env.words.stateFor(b.id))!;
    expect(hazy.hazyCount, 1);
    expect(hazy.streak, 0);

    final LearningState unknown = (await env.words.stateFor(c.id))!;
    expect(unknown.wrongCount, 1);
    expect(unknown.stage, StudyStage.relearning.code);

    expect(await env.words.eventsForWord(a.id), hasLength(1));
    expect(await env.words.eventsForWord(b.id), hasLength(1));
    expect(await env.words.eventsForWord(c.id), hasLength(1));

    final TodayProgress progress = await env.study.todayProgress(
      now: env.clock.now(),
      newTarget: 30,
      reviewLimit: 100,
    );
    expect(progress.newDone, 3);
    expect(progress.learnedWords, 3);
  });

  test('T07 连续答错后进入重学并按短期调度', () async {
    final Word word = await env.words.ensureWord(
      text: 'alpha',
      now: env.clock.now(),
    );
    await answer(word.id, AnswerResult.unknown, id: 'e1');
    final LearningState first = (await env.words.stateFor(word.id))!;
    expect(first.stage, StudyStage.relearning.code);
    expect(
      first.nextReviewAt! - env.clock.now().millisecondsSinceEpoch,
      lessThanOrEqualTo(30 * 60 * 1000),
    );

    env.clock.advance(const Duration(minutes: 31));
    final AnswerRecord second = await answer(
      word.id,
      AnswerResult.unknown,
      id: 'e2',
    );
    expect(second.repeatInSession, isTrue);
    final LearningState state = (await env.words.stateFor(word.id))!;
    expect(state.wrongCount, 2);
    expect(state.stage, StudyStage.relearning.code);
  });

  test('T08 连续答对延长复习间隔', () async {
    final Word word = await env.words.ensureWord(
      text: 'alpha',
      now: env.clock.now(),
    );
    final List<int> intervals = <int>[];
    for (int i = 0; i < 5; i++) {
      final AnswerRecord record = await answer(
        word.id,
        AnswerResult.known,
        type: i == 0 ? ReviewType.study : ReviewType.review,
        id: 'e$i',
      );
      intervals.add(record.intervalDays);
      env.clock.nextDay(); // wait until the word is due again
    }
    expect(intervals, <int>[1, 3, 7, 14, 30]);
    final LearningState state = (await env.words.stateFor(word.id))!;
    expect(state.streak, 5);
    expect(state.stage, StudyStage.review.code);
  });

  test('T09 每日新词目标与复习上限生效，超出部分计入积压', () async {
    final WordBook book = await env.seedBook(
      words: List<String>.generate(10, (int i) => 'word$i'),
    );

    final StudyQueue queue = await env.study.buildQueue(
      now: env.clock.now(),
      newLimit: 3,
      reviewLimit: 100,
      bookId: book.id,
    );
    expect(
      queue.cards.where((StudyCard c) => c.type == ReviewType.study),
      hasLength(3),
    );
    expect(queue.newAvailable, 10);

    // Study 5 words yesterday so that they are due today.
    env.clock.set(DateTime(2026, 11, 23, 9));
    final List<WordWithState> all = await env.words.listWords(bookId: book.id);
    for (final WordWithState row in all.take(5)) {
      await answer(row.word.id, AnswerResult.known, id: 'y_${row.word.id}');
    }
    env.clock.nextDay();
    expect(await env.study.dueCount(now: env.clock.now(), bookId: book.id), 5);

    final StudyQueue limited = await env.study.buildQueue(
      now: env.clock.now(),
      newLimit: 0,
      reviewLimit: 2,
      bookId: book.id,
    );
    expect(limited.cards, hasLength(2));
    expect(
      limited.cards.every((StudyCard c) => c.type == ReviewType.review),
      isTrue,
    );
    expect(limited.reviewAvailable, 5);
    expect(limited.backlog, 3);
  });

  test('T10 会话内重复练习不重复计算今日新词', () async {
    await env.seedBook(words: <String>['alpha']);
    final Word? word = await env.words.byNormalized('alpha');

    await answer(word!.id, AnswerResult.unknown, id: 'r1');
    env.clock.advance(const Duration(minutes: 1));
    await answer(
      word.id,
      AnswerResult.unknown,
      type: ReviewType.study,
      id: 'r2',
    );

    expect(
      await env.study.todayCount(now: env.clock.now(), type: ReviewType.study),
      1,
    );
    expect(
      await env.words.eventsForWord(word.id),
      hasLength(2),
      reason: '原始记录必须保留',
    );
  });

  test('T11 跨日复习任务不会丢失，今日进度重新计数', () async {
    await env.seedBook(words: <String>['alpha']);
    final Word word = (await env.words.byNormalized('alpha'))!;
    await answer(word.id, AnswerResult.known, id: 'd0');

    expect(await env.study.dueCount(now: env.clock.now()), 0);
    expect(
      await env.study.todayCount(now: env.clock.now(), type: ReviewType.study),
      1,
    );

    env.clock.nextDay();
    expect(await env.study.dueCount(now: env.clock.now()), 1);

    final StudyQueue queue = await env.study.buildQueue(
      now: env.clock.now(),
      newLimit: 30,
      reviewLimit: 100,
    );
    expect(queue.cards, hasLength(1));
    expect(queue.cards.single.type, ReviewType.review);

    final TodayProgress progress = await env.study.todayProgress(
      now: env.clock.now(),
      newTarget: 30,
      reviewLimit: 100,
    );
    expect(progress.newDone, 0);
    expect(progress.reviewDone, 0);
    expect(progress.dueNow, 1);
  });

  test('T12 关闭并重新打开应用后学习进度仍然存在', () async {
    final Directory dir = Directory.systemTemp.createTempSync(
      'materialword_persist',
    );
    final String path = '${dir.path}/app.sqlite';
    try {
      final AppDatabase first = AppDatabase(NativeDatabase(File(path)));
      final WordRepository firstWords = WordRepository(first);
      final StudyRepository firstStudy = StudyRepository(first);
      final Word word = await firstWords.ensureWord(
        text: 'alpha',
        now: env.clock.now(),
      );
      await firstStudy.recordAnswer(
        wordId: word.id,
        result: AnswerResult.hazy,
        type: ReviewType.study,
        eventId: 'persist-1',
        deviceId: 'device-a',
        now: env.clock.now(),
      );
      await first.close();

      final AppDatabase second = AppDatabase(NativeDatabase(File(path)));
      final WordRepository secondWords = WordRepository(second);
      final Word? reloaded = await secondWords.byNormalized('alpha');
      expect(reloaded, isNotNull);
      final LearningState? state = await secondWords.stateFor(reloaded!.id);
      expect(state, isNotNull);
      expect(state!.hazyCount, 1);
      expect(await secondWords.eventsForWord(reloaded.id), hasLength(1));
      await second.close();
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('T19 快速重复作答不会产生重复学习记录', () async {
    await env.seedBook(words: <String>['alpha']);
    final Word word = (await env.words.byNormalized('alpha'))!;
    final StudySession session = env.session();
    await session.load(newLimit: 10, reviewLimit: 10);
    expect(session.current, isNotNull);
    session.reveal();

    await Future.wait(<Future<AnswerRecord?>>[
      session.submit(AnswerResult.known),
      session.submit(AnswerResult.known),
      session.submit(AnswerResult.known),
    ]);
    // Without revealing again, further taps must be ignored.
    await session.submit(AnswerResult.known);

    expect(await env.words.eventsForWord(word.id), hasLength(1));
    expect(session.newAnswered, 1);
    session.dispose();
  });
}
