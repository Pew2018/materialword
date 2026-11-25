import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';

import 'helpers/test_env.dart';

/// The "next due" value that drives the one-shot refresh timer: it must point at
/// the soonest *future* due word and must not be fooled by tombstones, unlearned
/// words or already-due backlog.
void main() {
  late TestEnv env;

  setUp(() async {
    env = await TestEnv.create();
  });

  tearDown(() async {
    await env.dispose();
  });

  test('nothing scheduled means no timer', () async {
    await env.seedBook();
    expect(await env.study.nextDueAfter(env.clock.now()), isNull);
  });

  test('the soonest future due wins, backlog is ignored', () async {
    await env.seedBook(words: <String>['alpha', 'beta', 'gamma']);
    final ids = await env.db
        .customSelect('SELECT id FROM words ORDER BY normalized')
        .map((row) => row.read<String>('id'))
        .get();
    await env.study.recordAnswer(
      wordId: ids[0],
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'a1',
      deviceId: 'device',
      now: env.clock.now(),
    );
    env.clock.advance(const Duration(days: 1));
    await env.study.recordAnswer(
      wordId: ids[1],
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'a2',
      deviceId: 'device',
      now: env.clock.now(),
    );

    final DateTime now = env.clock.now();
    final DateTime? next = await env.study.nextDueAfter(now);
    // Property: whatever the scheduler computed, the value is the minimum of the
    // stored future dates — never the already-due backlog.
    final List<int> future = await env.db
        .customSelect(
          'SELECT next_review_at FROM learning_states '
          'WHERE stage != 0 AND next_review_at > ?',
          variables: [Variable.withInt(now.millisecondsSinceEpoch)],
        )
        .map((row) => row.read<int>('next_review_at'))
        .get();
    expect(future, isNotEmpty);
    expect(next, isNotNull);
    expect(
      next!.millisecondsSinceEpoch,
      future.reduce((int a, int b) => a < b ? a : b),
    );
  });

  test('deleted words and unlearned words never schedule a refresh', () async {
    await env.seedBook(words: <String>['alpha', 'beta']);
    final ids = await env.db
        .customSelect('SELECT id FROM words ORDER BY normalized')
        .map((row) => row.read<String>('id'))
        .get();
    await env.study.recordAnswer(
      wordId: ids.first,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'only',
      deviceId: 'device',
      now: env.clock.now(),
    );
    expect(await env.study.nextDueAfter(env.clock.now()), isNotNull);
    await env.words.softDelete(ids.first, now: env.clock.now());
    expect(await env.study.nextDueAfter(env.clock.now()), isNull);
  });

  test('a new answer moves the boundary forward and never backwards', () async {
    await env.seedBook(words: <String>['alpha']);
    final id = (await env.words.byNormalized('alpha'))!.id;
    final DateTime before = env.clock.now();
    await env.study.recordAnswer(
      wordId: id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'e1',
      deviceId: 'device',
      now: before,
    );
    final DateTime? first = await env.study.nextDueAfter(before);
    expect(first, isNotNull);

    env.clock.advance(const Duration(days: 2));
    await env.study.recordAnswer(
      wordId: id,
      result: AnswerResult.known,
      type: ReviewType.review,
      eventId: 'e2',
      deviceId: 'device',
      now: env.clock.now(),
    );
    final DateTime? second = await env.study.nextDueAfter(env.clock.now());
    expect(second, isNotNull);
    expect(second!.isAfter(first!), isTrue);
  });
}
