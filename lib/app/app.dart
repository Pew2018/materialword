import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/models/enums.dart';
import '../l10n/l10n.dart';
import 'navigation.dart';
import 'providers.dart';
import 'theme.dart';

/// Root widget.
///
/// Both themes are rebuilt from the stored accent colour, so changing it takes
/// effect immediately without restarting the app or recreating any widget
/// state (the learning session keeps running while the colours change).
class MaterialWordApp extends ConsumerWidget {
  const MaterialWordApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StudySettingsRow? settings = ref.watch(settingsProvider).value;
    final ThemePreference preference = ThemePreference.fromCode(
      settings?.themeMode,
    );
    final Color accent = parseAccent(settings?.accentColor);
    // Device-local: a sync never changes the language of another device, and a
    // language switch never touches the learning data.
    final AppLanguage language = ref.watch(languageProvider);

    return MaterialApp(
      title: 'MaterialWord',
      scrollBehavior: const ClassicScrollBehavior(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(Brightness.light, accent),
      darkTheme: AppTheme.of(Brightness.dark, accent),
      themeMode: switch (preference) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      // `null` follows the platform locale; Flutter resolves it against
      // [AppLocalizations.supportedLocales], so an untranslated system language
      // falls back to English and Traditional Chinese resolves to Simplified.
      locale: language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const AppShell(),
    );
  }
}

/// Keep native platform physics and scrollbars; omit decorative edge effects.
///
/// On macOS Flutter's default desktop physics is a bouncing simulation: the
/// page keeps travelling after the fingers (or wheel) stop, which reads as
/// heavy damping in a mostly-static list UI. [ClampingScrollPhysics] on top of
/// [RangeMaintainingScrollPhysics] follows the gesture directly, stops when the
/// input stops, and still keeps the scroll offset valid when content grows or
/// shrinks. Android and iOS keep their own platform behaviour untouched.
class ClassicScrollBehavior extends MaterialScrollBehavior {
  const ClassicScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (getPlatform(context) == TargetPlatform.macOS) {
      return const ClampingScrollPhysics(
        parent: RangeMaintainingScrollPhysics(),
      );
    }
    return super.getScrollPhysics(context);
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
