import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen awake during a learning or practice session.
///
/// Design rules mirror the TTS wrapper — a platform that cannot honour the
/// request must degrade silently, never break the session:
///
///  * the preference is **device-local** (`app_meta`), because "my phone should
///    not dim while I study" is not a shared learning plan and must not travel
///    to another device through sync;
///  * the flag is only ever on while a session page is on screen and the app is
///    in the foreground: leaving the page, backgrounding the app or a crash of
///    the plugin all release it;
///  * a platform without support reports that honestly instead of pretending.
class ScreenAwakeService {
  ScreenAwakeService({Future<void> Function(bool)? setter}) : _setter = setter;

  /// Injected in tests; production uses the real plugin.
  final Future<void> Function(bool)? _setter;

  bool _requested = false;
  bool _applied = false;
  String? _lastError;

  /// Local-only preference key. Never part of the sync payload.
  static const String preferenceKey = 'keep_screen_on';

  String? get lastError => _lastError;
  bool get isApplied => _applied;

  /// Whether this build can keep the screen on at all.
  bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Asks the platform to keep the display on. Returns false when the request
  /// could not be honoured; the session keeps working either way.
  Future<bool> enable() async {
    _requested = true;
    if (!isSupported) {
      _lastError = '当前平台不支持屏幕常亮，已按普通模式继续';
      _applied = false;
      return false;
    }
    try {
      final Future<void> Function(bool)? setter = _setter;
      if (setter != null) {
        await setter(true);
      } else {
        await WakelockPlus.enable();
      }
      _applied = true;
      _lastError = null;
      return true;
    } on PlatformException catch (e) {
      _applied = false;
      _lastError = '无法开启屏幕常亮：${e.message ?? e.code}';
      return false;
    } catch (_) {
      _applied = false;
      _lastError = '无法开启屏幕常亮，已按普通模式继续';
      return false;
    }
  }

  /// Releases the flag. Safe to call when it was never acquired.
  Future<void> disable() async {
    _requested = false;
    if (!isSupported) {
      _applied = false;
      return;
    }
    try {
      final Future<void> Function(bool)? setter = _setter;
      if (setter != null) {
        await setter(false);
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // Releasing must never throw: it runs from dispose().
    }
    _applied = false;
  }

  /// Re-applies the request after a background/foreground cycle.
  ///
  /// The OS drops the flag when the app is backgrounded, so "still requested"
  /// is not the same as "still applied" — this is what makes returning to the
  /// page behave like the user expects.
  Future<void> refresh() async {
    if (_requested) await enable();
  }

  bool get isRequested => _requested;
}
