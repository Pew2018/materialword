import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/enums.dart';

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

  static const String deviceIdKey = 'device_id';
  static const String datasetIdKey = 'dataset_id';
  static const String seededKey = 'sample_seeded';
  static const String lastSyncAtKey = 'last_sync_at';
  static const String lastSyncResultKey = 'last_sync_result';
  static const String syncConfigKey = 'sync_config';
  static const String pendingRebuildKey = 'pending_rebuild_words';

  Future<StudySettingsRow> load() async {
    final StudySettingsRow? row = await (db.select(
      db.studySettings,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (row != null) return row;
    await db
        .into(db.studySettings)
        .insertOnConflictUpdate(
          StudySettingsCompanion.insert(id: const Value<int>(1)),
        );
    return (db.select(
      db.studySettings,
    )..where((t) => t.id.equals(1))).getSingle();
  }

  Stream<StudySettingsRow> watch() {
    return (db.select(db.studySettings)..where((t) => t.id.equals(1)))
        .watchSingleOrNull()
        .asyncMap((StudySettingsRow? row) async {
          if (row != null) return row;
          await db
              .into(db.studySettings)
              .insertOnConflictUpdate(
                StudySettingsCompanion.insert(id: const Value<int>(1)),
              );
          return (db.select(
            db.studySettings,
          )..where((t) => t.id.equals(1))).getSingle();
        });
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
  }) async {
    // Make sure the row exists, but never rewrite its contents here.
    await load();

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

    await (db.update(
      db.studySettings,
    )..where((t) => t.id.equals(1))).write(patch);
  }

  /// A stable per-install identifier used to attribute review events.
  Future<String> deviceId() async {
    final String? existing = await db.readMeta(deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final String created = _uuid.v4();
    await db.writeMeta(deviceIdKey, created);
    return created;
  }

  /// Stable identity of *this* dataset. It must not change between exports,
  /// otherwise every sync looks like a brand-new dataset to the remote side.
  Future<String> datasetId() async {
    final String? existing = await db.readMeta(datasetIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final String created = _uuid.v4();
    await db.writeMeta(datasetIdKey, created);
    return created;
  }

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

  /// The persisted sync configuration (provider id + non-secret options).
  /// Secrets live in the platform credential store, never here.
  Future<Map<String, Object?>?> syncConfig() async {
    final String? raw = await db.readMeta(syncConfigKey);
    if (raw == null) return null;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return Map<String, Object?>.from(decoded);
  }

  Future<void> setSyncConfig(Map<String, Object?>? config) async {
    if (config == null) {
      await db.deleteMeta(syncConfigKey);
      return;
    }
    await db.writeMeta(syncConfigKey, jsonEncode(config));
  }
}
