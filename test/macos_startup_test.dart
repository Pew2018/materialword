import 'dart:io';

import 'package:drift/drift.dart' show QueryRow, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/models/study_models.dart';
import 'package:materialword/core/repositories/settings_repository.dart';
import 'package:materialword/core/repositories/word_repository.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/github_sync_provider.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'helpers/test_env.dart';
import 'helpers/legacy_schema.dart';

/// Phase 2.1 regressions: a macOS build that stands up, and an app that keeps
/// working when the Keychain or the network does not.
///
///  * MAC04 — a brand new database opens and is usable.
///  * MAC05 — a real phase 1 (schema 1) file migrates to schema 2 losslessly.
///  * MAC06 — an unusable Keychain breaks sync, never offline study, and never
///            silently downgrades a secret to plain text.
///  * MAC08 — no network / dead sync server still reaches the home screen.
void main() {
  group('MAC04 全新数据库正常启动', () {
    test('空目录首次打开即建立当前 schema，并可正常读写', () async {
      final Directory dir = Directory.systemTemp.createTempSync('mw_mac04');
      final File file = File('${dir.path}/materialword.sqlite');
      final AppDatabase db = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        dir.deleteSync(recursive: true);
      });

      // 空库上第一次读写：drift 在这里完成 createAll + beforeOpen。
      final WordRepository words = WordRepository(db);
      final Word word = await words.ensureWord(
        text: 'abandon',
        translation: 'v. 放弃',
        now: DateTime(2026, 11, 25, 9),
      );
      expect(word.id, isNotEmpty);
      expect((await words.byId(word.id))!.word, 'abandon');

      final StudySettingsRow settings = await SettingsRepository(db).load();
      expect(settings.dailyNewTarget, greaterThan(0));

      await db.close();
      final sql.Database raw = sql.sqlite3.open(file.path);
      addTearDown(raw.dispose);
      expect(
        raw.select('PRAGMA user_version').first['user_version'],
        AppDatabase.currentSchemaVersion,
        reason: '新库必须直接建立当前 schema（含同步列）',
      );
      final List<String> tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((sql.Row r) => r['name'] as String)
          .toList();
      expect(
        tables,
        containsAll(<String>[
          'words',
          'word_books',
          'word_book_entries',
          'learning_states',
          'review_events',
          'study_settings',
          'app_meta',
        ]),
      );
    });
  });

  group('MAC05 phase 1 数据库无损迁移并启动', () {
    test('真实 schema 1 文件升级到当前版本：数据、笔记、转义文本全部保留', () async {
      final Directory dir = Directory.systemTemp.createTempSync('mw_mac05');
      final File file = File('${dir.path}/materialword.sqlite');
      addTearDown(() => dir.deleteSync(recursive: true));

      const int t0 = 1763900000000; // 2026-11-23T… fixed timestamp
      final sql.Database raw = sql.sqlite3.open(file.path);
      raw.execute(phase1Schema);
      raw.execute('''
INSERT INTO word_books (id, name, description, source_type, source_url,
  created_at, updated_at, deleted_at)
VALUES ('book-1', 'CET6 核心', '', 'manual', '', $t0, $t0, NULL);
''');
      raw.execute('''
INSERT INTO words (id, word, normalized, phonetic, part_of_speech,
  translation, definition, example, phrase, note, source, exam_tags,
  bnc_rank, frq_rank, customized, revision, created_at, updated_at, deleted_at)
VALUES ('w-1', 'abandon', 'abandon', '/əˈbændən/', 'v.',
  'v. 放弃\\nn. 放任', 'to give up', '', '', '我的笔记', 'manual', 'cet6',
  1000, 900, 0, 1, $t0, $t0, NULL);
''');
      raw.execute('''
INSERT INTO word_book_entries (word_book_id, word_id, added_at)
VALUES ('book-1', 'w-1', $t0);
''');
      raw.execute('''
INSERT INTO learning_states (word_id, stage, correct_count, hazy_count,
  wrong_count, streak, interval_days, last_studied_at, next_review_at, updated_at)
VALUES ('w-1', 1, 2, 0, 0, 2, 1, $t0, $t0, $t0);
''');
      raw.execute('''
INSERT INTO review_events (id, word_id, device_id, answered_at, local_day,
  result, type, stage_before, interval_days_after, algo_version)
VALUES ('e-1', 'w-1', 'dev-old', $t0, '2026-11-23', 1, 'study', 0, 1, 1);
''');
      raw.execute('''
INSERT INTO study_settings (id, daily_new_target, daily_review_limit,
  current_word_book_id, study_mode, theme_mode)
VALUES (1, 17, 100, 'book-1', 'mixed', 'dark');
''');
      raw.execute('PRAGMA user_version = 1');
      raw.dispose();

      // 用线上同一条迁移路径打开：main() 之后的第一帧就会走这里。
      final AppDatabase db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final Word? word = await WordRepository(db).byId('w-1');
      expect(word, isNotNull, reason: '迁移不得丢词');
      expect(word!.note, '我的笔记');
      expect(
        word.translation,
        'v. 放弃\nn. 放任',
        reason: '迁移同时把旧的字面 \\n 转义修成真实换行',
      );

      final StudySettingsRow settings = await SettingsRepository(db).load();
      expect(settings.dailyNewTarget, 17);
      expect(settings.themeMode, ThemePreference.dark.code, reason: '用户主题保留');
      expect(settings.typographyScale, TypographyScale.material2014.code);
      expect(settings.currentWordBookId, 'book-1');

      final int entries = await _count(db, 'word_book_entries');
      final int events = await _count(db, 'review_events');
      final int states = await _count(db, 'learning_states');
      expect(entries, 1);
      expect(events, 1);
      expect(states, 1);

      // 新增的同步列存在，且既有条目被赋予了可比较的版本/时间。
      final List<QueryRow> columns = await db
          .customSelect('PRAGMA table_info(word_book_entries)')
          .get();
      expect(
        columns.map((QueryRow r) => r.read<String>('name')).toSet(),
        containsAll(<String>['version', 'updated_at', 'deleted_at']),
      );
      final QueryRow entry =
          (await db
                  .customSelect(
                    'SELECT version, updated_at, deleted_at FROM word_book_entries',
                  )
                  .get())
              .single;
      expect(entry.read<int>('version'), 1);
      expect(
        entry.read<int>('updated_at'),
        t0,
        reason: '旧的 added_at 回填成 updated_at',
      );
      expect(entry.read<int?>('deleted_at'), isNull);

      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        AppDatabase.currentSchemaVersion,
      );
    });

    test('迁移后再次打开是空操作（不重复加列、不丢数据）', () async {
      final Directory dir = Directory.systemTemp.createTempSync('mw_mac05b');
      final File file = File('${dir.path}/materialword.sqlite');
      addTearDown(() => dir.deleteSync(recursive: true));

      final sql.Database raw = sql.sqlite3.open(file.path);
      raw.execute(phase1Schema);
      raw.execute('PRAGMA user_version = 1');
      raw.dispose();

      for (int i = 0; i < 3; i++) {
        final AppDatabase db = AppDatabase(NativeDatabase(file));
        await db.customSelect('SELECT 1').get(); // 触发 open + 迁移
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          AppDatabase.currentSchemaVersion,
          reason: '第 ${i + 1} 次打开应保持当前版本',
        );
        await db.close();
      }
    });
  });

  group('MAC06 Keychain 不可用时仍可离线学习', () {
    test('自动同步返回失败报告而不是抛出，学习流程照常', () async {
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      final WordBook book = await env.seedBook(
        words: <String>['abandon', 'ability'],
      );
      await env.settings.save(currentWordBookId: Value<String?>(book.id));
      await env.settings.setSyncConfig(<String, Object?>{
        'provider': 'github',
        'owner': 'someone',
        'repo': 'materialword-data',
        'branch': 'main',
        'path': 'materialword-data.json',
        'autoOnStart': true,
      });

      final SyncCoordinator coordinator = SyncCoordinator(
        db: env.db,
        backup: env.backup,
        study: env.study,
        settings: env.settings,
        credentials: const UnavailableCredentialStore(),
        clock: env.clock,
      );

      // This regression exercises an already confirmed target. New targets
      // intentionally require a manual merge before automatic sync is allowed.
      final target = coordinator.providerFromConfig(
        await env.settings.syncConfig(),
      )!;
      await env.db.writeMeta(
        'sync_target:${SyncCoordinator.targetKey(target)}',
        '{}',
      );
      final SyncReport? report = await coordinator.autoSync();
      expect(report, isNotNull, reason: '已确认的 provider 应尝试同步');
      expect(report!.ok, isFalse);
      expect(report.message, contains('钥匙串'), reason: '必须告诉用户是钥匙串的问题、需要重新输入');

      // 离线学习不受影响。
      expect(await env.study.newWordCount(bookId: book.id), 2);
      final StudyQueue queue = await env.study.buildQueue(
        now: env.clock.now(),
        newLimit: 10,
        reviewLimit: 10,
        bookId: book.id,
      );
      expect(queue.cards, isNotEmpty, reason: '钥匙串不可用不得影响取词学习');
    });

    test('读不到凭据时明确抛 CredentialStoreUnavailable，绝不返回 null', () async {
      const CredentialStore store = UnavailableCredentialStore();
      await expectLater(
        store.read(CredentialKeys.githubToken),
        throwsA(isA<CredentialStoreUnavailable>()),
        reason: 'null 会被上层当成“没保存过”，从而静默丢掉同步能力',
      );
      await expectLater(
        store.write(CredentialKeys.githubToken, 'x'),
        throwsA(isA<CredentialStoreUnavailable>()),
      );
      await expectLater(
        store.delete(CredentialKeys.githubToken),
        throwsA(isA<CredentialStoreUnavailable>()),
      );
    });
  });

  group('MAC08 无网络 / 同步服务器不可用时正常进入首页', () {
    testWidgets('启动时同步不可用（含钥匙串不可用），首页照常渲染', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final TestEnv env = await TestEnv.create();
      await env.settings.setSyncConfig(<String, Object?>{
        'provider': 'github',
        'owner': 'someone',
        'repo': 'materialword-data',
        'branch': 'main',
        'path': 'materialword-data.json',
        'autoOnStart': true,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(env.db),
            clockProvider.overrideWithValue(env.clock),
            // Sync is configured but cannot authenticate: the app must not care.
            credentialStoreProvider.overrideWithValue(
              const UnavailableCredentialStore(),
            ),
          ],
          child: const MaterialWordApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('今日任务'), findsOneWidget, reason: '首页必须显示');
      expect(find.text('今日'), findsWidgets);
      expect(find.text('还没有单词'), findsOneWidget);

      // 主动拆掉界面并推进一点时间：drift 取消流查询时会排一个零延迟定时器，
      // 留在这里消化掉，否则测试收尾会被判为 "Pending timers"。
      await tester.pumpWidget(const SizedBox.shrink());
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
    });

    test('服务器不可达时同步失败可读，而不是让异常穿透启动流程', () async {
      final GitHubSyncProvider provider = GitHubSyncProvider(
        owner: 'someone',
        repo: 'materialword-data',
        credentials: InMemoryCredentialStore(<String, String>{
          CredentialKeys.githubToken: 'ghp_offline_test',
        }),
        // 真实的“连不上”：每个请求都以 SocketException 失败。
        client: MockClient(
          (http.Request request) async =>
              throw const SocketException('Network is unreachable'),
        ),
      );

      final SyncTestResult result = await provider.testConnection();
      expect(result.ok, isFalse, reason: '离线必须表现为可读的失败');
      expect(result.message, contains('网络'), reason: '提示要说明是网络问题');
    });
  });
}

Future<int> _count(AppDatabase db, String table) async {
  final QueryRow row =
      (await db.customSelect('SELECT COUNT(*) AS c FROM $table').get()).single;
  return row.read<int>('c');
}
