import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// The single localisation entry point used by every widget.
///
/// ```dart
/// final AppLocalizations l10n = context.l10n;
/// Text(l10n.navToday)
/// ```
///
/// Widgets must never branch on the language code, and must never hard-code a
/// translated string: the ARB resources in `lib/l10n` are the only source of
/// user-visible text.
extension AppLocalizationsContext on BuildContext {
  /// The current language's resources.
  ///
  /// Falls back to Simplified Chinese only when there is no [Localizations]
  /// scope at all — a widget pumped on its own (a preview, a narrow widget test)
  /// rather than inside the app. Every real screen runs under `MaterialApp`
  /// with [AppLocalizations.localizationsDelegates], so the fallback is never
  /// reached in production and a missing delegate can never crash a page.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('zh'));
}

/// Languages the app ships with, in the order the picker shows them.
///
/// The [code] is the persisted identifier and is independent of the display
/// name, so a language can be renamed without touching stored settings.
enum AppLanguage {
  /// Follow the operating system, falling back to English when the system
  /// language is not translated.
  system('system'),

  zh('zh'),
  en('en');

  const AppLanguage(this.code);

  final String code;

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.system;
    final String normalized = code.trim().toLowerCase();
    for (final AppLanguage value in AppLanguage.values) {
      if (value.code == normalized) return value;
    }
    // A backup written on another device, or a build that shipped another
    // language, must not break start-up: unknown values fall back to the system.
    return AppLanguage.system;
  }

  /// `null` means "let Flutter resolve the platform locale" (see
  /// [resolveLocale]).
  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.zh => const Locale('zh'),
    AppLanguage.en => const Locale('en'),
  };

  /// The name of the language in its own script, which stays recognisable even
  /// when the app is currently displaying the other language.
  String label(AppLocalizations l10n) => switch (this) {
    AppLanguage.system => l10n.appLanguageSystem,
    AppLanguage.zh => l10n.appLanguageChinese,
    AppLanguage.en => l10n.appLanguageEnglish,
  };
}
