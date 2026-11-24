import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/text/dictionary_text.dart';
import 'package:materialword/core/repositories/word_repository.dart';

import 'helpers/test_env.dart';

/// DATA01 — literal `\n` escapes are repaired everywhere they can enter.
/// DATA05/DATA06/DATA07 — the dashboard numbers are derived from real rows and
/// survive a day rollover.
void main() {
  group('DATA01 词典文本规范化', () {
    test('字面量 \\n 被还原为换行', () {
      expect(normalizeDictionaryText(r'v. 放弃\nn. 放任'), 'v. 放弃\nn. 放任');
      expect(normalizeDictionaryText(r'a\r\nb\rc\td'), 'a\nb\nc d');
    });

    test('CRLF 与多余空白被统一，且幂等', () {
      final String once = normalizeDictionaryText('a\r\n\r\n\r\nb   \r\nc');
      expect(once, 'a\n\nb\nc');
      expect(normalizeDictionaryText(once), once);
    });

    test('用户笔记不参与规范化', () {
      expect(kUserAuthoredFields, contains('note'));
      expect(kDictionaryFields, isNot(contains('note')));
      expect(needsDictionaryNormalization(r'keep\this'), isTrue);
      expect(needsDictionaryNormalization('普通笔记'), isFalse);
    });

    test('导入路径解析时规范化字面量换行', () async {
      final TestEnv env = await TestEnv.create();
      final service = env.importService();
      final preview = service.parseContent(
        r'''word,translation
apple,"n. 苹果\nn. 苹果树"''',
        format: 'csv',
        name: 'x.csv',
      );
      expect(preview.entries.single.translation, 'n. 苹果\nn. 苹果树');
      await env.dispose();
    });

    test('写入词条时规范化，但不破坏笔记', () async {
      final TestEnv env = await TestEnv.create();
      final word = await env.words.ensureWord(
        text: 'literal',
        translation: r'词义\n第二行',
        note: r'我的笔记\n保留反斜杠',
        now: env.clock.now(),
      );
      expect(word.translation, '词义\n第二行');
      expect(word.note, r'我的笔记\n保留反斜杠');
      await env.dispose();
    });
  });

  group('DATA05/06 今日数据来自真实数据库', () {
    test('空词库剩余新词为 0，而不是目标值', () async {
      final TestEnv env = await TestEnv.create();
      final today = await env.study.todayProgress(
        now: env.clock.now(),
        newTarget: 30,
        reviewLimit: 100,
      );
      expect(today.totalWords, 0);
      expect(today.unlearnedTotal, 0);
      expect(today.newRemainingAllowance, 30);
      expect(today.newAvailableToday, 0);
      expect(today.hasWork, isFalse);
      await env.dispose();
    });

    test('可学新词 = min(剩余额度, 实际未学习数)', () async {
      final TestEnv env = await TestEnv.create();
      await env.seedBook(words: List<String>.generate(5, (int i) => 'w$i'));
      final today = await env.study.todayProgress(
        now: env.clock.now(),
        newTarget: 30,
        reviewLimit: 100,
      );
      expect(today.unlearnedTotal, 5);
      expect(today.newAvailableToday, 5);
      await env.dispose();
    });

    test('已删除单词不计入总数、已学数与到期数', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(words: <String>['alpha', 'beta']);
      final rows = await env.words.listWords(bookId: book.id);
      final target = rows.first.word;
      await env.study.recordAnswer(
        wordId: target.id,
        result: AnswerResult.unknown,
        type: ReviewType.study,
        eventId: 'e1',
        deviceId: 'dev',
        now: env.clock.now(),
      );
      expect(await env.study.totalCount(bookId: book.id), 2);
      expect(
        await env.study.dueCount(now: env.clock.now(), bookId: book.id),
        0,
      );

      await env.words.softDelete(target.id, now: env.clock.now());
      final today = await env.study.todayProgress(
        now: env.clock.now(),
        newTarget: 30,
        reviewLimit: 100,
        bookId: book.id,
      );
      expect(today.totalWords, 1);
      expect(today.learnedWords, 0);
      expect(today.dueTotal, 0);
      expect(today.newAvailableToday, 1);
      await env.dispose();
    });

    test('移出词书的单词不再计入该词书，但保留在库中', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(words: <String>['alpha', 'beta']);
      final rows = await env.words.listWords(bookId: book.id);
      await env.books.removeWord(
        book.id,
        rows.first.word.id,
        now: env.clock.now(),
      );
      expect(await env.books.wordCount(book.id), 1);
      expect(await env.study.totalCount(bookId: book.id), 1);
      expect(await env.study.totalCount(), 2);
      await env.dispose();
    });
  });

  group('DATA07 跨日刷新', () {
    test('新词完成后剩余额度下降，跨日后重新计入', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(
        words: List<String>.generate(4, (int i) => 'd$i'),
      );
      final rows = await env.words.listWords(bookId: book.id);
      await env.study.recordAnswer(
        wordId: rows.first.word.id,
        result: AnswerResult.known,
        type: ReviewType.study,
        eventId: 'a1',
        deviceId: 'dev',
        now: env.clock.now(),
      );
      var today = await env.study.todayProgress(
        now: env.clock.now(),
        newTarget: 2,
        reviewLimit: 10,
        bookId: book.id,
      );
      expect(today.newDone, 1);
      expect(today.newRemainingAllowance, 1);
      expect(today.newAvailableToday, 1);

      env.clock.nextDay();
      today = await env.study.todayProgress(
        now: env.clock.now(),
        newTarget: 2,
        reviewLimit: 10,
        bookId: book.id,
      );
      expect(today.newDone, 0);
      expect(today.newRemainingAllowance, 2);
      expect(today.newAvailableToday, 2);
      await env.dispose();
    });
  });

  group('统计口径', () {
    test('没有作答记录时正确率为 null，而不是 0%', () async {
      final TestEnv env = await TestEnv.create();
      await env.seedBook(words: <String>['alpha']);
      final stats = await env.study.statistics(now: env.clock.now());
      expect(stats.totalAnswers, 0);
      expect(stats.hasAnswers, isFalse);
      expect(stats.accuracyOrNull, isNull);
      await env.dispose();
    });

    test('按词书筛选统计', () async {
      final TestEnv env = await TestEnv.create();
      final first = await env.seedBook(
        name: '书一',
        words: <String>['alpha', 'beta'],
      );
      final second = await env.seedBook(name: '书二', words: <String>['gamma']);
      final all = await env.study.statistics(now: env.clock.now());
      final onlyFirst = await env.study.statistics(
        now: env.clock.now(),
        bookId: first.id,
      );
      final onlySecond = await env.study.statistics(
        now: env.clock.now(),
        bookId: second.id,
      );
      expect(all.totalWords, 3);
      expect(onlyFirst.totalWords, 2);
      expect(onlySecond.totalWords, 1);
      expect(onlyFirst.scopedToBook, isTrue);
      await env.dispose();
    });

    test('手动标记掌握与重置进度都是可重放的事件', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(words: <String>['alpha']);
      final row = (await env.words.listWords(bookId: book.id)).single;

      await env.study.markMastered(
        wordId: row.word.id,
        deviceId: 'dev',
        now: env.clock.now(),
        eventId: 'm1',
      );
      var state = await env.words.stateFor(row.word.id);
      expect(state, isNotNull);
      expect(state!.stage, isNot(0));
      expect(state.correctCount, 0, reason: '人工管理不伪造正确作答');
      expect(state.intervalDays, 30);

      await env.study.resetProgress(
        wordId: row.word.id,
        deviceId: 'dev',
        now: env.clock.now().add(const Duration(minutes: 1)),
        eventId: 'r1',
      );
      state = await env.words.stateFor(row.word.id);
      expect(state, isNull, reason: '重置后应回到未学习状态');

      // The history is preserved and replayable.
      final events = await env.words.eventsForWord(row.word.id);
      expect(events.length, 2);
      expect(events.any((e) => e.mode == ReviewEventMode.reset), isTrue);
      await env.dispose();
    });
  });

  group('词汇管理查询', () {
    test('筛选、排序与搜索都只返回真实词条', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(
        words: <String>['alpha', 'beta', 'gamma'],
      );
      final rows = await env.words.listWords(bookId: book.id);
      // Make beta hard.
      final beta = rows.firstWhere((WordWithState w) => w.word.word == 'beta');
      for (int i = 0; i < 2; i++) {
        await env.study.recordAnswer(
          wordId: beta.word.id,
          result: AnswerResult.unknown,
          type: ReviewType.study,
          eventId: 'b$i',
          deviceId: 'dev',
          now: env.clock.now().add(Duration(minutes: i)),
        );
      }
      final hard = await env.study.managedWords(
        stage: ManagedStageFilter.hard,
        sort: ManagedSort.wrongDesc,
      );
      expect(hard.map((m) => m.word.word), <String>['beta']);
      expect(hard.single.errorRate, 1.0);

      final searched = await env.study.managedWords(search: 'bet');
      expect(searched.map((m) => m.word.word), <String>['beta']);

      final unlearned = await env.study.managedWords(
        stage: ManagedStageFilter.unlearned,
      );
      expect(unlearned.length, 2);
      expect(await env.study.managedCount(), 3);
      await env.dispose();
    });
  });
}
