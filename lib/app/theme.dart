import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Central design tokens. Every colour, size and radius used by the app lives
/// here so that screens never hard-code raw values.
class AppColors {
  const AppColors._();

  // Primary / accent (Material Design 2 style: strong primary, warm accent).
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color accent = Color(0xFFFF6D00);

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
  // red = unknown. Chinese stock-market red/green semantics do not apply here.
  static const Color known = Color(0xFF2E7D32);
  static const Color hazy = Color(0xFFEF6C00);
  static const Color unknown = Color(0xFFC62828);
}

class AppDimens {
  const AppDimens._();

  static const double appBarHeight = 56;
  static const double appBarTitleSize = 20;
  static const double listItemHeight = 56;
  static const double twoLineItemHeight = 72;
  static const double iconSize = 24;
  static const double iconSizeSmall = 20;
  static const double radius = 4;
  static const double gutter = 16;
  static const double compactGutter = 12;
  static const double minTouchTarget = 48;

  /// Below this width we treat the window as a phone.
  static const double desktopBreakpoint = 900;
  static const double navRailWidth = 220;
  static const double contentMaxWidth = 880;
}

/// Builds the two Material Design 2 themes (light / dark) plus the classic
/// typography and ripple setup.
class AppTheme {
  const AppTheme._();

  static ThemeData light({TargetPlatform? platform}) =>
      _build(Brightness.light, platform ?? defaultTargetPlatform);

  static ThemeData dark({TargetPlatform? platform}) =>
      _build(Brightness.dark, platform ?? defaultTargetPlatform);

  static ThemeData _build(Brightness brightness, TargetPlatform platform) {
    final bool isDark = brightness == Brightness.dark;

    final MaterialColor swatch = _swatch(
      AppColors.primary,
      AppColors.primaryDark,
      AppColors.primaryLight,
    );
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

    final ThemeData base2 = ThemeData(
      useMaterial3: false,
      brightness: brightness,
      primarySwatch: swatch,
      primaryColor: AppColors.primary,
      // Material 2 accent colour lives in the (legacy) colour scheme.
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: swatch,
        accentColor: AppColors.accent,
        brightness: brightness,
        backgroundColor: background,
        cardColor: surface,
      ),
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      dividerColor: divider,
      splashFactory: InkSplash.splashFactory,
      typography: Typography.material2014(platform: platform),
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base2.copyWith(
      appBarTheme: AppBarTheme(
        toolbarHeight: AppDimens.appBarHeight,
        elevation: 4,
        centerTitle: false,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: isDark ? textPrimary : Colors.white,
        titleTextStyle: TextStyle(
          fontSize: AppDimens.appBarTitleSize,
          fontWeight: FontWeight.w500,
          color: isDark ? textPrimary : Colors.white,
        ),
        iconTheme: IconThemeData(
          size: AppDimens.iconSize,
          color: isDark ? textPrimary : Colors.white,
        ),
        actionsIconTheme: IconThemeData(
          size: AppDimens.iconSize,
          color: isDark ? textPrimary : Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: EdgeInsets.zero,
        color: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppDimens.radius)),
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? textSecondary : AppColors.textSecondaryLight,
        textColor: textPrimary,
        minVerticalPadding: 12,
      ),
      iconTheme: IconThemeData(
        color: isDark ? textPrimary : AppColors.textPrimaryLight,
        size: AppDimens.iconSize,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: isDark ? AppColors.primaryLight : AppColors.primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radius),
          ),
          side: BorderSide(color: divider),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        foregroundColor: isDark ? AppColors.textPrimaryLight : Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius * 2),
        ),
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
        labelColor: isDark ? AppColors.primaryLight : Colors.white,
        unselectedLabelColor: isDark ? textSecondary : Colors.white70,
        indicatorColor: isDark ? AppColors.primaryLight : Colors.white,
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
          borderSide: BorderSide(
            color: isDark ? AppColors.primaryLight : AppColors.primary,
            width: 2,
          ),
        ),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.darkSurface
            : const Color(0xFF323232),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearMinHeight: 4,
        color: isDark ? AppColors.primaryLight : AppColors.primary,
      ),
      scrollbarTheme: ScrollbarThemeData(
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
    );
  }

  static MaterialColor _swatch(Color primary, Color dark, Color light) {
    return MaterialColor(primary.toARGB32(), <int, Color>{
      50: light.withValues(alpha: 0.15),
      100: light.withValues(alpha: 0.3),
      200: light.withValues(alpha: 0.5),
      300: light.withValues(alpha: 0.7),
      400: primary,
      500: primary,
      600: primary,
      700: dark,
      800: dark,
      900: dark,
    });
  }
}

/// Spacing helpers so paddings stay consistent across screens.
class AppSpacing {
  const AppSpacing._();

  static const SizedBox h4 = SizedBox(height: 4);
  static const SizedBox h8 = SizedBox(height: 8);
  static const SizedBox h12 = SizedBox(height: 12);
  static const SizedBox h16 = SizedBox(height: 16);
  static const SizedBox h24 = SizedBox(height: 24);
  static const SizedBox w4 = SizedBox(width: 4);
  static const SizedBox w8 = SizedBox(width: 8);
  static const SizedBox w12 = SizedBox(width: 12);
  static const SizedBox w16 = SizedBox(width: 16);
  static const SizedBox h32 = SizedBox(height: 32);
  static const SizedBox h48 = SizedBox(height: 48);
}
