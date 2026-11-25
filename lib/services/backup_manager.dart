import 'dart:io';

import 'package:drift/drift.dart' show QueryRow;
import 'package:file_picker/file_picker.dart';

import '../core/database/app_database.dart';
import '../core/models/enums.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/study_repository.dart';
import '../core/time_utils.dart';
import 'backup_service.dart';
import 'practice_session.dart';
import 'study_session.dart';

/// Why a recovery copy exists. Retention and UI wording differ per kind, and a
/// protective copy must never be pruned by the automatic-backup rotation.
enum BackupKind {
  manual('manual', '手动'),
  automatic('auto', '自动'),
  protective('protective', '高风险操作前');

  const BackupKind(this.slug, this.label);

  final String slug;
  final String label;

  static BackupKind parse(String name) {
    if (name.contains('-protective-')) return BackupKind.protective;
    if (name.contains('-auto-')) return BackupKind.automatic;
    return BackupKind.manual;
  }
}

class BackupEntry {
  const BackupEntry({
    required this.file,
    required this.modified,
    required this.bytes,
    required this.kind,
  });

  final File file;
  final DateTime modified;
  final int bytes;
  final BackupKind kind;

  String get name => file.uri.pathSegments.last;
}

/// What a recovery copy contains, read from the file itself (not from a cache).
class BackupInfo {
  const BackupInfo({
    required this.fileName,
    required this.valid,
    this.problem,
    this.exportedAt,
    this.schemaVersion = 0,
    this.words = 0,
    this.books = 0,
    this.entries = 0,
    this.events = 0,
    this.favorites = 0,
    this.tags = 0,
    this.deviceId,
    this.datasetId,
    this.hasDeviceSettings = false,
    this.appVersion = '',
  });

  final String fileName;
  final bool valid;
  final String? problem;
  final DateTime? exportedAt;
  final int schemaVersion;
  final int words;
  final int books;
  final int entries;
  final int events;
  final int favorites;
  final int tags;
  final String? deviceId;
  final String? datasetId;
  final bool hasDeviceSettings;
  final String appVersion;

  String get summary => valid
      ? '词条 $words · 词书 $books · 关联 $entries · 学习记录 $events'
            '${tags > 0 ? ' · 标签 $tags' : ''}${favorites > 0 ? ' · 收藏 $favorites' : ''}'
      : '无法读取：${problem ?? '未知原因'}';
}

/// Result of a point-in-time restore.
class RestoreOutcome {
  const RestoreOutcome({
    required this.report,
    required this.protectiveBackup,
    required this.clearedWords,
    required this.clearedEvents,
    required this.syncPaused,
  });

  final MergeReport report;
  final File protectiveBackup;
  final int clearedWords;
  final int clearedEvents;
  final bool syncPaused;

  String get summary =>
      '已恢复 ${report.newWords + report.updatedWords} 个词条、'
      '${report.addedEvents} 条学习记录（恢复前已保存保护性备份）';
}

class AutoBackupResult {
  const AutoBackupResult({this.file, this.skippedReason, this.error});

  final File? file;
  final String? skippedReason;
  final String? error;

  bool get created => file != null;

  String get message => created
      ? '已自动备份'
      : error != null
      ? '自动备份失败：$error'
      : '无变化，未重复备份';
}

/// Owns every recovery-copy operation so pages only render and confirm.
///
/// Responsibilities: create (atomic), list, inspect/verify, delete, export,
/// merge-restore, point-in-time restore, retention, automatic scheduling and
/// protective copies before destructive operations.
class BackupManager {
  BackupManager({
    required this.db,
    required this.backup,
    required this.study,
    required this.settings,
    required this.directory,
    this.clock = const SystemClock(),
  });

  final AppDatabase db;
  final BackupService backup;
  final StudyRepository study;
  final SettingsRepository settings;

  /// Where recovery copies live. Injected so tests can use a temp directory.
  final Future<Directory> Function() directory;
  final Clock clock;

  static const int manualRetention = 5;
  static const int protectiveRetention = 3;

  /// Listing never parses file contents (a 40 MB backup would make the page
  /// crawl); use [inspect] for one file.
  Future<List<BackupEntry>> list() async {
    final Directory dir = await directory();
    if (!dir.existsSync()) return const <BackupEntry>[];
    final List<BackupEntry> entries = <BackupEntry>[];
    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is! File) continue;
      final String name = entity.uri.pathSegments.last;
      if (!name.startsWith('materialword-backup-') || !name.endsWith('.json')) {
        continue;
      }
      try {
        final FileStat stat = entity.statSync();
        entries.add(
          BackupEntry(
            file: entity,
            modified: stat.modified,
            bytes: stat.size,
            kind: BackupKind.parse(name),
          ),
        );
      } catch (_) {
        // A file deleted mid-listing is not an error.
      }
    }
    entries.sort((BackupEntry a, BackupEntry b) {
      final int byName = b.name.compareTo(a.name);
      return byName != 0 ? byName : b.modified.compareTo(a.modified);
    });
    return entries;
  }

  Future<BackupInfo> inspect(File file) async {
    final String name = file.uri.pathSegments.last;
    try {
      final Map<String, Object?> dataset = await backup.readDataset(file.path);
      List<Object?> rows(String field) => (dataset[field] as List?) ?? const [];
      final Object? exportedAt = dataset['exportedAt'];
      return BackupInfo(
        fileName: name,
        valid: true,
        exportedAt: exportedAt is String
            ? DateTime.tryParse(exportedAt)?.toLocal()
            : null,
        schemaVersion: (dataset['schemaVersion'] as int?) ?? 0,
        words: rows('words').length,
        books: rows('wordBooks').length,
        entries: rows('entries').length,
        events: rows('reviewEvents').length,
        favorites: rows('favorites').length,
        tags: rows('tags').length,
        deviceId: dataset['deviceId'] as String?,
        datasetId: dataset['datasetId'] as String?,
        hasDeviceSettings: dataset['deviceSettings'] is Map,
        appVersion: (dataset['appVersion'] as String?) ?? '',
      );
    } on BackupException catch (e) {
      return BackupInfo(fileName: name, valid: false, problem: e.message);
    } catch (e) {
      return BackupInfo(fileName: name, valid: false, problem: '$e');
    }
  }

  Future<File> createBackup({BackupKind kind = BackupKind.manual}) async {
    final Directory dir = await directory();
    final File file = await backup.writeBackupFile(
      directory: dir,
      now: clock.now(),
      label: kind.slug,
    );
    if (kind == BackupKind.automatic) {
      final Map<String, Object?> dataset = await backup.buildDataset(
        now: clock.now(),
      );
      await settings.setLastAutoBackup(
        clock.now(),
        BackupService.contentHashOf(dataset),
      );
    }
    await prune(kind: kind);
    return file;
  }

  /// Keeps the newest copies of [kind] only. Protective copies have their own
  /// small budget so a burst of risky operations cannot flush the daily ones.
  Future<int> prune({BackupKind kind = BackupKind.automatic, int? keep}) async {
    final int limit =
        keep ??
        (kind == BackupKind.protective
            ? protectiveRetention
            : kind == BackupKind.automatic
            ? await settings.autoBackupRetention()
            : manualRetention);
    final List<BackupEntry> all = await list();
    final List<BackupEntry> mine = all
        .where((BackupEntry entry) => entry.kind == kind)
        .toList(growable: false);
    int removed = 0;
    for (final BackupEntry entry in mine.skip(limit)) {
      try {
        await entry.file.delete();
        removed++;
      } catch (_) {
        // Keep going: a single undeletable file must not stop the rotation.
      }
    }
    return removed;
  }

  Future<void> delete(File file) async {
    if (file.existsSync()) await file.delete();
  }

  Future<bool> exportCopy(File file) async {
    final Uri? saved = await FilePicker.saveFile(
      fileName: file.uri.pathSegments.last,
      bytes: await file.readAsBytes(),
      mimeType: 'application/json',
      dialogTitle: '导出恢复副本',
    );
    return saved != null;
  }

  /// Non-destructive merge: keeps everything already on this device.
  Future<MergeReport> restoreMerge(File file) async {
    final Map<String, Object?> dataset = await backup.readDataset(file.path);
    return backup.mergeDataset(dataset, now: clock.now());
  }

  /// Point-in-time restore. **Destructive by design**, therefore:
  ///  1. a protective copy of the current state is written and validated first;
  ///  2. the whole replace happens in one transaction (a failure rolls back to
  ///     the exact previous state);
  ///  3. active sessions and sync bookkeeping are invalidated;
  ///  4. sync stays paused until the user decides how to treat the remote.
  Future<RestoreOutcome> restoreSnapshot(
    File file, {
    bool applyDeviceSettings = true,
    Future<void> Function()? afterClear,
  }) async {
    final Map<String, Object?> dataset = await backup.readDataset(file.path);
    final File protective = await createBackup(kind: BackupKind.protective);

    int clearedWords = 0;
    int clearedEvents = 0;
    late MergeReport report;
    await db.transaction(() async {
      clearedWords = await _count(db.words.actualTableName);
      clearedEvents = await _count(db.reviewEvents.actualTableName);
      await _clearAll();
      // Test-only seam: lets a crash be injected *after* the destructive part
      // started, to prove the transaction rolls back to the previous state.
      if (afterClear != null) await afterClear();
      report = await backup.mergeValidatedInTransaction(
        dataset,
        now: clock.now(),
      );
      await db.deleteMeta(StudySession.persistenceKey);
      await db.deleteMeta(PracticeSession.persistenceKey);
      await db.deleteMeta(SettingsRepository.pendingRebuildKey);
      await db.deleteMeta('last_sync_at');
      await db.deleteMeta('last_sync_result');
      await db.deleteMeta('last_sync_local_hash');
      await db.deleteMeta('last_sync_remote_revision');
      await _deleteMetaWithPrefix('sync_target:');
      await _deleteMetaWithPrefix('sync_auto:');
      await settings.setSyncPaused(
        true,
        reason: '已恢复到 ${dataset['exportedAt'] ?? '历史备份'}，请确认如何处理远端数据',
      );
    });

    if (applyDeviceSettings) {
      await _applyDeviceSettings(dataset['deviceSettings']);
    }
    return RestoreOutcome(
      report: report,
      protectiveBackup: protective,
      clearedWords: clearedWords,
      clearedEvents: clearedEvents,
      syncPaused: true,
    );
  }

  /// Automatic backup: at most once per interval, only when the data actually
  /// changed, and never at the cost of the previous valid copy.
  Future<AutoBackupResult> autoBackupIfDue({DateTime? now}) async {
    final DateTime at = now ?? clock.now();
    if (!await settings.autoBackupEnabled()) {
      return const AutoBackupResult(skippedReason: '自动备份已关闭');
    }
    final DateTime? last = await settings.lastAutoBackupAt();
    final Duration interval = await settings.autoBackupInterval();
    if (last != null && at.difference(last) < interval) {
      return const AutoBackupResult(skippedReason: '未到检查时间');
    }
    final Map<String, Object?> dataset = await backup.buildDataset(now: at);
    final String hash = BackupService.contentHashOf(dataset);
    if (last != null && await settings.lastAutoBackupHash() == hash) {
      // Nothing changed: do not create a duplicate copy, but record the check so
      // the next one is a day away instead of a minute away.
      await settings.setLastAutoBackup(at, hash);
      return const AutoBackupResult(skippedReason: '数据没有变化');
    }
    try {
      final File file = await backup.writeBackupFile(
        directory: await directory(),
        now: at,
        label: BackupKind.automatic.slug,
      );
      await settings.setLastAutoBackup(at, hash);
      await prune(kind: BackupKind.automatic);
      return AutoBackupResult(file: file);
    } catch (e) {
      // Failure must not update the timestamp (so it retries) and must not
      // delete the previous copy (guaranteed by the atomic writer).
      return AutoBackupResult(error: '$e');
    }
  }

  /// Protective copy before a destructive operation. Throws on failure so the
  /// caller can abort the operation instead of proceeding unprotected.
  Future<File> createProtectiveBackup({required String reason}) async {
    final File file = await createBackup(kind: BackupKind.protective);
    final BackupInfo info = await inspect(file);
    if (!info.valid) {
      throw BackupException('保护性备份校验失败（$reason），已停止该操作：${info.problem}');
    }
    return file;
  }

  /// Convenience for UI code: returns null when the operation may proceed, or a
  /// user-facing reason when the protective copy could not be made.
  Future<String?> protectiveBackupFailure(String reason) async {
    try {
      await createProtectiveBackup(reason: reason);
      return null;
    } catch (e) {
      return '无法创建保护性备份（$reason），已取消该操作：$e';
    }
  }

  /// Housekeeping at start-up: remove temp files left by an interrupted write.
  Future<int> cleanupTempFiles() async =>
      BackupService.cleanupTempFiles(await directory());

  Future<int> _count(String table) async {
    final QueryRow row = await db
        .customSelect('SELECT COUNT(*) AS c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  Future<void> _clearAll() async {
    // Order matters only for readability; foreign keys cascade.
    await db.delete(db.reviewEvents).go();
    await db.delete(db.learningStates).go();
    await db.delete(db.wordTags).go();
    await db.delete(db.wordFavorites).go();
    await db.delete(db.wordBookEntries).go();
    await db.delete(db.userTags).go();
    await db.delete(db.words).go();
    await db.delete(db.wordBooks).go();
    await db.delete(db.syncAliases).go();
    await db.delete(db.contentVersions).go();
  }

  Future<void> _deleteMetaWithPrefix(String prefix) async {
    final List<AppMetaRow> rows = await db.select(db.appMeta).get();
    for (final AppMetaRow row in rows) {
      if (row.key.startsWith(prefix)) await db.deleteMeta(row.key);
    }
  }

  Future<void> _applyDeviceSettings(Object? raw) async {
    if (raw is! Map) return;
    final Map<String, Object?> values = Map<String, Object?>.from(raw);
    await settings.save(
      theme: _themeFrom(values['themeMode']),
      accentColor: values['accentColor'] is String
          ? values['accentColor'] as String
          : null,
      ttsVoice: values['ttsVoice'] is String
          ? values['ttsVoice'] as String
          : null,
      ttsLocale: values['ttsLocale'] is String
          ? values['ttsLocale'] as String
          : null,
      ttsRate: values['ttsRate'] is int ? values['ttsRate'] as int : null,
      ttsAutoSpeak: values['ttsAutoSpeak'] is bool
          ? values['ttsAutoSpeak'] as bool
          : null,
    );
    if (values['keepScreenOn'] is bool) {
      await db.writeMeta(
        'keep_screen_on',
        (values['keepScreenOn'] as bool) ? '1' : '0',
      );
    }
  }

  ThemePreference? _themeFrom(Object? value) {
    if (value is! String) return null;
    for (final ThemePreference preference in ThemePreference.values) {
      if (preference.code == value) return preference;
    }
    return null;
  }
}
