import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/services/sync/auto_sync_service.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';

import 'helpers/test_env.dart';

class _Remote extends ScriptedSyncProvider {
  _Remote(this.target);
  final String target;
  bool offline = false;
  @override
  String get id => target;
  @override
  Future<SyncPayload?> download() async {
    if (offline) throw const SyncException('offline', retryable: true);
    return super.download();
  }
}

class _Coordinator extends SyncCoordinator {
  _Coordinator(TestEnv e, this.remote)
    : super(
        db: e.db,
        backup: e.backup,
        study: e.study,
        settings: e.settings,
        credentials: InMemoryCredentialStore(),
        clock: e.clock,
      );
  SyncProvider remote;
  @override
  SyncProvider? providerFromConfig(Map<String, Object?>? config) =>
      config == null ? null : remote;
}

class _SpyCoordinator extends _Coordinator {
  _SpyCoordinator(super.e, super.remote);
  final triggers = <String>[];
  @override
  Future<SyncReport?> autoSync({String trigger = 'start'}) async {
    triggers.add(trigger);
    return SyncReport(ok: true, message: 'ok', at: clock.now());
  }

  @override
  Future<Duration?> autoRetryDelay({String trigger = 'change'}) async => null;
}

void main() {
  Future<void> enable(TestEnv e) => e.settings.setSyncConfig({
    'provider': 'test',
    'autoOnStart': true,
    'autoOnResume': true,
    'autoOnChange': true,
    'autoAfterSession': true,
  });

  test('AUTO persists target cooldown across coordinator recreation and skips unchanged edits', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha']);
    await enable(e);
    final p = _Remote('a'), first = _Coordinator(e, _Remote('unused'));
    first.remote = p;
    await first.sync(p);
    await e.words.ensureWord(text: 'beta', now: e.clock.now());
    final reads = p.downloadCalls;
    expect(await _Coordinator(e, p).autoSync(trigger: 'change'), isNull);
    expect(p.downloadCalls, reads);
    e.clock.advance(const Duration(minutes: 1));
    expect((await _Coordinator(e, p).autoSync(trigger: 'change'))!.ok, isTrue);
    e.clock.advance(const Duration(minutes: 2));
    final after = p.downloadCalls;
    expect(await _Coordinator(e, p).autoSync(trigger: 'change'), isNull);
    expect(
      p.downloadCalls,
      after,
      reason: 'hash check must precede network for edit-triggered sync',
    );
    expect(
      (await _Coordinator(e, p).autoSync(trigger: 'resume'))!.ok,
      isTrue,
      reason: 'resume may fetch new remote data without local edits',
    );
  });

  test(
    'AUTO failure backoff survives restart, grows, and manual retry clears it',
    () async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha']);
      await enable(e);
      final p = _Remote('a');
      await _Coordinator(e, p).sync(p);
      await e.words.ensureWord(text: 'beta', now: e.clock.now());
      e.clock.advance(const Duration(minutes: 2));
      p.offline = true;
      expect(
        (await _Coordinator(e, p).autoSync(trigger: 'change'))!.ok,
        isFalse,
      );
      e.clock.advance(const Duration(minutes: 4));
      expect(await _Coordinator(e, p).autoSync(trigger: 'change'), isNull);
      e.clock.advance(const Duration(minutes: 1));
      expect(
        (await _Coordinator(e, p).autoSync(trigger: 'change'))!.ok,
        isFalse,
      );
      final state = jsonDecode(
        (await e.db.readMeta('sync_auto:${SyncCoordinator.targetKey(p)}'))!,
      ) as Map;
      expect(state['failures'], 2);
      expect(
        state['next'],
        e.clock.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      );
      p.offline = false;
      expect((await _Coordinator(e, p).sync(p)).ok, isTrue);
      final reset = jsonDecode(
        (await e.db.readMeta('sync_auto:${SyncCoordinator.targetKey(p)}'))!,
      ) as Map;
      expect(reset['failures'], 0);
    },
  );

  test('AUTO separate targets require manual confirmation and preparation is mutually exclusive', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha']);
    await enable(e);
    final a = _Remote('a'), b = _Remote('b');
    final c = _Coordinator(e, a);
    expect(await c.autoSync(), isNull);
    expect(a.downloadCalls, 0);
    await c.sync(a);
    c.remote = b;
    expect(await c.autoSync(), isNull);
    expect(b.downloadCalls, 0);
    await c.sync(b);
    await e.words.ensureWord(text: 'beta', now: e.clock.now());
    e.clock.advance(const Duration(minutes: 2));
    final before = b.uploadCalls;
    final reports = await Future.wait([
      c.autoSync(trigger: 'change'),
      c.autoSync(trigger: 'change'),
    ]);
    expect(reports.where((r) => r != null), hasLength(1));
    expect(b.uploadCalls, before + 1);
  });

  testWidgets(
    'AUTO repeated data edits debounce and background suspends the timer',
    (tester) async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      final c = _SpyCoordinator(e, _Remote('a'));
      final service = AutoSyncService(db: e.db, coordinator: c);
      addTearDown(service.dispose);
      service.start();
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await e.words.ensureWord(text: 'word$i', now: e.clock.now());
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        expect(c.triggers, isEmpty);
      }
      await tester.pump(const Duration(seconds: 14));
      expect(c.triggers, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(c.triggers, ['change']);
      await e.words.ensureWord(text: 'background', now: e.clock.now());
      await tester.pump();
      service.setForeground(false);
      await tester.pump(const Duration(seconds: 30));
      expect(c.triggers, ['change']);
      service.setForeground(true);
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      expect(c.triggers, ['change', 'change']);
      service.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('AUTO session end is a separate optional trigger', (
    tester,
  ) async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    final c = _SpyCoordinator(e, _Remote('a'));
    final service = AutoSyncService(db: e.db, coordinator: c);
    addTearDown(service.dispose);
    service.requestSessionEnd();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(c.triggers.first, 'session-end');
    service.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
