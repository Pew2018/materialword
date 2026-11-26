import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/models/sprint_plan.dart';
import 'package:materialword/features/study/sprint_page.dart';
import 'package:materialword/features/study/study_page.dart';

import 'helpers/l10n_fixture.dart';
import 'helpers/test_env.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(finder, findsWidgets);
  }

  Future<void> mount(WidgetTester tester, TestEnv e) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          home: const SprintPage(),
        ),
      ),
    );
    await waitFor(tester, find.text('开始冲刺'));
    await settle(tester);
  }

  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'UI starts real sprint answers and exits without changing ordinary targets',
    (tester) async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      final book = await e.seedBook(words: ['alpha', 'beta']);
      await e.settings.save(
        dailyNewTarget: 42,
        dailyReviewLimit: 81,
        sprintPlan: SprintPlan(
          enabled: true,
          examDate: '2026-12-01',
          bookId: book.id,
          roundSize: 2,
          includeUnlearned: true,
          allowOverReviewLimit: true,
        ),
      );
      await mount(tester, e);
      expect(find.text('距离考试 7 天'), findsOneWidget);
      await tester.tap(find.text('开始冲刺').hitTestable());
      await waitFor(tester, find.byType(StudyPage));
      await settle(tester);
      await tester.tap(find.text('显示释义'));
      await settle(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, '认识'));
      await settle(tester);
      expect(
        (await e.db.select(e.db.reviewEvents).get()).single.mode,
        ReviewEventMode.specialSprint,
      );
      expect(
        await e.study.todayCount(now: e.clock.now(), type: ReviewType.review),
        1,
      );
      expect(
        await e.study.todayCount(now: e.clock.now(), type: ReviewType.study),
        0,
      );
      // `pageBack()` only recognises an English "Back" tooltip or a Cupertino
      // button; this app runs in Chinese on the classic Material app bar.
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text(zhText.continueSprint), findsOneWidget);
      final exit = find.text(zhText.endSprint);
      await tester.ensureVisible(exit);
      await settle(tester);
      await tester.tap(exit.hitTestable());
      await settle(tester);
      expect((await e.settings.loadSprintPlan()).enabled, isFalse);
      expect((await e.settings.load()).dailyNewTarget, 42);
      expect((await e.settings.load()).dailyReviewLimit, 81);
      expect(tester.takeException(), isNull);
      await clean(tester);
    },
  );

  testWidgets(
    'UI plan dialog cancellation is inert and confirmed edits persist',
    (tester) async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      final book = await e.seedBook(words: ['alpha', 'beta']);
      await e.settings.save(
        sprintPlan: SprintPlan(
          enabled: true,
          examDate: '2026-12-01',
          bookId: book.id,
          roundSize: 2,
          includeUnlearned: true,
          allowOverReviewLimit: true,
        ),
      );
      await mount(tester, e);
      final prior = await e.settings.sharedVersion();
      await tester.tap(find.byTooltip(zhText.setSprintPlan));
      await settle(tester);
      final size = find.widgetWithText(TextField, zhText.roundSizeRange);
      await tester.ensureVisible(size);
      await tester.enterText(size, '99');
      await tester.tap(find.text(zhText.commonCancel).hitTestable());
      await settle(tester);
      expect((await e.settings.loadSprintPlan()).roundSize, 2);
      expect(await e.settings.sharedVersion(), prior);
      await tester.tap(find.byTooltip(zhText.setSprintPlan));
      await settle(tester);
      await tester.ensureVisible(size);
      await tester.enterText(size, '3');
      await tester.tap(find.text(zhText.commonSave).hitTestable());
      await settle(tester);
      expect((await e.settings.loadSprintPlan()).roundSize, 3);
      expect(tester.takeException(), isNull);
      await clean(tester);
    },
  );
}
