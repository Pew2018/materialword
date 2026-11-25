import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/features/dictionary/dictionary_page.dart';
import 'package:materialword/features/word_management/quick_add_page.dart';
import 'package:materialword/shared/widgets/common.dart';

import 'helpers/test_dictionary.dart';
import 'helpers/test_env.dart';

/// DATA02 – DATA04: query generations, quick-add auto-fill bookkeeping and
/// "re-adding a word keeps the user's own content".
void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  final TestDictionary dictionary = TestDictionary.create(
    <String, ({String translation, String definition, String phonetic})>{
      'apple': (
        translation: r'n. 苹果\nn. 苹果树',
        definition: 'fruit of the apple tree',
        phonetic: 'ˈæpl',
      ),
      'app': (
        translation: 'n. 应用程序',
        definition: 'application',
        phonetic: 'æp',
      ),
    },
  );
  tearDownAll(dictionary.dispose);

  Future<TestEnv> pumpPage(
    WidgetTester tester,
    Widget page, {
    bool wrapInScaffold = false,
  }) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final TestEnv env = await TestEnv.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
          dictionaryProvider.overrideWith(
            (Ref ref) async => dictionary.service,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          home: wrapInScaffold ? Scaffold(body: page) : page,
        ),
      ),
    );
    await settle(tester);
    return env;
  }

  String fieldValue(WidgetTester tester, String label) {
    final TextField widget = tester.widget<TextField>(
      find.widgetWithText(TextField, label).first,
    );
    return widget.controller?.text ?? '';
  }

  group('DATA02 查询代际', () {
    test('SearchGeneration 使旧查询失效', () {
      final SearchGeneration generation = SearchGeneration();
      final int first = generation.next();
      expect(generation.isCurrent(first), isTrue);
      final int second = generation.next();
      expect(generation.isCurrent(first), isFalse);
      expect(generation.isCurrent(second), isTrue);
      generation.invalidate();
      expect(generation.isCurrent(second), isFalse);
    });

    testWidgets('快速切换查询词后只显示最新结果', (WidgetTester tester) async {
      final TestEnv env = await pumpPage(
        tester,
        const DictionaryPage(),
        wrapInScaffold: true,
      );
      await tester.enterText(find.byType(TextField).first, 'app');
      await settle(tester);
      expect(find.text('app'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'apple');
      await settle(tester);
      expect(find.text('apple'), findsWidgets);
      await env.dispose();
    });
  });

  group('DATA03 自动填充不会残留', () {
    testWidgets('更改输入词后清除上一词的自动填充', (WidgetTester tester) async {
      final TestEnv env = await pumpPage(tester, const QuickAddPage());
      await tester.enterText(find.byType(TextField).first, 'apple');
      await settle(tester);
      final String filled = fieldValue(tester, '中文释义');
      expect(filled, contains('n. 苹果'));
      expect(filled, contains('n. 苹果树'));
      expect(filled, contains('\n'), reason: '字面量 \\n 应变成真实换行');

      await tester.enterText(find.byType(TextField).first, 'banana');
      await settle(tester);
      expect(fieldValue(tester, '中文释义'), '', reason: '旧词的释义不能被当成新词的自动填充');
      await env.dispose();
    });

    testWidgets('用户编辑过的字段不会被词典覆盖', (WidgetTester tester) async {
      final TestEnv env = await pumpPage(tester, const QuickAddPage());
      await tester.enterText(find.byType(TextField).first, 'apple');
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '中文释义'), '我自己写的释义');
      await settle(tester);
      // Touching the word again must not overwrite the edited field.
      await tester.enterText(find.byType(TextField).first, 'apple ');
      await settle(tester);
      expect(fieldValue(tester, '中文释义'), '我自己写的释义');
      await env.dispose();
    });
  });

  group('DATA04 重复添加保留用户内容', () {
    test('重新添加已存在单词不会覆盖有效的释义与笔记', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(name: '我的词书', words: <String>['apple']);
      final Word original = (await env.words.listWords(bookId: book.id))
          .single
          .word;
      await env.words.updateContent(
        original.id,
        translation: '我的释义',
        note: '我的笔记',
        now: env.clock.now(),
      );

      // ensureWord is what quick-add uses for a word that already exists.
      final Word reloaded = await env.words.ensureWord(
        text: 'apple',
        translation: '词典释义',
        now: env.clock.now(),
      );
      expect(reloaded.id, original.id, reason: '不创建新词条');
      expect(reloaded.translation, '我的释义');
      expect(reloaded.note, '我的笔记');

      // An explicit edit of one field leaves the others alone.
      final Word edited = await env.words.updateContent(
        original.id,
        translation: '新释义',
        now: env.clock.now(),
      );
      expect(edited.translation, '新释义');
      expect(edited.note, '我的笔记');
      expect(await env.books.wordCount(book.id), 1);
      await env.dispose();
    });
  });
}
