import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/sprint_plan.dart';

const Uuid _uuid = Uuid();

/// Reads/writes the single settings row and the device identity.
///
/// Every write is a **field-level** `UPDATE` (`StudySettingsCompanion` only
/// carries the columns the caller asked for). The phase-1 implementation read
/// the whole row and replaced it, so two concurrent saves — the slider writing
/// `dailyNewTarget` while the dashboard writes `currentWordBookId` — could
/// silently undo each other. Now the last writer of *a given field* wins and
/// unrelated fields are never touched.
class SettingsRepository {
  SettingsRepository(this.db);

  final AppDatabase db;

  static const String sharedVersionKey = 'shared_settings_version';
  static const String sprintPlanKey = 'sprint_plan_v1';

  static const String deviceIdKey = 'device_id';
  static const String datasetIdKey = 'dataset_id';
  static const String seededKey = 'sample_seeded';
  static const String lastSyncAtKey = 'last_sync_at';
  static const String lastSyncResultKey = 'last_sync_result';
  static const String syncConfigKey = 'sync_config';
  static const String syncConfigRevisionKey = 'sync_config_revision';
  static const String cloudBackupS3ConfigKey = 'cloud_backup_s3_config';
  static const String cloudBackupWebDavConfigKey = 'cloud_backup_webdav_config';
  static const String cloudBackupPreferredTargetKey =
      'cloud_backup_preferred_target';
  static const String cloudBackupLastSuccessKey = 'cloud_backup_last_success';
  static const String cloudBackupLastDownloadKey = 'cloud_backup_last_download';
  static const String cloudBackupConfigRevisionKey =
      'cloud_backup_config_revision';
  static const String pendingRebuildKey = 'pending_rebuild_words';

  // ---- phase 5: backup preferences and post-restore sync isolation ----------
  static const String syncPausedKey = 'sync_paused_after_restore';
  static const String syncPausedReasonKey = 'sync_paused_reason';
  static const String autoBackupEnabledKey = 'auto_backup_enabled';
  static const String autoBackupIntervalKey = 'auto_backup_interval_hours';
  static const String autoBackupRetentionKey = 'auto_backup_retention';
  static const String lastAutoBackupAtKey = 'last_auto_backup_at';
  static const String lastAutoBackupHashKey = 'last_auto_backup_hash';

  Future<StudySettingsRow> load() async {
    final StudySettingsRow? row = await (db.select(
      db.studySettings,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (row != null) return row;
    await db
        .into(db.studySettings)
        .insert(
          StudySettingsCompanion.insert(id: const Value<int>(1)),
          mode: InsertMode.insertOrIgnore,
        );
    return (db.select(
      db.studySettings,
    )..where((t) => t.id.equals(1))).getSingle();
  }

  Stream<StudySettingsRow> watch() async* {
    await load();
    yield* (db.select(
      db.studySettings,
    )..where((t) => t.id.equals(1))).watchSingle();
  }

  /// Saves only the fields that are passed in. Returns once the row is written.
  Future<void> save({
    int? dailyNewTarget,
    int? dailyReviewLimit,
    Value<String?>? currentWordBookId,
    StudyMode? studyMode,
    ThemePreference? theme,
    String? accentColor,
    String? ttsVoice,
    String? ttsLocale,
    int? ttsRate,
    bool? ttsAutoSpeak,
    Map<String, Object?>? importedVersion,
    SprintPlan? sprintPlan,
  }) => db.transaction(() async {
    // Make sure the row exists, but never rewrite its contents here.
    final before = await load();
    final planChanged =
        sprintPlan != null &&
        jsonEncode(sprintPlan.toJson()) !=
            jsonEncode((await loadSprintPlan()).toJson());
    if (sprintPlan != null) SprintPlan.fromJson(sprintPlan.toJson());
    final bool sharedChanged =
        planChanged ||
        (dailyNewTarget != null && dailyNewTarget != before.dailyNewTarget) ||
        (dailyReviewLimit != null &&
            dailyReviewLimit != before.dailyReviewLimit) ||
        (studyMode != null && studyMode.code != before.studyMode);
    final StudySettingsCompanion patch = StudySettingsCompanion(
      dailyNewTarget: dailyNewTarget == null
          ? const Value<int>.absent()
          : Value<int>(dailyNewTarget),
      dailyReviewLimit: dailyReviewLimit == null
          ? const Value<int>.absent()
          : Value<int>(dailyReviewLimit),
      currentWordBookId: currentWordBookId ?? const Value<String?>.absent(),
      studyMode: studyMode == null
          ? const Value<String>.absent()
          : Value<String>(studyMode.code),
      themeMode: theme == null
          ? const Value<String>.absent()
          : Value<String>(theme.code),
      accentColor: accentColor == null
          ? const Value<String>.absent()
          : Value<String>(accentColor),
      ttsVoice: ttsVoice == null
          ? const Value<String>.absent()
          : Value<String>(ttsVoice),
      ttsLocale: ttsLocale == null
          ? const Value<String>.absent()
          : Value<String>(ttsLocale),
      ttsRate: ttsRate == null
          ? const Value<int>.absent()
          : Value<int>(ttsRate),
      ttsAutoSpeak: ttsAutoSpeak == null
          ? const Value<bool>.absent()
          : Value<bool>(ttsAutoSpeak),
    );

    if (patch.toColumns(true).isNotEmpty) {
      await (db.update(
        db.studySettings,
      )..where((t) => t.id.equals(1))).write(patch);
    }
    if (planChanged) {
      await db.writeMeta(sprintPlanKey, jsonEncode(sprintPlan.toJson()));
    }
    if (importedVersion != null) {
      await db.writeMeta(sharedVersionKey, jsonEncode(importedVersion));
    } else if (sharedChanged) {
      final version = await sharedVersion();
      await db.writeMeta(
        sharedVersionKey,
        jsonEncode(<String, Object?>{
          'counter': (version['counter'] as int) + 1,
          'deviceId': await deviceId(),
        }),
      );
    }
  });

  Future<SprintPlan> loadSprintPlan() async {
    final raw = await db.readMeta(sprintPlanKey);
    if (raw == null) return const SprintPlan();
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) throw const FormatException('冲刺计划无效');
    return SprintPlan.fromJson(data);
  }

  Stream<SprintPlan> watchSprintPlan() =>
      (db.select(db.appMeta)..where((t) => t.key.equals(sprintPlanKey)))
          .watchSingleOrNull()
          .map(
            (row) => row == null
                ? const SprintPlan()
                : SprintPlan.fromJson(
                    Map<String, Object?>.from(jsonDecode(row.value) as Map),
                  ),
          )
          .distinct((a, b) => jsonEncode(a.toJson()) == jsonEncode(b.toJson()));

  Future<Map<String, Object?>> sharedVersion() async {
    final raw = await db.readMeta(sharedVersionKey);
    if (raw == null) return <String, Object?>{'counter': 0, 'deviceId': ''};
    return Map<String, Object?>.from(jsonDecode(raw) as Map);
  }

  static int compareVersions(Map<String, Object?> a, Map<String, Object?> b) {
    final counter = (a['counter'] as int).compareTo(b['counter'] as int);
    return counter != 0
        ? counter
        : (a['deviceId'] as String).compareTo(b['deviceId'] as String);
  }

  /// A stable per-install identifier used to attribute review events.
  Future<String> deviceId() => _stableIdentity(deviceIdKey);

  /// Stable dataset identity, created once even when first-use callers overlap.
  Future<String> datasetId() => _stableIdentity(datasetIdKey);

  Future<String> _stableIdentity(String key) => db.transaction(() async {
    final existing = await db.readMeta(key);
    if (existing != null && existing.isNotEmpty) return existing;
    await db
        .into(db.appMeta)
        .insert(
          AppMetaCompanion.insert(key: key, value: _uuid.v4()),
          mode: InsertMode.insertOrIgnore,
        );
    final value = await db.readMeta(key);
    if (value == null || value.isEmpty) throw StateError('设备身份未能创建');
    return value;
  });

  Future<bool> isSampleSeeded() async =>
      (await db.readMeta(seededKey)) == 'true';

  Future<void> markSampleSeeded() => db.writeMeta(seededKey, 'true');

  // ------------------------------------------------------------ sync state
  Future<DateTime?> lastSyncAt() async {
    final String? raw = await db.readMeta(lastSyncAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> setLastSyncAt(DateTime moment) =>
      db.writeMeta(lastSyncAtKey, moment.toUtc().toIso8601String());

  Future<String?> lastSyncResult() => db.readMeta(lastSyncResultKey);

  Future<void> setLastSyncResult(String value) =>
      db.writeMeta(lastSyncResultKey, value);

  /// A point-in-time restore leaves the device deliberately out of sync with
  /// every remote. While this flag is set, no automatic sync runs and a manual
  /// sync must be an explicit "merge the remote into this device" decision.
  Future<bool> syncPaused() async =>
      (await db.readMeta(syncPausedKey)) == 'true';

  Future<String?> syncPausedReason() => db.readMeta(syncPausedReasonKey);

  Future<void> setSyncPaused(bool paused, {String reason = ''}) =>
      db.transaction(() async {
        if (paused) {
          await db.writeMeta(syncPausedKey, 'true');
          await db.writeMeta(syncPausedReasonKey, reason);
        } else {
          await db.deleteMeta(syncPausedKey);
          await db.deleteMeta(syncPausedReasonKey);
          // Forgetting the last synced revision forces the next sync to merge
          // instead of trusting bookkeeping that describes pre-restore data.
          await db.deleteMeta('last_sync_local_hash');
          await db.deleteMeta('last_sync_remote_revision');
        }
      });

  Future<bool> autoBackupEnabled() async {
    final String? raw = await db.readMeta(autoBackupEnabledKey);
    return raw != 'false'; // on by default
  }

  Future<void> setAutoBackupEnabled(bool value) =>
      db.writeMeta(autoBackupEnabledKey, value ? 'true' : 'false');

  Future<Duration> autoBackupInterval() async {
    final int hours =
        int.tryParse(await db.readMeta(autoBackupIntervalKey) ?? '') ?? 24;
    return Duration(hours: hours.clamp(1, 24 * 30));
  }

  Future<void> setAutoBackupInterval(Duration value) =>
      db.writeMeta(autoBackupIntervalKey, '${value.inHours.clamp(1, 24 * 30)}');

  Future<int> autoBackupRetention() async {
    final int value =
        int.tryParse(await db.readMeta(autoBackupRetentionKey) ?? '') ?? 5;
    return value.clamp(1, 30);
  }

  Future<void> setAutoBackupRetention(int value) =>
      db.writeMeta(autoBackupRetentionKey, '${value.clamp(1, 30)}');

  Future<DateTime?> lastAutoBackupAt() async {
    final raw = await db.readMeta(lastAutoBackupAtKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> setLastAutoBackup(DateTime at, String hash) =>
      db.transaction(() async {
        await db.writeMeta(lastAutoBackupAtKey, at.toUtc().toIso8601String());
        await db.writeMeta(lastAutoBackupHashKey, hash);
      });

  Future<String?> lastAutoBackupHash() => db.readMeta(lastAutoBackupHashKey);

  /// The persisted sync configuration (provider id + non-secret options).
  /// Secrets live in the platform credential store, never here.
  Future<Map<String, Object?>?> syncConfig() async {
    final String? raw = await db.readMeta(syncConfigKey);
    if (raw == null) return null;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return Map<String, Object?>.from(decoded);
  }

  Future<void> setSyncConfig(Map<String, Object?>? config) =>
      db.transaction(() async {
        final revision =
            int.tryParse(await db.readMeta(syncConfigRevisionKey) ?? '') ?? 0;
        await db.writeMeta(syncConfigRevisionKey, '${revision + 1}');
        if (config == null) {
          await db.deleteMeta(syncConfigKey);
          return;
        }
        await db.writeMeta(syncConfigKey, jsonEncode(config));
      });

  Future<bool> updateSyncAutoOption(
    String key,
    bool value, {
    required Map<String, Object?> expected,
  }) => db.transaction(() async {
    const flags = {
      'autoOnStart',
      'autoOnResume',
      'autoOnChange',
      'autoAfterSession',
    };
    if (!flags.contains(key)) throw ArgumentError.value(key);
    final current = await syncConfig();
    if (current == null) return false;
    String connection(Map<String, Object?> config) {
      final keys = config.keys.where((k) => !flags.contains(k)).toList()
        ..sort();
      return jsonEncode({for (final k in keys) k: config[k]});
    }

    if (connection(current) != connection(expected)) return false;
    await setSyncConfig({...current, key: value});
    return true;
  });
}
