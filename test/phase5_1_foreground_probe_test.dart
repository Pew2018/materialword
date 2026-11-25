import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/word_intake_service.dart';

import 'helpers/test_env.dart';

/// Phase 5.1 — AUTO-R01…R05.
///
/// The regression these guard: the periodic foreground check asked for the
/// config key `autoOnForeground`, which no code path ever wrote, so on a real
/// user configuration the remote was never polled and a second device's edits
/// only arrived when the user pressed "立即同步". A deleted remote file was also
/// reported as "no change" and stayed invisible forever.
class _ScriptedCoordinator extends SyncCoordinator {
  _ScriptedCoordinator(TestEnv env, this.remote)
    : super(
        db: env.db,
        backup: env.backup,
        study: env.study,
        settings: env.settings,
        credentials: InMemoryCredentialStore(),
        clock: env.clock,
      );

  final SyncProvider remote;

  /// The config saved by the settings repository says `provider: scripted`; only
  /// the transport is replaced, so the code path under test is the production
  /// one.
  @override
  SyncProvider? providerFromConfig(Map<String, Object?>? config) =>
      config == null ? null : remote;
}

class _CountingRemote extends ScriptedSyncProvider {
  int probeCalls = 0;

  @override
  Future<RemoteProbe> probeRemote() async {
    probeCalls++;
    return super.probeRemote();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv a;
  late TestEnv b;
  late _CountingRemote remote;

  setUp(() async {
    a = await TestEnv.create(now: DateTime(2026, 11, 24, 9));
    b = await TestEnv.create(now: DateTime(2026, 11, 24, 10));
    remote = _CountingRemote();
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  /// Saves the automatic-sync switches exactly like the settings page does:
  /// `setSyncConfig` for the connection, then `updateSyncAutoOption` per switch.
  Future<void> enableAuto(TestEnv env, List<String> options) async {
    await env.settings.setSyncConfig(<String, Object?>{'provider': 'scripted'});
    for (final String option in options) {
      final Map<String, Object?> saved = (await env.settings.syncConfig())!;
      final bool applied = await env.settings.updateSyncAutoOption(
        option,
        true,
        expected: saved,
      );
      expect(applied, isTrue, reason: '$option 必须能通过真实保存路径写入');
    }
  }

  Future<void> addWord(TestEnv env, String text) async {
    await env.intake.add(
      WordIntakeRequest(
        text: text,
        user: const WordContent(translation: '释义'),
      ),
      now: env.clock.now(),
    );
  }

  test('AUTO-R01 通过真实设置保存后，重建的协调器仍启用前台探测', () async {
    await addWord(a, 'alpha');
    await enableAuto(a, <String>['autoOnChange']);
    final Map<String, Object?> saved = (await a.settings.syncConfig())!;
    expect(saved['autoOnChange'], isTrue);
    expect(
      saved.containsKey('autoOnForeground'),
      isFalse,
      reason: '前台探测不再是用户配置项，不能留下只有测试能开启的幽灵键',
    );
    expect(
      SyncCoordinator.foregroundProbeEnabled(saved),
      isTrue,
      reason: '任一自动同步开关开启即启用前台探测',
    );

    final SyncCoordinator coordinator = _ScriptedCoordinator(a, remote);
    await coordinator.sync(remote, skipConnectionTest: true);
    // The per-target cooldown is one minute; a check inside it is skipped by
    // design, so step past it before asserting that the probe really ran.
    a.clock.advance(const Duration(minutes: 2));
    final int probesBefore = remote.probeCalls;
    // Nothing moved: the probe runs, finds the same revision, does no sync.
    expect(await coordinator.autoSync(trigger: 'foreground'), isNull);
    expect(remote.probeCalls, probesBefore + 1, reason: '探测必须真的发生');
  });

  test('AUTO-R01b 全部自动同步关闭时不做任何网络探测', () async {
    await addWord(a, 'alpha');
    await a.settings.setSyncConfig(<String, Object?>{'provider': 'scripted'});
    final SyncCoordinator coordinator = _ScriptedCoordinator(a, remote);
    await coordinator.sync(remote, skipConnectionTest: true);
    a.clock.advance(const Duration(minutes: 2));
    final int probesBefore = remote.probeCalls;
    expect(await coordinator.autoSync(trigger: 'foreground'), isNull);
    expect(remote.probeCalls, probesBefore);
  });

  test('AUTO-R01c 旧的幽灵配置键会被设置仓库拒绝', () async {
    await a.settings.setSyncConfig(<String, Object?>{'provider': 'scripted'});
    final Map<String, Object?> saved = (await a.settings.syncConfig())!;
    expect(
      () => a.settings.updateSyncAutoOption(
        'autoOnForeground',
        true,
        expected: saved,
      ),
      throwsArgumentError,
    );
  });

  test('AUTO-R02 本机无修改时前台探测取回另一台设备的修改', () async {
    await addWord(a, 'alpha');
    await enableAuto(b, <String>['autoOnResume']);
    await b.coordinator.sync(remote, skipConnectionTest: true);
    await a.coordinator.sync(remote, skipConnectionTest: true);
    await b.coordinator.sync(remote, skipConnectionTest: true);
    expect(await b.coordinator.hasLocalChanges(target: remote), isFalse);

    a.clock.advance(const Duration(minutes: 5));
    await addWord(a, 'beta');
    await a.coordinator.sync(remote, skipConnectionTest: true);

    b.clock.advance(const Duration(minutes: 2));
    final SyncCoordinator restarted = _ScriptedCoordinator(b, remote);
    final SyncReport? report = await restarted.autoSync(trigger: 'foreground');
    expect(report, isNotNull, reason: '前台探测必须真的检查远端');
    expect(report!.ok, isTrue);
    expect((await b.words.byNormalized('beta'))!.translation, '释义');
  });

  test('AUTO-R03 远端被删除时前台探测报告远端缺失，不能静默当作无变化', () async {
    await addWord(a, 'alpha');
    await enableAuto(a, <String>['autoOnChange']);
    final SyncCoordinator coordinator = _ScriptedCoordinator(a, remote);
    await coordinator.sync(remote, skipConnectionTest: true);

    a.clock.advance(const Duration(minutes: 2));
    remote.deleteRemoteDocument();
    final int uploadsBefore = remote.uploadCalls;
    final SyncReport? report = await coordinator.autoSync(
      trigger: 'foreground',
    );
    expect(report, isNotNull);
    expect(report!.ok, isFalse);
    expect(report.stage, SyncStage.remoteMissing);
    expect(remote.uploadCalls, uploadsBefore, reason: '不能自动重新上传整个数据库');
  });

  test('AUTO-R04 远端缺失后自动同步不会自行重建', () async {
    await addWord(a, 'alpha');
    await enableAuto(a, <String>['autoOnStart']);
    final SyncCoordinator coordinator = _ScriptedCoordinator(a, remote);
    await coordinator.sync(remote, skipConnectionTest: true);
    a.clock.advance(const Duration(minutes: 2));
    remote.deleteRemoteDocument();
    final int uploadsBefore = remote.uploadCalls;

    for (var round = 0; round < 3; round++) {
      a.clock.advance(const Duration(minutes: 6));
      final SyncReport? report = await coordinator.autoSync(
        trigger: 'foreground',
      );
      expect(report?.ok, anyOf(isNull, isFalse));
      expect(remote.uploadCalls, uploadsBefore);
    }
    expect(
      await a.settings.lastSyncResult(),
      anyOf(isNull, contains('远程数据文件已被删除')),
    );
  });

  test('AUTO-R05 用户主动“重新创建远端”后恢复正常同步', () async {
    await addWord(a, 'alpha');
    await enableAuto(a, <String>['autoOnChange']);
    final SyncCoordinator coordinator = _ScriptedCoordinator(a, remote);
    await coordinator.sync(remote, skipConnectionTest: true);
    final int uploadsAfterFirstSync = remote.uploadCalls;
    a.clock.advance(const Duration(minutes: 2));
    remote.deleteRemoteDocument();
    final SyncReport? missing = await coordinator.autoSync(
      trigger: 'foreground',
    );
    expect(missing!.stage, SyncStage.remoteMissing);
    expect(remote.uploadCalls, uploadsAfterFirstSync);

    final SyncReport recreated = await coordinator.sync(
      remote,
      skipConnectionTest: true,
      allowRemoteRecreate: true,
    );
    expect(recreated.ok, isTrue);
    expect(recreated.uploaded, isTrue);
    expect(remote.uploadCalls, uploadsAfterFirstSync + 1);

    // The probe is healthy again: nothing moved, so the next check is a no-op.
    a.clock.advance(const Duration(minutes: 2));
    final int probesBefore = remote.probeCalls;
    expect(await coordinator.autoSync(trigger: 'foreground'), isNull);
    expect(remote.probeCalls, probesBefore + 1);
  });
}
