import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/practice_session.dart';

import 'helpers/test_env.dart';

/// Phase 4B regressions: fair coverage, real eligibility, the answer state
/// machine, persistence across a restart, stale-question protection and
/// distractor quality.
void main() {
  late TestEnv env;

  setUp(() async {
    env = await TestEnv.create();
  });

  tearDown(() async {
    await env.dispose();
  });

  Future<PracticeSession> fresh(
    PracticeKind kind, {
    String? bookId,
    int limit = 20,
  }) async {
    final PracticeSession session = PracticeSession(
      env.study,
      env.settings,
      env.clock,
    );
    addTearDown(session.dispose);
    await session.load(kind: kind, bookId: bookId, limit: limit, resume: false);
    return session;
  }

  /// Answers every question of [session] correctly, leaving it finished.
  Future<List<String>> answerAll(PracticeSession session) async {
    final List<String> answered = <String>[];
    while (!session.isFinished) {
      final PracticeQuestion? question = session.current;
      if (question == null) break;
      answered.add(question.word.id);
      final PracticeOutcome? outcome = question.kind == PracticeKind.choice
          ? await session.submitChoice(question.correctIndex ?? 0)
          : await session.submitTyped(question.answer);
      expect(outcome, isNotNull);
      expect(session.advance(), isTrue);
    }
    await session.flush();
    return answered;
  }

  /// Bulk-seeds [count] words into one book. [examplesFrom] marks the index from
  /// which words carry an example sentence that really contains the word.
  ///
  /// Spellings are zero-padded so the alphabetical order the scheduler uses
  /// matches the numeric index — otherwise the ordering assertions below would
  /// be about lexicographic accidents instead of coverage.
  Future<WordBook> seedLarge(
    int count, {
    int examplesFrom = -1,
    String? name,
  }) async {
    final WordBook book = await env.books.create(
      name: name ?? 'large-$count',
      now: env.clock.now(),
    );
    String spelling(int i) => 'word${i.toString().padLeft(5, '0')}';
    const int chunk = 2000;
    for (int start = 0; start < count; start += chunk) {
      final int end = (start + chunk).clamp(0, count);
      await env.db.batch((batch) {
        batch.insertAll(env.db.words, <WordsCompanion>[
          for (int i = start; i < end; i++)
            WordsCompanion.insert(
              id: 'w$i',
              word: spelling(i),
              normalized: spelling(i),
              translation: Value('释义 $i'),
              example: Value(
                examplesFrom >= 0 && i >= examplesFrom
                    ? 'The ${spelling(i)} appears in this sentence.'
                    : '',
              ),
              createdAt: 1,
              updatedAt: 1,
            ),
        ]);
        batch.insertAll(env.db.wordBookEntries, <WordBookEntriesCompanion>[
          for (int i = start; i < end; i++)
            WordBookEntriesCompanion.insert(
              wordBookId: book.id,
              wordId: 'w$i',
              addedAt: 1,
            ),
        ]);
      });
    }
    return book;
  }

  group('4B-01 fair coverage', () {
    test('two rounds over 20 words cover all of them exactly once', () async {
      final WordBook book = await env.seedBook(
        words: <String>[
          for (int i = 0; i < 20; i++) 'word${i.toString().padLeft(2, '0')}',
        ],
      );

      final PracticeSession first = await fresh(
        PracticeKind.spelling,
        bookId: book.id,
        limit: 10,
      );
      final List<String> roundOne = await answerAll(first);
      expect(roundOne, hasLength(10));

      final PracticeSession second = await fresh(
        PracticeKind.spelling,
        bookId: book.id,
        limit: 10,
      );
      final List<String> roundTwo = await answerAll(second);
      expect(roundTwo, hasLength(10));

      expect(
        roundOne.toSet().intersection(roundTwo.toSet()),
        isEmpty,
        reason: 'the second round must cover the words the first one left',
      );
      expect(roundOne.toSet().union(roundTwo.toSet()), hasLength(20));

      // A third round has nothing left to cover but must not run dry.
      final PracticeSession third = await fresh(
        PracticeKind.spelling,
        bookId: book.id,
        limit: 10,
      );
      expect(third.total, 10);
    });

    test('40 rounds over 800 words reach every word', () async {
      final WordBook book = await seedLarge(800);
      final Set<String> seen = <String>{};
      int duplicates = 0;
      for (int round = 0; round < 40; round++) {
        final PracticeSession session = await fresh(
          PracticeKind.spelling,
          bookId: book.id,
          limit: 20,
        );
        for (final String id in await answerAll(session)) {
          if (!seen.add(id)) duplicates++;
        }
      }
      expect(seen, hasLength(800), reason: 'coverage must be exhaustive');
      expect(duplicates, 0, reason: 'no word should repeat before the rest');
    });

    test('5000-word book is walked progressively, not repeated', () async {
      final WordBook book = await seedLarge(5000);
      final Set<String> seen = <String>{};
      for (int round = 0; round < 15; round++) {
        final PracticeSession session = await fresh(
          PracticeKind.spelling,
          bookId: book.id,
          limit: 20,
        );
        seen.addAll(await answerAll(session));
      }
      expect(seen, hasLength(300));
    });

    test('20000-word book serves new words instead of one fixed head', () async {
      final WordBook book = await seedLarge(20000);
      final Set<String> seen = <String>{};
      // Ten rounds of 20 = 200 slots. The old implementation read one 120-row
      // window ordered by `last_studied_at`, so it could never reach index 199.
      for (int round = 0; round < 10; round++) {
        final PracticeSession session = await fresh(
          PracticeKind.spelling,
          bookId: book.id,
          limit: 20,
        );
        seen.addAll(await answerAll(session));
      }
      expect(seen, hasLength(200));
      final List<int> indexes =
          seen.map((String id) => int.parse(id.substring(1))).toList()..sort();
      expect(indexes.first, 0);
      expect(indexes.last, 199);
    });

    test(
      'a wrong word gets priority without filling the whole round',
      () async {
        final List<String> words = <String>[
          for (int i = 0; i < 40; i++) 'word${i.toString().padLeft(2, '0')}',
        ];
        final WordBook book = await env.seedBook(words: words);
        // Make three words genuinely hard: repeated failures in real answer
        // events, which is what the priority signal reads.
        final List<Word> rows = await env.books.wordsInBook(book.id);
        final List<Word> hard = rows.take(3).toList();
        for (final Word word in hard) {
          for (int i = 0; i < 4; i++) {
            await env.study.recordAnswer(
              wordId: word.id,
              result: AnswerResult.unknown,
              type: ReviewType.review,
              eventId: 'hard-${word.id}-$i',
              deviceId: 'test-device',
              now: env.clock.now(),
            );
          }
        }

        final PracticeSession session = await fresh(
          PracticeKind.spelling,
          bookId: book.id,
          limit: 20,
        );
        final List<String> ids = <String>[];
        while (!session.isFinished) {
          ids.add(session.current!.word.id);
          await session.submitTyped(session.current!.answer);
          session.advance();
        }
        expect(ids, hasLength(20));
        expect(
          ids.where(hard.map((Word w) => w.id).toSet().contains).length,
          3,
          reason: 'hard words are asked, but only once each',
        );
        expect(
          ids.where((String id) => !hard.any((Word w) => w.id == id)).length,
          greaterThanOrEqualTo(15),
          reason: 'the round must still leave room for other words',
        );
      },
    );

    test('switching book switches the coverage scope', () async {
      final WordBook bookA = await env.seedBook(
        name: 'A',
        words: <String>['alpha', 'beta'],
      );
      final WordBook bookB = await env.seedBook(
        name: 'B',
        words: <String>['gamma', 'delta'],
      );

      final PracticeSession inA = await fresh(
        PracticeKind.spelling,
        bookId: bookA.id,
        limit: 20,
      );
      final List<String> answeredA = await answerAll(inA);
      expect(answeredA, hasLength(2));

      final PracticeSession inB = await fresh(
        PracticeKind.spelling,
        bookId: bookB.id,
        limit: 20,
      );
      final List<String> answeredB = <String>[];
      while (inB.current != null) {
        answeredB.add(inB.current!.word.id);
        await inB.submitTyped(inB.current!.answer);
        inB.advance();
      }
      expect(
        answeredB.toSet().intersection(answeredA.toSet()),
        isEmpty,
        reason: 'book B must not inherit book A coverage',
      );
    });

    test('a word deleted mid-book no longer appears in later rounds', () async {
      final WordBook book = await env.seedBook(
        words: <String>['alpha', 'beta', 'gamma'],
      );
      final PracticeSession first = await fresh(
        PracticeKind.spelling,
        bookId: book.id,
      );
      final List<String> answered = <String>[];
      while (first.current != null) {
        answered.add(first.current!.word.id);
        await first.submitTyped(first.current!.answer);
        first.advance();
      }
      expect(answered, hasLength(3));

      await env.words.softDelete(answered.first, now: env.clock.now());

      final PracticeSession second = await fresh(
        PracticeKind.spelling,
        bookId: book.id,
      );
      final List<String> secondIds = <String>[];
      while (second.current != null) {
        secondIds.add(second.current!.word.id);
        await second.submitTyped(second.current!.answer);
        second.advance();
      }
      expect(secondIds, isNot(contains(answered.first)));
      expect(second.total, 2);
    });
  });

  group('4B-02 cloze eligibility', () {
    test('examples buried past the old window are still used', () async {
      // 300 words, examples only on the last five. The previous implementation
      // read a 120-row window, filtered it to nothing and reported "no words".
      final WordBook book = await seedLarge(300, examplesFrom: 295);
      final PracticeSession session = await fresh(
        PracticeKind.cloze,
        bookId: book.id,
        limit: 20,
      );
      expect(session.total, 5);
      final List<String> ids = <String>[];
      while (session.current != null) {
        final PracticeQuestion question = session.current!;
        ids.add(question.word.id);
        expect(question.prompt, contains('____'));
        await session.submitTyped(question.answer);
        session.advance();
      }
      expect(ids.toSet(), <String>{'w295', 'w296', 'w297', 'w298', 'w299'});
    });

    test('an example that does not contain the word is never used', () async {
      final WordBook book = await env.books.create(
        name: 'bad-example',
        now: env.clock.now(),
      );
      final Word word = await env.words.ensureWord(
        text: 'harvest',
        translation: '收获',
        // "harvests" is a different token: the drill must not blank it out.
        example: 'The harvests were good.',
        now: env.clock.now(),
      );
      await env.books.addWords(book.id, <String>[
        word.id,
      ], now: env.clock.now());

      final PracticeSession session = await fresh(
        PracticeKind.cloze,
        bookId: book.id,
      );
      // "harvests" contains "harvest" but not as a word: the boundary rule
      // rejects it, so no question is invented.
      expect(session.total, 0);
      expect(session.isEmpty, isTrue);
    });

    test('cloze never fabricates a question to fill the round', () async {
      final WordBook book = await seedLarge(50, examplesFrom: 45);
      final PracticeSession session = await fresh(
        PracticeKind.cloze,
        bookId: book.id,
        limit: 20,
      );
      // Asked for 20, only 5 are legitimate. Fewer real questions beat filler.
      expect(session.total, 5);
    });
  });

  group('4B-04 persistence and restore', () {
    test('an interrupted drill resumes on the same word', () async {
      final WordBook book = await env.seedBook(
        words: <String>['alpha', 'beta', 'gamma', 'delta'],
      );
      final PracticeSession first = await fresh(
        PracticeKind.spelling,
        bookId: book.id,
        limit: 2,
      );
      final String answeredId = first.current!.word.id;
      await first.submitTyped(first.current!.answer);
      first.advance();
      final String nextId = first.current!.word.id;
      expect(nextId, isNot(answeredId));

      // "Process restart": a brand-new session over the same database.
      final PracticeSession restored = PracticeSession(
        env.study,
        env.settings,
        env.clock,
      );
      addTearDown(restored.dispose);
      await restored.load(
        kind: PracticeKind.spelling,
        bookId: book.id,
        limit: 2,
      );
      expect(restored.phase, PracticePhase.question);
      expect(restored.current!.word.id, nextId);
      expect(restored.position, 1);
      expect(restored.answeredCount, 1);
      expect(restored.correctCount, 1);
      expect(restored.total, 2);

      // The restored drill does not re-write the answer it already saved.
      final List<ReviewEvent> events = await env.db
          .select(env.db.reviewEvents)
          .get();
      expect(events, hasLength(1));
    });

    test(
      'a different drill kind or book does not hijack the saved attempt',
      () async {
        final WordBook bookA = await env.seedBook(
          name: 'A',
          words: <String>['alpha', 'beta'],
        );
        final WordBook bookB = await env.seedBook(
          name: 'B',
          words: <String>['gamma', 'delta'],
        );
        final PracticeSession first = await fresh(
          PracticeKind.spelling,
          bookId: bookA.id,
        );
        await first.submitTyped(first.current!.answer);
        first.advance();

        final PracticeSession otherKind = PracticeSession(
          env.study,
          env.settings,
          env.clock,
        );
        addTearDown(otherKind.dispose);
        await otherKind.load(kind: PracticeKind.dictation, bookId: bookA.id);
        expect(otherKind.answeredCount, 0);
        expect(otherKind.phase, PracticePhase.question);

        final PracticeSession otherBook = PracticeSession(
          env.study,
          env.settings,
          env.clock,
        );
        addTearDown(otherBook.dispose);
        await otherBook.load(kind: PracticeKind.spelling, bookId: bookB.id);
        expect(otherBook.answeredCount, 0);
        expect(otherBook.current!.word.word, anyOf('gamma', 'delta'));
      },
    );

    test(
      'a corrupted blob is discarded instead of crashing the drill',
      () async {
        final WordBook book = await env.seedBook(
          words: <String>['alpha', 'beta'],
        );
        await env.db.writeMeta(
          PracticeSession.persistenceKey,
          '{"version":1,"kind":"spelling","questions":oops',
        );
        final PracticeSession session = PracticeSession(
          env.study,
          env.settings,
          env.clock,
        );
        addTearDown(session.dispose);
        await session.load(kind: PracticeKind.spelling, bookId: book.id);
        // A broken blob must not stop the drill: it starts a clean round.
        expect(session.phase, PracticePhase.question);
        expect(session.total, 2);
        expect(session.answeredCount, 0);
      },
    );

    test(
      'a word deleted while the app was closed is dropped on restore',
      () async {
        final WordBook book = await env.seedBook(
          words: <String>['alpha', 'beta', 'gamma'],
        );
        final PracticeSession first = await fresh(
          PracticeKind.spelling,
          bookId: book.id,
        );
        final String removed = first.current!.word.id;
        await env.words.softDelete(removed, now: env.clock.now());

        final PracticeSession restored = PracticeSession(
          env.study,
          env.settings,
          env.clock,
        );
        addTearDown(restored.dispose);
        await restored.load(kind: PracticeKind.spelling, bookId: book.id);
        expect(restored.phase, PracticePhase.question);
        expect(restored.total, 2);
        final Set<String> ids = <String>{};
        while (restored.current != null) {
          ids.add(restored.current!.word.id);
          await restored.submitTyped(restored.current!.answer);
          restored.advance();
        }
        expect(ids, isNot(contains(removed)));
        expect(ids, hasLength(2));
      },
    );

    test('a finished drill clears its saved attempt', () async {
      final WordBook book = await env.seedBook(
        words: <String>['alpha', 'beta'],
      );
      final PracticeSession session = await fresh(
        PracticeKind.spelling,
        bookId: book.id,
      );
      await answerAll(session);
      expect(session.isFinished, isTrue);
      expect(await env.db.readMeta(PracticeSession.persistenceKey), isNull);
    });

    test('wrong words and skips survive a restore', () async {
      final WordBook book = await env.seedBook(
        words: <String>['alpha', 'beta', 'gamma', 'delta'],
      );
      final PracticeSession first = await fresh(
        PracticeKind.spelling,
        bookId: book.id,
      );
      expect(first.skip(), isTrue);
      await first.submitTyped('definitely-wrong');
      first.advance();
      await first.flush();

      final PracticeSession restored = PracticeSession(
        env.study,
        env.settings,
        env.clock,
      );
      addTearDown(restored.dispose);
      await restored.load(kind: PracticeKind.spelling, bookId: book.id);
      expect(restored.skippedCount, 1);
      expect(restored.answeredCount, 1);
      expect(restored.correctCount, 0);
      expect(restored.summary().wrongWords, hasLength(1));
      expect(restored.canUndo, isTrue);
    });

    test('a restore never leaks into the normal study session', () async {
      final WordBook book = await env.seedBook(
        words: <String>['alpha', 'beta'],
      );
      final PracticeSession session = await fresh(
        PracticeKind.spelling,
        bookId: book.id,
      );
      await session.submitTyped(session.current!.answer);

      // The drill writes its own key and nothing else.
      expect(await env.db.readMeta(PracticeSession.persistenceKey), isNotNull);
      expect(await env.db.readMeta('active_study_session_v1'), isNull);
    });
  });

  group('4B-06 distractor quality', () {
    test(
      'a word that shares any real sense with the answer is excluded',
      () async {
        final WordBook book = await env.books.create(
          name: 'synonyms',
          now: env.clock.now(),
        );
        final List<Word> words = <Word>[
          await env.words.ensureWord(
            text: 'harvest',
            translation: 'n. 收获；收成',
            now: env.clock.now(),
          ),
          // Shares "收获" but has a different first sense — the old
          // first-segment-only check would have offered this as a distractor.
          await env.words.ensureWord(
            text: 'reap',
            translation: 'v. 收割；收获',
            now: env.clock.now(),
          ),
          await env.words.ensureWord(
            text: 'meadow',
            translation: '草地',
            now: env.clock.now(),
          ),
          await env.words.ensureWord(
            text: 'lantern',
            translation: '灯笼',
            now: env.clock.now(),
          ),
        ];
        await env.books.addWords(
          book.id,
          words.map((Word w) => w.id).toList(),
          now: env.clock.now(),
        );

        final PracticeSession session = await fresh(
          PracticeKind.choice,
          bookId: book.id,
          limit: 20,
        );
        while (session.current != null) {
          final PracticeQuestion question = session.current!;
          if (question.word.word == 'harvest') {
            expect(question.options, isNot(contains('reap')));
          }
          if (question.word.word == 'reap') {
            expect(question.options, isNot(contains('harvest')));
          }
          expect(
            question.options.toSet().length,
            question.options.length,
            reason: 'no duplicated option',
          );
          await session.submitChoice(question.correctIndex!);
          session.advance();
        }
      },
    );

    test('duplicate spellings never appear twice in one question', () async {
      final WordBook book = await env.books.create(
        name: 'dupes',
        now: env.clock.now(),
      );
      final Word answer = await env.words.ensureWord(
        text: 'ledger',
        translation: '账簿',
        now: env.clock.now(),
      );
      final List<Word> others = <Word>[
        await env.words.ensureWord(
          text: 'lantern',
          translation: '灯笼',
          now: env.clock.now(),
        ),
        await env.words.ensureWord(
          text: 'meadow',
          translation: '草地',
          now: env.clock.now(),
        ),
      ];
      await env.books.addWords(book.id, <String>[
        answer.id,
        ...others.map((Word w) => w.id),
      ], now: env.clock.now());
      final PracticeSession session = await fresh(
        PracticeKind.choice,
        bookId: book.id,
      );
      final PracticeQuestion question = session.current!;
      expect(question.options.toSet().length, question.options.length);
      expect(question.options.length, inInclusiveRange(2, 4));
    });

    test(
      'fewer than two clean options drops the word instead of padding it',
      () async {
        final WordBook book = await env.books.create(
          name: 'ambiguous',
          now: env.clock.now(),
        );
        final List<Word> words = <Word>[
          await env.words.ensureWord(
            text: 'big',
            translation: '大的',
            now: env.clock.now(),
          ),
          await env.words.ensureWord(
            text: 'large',
            translation: '大的；宽广的',
            now: env.clock.now(),
          ),
        ];
        await env.books.addWords(
          book.id,
          words.map((Word w) => w.id).toList(),
          now: env.clock.now(),
        );
        final PracticeSession session = await fresh(
          PracticeKind.choice,
          bookId: book.id,
        );
        expect(session.isEmpty, isTrue);
      },
    );
  });
}
