import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/models/study_models.dart';
import 'package:materialword/services/backup_service.dart';

import 'helpers/test_env.dart';

/// Phase 4D: where the merge/replay time actually goes, and whether batching
/// changed any result.
///
/// This is a *debug, in-memory SQLite, single-machine* measurement. The numbers
/// are comparable between runs of this file on the same machine and nothing
/// more; they are not a Release or on-device benchmark.
void main() {
  Future<TestEnv> seed(int words, int events) async {
    final TestEnv env = await TestEnv.create();
    final DateTime time = env.clock.now();
    final int base = time.millisecondsSinceEpoch;
    await env.db.transaction(() async {
      await env.db.batch(
        (batch) => batch.insertAll(env.db.words, <WordsCompanion>[
          for (int i = 0; i < words; i++)
            WordsCompanion.insert(
              id: 'word-$i',
              word: 'synthetic$i',
              normalized: 'synthetic$i',
              translation: Value('释义 $i'),
              createdAt: base,
              updatedAt: base,
            ),
        ]),
      );
      for (int start = 0; start < events; start += 5000) {
        await env.db.batch(
          (batch) =>
              batch.insertAll(env.db.reviewEvents, <ReviewEventsCompanion>[
                for (
                  int offset = 0;
                  offset < 5000 && start + offset < events;
                  offset++
                )
                  ReviewEventsCompanion.insert(
                    id: 'event-${start + offset}',
                    wordId: 'word-${(start + offset) % words}',
                    deviceId: 'synthetic-device',
                    answeredAt: base + start + offset,
                    localDay: '2026-11-24',
                    result: (start + offset) % 3,
                    type: 'review',
                  ),
              ]),
        );
      }
    });
    return env;
  }

  test('SEGMENTED 20000 words / 100000 events', () async {
    final TestEnv source = await seed(20000, 100000);
    final TestEnv target = await TestEnv.create();
    addTearDown(source.dispose);
    addTearDown(target.dispose);
    final DateTime time = source.clock.now();

    final Map<String, Object?> dataset = await source.backup.buildDataset(
      now: time,
    );
    final Map<String, double> phases = <String, double>{};
    final Stopwatch total = Stopwatch()..start();
    final MergeReport report = await target.backup.mergeDataset(
      dataset,
      now: time,
      onPhase: (String name, Duration elapsed) {
        phases[name] = (phases[name] ?? 0) + elapsed.inMicroseconds / 1000;
      },
    );
    total.stop();
    expect(report.addedEvents, 100000);
    expect(report.newWords, 20000);
    expect(report.rebuiltStates, 20000);

    final Map<String, Object?> out = <String, Object?>{
      ...phases,
      'total_ms': total.elapsedMicroseconds / 1000,
      'datasetWords': 20000,
      'datasetEvents': 100000,
    };
    stdout.writeln('MATERIALWORD_SEGMENTS ${jsonEncode(out)}');
    final String? destination = Platform.environment['MW_SEGMENTS_OUTPUT'];
    if (destination != null) {
      await File(destination)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(out));
    }
  }, timeout: const Timeout(Duration(minutes: 6)));

  test('batched replay writes exactly what the per-word path writes', () async {
    // Same log, two databases: one rebuilt word by word, one in batches. Any
    // difference would mean the optimisation changed a learning state.
    final TestEnv perWord = await seed(120, 600);
    final TestEnv batched = await TestEnv.create();
    addTearDown(perWord.dispose);
    addTearDown(batched.dispose);
    final DateTime time = perWord.clock.now();
    final Map<String, Object?> dataset = await perWord.backup.buildDataset(
      now: time,
    );
    await batched.backup.mergeDataset(dataset, now: time);

    final List<String> ids = <String>[for (int i = 0; i < 120; i++) 'word-$i'];
    final Map<String, List<int?>> batchedRows = <String, List<int?>>{
      for (final LearningState row
          in await batched.db.select(batched.db.learningStates).get())
        row.wordId: <int?>[
          row.stage,
          row.correctCount,
          row.hazyCount,
          row.wrongCount,
          row.streak,
          row.intervalDays,
          row.lastStudiedAt,
          row.nextReviewAt,
        ],
    };

    // Recompute every word with the single-word entry point.
    for (final String id in ids) {
      await batched.study.rebuildStateFromEvents(id);
    }
    final Map<String, List<int?>> perWordRows = <String, List<int?>>{
      for (final LearningState row
          in await batched.db.select(batched.db.learningStates).get())
        row.wordId: <int?>[
          row.stage,
          row.correctCount,
          row.hazyCount,
          row.wrongCount,
          row.streak,
          row.intervalDays,
          row.lastStudiedAt,
          row.nextReviewAt,
        ],
    };
    expect(perWordRows, batchedRows);
    expect(perWordRows, hasLength(120));
  });

  test(
    'a second import of the same dataset adds nothing and changes nothing',
    () async {
      final TestEnv source = await seed(200, 1000);
      final TestEnv target = await TestEnv.create();
      addTearDown(source.dispose);
      addTearDown(target.dispose);
      final DateTime time = source.clock.now();
      final Map<String, Object?> dataset = await source.backup.buildDataset(
        now: time,
      );
      final MergeReport first = await target.backup.mergeDataset(
        dataset,
        now: time,
      );
      expect(first.addedEvents, 1000);
      final Map<String, String> before = await _stateFingerprint(target);

      final MergeReport second = await target.backup.mergeDataset(
        dataset,
        now: time,
      );
      expect(second.addedEvents, 0);
      expect(second.duplicateEvents, 1000);
      expect(second.rebuiltStates, 0);
      expect(await _stateFingerprint(target), before);
      expect(
        await (target.db.select(target.db.reviewEvents).get()),
        hasLength(1000),
      );
    },
  );

  test(
    'a duplicate id inside one dataset is rejected before any write',
    () async {
      final TestEnv source = await seed(1, 1);
      final TestEnv target = await TestEnv.create();
      addTearDown(source.dispose);
      addTearDown(target.dispose);
      final DateTime time = source.clock.now();
      final Map<String, Object?> dataset = await source.backup.buildDataset(
        now: time,
      );
      final List<Object?> events = <Object?>[
        ...(dataset['reviewEvents']! as List<Object?>),
      ];
      // The same event twice in one payload: a hostile or broken client. The
      // validator rejects the whole document, so nothing is written at all —
      // strictly safer than de-duplicating it during the merge.
      final Map<String, Object?> withDuplicate = <String, Object?>{
        ...dataset,
        'reviewEvents': <Object?>[...events, events.first],
      };
      await expectLater(
        target.backup.mergeDataset(withDuplicate, now: time),
        throwsA(isA<BackupException>()),
      );
      expect(await target.db.select(target.db.reviewEvents).get(), isEmpty);
      expect(await target.db.select(target.db.words).get(), isEmpty);
    },
  );

  test('practice answers and their undo replay like any other event', () async {
    final TestEnv source = await TestEnv.create();
    final TestEnv target = await TestEnv.create();
    addTearDown(source.dispose);
    addTearDown(target.dispose);
    final WordBook book = await source.seedBook(words: <String>['alpha']);
    final Word word = (await source.books.wordsInBook(book.id)).single;
    final DateTime now = source.clock.now();

    await source.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'study-1',
      deviceId: 'device-a',
      now: now,
    );
    final AnswerRecord practice = await source.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.unknown,
      type: ReviewType.review,
      eventId: 'practice-1',
      deviceId: 'device-a',
      now: now.add(const Duration(minutes: 1)),
      mode: ReviewEventMode.forPractice(PracticeKind.spelling),
    );
    final LearningState afterPractice = (await source.study.managedWord(
      word.id,
    ))!.state!;
    expect(afterPractice.wrongCount, 1);
    // A drill never moves the ladder.
    expect(afterPractice.stage, StudyStage.learning.code);

    await source.study.undoAnswer(
      eventId: practice.eventId,
      undoId: 'undo-1',
      deviceId: 'device-a',
      now: now.add(const Duration(minutes: 2)),
    );

    final Map<String, Object?> dataset = await source.backup.buildDataset(
      now: now,
    );
    await target.backup.mergeDataset(dataset, now: now);
    final LearningState merged = (await target.study.managedWord(word.id))!
        .state!;
    final LearningState original = (await source.study.managedWord(word.id))!
        .state!;
    expect(merged.stage, original.stage);
    expect(merged.intervalDays, original.intervalDays);
    expect(merged.nextReviewAt, original.nextReviewAt);
    expect(merged.wrongCount, 0, reason: 'the undo removed the drill failure');
  });
}

Future<Map<String, String>> _stateFingerprint(TestEnv env) async {
  final List<LearningState> rows = await env.db
      .select(env.db.learningStates)
      .get();
  return <String, String>{
    for (final LearningState row in rows)
      row.wordId:
          '${row.stage}/${row.correctCount}/${row.hazyCount}/${row.wrongCount}'
          '/${row.streak}/${row.intervalDays}/${row.lastStudiedAt}'
          '/${row.nextReviewAt}',
  };
}
