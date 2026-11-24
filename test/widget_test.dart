import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/navigation.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/core/database/app_database.dart';

import 'helpers/test_env.dart';

/// Pumps the real application with an in-memory database.
Future<TestEnv> pumpApp(
  WidgetTester tester, {
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final TestEnv env = await TestEnv.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(env.db),
        clockProvider.overrideWithValue(env.clock),
      ],
      child: const MaterialWordApp(),
    ),
  );
  await settle(tester);
  return env;
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('T17 基础页面渲染（首页 + 空状态）', (WidgetTester tester) async {
    final TestEnv env = await pumpApp(tester);

    expect(find.text('MaterialWord'), findsOneWidget);
    expect(find.text('今日任务'), findsOneWidget);
    expect(find.text('当前学习词书'), findsOneWidget);
    // Empty database → onboarding card instead of study buttons.
    expect(find.text('还没有单词'), findsOneWidget);

    // Seeded data shows up after invalidation.
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    await env.settings.save(currentWordBookId: Value<String?>(book.id));
    await settle(tester);

    expect(tester.takeException(), isNull);
    await env.dispose();
  });

  testWidgets('T17 词书页面可用', (WidgetTester tester) async {
    final TestEnv env = await pumpApp(tester);
    await env.seedBook(name: '六级核心', words: <String>['alpha', 'beta', 'gamma']);

    await tester.tap(find.byIcon(Icons.library_books_outlined).first);
    await settle(tester);

    expect(find.text('我的词书'), findsOneWidget);
    expect(find.text('六级核心'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await env.dispose();
  });

  group('T18 不同窗口宽度下无严重布局溢出', () {
    for (final Size size in <Size>[
      const Size(360, 740),
      const Size(600, 900),
      const Size(1024, 768),
      const Size(1600, 1000),
    ]) {
      testWidgets('宽度 ${size.width.toInt()} 不溢出', (WidgetTester tester) async {
        final TestEnv env = await pumpApp(tester, size: size);
        await env.seedBook(words: <String>['alpha', 'beta']);
        await settle(tester);

        expect(tester.takeException(), isNull);

        // Visit every tab to make sure none of them overflows.
        //
        // Phase 2 replaced the official `BottomNavigationBar` with the custom
        // `ClassicBottomNavigationBar` (fixed item widths, item-scoped ripple,
        // separate hover/focus/pressed feedback). The assertion follows the new
        // widget but keeps exactly the same intent.
        final bool narrow = size.width < 900;
        expect(
          find.byType(ClassicBottomNavigationBar),
          narrow ? findsOneWidget : findsNothing,
        );
        for (final String label in <String>['词书', '词典', '统计', '设置', '今日']) {
          await tester.tap(find.byKey(ValueKey<String>('nav-$label')));
          await settle(tester);
          expect(tester.takeException(), isNull);
        }
        await env.dispose();
      });
    }
  });
}
