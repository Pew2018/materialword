import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/models/enums.dart';
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
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}

/// Keep native platform physics and scrollbars; omit decorative edge effects.
class ClassicScrollBehavior extends MaterialScrollBehavior {
  const ClassicScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
