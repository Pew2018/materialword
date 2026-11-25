import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/backup_service.dart';

import 'helpers/test_env.dart';

void main() {
  final now = DateTime.utc(2026, 11, 25, 12);
  Future<void> transfer(TestEnv a, TestEnv b) async => b.backup.mergeDataset(
    jsonDecode(await a.backup.exportToJson(now: now)) as Map<String, Object?>,
    now: now,
  );
  test('same timestamp and reversed lexical IDs preserve mastery cancellation causality', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha']);
    final id = (await e.words.byNormalized('alpha'))!.id;
    await e.study.recordAnswer(
      wordId: id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'original',
      deviceId: 'device',
      now: now,
    );
    final original = (await e.words.stateFor(id))!;
    await e.study.markMastered(
      wordId: id,
      deviceId: 'device',
      now: now,
      eventId: 'zzz-master',
    );
    await e.study.unmarkMastered(
      wordId: id,
      deviceId: 'device',
      now: now,
      eventId: 'aaa-unmaster',
    );
    final restored = (await e.words.stateFor(id))!;
    expect(restored.intervalDays, original.intervalDays);
    expect(restored.nextReviewAt, original.nextReviewAt);
    expect(restored.correctCount, 1);
    final events = await e.db.select(e.db.reviewEvents).get();
    expect(events.map((e) => e.causalOrder), [1, 2, 3]);
    expect(events.map((e) => e.answeredAt).toSet(), {
      now.millisecondsSinceEpoch,
    });
  });

  test('clock moving backwards does not move a later reset before an observed answer', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha']);
    final id = (await e.words.byNormalized('alpha'))!.id;
    await e.study.recordAnswer(
      wordId: id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'future-clock',
      deviceId: 'device',
      now: DateTime.utc(2099),
    );
    await e.study.resetProgress(
      wordId: id,
      deviceId: 'device',
      now: now,
      eventId: 'reset',
    );
    expect(await e.words.stateFor(id), isNull);
    await e.study.rebuildStateFromEvents(id);
    expect(await e.words.stateFor(id), isNull);
    final reset = (await e.db.select(e.db.reviewEvents).get()).last;
    expect(reset.answeredAt, now.millisecondsSinceEpoch);
    expect(reset.causalOrder, 2);
  });

  test('concurrent same-counter answers converge and next observed event increments order', () async {
    final a = await TestEnv.create(),
        b = await TestEnv.create(),
        c = await TestEnv.create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    addTearDown(c.dispose);
    await a.seedBook(words: ['alpha']);
    final id = (await a.words.byNormalized('alpha'))!.id;
    await a.study.recordAnswer(
      wordId: id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'first',
      deviceId: 'a',
      now: now,
    );
    await transfer(a, b);
    await a.study.recordAnswer(
      wordId: id,
      result: AnswerResult.unknown,
      type: ReviewType.review,
      eventId: 'concurrent-a',
      deviceId: 'a',
      now: now,
    );
    await b.study.recordAnswer(
      wordId: id,
      result: AnswerResult.hazy,
      type: ReviewType.review,
      eventId: 'concurrent-b',
      deviceId: 'b',
      now: now,
    );
    await transfer(a, b);
    await transfer(b, a);
    await transfer(a, c);
    await c.study.recordAnswer(
      wordId: id,
      result: AnswerResult.known,
      type: ReviewType.review,
      eventId: 'after-both',
      deviceId: 'c',
      now: now.subtract(const Duration(hours: 2)),
    );
    final event = (await c.db.select(c.db.reviewEvents).get()).last;
    expect(event.causalOrder, 3);
    await transfer(c, a);
    await transfer(a, b);
    await transfer(b, c);
    final state = (await a.words.stateFor(id))!;
    expect((await b.words.stateFor(id))!.toJson(), state.toJson());
    expect((await c.words.stateFor(id))!.toJson(), state.toJson());
    expect(
      BackupService.contentHashOf(await a.backup.buildDataset(now: now)),
      BackupService.contentHashOf(await c.backup.buildDataset(now: now)),
    );
  });

  test('immutable causal order conflicts and negative order reject complete import', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha']);
    final id = (await e.words.byNormalized('alpha'))!.id;
    await e.study.markMastered(
      wordId: id,
      deviceId: 'device',
      now: now,
      eventId: 'mastered',
    );
    final original = await e.backup.buildDataset(now: now);
    for (final counter in [-1, 2]) {
      final data = jsonDecode(jsonEncode(original)) as Map<String, Object?>;
      ((data['reviewEvents'] as List).single as Map)['causalOrder'] = counter;
      await expectLater(
        e.backup.mergeDataset(data, now: now),
        throwsA(isA<BackupException>()),
      );
      expect(
        (await e.db.select(e.db.reviewEvents).get()).single.causalOrder,
        1,
      );
    }
  });
}
