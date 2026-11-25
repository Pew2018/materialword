import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/models/sprint_plan.dart';
import 'package:materialword/core/repositories/sprint_repository.dart';
import 'package:materialword/services/backup_manager.dart';
import 'package:materialword/services/word_intake_service.dart';

import 'helpers/test_env.dart';

/// Phase 5.1 — BAK-R01…R05.
///
/// The regression these guard: a point-in-time restore cleared words, events and
/// books but let the Lamport version rule decide about shared settings, so an
/// old snapshot (counter 1) lost against the current settings (counter 5). The
/// result was a mixture — yesterday's vocabulary with today's daily target —
/// which is not a restore. Merge restore must keep the version rules, so the two
/// semantics are pinned separately.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;

  setUp(() async {
    env = await TestEnv.create(now: DateTime(2026, 11, 24, 9));
  });

  tearDown(() async {
    await env.dispose();
  });

  /// Snapshot state: target 20, review limit 60, mode review, one book.
  Future<WordBook> seedSnapshotState() async {
    await env.settings.save(
      dailyNewTarget: 20,
      dailyReviewLimit: 60,
      studyMode: StudyMode.reviewOnly,
    );
    final WordBook book = await env.seedBook(words: <String>['alpha', 'beta']);
    final WordIntakeResult extra = await env.intake.add(
      const WordIntakeRequest(text: 'gamma'),
      bookId: book.id,
      now: env.clock.now(),
    );
    expect(extra.kind, IntakeKind.created);
    return book;
  }

  test('BAK-R01 快照恢复把共享设置恢复到快照版本', () async {
    await seedSnapshotState();
    final Map<String, Object?> snapshotVersion = await env.settings
        .sharedVersion();
    expect(snapshotVersion['counter'], 1);
    final File copy = await env.backups.createBackup();

    // Move the present well past the snapshot.
    env.clock.advance(const Duration(days: 3));
    for (final int target in <int>[50, 51, 52, 53, 60]) {
      await env.settings.save(dailyNewTarget: target);
    }
    await env.settings.save(dailyReviewLimit: 300, studyMode: StudyMode.mixed);
    expect((await env.settings.load()).dailyNewTarget, 60);
    expect((await env.settings.sharedVersion())['counter'], greaterThan(1));

    await env.backups.restoreSnapshot(copy);

    final StudySettingsRow restored = await env.settings.load();
    expect(restored.dailyNewTarget, 20, reason: '每日新词目标必须回到快照值');
    expect(restored.dailyReviewLimit, 60);
    expect(restored.studyMode, StudyMode.reviewOnly.code);
    expect(
      await env.settings.sharedVersion(),
      snapshotVersion,
      reason: '共享设置版本也必须回到快照版本，否则下一次合并会再次覆盖',
    );
  });

  test('BAK-R02 合并恢复仍然遵守版本规则，不覆盖更新的本机设置', () async {
    await seedSnapshotState();
    final File copy = await env.backups.createBackup();

    env.clock.advance(const Duration(days: 1));
    await env.settings.save(dailyNewTarget: 50);

    await env.backups.restoreMerge(copy);
    expect(
      (await env.settings.load()).dailyNewTarget,
      50,
      reason: '合并恢复不能把较旧的快照设置强加给本机',
    );
  });

  test('BAK-R03 恢复后指向不存在词书的当前选择会被清理', () async {
    final WordBook snapshotBook = await seedSnapshotState();
    final File copy = await env.backups.createBackup();

    env.clock.advance(const Duration(days: 1));
    final WordBook laterBook = await env.books.create(
      name: '恢复后不存在',
      now: env.clock.now(),
    );
    await env.settings.save(currentWordBookId: Value<String?>(laterBook.id));
    expect((await env.settings.load()).currentWordBookId, laterBook.id);

    final RestoreOutcome outcome = await env.backups.restoreSnapshot(copy);

    expect(outcome.currentBookCleared, isTrue);
    expect(
      (await env.settings.load()).currentWordBookId,
      isNull,
      reason: '不能留下悬空的 currentWordBookId',
    );
    expect(await env.books.byId(laterBook.id), isNull);
    expect(await env.books.byId(snapshotBook.id), isNotNull);
  });

  test('BAK-R03b 快照里仍然存在的选择会被保留', () async {
    final WordBook book = await seedSnapshotState();
    await env.settings.save(currentWordBookId: Value<String?>(book.id));
    final File copy = await env.backups.createBackup();

    final RestoreOutcome outcome = await env.backups.restoreSnapshot(copy);
    expect(outcome.currentBookCleared, isFalse);
    expect((await env.settings.load()).currentWordBookId, book.id);
  });

  test('BAK-R04 冲刺计划引用已删除词书时安全降级而不是崩溃', () async {
    final WordBook book = await seedSnapshotState();
    await env.settings.save(
      sprintPlan: SprintPlan(
        enabled: true,
        examDate: '2027-01-01',
        bookId: book.id,
        roundSize: 20,
      ),
    );
    // Snapshot state where the plan still names a book that is already deleted.
    // (The dataset validator refuses a plan that points at no book at all, so
    // this is the only dangling reference a real file can carry.)
    await env.books.softDelete(book.id, now: env.clock.now());
    final File copy = await env.backups.createBackup();

    env.clock.advance(const Duration(days: 1));
    final WordBook other = await env.books.create(
      name: '后来的词书',
      now: env.clock.now(),
    );
    await env.settings.save(
      sprintPlan: SprintPlan(
        enabled: true,
        examDate: '2027-06-01',
        bookId: other.id,
        roundSize: 30,
      ),
    );

    final RestoreOutcome outcome = await env.backups.restoreSnapshot(copy);
    expect(outcome.report.newWords, 3);

    final SprintPlan plan = await env.settings.loadSprintPlan();
    expect(plan.bookId, book.id, reason: '不静默改成全部词书');
    expect(plan.enabled, isTrue, reason: '计划本身必须恢复成快照状态');
    final SprintOverview overview = await SprintRepository(env.db)
        .overview(plan, env.clock.now());
    expect(overview.bookAvailable, isFalse);
    expect(overview.wordIds, isEmpty);
    expect(overview.total, 0, reason: '不能把全部词书当成冲刺目标');
  });

  test('BAK-R05 恢复中途失败时词条与共享设置一起回滚', () async {
    await seedSnapshotState();
    final File copy = await env.backups.createBackup();

    env.clock.advance(const Duration(days: 1));
    await env.settings.save(dailyNewTarget: 50);
    final Map<String, Object?> versionBefore = await env.settings
        .sharedVersion();
    await env.intake.add(
      const WordIntakeRequest(text: 'delta'),
      now: env.clock.now(),
    );
    expect(await env.words.countWords(), 4);

    await expectLater(
      env.backups.restoreSnapshot(
        copy,
        afterMerge: () async => throw StateError('simulated crash'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await env.words.countWords(), 4, reason: '词条必须回滚');
    expect(await env.words.byNormalized('delta'), isNotNull);
    final StudySettingsRow settings = await env.settings.load();
    expect(settings.dailyNewTarget, 50, reason: '词条回滚了但 settings 已经改变是不允许的');
    expect(await env.settings.sharedVersion(), versionBefore);
    expect(await env.settings.syncPaused(), isFalse);
  });
}
