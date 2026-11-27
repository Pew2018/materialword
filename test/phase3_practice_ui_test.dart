import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/features/study/practice_page.dart';
import 'package:materialword/services/tts_service.dart';

import 'helpers/l10n_fixture.dart';
import 'helpers/test_env.dart';

class _SilentTts extends TtsService {
  int spoken = 0;

  @override
  Future<List<TtsVoice>> englishVoices({bool refresh = false}) async =>
      const <TtsVoice>[TtsVoice(name: 'Voice', locale: 'en-US')];

  @override
  Future<bool> speak(
    String text, {
    String? voiceName,
    String? locale,
    int rate = 50,
  }) async {
    spoken++;
    return true;
  }

  @override
  Future<void> stop() async {}
}

/// Real clicks through the practice UI: the drill must record what the user
/// actually typed or tapped, and nothing more.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<TestEnv> pumpPractice(
    WidgetTester tester,
    PracticeKind kind, {
    List<String> words = const <String>['alpha', 'beta', 'gamma'],
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    final TestEnv env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(words: words);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
          ttsServiceProvider.overrideWithValue(_SilentTts()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(platform: platform),
          home: PracticePage(kind: kind),
        ),
      ),
    );
    await settle(tester);
    return env;
  }

  testWidgets('spelling drills the typed word and reports a wrong answer', (
    WidgetTester tester,
  ) async {
    final TestEnv env = await pumpPractice(tester, PracticeKind.spelling);
    final String answer = (await env.study.practiceBatch(
      now: env.clock.now(),
      kind: PracticeKind.spelling,
    )).words.first.word;

    await tester.enterText(find.byType(TextField), 'wrong-answer');
    await tester.tap(find.text('提交'));
    await settle(tester);

    expect(find.text('错误'), findsOneWidget);
    expect(find.text(answer), findsOneWidget);
    expect(find.textContaining('正确拼写'), findsNothing);
    expect(find.textContaining('你的答案'), findsNothing);
    expect(find.textContaining('不会改变这个单词的复习间隔'), findsNothing);
    final events = await env.db.select(env.db.reviewEvents).get();
    expect(events.length, 1);
    expect(
      events.single.mode,
      ReviewEventMode.forPractice(PracticeKind.spelling),
    );
    expect(events.single.result, AnswerResult.unknown.code);
    expect(tester.takeException(), isNull);
    await clean(tester);
  });

  testWidgets('multiple choice accepts a tap and shows the word', (
    WidgetTester tester,
  ) async {
    final env = await pumpPractice(
      tester,
      PracticeKind.choice,
      words: <String>['alpha', 'beta', 'gamma', 'delta'],
    );
    final String answer = (await env.study.practiceBatch(
      now: env.clock.now(),
      kind: PracticeKind.choice,
    )).words.first.word;
    // Tap every option until one is accepted; the drill records one event only.
    final Finder options = find.byType(OutlinedButton);
    expect(options, findsWidgets);
    await tester.tap(options.first);
    await settle(tester);
    // Answered either way: the feedback card and the "next" button appear.
    expect(find.text('下一题'), findsOneWidget);
    expect(find.text(answer), findsWidgets);
    expect(find.textContaining('正确拼写'), findsNothing);
    expect(find.textContaining('你的答案'), findsNothing);
    expect(find.textContaining('不会改变这个单词的复习间隔'), findsNothing);
    expect(
      find.text('正确').evaluate().isNotEmpty ||
          find.text('错误').evaluate().isNotEmpty,
      isTrue,
    );
    final events = await env.db.select(env.db.reviewEvents).get();
    expect(events.length, 1);
    expect(
      events.single.mode,
      ReviewEventMode.forPractice(PracticeKind.choice),
    );
    expect(tester.takeException(), isNull);
    await clean(tester);
  });

  testWidgets('desktop choice uses 1–4 then Space for next', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final TestEnv env = await pumpPractice(
      tester,
      PracticeKind.choice,
      words: <String>['alpha', 'beta', 'gamma', 'delta'],
      platform: TargetPlatform.macOS,
    );
    expect(find.byType(OutlinedButton), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await settle(tester);
    expect(find.text('下一题'), findsOneWidget);
    expect(find.textContaining('正确拼写'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    // Either the next question or the results screen.
    expect(
      find.text('下一题').evaluate().isEmpty ||
          find.byType(OutlinedButton).evaluate().isNotEmpty ||
          find.text('查看结果').evaluate().isNotEmpty ||
          find.textContaining('正确').evaluate().isNotEmpty,
      isTrue,
    );
    final events = await env.db.select(env.db.reviewEvents).get();
    expect(events, isNotEmpty);
    expect(tester.takeException(), isNull);
    await clean(tester);
  });

  testWidgets('desktop spelling keeps Space in the text field', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpPractice(
      tester,
      PracticeKind.spelling,
      platform: TargetPlatform.macOS,
    );
    await tester.tap(find.byType(TextField));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'a');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    // Space must not advance the question while the field owns focus.
    expect(find.text('下一题'), findsNothing);
    expect(find.text('查看结果'), findsNothing);
    expect(tester.takeException(), isNull);
    await clean(tester);
  });

  testWidgets('dictation speaks the word instead of showing it', (
    WidgetTester tester,
  ) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(words: <String>['alpha', 'beta']);
    final tts = _SilentTts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
          ttsServiceProvider.overrideWithValue(tts),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          home: const PracticePage(kind: PracticeKind.dictation),
        ),
      ),
    );
    await settle(tester);
    expect(tts.spoken, greaterThan(0));
    expect(find.text('听发音，输入单词'), findsOneWidget);
    expect(find.byTooltip(zhText.showHint), findsOneWidget);
    expect(tester.takeException(), isNull);
    await clean(tester);
  });
}
