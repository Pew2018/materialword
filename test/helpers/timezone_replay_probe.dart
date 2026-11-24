import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';

import 'test_env.dart';

/// Invoked explicitly twice with different TZ environments, not discovered as
/// a regular test. Only synthetic data is written to the requested work file.
void main() {
  test('event due time survives a real timezone/process boundary', () async {
    final phase = Platform.environment['MW_TZ_PHASE'];
    final path = Platform.environment['MW_TZ_FILE'];
    if (path == null || phase == null) {
      throw StateError('Timezone probe needs an explicit phase and work file');
    }
    final env = await TestEnv.create(now: DateTime(2026, 11, 24, 21));
    addTearDown(env.dispose);
    if (phase == 'author') {
      await env.seedBook(words: ['alpha']);
      final id = (await env.words.listWords()).single.word.id;
      await env.study.recordAnswer(
        wordId: id,
        result: AnswerResult.known,
        type: ReviewType.study,
        eventId: 'timezone-event',
        deviceId: 'author',
        now: env.clock.now(),
      );
      final state = (await env.words.stateFor(id))!;
      await File(path).writeAsString(
        jsonEncode({
          'dataset': await env.backup.buildDataset(now: env.clock.now()),
          'expectedDue': state.nextReviewAt,
          'authorOffsetMinutes': env.clock.now().timeZoneOffset.inMinutes,
        }),
      );
    } else {
      final source = jsonDecode(await File(path).readAsString()) as Map;
      expect(
        env.clock.now().timeZoneOffset.inMinutes,
        isNot(source['authorOffsetMinutes']),
      );
      await env.backup.mergeDataset(
        Map<String, Object?>.from(source['dataset'] as Map),
        now: env.clock.now(),
      );
      final id = (await env.words.listWords()).single.word.id;
      await env.study.rebuildStateFromEvents(id);
      expect(
        (await env.words.stateFor(id))!.nextReviewAt,
        source['expectedDue'],
      );
    }
  });
}
