import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/models/enums.dart';
import '../l10n/l10n.dart';
import 'appearance_store.dart';
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
    _persistAppearance(ref);

    final StudySettingsRow? settings = ref.watch(settingsProvider).value;
    final AppearanceSnapshot snapshot = ref
        .watch(appearanceStoreProvider)
        .current;
    // Device-local: a sync never changes the language of another device, and a
    // language switch never touches the learning data.
    final AppLanguage language = ref.watch(languageProvider);

    // The settings row is the only source of truth once it exists. Until then
    // a trusted snapshot paints the last theme; an untrusted one (upgraded
    // install, no file yet) stays a blank surface so the default blue is never
    // drawn and then replaced.
    final bool showShell = settings != null || snapshot.trusted;
    final ThemePreference preference = settings != null
        ? ThemePreference.fromCode(settings.themeMode)
        : snapshot.theme;
    final Color accent = settings != null
        ? parseAccent(settings.accentColor)
        : parseAccent(snapshot.accentColor);
    final TypographyScale typography = settings != null
        ? TypographyScale.fromCode(settings.typographyScale)
        : snapshot.typography;

    return MaterialApp(
      // A new key when the shell appears drops the neutral theme instead of
      // animating from it. Later accent edits keep this key, so they still
      // update the existing [MaterialApp] immediately.
      key: ValueKey<String>(
        showShell ? 'appearance-ready' : 'appearance-pending',
      ),
      title: 'MaterialWord',
      scrollBehavior: const ClassicScrollBehavior(),
      debugShowCheckedModeBanner: false,
      theme: showShell
          ? AppTheme.of(Brightness.light, accent, typography: typography)
          : _neutralTheme(Brightness.light),
      darkTheme: showShell
          ? AppTheme.of(Brightness.dark, accent, typography: typography)
          : _neutralTheme(Brightness.dark),
      themeMode: switch (showShell ? preference : ThemePreference.system) {
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
      home: showShell ? const AppShell() : const _PendingAppearance(),
    );
  }
}

/// Writes the settings row into the local snapshot the first time it differs
/// from a trusted snapshot (including the upgraded-install case, where the
/// snapshot is not trusted yet). An equal trusted pair is left alone so the
/// file write cannot rebuild the theme.
void _persistAppearance(WidgetRef ref) {
  ref.listen<AsyncValue<StudySettingsRow>>(settingsProvider, (
    AsyncValue<StudySettingsRow>? _,
    AsyncValue<StudySettingsRow> next,
  ) {
    final StudySettingsRow? row = next.value;
    if (row == null) return;
    final AppearanceStore store = ref.read(appearanceStoreProvider);
    final ThemePreference theme = ThemePreference.fromCode(row.themeMode);
    final String accent = row.accentColor;
    final TypographyScale typography = TypographyScale.fromCode(
      row.typographyScale,
    );
    final AppearanceSnapshot snapshot = store.current;
    final bool same =
        snapshot.trusted &&
        snapshot.theme == theme &&
        snapshot.typography == typography &&
        parseAccent(snapshot.accentColor) == parseAccent(accent);
    if (same) return;
    unawaited(
      store.write(theme: theme, accentColor: accent, typography: typography),
    );
  });
}

/// Flat surface used before an untrusted appearance can be resolved.
///
/// No accent, no [AppTheme], no bar and no progress indicator: only the
/// platform brightness chooses the background.
ThemeData _neutralTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final Color background = dark
      ? AppColors.darkBackground
      : AppColors.lightBackground;
  return ThemeData(
    useMaterial3: false,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    canvasColor: background,
  );
}

class _PendingAppearance extends StatelessWidget {
  const _PendingAppearance();

  @override
  Widget build(BuildContext context) {
    final bool dark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Scaffold(
      backgroundColor: dark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
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
