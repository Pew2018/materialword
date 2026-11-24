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
    test('v1 数据升级到 v2 后完整保留并新增同步列', () async {
      final Directory dir = Directory.systemTemp.createTempSync('mw_migrate');
      final String path = '${dir.path}/materialword.sqlite';
      final File file = File(path);

      // 1. Create a v2 database the normal way, then downgrade its schema to
      //    what phase 1 shipped. This gives us a realistic v1 file with real
      //    user data in it.
      final AppDatabase fresh = AppDatabase(NativeDatabase(file));
      final WordRepository words = WordRepository(fresh);
      final StudyRepository study = StudyRepository(fresh);
      final SettingsRepository settings = SettingsRepository(fresh);
      final DateTime now = DateTime(2026, 11, 24, 9);
      final Word word = await words.ensureWord(
        text: 'abandon',
        translation: r'v. 放弃\nn. 放任',
        note: '我的笔记',
        now: now,
      );
      await study.recordAnswer(
        wordId: word.id,
        result: AnswerResult.known,
        type: ReviewType.study,
        eventId: 'old-event',
        deviceId: 'old-device',
        now: now,
      );
      await settings.save(dailyNewTarget: 17, accentColor: '#1565C0');
      await fresh.close();

      final sql.Database raw = sql.sqlite3.open(path);
      raw.execute('DROP INDEX IF EXISTS idx_entries_book');
      raw.execute('ALTER TABLE word_book_entries DROP COLUMN deleted_at');
      raw.execute('ALTER TABLE word_book_entries DROP COLUMN version');
      raw.execute('ALTER TABLE word_book_entries DROP COLUMN updated_at');
      raw.execute('ALTER TABLE word_books DROP COLUMN revision');
      raw.execute('ALTER TABLE review_events DROP COLUMN mode');
      raw.execute('ALTER TABLE study_settings DROP COLUMN accent_color');
      raw.execute('ALTER TABLE study_settings DROP COLUMN tts_voice');
      raw.execute('ALTER TABLE study_settings DROP COLUMN tts_locale');
      raw.execute('ALTER TABLE study_settings DROP COLUMN tts_rate');
      raw.execute('ALTER TABLE study_settings DROP COLUMN tts_auto_speak');
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

      final Word? after = await WordRepository(migrated).byId(word.id);
      expect(after, isNotNull);
      expect(after!.note, '我的笔记');
      expect(after.translation, 'v. 放弃\nn. 放任', reason: '升级同时修复旧转义');

      final List<ReviewEvent> events = await (migrated.select(
        migrated.reviewEvents,
      )).get();
      expect(events.single.id, 'old-event');
      expect(events.single.mode, 'normal');

      final LearningState? state = await StudyRepository(migrated)
          .rebuildAndRead(word.id);
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
