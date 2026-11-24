import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/models/study_models.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/study_repository.dart';
import '../core/repositories/word_repository.dart';
import '../core/repositories/wordbook_repository.dart';
import '../core/time_utils.dart';
import '../services/backup_service.dart';
import '../services/dictionary_service.dart';
import '../services/import_service.dart';
import '../services/sync/local_file_sync_provider.dart';
import '../services/sync/sync_provider.dart';

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

final Provider<StudyRepository> studyRepositoryProvider =
    Provider<StudyRepository>(
      (Ref ref) => StudyRepository(ref.watch(databaseProvider)),
    );

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => SettingsRepository(ref.watch(databaseProvider)),
    );

final Provider<BackupService> backupServiceProvider = Provider<BackupService>(
  (Ref ref) => BackupService(
    db: ref.watch(databaseProvider),
    study: ref.watch(studyRepositoryProvider),
    words: ref.watch(wordRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
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

final StreamProvider<StudySettingsRow> settingsProvider =
    StreamProvider<StudySettingsRow>(
      (Ref ref) => ref.watch(settingsRepositoryProvider).watch(),
    );

/// The book currently selected for studying, or null meaning "all books".
final Provider<String?> activeBookIdProvider = Provider<String?>((Ref ref) {
  return ref.watch(settingsProvider).value?.currentWordBookId;
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

final FutureProvider<StudyStatistics> statisticsProvider =
    FutureProvider<StudyStatistics>((Ref ref) async {
      return ref
          .watch(studyRepositoryProvider)
          .statistics(
            now: ref.watch(clockProvider).now(),
            bookId: ref.watch(activeBookIdProvider),
          );
    });

/// Sync providers shown in the backup screen. Only the local file provider is
/// usable in phase 1; the other two are listed but clearly marked as planned.
List<SyncProvider> buildSyncProviders(String localFilePath) => <SyncProvider>[
  LocalFileSyncProvider(filePath: localFilePath),
  const GitHubSyncProvider(),
  const WebDavSyncProvider(),
];
