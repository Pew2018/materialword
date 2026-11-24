import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/enums.dart';

const Uuid _uuid = Uuid();

/// Reads/writes the single settings row and the device identity.
class SettingsRepository {
  SettingsRepository(this.db);

  final AppDatabase db;

  static const String deviceIdKey = 'device_id';
  static const String seededKey = 'sample_seeded';

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

  Future<void> save({
    int? dailyNewTarget,
    int? dailyReviewLimit,
    Value<String?>? currentWordBookId,
    StudyMode? studyMode,
    ThemePreference? theme,
  }) async {
    final StudySettingsRow current = await load();
    await db
        .update(db.studySettings)
        .replace(
          current.copyWith(
            dailyNewTarget: dailyNewTarget,
            dailyReviewLimit: dailyReviewLimit,
            currentWordBookId:
                currentWordBookId ?? const Value<String?>.absent(),
            studyMode: studyMode?.code,
            themeMode: theme?.code,
          ),
        );
  }

  /// A stable per-install identifier used to attribute review events.
  Future<String> deviceId() async {
    final String? existing = await db.readMeta(deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final String created = _uuid.v4();
    await db.writeMeta(deviceIdKey, created);
    return created;
  }

  Future<bool> isSampleSeeded() async =>
      (await db.readMeta(seededKey)) == 'true';

  Future<void> markSampleSeeded() => db.writeMeta(seededKey, 'true');
}
