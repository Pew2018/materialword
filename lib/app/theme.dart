import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../core/models/enums.dart';

/// Static colours that are *not* part of the accent system: surfaces, text and
/// the three answer levels. Everything that should react to the user's accent
/// colour comes from `Theme.of(context).colorScheme` instead of these values.
class AppColors {
  const AppColors._();

  /// Classic blue — the default accent, kept identical to phase 1.
  static const Color defaultAccent = Color(0xFF1565C0);

  // Surfaces.
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);

  // Text.
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF6D6D6D);
  static const Color textPrimaryDark = Color(0xFFECEFF1);
  static const Color textSecondaryDark = Color(0xFFB0BEC5);

  // Lines.
  static const Color dividerLight = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF303030);

  // Answer levels. Deliberately conventional: green = known, amber = fuzzy,
  // red = unknown. Chinese stock-market red/green semantics do not apply here,
  // and these three never follow the theme accent: the meaning must stay
  // unmistakable in every theme.
  static const Color known = Color(0xFF2E7D32);
  static const Color hazy = Color(0xFFEF6C00);
  static const Color unknown = Color(0xFFC62828);

  /// Colour for an answer level, independent of the accent.
  static Color forAnswer(int code) => switch (code) {
    0 => unknown,
    1 => hazy,
    _ => known,
  };
}

class AppDimens {
  const AppDimens._();

  static const double appBarHeight = 56;
  static const double listItemHeight = 56;
  static const double twoLineItemHeight = 72;
  static const double iconSize = 24;
  static const double iconSizeSmall = 20;

  // Shape scale. Classic Material 1/2 is nearly square: buttons are 2dp,
  // surfaces (fields, menus, dialogs) 4dp, cards 2dp. Nothing above 4dp is a
  // button or a card in this app — a pill is never the right answer.
  static const double buttonRadius = 2;
  static const double radius = 4;
  static const double cardRadius = 2;
  static const double chipRadius = 2;

  static const double gutter = 16;
  static const double compactGutter = 12;
  static const double minTouchTarget = 48;
  static const double bottomNavHeight = 56;
  static const double fabSize = 56;
  static const double sectionHeaderHeight = 40;

  /// The single navigation breakpoint: at or above it the window gets the full
  /// side navigation (icon + label + brand), below it the phone bottom bar.
  ///
  /// There is deliberately no icon-only rail in between: a 76dp strip of
  /// unlabelled icons is neither a phone layout nor a desktop one, and it cost
  /// real content width in a narrow macOS window.
  static const double sideNavigationBreakpoint = 720;

  /// Above this width a list/detail two-column layout is comfortable.
  static const double twoPaneBreakpoint = 1040;

  static const double navRailWidth = 220;
  static const double contentMaxWidth = 880;

  /// Comfortable reading width for a pinned action bar on desktop.
  static const double actionBarMaxWidth = 720;
}

/// Motion tokens: three durations, one standard curve, so state changes feel
/// like one app instead of a dozen ad-hoc timings.
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration page = Duration(milliseconds: 240);
  static const Curve curve = Curves.easeInOut;
}

/// Which set an accent swatch belongs to.
///
/// Only used to group the picker. It is not persisted and never decides
/// behaviour.
enum AccentGroup { classic, material }

/// One accent colour preset.
///
/// [id] is a stable identifier (`classic.clearSkyBlue`, `material.blue`),
/// deliberately independent of the display name and of the position in the
/// list: presets can be reordered or renamed without touching a stored
/// preference, and the Chinese and English names live in the ARB resources.
///
/// The *colour* is what gets persisted (as `#RRGGBB`), so a user's choice keeps
/// working when the preset set changes — including a colour that is no longer
/// part of any preset.
class AccentPalette {
  const AccentPalette({
    required this.id,
    required this.color,
    required this.group,
  });

  final String id;
  final Color color;
  final AccentGroup group;

  String get hex => hexOf(color);
}

/// Classic accents (11), in the order of the reference design.
const List<AccentPalette> classicAccentPalettes = <AccentPalette>[
  AccentPalette(
    id: 'classic.clearSkyBlue',
    color: Color(0xFF00A8FC),
    group: AccentGroup.classic,
  ),
  AccentPalette(
    id: 'classic.deepSeaBlue',
    color: Color(0xFF0073D4),
    group: AccentGroup.classic,
  ),
  AccentPalette(
    id: 'classic.goldenOrange',
    color: Color(0xFFDA6945),
    group: AccentGroup.classic,
  ),
  AccentPalette(
    id: 'classic.lemonYellow',
    color: Color(0xFFF2A227),
    group: AccentGroup.classic,
  ),
  AccentPalette(
    id: 'classic.grassGreen',
    color: Color(0xFF65C400),
    group: AccentGroup.classic,
  ),
  AccentPalette(
    id: 'classic.jadeGreen',
    color: Color(0xFF009C8C),
    group: AccentGroup.classic,
  ),
  AccentPalette(
    id: 'classic.violet',
    color: Color(0xFF9B73D3),
    group: AccentGroup.classic,
  ),
  AccentPalette(
    id: 'classic.deepIndigo',
    color: Color(0xFF3F3DA8),
    group: AccentGroup.classic,
  ),
  AccentPalette(
    id: 'classic.skyBlue',
    color: Color(0xFF00CADD),
    group: AccentGroup.classic,
  ),
  AccentPalette(
    id: 'classic.vibrantPink',
    color: Color(0xFFFF5592),
    group: AccentGroup.classic,
  ),
  AccentPalette(
    id: 'classic.orchidPink',
    color: Color(0xFFC763CE),
    group: AccentGroup.classic,
  ),
];

/// Material Design accents (12), in the order of the reference design.
const List<AccentPalette> materialAccentPalettes = <AccentPalette>[
  AccentPalette(
    id: 'material.blue',
    color: Color(0xFF2196F3),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.teal',
    color: Color(0xFF009688),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.green',
    color: Color(0xFF4CAF50),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.red',
    color: Color(0xFFF44336),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.orange',
    color: Color(0xFFFF9800),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.purple',
    color: Color(0xFF9C27B0),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.cyan',
    color: Color(0xFF00BCD4),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.indigo',
    color: Color(0xFF3F51B5),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.pink',
    color: Color(0xFFE91E63),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.blueGray',
    color: Color(0xFF607D8B),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.deepOrange',
    color: Color(0xFFFF5722),
    group: AccentGroup.material,
  ),
  AccentPalette(
    id: 'material.lightGreen',
    color: Color(0xFF8BC34A),
    group: AccentGroup.material,
  ),
];

/// Every preset offered by the picker, grouped set first, in display order.
const List<AccentPalette> accentPalettes = <AccentPalette>[
  ...classicAccentPalettes,
  ...materialAccentPalettes,
];

/// Ids stored by builds up to 1.2.0. They are still accepted so an upgrading
/// user keeps the exact colour they picked, even where the id now means
/// something else (the old `blue` was #1565C0, not Material blue).
const Map<String, Color> _legacyAccentIds = <String, Color>{
  'blue': Color(0xFF1565C0),
  'indigo': Color(0xFF303F9F),
  'teal': Color(0xFF00796B),
  'green': Color(0xFF2E7D32),
  'lightGreen': Color(0xFF558B2F),
  'amber': Color(0xFFB26A00),
  'orange': Color(0xFFEF6C00),
  'deepOrange': Color(0xFFD84315),
  'red': Color(0xFFC62828),
  'pink': Color(0xFFAD1457),
  'purple': Color(0xFF6A1B9A),
  'blueGrey': Color(0xFF455A64),
  'brown': Color(0xFF5D4037),
  'grey': Color(0xFF424242),
};

/// `#RRGGBB` (upper case) for [color].
String hexOf(Color color) {
  final int argb = color.toARGB32() & 0xFFFFFF;
  return '#${argb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Parses `#RRGGBB`, `RRGGBB`, `#AARRGGBB` or a preset id. Always returns a
/// usable colour: an unreadable stored value falls back to the classic blue.
Color parseAccent(String? stored) {
  if (stored == null || stored.trim().isEmpty) return AppColors.defaultAccent;
  final String value = stored.trim();
  final String lower = value.toLowerCase();
  for (final AccentPalette palette in accentPalettes) {
    if (palette.id.toLowerCase() == lower) return palette.color;
  }
  final Color? legacy = _legacyAccentIds[lower];
  if (legacy != null) return legacy;
  final String hex = value.startsWith('#') ? value.substring(1) : value;
  if (hex.length == 6 || hex.length == 8) {
    final int? parsed = int.tryParse(hex, radix: 16);
    if (parsed != null) {
      return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
    }
  }
  return AppColors.defaultAccent;
}

/// Builds the two Material Design 2 themes plus the classic typography and
/// ripple setup. Every colour used by a widget comes from the resulting
/// [ThemeData], so switching the accent never requires a restart.
class AppTheme {
  const AppTheme._();

  static ThemeData light({
    Color? accent,
    TargetPlatform? platform,
    TypographyScale typography = TypographyScale.material2014,
  }) => _build(
    Brightness.light,
    accent ?? AppColors.defaultAccent,
    platform ?? defaultTargetPlatform,
    typography,
  );

  static ThemeData dark({
    Color? accent,
    TargetPlatform? platform,
    TypographyScale typography = TypographyScale.material2014,
  }) => _build(
    Brightness.dark,
    accent ?? AppColors.defaultAccent,
    platform ?? defaultTargetPlatform,
    typography,
  );

  static ThemeData of(
    Brightness brightness,
    Color accent, {
    TargetPlatform? platform,
    TypographyScale typography = TypographyScale.material2014,
  }) =>
      _build(brightness, accent, platform ?? defaultTargetPlatform, typography);

  /// The foreground colour that keeps text readable on [background].
  ///
  /// Picks whichever of white / near-black has the higher contrast ratio instead
  /// of Flutter's brightness heuristic. The heuristic splits colours at a fixed
  /// luminance, so mid-tone accents (violet, sky blue, pink) landed on white
  /// text at ~3:1 — below the 4.5:1 the app bar title and filled buttons need.
  /// With plain white or black the better of the two is always ≥ 4.5:1.
  static Color onColor(Color background) {
    final double withWhite = _contrastRatio(background, Colors.white);
    final double withBlack = _contrastRatio(background, Colors.black);
    return withWhite >= withBlack ? Colors.white : Colors.black87;
  }

  /// WCAG contrast ratio between two opaque colours.
  static double _contrastRatio(Color a, Color b) {
    final double la = a.computeLuminance();
    final double lb = b.computeLuminance();
    final double lighter = la > lb ? la : lb;
    final double darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Keep the classic white foreground by lowering the luminance of the
  /// surface painted directly under it, without modifying the accent itself.
  static Color whiteForegroundSurface(Color color) {
    const double minimumContrast = 4.5;
    if (_contrastRatio(color, Colors.white) >= minimumContrast) return color;
    double low = 0;
    double high = 1;
    for (int step = 0; step < 16; step++) {
      final double amount = (low + high) / 2;
      final Color candidate = Color.lerp(color, Colors.black, amount)!;
      if (_contrastRatio(candidate, Colors.white) >= minimumContrast) {
        high = amount;
      } else {
        low = amount;
      }
    }
    return Color.lerp(color, Colors.black, high)!;
  }

  /// The single style behind every **solid** accent button.
  ///
  /// `ElevatedButton` and `FilledButton` both point here, so the pair can never
  /// drift apart again: same background, always-white ink and icon, the same
  /// disabled pair and the 16dp horizontal padding. Only [elevation] differs,
  /// because an elevated button is meant to lift off the surface while a
  /// filled one sits on it. Material 2014 keeps the 2dp corner and the 88×40
  /// minimum; Material 2018 passes the Material 2 4dp corner and 64×36 minimum.
  ///
  /// The overlay is white-tinted: the global splash colour follows the accent,
  /// which is invisible on top of an accent-coloured fill.
  static ButtonStyle solidButtonStyle({
    required Color background,
    double elevation = 0,
    Size minimumSize = const Size(88, 40),
    double radius = AppDimens.buttonRadius,
  }) {
    final Color disabledBackground = Color.lerp(
      background,
      Colors.black,
      0.25,
    )!;
    return ButtonStyle(
      elevation: WidgetStateProperty.resolveWith<double?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.disabled) ? 0 : elevation,
      ),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.disabled)
            ? disabledBackground
            : background,
      ),
      // Never `onColor(background)`: the accent fill is normalised by
      // [whiteForegroundSurface] so white is always the readable choice here.
      foregroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
      iconColor: const WidgetStatePropertyAll<Color>(Colors.white),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.20);
        }
        if (states.contains(WidgetState.focused)) {
          return Colors.white.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withValues(alpha: 0.10);
        }
        return null;
      }),
      minimumSize: WidgetStatePropertyAll<Size>(minimumSize),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }

  static ThemeData _build(
    Brightness brightness,
    Color accent,
    TargetPlatform platform,
    TypographyScale typographyScale,
  ) {
    final bool isDark = brightness == Brightness.dark;

    // Dark theme needs a slightly lighter accent to stay legible on #121212.
    final Color primary = isDark ? _lighten(accent, 0.22) : accent;
    final Color onPrimary = onColor(primary);
    final Color filledAccent = whiteForegroundSurface(primary);
    final MaterialColor swatch = _swatch(accent);

    final Color background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color surface = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final Color textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final Color textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final Color divider = isDark
        ? AppColors.dividerDark
        : AppColors.dividerLight;

    // Material 2014 keeps the classic sizes this app already ships.
    // Material 2018 is Flutter's scale as-is: no size, weight or spacing
    // overrides. The study word's 38 / w500 / 0.2 / 1.15 lives on the 2014
    // headline role, so the page does not write its own font metrics.
    final bool material2018 = typographyScale == TypographyScale.material2018;
    final Typography typography = material2018
        ? Typography.material2018(platform: platform)
        : Typography.material2014(platform: platform);
    final TextTheme base = isDark ? typography.white : typography.black;
    final TextTheme sized = material2018
        ? base
        : base.copyWith(
            headlineMedium: base.headlineMedium?.copyWith(
              fontSize: 38,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
              height: 1.15,
            ),
            headlineSmall: base.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w400,
            ),
            titleLarge: base.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
            titleMedium: base.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            bodyLarge: base.bodyLarge?.copyWith(fontSize: 17),
            bodyMedium: base.bodyMedium?.copyWith(fontSize: 14),
            bodySmall: base.bodySmall?.copyWith(fontSize: 12),
            labelLarge: base.labelLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          );

    final TextTheme textTheme = sized.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final ColorScheme scheme =
        ColorScheme.fromSwatch(
          primarySwatch: swatch,
          accentColor: _secondaryOf(accent, isDark),
          brightness: brightness,
          backgroundColor: background,
          cardColor: surface,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          secondary: _secondaryOf(accent, isDark),
          onSecondary: onColor(_secondaryOf(accent, isDark)),
          surface: surface,
          onSurface: textPrimary,
          error: AppColors.unknown,
          onError: Colors.white,
          outline: divider,
        );

    final ThemeData base2 = ThemeData(
      useMaterial3: false,
      // Secondary pages slide in horizontally — never "up from the bottom",
      // which reads like a modal. Android uses the same Cupertino slide as
      // iOS/macOS so the first frame already paints the final app-bar and
      // scaffold colours (PredictiveBack's fade-forwards fallback used to
      // flash a transparent bar). System predictive-back stays enabled in the
      // manifest; only the page-transition builder changes.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      brightness: brightness,
      primarySwatch: swatch,
      primaryColor: primary,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      dividerColor: divider,
      disabledColor: isDark ? const Color(0xFF616161) : const Color(0xFF9E9E9E),
      // InkSplash keeps the classic Material 1/2 "expanding circle" feedback.
      splashFactory: InkRipple.splashFactory,
      typography: typography,
      textTheme: textTheme,
      visualDensity: material2018
          ? VisualDensity.adaptivePlatformDensity
          : VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[
        AppTypeScale(classic: !material2018),
      ],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashColor: primary.withValues(alpha: isDark ? 0.18 : 0.14),
      highlightColor: primary.withValues(alpha: isDark ? 0.10 : 0.08),
      hoverColor: primary.withValues(alpha: isDark ? 0.08 : 0.05),
      focusColor: primary.withValues(alpha: isDark ? 0.16 : 0.12),
      iconTheme: IconThemeData(
        color: isDark ? textPrimary : AppColors.textPrimaryLight,
        size: AppDimens.iconSize,
      ),
      // The side navigation needs a predictable surface.
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: material2018 ? null : FontWeight.w500,
        ),
        unselectedLabelTextStyle: TextStyle(color: textSecondary),
      ),
    );

    final ThemeData themed = base2.copyWith(
      appBarTheme: AppBarTheme(
        toolbarHeight: AppDimens.appBarHeight,
        elevation: material2018 ? 4 : 1,
        centerTitle: false,
        backgroundColor: isDark
            ? Color.alphaBlend(primary.withValues(alpha: 0.16), surface)
            : filledAccent,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.white),
        iconTheme: IconThemeData(size: AppDimens.iconSize, color: Colors.white),
        actionsIconTheme: IconThemeData(
          size: AppDimens.iconSize,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(material2018 ? 4 : AppDimens.cardRadius),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        minVerticalPadding: 8,
        selectedColor: primary,
        selectedTileColor: primary.withValues(alpha: 0.06),
        shape: material2018
            ? null
            : const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppDimens.cardRadius),
                ),
              ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: material2018 ? 8 : 3,
        selectedLabelStyle: TextStyle(
          fontWeight: material2018 ? null : FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(),
      ),
      // One definition for both filled button classes. `FilledButton` used to
      // fall back to the Material defaults (a 20dp pill with an automatically
      // chosen, sometimes black, foreground), which is how the backup dialogs
      // ended up with green pills and black text. Elevation is the only
      // deliberate difference: an elevated button lifts off the surface, a
      // filled one sits on it.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: material2018
            ? solidButtonStyle(
                background: filledAccent,
                elevation: 2,
                minimumSize: const Size(64, 36),
                radius: 4,
              )
            : solidButtonStyle(background: filledAccent, elevation: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: material2018
            ? solidButtonStyle(
                background: filledAccent,
                minimumSize: const Size(64, 36),
                radius: 4,
              )
            : solidButtonStyle(background: filledAccent),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: material2018 ? const Size(64, 36) : const Size(88, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              material2018 ? 4 : AppDimens.buttonRadius,
            ),
          ),
          side: BorderSide(color: divider),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: material2018 ? const Size(64, 36) : const Size(64, 40),
          padding: EdgeInsets.symmetric(horizontal: material2018 ? 16 : 12),
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              material2018 ? 4 : AppDimens.buttonRadius,
            ),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: filledAccent,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        sizeConstraints: material2018
            ? const BoxConstraints.tightFor(width: 56, height: 56)
            : null,
      ),
      dialogTheme: DialogThemeData(
        elevation: 24,
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white,
        indicatorColor: Colors.white,
        labelStyle: TextStyle(
          fontWeight: material2018 ? null : FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: material2018 ? null : true,
        filled: false,
        contentPadding: material2018
            ? null
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: material2018 ? 6 : null,
        backgroundColor: isDark
            ? AppColors.darkSurface
            : const Color(0xFF323232),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: isDark ? primary : const Color(0xFF80D8FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearMinHeight: 4,
        color: primary,
        linearTrackColor: divider,
        circularTrackColor: divider,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: divider,
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.12),
        valueIndicatorColor: primary,
        // No tick marks: a dense row of dots was pure visual noise.
        tickMarkShape: SliderTickMarkShape.noTickMark,
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.5)
              : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? primary : null,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? primary : null,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          isDark ? const Color(0xFF4F4F4F) : const Color(0xFFBDBDBD),
        ),
        thickness: WidgetStateProperty.all(8),
        radius: const Radius.circular(4),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 500),
      ),
      chipTheme: base2.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.12),
        side: BorderSide(color: divider),
        labelStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            material2018 ? 16 : AppDimens.chipRadius,
          ),
        ),
      ),
    );
    return withLocalizedComponentStyles(themed);
  }

  /// Copies text roles onto component themes.
  ///
  /// [ThemeData.localize] rewrites [ThemeData.textTheme] only. Buttons, the
  /// app bar, bars, tabs, fields and snack bars keep the styles captured
  /// here, so call this again with the localized theme. Material 2018 then
  /// follows that script's 2018 sizes; 2014 keeps the pinned ones.
  static ThemeData withLocalizedComponentStyles(ThemeData theme) {
    final TextTheme text = theme.textTheme;
    final TextStyle? labelLarge = text.labelLarge;
    final TextStyle? bodyMedium = text.bodyMedium;
    final TextStyle? bodySmall = text.bodySmall;

    ButtonStyle? labeled(ButtonStyle? style) {
      if (style == null || labelLarge == null) return style;
      return style.copyWith(
        textStyle: WidgetStatePropertyAll<TextStyle?>(labelLarge),
      );
    }

    // A null weight keeps the role. Material 2014 sets w500 on the selected
    // bar, rail and tab; Material 2018 leaves the weight unset so the role's
    // own weight and letter spacing stay.
    TextStyle? roleOn(TextStyle? role, TextStyle? painted, {Color? color}) {
      if (role == null) return null;
      return role.copyWith(
        color: color ?? painted?.color,
        fontWeight: painted?.fontWeight,
      );
    }

    final TextStyle? railSelected =
        theme.navigationRailTheme.selectedLabelTextStyle;
    final TextStyle? railUnselected =
        theme.navigationRailTheme.unselectedLabelTextStyle;

    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: text.titleLarge?.copyWith(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: labeled(theme.elevatedButtonTheme.style),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: labeled(theme.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: labeled(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: labeled(theme.textButtonTheme.style),
      ),
      navigationRailTheme: theme.navigationRailTheme.copyWith(
        selectedLabelTextStyle: roleOn(bodySmall, railSelected),
        unselectedLabelTextStyle: roleOn(bodySmall, railUnselected),
      ),
      bottomNavigationBarTheme: theme.bottomNavigationBarTheme.copyWith(
        selectedLabelStyle: roleOn(
          bodySmall,
          theme.bottomNavigationBarTheme.selectedLabelStyle,
        ),
        unselectedLabelStyle: roleOn(
          bodySmall,
          theme.bottomNavigationBarTheme.unselectedLabelStyle,
        ),
      ),
      tabBarTheme: theme.tabBarTheme.copyWith(
        labelStyle: roleOn(labelLarge, theme.tabBarTheme.labelStyle),
        unselectedLabelStyle: roleOn(
          labelLarge,
          theme.tabBarTheme.unselectedLabelStyle,
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        hintStyle: bodyMedium?.copyWith(
          color: theme.inputDecorationTheme.hintStyle?.color,
        ),
        labelStyle: bodyMedium?.copyWith(
          color: theme.inputDecorationTheme.labelStyle?.color,
        ),
      ),
      snackBarTheme: theme.snackBarTheme.copyWith(
        contentTextStyle: bodyMedium?.copyWith(
          color: theme.snackBarTheme.contentTextStyle?.color ?? Colors.white,
        ),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      popupMenuTheme: theme.popupMenuTheme.copyWith(textStyle: text.bodyMedium),
      chipTheme: theme.chipTheme.copyWith(labelStyle: text.bodySmall),
    );
  }

  /// A MaterialColor built from one accent by tinting towards white (50–300)
  /// and shading towards black (700–900).
  static MaterialColor _swatch(Color accent) {
    return MaterialColor(accent.toARGB32(), <int, Color>{
      50: _mix(accent, Colors.white, 0.90),
      100: _mix(accent, Colors.white, 0.75),
      200: _mix(accent, Colors.white, 0.55),
      300: _mix(accent, Colors.white, 0.35),
      400: _mix(accent, Colors.white, 0.15),
      500: accent,
      600: _mix(accent, Colors.black, 0.08),
      700: _mix(accent, Colors.black, 0.20),
      800: _mix(accent, Colors.black, 0.32),
      900: _mix(accent, Colors.black, 0.44),
    });
  }

  static Color _mix(Color base, Color other, double amount) =>
      Color.alphaBlend(other.withValues(alpha: amount), base);

  static Color _lighten(Color base, double amount) =>
      _mix(base, Colors.white, amount);

  /// Interactive secondary controls share the user's chosen hue.
  static Color _secondaryOf(Color accent, bool isDark) =>
      isDark ? _lighten(accent, 0.22) : accent;
}

/// Which type scale [AppTheme] built. Widgets use it to keep Material 2014
/// weights, spacing and line heights off the Material 2018 roles.
class AppTypeScale extends ThemeExtension<AppTypeScale> {
  const AppTypeScale({required this.classic});

  final bool classic;

  @override
  AppTypeScale copyWith({bool? classic}) =>
      AppTypeScale(classic: classic ?? this.classic);

  @override
  AppTypeScale lerp(ThemeExtension<AppTypeScale>? other, double t) {
    if (other is! AppTypeScale) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppTypeScaleTheme on ThemeData {
  bool get isClassicType => extension<AppTypeScale>()?.classic ?? true;

  /// Colour and [fontStyle] always apply. Weight, spacing and line height
  /// apply only on Material 2014.
  TextStyle? classicStyle(
    TextStyle? role, {
    FontWeight? weight,
    double? letterSpacing,
    double? height,
    Color? color,
    FontStyle? fontStyle,
  }) {
    if (role == null) return null;
    final TextStyle painted = role.copyWith(color: color, fontStyle: fontStyle);
    if (!isClassicType) return painted;
    return painted.copyWith(
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  BorderRadius get buttonRadius => _controlRadius(
    elevatedButtonTheme.style?.shape?.resolve(<WidgetState>{}),
  );

  /// Single-line button height. Material 2014 is 40; Material 2018 is 36.
  double get buttonMinHeight =>
      elevatedButtonTheme.style?.minimumSize
          ?.resolve(<WidgetState>{})
          ?.height ??
      40;

  /// Elevation of a solid button. Answer buttons keep the 2014 value of 1.
  double get solidButtonElevation =>
      elevatedButtonTheme.style?.elevation?.resolve(<WidgetState>{}) ?? 2;

  BorderRadius get cardRadius => _controlRadius(cardTheme.shape);

  BorderRadius get chipRadius => _controlRadius(chipTheme.shape);

  /// Dialogs, fields, menus and banners share this corner.
  BorderRadius get surfaceRadius => _controlRadius(dialogTheme.shape);
}

BorderRadius _controlRadius(ShapeBorder? shape) {
  if (shape is RoundedRectangleBorder && shape.borderRadius is BorderRadius) {
    return shape.borderRadius as BorderRadius;
  }
  return BorderRadius.zero;
}

/// Spacing helpers so paddings stay consistent across screens.
class AppSpacing {
  const AppSpacing._();

  static const SizedBox h4 = SizedBox(height: 4);
  static const SizedBox h8 = SizedBox(height: 8);
  static const SizedBox h12 = SizedBox(height: 12);
  static const SizedBox h16 = SizedBox(height: 16);
  static const SizedBox h24 = SizedBox(height: 24);
  static const SizedBox h32 = SizedBox(height: 32);
  static const SizedBox h48 = SizedBox(height: 48);
  static const SizedBox w4 = SizedBox(width: 4);
  static const SizedBox w8 = SizedBox(width: 8);
  static const SizedBox w12 = SizedBox(width: 12);
  static const SizedBox w16 = SizedBox(width: 16);
}
