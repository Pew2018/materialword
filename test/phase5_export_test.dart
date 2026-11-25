import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/services/import_service.dart';
import 'package:materialword/services/word_intake_service.dart';
import 'package:materialword/services/wordbook_export.dart';

import 'helpers/test_env.dart';

/// Phase 5D acceptance: EXP01–EXP12.
///
/// Every round trip goes through the real exporter, the real parser and the
/// real write path into a second, independent database — no assertions on
/// "the file exists" or "the JSON parses".
void main() {
  late TestEnv source;
  late TestEnv target;

  setUp(() async {
    source = await TestEnv.create();
    target = await TestEnv.create();
  });

  tearDown(() async {
    await source.dispose();
    await target.dispose();
  });

  /// A book with one word per interesting shape: full content, punctuation,
  /// newlines, unicode, an empty-meaning row and a deleted row.
  Future<({WordBook book, List<Word> words})> seed(TestEnv env) async {
    final WordBook book = await env.books.create(
      name: '六级 核心',
      description: '核心词表',
      now: env.clock.now(),
    );
    final Word rich = (await env.intake.add(
      const WordIntakeRequest(
        text: 'abandon',
        user: WordContent(
          phonetic: 'əˈbændən',
          partOfSpeech: 'v.',
          translation: '放弃；抛弃',
          definition: 'to leave somebody behind',
          example: 'They abandoned the plan.\nHe abandoned hope.',
          phrase: 'abandon oneself to',
          note: '第一章笔记',
        ),
        content: WordContent(),
        examTags: 'cet6 cet4',
      ),
      bookId: book.id,
      now: env.clock.now(),
    )).word;
    await env.db
        .update(env.db.words)
        .replace(rich.copyWith(bncRank: 3211, frqRank: 940));
    await env.intake.add(
      const WordIntakeRequest(
        text: 'take off',
        user: WordContent(
          translation: 'a, b "c" — 起飞',
          example: 'He said, "take off" today.',
        ),
      ),
      bookId: book.id,
      now: env.clock.now(),
    );
    await env.intake.add(
      const WordIntakeRequest(text: 'zeta'),
      bookId: book.id,
      now: env.clock.now(),
    );
    final Word deleted = (await env.intake.add(
      const WordIntakeRequest(
        text: 'obsolete',
        user: WordContent(translation: '已废弃'),
      ),
      bookId: book.id,
      now: env.clock.now(),
    )).word;
    await env.books.removeWord(book.id, deleted.id, now: env.clock.now());
    await env.words.softDelete(deleted.id, now: env.clock.now());
    return (book: book, words: await env.books.wordsInBook(book.id));
  }

  Future<ImportOutcome> importInto(
    TestEnv env,
    String body, {
    required String format,
    String name = 'book.json',
    String? bookId,
  }) {
    final ImportService service = env.importService();
    return service.commit(
      preview: service.parseContent(body, format: format, name: name),
      bookId: bookId,
      now: env.clock.now(),
    );
  }

  Future<List<Word>> bookWords(TestEnv env, String bookName) async {
    final List<WordBook> books = await env.books.listBooks();
    final WordBook book = books.firstWhere(
      (WordBook b) => b.name == bookName,
      orElse: () => books.first,
    );
    return env.books.wordsInBook(book.id);
  }

  test('EXP01 TXT 往返只保留拼写', () async {
    final seeded = await seed(source);
    final String body = WordBookExporter.encodeBook(
      WordBookExport(book: seeded.book, words: seeded.words),
      WordBookExportFormat.txt,
    );
    expect(body.trim().split('\n'), <String>['abandon', 'take off', 'zeta']);

    final ImportOutcome outcome = await importInto(
      target,
      body,
      format: 'txt',
      name: 'book.txt',
      bookId: null,
    );
    expect(outcome.created, 3);
    final List<Word> landed = await bookWords(target, 'book');
    expect(landed.map((Word w) => w.word).toSet(), <String>{
      'abandon',
      'take off',
      'zeta',
    });
    expect(landed.every((Word w) => w.translation.isEmpty), isTrue);
  });

  test('EXP02 CSV 标准字段往返，partOfSpeech 别名可识别', () async {
    final seeded = await seed(source);
    final String body = WordBookExporter.encodeBook(
      WordBookExport(book: seeded.book, words: seeded.words),
      WordBookExportFormat.csv,
    );
    expect(body.split('\n').first, WordBookExporter.csvColumns.join(','));

    final ImportOutcome outcome = await importInto(
      target,
      body,
      format: 'csv',
      name: 'book.csv',
    );
    expect(outcome.created, 3);

    final Word abandon = (await target.words.byNormalized('abandon'))!;
    expect(abandon.phonetic, 'əˈbændən');
    expect(abandon.partOfSpeech, 'v.');
    expect(abandon.translation, '放弃；抛弃');
    expect(abandon.definition, 'to leave somebody behind');
    expect(abandon.example, 'They abandoned the plan.\nHe abandoned hope.');
    expect(abandon.phrase, 'abandon oneself to');
    expect(abandon.note, '第一章笔记');
    expect(abandon.examTags, 'cet6 cet4');

    final Word punctuation = (await target.words.byNormalized('take off'))!;
    expect(punctuation.translation, 'a, b "c" — 起飞');
    expect(punctuation.example, 'He said, "take off" today.');
    expect(await target.books.wordCount(outcome.bookId!), 3);
  });

  test('EXP03 JSON 完整字段往返（含 bncRank / frqRank）', () async {
    final seeded = await seed(source);
    final String body = WordBookExporter.encodeBook(
      WordBookExport(book: seeded.book, words: seeded.words),
      WordBookExportFormat.json,
    );
    final Map<String, dynamic> decoded =
        jsonDecode(body) as Map<String, dynamic>;
    expect(decoded['kind'], 'materialword-wordbook');
    expect(decoded['schemaVersion'], WordBookExporter.exchangeVersion);
    expect(decoded['name'], '六级 核心');
    expect(decoded['description'], '核心词表');
    expect(decoded['wordCount'], 3);

    await importInto(target, body, format: 'json');
    final Word abandon = (await target.words.byNormalized('abandon'))!;
    final Word original = (await source.words.byNormalized('abandon'))!;
    for (final String field in <String>[
      'word',
      'phonetic',
      'partOfSpeech',
      'translation',
      'definition',
      'example',
      'phrase',
      'note',
      'examTags',
    ]) {
      expect(
        abandon.toJson()[field],
        original.toJson()[field],
        reason: '字段 $field 必须逐字一致',
      );
    }
    expect(abandon.bncRank, 3211);
    expect(abandon.frqRank, 940);
    final WordBook landed = (await target.books.listBooks()).single;
    expect(landed.name, '六级 核心');
    expect(landed.description, '核心词表');
  });

  test('EXP04 历史裸数组 JSON 仍然可以导入', () async {
    const String legacy =
        '[{"word":"alpha","translation":"阿尔法","pos":"n."},'
        '{"word":"beta","meaning":"贝塔"}]';
    final ImportOutcome outcome = await importInto(
      target,
      legacy,
      format: 'json',
      name: 'legacy.json',
    );
    expect(outcome.created, 2);
    expect((await target.words.byNormalized('alpha'))!.partOfSpeech, 'n.');
    expect((await target.words.byNormalized('beta'))!.translation, '贝塔');
  });

  test('EXP05 空字段保持为空，不会被词典或默认值填充', () async {
    final seeded = await seed(source);
    await importInto(
      target,
      WordBookExporter.encodeBook(
        WordBookExport(book: seeded.book, words: seeded.words),
        WordBookExportFormat.json,
      ),
      format: 'json',
    );
    final Word zeta = (await target.words.byNormalized('zeta'))!;
    expect(zeta.translation, '');
    expect(zeta.phonetic, '');
    expect(zeta.note, '');
    expect(zeta.examTags, '');
  });

  test('EXP06 多词书导出保留归属关系且不重复词条', () async {
    final WordBook first = await source.books.create(
      name: '书一',
      now: source.clock.now(),
    );
    final WordBook second = await source.books.create(
      name: '书二',
      now: source.clock.now(),
    );
    final Word shared = (await source.intake.add(
      const WordIntakeRequest(
        text: 'shared',
        user: WordContent(translation: '共享'),
      ),
      bookId: first.id,
      now: source.clock.now(),
    )).word;
    await source.intake.add(
      const WordIntakeRequest(text: 'shared'),
      bookId: second.id,
      now: source.clock.now(),
    );
    await source.intake.add(
      const WordIntakeRequest(text: 'onlysecond'),
      bookId: second.id,
      now: source.clock.now(),
    );

    final String body = WordBookExporter.encodeBooks(<WordBookExport>[
      WordBookExport(
        book: first,
        words: await source.books.wordsInBook(first.id),
      ),
      WordBookExport(
        book: second,
        words: await source.books.wordsInBook(second.id),
      ),
    ], WordBookExportFormat.json);

    final ImportOutcome outcome = await importInto(
      target,
      body,
      format: 'json',
    );
    expect(outcome.books, 2);
    expect(
      await target.books.wordCount((await target.books.listBooks()).first.id),
      1,
    );
    final Word landed = (await target.words.byNormalized('shared'))!;
    expect(landed.id, isNot(shared.id), reason: '不同数据库的 UUID 本来不同');
    expect((await target.words.bookIdsForWord(landed.id)), hasLength(2));
    expect(await target.words.countWords(), 2);
  });

  test('EXP07 多词书 CSV 带 book 列往返', () async {
    final WordBook first = await source.books.create(
      name: '书一',
      now: source.clock.now(),
    );
    final WordBook second = await source.books.create(
      name: '书二',
      now: source.clock.now(),
    );
    await source.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(translation: '甲'),
      ),
      bookId: first.id,
      now: source.clock.now(),
    );
    await source.intake.add(
      const WordIntakeRequest(
        text: 'beta',
        user: WordContent(translation: '乙'),
      ),
      bookId: second.id,
      now: source.clock.now(),
    );
    final String body = WordBookExporter.encodeBooks(<WordBookExport>[
      WordBookExport(
        book: first,
        words: await source.books.wordsInBook(first.id),
      ),
      WordBookExport(
        book: second,
        words: await source.books.wordsInBook(second.id),
      ),
    ], WordBookExportFormat.csv);
    expect(body.split('\n').first, startsWith('book,'));

    final ImportOutcome outcome = await importInto(target, body, format: 'csv');
    expect(outcome.books, 2);
    final List<WordBook> books = await target.books.listBooks();
    expect(books.map((WordBook b) => b.name).toSet(), <String>{'书一', '书二'});
    expect(await target.words.countWords(), 2);
  });

  test('EXP08 已删除词条不进入普通词书导出', () async {
    final seeded = await seed(source);
    final String json = WordBookExporter.encodeBook(
      WordBookExport(book: seeded.book, words: seeded.words),
      WordBookExportFormat.json,
    );
    expect(json, isNot(contains('obsolete')));

    final String all = WordBookExporter.encodeBooks(<WordBookExport>[
      WordBookExport(
        book: seeded.book,
        words: await source.books.wordsInBook(seeded.book.id),
      ),
    ], WordBookExportFormat.json);
    expect(all, isNot(contains('obsolete')));
    final String deleted = (await source.words.byNormalized(
      'obsolete',
      includeDeleted: true,
    ))!.word;
    expect(deleted, 'obsolete');
  });

  test('EXP09 CSV 公式注入防护仍然生效，且不是无损格式', () async {
    final WordBook book = await source.books.create(
      name: '安全',
      now: source.clock.now(),
    );
    final Word word = (await source.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(
          translation: '=HYPERLINK("http://evil.example")',
          note: '+cmd|calc',
        ),
      ),
      bookId: book.id,
      now: source.clock.now(),
    )).word;
    final String csv = WordBookExporter.encodeBook(
      WordBookExport(book: book, words: <Word>[word]),
      WordBookExportFormat.csv,
    );
    expect(csv, contains('"\'=HYPERLINK'));
    expect(csv, contains("'+cmd|calc"));
    // The stored value is untouched.
    expect((await source.words.byId(word.id))!.translation, startsWith('='));

    // JSON is the lossless channel: no apostrophe is added.
    final String json = WordBookExporter.encodeBook(
      WordBookExport(book: book, words: <Word>[word]),
      WordBookExportFormat.json,
    );
    expect(json, isNot(contains("'=HYPERLINK")));
  });

  test('EXP10 导入时不会盲删前导单引号', () async {
    final ImportOutcome outcome = await importInto(
      target,
      'word,translation\nalpha,\'=1+1\nbeta,it\'s fine\n',
      format: 'csv',
      name: 'quotes.csv',
    );
    expect(outcome.created, 2);
    expect((await target.words.byNormalized('alpha'))!.translation, "'=1+1");
    expect((await target.words.byNormalized('beta'))!.translation, "it's fine");
  });

  test('EXP11 导出不修改数据库（修订号与更新时间不变）', () async {
    final seeded = await seed(source);
    final Map<String, int> before = <String, int>{
      for (final Word word in seeded.words) word.id: word.revision,
    };
    for (final WordBookExportFormat format in WordBookExportFormat.values) {
      WordBookExporter.encodeBook(
        WordBookExport(book: seeded.book, words: seeded.words),
        format,
      );
    }
    for (final Word word in seeded.words) {
      final Word after = (await source.words.byId(word.id))!;
      expect(after.revision, before[word.id]);
      expect(after.updatedAt, word.updatedAt);
    }
  });

  test('EXP12 重复导入同一文件保持幂等且不破坏既有内容', () async {
    final seeded = await seed(source);
    final String body = WordBookExporter.encodeBook(
      WordBookExport(book: seeded.book, words: seeded.words),
      WordBookExportFormat.json,
    );
    final ImportOutcome first = await importInto(target, body, format: 'json');
    expect(first.created, 3);
    final Word abandon = (await target.words.byNormalized('abandon'))!;
    await target.intake.add(
      const WordIntakeRequest(
        text: 'abandon',
        user: WordContent(translation: '我在目标库改的'),
      ),
      now: target.clock.now(),
    );

    final ImportOutcome second = await importInto(target, body, format: 'json');
    expect(second.created, 0);
    expect(second.existing, 3);
    expect(await target.words.countWords(), 3);
    expect(
      (await target.words.byId(abandon.id))!.translation,
      '我在目标库改的',
      reason: '重复导入不能覆盖本机编辑',
    );
  });
}
