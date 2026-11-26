import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/repositories/settings_repository.dart';
import 'package:materialword/core/repositories/study_repository.dart';
import 'package:materialword/features/study/study_page.dart';
import 'package:materialword/services/study_session.dart';

import 'helpers/l10n_fixture.dart';
import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'ROUND unique words, attempts, results and difficulties survive undo',
    () async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha', 'beta', 'gamma']);
      final s = e.session();
      addTearDown(s.dispose);
      await s.load(newLimit: 2, reviewLimit: 10);
      s.reveal();
      await s.submit(AnswerResult.unknown);
      s.reveal();
      await s.submit(AnswerResult.hazy);
      // An unrelated answer in this time window must never enter the round.
      final outside = (await e.words.byNormalized('gamma'))!;
      await e.study.recordAnswer(
        wordId: outside.id,
        result: AnswerResult.known,
        type: ReviewType.study,
        eventId: 'unrelated',
        deviceId: 'other',
        now: e.clock.now(),
      );
      while (!s.isFinished) {
        s.reveal();
        await s.submit(AnswerResult.known);
      }
      final summary = await s.summary();
      expect(summary.newWords, 2);
      expect(summary.reviewWords, 0);
      expect(summary.uniqueWords, 2);
      expect(summary.attempts, 4);
      expect(summary.known, 2);
      expect(summary.hazy, 1);
      expect(summary.unknown, 1);
      expect(summary.repeatAttempts, 2);
      expect(summary.accuracy, 0.5);
      expect(summary.difficultWords.map((w) => w.word), ['alpha', 'beta']);
      expect(await s.undo(), isTrue);
      final undone = await s.summary();
      expect(undone.attempts, 3);
      expect(undone.known, 1);
      expect(undone.uniqueWords, 2);
      expect(undone.repeatAttempts, 1);
    },
  );

  test(
    'ROUND actual file close/reopen restores the exact round event IDs',
    () async {
      final e = await TestEnv.create(file: true);
      addTearDown(() => File(e.filePath!).parent.delete(recursive: true));
      await e.seedBook(words: ['alpha', 'beta']);
      final s = e.session();
      await s.load(newLimit: 2, reviewLimit: 10);
      s.reveal();
      await s.submit(AnswerResult.unknown);
      e.clock.advance(const Duration(minutes: 3));
      s.dispose();
      await e.db.close();
      final db = AppDatabase(NativeDatabase(File(e.filePath!)));
      addTearDown(db.close);
      final resumed = StudySession(
        StudyRepository(db),
        SettingsRepository(db),
        e.clock,
      );
      addTearDown(resumed.dispose);
      await resumed.load(newLimit: 1, reviewLimit: 10);
      expect((await resumed.summary()).unknown, 1);
      while (!resumed.isFinished) {
        resumed.reveal();
        await resumed.submit(AnswerResult.known);
      }
      final summary = await resumed.summary();
      expect(summary.attempts, 3);
      expect(summary.uniqueWords, 2);
      expect(summary.elapsed, const Duration(minutes: 3));
      e.clock.advance(const Duration(hours: 1));
      expect((await resumed.summary()).elapsed, const Duration(minutes: 3));
    },
  );

  test('ROUND failed submit rolls back both raw events and summary IDs', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha', 'beta']);
    final s = e.session();
    addTearDown(s.dispose);
    await s.load(newLimit: 2, reviewLimit: 10);
    await e.db.customStatement(
      "CREATE TRIGGER fail_round_snapshot BEFORE INSERT ON app_meta WHEN NEW.key = '${StudySession.persistenceKey}' BEGIN SELECT RAISE(ABORT, 'fault'); END",
    );
    s.reveal();
    expect(await s.submit(AnswerResult.unknown), isNull);
    expect((await s.summary()).attempts, 0);
    expect(await e.db.select(e.db.reviewEvents).get(), isEmpty);
    await e.db.customStatement('DROP TRIGGER fail_round_snapshot');
    expect(await s.submit(AnswerResult.unknown), isNotNull);
    expect((await s.summary()).attempts, 1);
  });

  test('ROUND focused practice does not add daily new words or inflate long intervals', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha', 'beta']);
    final id = (await e.words.byNormalized('alpha'))!.id;
    await e.study.markMastered(
      wordId: id,
      deviceId: 'device',
      now: e.clock.now(),
      eventId: 'mastered',
    );
    final before = (await e.words.stateFor(id))!;
    final s = e.session();
    addTearDown(s.dispose);
    await s.load(
      newLimit: 0,
      reviewLimit: 0,
      special: SpecialReview.sessionMistakes,
      focusedWordIds: [id, id, 'missing'],
    );
    expect(s.totalCards, 1);
    s.reveal();
    await s.submit(AnswerResult.known);
    expect((await e.words.stateFor(id))!.intervalDays, before.intervalDays);
    expect((await e.words.stateFor(id))!.nextReviewAt, before.nextReviewAt);
    expect(
      await e.study.todayCount(now: e.clock.now(), type: ReviewType.study),
      0,
    );
    expect((await s.summary()).reviewWords, 1);
    expect(
      (await e.words.eventsForWord(id)).first.mode,
      ReviewEventMode.specialSessionMistakes,
    );
    await e.backup.validateDatasetAsync(
      await e.backup.buildDataset(now: e.clock.now()),
    );
  });

  test('ROUND remote undo removes its result and deleted words cannot enter focused practice', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha']);
    final s = e.session();
    addTearDown(s.dispose);
    await s.load(newLimit: 1, reviewLimit: 10);
    final id = s.current!.word.id;
    s.reveal();
    final answer = await s.submit(AnswerResult.unknown);
    await e.study.undoAnswer(
      eventId: answer!.eventId,
      undoId: 'remote-undo',
      deviceId: 'other',
      now: e.clock.now(),
    );
    expect((await s.summary()).attempts, 0);
    await e.words.softDelete(id, now: e.clock.now());
    final practice = e.session();
    addTearDown(practice.dispose);
    await practice.load(
      newLimit: 0,
      reviewLimit: 20,
      special: SpecialReview.sessionMistakes,
      focusedWordIds: [id],
    );
    expect(practice.isEmpty, isTrue);
  });

  testWidgets(
    'UI summary reports real attempts and starts only this round mistakes',
    (tester) async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha']);
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> settle() async {
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(e.db),
            clockProvider.overrideWithValue(e.clock),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            theme: AppTheme.light(),
            home: const StudyPage(),
          ),
        ),
      );
      await settle();
      await tester.tap(find.text('显示释义'));
      await settle();
      await tester.tap(find.widgetWithText(ElevatedButton, '不认识'));
      await settle();
      await tester.tap(find.text('显示释义'));
      await settle();
      await tester.tap(find.widgetWithText(ElevatedButton, '认识'));
      await settle();
      expect(find.text('1 个单词 · 2 次作答'), findsOneWidget);
      expect(find.text(zhText.accuracyValue('50.0%')), findsOneWidget);
      final practice = find.text('复习本轮错词');
      await tester.ensureVisible(practice);
      await settle();
      await tester.tap(practice.hitTestable());
      await settle();
      // The drill opens its own session, titled with the same entry name.
      expect(find.text(zhText.specialSessionMistakes), findsWidgets);
      await tester.tap(find.text('显示释义'));
      await settle();
      await tester.tap(find.widgetWithText(ElevatedButton, '认识'));
      await settle();
      expect(
        await e.study.todayCount(now: e.clock.now(), type: ReviewType.study),
        1,
      );
      expect(
        (await e.db.select(e.db.reviewEvents).get()).where(
          (v) => v.mode == ReviewEventMode.specialSessionMistakes,
        ),
        hasLength(1),
      );
      expect(find.text('1 个单词 · 1 次作答'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
