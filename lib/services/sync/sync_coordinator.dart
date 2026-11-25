import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/database/app_database.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/repositories/study_repository.dart';
import '../../core/time_utils.dart';
import '../backup_service.dart';
import 'credential_store.dart';
import 'github_sync_provider.dart';
import 'local_file_sync_provider.dart';
import 'sync_provider.dart';
import 'webdav_sync_provider.dart';

/// Progress callback so the sync page can show what is happening.
enum SyncStage {
  idle('准备'),
  validating('校验配置'),
  downloading('读取远程数据'),
  merging('合并到本地'),
  rebuilding('重建学习状态'),
  uploading('上传数据'),
  verifying('校验上传结果'),
  done('完成'),
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
  Future<SyncReport> sync(
    SyncProvider provider, {
    void Function(SyncStage stage, String detail)? onProgress,
    bool skipConnectionTest = false,
  }) async {
    if (_running) {
      throw const SyncException('已有同步正在进行，请稍后再试');
    }
    if (!provider.isImplemented) {
      throw const SyncException('该同步方式尚未启用');
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

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        attempts = attempt + 1;
        try {
          onProgress?.call(SyncStage.downloading, '读取远程数据');
          final SyncPayload? remote = await provider.download();

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
              );
            }
            merge = await backup.mergeDataset(remote.dataset, now: clock.now());
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
          );
        } on SyncConflictException catch (e) {
          notes.add('第 $attempts 次上传冲突：${e.message}，正在重新拉取并合并');
          if (attempt == maxAttempts - 1) rethrow;
          continue;
        } on TimeoutException {
          throw const SyncException('网络超时：请检查网络后重试', retryable: true);
        }
      }
      throw const SyncException('同步未能完成：多次出现并发冲突，请稍后再试');
    } on SyncException catch (e) {
      await _recordFailure(clock.now(), message: '同步失败：${e.message}');
      rethrow;
    } catch (e) {
      await _recordFailure(clock.now());
      throw SyncException('同步失败：$e');
    } finally {
      if (provider is WebDavSyncProvider) {
        provider.clearCapturedCredentials();
        provider.close();
      }
      if (provider is GitHubSyncProvider) provider.clearCapturedCredentials();
      _running = false;
      _activeTarget = null;
      _activeConfigRevision = null;
    }
  }

  static const Map<String, String> autoFlags = {
    'start': 'autoOnStart',
    'resume': 'autoOnResume',
    'change': 'autoOnChange',
    'session-end': 'autoAfterSession',
  };

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
    if (config?[autoFlags[trigger]] != true) return null;
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
  Future<SyncReport?> autoSync({String trigger = 'start'}) async {
    if (_running || _preparingAuto) return null;
    _preparingAuto = true;
    try {
      final config = await settings.syncConfig();
      if (config?[autoFlags[trigger]] != true) return null;
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
      if ((trigger == 'change' || trigger == 'session-end') &&
          !await hasLocalChanges(target: provider)) {
        return null;
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
        return SyncReport(ok: false, message: e.message, at: clock.now());
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

  Future<void> _persistState({
    required DateTime now,
    required String hash,
    String? revision,
    required String message,
  }) => db.transaction(() async {
    if (await db.readMeta(SettingsRepository.syncConfigRevisionKey) ==
        _activeConfigRevision) {
      await settings.setLastSyncAt(now);
      await settings.setLastSyncResult(message);
      await db.writeMeta(lastLocalHashKey, hash);
      if (revision != null) await db.writeMeta(lastRemoteRevisionKey, revision);
    }
    await db.deleteMeta(SettingsRepository.pendingRebuildKey);
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
      });

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
  }) : _remote = initial,
       _revision = initial == null ? null : 'rev-0';

  Map<String, Object?>? _remote;
  String? _revision;

  final bool conflictOnce;
  final Object? failUploadWith;
  final Object? failDownloadWith;

  int downloadCalls = 0;
  int uploadCalls = 0;
  Map<String, Object?>? lastUploaded;
  String? lastIfRevision;
  bool _conflicted = false;

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
  Future<SyncTestResult> testConnection() async =>
      const SyncTestResult(ok: true, message: 'ok');

  @override
  Future<SyncUploadResult> upload(
    Map<String, Object?> dataset, {
    String? ifRevision,
  }) async {
    uploadCalls++;
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
