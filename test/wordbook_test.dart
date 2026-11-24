import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/models/study_models.dart';
import 'package:materialword/core/repositories/word_repository.dart';

import 'helpers/test_env.dart';

Future<AnswerRecord> answer(
  TestEnv env, {
  required String wordId,
  AnswerResult result = AnswerResult.known,
  ReviewType type = ReviewType.study,
  String? eventId,
}) {
  return env.study.recordAnswer(
    wordId: wordId,
    result: result,
    type: type,
    eventId: eventId ?? '${wordId}_${DateTime.now().microsecondsSinceEpoch}',
    deviceId: 'test-device',
    now: env.clock.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;
  setUp(() async {
    env = await TestEnv.create();
  });
  tearDown(() async {
    await env.dispose();
  });

  test('T01 新建词书并新增单词', () async {
    final WordBook book = await env.books.create(
      name: '六级核心',
      now: env.clock.now(),
    );
    expect(book.name, '六级核心');

    final Word word = await env.words.ensureWord(
      text: 'Abandon',
      phonetic: 'əˈbændən',
      translation: 'v. 放弃',
      now: env.clock.now(),
    );
    expect(word.normalized, 'abandon');
    await env.books.addWords(book.id, <String>[word.id], now: env.clock.now());

    expect(await env.books.wordCount(book.id), 1);
    final List<WordWithState> listed = await env.words.listWords(
      bookId: book.id,
    );
    expect(listed, hasLength(1));
    expect(listed.single.word.word, 'Abandon');
    expect(listed.single.state, isNull);
  });

  test('T05 同一个单词加入多个词书，学习记录只有一份', () async {
    final WordBook bookA = await env.books.create(
      name: 'A',
      now: env.clock.now(),
    );
    final WordBook bookB = await env.books.create(
      name: 'B',
      now: env.clock.now(),
    );
    final Word word = await env.words.ensureWord(
      text: 'abandon',
      now: env.clock.now(),
    );

    await env.books.addWords(bookA.id, <String>[word.id], now: env.clock.now());
    await env.books.addWords(bookB.id, <String>[word.id], now: env.clock.now());

    // Adding the same text again must reuse the existing row.
    final Word again = await env.words.ensureWord(
      text: ' abandon ',
      now: env.clock.now(),
    );
    expect(again.id, word.id);

    await answer(env, wordId: word.id);

    expect(await env.books.wordCount(bookA.id), 1);
    expect(await env.books.wordCount(bookB.id), 1);
    final LearningState? state = await env.words.stateFor(word.id);
    expect(state, isNotNull);
    expect(state!.correctCount, 1);
    final List<ReviewEvent> events = await env.words.eventsForWord(word.id);
    expect(events, hasLength(1));
  });

  test('词条编辑会标记为用户自定义且更新 revision', () async {
    final Word word = await env.words.ensureWord(
      text: 'abandon',
      now: env.clock.now(),
    );
    expect(word.customized, isFalse);
    final Word edited = await env.words.updateContent(
      word.id,
      translation: 'v. 放弃；抛弃',
      note: '常与 plan 搭配',
      now: env.clock.now(),
    );
    expect(edited.customized, isTrue);
    expect(edited.revision, word.revision + 1);
    expect(edited.note, '常与 plan 搭配');
  });

  test('删除单词是软删除，重新添加不会丢学习记录', () async {
    final Word word = await env.words.ensureWord(
      text: 'abandon',
      now: env.clock.now(),
    );
    await answer(env, wordId: word.id);
    await env.words.softDelete(word.id, now: env.clock.now());

    expect(await env.words.byNormalized('abandon'), isNull);
    final Word? deleted = await env.words.byNormalized(
      'abandon',
      includeDeleted: true,
    );
    expect(deleted, isNotNull);
    expect(deleted!.deletedAt, isNotNull);

    final Word revived = await env.words.ensureWord(
      text: 'abandon',
      now: env.clock.now(),
    );
    expect(revived.id, word.id);
    expect(revived.deletedAt, isNull);
    final LearningState? state = await env.words.stateFor(word.id);
    expect(state!.correctCount, 1);
  });
}
