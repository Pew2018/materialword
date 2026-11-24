import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/core/repositories/settings_repository.dart';
import 'package:materialword/core/repositories/study_repository.dart';
import 'package:materialword/core/repositories/word_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'helpers/test_env.dart';
import 'helpers/legacy_schema.dart';

/// UI05 — concurrent setting writes must not clobber each other.
/// DATA08 — the v1 → v2 migration is lossless.
void main() {
  group('UI05 设置写入并发正确性', () {
    test('不同字段并发保存不会互相覆盖', () async {
      final TestEnv env = await TestEnv.create();
      await env.settings.save(
        dailyNewTarget: 20,
        dailyReviewLimit: 60,
        accentColor: '#1565C0',
        studyMode: StudyMode.mixed,
      );

      await Future.wait(<Future<void>>[
        env.settings.save(dailyNewTarget: 37),
        env.settings.save(dailyReviewLimit: 88),
        env.settings.save(accentColor: '#00796B'),
        env.settings.save(theme: ThemePreference.dark),
      ]);

      final StudySettingsRow row = await env.settings.load();
      expect(row.dailyNewTarget, 37);
      expect(row.dailyReviewLimit, 88);
      expect(row.accentColor, '#00796B');
      expect(row.themeMode, ThemePreference.dark.code);
      expect(row.studyMode, StudyMode.mixed.code);
      await env.dispose();
    });

    test('同一字段连续保存最后写入者生效', () async {
      final TestEnv env = await TestEnv.create();
      for (int value in <int>[11, 22, 33, 44]) {
        await env.settings.save(dailyNewTarget: value);
      }
      expect((await env.settings.load()).dailyNewTarget, 44);
      await env.dispose();
    });

    test('字段级更新不会清掉未提及的词书选择', () async {
      final TestEnv env = await TestEnv.create();
      final book = await env.seedBook(words: <String>['alpha']);
      await env.settings.save(currentWordBookId: Value<String?>(book.id));
      await env.settings.save(dailyNewTarget: 45);
      final StudySettingsRow row = await env.settings.load();
      expect(row.dailyNewTarget, 45);
      expect(row.currentWordBookId, book.id);
      await env.dispose();
    });
  });

  group('DATA08 数据库无损迁移', () {
    test('v1 数据升级到当前版本后完整保留并新增同步列', () async {
      final Directory dir = Directory.systemTemp.createTempSync('mw_migrate');
      final String path = '${dir.path}/materialword.sqlite';
      final File file = File(path);

      // Build the literal released v1 schema. Never derive a legacy fixture
      // by dropping columns from whatever the current database happens to be.
      final now = DateTime(2026, 11, 24, 9);
      const wordId = 'legacy-word';
      final raw = sql.sqlite3.open(path);
      raw.execute(phase1Schema);
      raw.execute(
        'INSERT INTO words(id, word, normalized, translation, note, created_at, updated_at) VALUES(?,?,?,?,?,?,?)',
        [
          wordId,
          'abandon',
          'abandon',
          r'v. 放弃\nn. 放任',
          '我的笔记',
          now.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
        ],
      );
      raw.execute(
        'INSERT INTO review_events(id,word_id,device_id,answered_at,local_day,result,type,interval_days_after) VALUES(?,?,?,?,?,?,?,?)',
        [
          'old-event',
          wordId,
          'old-device',
          now.millisecondsSinceEpoch,
          '2026-11-24',
          2,
          'study',
          1,
        ],
      );
      raw.execute(
        'INSERT INTO learning_states(word_id,stage,correct_count,interval_days,last_studied_at,next_review_at,updated_at) VALUES(?,?,?,?,?,?,?)',
        [
          wordId,
          1,
          1,
          1,
          now.millisecondsSinceEpoch,
          DateTime(2026, 11, 25).millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
        ],
      );
      raw.execute(
        'INSERT INTO study_settings(id,daily_new_target) VALUES(1,17)',
      );
      raw.execute('PRAGMA user_version = 1');
      raw.dispose();

      // 2. Reopen: MigrationStrategy.onUpgrade adds the missing columns.
      final AppDatabase migrated = AppDatabase(NativeDatabase(file));
      final List<QueryRow> columns = await migrated
          .customSelect(
            'PRAGMA table_info(word_book_entries)',
            readsFrom: <ResultSetImplementation<dynamic, dynamic>>{},
          )
          .get();
      final Set<String> names = columns
          .map((QueryRow r) => r.read<String>('name'))
          .toSet();
      expect(
        names,
        containsAll(<String>['deleted_at', 'version', 'updated_at']),
      );

      final StudySettingsRow row = await SettingsRepository(migrated).load();
      expect(row.dailyNewTarget, 17);
      expect(row.accentColor, '#1565C0', reason: '迁移默认值为经典蓝');

      final Word? after = await WordRepository(migrated).byId(wordId);
      expect(after, isNotNull);
      expect(after!.note, '我的笔记');
      expect(after.translation, 'v. 放弃\nn. 放任', reason: '升级同时修复旧转义');

      final List<ReviewEvent> events = await (migrated.select(
        migrated.reviewEvents,
      )).get();
      expect(events.single.id, 'old-event');
      expect(events.single.mode, 'normal');

      final LearningState? state = await StudyRepository(migrated)
          .rebuildAndRead(wordId);
      expect(state, isNotNull);
      expect(state!.stage, isNot(0));

      await migrated.close();
      dir.deleteSync(recursive: true);
    });
  });
}

/// Small read helper kept out of production code.
extension _MigrationRead on StudyRepository {
  Future<LearningState?> rebuildAndRead(String wordId) async {
    await rebuildStateFromEvents(wordId);
    return (db.select(
      db.learningStates,
    )..where((t) => t.wordId.equals(wordId))).getSingleOrNull();
  }
}
