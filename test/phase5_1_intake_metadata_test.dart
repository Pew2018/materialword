import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/repositories/content_sync_repository.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/word_intake_service.dart';

import 'helpers/test_env.dart';

/// Phase 5.1 — INTAKE-R01…R06.
///
/// The regression these guard: `WordIntakeService` used to decide "write or not"
/// from a hand-maintained list that only the *text* resolvers filled in, so an
/// import that supplied `examTags` / `bncRank` / `frqRank` for a word whose text
/// was already complete composed a new row and then threw it away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;
  late ScriptedSyncProvider remote;

  setUp(() async {
    env = await TestEnv.create(now: DateTime(2026, 11, 24, 9));
    remote = ScriptedSyncProvider();
  });

  tearDown(() async {
    await env.dispose();
  });

  /// A word that came from the dictionary: complete text, no customisation and
  /// empty metadata — exactly the state an import is expected to enrich.
  Future<Word> dictionaryWord() => env.words.ensureWord(
    text: 'abandon',
    translation: '放弃',
    now: env.clock.now(),
  );

  test('INTAKE-R01 examTags 从空到有值必须写库', () async {
    final Word before = await dictionaryWord();
    expect(before.examTags, isEmpty);
    expect(before.customized, isFalse);

    final WordIntakeResult result = await env.intake.add(
      const WordIntakeRequest(text: 'abandon', examTags: 'cet6'),
      now: env.clock.now(),
    );
    final Word after = (await env.words.byNormalized('abandon'))!;
    expect(after.examTags, 'cet6');
    expect(result.kind, IntakeKind.updated);
    expect(result.changedFields, contains('examTags'));
    expect(after.revision, before.revision + 1);
    expect(after.translation, '放弃', reason: '只改元数据，不能动文本');
    expect(after.customized, isFalse, reason: '词典元数据不等于用户手写内容');
  });

  test('INTAKE-R02 bncRank 0 → 非 0 必须写库', () async {
    final Word before = await dictionaryWord();
    expect(before.bncRank, 0);
    await env.intake.add(
      const WordIntakeRequest(text: 'abandon', bncRank: 3211),
      now: env.clock.now(),
    );
    final Word after = (await env.words.byNormalized('abandon'))!;
    expect(after.bncRank, 3211);
    expect(after.revision, before.revision + 1);
  });

  test('INTAKE-R03 frqRank 0 → 非 0 必须写库', () async {
    final Word before = await dictionaryWord();
    expect(before.frqRank, 0);
    await env.intake.add(
      const WordIntakeRequest(text: 'abandon', frqRank: 940),
      now: env.clock.now(),
    );
    final Word after = (await env.words.byNormalized('abandon'))!;
    expect(after.frqRank, 940);
    expect(after.revision, before.revision + 1);
  });

  test('INTAKE-R04 已存在的元数据不被较新的导入覆盖', () async {
    final Word word = await env.words.ensureWord(
      text: 'abandon',
      translation: '放弃',
      examTags: 'cet6',
      bncRank: 3211,
      frqRank: 940,
      now: env.clock.now(),
    );
    final WordIntakeResult result = await env.intake.add(
      const WordIntakeRequest(
        text: 'abandon',
        examTags: 'cet4',
        bncRank: 5000,
        frqRank: 1200,
      ),
      now: env.clock.now(),
    );
    final Word after = (await env.words.byId(word.id))!;
    expect(after.examTags, 'cet6');
    expect(after.bncRank, 3211);
    expect(after.frqRank, 940);
    expect(result.kind, IntakeKind.unchanged);
    expect(after.revision, word.revision, reason: '没有真实变化就不该写库');
    expect(after.updatedAt, word.updatedAt);
  });

  test('INTAKE-R05 元数据更新会写入字段版本并同步到其他设备', () async {
    final Word before = await dictionaryWord();
    await env.intake.add(
      const WordIntakeRequest(text: 'abandon', examTags: 'cet6', bncRank: 3211),
      now: env.clock.now(),
    );
    final Map<String, Map<String, Object?>> versions =
        await ContentSyncRepository(env.db).versions('word', before.id);
    expect(versions['examTags']!['version'], greaterThan(1));
    expect(versions['bncRank']!['version'], greaterThan(1));

    await env.coordinator.sync(remote, skipConnectionTest: true);

    final TestEnv other = await TestEnv.create(now: DateTime(2026, 11, 24, 12));
    addTearDown(other.dispose);
    final SyncCoordinator peer = SyncCoordinator(
      db: other.db,
      backup: other.backup,
      study: other.study,
      settings: other.settings,
      credentials: env.coordinator.credentials,
      clock: other.clock,
    );
    await peer.sync(remote, skipConnectionTest: true);
    final Word landed = (await other.words.byNormalized('abandon'))!;
    expect(landed.examTags, 'cet6');
    expect(landed.bncRank, 3211);
    expect(
      BackupService.contentHashOf(
        await other.backup.buildDataset(now: other.clock.now()),
      ),
      BackupService.contentHashOf(
        await env.backup.buildDataset(now: env.clock.now()),
      ),
    );
  });

  test('INTAKE-R06 完全无变化的重复新增不写库', () async {
    final WordIntakeResult first = await env.intake.add(
      const WordIntakeRequest(
        text: 'abandon',
        user: WordContent(translation: '放弃'),
      ),
      now: env.clock.now(),
    );
    final Word created = first.word;
    expect(first.kind, IntakeKind.created);
    final Map<String, Map<String, Object?>> versionsBefore =
        await ContentSyncRepository(env.db).versions('word', created.id);

    env.clock.advance(const Duration(minutes: 30));
    final WordIntakeResult again = await env.intake.add(
      const WordIntakeRequest(
        text: 'abandon',
        user: WordContent(translation: '放弃'),
      ),
      now: env.clock.now(),
    );

    expect(again.kind, IntakeKind.unchanged);
    expect(again.word.revision, created.revision, reason: '重复新增不能抬高版本');
    expect(again.word.updatedAt, created.updatedAt);
    expect(again.word.customized, isTrue);
    final Word reloaded = (await env.words.byId(created.id))!;
    expect(reloaded.revision, created.revision);
    expect(reloaded.updatedAt, created.updatedAt);
    expect(
      await ContentSyncRepository(env.db).versions('word', created.id),
      versionsBefore,
      reason: '没有写入就不该生成字段版本',
    );
  });
}
