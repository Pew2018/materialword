import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

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
  static const double appBarTitleSize = 20;
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

/// A classic Material Design 2 accent colour.
class AccentPalette {
  const AccentPalette({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;

  String get hex => hexOf(color);
}

/// 12 classic Material 2 palettes. Kept as plain hex strings so the selection
/// persists as a single text column and a custom colour needs no migration.
const List<AccentPalette> accentPalettes = <AccentPalette>[
  AccentPalette(id: 'blue', label: '经典蓝', color: Color(0xFF1565C0)),
  AccentPalette(id: 'indigo', label: '靛蓝', color: Color(0xFF303F9F)),
  AccentPalette(id: 'teal', label: '蓝绿', color: Color(0xFF00796B)),
  AccentPalette(id: 'green', label: '绿色', color: Color(0xFF2E7D32)),
  AccentPalette(id: 'lightGreen', label: '浅绿', color: Color(0xFF558B2F)),
  AccentPalette(id: 'amber', label: '琥珀', color: Color(0xFFB26A00)),
  AccentPalette(id: 'orange', label: '橙色', color: Color(0xFFEF6C00)),
  AccentPalette(id: 'deepOrange', label: '深橙', color: Color(0xFFD84315)),
  AccentPalette(id: 'red', label: '红色', color: Color(0xFFC62828)),
  AccentPalette(id: 'pink', label: '粉色', color: Color(0xFFAD1457)),
  AccentPalette(id: 'purple', label: '紫色', color: Color(0xFF6A1B9A)),
  AccentPalette(id: 'blueGrey', label: '蓝灰', color: Color(0xFF455A64)),
  AccentPalette(id: 'brown', label: '棕色', color: Color(0xFF5D4037)),
  AccentPalette(id: 'grey', label: '中性灰', color: Color(0xFF424242)),
];

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
  for (final AccentPalette palette in accentPalettes) {
    if (palette.id.toLowerCase() == value.toLowerCase()) return palette.color;
  }
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

  static ThemeData light({Color? accent, TargetPlatform? platform}) => _build(
    Brightness.light,
    accent ?? AppColors.defaultAccent,
    platform ?? defaultTargetPlatform,
  );

  static ThemeData dark({Color? accent, TargetPlatform? platform}) => _build(
    Brightness.dark,
    accent ?? AppColors.defaultAccent,
    platform ?? defaultTargetPlatform,
  );

  static ThemeData of(
    Brightness brightness,
    Color accent, {
    TargetPlatform? platform,
  }) => _build(brightness, accent, platform ?? defaultTargetPlatform);

  /// The foreground colour that keeps text readable on [background].
  static Color onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;

  static ThemeData _build(
    Brightness brightness,
    Color accent,
    TargetPlatform platform,
  ) {
    final bool isDark = brightness == Brightness.dark;

    // Dark theme needs a slightly lighter accent to stay legible on #121212.
    final Color primary = isDark ? _lighten(accent, 0.22) : accent;
    final Color onPrimary = onColor(primary);
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

    // Typography.material2014 is the classic Material Design text scale
    // (Roboto 14/16/20/24...). It is what gives the app its "Android 7" feel.
    final Typography typography = Typography.material2014(platform: platform);
    final TextTheme base = isDark ? typography.white : typography.black;

    final TextTheme textTheme = base
        .copyWith(
          headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w400,
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
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 16),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 14),
          bodySmall: base.bodySmall?.copyWith(fontSize: 12),
        )
        .apply(bodyColor: textPrimary, displayColor: textPrimary);

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
      // Secondary pages slide in horizontally with a short travel and a subtle
      // fade — never "up from the bottom", which reads like a modal. Android
      // additionally follows the system predictive-back gesture (the builder
      // falls back to the same horizontal fade when the gesture is not used).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
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
      visualDensity: VisualDensity.standard,
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
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelTextStyle: TextStyle(color: textSecondary, fontSize: 12),
      ),
    );

    return base2.copyWith(
      appBarTheme: AppBarTheme(
        toolbarHeight: AppDimens.appBarHeight,
        elevation: 1,
        centerTitle: false,
        backgroundColor: isDark
            ? Color.alphaBlend(primary.withValues(alpha: 0.16), surface)
            : primary,
        foregroundColor: isDark ? textPrimary : onPrimary,
        titleTextStyle: TextStyle(
          fontSize: AppDimens.appBarTitleSize,
          fontWeight: FontWeight.w500,
          color: isDark ? textPrimary : onPrimary,
        ),
        iconTheme: IconThemeData(
          size: AppDimens.iconSize,
          color: isDark ? textPrimary : onPrimary,
        ),
        actionsIconTheme: IconThemeData(
          size: AppDimens.iconSize,
          color: isDark ? textPrimary : onPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        color: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppDimens.cardRadius)),
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        minVerticalPadding: 8,
        selectedColor: primary,
        selectedTileColor: primary.withValues(alpha: 0.06),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppDimens.cardRadius)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 3,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          minimumSize: const Size(88, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
          ),
          side: BorderSide(color: divider),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 6,
        shape: const CircleBorder(),
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
        labelColor: isDark ? primary : onPrimary,
        unselectedLabelColor: isDark
            ? textSecondary
            : onPrimary.withValues(alpha: 0.7),
        indicatorColor: isDark ? primary : onPrimary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
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
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.darkSurface
            : const Color(0xFF323232),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
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
          borderRadius: BorderRadius.circular(AppDimens.chipRadius),
        ),
      ),
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
