import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';

import 'helpers/test_env.dart';

void main() {
  for (final count in [800, 5000, 20000]) {
    test(
      'WORD pagination covers $count words with tied creation times',
      () async {
        final env = await TestEnv.create();
        addTearDown(env.dispose);
        await env.db.batch((batch) {
          batch.insertAll(
            env.db.words,
            List.generate(
              count,
              (i) => WordsCompanion.insert(
                id: 'id-$i',
                word: 'word$i',
                normalized: 'word$i',
                createdAt: 1,
                updatedAt: 1,
              ),
            ),
          );
        });
        for (final sort in ManagedSort.values) {
          final ids = <String>[];
          for (int offset = 0; offset < count; offset += 137) {
            final rows = await env.study.managedWords(
              sort: sort,
              limit: 137,
              offset: offset,
            );
            ids.addAll(rows.map((r) => r.word.id));
          }
          expect(ids.length, count);
          expect(
            ids.toSet().length,
            count,
            reason: 'No omissions or duplicates for $sort',
          );
        }
        expect(
          await env.study.managedCount(search: 'word19999'),
          count == 20000 ? 1 : 0,
        );
      },
    );
  }

  test(
    'STUDY manual mastery preserves real counts and survives merge/replay',
    () async {
      final a = await TestEnv.create();
      final b = await TestEnv.create();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.seedBook(words: ['alpha']);
      final word = (await a.words.listWords()).single.word;
      await a.study.recordAnswer(
        wordId: word.id,
        result: AnswerResult.unknown,
        type: ReviewType.study,
        eventId: 'answer',
        deviceId: 'a',
        now: a.clock.now(),
      );
      await a.study.markMastered(
        wordId: word.id,
        deviceId: 'a',
        now: a.clock.now().add(const Duration(seconds: 1)),
        eventId: 'master',
      );
      final state = (await a.words.stateFor(word.id))!;
      expect(state.intervalDays, 30);
      expect(state.correctCount, 0);
      expect(state.wrongCount, 1);
      expect(
        await a.study.todayCount(now: a.clock.now(), type: ReviewType.review),
        0,
      );
      final stats = await a.study.statistics(now: a.clock.now());
      expect(stats.correctCount, 0);
      expect(stats.wrongCount, 1);
      await b.backup.mergeDataset(
        await a.backup.buildDataset(now: a.clock.now()),
        now: b.clock.now(),
      );
      final restored = (await b.words.stateFor(word.id))!;
      expect(restored.intervalDays, 30);
      expect(restored.wrongCount, 1);
      expect(restored.correctCount, 0);
    },
  );

  test(
    'STUDY undo is append-only, idempotent and excludes undone statistics',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: ['alpha']);
      final id = (await env.words.listWords()).single.word.id;
      await env.study.recordAnswer(
        wordId: id,
        result: AnswerResult.known,
        type: ReviewType.study,
        eventId: 'answer',
        deviceId: 'a',
        now: env.clock.now(),
      );
      for (int i = 0; i < 2; i++) {
        await env.study.undoAnswer(
          eventId: 'answer',
          undoId: 'undo',
          deviceId: 'a',
          now: env.clock.now().add(const Duration(seconds: 1)),
        );
      }
      expect(await env.words.stateFor(id), isNull);
      expect((await env.words.eventsForWord(id)).length, 2);
      expect(
        await env.study.todayCount(
          now: env.clock.now(),
          type: ReviewType.study,
        ),
        0,
      );
      expect(
        (await env.study.statistics(now: env.clock.now())).correctCount,
        0,
      );
    },
  );

  test('DB reset batch rolls back all changes when any event fails', () async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    await env.seedBook(words: ['alpha', 'beta']);
    final ids = (await env.words.listWords()).map((r) => r.word.id).toList();
    int calls = 0;
    await expectLater(
      env.study.resetProgressBatch(
        wordIds: ids,
        deviceId: 'a',
        now: env.clock.now(),
        eventIdFor: (_) {
          if (++calls == 2) throw StateError('injected failure');
          return 'reset';
        },
      ),
      throwsStateError,
    );
    expect(await env.db.select(env.db.reviewEvents).get(), isEmpty);
  });
  test(
    'STUDY cancelling manual mastery restores authentic history and due time',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: ['alpha']);
      final id = (await env.words.listWords()).single.word.id;
      await env.study.recordAnswer(
        wordId: id,
        result: AnswerResult.unknown,
        type: ReviewType.study,
        eventId: 'answer',
        deviceId: 'a',
        now: env.clock.now(),
      );
      final originalDue = (await env.words.stateFor(id))!.nextReviewAt;
      await env.study.markMastered(
        wordId: id,
        deviceId: 'a',
        eventId: 'master',
        now: env.clock.now().add(const Duration(seconds: 1)),
      );
      await env.study.unmarkMastered(
        wordId: id,
        deviceId: 'a',
        eventId: 'unmaster',
        now: env.clock.now().add(const Duration(seconds: 2)),
      );
      final state = (await env.words.stateFor(id))!;
      expect(state.nextReviewAt, originalDue);
      expect(state.wrongCount, 1);
      expect(state.correctCount, 0);
      expect((await env.words.eventsForWord(id)), hasLength(3));
    },
  );

  test(
    'STUDY nearest due timestamp excludes deleted words and elapsed deadlines',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: ['alpha']);
      final id = (await env.words.listWords()).single.word.id;
      await env.study.recordAnswer(
        wordId: id,
        result: AnswerResult.unknown,
        type: ReviewType.study,
        eventId: 'answer',
        deviceId: 'a',
        now: env.clock.now(),
      );
      expect(
        await env.study.nextDueAfter(env.clock.now()),
        env.clock.now().add(const Duration(minutes: 30)).toUtc(),
      );
      expect(
        await env.study.nextDueAfter(
          env.clock.now().add(const Duration(minutes: 31)),
        ),
        isNull,
      );
      await env.words.softDelete(id, now: env.clock.now());
      expect(await env.study.nextDueAfter(env.clock.now()), isNull);
    },
  );
}
