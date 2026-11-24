import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/repositories/settings_repository.dart';
import 'package:materialword/core/repositories/study_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'helpers/legacy_schema.dart';

class FailingMigrationDatabase extends AppDatabase {
  FailingMigrationDatabase(super.executor);
  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) {
    if (statement.startsWith('CREATE TABLE') &&
        statement.contains('"user_tags"')) {
      throw StateError('Injected interruption during migration');
    }
    return super.customStatement(statement, args);
  }
}

void main() {
  final anchor = DateTime.utc(2026, 11, 23, 16).millisecondsSinceEpoch;
  final answered = DateTime.utc(2026, 11, 24, 1).millisecondsSinceEpoch;
  final due = anchor + const Duration(days: 1).inMilliseconds;
  void seed(String path, int version) {
    final db = sql.sqlite3.open(path);
    db.execute(version == 1 ? phase1Schema : phase2Schema);
    db.execute(
      'INSERT INTO words(id,word,normalized,note,created_at,updated_at) VALUES(?,?,?,?,?,?)',
      [
        'word',
        'alpha',
        'alpha',
        'personal note retained exactly',
        answered,
        answered,
      ],
    );
    db.execute(
      'INSERT INTO words(id,word,normalized,deleted_at,created_at,updated_at) VALUES(?,?,?,?,?,?)',
      ['deleted-word', 'beta', 'beta', answered, answered, answered],
    );
    db.execute(
      'INSERT INTO word_books(id,name,created_at,updated_at) VALUES(?,?,?,?)',
      ['book', 'Legacy', answered, answered],
    );
    db.execute(
      'INSERT INTO word_book_entries(word_book_id,word_id,added_at) VALUES(?,?,?)',
      ['book', 'word', answered],
    );
    db.execute(
      'INSERT INTO review_events(id,word_id,device_id,answered_at,local_day,result,type,interval_days_after,algo_version) VALUES(?,?,?,?,?,?,?,?,?)',
      [
        'event',
        'word',
        'original-device',
        answered,
        '2026-11-24',
        2,
        'study',
        1,
        1,
      ],
    );
    db.execute(
      'INSERT INTO learning_states(word_id,stage,correct_count,streak,interval_days,last_studied_at,next_review_at,updated_at) VALUES(?,?,?,?,?,?,?,?)',
      ['word', 1, 1, 1, 1, answered, due, answered],
    );
    db.execute(
      "INSERT INTO study_settings(id,daily_new_target,theme_mode,current_word_book_id) VALUES(1,42,'dark','book')",
    );
    db.execute(
      "INSERT INTO app_meta(key,value) VALUES('device_id','original-device')",
    );
    db.execute(
      "INSERT INTO app_meta(key,value) VALUES('last_sync_remote_revision','opaque-revision')",
    );
    if (version == 2) {
      db.execute(
        "UPDATE study_settings SET accent_color='#00796B',tts_rate=73",
      );
      db.execute(
        'UPDATE word_book_entries SET version=9,updated_at=?,deleted_at=?',
        [answered + 1, answered + 1],
      );
    }
    db.execute('PRAGMA user_version=$version');
    db.dispose();
  }

  for (final version in [1, 2]) {
    test(
      'DB actual Schema $version upgrades without changing notes, state, identity or tombstones',
      () async {
        final dir = await Directory.systemTemp.createTemp('mw_v${version}_');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}/user.db';
        seed(path, version);
        final db = AppDatabase(NativeDatabase(File(path)));
        addTearDown(db.close);
        final settings = await SettingsRepository(db).load();
        expect(settings.dailyNewTarget, 42);
        expect(settings.themeMode, 'dark');
        expect(settings.currentWordBookId, 'book');
        expect(await db.readMeta('device_id'), 'original-device');
        expect(
          await db.readMeta('last_sync_remote_revision'),
          'opaque-revision',
        );
        final word = await (db.select(
          db.words,
        )..where((t) => t.id.equals('word'))).getSingle();
        expect(word.note, 'personal note retained exactly');
        expect(
          (await (db.select(
            db.words,
          )..where((t) => t.id.equals('deleted-word'))).getSingle()).deletedAt,
          answered,
        );
        final state = await db.select(db.learningStates).getSingle();
        expect(state.nextReviewAt, due);
        expect(state.correctCount, 1);
        final event = await db.select(db.reviewEvents).getSingle();
        expect(event.dayStartUtc, anchor);
        await StudyRepository(db).rebuildStateFromEvents('word');
        expect(
          (await db.select(db.learningStates).getSingle()).nextReviewAt,
          due,
        );
        if (version == 2) {
          expect(settings.accentColor, '#00796B');
          expect(settings.ttsRate, 73);
          final link = await db.select(db.wordBookEntries).getSingle();
          expect(link.version, 9);
          expect(link.deletedAt, answered + 1);
        }
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          3,
        );
        expect(await db.select(db.userTags).get(), isEmpty);
      },
    );

    test(
      'DB interrupted Schema $version migration rolls back and next open succeeds',
      () async {
        final dir = await Directory.systemTemp.createTemp('mw_interrupt_');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}/user.db';
        seed(path, version);
        final interrupted = FailingMigrationDatabase(
          NativeDatabase(File(path)),
        );
        await expectLater(
          interrupted.customSelect('SELECT 1').get(),
          throwsStateError,
        );
        await interrupted.close();
        final raw = sql.sqlite3.open(path);
        expect(
          raw.select('PRAGMA user_version').first['user_version'],
          version,
        );
        expect(
          raw
              .select('PRAGMA table_info(review_events)')
              .any((r) => r['name'] == 'day_start_utc'),
          isFalse,
        );
        expect(
          raw
              .select(
                "SELECT COUNT(*) AS n FROM sqlite_master WHERE name='word_favorites'",
              )
              .first['n'],
          0,
        );
        raw.dispose();
        final reopened = AppDatabase(NativeDatabase(File(path)));
        addTearDown(reopened.close);
        expect((await reopened.select(reopened.words).get()).length, 2);
        expect(await reopened.readMeta('device_id'), 'original-device');
      },
    );
  }
}
