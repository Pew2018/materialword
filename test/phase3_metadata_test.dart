import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/repositories/study_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/repositories/word_metadata_repository.dart';
import 'package:materialword/services/backup_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 25, 12);
  WordMetadataRepository repo(TestEnv e) => WordMetadataRepository(e.db);
  Future<void> transfer(TestEnv a, TestEnv b) async => b.backup.mergeDataset(
    jsonDecode(await a.backup.exportToJson(now: now)) as Map<String, Object?>,
    now: now,
  );
  Future<String> hash(TestEnv e) async =>
      BackupService.contentHashOf(await e.backup.buildDataset(now: now));

  test('favorites, multiple tags, rename and relation removal persist across reopen', () async {
    final e = await TestEnv.create(file: true);
    addTearDown(() => Directory(e.filePath!).parent.delete(recursive: true));
    await e.seedBook(words: ['alpha', 'beta']);
    final words = await e.study.managedWordIds();
    final one = await repo(e).createTag('考试', now: now);
    final two = await repo(e).createTag('易错', now: now);
    expect((await repo(e).createTag(' 考试 ', now: now)).id, one.id);
    await repo(e).setFavorite(words, true, now: now);
    await repo(e).setTag(words, one.id, true, now: now);
    await repo(e).setTag([words.first], two.id, true, now: now);
    await repo(e).renameTag(one.id, '期末考试', now: now);
    expect(await repo(e).watchTags(wordId: words.first).first, hasLength(2));
    await repo(e).setTag([words.last], one.id, false, now: now);
    expect(await e.study.managedCount(tagId: one.id), 1);
    expect(await e.study.managedCount(favoritesOnly: true), 2);
    // A second file-backed connection proves this is stored data, not widget state.
    await e.db.close();
    final reopened = AppDatabase(NativeDatabase(File(e.filePath!)));
    addTearDown(reopened.close);
    final reopenedMetadata = WordMetadataRepository(reopened);
    expect(await reopenedMetadata.watchFavorite(words.first).first, isTrue);
    expect(
      (await reopenedMetadata.listTags()).map((t) => t.name),
      contains('期末考试'),
    );
    expect(await StudyRepository(reopened).managedCount(tagId: one.id), 1);
  });

  test('three independent devices converge favorites, tags, aliases and renamed tag relations', () async {
    final a = await TestEnv.create(),
        b = await TestEnv.create(),
        c = await TestEnv.create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    addTearDown(c.dispose);
    await a.seedBook(words: ['alpha']);
    await b.seedBook(words: ['alpha']);
    final aw = (await a.words.byNormalized('alpha'))!,
        bw = (await b.words.byNormalized('alpha'))!;
    final at = await repo(a).createTag('exam', now: now),
        bt = await repo(b).createTag('exam', now: now);
    await repo(a).setFavorite([aw.id], true, now: now);
    await repo(b).setTag([bw.id], bt.id, true, now: now);
    await transfer(a, b);
    await transfer(b, a);
    expect(await repo(a).watchTags(wordId: aw.id).first, hasLength(1));
    await repo(a).renameTag(at.id, 'final exam', now: now);
    await transfer(a, b);
    await transfer(b, c);
    await transfer(c, a);
    await transfer(a, b);
    expect((await repo(b).listTags()).single.name, 'final exam');
    expect((await repo(b).listTags()).single.id, bt.id);
    expect(await repo(c).listTags(), hasLength(1));
    expect(await hash(a), await hash(b));
    expect(await hash(b), await hash(c));
    final report = await a.backup.mergeDataset(
      await b.backup.buildDataset(now: now),
      now: now,
    );
    expect(report.metadataUpdates, 0);
    expect(report.hasChanges, isFalse);
  });

  test(
    'unseen removal wins assignment and false favorite at equal versions',
    () async {
      final a = await TestEnv.create(), b = await TestEnv.create();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.seedBook(words: ['alpha']);
      final tag = await repo(a).createTag('exam', now: now);
      await transfer(a, b);
      final id = (await a.words.byNormalized('alpha'))!.id;
      await repo(a).setTag([id], tag.id, false, now: now);
      await repo(a).setFavorite([id], false, now: now);
      await repo(b).setTag([id], tag.id, true, now: DateTime.utc(2099));
      await repo(b).setFavorite([id], true, now: DateTime.utc(2099));
      await transfer(a, b);
      await transfer(b, a);
      expect(await repo(b).watchFavorite(id).first, isFalse);
      expect(await repo(b).watchTags(wordId: id).first, isEmpty);
      await repo(b).setTag([id], tag.id, true, now: now);
      await repo(b).setFavorite([id], true, now: now);
      await transfer(b, a);
      await transfer(a, b);
      expect(await repo(a).watchFavorite(id).first, isTrue);
      expect(await repo(a).watchTags(wordId: id).first, hasLength(1));
      expect(await hash(a), await hash(b));
    },
  );

  test('tag deletion survives offline renames and recreation keeps old relations deleted', () async {
    final a = await TestEnv.create(), b = await TestEnv.create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.seedBook(words: ['alpha']);
    final id = (await a.words.byNormalized('alpha'))!.id;
    final tag = await repo(a).createTag('exam', now: now);
    await repo(a).setTag([id], tag.id, true, now: now);
    await transfer(a, b);
    await repo(a).deleteTag(tag.id, now: now);
    for (var i = 0; i < 4; i++) {
      await repo(b).renameTag(tag.id, 'offline $i', now: DateTime.utc(2099));
    }
    await transfer(b, a);
    await transfer(a, b);
    expect(await repo(b).listTags(), isEmpty);
    expect(await repo(b).watchTags(wordId: id).first, isEmpty);
    final fresh = await repo(b).createTag('exam', now: now);
    expect(fresh.id, isNot(tag.id));
    await transfer(b, a);
    await transfer(a, b);
    expect((await repo(a).listTags()).single.id, fresh.id);
    expect(await repo(a).watchTags(wordId: id).first, isEmpty);
    expect(await hash(a), await hash(b));
  });

  test('batch metadata operations roll back on a deleted word and filters agree across pages', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha', 'beta', 'gamma']);
    final ids = await e.study.managedWordIds();
    final tag = await repo(e).createTag('exam', now: now);
    await e.words.softDelete(ids.last, now: now);
    await expectLater(
      repo(e).setTag(ids, tag.id, true, now: now),
      throwsStateError,
    );
    expect(await e.db.select(e.db.wordTags).get(), isEmpty);
    await expectLater(
      repo(e).setFavorite(ids, true, now: now),
      throwsStateError,
    );
    expect(await e.db.select(e.db.wordFavorites).get(), isEmpty);
    await repo(e).setTag(ids.take(2), tag.id, true, now: now);
    await repo(e).setFavorite(ids.take(1), true, now: now);
    final filtered = await e.study.managedWordIds(
      tagId: tag.id,
      favoritesOnly: true,
    );
    expect(filtered, [ids.first]);
    expect(await e.study.managedCount(tagId: tag.id, favoritesOnly: true), 1);
    expect(
      (await e.study.managedWords(
        tagId: tag.id,
        favoritesOnly: true,
        limit: 1,
      )).single.word.id,
      ids.first,
    );
  });

  test(
    'tag names participate in search and deleted tags stop matching',
    () async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha', 'beta']);
      final ids = await e.study.managedWordIds();
      final tag = await repo(e).createTag('exam', now: now);
      await repo(e).setTag(ids, tag.id, true, now: now);
      expect(await e.study.managedCount(search: 'exam'), 2);
      expect(await e.study.managedWordIds(search: 'exam'), ids);
      expect(await e.study.managedWords(search: 'exam'), hasLength(2));
      await repo(e).renameTag(tag.id, 'final', now: now);
      expect(await e.study.managedCount(search: 'exam'), 0);
      expect(await e.study.managedCount(search: 'final'), 2);
      await repo(e).deleteTag(tag.id, now: now);
      expect(await e.study.managedCount(search: 'final'), 0);
    },
  );

  test(
    'unfavorite while paused or before submit skips without answers',
    () async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha', 'beta']);
      final ids = await e.study.managedWordIds();
      await repo(e).setFavorite(ids, true, now: now);
      final session = e.session();
      await session.load(
        newLimit: 20,
        reviewLimit: 30,
        special: SpecialReview.favorites,
      );
      final removed = session.current!.word.id;
      session.dispose();
      await repo(e).setFavorite([removed], false, now: now);
      final resumed = e.session();
      addTearDown(resumed.dispose);
      await resumed.load(
        newLimit: 20,
        reviewLimit: 30,
        special: SpecialReview.favorites,
      );
      expect(resumed.totalCards, 1);
      expect(resumed.current!.word.id, isNot(removed));
      await repo(e).setFavorite(ids, false, now: now);
      resumed.reveal();
      expect(await resumed.submit(AnswerResult.known), isNull);
      expect(await e.db.select(e.db.reviewEvents).get(), isEmpty);
    },
  );

  test('favorites special queue includes unlearned favorites and excludes other words', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.seedBook(words: ['alpha', 'beta']);
    final word = (await e.words.byNormalized('alpha'))!;
    await repo(e).setFavorite([word.id], true, now: now);
    final session = e.session();
    addTearDown(session.dispose);
    await session.load(
      newLimit: 20,
      reviewLimit: 30,
      special: SpecialReview.favorites,
    );
    expect(session.totalCards, 1);
    expect(session.current!.word.id, word.id);
    session.reveal();
    await session.submit(AnswerResult.known);
    expect(
      (await e.db.select(e.db.reviewEvents).get()).single.mode,
      ReviewEventMode.specialFavorites,
    );
    await e.backup.validateDatasetAsync(await e.backup.buildDataset(now: now));
  });

  test(
    'invalid metadata or missing references reject the whole backup',
    () async {
      final e = await TestEnv.create();
      addTearDown(e.dispose);
      await e.seedBook(words: ['alpha']);
      final id = (await e.words.byNormalized('alpha'))!.id;
      await repo(e).setFavorite([id], true, now: now);
      final original = await e.backup.buildDataset(now: now),
          before = await hash(e);
      for (final field in ['wordId', 'value', 'version', 'updatedAt']) {
        final data = jsonDecode(jsonEncode(original)) as Map<String, Object?>;
        ((data['favorites'] as List).single as Map)[field] = field == 'version'
            ? -1
            : 'invalid';
        await expectLater(
          e.backup.mergeDataset(data, now: now),
          throwsA(isA<BackupException>()),
        );
        expect(await hash(e), before);
      }
    },
  );
}
