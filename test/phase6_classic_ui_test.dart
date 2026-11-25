import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/navigation.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/features/study/study_page.dart';
import 'package:materialword/services/tts_service.dart';
import 'package:materialword/shared/widgets/classic_select.dart';

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

/// The final UI contract: one classic Material shape scale, a rectangular
/// bottom bar without a selected background, a single-surface study action bar
/// and menus that never stretch to the page width.
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

  BorderRadiusGeometry? radiusOf(ButtonStyle? style) {
    final OutlinedBorder? shape = style?.shape?.resolve(<WidgetState>{});
    if (shape is RoundedRectangleBorder) return shape.borderRadius;
    return null;
  }

  test('one classic shape scale for buttons, fields, menus and cards', () {
    final ThemeData theme = AppTheme.light();
    expect(theme.useMaterial3, isFalse);
    expect(radiusOf(theme.elevatedButtonTheme.style), BorderRadius.circular(2));
    expect(radiusOf(theme.outlinedButtonTheme.style), BorderRadius.circular(2));
    expect(radiusOf(theme.textButtonTheme.style), BorderRadius.circular(2));

    final ShapeBorder dialog = theme.dialogTheme.shape!;
    expect(
      (dialog as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(AppDimens.radius),
    );
    final ShapeBorder menu = theme.popupMenuTheme.shape!;
    expect(
      (menu as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(AppDimens.radius),
    );
    expect(theme.popupMenuTheme.elevation, 8);
    final ShapeBorder card = theme.cardTheme.shape!;
    expect(
      (card as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(AppDimens.cardRadius),
    );
    // Nothing in the app is allowed to reintroduce the 10–12dp button.
    expect(AppDimens.buttonRadius, lessThanOrEqualTo(4));
  });

  testWidgets('bottom bar: five equal rectangles, no tint, no pill', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int index = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => Scaffold(
            bottomNavigationBar: ClassicBottomNavigationBar(
              currentIndex: index,
              onTap: (int i) => setState(() => index = i),
            ),
          ),
        ),
      ),
    );

    final List<Rect> rects = <Rect>[
      for (final AppDestination destination in appDestinations)
        tester.getRect(
          find.byKey(ValueKey<String>('nav-${destination.label}')),
        ),
    ];
    expect(rects, hasLength(5));
    for (final Rect rect in rects) {
      expect(rect.width, closeTo(80, 0.5), reason: 'equal width');
      expect(rect.height, closeTo(AppDimens.bottomNavHeight, 0.5));
    }

    // No selection background, no rounded container, no card: the item is a
    // transparent rect that the splash is clipped by.
    void expectNoTint() {
      for (final AppDestination destination in appDestinations) {
        final Finder item = find.byKey(
          ValueKey<String>('nav-${destination.label}'),
        );
        final Material surface = tester.widget<Material>(
          find.descendant(of: item, matching: find.byType(Material)).first,
        );
        expect(
          surface.color,
          isNull,
          reason: '${destination.label} background',
        );
        expect(surface.shape, isNull, reason: '${destination.label} shape');
        final InkWell ink = tester.widget<InkWell>(
          find.descendant(of: item, matching: find.byType(InkWell)).first,
        );
        expect(ink.customBorder, isNull, reason: 'rect ink area');
      }
    }

    expectNoTint();
    final Rect before = tester.getRect(
      find.byKey(const ValueKey<String>('nav-统计')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('nav-统计')));
    await settle(tester);
    expect(index, 3);
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('nav-统计'))),
      before,
      reason: 'selecting must not move or resize the item',
    );
    expectNoTint();
    expect(tester.takeException(), isNull);
  });

  testWidgets('study action bar is one surface with a classic button', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final TestEnv env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(words: <String>['alpha', 'beta']);
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
          ttsServiceProvider.overrideWithValue(_SilentTts()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(platform: TargetPlatform.macOS),
          home: const StudyPage(),
        ),
      ),
    );
    await settle(tester);

    // The shortcut is a hint next to the action, never part of its label.
    expect(find.text('显示释义'), findsOneWidget);
    expect(find.textContaining('（Space）'), findsNothing);
    expect(find.text('Space'), findsOneWidget);

    // No second elevated white layer wrapped around the button.
    final Iterable<Material> surfaces = tester.widgetList<Material>(
      find.byType(Material),
    );
    expect(
      surfaces.where((Material m) => m.elevation >= 8),
      isEmpty,
      reason: 'the action bar must not be a floating card',
    );

    // The rendered surface (theme style resolved) is a 2dp rectangle.
    BorderRadiusGeometry? renderedRadius(String label) {
      final Material surface = tester.widget<Material>(
        find
            .descendant(
              of: find.widgetWithText(ElevatedButton, label),
              matching: find.byType(Material),
            )
            .first,
      );
      final ShapeBorder? shape = surface.shape;
      return shape is RoundedRectangleBorder ? shape.borderRadius : null;
    }

    expect(renderedRadius('显示释义'), BorderRadius.circular(2));

    await tester.tap(find.text('显示释义'));
    await settle(tester);

    final List<Rect> answers = <Rect>[
      for (final String label in <String>['不认识', '模糊', '认识'])
        tester.getRect(find.widgetWithText(ElevatedButton, label)),
    ];
    expect(answers.map((Rect r) => r.height), everyElement(closeTo(48, 0.5)));
    expect(answers[0].width, closeTo(answers[1].width, 0.5));
    expect(answers[1].width, closeTo(answers[2].width, 0.5));
    for (final String label in <String>['不认识', '模糊', '认识']) {
      expect(renderedRadius(label), BorderRadius.circular(2));
    }
    expect(tester.takeException(), isNull);
    await clean(tester);
  });

  testWidgets('classic select opens a constrained menu with 16dp margins', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String value = 'a';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          appBar: AppBar(title: const Text('选择')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) =>
                  ClassicSelect<String>(
                    label: '当前学习词书',
                    value: value,
                    options: const <ClassicOption<String>>[
                      ClassicOption<String>(value: 'a', label: '全部词书'),
                      ClassicOption<String>(
                        value: 'b',
                        label: 'CET-6 示例词书（31 词）',
                      ),
                    ],
                    onChanged: (String picked) =>
                        setState(() => value = picked),
                  ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ClassicSelect<String>));
    await settle(tester);
    final Rect menu = tester.getRect(find.byType(PopupMenuItem<String>).first);
    expect(menu.width, lessThanOrEqualTo(320));
    expect(menu.width, greaterThanOrEqualTo(112));
    expect(menu.left, greaterThanOrEqualTo(16));
    expect(menu.right, lessThanOrEqualTo(1000 - 16));

    await tester.tap(find.text('CET-6 示例词书（31 词）'));
    await settle(tester);
    expect(find.text('CET-6 示例词书（31 词）'), findsOneWidget);
    expect(value, 'b');
    expect(tester.takeException(), isNull);
  });

  testWidgets('classic menu keeps its surface and contrast in dark mode', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ThemeData theme = AppTheme.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          appBar: AppBar(title: const Text('选择')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ClassicSelect<String>(
              label: '当前学习词书',
              value: 'a',
              options: const <ClassicOption<String>>[
                ClassicOption<String>(value: 'a', label: '全部词书'),
                ClassicOption<String>(value: 'b', label: 'CET-6 示例词书'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ClassicSelect<String>));
    await settle(tester);

    // The menu is the dark surface, not a white sheet, and its labels keep the
    // light text colour.
    final Material surface = tester.widget<Material>(
      find
          .ancestor(
            of: find.byType(PopupMenuItem<String>).first,
            matching: find.byType(Material),
          )
          .last,
    );
    expect(surface.color, theme.colorScheme.surface);
    final Text label = tester.widget<Text>(find.text('CET-6 示例词书'));
    expect(label.style?.color ?? theme.textTheme.bodyMedium?.color, isNotNull);
    expect(
      ThemeData.estimateBrightnessForColor(theme.colorScheme.surface),
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard has one primary action and no duplicate 词书 entry', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final TestEnv env = await TestEnv.create();
    await env.seedBook(words: <String>['alpha', 'beta', 'gamma']);
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

    expect(find.text('当前学习词书'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, '词书'),
      findsNothing,
      reason: 'the navigation bar already has a 词书 destination',
    );
    expect(find.widgetWithText(ElevatedButton, '开始学习'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '只做复习'), findsOneWidget);
    // Special drills are list rows, not a row of competing buttons.
    expect(find.text('专项复习'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '困难词专项'), findsNothing);
    expect(tester.takeException(), isNull);
    await clean(tester);
    await env.dispose();
  });
}
