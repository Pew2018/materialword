import '../services/tts_service.dart';
import 'l10n.dart';

/// Display name of a system voice: "US · Samantha".
///
/// The service reports the raw `locale` and `name`; the readable variant name is
/// a translation, so it is built here instead of inside the service.
String ttsVoiceLabel(AppLocalizations l10n, TtsVoice voice) {
  final String variant = switch (voice.locale.toLowerCase()) {
    'en-us' => l10n.voiceVariantUS,
    'en-gb' => l10n.voiceVariantUK,
    'en-au' => l10n.voiceVariantAU,
    'en-ca' => l10n.voiceVariantCA,
    'en-ie' => l10n.voiceVariantIE,
    'en-in' => l10n.voiceVariantIN,
    _ => voice.locale,
  };
  return '$variant · ${voice.name}';
}
