import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/services/word_form_guesser.dart';
import 'package:materialword/services/wordbook_export.dart';

import 'helpers/test_env.dart';

/// Word-book content export and base-form hints: rule-based, data-verified, and
/// never merging two user entries.
void main() {
  group('word forms', () {
    List<String> lemmas(String input) =>
        WordFormGuesser.candidates(input)
            .map((WordFormCandidate c) => c.lemma)
            .toList();

    test('recognised inflections resolve to a candidate base form', () {
      expect(lemmas('recognized'), contains('recognize'));
      expect(lemmas('recognises'), contains('recognise'));
      expect(lemmas('studies'), contains('study'));
      expect(lemmas('studied'), contains('study'));
      expect(lemmas('stopped'), contains('stop'));
      expect(lemmas('running'), contains('run'));
      expect(lemmas('making'), contains('make'));
      expect(lemmas('bigger'), contains('big'));
      expect(lemmas('largest'), contains('large'));
      expect(lemmas('happier'), contains('happy'));
      expect(lemmas('boxes'), contains('box'));
    });

    test('a base form never proposes itself', () {
      for (final String candidate in lemmas('recognize')) {
        expect(candidate, isNot('recognize'));
      }
    });

    test('non alphabetic input and short words produce nothing', () {
      expect(lemmas(''), isEmpty);
      expect(lemmas('a'), isEmpty);
      expect(lemmas('two words'), isEmpty);
      expect(lemmas('123'), isEmpty);
      expect(lemmas('a-b'), isEmpty);
    });

    test('the candidate list is bounded and de-duplicated', () {
      final List<WordFormCandidate> candidates = WordFormGuesser.candidates(
        'interesting',
      );
      expect(
        candidates.length,
        lessThanOrEqualTo(WordFormGuesser.maxCandidates),
      );
      final Set<String> unique = candidates.map((c) => c.lemma).toSet();
      expect(unique.length, candidates.length);
      expect(candidates.first.relation, isNotEmpty);
    });
  });

  group('word book export', () {
    late TestEnv env;

    setUp(() async {
      env = await TestEnv.create();
    });

    tearDown(() async {
      await env.dispose();
    });

    Future<List<Word>> bookWords() async {
      final WordBook book = await env.books.create(
        name: '导出',
        now: env.clock.now(),
      );
      final Word plain = await env.words.ensureWord(
        text: 'plain',
        phonetic: 'pleɪn',
        partOfSpeech: 'adj.',
        translation: '简单的',
        now: env.clock.now(),
      );
      final Word quoted = await env.words.ensureWord(
        text: 'quote',
        translation: 'a, b "c"\nsecond line',
        now: env.clock.now(),
      );
      final Word removed = await env.words.ensureWord(
        text: 'removed',
        translation: '已移出',
        now: env.clock.now(),
      );
      await env.books.addWords(book.id, <String>[
        plain.id,
        quoted.id,
        removed.id,
      ], now: env.clock.now());
      await env.books.removeWord(book.id, removed.id, now: env.clock.now());
      return env.books.wordsInBook(book.id);
    }

    test('only live members are exported, alphabetically', () async {
      final List<Word> words = await bookWords();
      expect(words.map((Word w) => w.word), <String>['plain', 'quote']);
    });

    test('txt is one word per line', () async {
      final String text = WordBookExporter.encode(
        await bookWords(),
        WordBookExportFormat.txt,
      );
      expect(text.split('\n').where((String l) => l.isNotEmpty), <String>[
        'plain',
        'quote',
      ]);
    });

    test('csv quotes separators, quotes and line breaks', () async {
      final String csv = WordBookExporter.encode(
        await bookWords(),
        WordBookExportFormat.csv,
      );
      final List<String> lines = const LineSplitter().convert(csv);
      expect(lines.first, WordBookExporter.csvColumns.join(','));
      expect(csv, contains('plain'));
      // The comma, the quote and the newline all stay inside one quoted field.
      expect(csv, contains('"a, b ""c""\nsecond line"'));
      expect(csv, isNot(contains('removed')));
    });

    test('json is valid and structured', () async {
      final String json = WordBookExporter.encode(
        await bookWords(),
        WordBookExportFormat.json,
      );
      final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
      expect(decoded.length, 2);
      final Map<String, dynamic> first = decoded.first as Map<String, dynamic>;
      expect(first['word'], 'plain');
      expect(first['phonetic'], 'pleɪn');
      expect(first['translation'], '简单的');
      expect(first.containsKey('note'), isTrue);
    });
  });
}
