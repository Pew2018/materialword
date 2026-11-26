import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';

import 'helpers/test_env.dart';

void main() {
  test('PERF synthetic 20000 words and 100000 learning events', () async {
    final measurements = <String, num>{};
    Future<T> measure<T>(String name, Future<T> Function() operation) async {
      final timer = Stopwatch()..start();
      final result = await operation();
      measurements[name] = timer.elapsedMicroseconds / 1000;
      return result;
    }

    final a = await measure('open_ms', TestEnv.create);
    final b = await TestEnv.create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final time = a.clock.now();
    final base = time.millisecondsSinceEpoch;
    await measure(
      'seed_ms',
      () => a.db.transaction(() async {
        await a.db.batch(
          (batch) => batch.insertAll(
            a.db.words,
            List.generate(
              20000,
              (i) => WordsCompanion.insert(
                id: 'word-$i',
                word: 'synthetic$i',
                normalized: 'synthetic$i',
                createdAt: base,
                updatedAt: base,
              ),
            ),
          ),
        );
        for (int start = 0; start < 100000; start += 5000) {
          await a.db.batch(
            (batch) => batch.insertAll(
              a.db.reviewEvents,
              List.generate(5000, (offset) {
                final i = start + offset;
                return ReviewEventsCompanion.insert(
                  id: 'event-$i',
                  wordId: 'word-${i % 20000}',
                  deviceId: 'synthetic-device',
                  answeredAt: base + i,
                  localDay: '2026-11-24',
                  result: i % 3,
                  type: 'review',
                );
              }),
            ),
          );
        }
      }),
    );
    await a.study.rebuildStatesForWords([
      for (var i = 0; i < 20000; i++) 'word-$i',
    ]);
    final found = await measure(
      'search_ms',
      () => a.study.managedWords(search: 'synthetic19999'),
    );
    expect(found, hasLength(1));
    final firstPage = await measure(
      'page_ms',
      () => a.study.managedWords(limit: 100),
    );
    expect(firstPage, hasLength(100));
    final ids = await measure(
      'select_filtered_ids_ms',
      () => a.study.managedWordIds(search: 'synthetic'),
    );
    expect(ids, hasLength(20000));
    await measure(
      'single_answer_ms',
      () => a.study.recordAnswer(
        wordId: 'word-0',
        result: AnswerResult.known,
        type: ReviewType.review,
        eventId: 'measured-answer',
        deviceId: 'synthetic-device',
        now: time.add(const Duration(days: 2)),
      ),
    );
    await measure('statistics_ms', () => a.study.statistics(now: time));
    await measure(
      'queue_ms',
      () => a.study.buildQueue(now: time, newLimit: 30, reviewLimit: 100),
    );
    final data = await measure(
      'snapshot_ms',
      () => a.backup.buildDataset(now: time),
    );
    expect(data['reviewEvents'] as List, hasLength(100001));
    final json = await measure('json_encode_ms', () async => jsonEncode(data));
    measurements['json_bytes'] = utf8.encode(json).length;
    await measure('json_decode_ms', () async => a.backup.decodeDataset(json));
    final report = await measure(
      'merge_and_replay_ms',
      () => b.backup.mergeDataset(data, now: time),
    );
    expect(report.addedEvents, 100001);
    expect(report.newWords, 20000);
    await measure(
      'single_replay_ms',
      () => b.study.rebuildStateFromEvents('word-0'),
    );
    measurements['words'] = 20000;
    measurements['events'] = 100001;
    stdout.writeln('MATERIALWORD_BENCHMARK ${jsonEncode(measurements)}');
    final destination = Platform.environment['MW_BENCHMARK_OUTPUT'];
    if (destination != null) {
      await File(
        destination,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(measurements));
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
