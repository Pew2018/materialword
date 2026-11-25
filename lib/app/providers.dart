import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/database/app_database.dart';
import '../l10n/l10n.dart';
import '../l10n/language_store.dart';
import '../core/models/study_models.dart';
import '../core/models/sprint_plan.dart';
import '../core/repositories/sprint_repository.dart';
import '../core/models/enums.dart';
import '../services/study_session.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/study_repository.dart';
import '../core/repositories/word_repository.dart';
import '../core/repositories/wordbook_repository.dart';
import '../core/repositories/word_metadata_repository.dart';
import '../core/time_utils.dart';
import '../services/backup_service.dart';
import '../services/backup_files.dart';
import '../services/backup_manager.dart';
import '../services/dictionary_service.dart';
import '../services/import_service.dart';
import '../services/word_intake_service.dart';
import '../services/sync/credential_store.dart';
import '../services/sync/github_sync_provider.dart';
import '../services/sync/local_file_sync_provider.dart';
import '../services/sync/sync_coordinator.dart';
import '../services/sync/auto_sync_service.dart';
import '../services/sync/conflict_resolution_service.dart';
import '../services/sync/conflict_store.dart';
import '../services/sync/sync_provider.dart';
import '../services/sync/webdav_sync_provider.dart';
import '../services/screen_awake.dart';
import '../services/tts_service.dart';
import 'theme.dart';

/// Overridden in `main()` (and in tests) with a real database.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>(
  (Ref ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final Provider<Clock> clockProvider = Provider<Clock>(
  (Ref ref) => const SystemClock(),
);

final Provider<WordRepository> wordRepositoryProvider =
    Provider<WordRepository>(
      (Ref ref) => WordRepository(ref.watch(databaseProvider)),
    );

final Provider<WordBookRepository> wordBookRepositoryProvider =
    Provider<WordBookRepository>(
      (Ref ref) => WordBookRepository(ref.watch(databaseProvider)),
    );

final wordMetadataRepositoryProvider = Provider<WordMetadataRepository>(
  (ref) => WordMetadataRepository(ref.watch(databaseProvider)),
);

final Provider<StudyRepository> studyRepositoryProvider =
    Provider<StudyRepository>(
      (Ref ref) => StudyRepository(ref.watch(databaseProvider)),
    );

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => SettingsRepository(ref.watch(databaseProvider)),
    );

final sprintRepositoryProvider = Provider<SprintRepository>(
  (ref) => SprintRepository(ref.watch(databaseProvider)),
);
final sprintPlanProvider = StreamProvider<SprintPlan>(
  (ref) => ref.watch(settingsRepositoryProvider).watchSprintPlan(),
);

final Provider<BackupService> backupServiceProvider = Provider<BackupService>(
  (Ref ref) => BackupService(
    db: ref.watch(databaseProvider),
    study: ref.watch(studyRepositoryProvider),
    words: ref.watch(wordRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
  ),
);

/// Transport used by sync providers built from the settings page.
///
/// `null` means "let the provider create its own client", which is the shipping
/// path. Tests override it with an in-memory or loopback client so the *page* —
/// not only the provider — can be driven end to end.
final Provider<http.Client?> syncHttpClientProvider = Provider<http.Client?>(
  (Ref ref) => null,
);

/// Recovery copies: creation, retention, automatic scheduling, protective
/// backups and both restore modes.
final backupManagerProvider = Provider<BackupManager>(
  (Ref ref) => BackupManager(
    db: ref.watch(databaseProvider),
    backup: ref.watch(backupServiceProvider),
    study: ref.watch(studyRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    directory: BackupPaths.appDirectory,
    clock: ref.watch(clockProvider),
  ),
);

final Provider<SyncConflictStore> syncConflictStoreProvider =
    Provider<SyncConflictStore>(
      (Ref ref) => SyncConflictStore(ref.watch(databaseProvider)),
    );

/// Turns a recorded conflict back into a normal local edit. Lives outside the
/// widget so every recoverable field is handled in one place.
final Provider<SyncConflictResolutionService> syncConflictResolutionProvider =
    Provider<SyncConflictResolutionService>(
      (Ref ref) => SyncConflictResolutionService(
        db: ref.watch(databaseProvider),
        words: ref.watch(wordRepositoryProvider),
        wordBooks: ref.watch(wordBookRepositoryProvider),
        intake: ref.watch(wordIntakeProvider),
        conflicts: ref.watch(syncConflictStoreProvider),
      ),
    );

/// Dictionary loading is lazy: the bundled SQLite file is only copied/opened the
/// first time a screen (or the quick-add flow) actually needs a lookup.
final FutureProvider<DictionaryService> dictionaryProvider =
    FutureProvider<DictionaryService>(
      (Ref ref) => DictionaryService.openBundled(),
    );

final Provider<ImportService> importServiceProvider = Provider<ImportService>((
  Ref ref,
) {
  final AsyncValue<DictionaryService> dictionary = ref.watch(
    dictionaryProvider,
  );
  return ImportService(
    words: ref.watch(wordRepositoryProvider),
    wordBooks: ref.watch(wordBookRepositoryProvider),
    dictionary: dictionary.value,
  );
});

/// The single write path for adding, re-adding and importing words.
final Provider<WordIntakeService> wordIntakeProvider =
    Provider<WordIntakeService>(
      (Ref ref) => WordIntakeService(
        db: ref.watch(databaseProvider),
        words: ref.watch(wordRepositoryProvider),
        wordBooks: ref.watch(wordBookRepositoryProvider),
      ),
    );

/// Device-local app language.
///
/// The default is an in-memory Chinese store so that widget tests (and any
/// caller that forgets to override it) behave exactly like the previous
/// Chinese-only build. `main()` overrides it with the value read from disk
/// before the first frame.
final Provider<LanguageStore> languageStoreProvider = Provider<LanguageStore>(
  (Ref ref) => MemoryLanguageStore(AppLanguage.zh),
);

/// Currently displayed language.
///
/// Only `MaterialApp.locale` changes on switch: no route is rebuilt, no data
/// provider is invalidated, and the running study session is untouched.
class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => ref.watch(languageStoreProvider).current;

  Future<void> select(AppLanguage language) async {
    if (state == language) return;
    state = language;
    await ref.read(languageStoreProvider).write(language);
  }
}

final NotifierProvider<LanguageController, AppLanguage> languageProvider =
    NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);

final StreamProvider<StudySettingsRow> settingsProvider =
    StreamProvider<StudySettingsRow>(
      (Ref ref) => ref.watch(settingsRepositoryProvider).watch(),
    );

/// The book currently selected for studying, or null meaning "all books".
final Provider<String?> activeBookIdProvider = Provider<String?>((Ref ref) {
  return ref.watch(settingsProvider).value?.currentWordBookId;
});

/// Accent colour of the current theme. Rebuilt whenever the setting changes, so
/// switching colours is instantaneous — no restart, and no state is lost
/// because only the [ThemeData] changes.
final Provider<Color> accentColorProvider = Provider<Color>((Ref ref) {
  return parseAccent(ref.watch(settingsProvider).value?.accentColor);
});

final FutureProvider<TodayProgress> todayProgressProvider =
    FutureProvider<TodayProgress>((Ref ref) async {
      final StudySettingsRow settings = await ref
          .watch(settingsRepositoryProvider)
          .load();
      return ref
          .watch(studyRepositoryProvider)
          .todayProgress(
            now: ref.watch(clockProvider).now(),
            newTarget: settings.dailyNewTarget,
            reviewLimit: settings.dailyReviewLimit,
            bookId: settings.currentWordBookId,
          );
    });

final StreamProvider<List<WordBookSummary>> bookSummariesProvider =
    StreamProvider<List<WordBookSummary>>((Ref ref) {
      return ref
          .watch(wordBookRepositoryProvider)
          .watchSummaries(now: ref.watch(clockProvider).now());
    });

/// Statistics honour the explicit scope filter: `null` = every book.
class StatisticsBookFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? bookId) => state = bookId;
}

final NotifierProvider<StatisticsBookFilter, String?>
statisticsBookFilterProvider = NotifierProvider<StatisticsBookFilter, String?>(
  StatisticsBookFilter.new,
);

final FutureProvider<StudyStatistics> statisticsProvider =
    FutureProvider<StudyStatistics>((Ref ref) async {
      return ref
          .watch(studyRepositoryProvider)
          .statistics(
            now: ref.watch(clockProvider).now(),
            bookId: ref.watch(statisticsBookFilterProvider),
          );
    });

final Provider<TtsService> ttsServiceProvider = Provider<TtsService>(
  (Ref ref) => TtsService(),
);

final Provider<ScreenAwakeService> screenAwakeProvider =
    Provider<ScreenAwakeService>((Ref ref) => ScreenAwakeService());

/// Device-local "keep the screen on while studying" switch.
///
/// Stored in `app_meta`, deliberately not in `study_settings`: the preference is
/// about this screen, not about the learning plan, so it must never be synced.
final FutureProvider<bool> keepScreenOnProvider = FutureProvider<bool>((
  Ref ref,
) async {
  final AppDatabase db = ref.watch(databaseProvider);
  final String? value = await db.readMeta(ScreenAwakeService.preferenceKey);
  return value == '1';
});

final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  final service = AutoSyncService(
    db: ref.watch(databaseProvider),
    coordinator: ref.watch(syncCoordinatorProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final Provider<CredentialStore> credentialStoreProvider =
    Provider<CredentialStore>((Ref ref) => SecureCredentialStore());

/// All sync providers that can be configured. Only one is active at a time.
final Provider<SyncCoordinator> syncCoordinatorProvider =
    Provider<SyncCoordinator>(
      (Ref ref) => SyncCoordinator(
        db: ref.watch(databaseProvider),
        backup: ref.watch(backupServiceProvider),
        study: ref.watch(studyRepositoryProvider),
        settings: ref.watch(settingsRepositoryProvider),
        credentials: ref.watch(credentialStoreProvider),
        clock: ref.watch(clockProvider),
      ),
    );

/// The provider for a stored config, used by the sync page and the auto-sync
/// hooks. Returns null when sync is switched off.
SyncProvider? providerForConfig(
  Map<String, Object?>? config, {
  CredentialStore? credentials,
}) {
  if (config == null) return null;
  final String id = (config['provider'] as String?) ?? 'none';
  switch (id) {
    case 'local-file':
      final String path = (config['path'] as String?) ?? '';
      return LocalFileSyncProvider(filePath: path);
    case 'github':
      return GitHubSyncProvider.fromConfig(config, credentials: credentials);
    case 'webdav':
      return WebDavSyncProvider.fromConfig(config, credentials: credentials);
    default:
      return null;
  }
}

/// Backwards-compatible helper kept for tests and the backup page.
List<SyncProvider> buildSyncProviders(String localFilePath) => <SyncProvider>[
  LocalFileSyncProvider(filePath: localFilePath),
  GitHubSyncProvider.placeholder(),
  WebDavSyncProvider.placeholder(),
];

/// Read only two small metadata rows, not vocabulary or review history.
final pausedSessionProvider = StreamProvider<PausedStudySession?>((ref) {
  final db = ref.watch(databaseProvider);
  final clock = ref.watch(clockProvider);
  return (db.select(db.appMeta)..where(
        (t) => t.key.isIn([
          StudySession.persistenceKey,
          SettingsRepository.sharedVersionKey,
        ]),
      ))
      .watch()
      .map((rows) {
        final values = {for (final row in rows) row.key: row.value};
        final raw = values[StudySession.persistenceKey];
        if (raw == null) return null;
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final now = clock.now().toLocal();
          if (data['version'] != 1 ||
              data['day'] != '${now.year}-${now.month}-${now.day}') {
            return null;
          }
          final current = jsonDecode(
            values[SettingsRepository.sharedVersionKey] ??
                '{"counter":0,"deviceId":""}',
          ) as Map;
          final planned = jsonDecode(data['planVersion'] as String) as Map;
          if (current['counter'] != planned['counter'] ||
              current['deviceId'] != planned['deviceId']) {
            return null;
          }
          final cursor = data['cursor'] as int,
              total = (data['queue'] as List).length;
          if (cursor < 0 || cursor >= total) return null;
          return PausedStudySession(
            bookId: data['bookId'] as String?,
            mode: StudyMode.fromCode(data['mode'] as String),
            special: SpecialReview.fromCode(data['special'] as String),
            position: cursor,
            total: total,
          );
        } catch (_) {
          return null;
        }
      });
});
