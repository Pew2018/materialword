import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/services/backup_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'offline union converges, duplicates are idempotent, reset survives',
    () async {
      final a = await TestEnv.create();
      final b = await TestEnv.create();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      for (final env in [a, b]) {
        final w = await env.words.ensureWord(
          text: 'alpha',
          now: env.clock.now(),
        );
        await env.study.recordAnswer(
          wordId: w.id,
          result: AnswerResult.known,
          type: ReviewType.study,
          eventId: env == a ? 'a' : 'b',
          deviceId: env == a ? 'a' : 'b',
          now: env.clock.now(),
        );
      }
      final original = await a.backup.buildDataset(now: a.clock.now());
      await a.backup.mergeDataset(
        await b.backup.buildDataset(now: b.clock.now()),
        now: a.clock.now(),
      );
      final merged = await a.backup.buildDataset(now: a.clock.now());
      expect((merged['learningStates'] as List).single['correctCount'], 2);
      await b.backup.mergeDataset(merged, now: b.clock.now());
      await a.backup.mergeDataset(
        await b.backup.buildDataset(now: b.clock.now()),
        now: a.clock.now(),
      );
      expect(
        BackupService.contentHashOf(
          await a.backup.buildDataset(now: a.clock.now()),
        ),
        BackupService.contentHashOf(
          await b.backup.buildDataset(now: b.clock.now()),
        ),
      );
      final word = (await a.words.byNormalized('alpha'))!;
      await a.study.resetProgress(
        wordId: word.id,
        now: a.clock.now(),
        deviceId: 'a',
        eventId: 'reset',
      );
      await a.backup.mergeDataset(original, now: a.clock.now());
      expect(await a.words.stateFor(word.id), isNull);
    },
  );

  test('corruption and unsupported algorithms rejected; v4 rebuilds', () async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    final w = await env.words.ensureWord(text: 'alpha', now: env.clock.now());
    await env.study.recordAnswer(
      wordId: w.id,
      result: AnswerResult.hazy,
      type: ReviewType.study,
      eventId: 'a',
      deviceId: 'a',
      now: env.clock.now(),
    );
    final data = jsonDecode(
      await env.backup.exportToJson(now: env.clock.now()),
    ) as Map<String, Object?>;
    env.backup.validateDataset(data);
    (data['learningStates'] as List).single['correctCount'] = 99;
    expect(
      () => env.backup.validateDataset(data),
      throwsA(isA<BackupException>()),
    );
    data['schemaVersion'] = 4;
    data.remove('learningStates');
    data.remove('progressEventDigest');
    data.remove('progressAlgorithmVersion');
    final other = await TestEnv.create();
    addTearDown(other.dispose);
    await other.backup.mergeDataset(data, now: other.clock.now());
    expect((await other.words.stateFor(w.id))!.hazyCount, 1);
    data['schemaVersion'] = 999;
    expect(
      () => env.backup.validateDataset(data),
      throwsA(isA<BackupException>()),
    );
  });

  test('snapshot preserves exact state and rolls back on failure', () async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    final w = await env.words.ensureWord(text: 'alpha', now: env.clock.now());
    await env.study.recordAnswer(
      wordId: w.id,
      result: AnswerResult.unknown,
      type: ReviewType.study,
      eventId: 'a',
      deviceId: 'a',
      now: env.clock.now(),
    );
    // updatedAt is bookkeeping, independent of the scheduling event timestamp.
    await (env.db.update(env.db.learningStates)
          ..where((t) => t.wordId.equals(w.id)))
        .write(const LearningStatesCompanion(updatedAt: Value(123)));
    final before = (await env.words.stateFor(w.id))!.toJson();
    final file = await env.backups.createBackup();
    await env.backups.restoreSnapshot(file);
    expect((await env.words.stateFor(w.id))!.toJson(), before);
    await expectLater(
      env.backups.restoreSnapshot(
        file,
        afterMerge: () async {
          throw StateError('injected');
        },
      ),
      throwsStateError,
    );
    expect((await env.words.stateFor(w.id))!.toJson(), before);
    expect(await env.settings.syncPaused(), isTrue);
  });
}
