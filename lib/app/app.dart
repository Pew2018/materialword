import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/enums.dart';
import 'navigation.dart';
import 'providers.dart';
import 'theme.dart';

/// Root widget. Theme follows the stored preference (system / light / dark).
class MaterialWordApp extends ConsumerWidget {
  const MaterialWordApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? themeCode = ref.watch(settingsProvider).value?.themeMode;
    final ThemePreference preference = ThemePreference.fromCode(themeCode);

    return MaterialApp(
      title: 'MaterialWord',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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
