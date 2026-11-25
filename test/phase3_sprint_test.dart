import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/models/sprint_plan.dart';
import 'package:materialword/core/repositories/sprint_repository.dart';
import 'package:materialword/services/backup_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SprintPlan plan(String id, {bool over = false, bool unlearned = true}) =>
      SprintPlan(
        enabled: true,
        examDate: '2026-12-01',
        bookId: id,
        roundSize: 5,
        includeUnlearned: unlearned,
        allowOverReviewLimit: over,
      );
  Future<void> transfer(TestEnv a, TestEnv b) async => b.backup.mergeDataset(
    jsonDecode(await a.backup.exportToJson(now: a.clock.now()))
        as Map<String, Object?>,
    now: b.clock.now(),
  );

  test('SPRINT calendar validation and plan-only saves preserve ordinary/device settings', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    final book = await e.seedBook(words: ['alpha']);
    await e.settings.save(
      dailyNewTarget: 42,
      dailyReviewLimit: 81,
      theme: ThemePreference.dark,
      ttsVoice: 'device voice',
    );
    final prior = await e.settings.sharedVersion();
    await e.settings.save(sprintPlan: plan(book.id));
    final current = await e.settings.load();
    expect(current.dailyNewTarget, 42);
    expect(current.dailyReviewLimit, 81);
    expect(current.themeMode, 'dark');
    expect(current.ttsVoice, 'device voice');
    expect(
      (await e.settings.sharedVersion())['counter'],
      (prior['counter'] as int) + 1,
    );
    expect((await e.settings.loadSprintPlan()).daysUntil(e.clock.now()), 7);
    final valid = (await e.settings.loadSprintPlan()).toJson();
    for (final bad in [
      {'examDate': '2026-02-30'},
      {'roundSize': 0},
      {'includeUnlearned': 'true'},
      {'version': 1.0},
      {'version': 2},
    ]) {
      expect(
        () => SprintPlan.fromJson({...valid, ...bad}),
        throwsFormatException,
      );
    }
    await e.settings.save(
      sprintPlan: SprintPlan.fromJson({...valid, 'enabled': false}),
    );
    expect((await e.settings.load()).dailyNewTarget, 42);
    expect((await e.settings.load()).studyMode, current.studyMode);
  });

  test('SPRINT book scope, unlearned switch and ordinary review allowance are real', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    final book = await e.seedBook(words: ['alpha', 'beta']);
    await e.seedBook(name: 'other', words: ['gamma']);
    await e.settings.save(dailyReviewLimit: 1, sprintPlan: plan(book.id));
    final repo = SprintRepository(e.db);
    final first = await repo.overview(
      await e.settings.loadSprintPlan(),
      e.clock.now(),
    );
    expect(first.total, 2);
    expect(first.unlearned, 2);
    expect(first.wordIds, hasLength(1));
    expect(first.reviewAllowance, 1);
    final s = e.session();
    addTearDown(s.dispose);
    await s.load(
      newLimit: 0,
      reviewLimit: 1,
      special: SpecialReview.sprint,
      bookId: book.id,
      focusedWordIds: first.wordIds,
    );
    s.reveal();
    expect(await s.submit(AnswerResult.known), isNotNull);
    expect(
      (await s.summary()).newWords,
      1,
      reason: 'new exposure is reported honestly within the sprint',
    );
    expect(
      await e.study.todayCount(now: e.clock.now(), type: ReviewType.study),
      0,
    );
    final exhausted = await repo.overview(plan(book.id), e.clock.now());
    expect(exhausted.wordIds, isEmpty);
    expect(exhausted.reviewAllowance, 0);
    final override = await repo.overview(
      plan(book.id, over: true),
      e.clock.now(),
    );
    expect(override.wordIds, hasLength(2));
    final onlySeen = await repo.overview(
      plan(book.id, over: true, unlearned: false),
      e.clock.now(),
    );
    expect(onlySeen.eligible, 1);
  });

  test('SPRINT undo removes recent mistakes and deleted book never becomes all words', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    final book = await e.seedBook(words: ['alpha']);
    await e.seedBook(name: 'other', words: ['beta']);
    final id = (await e.words.byNormalized('alpha'))!.id;
    await e.study.recordAnswer(
      wordId: id,
      result: AnswerResult.unknown,
      type: ReviewType.study,
      eventId: 'wrong',
      deviceId: 'device',
      now: e.clock.now(),
    );
    final repo = SprintRepository(e.db);
    final before = await repo.overview(plan(book.id), e.clock.now());
    expect(before.hard, 1);
    expect(before.recentMistakes, 1);
    await e.study.undoAnswer(
      eventId: 'wrong',
      undoId: 'undo-wrong',
      deviceId: 'device',
      now: e.clock.now(),
    );
    final after = await repo.overview(plan(book.id), e.clock.now());
    expect(after.hard, 0);
    expect(after.recentMistakes, 0);
    await e.books.softDelete(book.id, now: e.clock.now());
    final deleted = await repo.overview(plan(book.id), e.clock.now());
    expect(deleted.bookAvailable, isFalse);
    expect(deleted.wordIds, isEmpty);
    expect(deleted.total, 0);
  });

  test('SPRINT observed quota or plan changes block answers without consuming the card', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    final book = await e.seedBook(words: ['alpha', 'beta']);
    await e.settings.save(dailyReviewLimit: 1, sprintPlan: plan(book.id));
    final id = (await e.words.byNormalized('alpha'))!.id,
        other = (await e.words.byNormalized('beta'))!.id;
    final s = e.session();
    addTearDown(s.dispose);
    await s.load(
      newLimit: 0,
      reviewLimit: 1,
      special: SpecialReview.sprint,
      bookId: book.id,
      focusedWordIds: [id],
    );
    await e.study.recordAnswer(
      wordId: other,
      result: AnswerResult.known,
      type: ReviewType.review,
      eventId: 'elsewhere',
      deviceId: 'other',
      now: e.clock.now(),
    );
    s.reveal();
    expect(await s.submit(AnswerResult.known), isNull);
    expect(s.current!.word.id, id);
    expect((await s.summary()).attempts, 0);
    await e.study.undoAnswer(
      eventId: 'elsewhere',
      undoId: 'undo-elsewhere',
      deviceId: 'other',
      now: e.clock.now(),
    );
    expect(await s.submit(AnswerResult.known), isNotNull);
    final next = e.session();
    addTearDown(next.dispose);
    await next.load(
      newLimit: 0,
      reviewLimit: 1,
      special: SpecialReview.sprint,
      bookId: book.id,
      focusedWordIds: [other],
    );
    await e.settings.save(
      sprintPlan: SprintPlan.fromJson({
        ...plan(book.id).toJson(),
        'enabled': false,
      }),
    );
    next.reveal();
    expect(await next.submit(AnswerResult.known), isNull);
    expect(next.error, contains('计划已改变'));
  });

  test('SPRINT smoothed evidence and coverage prevent a sparse error from owning every slot', () {
    final now = DateTime(2026, 11, 24, 9);
    Map<String, Object?> candidate(
      String id,
      int wrong,
      int correct, {
      int? last,
      int? due,
    }) => {
      'id': id,
      'normalized': id,
      'stage': StudyStage.review.code,
      'wrong_count': wrong,
      'hazy_count': 0,
      'correct_count': correct,
      'interval_days': 30,
      'consecutive_wrong': 0,
      'last_studied_at': last ?? now.millisecondsSinceEpoch,
      'next_review_at': due,
    };
    final single = SprintPlan.fromJson({
      ...plan('book', over: true).toJson(),
      'roundSize': 1,
    });
    expect(
      rankSprintCandidates(
        [candidate('sparse', 1, 0), candidate('evidenced', 5, 5)],
        single,
        now,
        100,
      ).wordIds,
      ['evidenced'],
    );
    final many = [
      for (var i = 0; i < 9; i++) candidate('hard$i', 10, 5),
      candidate('oldest', 0, 30, last: 0),
    ];
    final chosen = rankSprintCandidates(
      many,
      plan('book', over: true),
      now,
      100,
    ).wordIds;
    expect(chosen, hasLength(5));
    expect(chosen.toSet(), hasLength(5));
    expect(chosen, contains('oldest'));
    final hardOff = SprintPlan.fromJson({
      ...single.toJson(),
      'prioritizeHard': false,
    });
    final options = [
      candidate('hard', 5, 5),
      candidate('due', 0, 20, due: now.millisecondsSinceEpoch - 1),
    ];
    expect(rankSprintCandidates(options, single, now, 100).wordIds, ['hard']);
    expect(rankSprintCandidates(options, hardOff, now, 100).wordIds, ['due']);
    final justCorrect = {
      ...candidate('recent-hard', 5, 5),
      'last_result': AnswerResult.known.code,
    };
    final unseen = {
      ...candidate('unseen', 0, 0),
      'stage': 0,
      'interval_days': 0,
      'last_studied_at': null,
    };
    expect(
      rankSprintCandidates([justCorrect, unseen], single, now, 100).wordIds,
      ['unseen'],
    );
    final expired = SprintPlan.fromJson({
      ...single.toJson(),
      'examDate': '2026-11-23',
    });
    expect(rankSprintCandidates(options, expired, now, 100).wordIds, isEmpty);
  });

  test('SPRINT shared plan maps independent book UUIDs and three-device hashes converge', () async {
    final a = await TestEnv.create(),
        b = await TestEnv.create(),
        c = await TestEnv.create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    addTearDown(c.dispose);
    final ab = await a.seedBook(words: ['alpha']),
        bb = await b.seedBook(words: ['alpha']);
    await b.settings.save(theme: ThemePreference.dark, ttsVoice: 'local voice');
    await a.settings.save(sprintPlan: plan(ab.id));
    await transfer(a, b);
    await transfer(b, a);
    await transfer(b, c);
    await transfer(c, a);
    expect((await b.settings.loadSprintPlan()).bookId, bb.id);
    expect((await b.settings.load()).ttsVoice, 'local voice');
    expect((await b.settings.load()).themeMode, 'dark');
    final ah = BackupService.contentHashOf(
      await a.backup.buildDataset(now: a.clock.now()),
    );
    expect(
      BackupService.contentHashOf(
        await b.backup.buildDataset(now: b.clock.now()),
      ),
      ah,
    );
    expect(
      BackupService.contentHashOf(
        await c.backup.buildDataset(now: c.clock.now()),
      ),
      ah,
    );
  });

  test(
    'SPRINT corrupt plan or dangling scope rejects the complete import',
    () async {
      final e = await TestEnv.create(), target = await TestEnv.create();
      addTearDown(e.dispose);
      addTearDown(target.dispose);
      final book = await e.seedBook(words: ['alpha']);
      await e.settings.save(sprintPlan: plan(book.id));
      final original = await e.backup.buildDataset(now: e.clock.now());
      for (final bad in [
        {'bookId': 'missing'},
        {'examDate': '2026-02-30'},
        {'roundSize': 0},
        {'enabled': 'true'},
      ]) {
        final data = jsonDecode(jsonEncode(original)) as Map<String, Object?>;
        final shared = data['settings'] as Map,
            current = shared['sprintPlan'] as Map;
        shared['sprintPlan'] = {...current, ...bad};
        await expectLater(
          target.backup.mergeDataset(data, now: target.clock.now()),
          throwsA(isA<BackupException>()),
        );
        expect(await target.db.select(target.db.words).get(), isEmpty);
      }
    },
  );
}
