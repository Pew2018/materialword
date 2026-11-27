import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/navigation.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/features/study/study_page.dart';
import 'package:materialword/shared/widgets/common.dart';

import 'helpers/test_dictionary.dart';
import 'helpers/test_env.dart';

void main() {
  test('UI Android, iOS and macOS share the Cupertino horizontal slide', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isFalse);
    // Secondary pages slide in horizontally on Android too — same Cupertino
    // builder as iOS/macOS — so the first frame already paints the final
    // app-bar colour. Never "up from the bottom": that reads as a modal.
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.windows],
      isA<FadeForwardsPageTransitionsBuilder>(),
    );
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:enableOnBackInvokedCallback="true"'),
    );
    expect(
      AppTheme.light(accent: Colors.teal).colorScheme.secondary,
      Colors.teal,
    );
  });

  test('UI navigation has exactly two states and follows the window width', () {
    // Bottom bar, then the full labelled side navigation. The icon-only rail
    // that used to exist between 720 and 899 is gone for good: a narrow macOS
    // window is a phone layout, and anything from 720dp up gets the complete
    // rail with icons, labels and the brand block.
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      expect(
        layoutFor(width: 1280, platform: platform),
        ShellLayout.rail,
        reason: '1280 on $platform',
      );
      expect(layoutFor(width: 900, platform: platform), ShellLayout.rail);
      expect(layoutFor(width: 800, platform: platform), ShellLayout.rail);
      expect(
        layoutFor(width: 720, platform: platform),
        ShellLayout.rail,
        reason: 'the breakpoint itself already gets the full rail',
      );
      expect(
        layoutFor(width: 719, platform: platform),
        ShellLayout.bottomBar,
        reason: 'one dp below the breakpoint is the phone layout',
      );
      expect(
        layoutFor(width: 640, platform: platform),
        ShellLayout.bottomBar,
        reason: 'narrow window on $platform must use the bottom bar',
      );
      expect(layoutFor(width: 412, platform: platform), ShellLayout.bottomBar);
    }
    // Only two states exist; the enum itself guarantees no third layout.
    expect(ShellLayout.values, hasLength(2));
  });

  testWidgets(
    'UI bottom navigation animates colour without replacing the ink response',
    (tester) async {
      int index = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: ClassicBottomNavigationBar(
                currentIndex: index,
                onTap: (i) => setState(() => index = i),
              ),
            ),
          ),
        ),
      );
      final item = find.byKey(const ValueKey('nav-wordLists'));
      final ink = find.descendant(of: item, matching: find.byType(InkWell));
      final inkElement = tester.element(ink);
      final widget = tester.widget<InkWell>(ink);
      // Rectangular hit area: no rounded border, no pill, no clipped card.
      expect(widget.customBorder, isNull);
      expect(widget.splashFactory, InkRipple.splashFactory);
      // Nothing paints a persistent selection background.
      expect(widget.highlightColor, isNot(Colors.transparent));
      final Rect itemRect = tester.getRect(item);
      final Material surface = tester.widget<Material>(
        find.descendant(of: item, matching: find.byType(Material)).first,
      );
      expect(surface.color, isNull, reason: 'selected item has no tint');
      final label = find
          .descendant(of: item, matching: find.byType(Text))
          .first;
      final original = tester.widget<Text>(label).style!.color;
      final origin = tester.getTopLeft(item) + const Offset(9, 9);
      final gesture = await tester.startGesture(origin);
      await tester.pump(const Duration(milliseconds: 70));
      await gesture.up();
      await tester.pump();
      expect(index, 1);
      expect(identical(tester.element(ink), inkElement), isTrue);
      await tester.pump(const Duration(milliseconds: 60));
      final middle = tester.widget<Text>(label).style!.color;
      expect(middle, isNot(original));
      expect(middle, isNot(AppTheme.light().colorScheme.primary));
      await tester.pump(AppMotion.fast);
      expect(
        tester.widget<Text>(label).style!.color,
        AppTheme.light().colorScheme.primary,
      );
      expect(identical(tester.element(ink), inkElement), isTrue);
      // Selection changes colour only: the geometry is untouched.
      expect(tester.getRect(item), itemRect);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UI panes use parent width rather than global MediaQuery width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1800, 900)),
          child: Center(
            child: SizedBox(
              width: 700,
              child: AdaptiveTwoPane(
                list: const Text('list'),
                detail: const Text('detail'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('list'), findsOneWidget);
    expect(find.text('detail'), findsNothing);
  });

  testWidgets(
    'UI macOS navigation survives narrow and short resize with search state',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final env = await TestEnv.create();
      await env.settings.load();
      addTearDown(env.dispose);
      final dictionary = TestDictionary.create({});
      addTearDown(dictionary.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(env.db),
            dictionaryProvider.overrideWith((ref) async => dictionary.service),
            clockProvider.overrideWithValue(env.clock),
          ],
          child: const MaterialWordApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('nav-dictionary')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final field = find.byType(TextField).first;
      await tester.enterText(field, 'retained');
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pump(const Duration(milliseconds: 300));
      final controller = tester.widget<TextField>(field).controller;
      tester.view.physicalSize = const Size(550, 340);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // A 550dp macOS window is a phone layout: bottom bar, no rail.
      expect(find.byType(ClassicBottomNavigationBar), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller,
        same(controller),
      );
      expect(controller!.text, 'retained');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      // Drain Drift's deferred query-cache removals before database.close().
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('UI prompt input survives route dismissal animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => promptForText(context, title: '名称', label: '输入'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'value');
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets(
    'UI dashboard resumes the persisted card and skip does not fabricate an answer',
    (tester) async {
      final env = await TestEnv.create();
      await env.seedBook(words: ['alpha', 'beta', 'gamma']);
      final session = env.session();
      await session.load(newLimit: 3, reviewLimit: 10);
      session.reveal();
      await session.submit(AnswerResult.unknown);
      final current = session.current!.word.word;
      session.dispose();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(env.db),
            clockProvider.overrideWithValue(env.clock),
          ],
          child: const MaterialWordApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('继续学习'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(StudyPage), findsOneWidget);
      expect(find.text(current), findsWidgets);
      expect(await env.db.select(env.db.reviewEvents).get(), hasLength(1));
      await tester.tap(find.byTooltip('跳过'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(await env.db.select(env.db.reviewEvents).get(), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await env.dispose();
    },
  );
}
