import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/features/study/study_page.dart';
import 'package:materialword/features/settings/settings_page.dart';
import 'package:materialword/features/word_management/word_detail_page.dart';
import 'package:materialword/services/tts_service.dart';

import 'helpers/test_env.dart';

class _SilentTts extends TtsService {
  int stops = 0;
  int refreshes = 0;
  @override
  Future<List<TtsVoice>> englishVoices({bool refresh = false}) async {
    if (refresh) refreshes++;
    return [
      if (!refresh) const TtsVoice(name: 'Same', locale: 'en-US'),
      const TtsVoice(name: 'Same', locale: 'en-GB'),
    ];
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'UI refreshes voices with duplicate names and a removed selected locale',
    (tester) async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.settings.load();
      await e.settings.save(ttsVoice: 'Same', ttsLocale: 'en-US');
      final tts = _SilentTts();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(e.db),
            clockProvider.overrideWithValue(e.clock),
            ttsServiceProvider.overrideWithValue(tts),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SettingsPage(),
          ),
        ),
      );
      await settle(tester);
      final refresh = find.text('刷新语音列表');
      await tester.scrollUntilVisible(
        refresh,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(refresh);
      await settle(tester);
      await tester.tap(refresh.hitTestable());
      await settle(tester);
      expect(tts.refreshes, 1);
      expect(tester.takeException(), isNull);
      await clean(tester);
    },
  );

  test(
    'STUDY edited current content refreshes all repeat cards without an event',
    () async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha']);
      final session = e.session();
      addTearDown(session.dispose);
      await session.load(newLimit: 1, reviewLimit: 10);
      session.reveal();
      await session.submit(AnswerResult.unknown);
      final id = session.current!.word.id;
      await e.words.updateContent(
        id,
        translation: '最新释义',
        note: '个人笔记',
        now: e.clock.now(),
      );
      await session.refreshCurrent();
      expect(session.current!.word.translation, '最新释义');
      expect(session.current!.word.note, '个人笔记');
      expect(session.current!.repeatCount, 1);
      expect(session.totalCards, 2);
      expect(await e.db.select(e.db.reviewEvents).get(), hasLength(1));
      await e.words.softDelete(id, now: e.clock.now());
      await session.refreshCurrent();
      expect(session.isFinished, isTrue);
      expect(await e.db.select(e.db.reviewEvents).get(), hasLength(1));
    },
  );

  testWidgets(
    'UI can cancel manual mastery without adding real answer counts',
    (tester) async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha']);
      final id = (await e.words.byNormalized('alpha'))!.id;
      await e.study.markMastered(
        wordId: id,
        deviceId: 'device',
        now: e.clock.now(),
        eventId: 'mastered',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(e.db),
            clockProvider.overrideWithValue(e.clock),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: WordDetailPage(wordId: id),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('取消掌握'));
      await settle(tester);
      await tester.tap(find.text('取消掌握').hitTestable().last);
      await settle(tester);
      expect((await e.words.stateFor(id))?.intervalDays ?? 0, lessThan(30));
      expect(
        (await e.db.select(e.db.reviewEvents).get()).last.mode,
        ReviewEventMode.manualUnmastered,
      );
      expect(
        await e.study.todayCount(now: e.clock.now(), type: ReviewType.review),
        0,
      );
      expect(tester.takeException(), isNull);
      await clean(tester);
    },
  );

  testWidgets(
    'UI quick edit returns to the same card and shows saved content',
    (tester) async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha']);
      final tts = _SilentTts();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(e.db),
            clockProvider.overrideWithValue(e.clock),
            ttsServiceProvider.overrideWithValue(tts),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const StudyPage()),
        ),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('编辑当前词条'));
      await settle(tester);
      expect(find.byType(WordDetailPage), findsOneWidget);
      final note = find.widgetWithText(TextField, '个人笔记');
      await tester.ensureVisible(note);
      await tester.enterText(note, 'edited during study');
      final save = find.text('保存修改');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      expect(find.byType(StudyPage), findsOneWidget);
      expect(find.text('alpha'), findsWidgets);
      expect(
        (await e.words.byNormalized('alpha'))!.note,
        'edited during study',
      );
      expect(await e.db.select(e.db.reviewEvents).get(), isEmpty);
      expect(tts.stops, greaterThan(0));
      expect(tester.takeException(), isNull);
      await clean(tester);
    },
  );

  testWidgets('UI entering background stops application speech', (
    tester,
  ) async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    final tts = _SilentTts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(e.db),
          clockProvider.overrideWithValue(e.clock),
          ttsServiceProvider.overrideWithValue(tts),
        ],
        child: const MaterialWordApp(),
      ),
    );
    await settle(tester);
    final before = tts.stops;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tts.stops, greaterThan(before));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await clean(tester);
  });
}
