import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/backup_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('T13 本地备份导出与恢复', () async {
    final TestEnv env = await TestEnv.create();
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    final Word word = (await env.words.byNormalized('alpha'))!;
    await env.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.hazy,
      type: ReviewType.study,
      eventId: 'evt-1',
      deviceId: 'device-a',
      now: env.clock.now(),
    );

    final String json = await env.backup.exportToJson(now: env.clock.now());
    final Map<String, Object?> dataset =
        jsonDecode(json) as Map<String, Object?>;
    expect(dataset['schemaVersion'], backupSchemaVersion);
    expect(dataset['kind'], backupKind);
    expect((dataset['words'] as List<dynamic>), hasLength(2));
    expect((dataset['reviewEvents'] as List<dynamic>), hasLength(1));
    expect(dataset.containsKey('deviceId'), isTrue);

    final TestEnv restored = await TestEnv.create(
      now: DateTime(2026, 12, 1, 9),
    );
    final MergeReport report = await restored.backup.mergeDataset(
      jsonDecode(json) as Map<String, Object?>,
      now: DateTime(2026, 12, 1, 9),
    );
    expect(report.newWords, 2);
    expect(report.newBooks, 1);
    expect(report.newEntries, 2);
    expect(report.addedEvents, 1);
    expect(report.rebuiltStates, 1);

    final Word? alpha = await restored.words.byNormalized('alpha');
    expect(alpha, isNotNull);
    final LearningState? state = await restored.words.stateFor(alpha!.id);
    expect(state, isNotNull);
    expect(state!.hazyCount, 1);
    expect(state.stage, StudyStage.learning.code);
    expect(await restored.books.wordCount(book.id), 2);

    await env.dispose();
    await restored.dispose();
  });

  test('T14 两个设备的学习事件合并', () async {
    final TestEnv phone = await TestEnv.create(now: DateTime(2026, 11, 24, 9));
    final TestEnv mac = await TestEnv.create(now: DateTime(2026, 11, 24, 10));

    // Phone studies "alpha" and exports.
    final Word phoneWord = await phone.words.ensureWord(
      text: 'alpha',
      now: phone.clock.now(),
    );
    await phone.study.recordAnswer(
      wordId: phoneWord.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'phone-event-1',
      deviceId: 'phone',
      now: phone.clock.now(),
    );
    final String phoneJson = await phone.backup.exportToJson(
      now: phone.clock.now(),
    );

    // Mac restores the phone backup, then studies the same word again.
    await mac.backup.mergeDataset(
      jsonDecode(phoneJson) as Map<String, Object?>,
      now: mac.clock.now(),
    );
    final Word? macWord = await mac.words.byNormalized('alpha');
    expect(macWord, isNotNull);
    await mac.study.recordAnswer(
      wordId: macWord!.id,
      result: AnswerResult.unknown,
      type: ReviewType.review,
      eventId: 'mac-event-1',
      deviceId: 'mac',
      now: mac.clock.now().add(const Duration(days: 1)),
    );
    final String macJson = await mac.backup.exportToJson(now: mac.clock.now());

    // Merging back into the phone unions the histories.
    final MergeReport report = await phone.backup.mergeDataset(
      jsonDecode(macJson) as Map<String, Object?>,
      now: phone.clock.now(),
    );
    expect(report.addedEvents, 1);
    expect(report.duplicateEvents, 1);
    expect(report.newWords, 0);

    final List<ReviewEvent> events = await phone.words.eventsForWord(
      phoneWord.id,
    );
    expect(events, hasLength(2));
    final LearningState? state = await phone.words.stateFor(phoneWord.id);
    expect(state!.correctCount, 1);
    expect(state.wrongCount, 1);
    expect(state.stage, StudyStage.relearning.code, reason: '状态由合并后的历史重算');

    await phone.dispose();
    await mac.dispose();
  });

  test('T15 同一份备份重复导入不会重复增加统计', () async {
    final TestEnv source = await TestEnv.create();
    final Word word = await source.words.ensureWord(
      text: 'alpha',
      now: source.clock.now(),
    );
    await source.study.recordAnswer(
      wordId: word.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'dup-1',
      deviceId: 'device-a',
      now: source.clock.now(),
    );
    final Map<String, Object?> dataset = jsonDecode(
      await source.backup.exportToJson(now: source.clock.now()),
    ) as Map<String, Object?>;

    final TestEnv target = await TestEnv.create();
    await target.backup.mergeDataset(dataset, now: target.clock.now());
    final int wordsAfterFirst = await target.words.countWords();
    final List<ReviewEvent> eventsAfterFirst = await target.words.eventsForWord(
      word.id,
    );

    for (int i = 0; i < 2; i++) {
      final MergeReport report = await target.backup.mergeDataset(
        dataset,
        now: target.clock.now(),
      );
      expect(report.addedEvents, 0);
      expect(report.newWords, 0);
    }

    expect(await target.words.countWords(), wordsAfterFirst);
    expect(
      await target.words.eventsForWord(word.id),
      hasLength(eventsAfterFirst.length),
    );
    final LearningState? state = await target.words.stateFor(word.id);
    expect(state!.correctCount, 1);

    await source.dispose();
    await target.dispose();
  });

  test('T16 错误备份文件不会破坏数据库', () async {
    final TestEnv env = await TestEnv.create();
    await env.seedBook(words: <String>['alpha', 'beta']);
    final int before = await env.words.countWords();

    expect(
      () => env.backup.decodeDataset('{"schemaVersion":1,"kind":"other"}'),
      throwsA(isA<BackupException>()),
    );
    expect(
      () => env.backup.decodeDataset('not json'),
      throwsA(isA<BackupException>()),
    );
    expect(
      () => env.backup.decodeDataset('{"schemaVersion":999,"words":[]}'),
      throwsA(isA<BackupException>()),
    );
    expect(
      () => env.backup.decodeDataset('{"words":[]}'),
      throwsA(isA<BackupException>()),
    );

    // A structurally valid but semantically broken dataset must not throw away data.
    final MergeReport report = await env.backup.mergeDataset(<String, Object?>{
      'schemaVersion': 1,
      'words': <Object>[
        <String, Object?>{'id': 'x'},
      ],
      'entries': <Object>[
        <String, Object?>{'wordBookId': 'missing', 'wordId': 'missing'},
      ],
      'reviewEvents': <Object>[
        <String, Object?>{'id': 'e', 'wordId': 'missing'},
      ],
    }, now: env.clock.now());
    expect(report.skippedEntries, greaterThan(0));
    expect(await env.words.countWords(), before);

    await env.dispose();
  });
}
