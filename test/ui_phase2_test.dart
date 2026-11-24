import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/navigation.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/features/study/study_page.dart';
import 'package:materialword/features/word_management/quick_add_page.dart';
import 'package:materialword/features/word_management/word_management_page.dart';
import 'package:materialword/services/dictionary_service.dart';

import 'helpers/test_dictionary.dart';
import 'helpers/test_env.dart';

/// UI01 – UI09: navigation geometry, state preservation, the slider write
/// discipline, theme switching, responsive layout and the fixed answer bar.
void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<TestEnv> pumpApp(
    WidgetTester tester, {
    Size size = const Size(420, 900),
    DictionaryService? dictionary,
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
          if (dictionary != null)
            dictionaryProvider.overrideWith((Ref ref) async => dictionary),
        ],
        child: const MaterialWordApp(),
      ),
    );
    await settle(tester);
    return env;
  }

  group('UI01 底栏项目等宽且选中状态稳定', () {
    testWidgets('五个项目宽度一致，选中不改变尺寸', (WidgetTester tester) async {
      final TestEnv env = await pumpApp(tester);
      const List<String> labels = <String>['今日', '词书', '词典', '统计', '设置'];

      final List<Size> before = <Size>[];
      final List<Offset> positions = <Offset>[];
      for (final String label in labels) {
        final Finder item = find.byKey(ValueKey<String>('nav-$label'));
        expect(item, findsOneWidget);
        before.add(tester.getSize(item));
        positions.add(tester.getTopLeft(item));
      }
      // Equal widths (window width / 5) and a single row.
      for (final Size size in before) {
        expect(size.width, closeTo(420 / 5, 0.5));
        expect(size.height, closeTo(before.first.height, 0.5));
      }
      expect(positions.map((Offset o) => o.dy).toSet().length, 1);

      await tester.tap(find.byKey(const ValueKey<String>('nav-统计')));
      await settle(tester);

      for (int i = 0; i < labels.length; i++) {
        final Finder item = find.byKey(ValueKey<String>('nav-${labels[i]}'));
        expect(tester.getSize(item), before[i], reason: '尺寸不能因选中而变化');
        expect(tester.getTopLeft(item), positions[i], reason: '位置不能跳动');
      }
      expect(tester.takeException(), isNull);
      await env.dispose();
    });
  });

  group('UI02 涟漪、悬停与焦点边界', () {
    testWidgets('每个导航项有自己的 Material 与 InkWell', (WidgetTester tester) async {
      final TestEnv env = await pumpApp(tester);
      final Finder bar = find.byType(ClassicBottomNavigationBar);
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.byType(InkWell)),
        findsNWidgets(5),
      );

      for (final String label in <String>['今日', '词书', '词典', '统计', '设置']) {
        final Finder item = find.byKey(ValueKey<String>('nav-$label'));
        final Finder ink = find.descendant(
          of: item,
          matching: find.byType(InkWell),
        );
        expect(ink, findsOneWidget);
        // The InkWell exactly covers the item: a splash cannot bleed into a
        // neighbouring tab.
        expect(tester.getSize(ink), tester.getSize(item));
      }
      expect(tester.takeException(), isNull);
      await env.dispose();
    });
  });

  group('UI03 切换一级页面保留状态', () {
    testWidgets('搜索文本在切换标签后保留', (WidgetTester tester) async {
      final TestEnv env = await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey<String>('nav-词典')));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, 'abandon');
      await settle(tester);
      expect(find.text('abandon'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('nav-统计')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('nav-词典')));
      await settle(tester);

      expect(
        find.text('abandon'),
        findsOneWidget,
        reason: 'IndexedStack keeps the page (and its text) alive',
      );
      await env.dispose();
    });
  });

  group('UI04 Slider 拖动不写库', () {
    testWidgets('拖动期间数值实时变化，松手才写一次数据库', (WidgetTester tester) async {
      final TestEnv env = await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey<String>('nav-设置')));
      await settle(tester);

      final int before = (await env.settings.load()).dailyNewTarget;
      final Finder slider = find.byType(Slider).first;
      final Offset center = tester.getCenter(slider);

      final TestGesture gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();

      // During the drag the persisted value must not change.
      expect((await env.settings.load()).dailyNewTarget, before);

      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      expect((await env.settings.load()).dailyNewTarget, before);

      await gesture.up();
      await settle(tester);

      final int after = (await env.settings.load()).dailyNewTarget;
      expect(after, greaterThan(before));
      expect(tester.takeException(), isNull);
      await env.dispose();
    });
  });

  group('UI06 强调色即时生效并持久化', () {
    testWidgets('选择预设色后主题立即改变且写入设置', (WidgetTester tester) async {
      final TestEnv env = await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey<String>('nav-设置')));
      await settle(tester);

      await tester.tap(find.byTooltip('蓝绿'));
      await settle(tester);

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.theme!.colorScheme.primary, const Color(0xFF00796B));
      expect((await env.settings.load()).accentColor, '#00796B');

      // Dark theme stays usable with the same accent.
      expect(app.darkTheme, isNotNull);
      expect(app.darkTheme!.brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
      await env.dispose();
    });

    testWidgets('自定义 HEX 与恢复默认', (WidgetTester tester) async {
      final TestEnv env = await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey<String>('nav-设置')));
      await settle(tester);

      await env.settings.save(accentColor: '#00796B');
      await settle(tester);
      await tester.ensureVisible(find.text('自定义 HEX'));
      await settle(tester);
      await tester.tap(find.text('自定义 HEX').hitTestable());
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, '#6A1B9A');
      await tester.tap(find.text('应用'));
      await settle(tester);
      expect((await env.settings.load()).accentColor, '#6A1B9A');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('恢复默认'));
      await settle(tester);
      await tester.tap(find.text('恢复默认').hitTestable());
      await settle(tester);
      expect((await env.settings.load()).accentColor, '#1565C0');
      await env.dispose();
    });
  });

  group('UI07 不同尺寸窗口无溢出（含词汇管理）', () {
    for (final Size size in <Size>[
      const Size(360, 740),
      const Size(760, 900),
      const Size(1200, 900),
    ]) {
      testWidgets('宽度 ${size.width.toInt()} 的词汇管理页面不溢出', (
        WidgetTester tester,
      ) async {
        final TestEnv env = await TestEnv.create();
        await env.seedBook(words: <String>['alpha', 'beta', 'gamma']);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(env.db),
              clockProvider.overrideWithValue(env.clock),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const WordManagementPage(),
            ),
          ),
        );
        await settle(tester);
        expect(find.text('alpha'), findsWidgets);
        expect(tester.takeException(), isNull);
        await env.dispose();
      });
    }
  });

  group('UI08 移动端不显示桌面快捷键', () {
    testWidgets('手机宽度隐藏快捷键提示', (WidgetTester tester) async {
      final TestEnv env = await pumpApp(tester, size: const Size(400, 820));
      await tester.tap(find.byKey(const ValueKey<String>('nav-今日')));
      await settle(tester);
      expect(find.textContaining('⌘'), findsNothing);

      await env.dispose();
    });

    testWidgets('桌面宽度显示快捷键提示', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final TestEnv env = await TestEnv.create();
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(env.db),
            clockProvider.overrideWithValue(env.clock),
          ],
          child: MaterialApp(
            theme: AppTheme.light(platform: TargetPlatform.macOS),
            home: const QuickAddPage(),
          ),
        ),
      );
      await settle(tester);
      expect(find.textContaining('⌘'), findsWidgets);
      await env.dispose();
    });
  });

  group('UI09 长释义不遮挡固定作答区', () {
    testWidgets('超长释义时三个作答按钮仍在屏幕内', (WidgetTester tester) async {
      final TestDictionary dictionary = TestDictionary.create(
        <String, ({String translation, String definition, String phonetic})>{
          'verbose': (
            translation: List<String>.generate(
              40,
              (int i) => '第 $i 行非常长的中文释义，用于验证滚动区域与固定操作区',
            ).join('\n'),
            definition: 'a very long definition line',
            phonetic: 'vɜːˈbəʊs',
          ),
        },
      );
      addTearDown(dictionary.dispose);

      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(words: <String>['verbose']);
      await env.settings.save(currentWordBookId: Value<String?>(book.id));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(env.db),
            clockProvider.overrideWithValue(env.clock),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const StudyPage()),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('显示释义'));
      await settle(tester);

      final Finder known = find.widgetWithText(ElevatedButton, '认识');
      expect(known, findsOneWidget);
      final Rect rect = tester.getRect(known);
      expect(rect.bottom, lessThanOrEqualTo(700));
      expect(rect.top, greaterThan(400));
      expect(tester.takeException(), isNull);
      await env.dispose();
    });
  });
}
