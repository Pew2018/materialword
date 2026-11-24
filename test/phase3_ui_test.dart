import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/navigation.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/shared/widgets/common.dart';

import 'helpers/test_dictionary.dart';
import 'helpers/test_env.dart';

void main() {
  test(
    'UI Android classic transition and native Apple transition are explicit',
    () {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isFalse);
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<FadeUpwardsPageTransitionsBuilder>(),
      );
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android:enableOnBackInvokedCallback="false"'),
      );
      expect(
        AppTheme.light(accent: Colors.teal).colorScheme.secondary,
        Colors.teal,
      );
      expect(
        layoutFor(width: 440, platform: TargetPlatform.macOS),
        ShellLayout.compactRail,
      );
    },
  );

  testWidgets(
    'UI bottom navigation animates colour without replacing the ink response',
    (tester) async {
      int index = 0;
      await tester.pumpWidget(
        MaterialApp(
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
      final item = find.byKey(const ValueKey('nav-词书'));
      final ink = find.descendant(of: item, matching: find.byType(InkWell));
      final inkElement = tester.element(ink);
      final widget = tester.widget<InkWell>(ink);
      expect(widget.customBorder, isA<RoundedRectangleBorder>());
      expect(
        (widget.customBorder! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(16),
      );
      expect(widget.splashFactory, InkRipple.splashFactory);
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
      await tester.pump(const Duration(milliseconds: 105));
      final middle = tester.widget<Text>(label).style!.color;
      expect(middle, isNot(original));
      expect(middle, isNot(AppTheme.light().colorScheme.primary));
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester.widget<Text>(label).style!.color,
        AppTheme.light().colorScheme.primary,
      );
      expect(identical(tester.element(ink), inkElement), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UI panes use parent width rather than global MediaQuery width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
      await tester.tap(find.byKey(const ValueKey('nav-词典')));
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
      expect(find.byType(ClassicBottomNavigationBar), findsNothing);
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
}
