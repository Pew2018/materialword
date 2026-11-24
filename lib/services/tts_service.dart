import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// One system voice as reported by the platform.
class TtsVoice {
  const TtsVoice({required this.name, required this.locale, this.label});

  final String name;
  final String locale;
  final String? label;

  String get display => label ?? '$locale · $name';
}

/// Thin, defensive wrapper around the platform TTS engine.
///
/// Design rules:
///  * every platform call is guarded — a missing engine, a missing voice or a
///    denied audio session must never break the learning loop;
///  * voices are never assumed to work offline, and English availability is
///    reported honestly instead of being faked;
///  * the instance is created lazily and initialised once.
class TtsService {
  TtsService({FlutterTts? engine}) : _engine = engine;

  FlutterTts? _engine;
  bool _initialised = false;
  bool _failed = false;
  String? _lastError;
  List<TtsVoice>? _voicesCache;

  bool get isSupported => !_failed;
  String? get lastError => _lastError;

  Future<FlutterTts?> _ensure() async {
    if (_failed) return null;
    final FlutterTts? existing = _engine;
    if (_initialised && existing != null) return existing;
    try {
      final FlutterTts engine = existing ?? FlutterTts();
      await engine.setSharedInstance(true);
      await engine.awaitSpeakCompletion(true);
      _engine = engine;
      _initialised = true;
      return engine;
    } catch (e) {
      _failed = true;
      _lastError = '系统语音不可用：$e';
      return null;
    }
  }

  /// English voices the platform actually exposes. Empty when the engine has no
  /// English voice installed — the UI then falls back to a plain "不可用" hint.
  Future<List<TtsVoice>> englishVoices() async {
    final List<TtsVoice>? cached = _voicesCache;
    if (cached != null) return cached;
    final FlutterTts? engine = await _ensure();
    if (engine == null) return const <TtsVoice>[];
    try {
      final Object? raw = await engine.getVoices;
      if (raw is! List) return const <TtsVoice>[];
      final List<TtsVoice> voices = <TtsVoice>[];
      for (final Object? item in raw) {
        if (item is! Map) continue;
        final String? name = item['name'] as String?;
        final String? locale = item['locale'] as String?;
        if (name == null || locale == null) continue;
        if (!locale.toLowerCase().startsWith('en')) continue;
        voices.add(
          TtsVoice(
            name: name,
            locale: locale,
            label: _prettyVoiceLabel(name, locale),
          ),
        );
      }
      voices.sort((TtsVoice a, TtsVoice b) => a.locale.compareTo(b.locale));
      _voicesCache = voices;
      return voices;
    } catch (e) {
      _lastError = '读取语音列表失败：$e';
      return const <TtsVoice>[];
    }
  }

  String _prettyVoiceLabel(String name, String locale) {
    final String variant = switch (locale.toLowerCase()) {
      'en-us' => '美式',
      'en-gb' => '英式',
      'en-au' => '澳洲',
      'en-ca' => '加拿大',
      'en-ie' => '爱尔兰',
      'en-in' => '印度',
      _ => locale,
    };
    return '$variant · $name';
  }

  /// Speaks [text]. Returns false (and keeps [lastError]) when TTS is missing.
  Future<bool> speak(
    String text, {
    String? voiceName,
    String? locale,
    int rate = 50,
  }) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final FlutterTts? engine = await _ensure();
    if (engine == null) return false;
    try {
      await engine.stop();
      await engine.setLanguage(locale ?? 'en-US');
      // flutter_tts expects 0.0–1.0 where 0.5 is "normal".
      await engine.setSpeechRate((rate.clamp(0, 100)) / 100.0);
      await engine.setVolume(1.0);
      await engine.setPitch(1.0);
      if (voiceName != null && voiceName.isNotEmpty) {
        await engine.setVoice(<String, String>{
          'name': voiceName,
          'locale': locale ?? 'en-US',
        });
      }
      final Object? result = await engine.speak(trimmed);
      final bool ok = result == 1 || result == true || result == null;
      if (!ok) _lastError = '系统未能开始朗读';
      return ok;
    } catch (e) {
      _lastError = '朗读失败：$e';
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _engine?.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }
}
