import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:materialword/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late List<Map<String, String>> voices;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    voices = [
      {'name': 'System English', 'locale': 'en-US'},
    ];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getVoices') return voices;
      return 1;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('TTS Android discovery normalizes and deduplicates voices and skips iOS setup', () async {
    voices = [
      {'name': 'same', 'locale': 'en_US'},
      {'name': 'same', 'locale': 'en-US'},
      {'name': 'same', 'locale': 'en-GB'},
      {'name': '中文', 'locale': 'zh-CN'},
    ];
    final tts = TtsService();
    final result = await tts.englishVoices();
    expect(result, hasLength(2));
    expect(result.map((v) => v.key).toSet(), hasLength(2));
    expect(calls.where((c) => c.method == 'setSharedInstance'), isEmpty);
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android.intent.action.TTS_SERVICE'),
    );
    await tts.englishVoices();
    expect(calls.where((c) => c.method == 'getVoices'), hasLength(1));
  });

  test(
    'TTS iOS concurrent initialization configures shared instance once',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final tts = TtsService();
      await Future.wait([tts.englishVoices(), tts.englishVoices()]);
      expect(calls.where((c) => c.method == 'setSharedInstance'), hasLength(1));
      expect(
        calls.where((c) => c.method == 'awaitSpeakCompletion'),
        hasLength(1),
      );
    },
  );

  test('TTS unavailable engine and installed voices recover after explicit refresh', () async {
    bool installed = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (!installed) throw MissingPluginException('not ready');
      if (call.method == 'getVoices') return voices;
      return 1;
    });
    final tts = TtsService();
    expect(await tts.englishVoices(), isEmpty);
    expect(tts.isSupported, isFalse);
    installed = true;
    expect(await tts.englishVoices(refresh: true), hasLength(1));
    expect(tts.isSupported, isTrue);
    expect(await tts.speak('hello'), isTrue);
  });

  test('TTS no English voices never pretends to speak and refresh finds installed voice', () async {
    voices = [];
    final tts = TtsService();
    expect(await tts.speak('hello'), isFalse);
    expect(tts.lastError, contains('英语语音'));
    expect(calls.where((c) => c.method == 'speak'), isEmpty);
    voices = [
      {'name': 'US', 'locale': 'en-US'},
    ];
    expect(await tts.englishVoices(refresh: true), hasLength(1));
    expect(await tts.speak('hello', voiceName: 'US', rate: 200), isTrue);
    expect(calls.lastWhere((c) => c.method == 'setSpeechRate').arguments, 1.0);
    expect(tts.lastError, isNull);
  });

  test(
    'TTS rejected language or removed selected voice reports failure',
    () async {
      final tts = TtsService();
      expect(await tts.speak('hello', voiceName: 'gone'), isFalse);
      expect(tts.lastError, contains('所选语音'));
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'setLanguage') return -1;
        return 1;
      });
      expect(await tts.speak('hello'), isFalse);
      expect(tts.lastError, contains('语音包'));
    },
  );

  test(
    'TTS stop during asynchronous configuration prevents stale speech',
    () async {
      final entered = Completer<void>(), language = Completer<int>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getVoices') return voices;
        if (call.method == 'setLanguage') {
          entered.complete();
          return language.future;
        }
        return 1;
      });
      final tts = TtsService();
      final speaking = tts.speak('stale');
      await entered.future;
      await tts.stop();
      language.complete(1);
      expect(
        await speaking,
        isTrue,
        reason: 'intentional cancellation is not an error',
      );
      expect(calls.where((c) => c.method == 'speak'), isEmpty);
      expect(tts.isSpeaking, isFalse);
    },
  );

  test('TTS next request supersedes pending configuration without speaking old word', () async {
    final entered = Completer<void>(), language = Completer<int>();
    int languages = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getVoices') return voices;
      if (call.method == 'setLanguage' && ++languages == 1) {
        entered.complete();
        return language.future;
      }
      return 1;
    });
    final tts = TtsService();
    final old = tts.speak('old');
    await entered.future;
    expect(await tts.speak('new'), isTrue);
    language.complete(1);
    await old;
    final spoken = calls.where((c) => c.method == 'speak').toList();
    expect(spoken, hasLength(1));
    expect(spoken.single.arguments, 'new');
  });

  test('TTS native start/completion/cancel handlers track playback state', () async {
    final engine = FlutterTts();
    // Supply a real plugin object while invoking its documented callback hooks.
    final service = TtsService(engine: engine);
    await service.englishVoices();
    engine.startHandler!();
    expect(service.isSpeaking, isTrue);
    engine.completionHandler!();
    expect(service.isSpeaking, isFalse);
    engine.startHandler!();
    engine.cancelHandler!();
    expect(service.isSpeaking, isFalse);
    engine.errorHandler!('native error');
    expect(service.lastError, contains('系统朗读失败'));
    await service.stop();
  });
}
