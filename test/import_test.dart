import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/import_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;
  setUp(() async {
    env = await TestEnv.create();
  });
  tearDown(() async {
    await env.dispose();
  });

  test('T02 批量导入 TXT（每行一个单词）', () async {
    final ImportService service = env.importService();
    final ImportPreview preview = service.parseContent(
      '# 六级必备\nabandon\nbenefit\tv. 有益于\ncurious\n\ninvalid_line_123\n',
      format: 'txt',
      name: 'cet6.txt',
    );
    expect(preview.validCount, 3);
    expect(preview.invalidCount, 1);
    expect(preview.detectedBookName, 'cet6');

    final WordBook book = await env.books.create(
      name: '六级',
      now: env.clock.now(),
    );
    final ImportOutcome outcome = await service.commit(
      preview: preview,
      bookId: book.id,
      now: env.clock.now(),
    );
    expect(outcome.created, 3);
    expect(await env.books.wordCount(book.id), 3);

    final Word? benefit = await env.words.byNormalized('benefit');
    expect(benefit!.translation, 'v. 有益于');
  });

  test('T03 CSV 与 JSON 导入', () async {
    final ImportService service = env.importService();
    const String csv =
        'word,phonetic,pos,translation,example\n'
        'abandon,əˈbændən,v.,放弃,They abandoned the plan.\n'
        'benefit,,n.,好处,\n';
    final ImportPreview csvPreview = service.parseContent(
      csv,
      format: 'csv',
      name: 'list.csv',
    );
    expect(csvPreview.validCount, 2);

    const String json =
        '{"schemaVersion":1,"name":"JSON 词书",'
        '"words":[{"word":"curious","translation":"adj. 好奇的"},{"word":"abandon","translation":"重复"}]}';
    final ImportPreview jsonPreview = service.parseContent(
      json,
      format: 'json',
      name: 'list.json',
    );
    expect(jsonPreview.validCount, 2);
    expect(jsonPreview.detectedBookName, 'JSON 词书');

    final WordBook bookA = await env.books.create(
      name: 'CSV',
      now: env.clock.now(),
    );
    await service.commit(
      preview: csvPreview,
      bookId: bookA.id,
      now: env.clock.now(),
    );
    final WordBook bookB = await env.books.create(
      name: 'JSON',
      now: env.clock.now(),
    );
    await service.commit(
      preview: jsonPreview,
      bookId: bookB.id,
      now: env.clock.now(),
    );

    final Word? abandon = await env.words.byNormalized('abandon');
    expect(abandon!.phonetic, 'əˈbændən');
    expect(abandon.example, 'They abandoned the plan.');
    // Re-imported from JSON: existing content is kept, not overwritten.
    expect(abandon.translation, '放弃');
    expect(await env.books.wordCount(bookB.id), 2);
  });

  test('T04 重复导入不会产生重复词条或清除学习记录', () async {
    final ImportService service = env.importService();
    final ImportPreview preview = service.parseContent(
      'abandon\nbenefit\n',
      format: 'txt',
      name: 'a.txt',
    );
    final WordBook book = await env.books.create(
      name: '重复测试',
      now: env.clock.now(),
    );

    await service.commit(
      preview: preview,
      bookId: book.id,
      now: env.clock.now(),
    );
    final Word? word = await env.words.byNormalized('abandon');
    await env.study.recordAnswer(
      wordId: word!.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'e1',
      deviceId: 'd',
      now: env.clock.now(),
    );

    final ImportOutcome second = await service.commit(
      preview: preview,
      bookId: book.id,
      now: env.clock.now(),
    );
    expect(second.created, 0);
    expect(second.existing, 2);
    expect(await env.books.wordCount(book.id), 2);

    final LearningState? state = await env.words.stateFor(word.id);
    expect(state, isNotNull);
    expect(state!.correctCount, 1, reason: '学习进度必须保留');
    expect(await env.words.eventsForWord(word.id), hasLength(1));

    final List<Word> all = await env.words.db.select(env.words.db.words).get();
    expect(all.where((Word w) => w.normalized == 'abandon'), hasLength(1));
  });

  test('T20 词典补全不会覆盖用户自定义内容', () async {
    final Word word = await env.words.ensureWord(
      text: 'abandon',
      translation: '我自己的释义',
      note: '我的笔记',
      now: env.clock.now(),
    );
    final Word edited = await env.words.updateContent(
      word.id,
      translation: '我自己的释义',
      note: '我的笔记',
      now: env.clock.now(),
    );
    expect(edited.customized, isTrue);

    final Word enriched = await env.words.applyDictionaryInfo(
      word: edited,
      phonetic: 'əˈbændən',
      translation: '词典释义（不应覆盖）',
      definition: 'to leave behind',
      examTags: 'cet4 cet6',
      now: env.clock.now(),
    );
    expect(enriched.translation, '我自己的释义');
    expect(enriched.phonetic, 'əˈbændən', reason: '空白字段可以补全');
    expect(enriched.definition, 'to leave behind');
    expect(enriched.note, '我的笔记');
  });

  test('导入文件格式错误时抛出异常且不改动数据库', () async {
    final ImportService service = env.importService();
    expect(
      () => service.parseContent(
        '{"schemaVersion":99,"words":[]}',
        format: 'json',
        name: 'x.json',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => service.parseContent(
        'name,translation\na,苹果\n',
        format: 'csv',
        name: 'x.csv',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(await env.words.countWords(), 0);
  });
}
