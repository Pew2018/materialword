import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/backup_service.dart';

import 'helpers/test_env.dart';

void main() {
  test('SYNC corrupt fields, duplicate identities and dangling references reject the whole document', () async {
    final source = await TestEnv.create();
    final target = await TestEnv.create();
    addTearDown(source.dispose);
    addTearDown(target.dispose);
    await source.seedBook(words: ['alpha']);
    await target.seedBook(words: ['beta']);
    final word = (await source.words.listWords()).single.word;
    await source.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'original-answer',
      deviceId: 'source',
      now: source.clock.now(),
    );
    final valid = await source.backup.buildDataset(now: source.clock.now());
    final mutations = <void Function(Map<String, dynamic>)>[
      (d) => (d['words'] as List).first['note'] = 42,
      (d) => (d['words'] as List).first['normalized'] = 'unrelated',
      (d) => (d['words'] as List).add((d['words'] as List).first),
      (d) => (d['entries'] as List).first['wordId'] = 'missing',
      (d) => (d['reviewEvents'] as List).first['result'] = 4,
      (d) => (d['reviewEvents'] as List).first['type'] = 'future-type',
      (d) => (d['reviewEvents'] as List).first['algoVersion'] = 999,
      (d) => (d['reviewEvents'] as List).first['mode'] = 'undo:missing',
      (d) => (d['reviewEvents'] as List).first['answeredAt'] =
          '2026-11-24T09:00:00',
      (d) => (d['reviewEvents'] as List).first['dayStartUtc'] =
          '2027-01-01T00:00:00Z',
      (d) => (d['words'] as List).first['deletedAt'] = 'invalid',
      (d) => d.remove('words'),
    ];
    for (final mutate in mutations) {
      final changed = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      mutate(changed);
      await expectLater(
        target.backup.mergeDataset(changed, now: target.clock.now()),
        throwsA(isA<BackupException>()),
      );
      expect(await target.words.countWords(), 1);
      expect((await target.words.listWords()).single.word.word, 'beta');
      expect(await target.db.select(target.db.reviewEvents).get(), isEmpty);
    }
  });

  test('SYNC old backup without time provenance gets a stable valid UTC anchor', () async {
    final a = await TestEnv.create(now: DateTime.utc(2026, 11, 23, 18));
    final b = await TestEnv.create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.seedBook(words: ['alpha']);
    final word = (await a.words.listWords()).single.word;
    await a.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'legacy',
      deviceId: 'source',
      now: a.clock.now(),
    );
    final data = await a.backup.buildDataset(now: a.clock.now());
    data['schemaVersion'] = 2;
    final event = (data['reviewEvents'] as List).single as Map;
    event.remove('dayStartUtc');
    event.remove('dayStartSource');
    // A source ahead of UTC can have a local date later than the UTC answer date.
    event['localDay'] = '2026-11-24';
    await b.backup.mergeDataset(data, now: b.clock.now());
    final exported = await b.backup.buildDataset(now: b.clock.now());
    expect(() => b.backup.validateDataset(exported), returnsNormally);
    expect(
      (exported['reviewEvents'] as List).single['dayStartUtc'],
      '2026-11-23T00:00:00.000Z',
    );
    final before = BackupService.contentHashOf(exported);
    await a.backup.mergeDataset(exported, now: a.clock.now());
    // The original event retains its authored anchor: importing a legacy copy
    // cannot silently rewrite immutable scheduling provenance already present.
    expect(
      (await a.db.select(a.db.reviewEvents).getSingle()).dayStartUtc,
      isNotNull,
    );
    expect(
      BackupService.contentHashOf(
        await b.backup.buildDataset(now: b.clock.now()),
      ),
      before,
    );
    await b.backup.mergeDataset(
      await a.backup.buildDataset(now: a.clock.now()),
      now: b.clock.now(),
    );
    expect(
      (await b.db.select(b.db.reviewEvents).getSingle()).dayStartSource,
      'authored',
    );
    expect(
      (await b.words.stateFor(word.id))!.nextReviewAt,
      (await a.words.stateFor(word.id))!.nextReviewAt,
    );
    expect(
      BackupService.contentHashOf(
        await b.backup.buildDataset(now: b.clock.now()),
      ),
      BackupService.contentHashOf(
        await a.backup.buildDataset(now: a.clock.now()),
      ),
    );
  });
}
