import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/services/screen_awake.dart';

import 'helpers/test_env.dart';

/// Phase 4E-01: the keep-awake flag is acquired only for a real session, and is
/// always released again. No platform call is asserted beyond the injected
/// setter: a mock success is not evidence of a real device keeping its screen
/// on, and this file does not claim otherwise.
void main() {
  late TestEnv env;
  late List<bool> calls;

  setUp(() async {
    env = await TestEnv.create();
    calls = <bool>[];
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await env.dispose();
  });

  ScreenAwakeService service() =>
      ScreenAwakeService(setter: (bool value) async => calls.add(value));

  test('the preference is device-local and defaults to off', () async {
    expect(await env.db.readMeta(ScreenAwakeService.preferenceKey), isNull);
    // Stored in app_meta, never in study_settings: it must not be synced with
    // the learning plan.
    expect(ScreenAwakeService.preferenceKey, 'keep_screen_on');
    await env.db.writeMeta(ScreenAwakeService.preferenceKey, '1');
    expect(await env.db.readMeta(ScreenAwakeService.preferenceKey), '1');
  });

  test('enable applies the flag and disable releases it', () async {
    final ScreenAwakeService screen = service();
    expect(await screen.enable(), isTrue);
    expect(calls, <bool>[true]);
    expect(screen.isApplied, isTrue);

    await screen.disable();
    expect(calls, <bool>[true, false]);
    expect(screen.isApplied, isFalse);
  });

  test('disabling without enabling is harmless', () async {
    final ScreenAwakeService screen = service();
    await screen.disable();
    expect(calls, <bool>[false]);
    expect(screen.isApplied, isFalse);
  });

  test('refresh only re-applies a request that is still active', () async {
    final ScreenAwakeService screen = service();
    await screen.refresh();
    expect(calls, isEmpty, reason: 'nothing was requested yet');

    await screen.enable();
    calls.clear();
    await screen.refresh();
    expect(calls, <bool>[true], reason: 'backgrounding drops the OS flag');

    await screen.disable();
    calls.clear();
    await screen.refresh();
    expect(calls, isEmpty, reason: 'leaving the page must not re-acquire it');
  });

  test('a platform without support degrades instead of failing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final ScreenAwakeService screen = service();
    expect(screen.isSupported, isFalse);
    expect(await screen.enable(), isFalse);
    expect(calls, isEmpty);
    expect(screen.lastError, contains('不支持'));
    // Releasing is still safe and stays silent.
    await screen.disable();
    expect(calls, isEmpty);
  });

  test('a throwing platform call is reported, not thrown', () async {
    final ScreenAwakeService screen = ScreenAwakeService(
      setter: (bool value) async => throw StateError('no window'),
    );
    expect(await screen.enable(), isFalse);
    expect(screen.isApplied, isFalse);
    expect(screen.lastError, isNotNull);
    // A later disable must not rethrow either.
    await screen.disable();
  });

  test('the flag is never left on by a failed enable', () async {
    int attempts = 0;
    final ScreenAwakeService screen = ScreenAwakeService(
      setter: (bool value) async {
        attempts++;
        if (value) throw StateError('denied');
      },
    );
    await screen.enable();
    await screen.enable();
    expect(attempts, 2);
    expect(screen.isApplied, isFalse);
    await screen.disable();
    expect(screen.isApplied, isFalse);
  });
}
