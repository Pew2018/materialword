import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/repositories/content_sync_repository.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/sync/conflict_resolution_service.dart';
import 'package:materialword/services/sync/conflict_store.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/word_intake_service.dart';

import 'helpers/test_env.dart';

/// Phase 5.1 — CONFLICT-R01…R11.
///
/// Every case starts from a conflict that a **real** merge produced (two
/// databases, one provider with the production conditional-write contract),
/// restores the discarded value through the production service and then syncs
/// again, so "restore" is proven to be an ordinary new edit that propagates.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv a;
  late TestEnv b;
  late ScriptedSyncProvider remote;

  setUp(() async {
    a = await TestEnv.create(now: DateTime(2026, 11, 24, 9));
    b = await TestEnv.create(now: DateTime(2026, 11, 24, 10));
    remote = ScriptedSyncProvider();
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  Future<SyncReport> sync(TestEnv env) =>
      env.coordinator.sync(remote, skipConnectionTest: true);

  Future<String> hashOf(TestEnv env) async => BackupService.contentHashOf(
    await env.backup.buildDataset(now: env.clock.now()),
  );

  Future<Word> add(
    TestEnv env,
    String text, {
    String? translation,
    String? bookId,
  }) async {
    final WordIntakeResult result = await env.intake.add(
      WordIntakeRequest(
        text: text,
        user: WordContent(translation: translation),
      ),
      bookId: bookId,
      now: env.clock.now(),
    );
    return result.word;
  }

  Future<StoredSyncConflict> conflictFor(
    TestEnv env,
    String field, {
    String? kind,
  }) async {
    final List<StoredSyncConflict> all = await env.conflicts.list();
    return all.firstWhere(
      (StoredSyncConflict entry) =>
          entry.field == field && (kind == null || entry.kind == kind),
      orElse: () => throw StateError(
        '没有记录到 $field 冲突，实际记录：'
        '${all.map((StoredSyncConflict e) => '${e.kind}.${e.field}').join(', ')}',
      ),
    );
  }

  /// Both devices start from the same word, and both have edited `translation`
  /// once, so a second concurrent edit on both sides is a real field conflict.
  Future<Word> sharedWord() async {
    final Word word = await add(a, 'alpha', translation: '初始释义');
    await sync(a);
    await sync(b);
    return word;
  }

  test('CONFLICT-R01 释义冲突：恢复被覆盖值后成为新的本机编辑并再次收敛', () async {
    await sharedWord();
    a.clock.advance(const Duration(minutes: 5));
    b.clock.advance(const Duration(minutes: 9));
    await a.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(translation: 'A 的释义'),
      ),
      now: a.clock.now(),
    );
    await b.intake.add(
      const WordIntakeRequest(
        text: 'alpha',
        user: WordContent(translation: 'B 的释义'),
      ),
      now: b.clock.now(),
    );
    await sync(a);
    await sync(b);
    expect(
      (await b.words.byNormalized('alpha'))!.translation,
      'B 的释义',
      reason: '更新的编辑先赢',
    );

    final StoredSyncConflict conflict = await conflictFor(b, 'translation');
    expect(conflict.discardedValue, 'A 的释义');
    expect(conflict.adoptedValue, 'B 的释义');

    final ConflictRestoreOutcome outcome = await b.conflictResolution
        .restoreDiscardedValue(conflict, now: b.clock.now());
    expect(outcome.field, 'translation');
    expect((await b.words.byNormalized('alpha'))!.translation, 'A 的释义');
    expect(
      (await b.conflicts.list()).where(
        (StoredSyncConflict e) => e.id == conflict.id,
      ),
      isEmpty,
      reason: '成功恢复后才移除记录',
    );

    await sync(b);
    await sync(a);
    expect((await a.words.byNormalized('alpha'))!.translation, 'A 的释义');
    expect(await hashOf(a), await hashOf(b));
  });

  test('CONFLICT-R02 词条重命名冲突：恢复被覆盖的名字且保持同一身份', () async {
    final Word word = await sharedWord();
    a.clock.advance(const Duration(minutes: 5));
    b.clock.advance(const Duration(minutes: 9));
    await a.words.updateContent(word.id, text: 'colour', now: a.clock.now());
    await b.words.updateContent(word.id, text: 'couler', now: b.clock.now());
    await sync(a);
    await sync(b);

    final StoredSyncConflict conflict = await conflictFor(b, 'word');
    expect(conflict.discardedValue, 'colour');
    await b.conflictResolution.restoreDiscardedValue(
      conflict,
      now: b.clock.now(),
    );

    expect((await b.words.byId(word.id))!.word, 'colour');
    await sync(b);
    await sync(a);
    expect((await a.words.byId(word.id))!.word, 'colour');
    expect(await a.words.countWords(), 1, reason: '恢复不能被当成新词条');
    expect(await hashOf(a), await hashOf(b));
  });

  test('CONFLICT-R03 删除状态冲突：恢复“未删除”必须真正 revive', () async {
    final Word word = await sharedWord();
    // Seed a deletion version on both sides, then revive on both, so that both
    // devices genuinely hold a >1 `deletedAt` stamp.
    await a.words.softDelete(word.id, now: a.clock.now());
    await sync(a);
    await sync(b);
    a.clock.advance(const Duration(minutes: 1));
    b.clock.advance(const Duration(minutes: 1));
    await a.intake.reviveById(word.id, now: a.clock.now());
    await b.intake.reviveById(word.id, now: b.clock.now());
    await sync(a);
    await sync(b);

    // A: delete → revive → delete (v5, deleted). B: delete → revive (v4, alive).
    a.clock.advance(const Duration(minutes: 1));
    await a.words.softDelete(word.id, now: a.clock.now());
    await a.intake.reviveById(word.id, now: a.clock.now());
    await a.words.softDelete(word.id, now: a.clock.now());
    b.clock.advance(const Duration(minutes: 1));
    await b.words.softDelete(word.id, now: b.clock.now());
    await b.intake.reviveById(word.id, now: b.clock.now());

    await sync(b);
    await sync(a);
    expect((await a.words.byId(word.id))!.deletedAt, isNotNull);
    final StoredSyncConflict conflict = await conflictFor(a, 'deletedAt');
    expect(conflict.discardedValue, isNull, reason: '被丢弃的是“未删除”，恢复语义必须是复活');

    final int revisionBefore = (await a.words.byId(word.id))!.revision;
    await a.conflictResolution.restoreDiscardedValue(
      conflict,
      now: a.clock.now(),
    );
    final Word revived = (await a.words.byId(word.id))!;
    expect(revived.deletedAt, isNull, reason: '必须真正恢复为存活状态');
    expect(revived.revision, greaterThan(revisionBefore));

    await sync(a);
    await sync(b);
    expect((await b.words.byId(word.id))!.deletedAt, isNull);
    expect(await hashOf(a), await hashOf(b));
  });

  test('CONFLICT-R04 删除状态冲突：恢复“已删除”必须真正 soft-delete', () async {
    final Word word = await sharedWord();
    await a.words.softDelete(word.id, now: a.clock.now());
    await sync(a);
    await sync(b);
    a.clock.advance(const Duration(minutes: 1));
    b.clock.advance(const Duration(minutes: 1));
    await a.intake.reviveById(word.id, now: a.clock.now());
    await b.intake.reviveById(word.id, now: b.clock.now());
    await sync(a);
    await sync(b);

    // A deletes (v3). B deletes then revives (v4, alive) and uploads.
    a.clock.advance(const Duration(minutes: 1));
    await a.words.softDelete(word.id, now: a.clock.now());
    b.clock.advance(const Duration(minutes: 2));
    await b.words.softDelete(word.id, now: b.clock.now());
    await b.intake.reviveById(word.id, now: b.clock.now());
    await sync(b);
    await sync(a);

    expect((await a.words.byId(word.id))!.deletedAt, isNull);
    final StoredSyncConflict conflict = await conflictFor(a, 'deletedAt');
    expect(conflict.discardedValue, isNotNull, reason: '被丢弃的是删除标记');

    await a.conflictResolution.restoreDiscardedValue(
      conflict,
      now: a.clock.now(),
    );
    expect(
      (await a.words.byId(word.id))!.deletedAt,
      isNotNull,
      reason: '恢复删除值必须真正写入墓碑',
    );
    expect(await a.words.byNormalized('alpha'), isNull);

    await sync(a);
    await sync(b);
    expect((await b.words.byId(word.id))!.deletedAt, isNotNull);
    expect(await hashOf(a), await hashOf(b));
  });

  test('CONFLICT-R05 考试标签冲突可恢复', () async {
    final Word word = await sharedWord();
    a.clock.advance(const Duration(minutes: 5));
    b.clock.advance(const Duration(minutes: 9));
    await a.words.updateMetadata(word.id, examTags: 'cet6', now: a.clock.now());
    await b.words.updateMetadata(word.id, examTags: 'cet4', now: b.clock.now());
    await sync(a);
    await sync(b);

    final StoredSyncConflict conflict = await conflictFor(b, 'examTags');
    expect(conflict.discardedValue, 'cet6');
    await b.conflictResolution.restoreDiscardedValue(
      conflict,
      now: b.clock.now(),
    );
    expect((await b.words.byId(word.id))!.examTags, 'cet6');
    await sync(b);
    await sync(a);
    expect((await a.words.byId(word.id))!.examTags, 'cet6');
    expect(await hashOf(a), await hashOf(b));
  });

  test('CONFLICT-R06 bncRank 冲突可恢复', () async {
    final Word word = await sharedWord();
    a.clock.advance(const Duration(minutes: 5));
    b.clock.advance(const Duration(minutes: 9));
    await a.words.updateMetadata(word.id, bncRank: 3211, now: a.clock.now());
    await b.words.updateMetadata(word.id, bncRank: 5000, now: b.clock.now());
    await sync(a);
    await sync(b);

    final StoredSyncConflict conflict = await conflictFor(b, 'bncRank');
    expect(conflict.discardedValue, 3211);
    await b.conflictResolution.restoreDiscardedValue(
      conflict,
      now: b.clock.now(),
    );
    expect((await b.words.byId(word.id))!.bncRank, 3211);
    await sync(b);
    await sync(a);
    expect((await a.words.byId(word.id))!.bncRank, 3211);
    expect(await hashOf(a), await hashOf(b));
  });

  test('CONFLICT-R07 frqRank 冲突可恢复', () async {
    final Word word = await sharedWord();
    a.clock.advance(const Duration(minutes: 5));
    b.clock.advance(const Duration(minutes: 9));
    await a.words.updateMetadata(word.id, frqRank: 940, now: a.clock.now());
    await b.words.updateMetadata(word.id, frqRank: 1200, now: b.clock.now());
    await sync(a);
    await sync(b);

    final StoredSyncConflict conflict = await conflictFor(b, 'frqRank');
    expect(conflict.discardedValue, 940);
    await b.conflictResolution.restoreDiscardedValue(
      conflict,
      now: b.clock.now(),
    );
    expect((await b.words.byId(word.id))!.frqRank, 940);
    await sync(b);
    await sync(a);
    expect((await a.words.byId(word.id))!.frqRank, 940);
    expect(await hashOf(a), await hashOf(b));
  });

  test('CONFLICT-R08 词书名称冲突可恢复', () async {
    final WordBook book = await a.books.create(name: '旧名字', now: a.clock.now());
    await add(a, 'alpha', bookId: book.id);
    await sync(a);
    await sync(b);

    a.clock.advance(const Duration(minutes: 5));
    b.clock.advance(const Duration(minutes: 9));
    await a.books.rename(book.id, 'A 的名字', now: a.clock.now());
    await b.books.rename(book.id, 'B 的名字', now: b.clock.now());
    await sync(a);
    await sync(b);
    expect((await b.books.byId(book.id))!.name, 'B 的名字');

    final StoredSyncConflict conflict = await conflictFor(b, 'name');
    expect(conflict.discardedValue, 'A 的名字');
    await b.conflictResolution.restoreDiscardedValue(
      conflict,
      now: b.clock.now(),
    );
    expect((await b.books.byId(book.id))!.name, 'A 的名字');
    await sync(b);
    await sync(a);
    expect((await a.books.byId(book.id))!.name, 'A 的名字');
    expect(await hashOf(a), await hashOf(b));
  });

  test('CONFLICT-R09 词书描述冲突可恢复', () async {
    final WordBook book = await a.books.create(
      name: '词书',
      description: '旧描述',
      now: a.clock.now(),
    );
    await add(a, 'alpha', bookId: book.id);
    await sync(a);
    await sync(b);

    a.clock.advance(const Duration(minutes: 5));
    b.clock.advance(const Duration(minutes: 9));
    await a.books.updateDescription(book.id, 'A 的描述', now: a.clock.now());
    await b.books.updateDescription(book.id, 'B 的描述', now: b.clock.now());
    await sync(a);
    await sync(b);

    final StoredSyncConflict conflict = await conflictFor(b, 'description');
    expect(conflict.discardedValue, 'A 的描述');
    await b.conflictResolution.restoreDiscardedValue(
      conflict,
      now: b.clock.now(),
    );
    expect((await b.books.byId(book.id))!.description, 'A 的描述');
    await sync(b);
    await sync(a);
    expect((await a.books.byId(book.id))!.description, 'A 的描述');
    expect(await hashOf(a), await hashOf(b));
  });

  test('CONFLICT-R10 词书删除状态冲突：恢复“未删除”让词书回到列表', () async {
    final WordBook book = await a.books.create(
      name: '可恢复词书',
      now: a.clock.now(),
    );
    await add(a, 'alpha', bookId: book.id);
    await sync(a);
    await sync(b);

    // Build a >1 deletion stamp on both sides first.
    await a.books.softDelete(book.id, now: a.clock.now());
    await sync(a);
    await sync(b);
    a.clock.advance(const Duration(minutes: 1));
    b.clock.advance(const Duration(minutes: 1));
    await a.books.restore(book.id, now: a.clock.now());
    await b.books.restore(book.id, now: b.clock.now());
    await sync(a);
    await sync(b);

    a.clock.advance(const Duration(minutes: 1));
    await a.books.softDelete(book.id, now: a.clock.now());
    await a.books.restore(book.id, now: a.clock.now());
    await a.books.softDelete(book.id, now: a.clock.now());
    b.clock.advance(const Duration(minutes: 2));
    await b.books.softDelete(book.id, now: b.clock.now());
    await b.books.restore(book.id, now: b.clock.now());

    await sync(b);
    await sync(a);
    expect((await a.books.byId(book.id))!.deletedAt, isNotNull);

    final StoredSyncConflict conflict = await conflictFor(a, 'deletedAt');
    expect(conflict.discardedValue, isNull);
    await a.conflictResolution.restoreDiscardedValue(
      conflict,
      now: a.clock.now(),
    );
    expect((await a.books.byId(book.id))!.deletedAt, isNull);
    expect(
      (await a.books.listBooks()).map((WordBook b) => b.id),
      contains(book.id),
    );

    await sync(a);
    await sync(b);
    expect((await b.books.byId(book.id))!.deletedAt, isNull);
    expect(await hashOf(a), await hashOf(b));
  });

  test('CONFLICT-R11 不支持的字段明确拒绝，且保留冲突记录', () async {
    final Word word = await sharedWord();
    await b.conflicts.record(<FieldConflict>[
      FieldConflict(
        kind: 'word',
        id: word.id,
        field: 'notARealField',
        localValue: 'x',
        remoteValue: 'y',
        chosenRemote: true,
        localVersion: 3,
        remoteVersion: 4,
        localUpdatedAt: 0,
        remoteUpdatedAt: 0,
        label: 'alpha',
      ),
    ], now: b.clock.now());
    final StoredSyncConflict conflict = await conflictFor(b, 'notARealField');

    expect(
      SyncConflictResolutionService.canRestore(conflict),
      isFalse,
      reason: '不可恢复字段不能出现可点击的恢复按钮',
    );
    await expectLater(
      b.conflictResolution.restoreDiscardedValue(conflict, now: b.clock.now()),
      throwsA(isA<ConflictRestoreException>()),
    );
    expect(
      (await b.conflicts.list()).where(
        (StoredSyncConflict e) => e.id == conflict.id,
      ),
      hasLength(1),
      reason: '失败时不能移除冲突记录',
    );
  });
}
