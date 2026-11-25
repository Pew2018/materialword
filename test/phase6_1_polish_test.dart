import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/navigation.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/features/statistics/statistics_page.dart';
import 'package:materialword/features/sync/sync_settings_page.dart';
import 'package:materialword/services/practice_session.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/tts_service.dart';
import 'package:materialword/shared/widgets/common.dart';

import 'helpers/test_dictionary.dart';
import 'helpers/test_env.dart';

/// Phase 6.1 — the interaction contract.
///
/// Everything here is a UI contract, not a data contract: two navigation
/// states, one switch row, a slider that follows the pointer, a statistics
/// row whose label and number share one type scale, one search entry point,
/// one sync page, and a visible classic ripple on every top-bar button.
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

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _clean(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

/// The page's own vertical scroller.
///
/// The shell's side navigation is a [SingleChildScrollView] that comes first in
/// the tree, so a bare `find.byType(Scrollable).first` drags the rail and the
/// target never appears.
Finder _pageScrollable() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(target, delta, scrollable: _pageScrollable());
  await _settle(tester);
}

/// Pumps the real shell at [size] with a fresh in-memory database.
Future<TestEnv> _pumpShell(
  WidgetTester tester, {
  required Size size,
  TestDictionary? dictionary,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final TestEnv env = await TestEnv.create();
  addTearDown(() async {
    // Unmount *before* closing the database, even when an assertion aborted the
    // test: a page that is still mounted keeps firing timers and queries and
    // would throw into the next test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await env.dispose();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(env.db),
        clockProvider.overrideWithValue(env.clock),
        ttsServiceProvider.overrideWithValue(_SilentTts()),
        if (dictionary != null)
          dictionaryProvider.overrideWith((ref) async => dictionary.service),
      ],
      child: const MaterialWordApp(),
    ),
  );
  await _settle(tester);
  return env;
}

void main() {
  group('NAV 响应式导航', () {
    test('NAV03 只有底栏与完整侧栏两种状态', () {
      expect(ShellLayout.values, hasLength(2));
      expect(
        ShellLayout.values.map((ShellLayout value) => value.name),
        isNot(contains('compactRail')),
      );
      // The breakpoint is the only thing that decides: no platform is special.
      for (final double width in <double>[0, 412, 600, 719]) {
        expect(
          layoutFor(width: width, platform: TargetPlatform.macOS),
          ShellLayout.bottomBar,
          reason: '$width must be the phone layout',
        );
      }
      for (final double width in <double>[720, 800, 900, 1024, 1600]) {
        expect(
          layoutFor(width: width, platform: TargetPlatform.macOS),
          ShellLayout.rail,
          reason: '$width must be the full side navigation',
        );
      }
    });

    testWidgets('NAV01/NAV02 719 是底栏，720 是完整文字侧栏', (WidgetTester tester) async {
      await _pumpShell(tester, size: const Size(719, 900));
      expect(find.byType(ClassicBottomNavigationBar), findsOneWidget);
      expect(find.text('MaterialWord'), findsNothing);
      await _clean(tester);

      await _pumpShell(tester, size: const Size(720, 900));
      expect(find.byType(ClassicBottomNavigationBar), findsNothing);
      expect(find.text('MaterialWord'), findsOneWidget);
      for (final String label in <String>['今日', '词书', '词典', '统计', '设置']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey<String>('nav-$label')),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: 'the rail shows icon and label at 720dp',
        );
      }
      await _clean(tester);
    });

    testWidgets('NAV04 720 / 840 / 900 / 1024 都不溢出且能切换', (
      WidgetTester tester,
    ) async {
      for (final double width in <double>[720, 840, 900, 1024]) {
        final TestEnv env = await _pumpShell(tester, size: Size(width, 900));
        await env.seedBook(words: <String>['alpha', 'beta']);
        await _settle(tester);

        expect(tester.takeException(), isNull, reason: 'after $width pump');
        expect(
          find.byType(ClassicBottomNavigationBar),
          findsNothing,
          reason: '$width must not fall back to the phone bar',
        );
        for (final String label in <String>['词书', '词典', '统计', '设置', '今日']) {
          await tester.tap(find.byKey(ValueKey<String>('nav-$label')));
          await _settle(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: 'no RenderFlex overflow on $label at $width',
          );
        }
        await _clean(tester);
      }
    });

    testWidgets('NAV05 侧栏切换一级页面时状态保留', (WidgetTester tester) async {
      final TestDictionary dictionary = TestDictionary.create(
        <String, ({String translation, String definition, String phonetic})>{
          'abandon': (
            translation: '放弃',
            definition: 'to give up',
            phonetic: 'əˈbændən',
          ),
        },
      );
      addTearDown(dictionary.dispose);
      await _pumpShell(
        tester,
        size: const Size(900, 900),
        dictionary: dictionary,
      );

      await tester.tap(find.byKey(const ValueKey<String>('nav-词典')));
      await _settle(tester);
      final TextEditingController controller = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!;
      await tester.enterText(find.byType(TextField).first, 'abandon');
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey<String>('nav-统计')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('nav-词典')));
      await _settle(tester);

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller,
        same(controller),
      );
      expect(controller.text, 'abandon');
      expect(tester.takeException(), isNull);
      await _clean(tester);
    });
  });

  group('SET 设置页', () {
    testWidgets('SET01 随机学习顺序有 shuffle 图标，SET02 三行开关一致', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, size: const Size(1280, 900));
      await tester.tap(find.byKey(const ValueKey<String>('nav-设置')));
      await _settle(tester);

      final Finder randomRow = find.widgetWithText(SwitchListTile, '随机学习顺序');
      await _reveal(tester, randomRow);

      expect(
        find.descendant(of: randomRow, matching: find.byIcon(Icons.shuffle)),
        findsOneWidget,
        reason: 'the row that was missing its leading icon now has one',
      );

      // Every switch row is the same component with the same paddings.
      final List<SwitchListTile> switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches, isNotEmpty);
      for (final SwitchListTile tile in switches) {
        expect(
          tile.contentPadding,
          const EdgeInsets.symmetric(horizontal: AppDimens.gutter, vertical: 2),
          reason: 'one padding for every switch row',
        );
        expect(tile.dense, isNot(true), reason: 'no mixed dense rows');
      }
      await _clean(tester);
    });

    testWidgets('SET03/04/05 Slider 连续跟手，松手才写库', (WidgetTester tester) async {
      final TestEnv env = await _pumpShell(tester, size: const Size(1280, 900));
      await tester.tap(find.byKey(const ValueKey<String>('nav-设置')));
      await _settle(tester);

      final Finder sliderFinder = find.byType(Slider);
      await _reveal(tester, sliderFinder);

      final Slider slider = tester.widget<Slider>(sliderFinder);
      expect(
        slider.divisions,
        isNull,
        reason: '18 divisions made every drag jump in 5% steps',
      );
      expect(slider.min, 10);
      expect(slider.max, 100);

      final int before = (await env.settings.load()).ttsRate;
      final Rect rect = tester.getRect(sliderFinder);
      final TestGesture gesture = await tester.startGesture(
        Offset(rect.left + 8, rect.center.dy),
      );
      await tester.pump();
      await gesture.moveTo(Offset(rect.center.dx, rect.center.dy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(
        (await env.settings.load()).ttsRate,
        before,
        reason: 'dragging only moves the draft, never the database',
      );

      await gesture.up();
      await tester.pump();
      await _settle(tester);
      expect(
        (await env.settings.load()).ttsRate,
        isNot(before),
        reason: 'release commits exactly once',
      );
      expect(tester.takeException(), isNull);
      await _clean(tester);
    });
  });

  group('SCROLL 滚动物理', () {
    testWidgets('SCROLL01 macOS 用跟手的 Clamping，其他平台不变', (
      WidgetTester tester,
    ) async {
      const ClassicScrollBehavior behavior = ClassicScrollBehavior();

      // `MaterialScrollBehavior.getPlatform` reads the *theme* platform, so the
      // test states it explicitly instead of relying on the host OS.
      Future<ScrollPhysics> physicsOn(TargetPlatform platform) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform, useMaterial3: false),
            // A fresh element per platform: reusing the element would keep the
            // old `Theme` dependency and silently report the previous theme.
            home: Builder(
              key: ValueKey<TargetPlatform>(platform),
              builder: (BuildContext inner) {
                context = inner;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        // `MaterialApp` animates theme changes; read the platform after the
        // animation, otherwise the previous theme is still the current one.
        await tester.pump(const Duration(milliseconds: 400));
        return behavior.getScrollPhysics(context);
      }

      final ScrollPhysics macos = await physicsOn(TargetPlatform.macOS);
      expect(macos, isA<ClampingScrollPhysics>());
      expect(macos, isNot(isA<BouncingScrollPhysics>()));
      expect(macos.parent, isA<RangeMaintainingScrollPhysics>());

      expect(
        await physicsOn(TargetPlatform.iOS),
        isA<BouncingScrollPhysics>(),
        reason: 'iOS keeps its own physics',
      );
      expect(
        await physicsOn(TargetPlatform.android),
        isA<ClampingScrollPhysics>(),
      );
      expect(
        await physicsOn(TargetPlatform.windows),
        isA<ClampingScrollPhysics>(),
      );
    });
  });

  group('STAT 作答构成', () {
    testWidgets('STAT01/02/03 父子同一字号、真实缩进、保留等宽数字', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      final WordBook book = await env.seedBook(
        words: <String>['alpha', 'beta', 'gamma'],
      );
      final List<String> ids = await env.db
          .customSelect('SELECT id FROM words ORDER BY normalized')
          .map((row) => row.read<String>('id'))
          .get();
      await env.study.recordAnswer(
        wordId: ids[0],
        result: AnswerResult.known,
        type: ReviewType.review,
        eventId: 'normal-1',
        deviceId: 'device',
        now: env.clock.now(),
      );
      final PracticeSession practice = PracticeSession(
        env.study,
        env.settings,
        env.clock,
      );
      await practice.load(kind: PracticeKind.choice, bookId: book.id);
      addTearDown(practice.dispose);
      await practice.submitChoice(practice.current!.correctIndex ?? 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(env.db),
            clockProvider.overrideWithValue(env.clock),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: StatisticsPage()),
          ),
        ),
      );
      await _settle(tester);

      final Finder childLabel = find.text('• ${PracticeKind.choice.label}');
      await _reveal(tester, childLabel);

      final Finder parentLabel = find.text('练习模式');
      expect(parentLabel, findsOneWidget);
      expect(childLabel, findsOneWidget);

      List<Text> rowTexts(Finder label) {
        final Finder row = find
            .ancestor(of: label, matching: find.byType(Row))
            .first;
        return tester
            .widgetList<Text>(
              find.descendant(of: row, matching: find.byType(Text)),
            )
            .toList();
      }

      final List<Text> parent = rowTexts(parentLabel);
      final List<Text> child = rowTexts(childLabel);
      expect(parent, hasLength(2));
      expect(child, hasLength(2));

      // Left and right belong to the same visual level.
      expect(parent[0].style?.fontSize, parent[1].style?.fontSize);
      expect(child[0].style?.fontSize, child[1].style?.fontSize);
      // …and a child row really is one level below its parent.
      expect(child[0].style!.fontSize!, lessThan(parent[0].style!.fontSize!));
      // The number column keeps tabular figures.
      expect(
        child[1].style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      // Real layout indent, not a full-width space in the label.
      expect(
        tester.getTopLeft(childLabel).dx - tester.getTopLeft(parentLabel).dx,
        closeTo(16, 0.5),
      );
      for (final Text text in <Text>[...parent, ...child]) {
        expect(
          text.data ?? '',
          isNot(contains('\u3000')),
          reason: 'no ideographic space used for layout',
        );
      }
      await _clean(tester);
    });
  });

  group('DICT 词典搜索入口', () {
    testWidgets('DICT01/02/03 AppBar 只剩页面内搜索，⌘F 仍然聚焦', (
      WidgetTester tester,
    ) async {
      final TestDictionary dictionary = TestDictionary.create(
        <String, ({String translation, String definition, String phonetic})>{
          'abandon': (
            translation: '放弃',
            definition: 'to give up',
            phonetic: 'əˈbændən',
          ),
        },
      );
      addTearDown(dictionary.dispose);
      await _pumpShell(
        tester,
        size: const Size(1280, 900),
        dictionary: dictionary,
      );
      await tester.tap(find.byKey(const ValueKey<String>('nav-词典')));
      await _settle(tester);

      // DICT01: the duplicated AppBar search button is gone.
      expect(find.byTooltip('搜索 (⌘F)'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ClassicAppBar),
          matching: find.byIcon(Icons.search),
        ),
        findsNothing,
      );

      // DICT02: the in-page field keeps its own search affordance.
      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.decoration?.prefixIcon, isA<Icon>());

      // DICT03: ⌘F / Ctrl+F still jumps to the dictionary and focuses the
      // field. (Ctrl+F is pressed from another tab so nothing is being edited.)
      await tester.tap(find.byKey(const ValueKey<String>('nav-统计')));
      await _settle(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await _settle(tester);
      expect(find.text('词典'), findsWidgets);
      TextField current() =>
          tester.widget<TextField>(find.byType(TextField).first);
      expect(current().focusNode?.hasFocus, isTrue);

      current().focusNode!.unfocus();
      await _settle(tester);
      expect(current().focusNode?.hasFocus, isFalse);

      // Go back to another tab and press the desktop shortcut again: tapping a
      // destination must hand keyboard focus back to the shell, otherwise the
      // shortcut would stop working after the first navigation tap.
      await tester.tap(find.byKey(const ValueKey<String>('nav-今日')));
      await _settle(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await _settle(tester);
      expect(current().focusNode?.hasFocus, isTrue);

      expect(tester.takeException(), isNull);
      await _clean(tester);
    });
  });

  group('SYNCUI 数据同步页', () {
    Future<TestEnv> pumpSync(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.settings.setSyncConfig(<String, Object?>{
        'provider': 'github',
        'owner': 'test-user',
        'repo': 'data',
        'branch': 'main',
        'path': 'backup.json',
        'autoOnStart': true,
        'autoOnResume': true,
        'autoOnChange': true,
        'autoAfterSession': true,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(env.db),
            clockProvider.overrideWithValue(env.clock),
            credentialStoreProvider.overrideWithValue(
              InMemoryCredentialStore(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SyncSettingsPage(),
          ),
        ),
      );
      await _settle(tester);
      return env;
    }

    testWidgets('SYNCUI01 四个自动同步开关完全一致', (WidgetTester tester) async {
      await pumpSync(tester);

      const List<String> labels = <String>[
        '启动时同步',
        '返回应用时同步',
        '数据变化后自动同步',
        '本轮学习结束后同步',
      ];
      final List<double> heights = <double>[];
      for (final String label in labels) {
        final Finder row = find.widgetWithText(SwitchListTile, label);
        await _reveal(tester, row);
        final SwitchListTile tile = tester.widget<SwitchListTile>(row);
        expect(
          tile.contentPadding,
          const EdgeInsets.symmetric(horizontal: AppDimens.gutter, vertical: 2),
          reason: '$label padding',
        );
        expect(tile.dense, isNot(true), reason: '$label density');
        expect(tile.secondary, isA<Icon>(), reason: '$label leading icon');
        heights.add(tester.getSize(row).height);
      }
      expect(heights.toSet(), hasLength(1), reason: '$heights');
      await _clean(tester);
    });

    testWidgets('SYNCUI02 只有立即同步是主按钮', (WidgetTester tester) async {
      await pumpSync(tester);
      await _reveal(tester, find.widgetWithText(ElevatedButton, '立即同步'));

      expect(find.widgetWithText(OutlinedButton, '测试连接'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '立即同步'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '导出备份'), findsOneWidget);
      expect(find.text('导出本地备份'), findsNothing);
      // Exactly one primary action on the page.
      expect(find.byType(ElevatedButton), findsOneWidget);
      await _clean(tester);
    });

    testWidgets('SYNCUI03 高级说明默认收起', (WidgetTester tester) async {
      await pumpSync(tester);
      final Finder summary = find.text('同步与合并说明');
      await _reveal(tester, summary);

      expect(summary, findsOneWidget);
      expect(
        find.textContaining('同一个单词只保留一条记录'),
        findsNothing,
        reason: 'the main page is not a protocol document',
      );
      expect(find.textContaining('Keystore'), findsNothing);

      await tester.tap(summary);
      await _settle(tester);
      expect(
        find.textContaining('同一个单词只保留一条记录'),
        findsOneWidget,
        reason: 'the details are one tap away',
      );
      await _clean(tester);
    });

    testWidgets('SYNCUI04 连接输入框左右边距与间距一致', (WidgetTester tester) async {
      await pumpSync(tester);
      await _reveal(tester, find.text('GitHub 用户名或组织'));

      final List<Rect> rects = <Rect>[
        for (int i = 0; i < 5; i++)
          tester.getRect(find.byType(TextField).at(i)),
      ];
      for (final Rect rect in rects) {
        expect(rect.left, closeTo(rects.first.left, 0.5));
        expect(rect.width, closeTo(rects.first.width, 0.5));
      }
      final List<double> gaps = <double>[
        for (int i = 1; i < rects.length; i++)
          rects[i].top - rects[i - 1].bottom,
      ];
      for (final double gap in gaps) {
        expect(
          gap,
          closeTo(gaps.first, 1),
          reason: 'every field sits at the same distance: $gaps',
        );
        expect(gap, greaterThanOrEqualTo(15));
      }
      await _clean(tester);
    });
  });

  group('TOP AppBar 交互反馈', () {
    /// Builds a two-route app so the automatic [BackButton] is on screen, and
    /// returns the theme so colours can be compared.
    Future<void> pumpPushedPage(WidgetTester tester, ThemeData theme) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              appBar: ClassicAppBar(title: const Text('第一页')),
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext inner) => Scaffold(
                        appBar: ClassicAppBar(
                          title: const Text('第二页'),
                          actions: <Widget>[
                            IconButton(
                              tooltip: '添加',
                              icon: const Icon(Icons.add),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        body: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  child: const Text('进入'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('进入'));
      await _settle(tester);
    }

    void expectRippleContract(WidgetTester tester, ThemeData theme) {
      final Color background = theme.appBarTheme.backgroundColor!;
      final Color foreground = theme.appBarTheme.foregroundColor!;

      final Finder appBar = find.byType(ClassicAppBar);
      final List<InkResponse> inks = tester
          .widgetList<InkResponse>(
            find.descendant(of: appBar, matching: find.byType(InkResponse)),
          )
          .toList();
      expect(inks, hasLength(2), reason: 'back button + action button');
      for (final InkResponse ink in inks) {
        final Color splash = ink.splashColor!;
        expect(
          splash,
          isNot(background),
          reason: 'an accent splash on an accent bar is invisible',
        );
        // The splash is the *foreground* colour at low alpha.
        expect(splash.r, closeTo(foreground.r, 0.001));
        expect(splash.g, closeTo(foreground.g, 0.001));
        expect(splash.b, closeTo(foreground.b, 0.001));
        expect(splash.a, greaterThan(0.1));
        expect(
          (Color.alphaBlend(splash, background).computeLuminance() -
                  background.computeLuminance())
              .abs(),
          greaterThan(0.02),
          reason: 'the pressed state must actually be visible',
        );
      }
      expect(inks[0].splashColor, inks[1].splashColor);
      // The override really lives in the AppBar subtree's theme, which is why
      // a back arrow this project never constructs also gets the ripple.
      final ThemeData appBarTheme = Theme.of(
        tester.element(find.byType(AppBar)),
      );
      expect(appBarTheme.splashFactory, InkRipple.splashFactory);
      expect(appBarTheme.splashColor, isNot(background));
      expect(appBarTheme.highlightColor, isNot(background));
    }

    testWidgets('TOP01-07 浅色主题：返回与操作按钮都有可见 foreground ripple', (
      WidgetTester tester,
    ) async {
      final ThemeData theme = AppTheme.light();
      await pumpPushedPage(tester, theme);
      expectRippleContract(tester, theme);

      // 24dp icon, at least 48dp hit target, no persistent container.
      final Finder appBar = find.byType(ClassicAppBar);
      final Finder backInk = find
          .descendant(of: appBar, matching: find.byType(InkResponse))
          .first;
      expect(tester.getSize(backInk).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(backInk).height, greaterThanOrEqualTo(48));
      final Icon backIcon = tester.widget<Icon>(
        find.descendant(of: appBar, matching: find.byType(Icon)).first,
      );
      expect(backIcon.size ?? AppDimens.iconSize, AppDimens.iconSize);

      final List<Material> materials = tester
          .widgetList<Material>(
            find.descendant(of: appBar, matching: find.byType(Material)),
          )
          .toList();
      expect(
        materials.where((Material m) => m.shape != null),
        isEmpty,
        reason: 'no circle, pill or filled icon container',
      );
      expect(
        materials.where(
          (Material m) =>
              m.color != null && m.color != theme.appBarTheme.backgroundColor,
        ),
        isEmpty,
      );

      // Press must not leave anything behind.
      final Rect before = tester.getRect(find.byTooltip('添加'));
      await tester.tap(find.byTooltip('添加'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getRect(find.byTooltip('添加')), before);
      expect(
        tester
            .widgetList<Material>(
              find.descendant(
                of: find.byType(ClassicAppBar),
                matching: find.byType(Material),
              ),
            )
            .where((Material m) => m.shape != null),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await _clean(tester);
    });

    testWidgets('TOP08 深色主题同样可见', (WidgetTester tester) async {
      final ThemeData theme = AppTheme.dark();
      await pumpPushedPage(tester, theme);
      expectRippleContract(tester, theme);
      expect(
        ThemeData.estimateBrightnessForColor(
          theme.appBarTheme.backgroundColor!,
        ),
        Brightness.dark,
      );
      await _clean(tester);
    });
  });
}
