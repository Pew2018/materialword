import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:drift/native.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/repositories/settings_repository.dart';
import 'package:materialword/core/repositories/study_repository.dart';
import 'package:materialword/core/repositories/word_repository.dart';
import 'package:materialword/core/repositories/wordbook_repository.dart';
import 'package:materialword/core/repositories/word_metadata_repository.dart';
import 'package:materialword/core/time_utils.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/backup_manager.dart';
import 'package:materialword/services/import_service.dart';
import 'package:materialword/services/study_session.dart';
import 'package:materialword/services/sync/conflict_resolution_service.dart';
import 'package:materialword/services/sync/conflict_store.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/word_intake_service.dart';
import 'package:materialword/services/dictionary_service.dart';

/// Deterministic clock: tests decide exactly what "now" is.
class FixedClock extends Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value;

  void advance(Duration duration) => _now = _now.add(duration);

  void nextDay({int days = 1}) {
    _now = DateTime(_now.year, _now.month, _now.day + days, 9);
  }
}

/// One in-memory database with every service wired up, mirroring the app.
class TestEnv {
  TestEnv._(this.db, this.clock, {this.filePath});

  final AppDatabase db;
  final FixedClock clock;
  final String? filePath;

  late final WordRepository words = WordRepository(db);
  late final WordBookRepository books = WordBookRepository(db);
  late final StudyRepository study = StudyRepository(db);
  late final SettingsRepository settings = SettingsRepository(db);
  late final WordMetadataRepository metadata = WordMetadataRepository(db);
  late final WordIntakeService intake = WordIntakeService(
    db: db,
    words: words,
    wordBooks: books,
  );
  late final BackupService backup = BackupService(
    db: db,
    study: study,
    words: words,
    settings: settings,
  );

  /// Recovery copies live in a per-test directory, never in the user's home.
  late final Directory backupDirectory = Directory.systemTemp.createTempSync(
    'mw_backups',
  );

  late final BackupManager backups = BackupManager(
    db: db,
    backup: backup,
    study: study,
    settings: settings,
    directory: () async => backupDirectory,
    clock: clock,
  );

  /// Secrets for tests: real code paths read them, nothing touches the
  /// platform keychain.
  late final InMemoryCredentialStore credentials = InMemoryCredentialStore();

  late final SyncCoordinator coordinator = SyncCoordinator(
    db: db,
    backup: backup,
    study: study,
    settings: settings,
    credentials: credentials,
    clock: clock,
    httpClient: httpClient,
  );

  /// Set before the first use of [coordinator] when a test needs a client that
  /// trusts a loopback TLS certificate.
  http.Client? httpClient;

  late final SyncConflictStore conflicts = SyncConflictStore(db);

  late final SyncConflictResolutionService conflictResolution =
      SyncConflictResolutionService(
        db: db,
        words: words,
        wordBooks: books,
        intake: intake,
        conflicts: conflicts,
      );

  ImportService importService({
    bool withDictionary = false,
    DictionaryService? dictionary,
  }) => ImportService(
    words: words,
    wordBooks: books,
    dictionary: dictionary ?? (withDictionary ? null : null),
  );

  StudySession session() => StudySession(study, settings, clock);

  static Future<TestEnv> create({DateTime? now, bool file = false}) async {
    final DateTime start = now ?? DateTime(2026, 11, 24, 9);
    final String? path;
    final QueryExecutor executor;
    if (file) {
      final Directory dir = Directory.systemTemp.createTempSync(
        'materialword_test',
      );
      path = '${dir.path}/test.sqlite';
      executor = NativeDatabase(File(path));
    } else {
      path = null;
      executor = NativeDatabase.memory();
    }
    final AppDatabase db = AppDatabase(executor);
    // Touch the schema so migrations/PRAGMA setup run before assertions.
    await db.customSelect('SELECT 1').get();
    return TestEnv._(db, FixedClock(start), filePath: path);
  }

  /// Adds [count] words (alpha, beta, …) to a fresh book and returns them.
  Future<WordBook> seedBook({
    String name = '测试词书',
    List<String> words = const <String>['alpha', 'beta', 'gamma'],
  }) async {
    final WordBook book = await books.create(name: name, now: clock.now());
    for (final String text in words) {
      final Word word = await this.words.ensureWord(
        text: text,
        translation: '释义 $text',
        now: clock.now(),
      );
      await books.addWords(book.id, <String>[word.id], now: clock.now());
    }
    return book;
  }

  Future<void> dispose() async {
    await db.close();
    if (backupDirectory.existsSync()) {
      try {
        backupDirectory.deleteSync(recursive: true);
      } catch (_) {
        // A test may have made the directory read-only on purpose.
      }
    }
    if (filePath != null) {
      final Directory dir = Directory(filePath!).parent;
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  }
}
