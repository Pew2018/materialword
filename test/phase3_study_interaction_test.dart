import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/models/study_models.dart';
import 'package:materialword/features/study/study_page.dart';
import 'package:materialword/services/study_session.dart';
import 'package:materialword/services/tts_service.dart';

import 'helpers/test_env.dart';

class _SilentTts extends TtsService {
  @override
  Future<List<TtsVoice>> englishVoices({bool refresh = false}) async =>
      const <TtsVoice>[];

  @override
  Future<bool> speak(
    String text, {
    String? voiceName,
    String? locale,
    int rate = 50,
  }) async => true;

  @override
  Future<void> stop() async {}
}

/// Study-page interactions that must not become shortcuts around the recorded
/// answer: random order, swipe-to-reveal, and special queues.
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

  test('random order keeps every card exactly once', () async {
    final TestEnv env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(
      words: <String>['alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta'],
    );
    final StudyQueue queue = await env.study.buildQueue(
      now: env.clock.now(),
      newLimit: 30,
      reviewLimit: 30,
    );
    expect(queue.cards.length, 6);

    final StudySession shuffled = env.session();
    addTearDown(shuffled.dispose);
    await shuffled.load(newLimit: 30, reviewLimit: 30, shuffle: true);
    final List<String> ids = <String>[];
    final int total = shuffled.totalCards;
    for (int i = 0; i < total; i++) {
      ids.add(shuffled.current!.word.id);
      // Await: skip() is asynchronous and a second call would be ignored while
      // the first is still persisting.
      await shuffled.skip();
    }
    expect(ids.length, 6);
    expect(ids.toSet().length, ids.length, reason: 'no duplicated card');
    expect(
      ids.toSet(),
      queue.cards.map((StudyCard card) => card.word.id).toSet(),
      reason: 'shuffling must not drop a card',
    );
  });

  testWidgets(
    'swiping up reveals the meaning, tapping an answer is still required',
    (WidgetTester tester) async {
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);
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
            theme: AppTheme.light(),
            home: const StudyPage(),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('回想单词的含义'), findsOneWidget);
      expect(find.text('不认识'), findsNothing);

      await tester.fling(find.text('alpha').first, const Offset(0, -260), 1200);
      await settle(tester);

      // Revealed: the meaning and the three answer buttons are on screen.
      expect(find.text('回想单词的含义'), findsNothing);
      expect(find.text('不认识'), findsOneWidget);
      expect(find.text('模糊'), findsOneWidget);
      expect(find.text('认识'), findsOneWidget);
      // Revealing alone never records an answer.
      expect(await env.db.select(env.db.reviewEvents).get(), isEmpty);
      expect(tester.takeException(), isNull);
      await clean(tester);
    },
  );

  test('a special queue with no eligible word stays empty', () async {
    final TestEnv env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(words: <String>['alpha', 'beta']);
    final StudySession session = env.session();
    addTearDown(session.dispose);
    await session.load(
      newLimit: 0,
      reviewLimit: 20,
      special: SpecialReview.favorites,
    );
    expect(session.isEmpty, isTrue);
    expect(session.special, SpecialReview.favorites);
  });
}
