import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/features/dictionary/dictionary_page.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/shared/widgets/common.dart';

import 'helpers/test_dictionary.dart';
import 'helpers/test_env.dart';

void main() {
  final TestDictionary dictionary = TestDictionary.create(
    <String, ({String translation, String definition, String phonetic})>{
      'app': (
        translation: 'n. 应用程序',
        definition: 'application',
        phonetic: 'æp',
      ),
      'apple': (translation: 'n. 苹果', definition: 'fruit', phonetic: 'ˈæpl'),
    },
  );
  tearDownAll(dictionary.dispose);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<TestEnv> pumpDictionary(
    WidgetTester tester, {
    Future<void> Function(TestEnv env)? seed,
  }) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final TestEnv env = await TestEnv.create();
    if (seed != null) await seed(env);
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
          home: const Scaffold(body: DictionaryPage()),
        ),
      ),
    );
    await settle(tester);
    return env;
  }

  test('我的单词默认仍匹配英文释义，词典查询可以关掉', () async {
    final TestEnv env = await TestEnv.create();
    final observe = await env.words.ensureWord(
      text: 'observe',
      translation: '观察',
      definition: 'watch attentively',
      now: env.clock.now(),
    );
    final mourn = await env.words.ensureWord(
      text: 'mourn',
      translation: '哀悼',
      definition: 'observe the customs of mourning',
      now: env.clock.now(),
    );
    final List<String> wide = (await env.words.listWords(query: 'obse'))
        .map((row) => row.word.word)
        .toList();
    expect(wide, containsAll(<String>['mourn', 'observe']));

    final List<String> narrow = (await env.words.listWords(
      query: 'obse',
      matchDefinition: false,
    )).map((row) => row.word.word).toList();
    expect(narrow, <String>['observe']);

    await env.words.updateContent(
      mourn.id,
      note: 'personal gloss',
      now: env.clock.now(),
    );
    final List<String> byNote = (await env.words.listWords(
      query: 'personal gloss',
      matchDefinition: false,
    )).map((row) => row.word.word).toList();
    expect(byNote, <String>['mourn']);
    expect(observe.word, 'observe');
    await env.dispose();
  });

  testWidgets('词典页不因英文释义带出无关单词', (WidgetTester tester) async {
    final TestEnv env = await pumpDictionary(
      tester,
      seed: (TestEnv env) async {
        await env.words.ensureWord(
          text: 'mourn',
          translation: '哀悼',
          definition: 'observe the customs of mourning',
          now: env.clock.now(),
        );
      },
    );
    await tester.enterText(find.byType(TextField).first, 'obse');
    await settle(tester);
    expect(find.text('mourn'), findsNothing);
    expect(find.textContaining('我的单词'), findsNothing);
    await env.dispose();
  });

  testWidgets('未入库的查询结果点开只读详情，加号仍负责加入词书', (WidgetTester tester) async {
    final TestEnv env = await pumpDictionary(
      tester,
      seed: (TestEnv env) async {
        final book = await env.books.create(name: '当前', now: env.clock.now());
        await env.settings.save(currentWordBookId: Value<String?>(book.id));
      },
    );
    await tester.enterText(find.byType(TextField).first, 'app');
    await settle(tester);
    expect(find.byTooltip('加入词书'), findsWidgets);

    await tester.tap(find.widgetWithText(ListTile, 'app').first);
    await settle(tester);
    expect(find.text('单词信息'), findsOneWidget);
    expect(find.textContaining('应用程序'), findsOneWidget);
    expect(find.text('学习进度'), findsNothing);
    expect(find.text('保存'), findsNothing);
    expect(await env.words.countWords(), 0);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    await tester.tap(find.byTooltip('加入词书').first);
    await settle(tester);
    expect(find.text('已添加「app」'), findsOneWidget);
    expect(
      await env.books.wordCount((await env.books.listBooks()).single.id),
      1,
    );
    await env.dispose();
  });

  testWidgets('已在当前词书的单词点开完整详情', (WidgetTester tester) async {
    final TestEnv env = await pumpDictionary(
      tester,
      seed: (TestEnv env) async {
        final book = await env.seedBook(name: '当前', words: <String>['apple']);
        await env.settings.save(currentWordBookId: Value<String?>(book.id));
      },
    );
    await tester.enterText(find.byType(TextField).first, 'apple');
    await settle(tester);
    expect(find.text('未学'), findsOneWidget);

    await tester.tap(find.text('未学'));
    await settle(tester);
    expect(find.text('学习进度'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);

    await tester.tap(find.byType(AppBarPopupMenuButton<String>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('移出词书'), findsOneWidget);
    await env.dispose();
  });

  testWidgets('不在当前词书的已有单词不提供移出', (WidgetTester tester) async {
    final TestEnv env = await pumpDictionary(
      tester,
      seed: (TestEnv env) async {
        await env.words.ensureWord(
          text: 'apple',
          translation: '苹果',
          now: env.clock.now(),
        );
        final book = await env.books.create(name: '当前', now: env.clock.now());
        await env.settings.save(currentWordBookId: Value<String?>(book.id));
      },
    );
    await tester.enterText(find.byType(TextField).first, 'apple');
    await settle(tester);
    await tester.tap(find.text('未学'));
    await settle(tester);
    expect(find.text('学习进度'), findsOneWidget);
    await tester.tap(find.byType(AppBarPopupMenuButton<String>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('移出词书'), findsNothing);
    await env.dispose();
  });

  testWidgets('查询结果里已入库的词打开已保存详情', (WidgetTester tester) async {
    final TestEnv env = await pumpDictionary(
      tester,
      seed: (TestEnv env) async {
        await env.words.ensureWord(
          text: 'apple',
          translation: '我的苹果',
          now: env.clock.now(),
        );
      },
    );
    await tester.enterText(find.byType(TextField).first, 'apple');
    await settle(tester);
    final Finder result = find.ancestor(
      of: find.byTooltip('加入词书'),
      matching: find.byType(ListTile),
    );
    await tester.tap(result);
    await settle(tester);
    expect(find.text('学习进度'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    await env.dispose();
  });
}
