import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// One system voice as reported by the platform.
class TtsVoice {
  const TtsVoice({required this.name, required this.locale, this.label});

  final String name;
  final String locale;
  final String? label;

  String get display => label ?? '$locale · $name';
  String get key => jsonEncode([name, locale]);
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
  Future<FlutterTts?>? _initializing;
  int _generation = 0;
  int _voiceGeneration = 0;
  bool _speaking = false;

  bool get isSupported => !_failed;
  String? get lastError => _lastError;
  bool get isSpeaking => _speaking;

  Future<FlutterTts?> _ensure() async {
    if (_failed) return null;
    final FlutterTts? existing = _engine;
    if (_initialised && existing != null) return existing;
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<FlutterTts?> _initialize() async {
    try {
      final FlutterTts engine = _engine ?? FlutterTts();
      _engine = engine;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await engine.setSharedInstance(true);
      }
      await engine.awaitSpeakCompletion(true);
      engine.setStartHandler(() => _speaking = true);
      engine.setCompletionHandler(() => _speaking = false);
      engine.setCancelHandler(() => _speaking = false);
      engine.setErrorHandler((message) {
        _speaking = false;
        _lastError = '系统朗读失败，请检查语音设置后重试';
      });
      _engine = engine;
      _initialised = true;
      return engine;
    } catch (e) {
      _failed = true;
      _lastError = '系统语音不可用，请安装英语语音后刷新';
      return null;
    }
  }

  /// English voices the platform actually exposes. Empty when the engine has no
  /// English voice installed — the UI then falls back to a plain "不可用" hint.
  Future<List<TtsVoice>> englishVoices({bool refresh = false}) async {
    if (refresh) {
      _voiceGeneration++;
      await stop();
      await _initializing;
      _failed = false;
      _initialised = false;
      _voicesCache = null;
      _lastError = null;
    }
    final List<TtsVoice>? cached = _voicesCache;
    if (cached != null) return cached;
    final FlutterTts? engine = await _ensure();
    if (engine == null) return const <TtsVoice>[];
    final lookup = _voiceGeneration;
    try {
      final Object? raw = await engine.getVoices;
      if (lookup != _voiceGeneration) return await englishVoices();
      if (raw is! List) return const <TtsVoice>[];
      final List<TtsVoice> voices = <TtsVoice>[];
      for (final Object? item in raw) {
        if (item is! Map) continue;
        final String? name = item['name'] as String?;
        final String? locale = (item['locale'] as String?)?.replaceAll(
          '_',
          '-',
        );
        if (name == null || locale == null) continue;
        if (!RegExp(r'^en(?:-|$)', caseSensitive: false).hasMatch(locale)) {
          continue;
        }
        if (voices.any((v) => v.name == name && v.locale == locale)) continue;
        voices.add(
          TtsVoice(
            name: name,
            locale: locale,
            label: _prettyVoiceLabel(name, locale),
          ),
        );
      }
      voices.sort((a, b) => a.key.compareTo(b.key));
      _voicesCache = voices;
      _lastError = voices.isEmpty ? '系统没有可用英语语音，请在系统设置安装后刷新' : null;
      return voices;
    } catch (e) {
      _lastError = '读取语音列表失败，请刷新后重试';
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
    final request = ++_generation;
    _lastError = null;
    final FlutterTts? engine = await _ensure();
    if (request != _generation) return true;
    if (engine == null) return false;
    try {
      final voices = await englishVoices();
      if (request != _generation) return true;
      if (voices.isEmpty) return false;
      final preferred = (locale ?? 'en-US').replaceAll('_', '-');
      final selected = voiceName != null && voiceName.isNotEmpty
          ? voices
                .where(
                  (v) =>
                      v.name == voiceName &&
                      v.locale.toLowerCase() == preferred.toLowerCase(),
                )
                .firstOrNull
          : voices
                    .where(
                      (v) => v.locale.toLowerCase() == preferred.toLowerCase(),
                    )
                    .firstOrNull ??
                voices.first;
      if (selected == null) {
        _lastError = '所选语音已不可用，请刷新并重新选择';
        return false;
      }
      await engine.stop();
      if (request != _generation) return true;
      final language = await engine.setLanguage(selected.locale);
      if (request != _generation) return true;
      if (language == 0 || (language is int && language < 0)) {
        _lastError = '系统无法使用该英语语音，请检查语音包';
        return false;
      }
      // flutter_tts expects 0.0–1.0 where 0.5 is "normal".
      await engine.setSpeechRate((rate.clamp(0, 100)) / 100.0);
      if (request != _generation) return true;
      await engine.setVolume(1.0);
      if (request != _generation) return true;
      await engine.setPitch(1.0);
      if (request != _generation) return true;
      final voiceResult = await engine.setVoice(<String, String>{
        'name': selected.name,
        'locale': selected.locale,
      });
      if (request != _generation) return true;
      if (voiceResult == 0 || (voiceResult is int && voiceResult < 0)) {
        _lastError = '系统无法切换该语音，请刷新后重试';
        return false;
      }
      final Object? result = await engine.speak(trimmed);
      if (request != _generation) {
        return true; // Intentional stop is not an error.
      }
      final bool ok = result == 1 || result == true;
      if (!ok) _lastError = '系统未能开始朗读';
      return ok;
    } catch (e) {
      if (request != _generation) return true;
      _lastError = '朗读失败，请刷新语音并重试';
      return false;
    }
  }

  Future<void> stop() async {
    _generation++;
    _speaking = false;
    try {
      await _engine?.stop();
    } catch (e) {
      _lastError = '停止朗读失败，请检查系统语音';
    }
  }
}
