import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/l10n/language_store.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/navigation.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/features/study/study_page.dart';
import 'package:materialword/services/tts_service.dart';
import 'package:materialword/shared/widgets/classic_select.dart';
import 'package:materialword/shared/widgets/common.dart';

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

    final ThemeData classic = ThemeData.localize(
      theme,
      Typography.material2014(platform: theme.platform).englishLike,
    );
    expect(theme.appBarTheme.elevation, 1);
    expect(classic.textTheme.headlineMedium?.fontSize, 38);
    expect(classic.textTheme.headlineMedium?.fontWeight, FontWeight.w500);
    expect(classic.textTheme.headlineSmall?.fontSize, 22);
    expect(classic.textTheme.bodyLarge?.fontSize, 17);
    expect(classic.textTheme.bodyMedium?.fontSize, 14);
    expect(classic.textTheme.labelLarge?.fontSize, 14);
    expect(classic.textTheme.labelLarge?.fontWeight, FontWeight.w500);
    expect(classic.textTheme.titleMedium?.fontWeight, FontWeight.w500);
    final ShapeBorder chip = theme.chipTheme.shape!;
    expect(
      (chip as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(2),
    );

    final TextTheme stock = Typography.material2018().englishLike;
    final ThemeData modern = ThemeData.localize(
      AppTheme.light(typography: TypographyScale.material2018),
      stock,
    );
    expect(modern.useMaterial3, isFalse);
    expect(modern.appBarTheme.elevation, 4);
    expect(modern.bottomNavigationBarTheme.elevation, 8);
    for (final ButtonStyle? style in <ButtonStyle?>[
      modern.elevatedButtonTheme.style,
      modern.filledButtonTheme.style,
      modern.outlinedButtonTheme.style,
      modern.textButtonTheme.style,
    ]) {
      expect(radiusOf(style), BorderRadius.circular(4));
      expect(style?.minimumSize?.resolve(<WidgetState>{})?.height, 36);
    }
    final ShapeBorder modernCard = modern.cardTheme.shape!;
    expect(
      (modernCard as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(4),
    );
    final ShapeBorder modernChip = modern.chipTheme.shape!;
    expect(
      (modernChip as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(16),
    );
    expect(modern.textTheme.headlineMedium?.fontSize, isNot(38));
    expect(modern.textTheme.bodyLarge?.fontSize, isNot(17));
    expect(
      modern.textTheme.headlineMedium?.fontSize,
      stock.headlineMedium?.fontSize,
    );
    expect(
      modern.textTheme.headlineMedium?.letterSpacing,
      stock.headlineMedium?.letterSpacing,
    );
    expect(modern.textTheme.bodyLarge?.fontSize, stock.bodyLarge?.fontSize);
    expect(
      modern.textTheme.bodyLarge?.letterSpacing,
      stock.bodyLarge?.letterSpacing,
    );
    final ThemeData modernPainted = AppTheme.withLocalizedComponentStyles(
      modern,
    );
    expect(modernPainted.appBarTheme.titleTextStyle?.color, Colors.white);
    expect(
      modernPainted.appBarTheme.titleTextStyle?.fontSize,
      stock.titleLarge?.fontSize,
    );
    expect(
      modernPainted.elevatedButtonTheme.style?.textStyle
          ?.resolve(<WidgetState>{})
          ?.fontSize,
      stock.labelLarge?.fontSize,
    );
    expect(
      modernPainted.elevatedButtonTheme.style?.textStyle
          ?.resolve(<WidgetState>{})
          ?.fontWeight,
      stock.labelLarge?.fontWeight,
    );
    expect(
      modernPainted.elevatedButtonTheme.style?.textStyle
          ?.resolve(<WidgetState>{})
          ?.letterSpacing,
      stock.labelLarge?.letterSpacing,
    );
    expect(
      modernPainted.bottomNavigationBarTheme.selectedLabelStyle?.fontSize,
      stock.bodySmall?.fontSize,
    );
    expect(
      modernPainted.bottomNavigationBarTheme.selectedLabelStyle?.fontWeight,
      stock.bodySmall?.fontWeight,
    );
    expect(
      modernPainted.inputDecorationTheme.hintStyle?.fontSize,
      stock.bodyMedium?.fontSize,
    );
  });

  testWidgets('Material 2018 keeps its bar elevation and tag shape', (
    WidgetTester tester,
  ) async {
    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: theme,
          home: Scaffold(
            body: const TagChip(label: 'CET'),
            bottomNavigationBar: ClassicBottomNavigationBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    BorderRadius tagRadius() {
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(TagChip),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).borderRadius! as BorderRadius;
    }

    double barElevation() {
      final Material material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(ClassicBottomNavigationBar),
              matching: find.byType(Material),
            )
            .first,
      );
      return material.elevation;
    }

    await pump(AppTheme.light());
    expect(barElevation(), 3);
    expect(tagRadius(), const BorderRadius.all(Radius.circular(3)));

    await pump(AppTheme.light(typography: TypographyScale.material2018));
    expect(barElevation(), 8);
    expect(tagRadius(), const BorderRadius.all(Radius.circular(16)));
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
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
        tester.getRect(find.byKey(ValueKey<String>('nav-${destination.id}'))),
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
          ValueKey<String>('nav-${destination.id}'),
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
      find.byKey(const ValueKey<String>('nav-statistics')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('nav-statistics')));
    await settle(tester);
    expect(index, 3);
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('nav-statistics'))),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(platform: TargetPlatform.macOS),
          home: const StudyPage(),
        ),
      ),
    );
    await settle(tester);

    // Reveal fills the action strip; Space is a shortcut only, never a keycap.
    expect(find.text('显示释义'), findsOneWidget);
    expect(find.textContaining('（Space）'), findsNothing);
    expect(find.text('Space'), findsNothing);

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

  testWidgets('a 360dp study page keeps its AppBar readable', (
    WidgetTester tester,
  ) async {
    final TestEnv env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(words: <String>['alpha', 'beta']);
    // One wrong answer, so the focused drill has a card (and a long title).
    final session = env.session();
    await session.load(newLimit: 2, reviewLimit: 0);
    session.reveal();
    await session.submit(AnswerResult.unknown);
    session.dispose();

    tester.view.physicalSize = const Size(360, 740);
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          home: const StudyPage(special: SpecialReview.hard),
        ),
      ),
    );
    await settle(tester);
    // Four icon buttons plus the counter used to overflow this AppBar.
    expect(find.byTooltip('更多操作'), findsOneWidget);
    expect(find.byTooltip('跳过'), findsNothing);
    expect(find.text('显示释义'), findsOneWidget);
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: AppTheme.light(),
        home: Scaffold(
          appBar: AppBar(title: const Text('选择')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) =>
                  ClassicSelect<String>(
                    label: '学习词书',
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: theme,
        home: Scaffold(
          appBar: AppBar(title: const Text('选择')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ClassicSelect<String>(
              label: '学习词书',
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

    expect(find.text('学习词书'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, '词书'),
      findsNothing,
      reason: 'the navigation bar already has a 词书 destination',
    );
    expect(find.widgetWithText(ElevatedButton, '开始学习'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '仅复习'), findsOneWidget);
    // Special drills are list rows, not a row of competing buttons.
    expect(find.text('专项复习'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '困难词复习'), findsNothing);
    expect(tester.takeException(), isNull);
    await clean(tester);
    await env.dispose();
  });

  // ── Phase 6.5A: the solid button style is defined once and always white ──

  double contrast(Color a, Color b) {
    final double la = a.computeLuminance();
    final double lb = b.computeLuminance();
    final double hi = la > lb ? la : lb;
    final double lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('T02-T07 filled and elevated buttons share one classic solid style', () {
    for (final ThemeData theme in <ThemeData>[
      AppTheme.light(),
      AppTheme.dark(),
    ]) {
      expect(theme.useMaterial3, isFalse);
      expect(theme.filledButtonTheme.style, isNotNull);
      for (final ButtonStyle style in <ButtonStyle>[
        theme.elevatedButtonTheme.style!,
        theme.filledButtonTheme.style!,
      ]) {
        // 2dp, not a pill: `StadiumBorder` and a 10–20dp radius are both gone.
        expect(
          radiusOf(style),
          BorderRadius.circular(AppDimens.buttonRadius),
          reason: 'classic corner',
        );
        expect(style.foregroundColor!.resolve(<WidgetState>{}), Colors.white);
        expect(
          style.iconColor!.resolve(<WidgetState>{}),
          Colors.white,
          reason: 'the icon of a solid button is white too',
        );
        expect(
          style.foregroundColor!.resolve(<WidgetState>{WidgetState.disabled}),
          Colors.white,
          reason: 'a disabled fill keeps white ink, it just dims the fill',
        );
        expect(style.minimumSize!.resolve(<WidgetState>{}), const Size(88, 40));
      }
    }
    // Only the elevation may differ.
    expect(
      AppTheme.light().elevatedButtonTheme.style!.elevation!.resolve(
        <WidgetState>{},
      ),
      2,
    );
    expect(
      AppTheme.light().filledButtonTheme.style!.elevation!.resolve(
        <WidgetState>{},
      ),
      0,
    );
  });

  test('T08-T13 every accent keeps white readable on every solid fill', () {
    expect(accentPalettes, hasLength(23));
    final List<Color> accents = <Color>[
      for (final AccentPalette palette in accentPalettes) palette.color,
      // Deliberately extreme custom accents: the brightest yellow a user can
      // pick and a pure white.
      const Color(0xFFFFF176),
      const Color(0xFFFFFFFF),
      const Color(0xFFF2A227),
    ];
    for (final Color accent in accents) {
      for (final Brightness brightness in Brightness.values) {
        final ThemeData theme = AppTheme.of(brightness, accent);
        final Color fill = theme.filledButtonTheme.style!.backgroundColor!
            .resolve(<WidgetState>{})!;
        final Color ink = theme.filledButtonTheme.style!.foregroundColor!
            .resolve(<WidgetState>{})!;
        expect(ink, Colors.white, reason: '${hexOf(accent)} ink');
        expect(
          contrast(fill, ink),
          greaterThanOrEqualTo(4.5),
          reason: '${hexOf(accent)} $brightness fill contrast',
        );
        // The app bar uses the same normalised surface in light mode, and a
        // mixed surface in dark mode: both must carry a white title.
        final Color bar = theme.appBarTheme.backgroundColor!;
        if (brightness == Brightness.light) expect(bar, fill);
        expect(
          contrast(bar, Colors.white),
          greaterThanOrEqualTo(4.5),
          reason: '${hexOf(accent)} $brightness app bar',
        );
        expect(theme.appBarTheme.titleTextStyle!.color, Colors.white);
        expect(theme.appBarTheme.iconTheme!.color, Colors.white);
        expect(theme.appBarTheme.actionsIconTheme!.color, Colors.white);
      }
    }
  });

  test(
    'T14-T15 the accent preference and the answer colours are untouched',
    () {
      const Color bright = Color(0xFFF2A227);
      final ThemeData theme = AppTheme.light(accent: bright);
      final Color fill = theme.filledButtonTheme.style!.backgroundColor!
          .resolve(<WidgetState>{})!;
      // The fill is darkened so white stays readable…
      expect(fill, isNot(bright));
      // …but neither the stored value nor the picker swatch changes.
      expect(hexOf(bright), '#F2A227');
      expect(parseAccent(hexOf(bright)), bright);
      expect(
        accentPalettes
            .firstWhere((AccentPalette p) => p.id == 'classic.lemonYellow')
            .color,
        bright,
      );
      // Answer semantics stay conventional in every theme.
      expect(AppColors.known, const Color(0xFF2E7D32));
      expect(AppColors.hazy, const Color(0xFFEF6C00));
      expect(AppColors.unknown, const Color(0xFFC62828));
      expect(AppColors.forAnswer(0), AppColors.unknown);
      expect(AppColors.forAnswer(1), AppColors.hazy);
      expect(AppColors.forAnswer(2), AppColors.known);
    },
  );

  // ── Phase 6.5B: one menu, anchored to its trigger, inside the overlay ──

  Future<void> pumpSelect(
    WidgetTester tester, {
    required Size size,
    required double top,
    int options = 3,
    bool enabled = true,
    String label = '备份目标',
    String longLabel = '',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String value = 'a';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: SizedBox(
                  width: 220,
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) =>
                        ClassicSelect<String>(
                          label: label,
                          value: value,
                          enabled: enabled,
                          options: <ClassicOption<String>>[
                            ClassicOption<String>(
                              value: 'a',
                              label: longLabel.isEmpty ? '选项 A' : longLabel,
                            ),
                            for (int i = 1; i < options; i++)
                              ClassicOption<String>(
                                value: 'o$i',
                                label: '选项 $i',
                              ),
                          ],
                          onChanged: (String picked) =>
                              setState(() => value = picked),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byType(ClassicSelect<String>));
    await settle(tester);
  }

  List<Rect> menuItems(WidgetTester tester) => <Rect>[
    for (final Element e in find.byType(PopupMenuItem<String>).evaluate())
      tester.getRect(find.byWidget(e.widget)),
  ];

  testWidgets('T22-T23 the menu sits under the trigger, left aligned', (
    WidgetTester tester,
  ) async {
    await pumpSelect(tester, size: const Size(700, 800), top: 100);
    final Rect trigger = tester.getRect(find.byType(ClassicSelect<String>));
    final List<Rect> items = menuItems(tester);
    expect(items, hasLength(3));
    expect(
      items.first.left,
      closeTo(trigger.left, 0.5),
      reason: 'left aligned',
    );
    expect(
      items.first.top,
      greaterThanOrEqualTo(trigger.bottom),
      reason: 'opens below',
    );
    expect(
      items.first.top - trigger.bottom,
      lessThanOrEqualTo(14),
      reason: 'about 4dp gap plus the menu surface padding',
    );
    // Never the page width: 700dp window, 320dp menu at most.
    expect(items.first.width, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('T24 the menu flips above when the space below is too small', (
    WidgetTester tester,
  ) async {
    await pumpSelect(tester, size: const Size(700, 800), top: 520, options: 8);
    final Rect trigger = tester.getRect(find.byType(ClassicSelect<String>));
    final List<Rect> items = menuItems(tester);
    expect(items, hasLength(8));
    final double menuBottom = items.last.bottom;
    expect(
      menuBottom,
      lessThanOrEqualTo(trigger.top),
      reason: 'eight 48dp rows cannot fit below a trigger at y=520',
    );
  });

  testWidgets('T25-T27 a narrow window never produces illegal bounds', (
    WidgetTester tester,
  ) async {
    // 240dp is narrower than the 160dp minimum plus two 16dp margins.
    await pumpSelect(tester, size: const Size(240, 420), top: 40);
    final List<Rect> items = menuItems(tester);
    expect(items, isNotEmpty);
    for (final Rect item in items) {
      expect(item.width, greaterThan(0));
      expect(item.left, greaterThanOrEqualTo(0));
      expect(item.right, lessThanOrEqualTo(240));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('T26 a roomy window keeps at least a 16dp margin', (
    WidgetTester tester,
  ) async {
    await pumpSelect(tester, size: const Size(1000, 800), top: 40);
    final List<Rect> items = menuItems(tester);
    expect(items.first.left, greaterThanOrEqualTo(16));
    expect(items.first.right, lessThanOrEqualTo(1000 - 16));
    expect(items.first.top, greaterThanOrEqualTo(16));
  });

  testWidgets('T28 a long label cannot push the check mark out of the menu', (
    WidgetTester tester,
  ) async {
    await pumpSelect(
      tester,
      size: const Size(400, 800),
      top: 40,
      options: 2,
      longLabel:
          'WebDAV · dav.a-very-long-host-name.example.com/materialword-backups',
    );
    final Rect menu = menuItems(tester).first;
    final Finder check = find.byIcon(Icons.check);
    expect(check, findsOneWidget);
    final Rect tick = tester.getRect(check);
    expect(tick.right, lessThanOrEqualTo(menu.right + 0.5));
    expect(tick.left, greaterThan(menu.left));
    // The field shows the same label; both truncate rather than overflow.
    final Text label = tester.widget<Text>(
      find.textContaining('dav.a-very-long-host-name').last,
    );
    expect(label.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T30 a disabled selector cannot open a menu', (
    WidgetTester tester,
  ) async {
    await pumpSelect(
      tester,
      size: const Size(700, 800),
      top: 40,
      enabled: false,
    );
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T31 a selector inside a dialog is positioned in the overlay', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('手动备份'),
                  content: SizedBox(
                    width: 390,
                    child: ClassicSelect<String>(
                      label: '备份目标',
                      value: 'a',
                      options: const <ClassicOption<String>>[
                        ClassicOption<String>(value: 'a', label: 'S3 · bucket'),
                        ClassicOption<String>(
                          value: 'b',
                          label: 'WebDAV · dav',
                        ),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                  actions: const <Widget>[SizedBox.shrink()],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.byType(ClassicSelect<String>));
    await settle(tester);

    final Rect trigger = tester.getRect(find.byType(ClassicSelect<String>));
    final Rect item = menuItems(tester).first;
    expect(item.left, closeTo(trigger.left, 0.5));
    expect(item.top, greaterThanOrEqualTo(trigger.bottom));
    expect(item.left, greaterThanOrEqualTo(16));
    expect(item.right, lessThanOrEqualTo(700 - 16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('T32 the menu stays inside the window after a resize', (
    WidgetTester tester,
  ) async {
    await pumpSelect(tester, size: const Size(1000, 800), top: 40);
    tester.view.physicalSize = const Size(360, 640);
    await tester.pump();
    await settle(tester);
    final List<Rect> items = menuItems(tester);
    expect(items, isNotEmpty);
    for (final Rect item in items) {
      expect(item.left, greaterThanOrEqualTo(0));
      expect(item.right, lessThanOrEqualTo(360));
      expect(item.bottom, lessThanOrEqualTo(640));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('T18-T19 the language preference is a classic select, not a '
      'radio dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(920, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final TestEnv env = await TestEnv.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
          languageStoreProvider.overrideWithValue(
            MemoryLanguageStore(AppLanguage.zh),
          ),
        ],
        child: const MaterialWordApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('设置').last);
    await settle(tester);

    // The appearance group holds it, as one enumerated preference.
    final Finder select = find.byType(ClassicSelect<AppLanguage>);
    await tester.scrollUntilVisible(
      select,
      240,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await settle(tester);
    expect(select, findsOneWidget);

    await tester.tap(select);
    await settle(tester);
    // The old centred radio sheet is gone for good.
    expect(find.byType(SimpleDialog), findsNothing);
    expect(find.byType(RadioListTile<AppLanguage>), findsNothing);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('English'));
    await settle(tester);
    // Same route, same scroll position, different language.
    expect(find.text('Appearance'), findsWidgets);
    expect(find.byType(ClassicSelect<AppLanguage>), findsOneWidget);
    expect(tester.takeException(), isNull);
    await clean(tester);
    await env.dispose();
  });
}
