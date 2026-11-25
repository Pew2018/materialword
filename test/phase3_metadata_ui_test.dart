import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/repositories/word_metadata_repository.dart';
import 'package:materialword/features/word_management/word_management_page.dart';
import 'package:materialword/features/word_management/word_metadata_widgets.dart';

import 'helpers/test_env.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> mount(WidgetTester tester, TestEnv env, Widget home) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('UI creates, renames, cancels deletion and deletes a real tag', (
    tester,
  ) async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await mount(tester, e, const TagsPage());
    await tester.tap(find.byTooltip('创建标签'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '考试');
    await tester.tap(find.text('确定'));
    await settle(tester);
    expect((await WordMetadataRepository(e.db).listTags()).single.name, '考试');
    await tester.tap(find.text('考试'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '期末');
    await tester.tap(find.text('确定'));
    await settle(tester);
    expect(find.text('期末'), findsOneWidget);
    await tester.tap(find.byTooltip('删除标签 期末'));
    await settle(tester);
    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(await WordMetadataRepository(e.db).listTags(), hasLength(1));
    await tester.tap(find.byTooltip('删除标签 期末'));
    await settle(tester);
    await tester.tap(find.text('删除').hitTestable());
    await settle(tester);
    expect(await WordMetadataRepository(e.db).listTags(), isEmpty);
    expect(
      (await e.db.select(e.db.userTags).get()).single.deletedAt,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
    'UI favorite and tag assignment/removal persist and picker cancellation does nothing',
    (tester) async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha']);
      final id = (await e.words.byNormalized('alpha'))!.id;
      final repo = WordMetadataRepository(e.db);
      final tag = await repo.createTag('考试', now: e.clock.now());
      await mount(
        tester,
        e,
        Scaffold(
          appBar: AppBar(actions: [FavoriteButton(wordId: id)]),
          body: WordTagsEditor(wordId: id),
        ),
      );
      await tester.tap(find.byTooltip('收藏单词'));
      await settle(tester);
      expect(
        (await e.db.select(e.db.wordFavorites).get()).single.value,
        isTrue,
      );
      await tester.tap(find.text('添加标签'));
      await settle(tester);
      await tester.tapAt(const Offset(8, 550));
      await settle(tester);
      expect(await e.db.select(e.db.wordTags).get(), isEmpty);
      await tester.tap(find.text('添加标签'));
      await settle(tester);
      await tester.tap(find.text('考试').hitTestable());
      await settle(tester);
      expect((await e.db.select(e.db.wordTags).get()).single.tagId, tag.id);
      final chip = tester.widget<InputChip>(find.byType(InputChip));
      expect(chip.deleteButtonTooltipMessage, '移除标签 考试');
      await tester.tap(find.byTooltip('移除标签 考试'));
      await settle(tester);
      expect(find.byType(InputChip), findsNothing);
      expect(
        (await e.db.select(e.db.wordTags).get()).single.deletedAt,
        isNotNull,
      );
      await tester.tap(find.byTooltip('取消收藏'));
      await settle(tester);
      expect(
        (await e.db.select(e.db.wordFavorites).get()).single.value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'UI favorites filter and all-filtered batch removal use current matching IDs',
    (tester) async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(
        words: List.generate(150, (i) => 'word${i.toString().padLeft(3, '0')}'),
      );
      final repo = WordMetadataRepository(e.db),
          ids = await e.study.managedWordIds();
      await repo.setFavorite(ids.take(121), true, now: e.clock.now());
      await mount(tester, e, const WordManagementPage());
      await tester.tap(find.text('仅收藏'));
      await settle(tester);
      expect(find.text('全部单词（121）'), findsOneWidget);
      await tester.ensureVisible(find.text('选择全部 121 项'));
      await tester.tap(find.text('选择全部 121 项'));
      await settle(tester);
      expect(find.text('已选 121'), findsOneWidget);
      await tester.tap(find.byTooltip('收藏与标签批量操作'));
      await settle(tester);
      await tester.tap(find.text('取消收藏'));
      await settle(tester);
      expect(await e.study.managedCount(favoritesOnly: true), 0);
      expect(find.text('没有符合条件的单词'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );
}
