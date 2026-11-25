import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/database/app_database.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/repositories/study_repository.dart';
import '../../core/time_utils.dart';
import '../backup_service.dart';
import '../diagnostics_service.dart';
import 'conflict_store.dart';
import 'credential_store.dart';
import 'github_sync_provider.dart';
import 'local_file_sync_provider.dart';
import 'sync_provider.dart';
import 'webdav_sync_provider.dart';

/// Progress callback so the sync page can show what is happening.
///
/// Every stage is a statement about *this device*: "merged" means the local
/// database already changed, even if the upload is still pending.
enum SyncStage {
  idle('准备'),
  validating('校验配置'),
  downloading('读取远程数据'),
  merging('合并到本地'),
  rebuilding('重建学习状态'),
  uploading('上传数据'),
  verifying('校验上传结果'),
  done('完成'),
  mergedNotUploaded('本机已合并，上传未完成'),
  waitingBackoff('等待退避'),
  authFailed('认证失败'),
  remoteMissing('远程数据缺失'),
  remoteCorrupt('远程数据不可用'),
  configChanged('配置已变化'),
  pausedAfterRestore('恢复后已暂停同步'),
  failed('失败');

  const SyncStage(this.label);

  final String label;
}

class SyncReport {
  const SyncReport({
    required this.ok,
    required this.message,
    required this.at,
    this.merge,
    this.uploaded = false,
    this.skipped = false,
    this.attempts = 1,
    this.notes = const <String>[],
    this.stage = SyncStage.done,
    this.localMerged = false,
    this.conflicts = 0,
  });

  final bool ok;
  final String message;
  final DateTime at;
  final MergeReport? merge;

  /// True when a new snapshot was written to the remote.
  final bool uploaded;

  /// True when nothing needed to be uploaded (data identical on both sides).
  final bool skipped;
  final int attempts;
  final List<String> notes;

  /// Final stage, so the UI never has to guess from [ok].
  final SyncStage stage;

  /// True when the local database was modified by this run (a merge happened).
  final bool localMerged;

  /// Conflicts recorded during the merge (also persisted locally).
  final int conflicts;
}

/// One coordinator for every transport.
///
/// Responsibilities:
///  * a single mutex — two syncs can never run at the same time;
///  * validate → download → validate data → merge (in one transaction) →
///    rebuild states → build snapshot → conditional upload → verify → persist
///    state → refresh UI (the caller invalidates providers);
///  * conflict handling by re-downloading and merging, with a bounded number of
///    attempts — never by force-overwriting the remote;
///  * content hashing, so an unchanged dataset is not re-uploaded;
///  * a PendingRebuild marker, so an interrupted run can be repaired.
class SyncCoordinator {
  SyncCoordinator({
    required this.db,
    required this.backup,
    required this.study,
    required this.settings,
    required this.credentials,
    this.clock = const SystemClock(),
  });

  final AppDatabase db;
  final BackupService backup;
  final StudyRepository study;
  final SettingsRepository settings;
  final CredentialStore credentials;
  final Clock clock;

  static const String lastLocalHashKey = 'last_sync_local_hash';
  static const String lastRemoteRevisionKey = 'last_sync_remote_revision';
  static const int maxAttempts = 3;

  /// Debounce for automatic sync (start-up / resume): at most one attempt per
  /// minute, and repeated failures back off for five minutes.
  static const Duration autoSyncMinInterval = Duration(minutes: 1);
  static const Duration autoSyncFailureBackoff = Duration(minutes: 5);

  bool _running = false;
  String? _activeTarget;
  String? _activeConfigRevision;
  bool _preparingAuto = false;

  bool get isRunning => _running;

  /// Builds the provider described by the stored configuration.
  SyncProvider? providerFromConfig(Map<String, Object?>? config) {
    if (config == null) return null;
    final String id = (config['provider'] as String?) ?? 'none';
    return switch (id) {
      'local-file' => LocalFileSyncProvider(
        filePath: (config['path'] as String?) ?? '',
      ),
      'github' => GitHubSyncProvider.fromConfig(
        config,
        credentials: credentials,
      ),
      'webdav' => WebDavSyncProvider.fromConfig(
        config,
        credentials: credentials,
      ),
      _ => null,
    };
  }

  /// Runs one full sync. Throws [SyncException] for expected failures so the UI
  /// can show a precise reason; unexpected errors are wrapped as well.
  ///
  /// [allowRemoteRecreate] is required to (re)create a remote that was deleted:
  /// a missing file after a successful sync is *not* permission to upload the
  /// whole database again.
  /// [resumeAfterRestore] bypasses the post-restore pause and must only be set
  /// from an explicit user action that says what happens to the remote.
  Future<SyncReport> sync(
    SyncProvider provider, {
    void Function(SyncStage stage, String detail)? onProgress,
    bool skipConnectionTest = false,
    bool allowRemoteRecreate = false,
    bool resumeAfterRestore = false,
  }) async {
    if (_running) {
      throw const SyncException('已有同步正在进行，请稍后再试');
    }
    if (!provider.isImplemented) {
      throw const SyncException('该同步方式尚未启用');
    }
    if (!resumeAfterRestore && await settings.syncPaused()) {
      onProgress?.call(SyncStage.pausedAfterRestore, '恢复后已暂停同步');
      throw SyncException(
        '同步已暂停：${await settings.syncPausedReason() ?? '恢复历史备份后需要先确认如何处理远端数据'}',
      );
    }
    _running = true;
    _activeTarget = targetKey(provider);
    final List<String> notes = <String>[];
    try {
      _activeConfigRevision = await db.readMeta(
        SettingsRepository.syncConfigRevisionKey,
      );
      if (provider is GitHubSyncProvider) await provider.captureCredentials();
      if (provider is WebDavSyncProvider) await provider.captureCredentials();
      onProgress?.call(SyncStage.validating, '检查配置');
      if (!skipConnectionTest || provider is WebDavSyncProvider) {
        final SyncTestResult test = await provider.testConnection();
        if (!test.ok) {
          throw SyncException('连接测试未通过：${test.message}');
        }
        notes.addAll(
          test.details.where(
            (String d) => !d.startsWith('NO_CONDITIONAL_WRITE'),
          ),
        );
        if (!test.supportsConditionalWrites) {
          if (provider is WebDavSyncProvider) {
            throw const SyncException('服务器未通过条件写入验证，请使用手动文件备份');
          }
          notes.add('该目标仅适合手动备份，不保证自动双向同步');
        }
      }

      MergeReport? merge;
      bool uploaded = false;
      int attempts = 0;
      int recordedConflicts = 0;

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        attempts = attempt + 1;
        try {
          onProgress?.call(SyncStage.downloading, '读取远程数据');
          final SyncPayload? remote = await provider.download();

          if (remote == null &&
              !allowRemoteRecreate &&
              await hasSyncedTarget(provider)) {
            onProgress?.call(SyncStage.remoteMissing, '远程数据文件不存在');
            throw const SyncRemoteMissingException();
          }
          if (provider is WebDavSyncProvider &&
              remote != null &&
              remote.revision == null) {
            throw const SyncException('WebDAV 未提供强 ETag，无法安全同步。请使用手动备份');
          }
          final Map<String, Object?> localBefore = await backup.buildDataset(
            now: clock.now(),
          );
          final String localHash = await BackupService.contentHashOfAsync(
            localBefore,
          );

          String? remoteHash;
          if (remote != null) {
            onProgress?.call(SyncStage.merging, '合并远程数据');
            try {
              await backup.validateDatasetAsync(remote.dataset);
            } on BackupException catch (e) {
              onProgress?.call(SyncStage.remoteCorrupt, '远程数据不可用');
              throw SyncDataException('远程数据不可用：${e.message}');
            }
            remoteHash = await BackupService.contentHashOfAsync(remote.dataset);
            if (remoteHash == localHash) {
              // Same content on both sides: nothing to merge, nothing to push.
              await _persistState(
                now: clock.now(),
                hash: localHash,
                revision: remote.revision,
                message: '本地与远程数据一致，无需上传',
              );
              return SyncReport(
                ok: true,
                message: '本地与远程数据一致，无需上传',
                at: clock.now(),
                skipped: true,
                attempts: attempts,
                notes: notes,
                stage: SyncStage.done,
              );
            }
            merge = await backup.mergeDataset(remote.dataset, now: clock.now());
            recordedConflicts += await _recordConflicts(merge);
          }

          onProgress?.call(SyncStage.rebuilding, '重建派生状态');
          await recoverPendingRebuild();

          final Map<String, Object?> merged = await backup.buildDataset(
            now: clock.now(),
          );
          final String mergedHash = await BackupService.contentHashOfAsync(
            merged,
          );

          if (remote != null &&
              remoteHash != null &&
              mergedHash == remoteHash) {
            // Merging added nothing new (e.g. the remote was a superset).
            await _persistState(
              now: clock.now(),
              hash: mergedHash,
              revision: remote.revision,
              message: '远程已包含全部本地数据，未上传',
            );
            return SyncReport(
              ok: true,
              message: '远程已包含全部本地数据，未上传',
              at: clock.now(),
              merge: merge,
              skipped: true,
              attempts: attempts,
              notes: notes,
              stage: SyncStage.done,
              localMerged: merge?.hasChanges ?? false,
              conflicts: recordedConflicts,
            );
          }

          onProgress?.call(SyncStage.uploading, '上传数据');
          final SyncUploadResult result = await provider.upload(
            merged,
            ifRevision: remote?.revision,
          );
          if (!result.ok) {
            throw SyncException('上传失败：${result.message}');
          }
          uploaded = true;

          onProgress?.call(SyncStage.verifying, '校验上传结果');
          await _verifyUpload(provider, mergedHash);

          await _persistState(
            now: clock.now(),
            hash: mergedHash,
            revision: result.revision ?? remote?.revision,
            message: '同步完成',
          );

          final String message = merge == null
              ? '已上传本地数据（${_formatCount(merged)}）'
              : '同步完成：${merge.summary}';
          return SyncReport(
            ok: true,
            message: message,
            at: clock.now(),
            merge: merge,
            uploaded: uploaded,
            attempts: attempts,
            notes: notes,
            stage: SyncStage.done,
            localMerged: merge?.hasChanges ?? false,
            conflicts: recordedConflicts,
          );
        } on SyncConflictException catch (e) {
          notes.add('第 $attempts 次上传冲突：${e.message}，正在重新拉取并合并');
          if (attempt == maxAttempts - 1) {
            if (merge?.hasChanges ?? false) {
              throw SyncPartialException(
                '本机已合并远程数据，但上传未能完成（多次并发冲突）。'
                '本机数据已保留，稍后重试即可：${e.message}',
                mergeSummary: merge?.summary ?? '',
                localChanged: true,
              );
            }
            rethrow;
          }
          continue;
        } on TimeoutException {
          if (merge?.hasChanges ?? false) {
            throw SyncPartialException(
              '本机已合并远程数据，但上传超时。本机数据已保留，稍后重试即可',
              mergeSummary: merge?.summary ?? '',
              localChanged: true,
            );
          }
          throw const SyncException('网络超时：请检查网络后重试', retryable: true);
        } on SyncException catch (e) {
          // A failure after a successful merge must never be reported as
          // "nothing was changed".
          if ((merge?.hasChanges ?? false) &&
              e is! SyncDataException &&
              e is! SyncRemoteMissingException) {
            throw SyncPartialException(
              '本机已合并远程数据，但未完成上传：${e.message}',
              mergeSummary: merge?.summary ?? '',
              localChanged: true,
            );
          }
          rethrow;
        }
      }
      throw const SyncException('同步未能完成：多次出现并发冲突，请稍后再试');
    } on SyncException catch (e) {
      DiagnosticsService.instance.log(
        'sync',
        'failed: ${e.message} (retryable: ${e.retryable})',
        error: true,
      );
      await _recordFailure(clock.now(), message: '同步失败：${e.message}');
      rethrow;
    } catch (e) {
      // The exception *type* only: the message may embed a URL with credentials.
      DiagnosticsService.instance.log(
        'sync',
        'failed with ${e.runtimeType}',
        error: true,
      );
      await _recordFailure(clock.now());
      throw SyncException('同步失败：$e');
    } finally {
      if (provider is WebDavSyncProvider) {
        provider.clearCapturedCredentials();
        provider.close();
      }
      if (provider is GitHubSyncProvider) {
        provider.clearCapturedCredentials();
        provider.close();
      }
      _running = false;
      _activeTarget = null;
      _activeConfigRevision = null;
    }
  }

  Future<int> _recordConflicts(MergeReport? merge) async {
    if (merge == null || merge.conflictDetails.isEmpty) return 0;
    try {
      return await SyncConflictStore(db)
          .record(merge.conflictDetails, now: clock.now());
    } catch (e) {
      // Recording is diagnostic only; it must never fail a sync.
      DiagnosticsService.instance.log(
        'sync',
        'conflict recording failed with ${e.runtimeType}',
        error: true,
      );
      return 0;
    }
  }

  /// True when the remote is not what this device last synced against.
  ///
  /// [SyncProvider.probeRemote] keeps "the document is gone" apart from "this
  /// provider cannot tell": a target that synced successfully and now reports a
  /// missing remote **has changed**, and pretending otherwise would leave a
  /// device silently stuck on a remote that was deleted by someone else.
  Future<bool> remoteChanged({SyncProvider? provider}) async {
    final SyncProvider? target =
        provider ?? providerFromConfig(await settings.syncConfig());
    if (target == null || !target.supportsConditionalWrites) return false;
    final String? raw = await db.readMeta('sync_target:${targetKey(target)}');
    if (raw == null) return true;
    String? lastRevision;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return true;
      lastRevision = decoded['revision'] as String?;
    } on FormatException {
      return true;
    } on TypeError {
      return true;
    }
    final RemoteProbe probe = await target.probeRemote();
    return switch (probe.kind) {
      RemoteProbeKind.unsupported => false,
      // Report a change so the guarded sync path raises remoteMissing instead of
      // silently returning "nothing to do".
      RemoteProbeKind.missing => true,
      RemoteProbeKind.revision => probe.revision != lastRevision,
    };
  }

  /// Automatic-sync switches the settings page can write.
  static const Map<String, String> autoFlags = {
    'start': 'autoOnStart',
    'resume': 'autoOnResume',
    'change': 'autoOnChange',
    'session-end': 'autoAfterSession',
  };

  /// The low-frequency foreground remote check is an internal reliability
  /// mechanism, not a user preference: it only runs when the user has asked for
  /// *some* automatic sync and the target supports conditional writes. It never
  /// had a settings row of its own, so enabling it can no longer depend on a
  /// config key that nothing writes.
  static bool foregroundProbeEnabled(Map<String, Object?>? config) {
    if (config == null) return false;
    return autoFlags.values.any((String flag) => config[flag] == true);
  }

  static bool _triggerEnabled(Map<String, Object?>? config, String trigger) {
    if (config == null) return false;
    if (trigger == 'foreground') return foregroundProbeEnabled(config);
    final String? flag = autoFlags[trigger];
    return flag != null && config[flag] == true;
  }

  Future<Map<String, int>> _autoState(SyncProvider provider) async {
    final raw = await db.readMeta('sync_auto:${targetKey(provider)}');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded.values.any((value) => value is! int)) {
        return {};
      }
      return decoded.map((key, value) => MapEntry(key as String, value as int));
    } on FormatException {
      return {};
    }
  }

  Future<Duration?> autoRetryDelay({String trigger = 'change'}) async {
    final config = await settings.syncConfig();
    if (!_triggerEnabled(config, trigger)) return null;
    final provider = providerFromConfig(config);
    if (provider == null ||
        !provider.supportsConditionalWrites ||
        !await hasSyncedTarget(provider)) {
      return null;
    }
    final state = await _autoState(provider),
        now = clock.now().millisecondsSinceEpoch;
    if (now < (state['attempt'] ?? 0)) return Duration.zero;
    final remaining = (state['next'] ?? 0) - now;
    return remaining > 0 ? Duration(milliseconds: remaining) : Duration.zero;
  }

  /// Foreground-only automatic sync; caller debounces actual edits.
  /// Per-target attempt/backoff survives process restarts. Manual sync bypasses it.
  ///
  /// `foreground` is the periodic remote check: it runs even when this device
  /// has no local changes, but only performs a full sync when the remote
  /// revision differs from the one stored by the last successful run.
  Future<SyncReport?> autoSync({String trigger = 'start'}) async {
    if (_running || _preparingAuto) return null;
    _preparingAuto = true;
    try {
      if (await settings.syncPaused()) return null;
      final config = await settings.syncConfig();
      if (!_triggerEnabled(config, trigger)) return null;
      final provider = providerFromConfig(config);
      if (provider == null ||
          !provider.supportsConditionalWrites ||
          !await hasSyncedTarget(provider)) {
        return null;
      }
      final revision = await db.readMeta(
        SettingsRepository.syncConfigRevisionKey,
      );
      final state = await _autoState(provider), now = clock.now();
      final millis = now.millisecondsSinceEpoch;
      if (millis >= (state['attempt'] ?? 0) && millis < (state['next'] ?? 0)) {
        return null;
      }
      if (trigger == 'change' || trigger == 'session-end') {
        if (!await hasLocalChanges(target: provider)) return null;
      }
      if (trigger == 'foreground') {
        // Cheap probe first; a full sync only when the remote actually moved.
        if (!await remoteChanged(provider: provider)) return null;
      }
      if (_running) return null;
      await db.writeMeta(
        'sync_auto:${targetKey(provider)}',
        jsonEncode({
          'attempt': millis,
          'next': millis + autoSyncMinInterval.inMilliseconds,
          'failures': state['failures'] ?? 0,
        }),
      );
      try {
        return await sync(provider, skipConnectionTest: true);
      } on SyncException catch (e) {
        final failures = ((state['failures'] ?? 0) + 1).clamp(1, 10);
        final minutes = (5 * (1 << (failures - 1))).clamp(5, 60);
        await db.writeMeta(
          'sync_auto:${targetKey(provider)}',
          jsonEncode({
            'attempt': millis,
            'next': clock
                .now()
                .add(Duration(minutes: minutes))
                .millisecondsSinceEpoch,
            'failures': failures,
          }),
        );
        await db.transaction(() async {
          if (await db.readMeta(SettingsRepository.syncConfigRevisionKey) ==
              revision) {
            await settings.setLastSyncResult('自动同步失败：${e.message}');
          }
        });
        return SyncReport(
          ok: false,
          message: e.message,
          at: clock.now(),
          stage: e is SyncRemoteMissingException
              ? SyncStage.remoteMissing
              : e is SyncPartialException
              ? SyncStage.mergedNotUploaded
              : SyncStage.failed,
          localMerged: e is SyncPartialException && e.localChanged,
        );
      }
    } finally {
      _preparingAuto = false;
    }
  }

  Future<void> _verifyUpload(SyncProvider provider, String expectedHash) async {
    final after = await provider.download();
    if (after == null) throw const SyncException('上传后无法读回远程数据');
    await backup.validateDatasetAsync(after.dataset);
    final actual = await BackupService.contentHashOfAsync(after.dataset);
    if (actual != expectedHash) {
      throw const SyncConflictException('上传后远程内容再次变化，重新读取并合并');
    }
  }

  /// Persists the outcome.
  ///
  /// If the configuration changed while this run was in flight, the *global*
  /// last-sync fields belong to the new target the user just picked, so they are
  /// left alone. The per-target record is still written: it describes the target
  /// that actually received the upload, keyed by its own identity.
  Future<void> _persistState({
    required DateTime now,
    required String hash,
    String? revision,
    required String message,
  }) => db.transaction(() async {
    await db.deleteMeta(SettingsRepository.pendingRebuildKey);
    if (await db.readMeta(SettingsRepository.syncConfigRevisionKey) ==
        _activeConfigRevision) {
      await settings.setLastSyncAt(now);
      await settings.setLastSyncResult(message);
      await db.writeMeta(lastLocalHashKey, hash);
      if (revision != null) await db.writeMeta(lastRemoteRevisionKey, revision);
    }
    final target = _activeTarget;
    if (target != null) {
      await db.writeMeta(
        'sync_auto:$target',
        jsonEncode({
          'attempt': now.millisecondsSinceEpoch,
          'next': now.add(autoSyncMinInterval).millisecondsSinceEpoch,
          'failures': 0,
        }),
      );
      await db.writeMeta(
        'sync_target:$target',
        jsonEncode({
          'at': now.toUtc().toIso8601String(),
          'hash': hash,
          'revision': revision,
        }),
      );
    }
  });

  static String targetKey(SyncProvider provider) {
    final String identity = switch (provider) {
      GitHubSyncProvider p => jsonEncode([
        'github',
        p.owner.toLowerCase(),
        p.repo.toLowerCase(),
        p.branch,
        p.path,
        p.identityEpoch,
      ]),
      WebDavSyncProvider p => jsonEncode([
        'webdav',
        p.baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
        p.remoteDir,
        p.fileName,
        p.identityEpoch,
      ]),
      LocalFileSyncProvider p => jsonEncode(['local-file', p.filePath]),
      _ => provider.id,
    };
    return sha256.convert(utf8.encode(identity)).toString();
  }

  Future<bool> hasSyncedTarget(SyncProvider provider) async =>
      await db.readMeta('sync_target:${targetKey(provider)}') != null;

  Future<void> _recordFailure(DateTime now, {String message = '同步失败'}) =>
      db.transaction(() async {
        if (await db.readMeta(SettingsRepository.syncConfigRevisionKey) ==
            _activeConfigRevision) {
          await settings.setLastSyncResult(message);
        }
        // A failed run must also arm the per-target backoff, otherwise the next
        // automatic trigger retries immediately and a broken network turns into
        // a request loop.
        final String? target = _activeTarget;
        if (target == null) return;
        final Map<String, int> state = await _autoStateFor(target);
        final int failures = ((state['failures'] ?? 0) + 1).clamp(1, 10);
        final int minutes = (5 * (1 << (failures - 1))).clamp(5, 60);
        await db.writeMeta(
          'sync_auto:$target',
          jsonEncode({
            'attempt': now.millisecondsSinceEpoch,
            'next': now.add(Duration(minutes: minutes)).millisecondsSinceEpoch,
            'failures': failures,
          }),
        );
      });

  Future<Map<String, int>> _autoStateFor(String target) async {
    final raw = await db.readMeta('sync_auto:$target');
    if (raw == null) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded.values.any((value) => value is! int)) {
        return <String, int>{};
      }
      return decoded.map((key, value) => MapEntry(key as String, value as int));
    } on FormatException {
      return <String, int>{};
    }
  }

  /// Writes a recovery marker before a long rebuild. The merge itself runs in a
  /// single transaction (so it rolls back cleanly), this is a belt-and-braces
  /// safety net for a future staged implementation and for crash recovery.
  Future<void> markPendingRebuild(Iterable<String> wordIds) async {
    if (wordIds.isEmpty) return;
    await db.writeMeta(
      SettingsRepository.pendingRebuildKey,
      jsonEncode(wordIds.toList(growable: false)),
    );
  }

  /// Repairs learning state after an interrupted rebuild. Safe to call at any
  /// time: it only touches words listed in the marker.
  Future<int> recoverPendingRebuild() async {
    final String? raw = await db.readMeta(SettingsRepository.pendingRebuildKey);
    if (raw == null || raw.isEmpty) return 0;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      await db.deleteMeta(SettingsRepository.pendingRebuildKey);
      return 0;
    }
    if (decoded is! List) {
      await db.deleteMeta(SettingsRepository.pendingRebuildKey);
      return 0;
    }
    int repaired = 0;
    for (final Object? id in decoded) {
      if (id is! String) continue;
      await study.rebuildStateFromEvents(id);
      repaired++;
    }
    await db.deleteMeta(SettingsRepository.pendingRebuildKey);
    return repaired;
  }

  /// Local changes that have not been pushed yet (best-effort indicator for the
  /// sync page). Compares the current content hash with the last synced hash.
  Future<bool> hasLocalChanges({SyncProvider? target}) async {
    final provider = target ?? providerFromConfig(await settings.syncConfig());
    final raw = provider == null
        ? null
        : await db.readMeta('sync_target:${targetKey(provider)}');
    final String? last = raw == null
        ? null
        : (jsonDecode(raw) as Map)['hash'] as String?;
    if (last == null) return true;
    final Map<String, Object?> dataset = await backup.buildDataset(
      now: clock.now(),
    );
    return await BackupService.contentHashOfAsync(dataset) != last;
  }

  String _formatCount(Map<String, Object?> dataset) {
    final int words = (dataset['words'] as List<dynamic>?)?.length ?? 0;
    final int events = (dataset['reviewEvents'] as List<dynamic>?)?.length ?? 0;
    return '$words 个词条 / $events 条学习记录';
  }
}

/// Helper for tests: an in-memory "remote server" with the same conditional
/// write semantics as the real providers.
class ScriptedSyncProvider implements SyncProvider {
  ScriptedSyncProvider({
    Map<String, Object?>? initial,
    this.conflictOnce = false,
    this.failUploadWith,
    this.failDownloadWith,
    this.beforeUpload,
    this.failFirstUploads = 0,
  }) : _remote = initial,
       _revision = initial == null ? null : 'rev-0';

  Map<String, Object?>? _remote;
  String? _revision;

  final bool conflictOnce;
  final Object? failUploadWith;
  final Object? failDownloadWith;

  /// Runs immediately before a conditional write, i.e. while the local merge is
  /// already applied but the upload has not happened yet.
  final Future<void> Function()? beforeUpload;

  /// Fails the first N uploads to exercise retry/backoff behaviour.
  final int failFirstUploads;

  int downloadCalls = 0;
  int uploadCalls = 0;
  Map<String, Object?>? lastUploaded;
  String? lastIfRevision;
  bool _conflicted = false;

  /// Drops the remote document, as if someone deleted the file in the repo or
  /// on the WebDAV server. The revision goes with it — a file that is not there
  /// has no version — so a later unconditional upload can recreate it.
  void deleteRemoteDocument() {
    _remote = null;
    _revision = null;
  }

  @override
  String get id => 'scripted';

  @override
  String get label => '脚本测试';

  @override
  String get description => 'test double';

  @override
  bool get isImplemented => true;

  @override
  bool get requiresNetwork => false;

  @override
  bool get supportsConditionalWrites => true;

  @override
  Future<SyncPayload?> download() async {
    downloadCalls++;
    final Object? failure = failDownloadWith;
    if (failure is SyncException) throw failure;
    final Map<String, Object?>? data = _remote;
    if (data == null) return null;
    return SyncPayload(dataset: data, revision: _revision);
  }

  @override
  Future<RemoteProbe> probeRemote() async => _remote == null
      ? const RemoteProbe.missing()
      : RemoteProbe.revision(_revision ?? '');

  @override
  Future<String?> remoteRevision() async => _remote == null ? null : _revision;

  @override
  Future<SyncTestResult> testConnection() async =>
      const SyncTestResult(ok: true, message: 'ok');

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async {
    uploadCalls++;
    if (beforeUpload != null) await beforeUpload!();
    if (failFirstUploads > 0 && uploadCalls <= failFirstUploads) {
      throw const SyncException('模拟：网络在上传中中断', retryable: true);
    }
    lastUploaded = dataset;
    lastIfRevision = ifRevision;
    if (conflictOnce && !_conflicted) {
      _conflicted = true;
      throw const SyncConflictException('模拟并发冲突');
    }
    final Object? failure = failUploadWith;
    if (failure is SyncException) throw failure;
    if (ifRevision != _revision) {
      throw const SyncConflictException('模拟：基于过期版本写入');
    }
    _remote = dataset;
    _revision = 'rev-$uploadCalls';
    return SyncUploadResult(ok: true, message: 'ok', revision: _revision);
  }
}

/// Extension so the UI can show a short "待同步" hint.
extension SyncReportStatus on SyncReport {
  String get shortStatus => ok ? (skipped ? '无变化' : '成功') : '失败';
}
