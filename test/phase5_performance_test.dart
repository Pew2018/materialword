import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/backup_manager.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/word_intake_service.dart';
import 'package:materialword/services/import_service.dart';
import 'package:materialword/services/wordbook_export.dart';

import 'helpers/test_env.dart';

/// Phase 5G: file-backed SQLite benchmarks plus the "batched merge == per-row
/// merge" equivalence proof.
///
/// These numbers come from **debug + file SQLite on this machine**. They are
/// not release or device figures; the report labels them accordingly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seed(
    TestEnv env, {
    required int words,
    required int events,
  }) async {
    final DateTime now = env.clock.now();
    final WordBook book = await env.books.create(name: '基准', now: now);
    final int millis = now.millisecondsSinceEpoch;
    final List<WordsCompanion> wordRows = <WordsCompanion>[
      for (int i = 0; i < words; i++)
        WordsCompanion.insert(
          id: 'w$i',
          word: 'word$i',
          normalized: 'word$i',
          translation: Value<String>('释义 $i'),
          definition: Value<String>('definition $i'),
          createdAt: millis,
          updatedAt: millis,
        ),
    ];
    await env.db.batch(
      (Batch batch) => batch.insertAll(env.db.words, wordRows),
    );
    await env.db.batch(
      (Batch batch) =>
          batch.insertAll(env.db.wordBookEntries, <WordBookEntriesCompanion>[
            for (int i = 0; i < words; i++)
              WordBookEntriesCompanion.insert(
                wordBookId: book.id,
                wordId: 'w$i',
                addedAt: millis,
                version: const Value<int>(1),
                updatedAt: Value<int>(millis),
              ),
          ]),
    );
    // `events` answers spread over the words, each with a unique causal order.
    final List<ReviewEventsCompanion> eventRows = <ReviewEventsCompanion>[
      for (int i = 0; i < events; i++)
        ReviewEventsCompanion.insert(
          id: 'e$i',
          wordId: 'w${i % words}',
          deviceId: 'bench',
          answeredAt: millis + i,
          localDay: '2026-11-24',
          result: 2,
          type: i.isEven ? 'study' : 'review',
          causalOrder: Value<int>(i + 1),
          dayStartUtc: Value<int?>(millis - millis % 86400000),
          dayStartSource: const Value<String>('authored'),
        ),
    ];
    for (int start = 0; start < eventRows.length; start += 5000) {
      final int end = (start + 5000).clamp(0, eventRows.length);
      await env.db.batch(
        (Batch batch) =>
            batch.insertAll(env.db.reviewEvents, eventRows.sublist(start, end)),
      );
    }
    await env.study.rebuildStatesForWords(<String>[
      for (int i = 0; i < words; i++) 'w$i',
    ]);
  }

  Future<Map<String, int>> measure(TestEnv env, {required String label}) async {
    final Map<String, int> timings = <String, int>{};
    Future<void> time(String name, Future<void> Function() action) async {
      final Stopwatch watch = Stopwatch()..start();
      await action();
      timings[name] = watch.elapsedMilliseconds;
    }

    await time('add', () async {
      await env.intake.add(
        const WordIntakeRequest(text: 'benchmarkword'),
        now: env.clock.now(),
      );
    });
    await time('import500', () async {
      final ImportService service = env.importService();
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < 500; i++) {
        buffer.writeln('imported$i');
      }
      await service.commit(
        preview: service.parseContent(
          buffer.toString(),
          format: 'txt',
          name: 'i.txt',
        ),
        newBookName: '导入基准',
        now: env.clock.now(),
      );
    });
    await time('search', () async {
      await env.words.listWords(query: 'word1', limit: 200);
    });
    await time('exportJson', () async {
      final WordBookExportFormat format = WordBookExportFormat.json;
      final List<WordBook> books = await env.books.listBooks();
      WordBookExporter.encodeBook(
        WordBookExport(
          book: books.first,
          words: await env.books.wordsInBook(books.first.id),
        ),
        format,
        exportedAt: env.clock.now(),
      );
    });
    File? backupFile;
    await time('backup', () async {
      backupFile = await env.backups.createBackup();
    });
    await time('verify', () async {
      final BackupInfo info = await env.backups.inspect(backupFile!);
      expect(info.valid, isTrue);
    });
    await time('merge', () async {
      // Re-merging the snapshot is the "no new data" path, which still has to
      // walk every word and event.
      final Map<String, Object?> dataset = await env.backup.readDataset(
        backupFile!.path,
      );
      await env.backup.mergeDataset(dataset, now: env.clock.now());
    });
    await time('replay', () async {
      await env.study.rebuildStatesForWords(<String>[
        for (int i = 0; i < 200; i++) 'w$i',
      ]);
    });
    // ignore: avoid_print
    print(
      'MW_BENCH $label ${timings.entries.map((e) => '${e.key}=${e.value}ms').join(' ')}',
    );
    return timings;
  }

  test('PERF01 1k 词 / 10k 事件（文件型数据库）', () async {
    final TestEnv env = await TestEnv.create(file: true);
    addTearDown(env.dispose);
    await seed(env, words: 1000, events: 10000);
    final Map<String, int> timings = await measure(env, label: '1k/10k');
    expect(timings['search'], lessThan(2000));
    expect(await env.words.countWords(), greaterThanOrEqualTo(1000));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('PERF02 5k 词 / 30k 事件（文件型数据库）', () async {
    final TestEnv env = await TestEnv.create(file: true);
    addTearDown(env.dispose);
    await seed(env, words: 5000, events: 30000);
    final Map<String, int> timings = await measure(env, label: '5k/30k');
    expect(timings['merge'], lessThan(120000));
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('PERF03 冷启动与热启动（同一文件重新打开）', () async {
    final TestEnv env = await TestEnv.create(file: true);
    await seed(env, words: 1000, events: 10000);
    final String path = env.filePath!;

    final Stopwatch cold = Stopwatch()..start();
    final AppDatabase reopened = AppDatabase(NativeDatabase(File(path)));
    final int count = await reopened
        .customSelect('SELECT COUNT(*) AS c FROM words')
        .getSingle()
        .then((QueryRow row) => row.read<int>('c'));
    cold.stop();
    expect(count, 1000);

    final Stopwatch warm = Stopwatch()..start();
    await reopened.customSelect('SELECT COUNT(*) AS c FROM words').getSingle();
    warm.stop();
    // ignore: avoid_print
    print(
      'MW_BENCH coldStart=${cold.elapsedMilliseconds}ms warmQuery=${warm.elapsedMilliseconds}ms',
    );
    await reopened.close();
    await env.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('PERF04 批量合并与逐词合并逐字段等价', () async {
    final TestEnv source = await TestEnv.create();
    final TestEnv batched = await TestEnv.create();
    final TestEnv legacy = await TestEnv.create();
    addTearDown(source.dispose);
    addTearDown(batched.dispose);
    addTearDown(legacy.dispose);

    final WordBook book = await source.seedBook(
      words: <String>['alpha', 'beta', 'gamma'],
    );
    final Word alpha = (await source.words.byNormalized('alpha'))!;
    await source.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(translation: '改过的释义', note: '笔记'),
      ),
      now: source.clock.now(),
    );
    final Word beta = (await source.words.byNormalized('beta'))!;
    await source.words.softDelete(beta.id, now: source.clock.now());
    await source.intake.add(
      const WordIntakeRequest(text: 'delta'),
      bookId: book.id,
      now: source.clock.now(),
    );
    await source.study.recordAnswer(
      wordId: alpha.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'evt-bench',
      deviceId: 'dev',
      now: source.clock.now(),
    );
    final Map<String, Object?> dataset = await source.backup.buildDataset(
      now: source.clock.now(),
    );

    // A pre-existing local state that overlaps the incoming dataset: the merge
    // must combine, not just insert. It is created once and copied into both
    // databases so that locally generated ids are identical and the comparison
    // is about merge behaviour, not about random UUIDs.
    final TestEnv base = await TestEnv.create();
    addTearDown(base.dispose);
    await base.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(translation: '本机释义'),
      ),
      now: base.clock.now(),
    );
    await base.intake.add(
      const WordIntakeRequest(text: 'epsilon'),
      now: base.clock.now(),
    );
    final Map<String, Object?> baseDataset = await base.backup.buildDataset(
      now: base.clock.now(),
    );
    for (final TestEnv env in <TestEnv>[batched, legacy]) {
      await env.backup.mergeDataset(baseDataset, now: env.clock.now());
    }

    final MergeReport batchedReport = await batched.backup.mergeDataset(
      dataset,
      now: batched.clock.now(),
    );
    final MergeReport legacyReport = await legacy.backup.mergeDataset(
      dataset,
      now: legacy.clock.now(),
      legacyWordMerge: true,
    );
    expect(batchedReport.newWords, legacyReport.newWords);
    expect(batchedReport.updatedWords, legacyReport.updatedWords);
    expect(batchedReport.deletedWords, legacyReport.deletedWords);
    expect(batchedReport.newEntries, legacyReport.newEntries);
    expect(batchedReport.addedEvents, legacyReport.addedEvents);
    expect(batchedReport.conflicts, legacyReport.conflicts);

    final Map<String, Object?> batchedData = await batched.backup.buildDataset(
      now: batched.clock.now(),
    );
    final Map<String, Object?> legacyData = await legacy.backup.buildDataset(
      now: legacy.clock.now(),
    );
    // Volatile fields differ by device/time; everything else must match.
    for (final String key in <String>['exportedAt', 'deviceId', 'datasetId']) {
      batchedData.remove(key);
      legacyData.remove(key);
    }
    expect(
      BackupService.contentHashOf(batchedData),
      BackupService.contentHashOf(legacyData),
    );
    expect(
      batchedContent(batchedData),
      batchedContent(legacyData),
      reason: '逐字段等价：词条、关联、事件、版本与别名',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('PERF06 同一数据集：逐词合并 vs 批量合并耗时', () async {
    final TestEnv seedEnv = await TestEnv.create(file: true);
    await seed(seedEnv, words: 5000, events: 30000);
    final Map<String, Object?> dataset = await seedEnv.backup.buildDataset(
      now: seedEnv.clock.now(),
    );
    await seedEnv.dispose();

    Future<int> run({required bool legacy}) async {
      final TestEnv env = await TestEnv.create(file: true);
      try {
        // Same number of pre-existing words on both sides, so the merge has to
        // resolve identities instead of plainly inserting.
        final List<dynamic> localWords = (dataset['words'] as List<dynamic>)
            .take(2000)
            .toList();
        final Set<String> localIds = <String>{
          for (final dynamic row in localWords)
            (row as Map<String, dynamic>)['id'] as String,
        };
        final Map<String, Object?> local = <String, Object?>{
          ...dataset,
          'words': localWords,
          'entries': <Object?>[
            for (final dynamic entry in (dataset['entries'] as List<dynamic>))
              if (localIds.contains(
                (entry as Map<String, dynamic>)['wordId'] as String,
              ))
                entry,
          ],
          'reviewEvents': const <Object?>[],
        };
        await env.backup.mergeDataset(local, now: env.clock.now());
        final Stopwatch watch = Stopwatch()..start();
        await env.backup.mergeDataset(
          dataset,
          now: env.clock.now(),
          legacyWordMerge: legacy,
        );
        watch.stop();
        return watch.elapsedMilliseconds;
      } finally {
        await env.dispose();
      }
    }

    final int legacyMs = await run(legacy: true);
    final int batchedMs = await run(legacy: false);
    // ignore: avoid_print
    print(
      'MW_BENCH mergeWordPhase legacy=${legacyMs}ms batched=${batchedMs}ms '
      'speedup=${(legacyMs / batchedMs).toStringAsFixed(2)}x',
    );
    expect(batchedMs, lessThan(legacyMs));
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('PERF05 20k 词 / 100k 事件（需 MW_BENCH_FULL=1）', () async {
    if (Platform.environment['MW_BENCH_FULL'] != '1') {
      // ignore: avoid_print
      print('MW_BENCH skipped 20k/100k (set MW_BENCH_FULL=1 to run)');
      return;
    }
    final TestEnv env = await TestEnv.create(file: true);
    addTearDown(env.dispose);
    await seed(env, words: 20000, events: 100000);
    final Map<String, int> timings = await measure(env, label: '20k/100k');
    expect(timings['merge'], lessThan(300000));
  }, timeout: const Timeout(Duration(minutes: 20)));
}

/// Canonical, id-free view of the data used for the equivalence assertion.
String batchedContent(Map<String, Object?> dataset) {
  Object? canonical(Object? value) {
    if (value is Map) {
      final List<String> keys = value.keys.cast<String>().toList()..sort();
      return <String, Object?>{
        for (final String k in keys) k: canonical(value[k]),
      };
    }
    if (value is List) {
      final List<Object?> rows = value.map(canonical).toList();
      rows.sort((Object? a, Object? b) => '$a'.compareTo('$b'));
      return rows;
    }
    return value;
  }

  return '${canonical(<String, Object?>{
    for (final String key in <String>['words', 'wordBooks', 'entries', 'reviewEvents', 'favorites', 'tags', 'wordTags', 'settings']) key: dataset[key],
  })}';
}
