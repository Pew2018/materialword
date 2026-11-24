import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/repositories/settings_repository.dart';
import 'package:materialword/services/backup_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final instant = DateTime.utc(2026, 11, 25, 12);

  Future<void> transfer(TestEnv source, TestEnv target) async {
    final data = jsonDecode(
      await source.backup.exportToJson(now: instant),
    ) as Map<String, Object?>;
    await target.backup.mergeDataset(data, now: instant);
  }

  Future<String> hash(TestEnv env) async =>
      BackupService.contentHashOf(await env.backup.buildDataset(now: instant));

  test('independent identities retain later word/book renames and links on three devices', () async {
    final a = await TestEnv.create(),
        b = await TestEnv.create(),
        c = await TestEnv.create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    addTearDown(c.dispose);
    final ab = await a.seedBook(words: ['alpha']);
    final bb = await b.seedBook(words: ['alpha']);
    final aw = (await a.words.byNormalized('alpha'))!;
    final bw = (await b.words.byNormalized('alpha'))!;
    expect(aw.id, isNot(bw.id));
    await transfer(a, b);
    await transfer(b, a);
    await a.words.updateContent(aw.id, text: 'alphabet', now: instant);
    await a.books.rename(ab.id, '重命名词书', now: instant);
    await transfer(a, b);
    expect((await b.words.byId(bw.id))!.normalized, 'alphabet');
    expect(await b.words.byNormalized('alpha'), isNull);
    expect((await b.books.byId(bb.id))!.name, '重命名词书');
    expect(await b.books.wordCount(bb.id), 1);
    await transfer(b, c);
    await transfer(c, a);
    await transfer(a, b);
    expect(await hash(a), await hash(b));
    expect(await hash(b), await hash(c));
    expect(await b.db.select(b.db.words).get(), hasLength(1));
    expect(await c.db.select(c.db.wordBooks).get(), hasLength(1));
  });

  test('independent fields survive concurrent edits, first restore and later edits', () async {
    final a = await TestEnv.create(),
        b = await TestEnv.create(),
        c = await TestEnv.create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    addTearDown(c.dispose);
    await a.seedBook(words: ['alpha']);
    await transfer(a, b);
    final id = (await a.words.byNormalized('alpha'))!.id;
    await a.words.updateContent(id, note: '用户原样笔记\n第二行', now: instant);
    await b.words.updateContent(
      id,
      definition: 'independent definition',
      now: instant,
    );
    await transfer(a, b);
    await transfer(b, a);
    expect((await a.words.byId(id))!.note, '用户原样笔记\n第二行');
    expect((await a.words.byId(id))!.definition, 'independent definition');
    await transfer(a, c);
    await c.words.updateContent(id, phonetic: '/test/', now: instant);
    await transfer(c, a);
    await transfer(a, b);
    await transfer(b, c);
    expect((await b.words.byId(id))!.note, '用户原样笔记\n第二行');
    expect((await b.words.byId(id))!.definition, 'independent definition');
    expect((await b.words.byId(id))!.phonetic, '/test/');
    expect(await hash(a), await hash(b));
    expect(await hash(b), await hash(c));
  });

  test(
    'same-field equal-time conflict has a deterministic source tie break',
    () async {
      final a = await TestEnv.create(), b = await TestEnv.create();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.seedBook(words: ['alpha']);
      await transfer(a, b);
      await a.db.writeMeta(SettingsRepository.deviceIdKey, 'device-a');
      await b.db.writeMeta(SettingsRepository.deviceIdKey, 'device-b');
      final id = (await a.words.byNormalized('alpha'))!.id;
      await a.words.updateContent(id, note: 'A note', now: instant);
      await b.words.updateContent(id, note: 'B note', now: instant);
      await transfer(a, b);
      await transfer(b, a);
      expect((await a.words.byId(id))!.note, 'B note');
      expect(await hash(a), await hash(b));
    },
  );

  test(
    'unobserved edit cannot revive a deletion, explicit re-add can',
    () async {
      final a = await TestEnv.create(), b = await TestEnv.create();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.seedBook(words: ['alpha']);
      await transfer(a, b);
      final id = (await a.words.byNormalized('alpha'))!.id;
      await a.words.softDelete(id, now: instant);
      // A badly skewed clock and many content revisions cannot undo a deletion.
      for (var i = 0; i < 5; i++) {
        await b.words.updateContent(
          id,
          note: 'offline $i',
          now: DateTime.utc(2099),
        );
      }
      await transfer(b, a);
      await transfer(a, b);
      expect((await b.words.byId(id))!.deletedAt, isNotNull);
      await b.words.ensureWord(
        text: 'alpha',
        now: instant.add(const Duration(days: 1)),
      );
      await transfer(b, a);
      await transfer(a, b);
      expect((await a.words.byId(id))!.deletedAt, isNull);
      expect((await a.words.byId(id))!.note, 'offline 4');
      expect(await hash(a), await hash(b));
    },
  );

  test(
    'legacy omission preserves local text while explicit empty clears it',
    () async {
      final a = await TestEnv.create();
      addTearDown(a.dispose);
      await a.seedBook(words: ['alpha']);
      final id = (await a.words.byNormalized('alpha'))!.id;
      await a.words.updateContent(id, note: '保留', now: instant);
      final data = await a.backup.buildDataset(now: instant);
      final row = (data['words'] as List).single as Map<String, Object?>;
      row.remove('fieldVersions');
      row.remove('note');
      row['revision'] = 99;
      row['translation'] = 'legacy update';
      await a.backup.mergeDataset(data, now: instant);
      expect((await a.words.byId(id))!.note, '保留');
      expect((await a.words.byId(id))!.translation, 'legacy update');
      row['note'] = '';
      row['revision'] = 100;
      await a.backup.mergeDataset(data, now: instant);
      expect((await a.words.byId(id))!.note, isEmpty);
    },
  );

  test(
    'rename collision is atomic and does not persist incoming aliases',
    () async {
      final a = await TestEnv.create(), b = await TestEnv.create();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.seedBook(words: ['alpha']);
      await transfer(a, b);
      final id = (await a.words.byNormalized('alpha'))!.id;
      await b.words.ensureWord(text: 'beta', now: instant);
      await a.words.updateContent(id, text: 'beta', now: instant);
      final before = await hash(b);
      await expectLater(transfer(a, b), throwsA(isA<BackupException>()));
      expect(await hash(b), before);
      expect((await b.words.byId(id))!.word, 'alpha');
    },
  );

  test('saving unchanged content is a no-op and stale dictionary fills current row only', () async {
    final a = await TestEnv.create();
    addTearDown(a.dispose);
    await a.seedBook(words: ['alpha']);
    final stale = (await a.words.byNormalized('alpha'))!;
    await a.words.updateContent(stale.id, note: '', now: instant);
    final before = await hash(a);
    await a.words.updateContent(stale.id, note: '', now: instant);
    expect(await hash(a), before);
    await a.words.updateContent(
      stale.id,
      note: 'new note',
      definition: 'manual',
      now: instant,
    );
    await a.words.applyDictionaryInfo(
      word: stale,
      definition: 'dictionary',
      phonetic: '/a/',
      now: instant,
    );
    final word = (await a.words.byId(stale.id))!;
    expect(word.note, 'new note');
    expect(word.definition, 'manual');
    expect(word.phonetic, '/a/');
  });

  test('concurrent first use shares one device and dataset identity', () async {
    final a = await TestEnv.create();
    addTearDown(a.dispose);
    final devices = await Future.wait(
      List.generate(20, (_) => a.settings.deviceId()),
    );
    final datasets = await Future.wait(
      List.generate(20, (_) => a.settings.datasetId()),
    );
    expect(devices.toSet(), hasLength(1));
    expect(datasets.toSet(), hasLength(1));
    expect(devices.first, isNot(datasets.first));
  });

  test(
    'deleted book and fresh same-name book keep separate links and hashes',
    () async {
      final a = await TestEnv.create(), b = await TestEnv.create();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final old = await a.seedBook(words: ['alpha']);
      await transfer(a, b);
      await a.books.softDelete(old.id, now: instant);
      final fresh = await a.books.create(
        name: old.name,
        now: instant.add(const Duration(seconds: 1)),
      );
      final word = (await a.words.byNormalized('alpha'))!;
      await a.books.addWords(fresh.id, [
        word.id,
      ], now: instant.add(const Duration(seconds: 2)));
      await transfer(a, b);
      await transfer(b, a);
      expect((await b.books.byId(old.id))!.deletedAt, isNotNull);
      expect((await b.books.byId(fresh.id))!.deletedAt, isNull);
      expect(await b.books.wordCount(fresh.id), 1);
      expect(await hash(a), await hash(b));
      final data = await a.backup.buildDataset(now: instant);
      final changed = jsonDecode(jsonEncode(data)) as Map<String, Object?>;
      (changed['entries'] as List).removeWhere(
        (e) => e['wordBookId'] == old.id,
      );
      final other = jsonDecode(jsonEncode(data)) as Map<String, Object?>;
      (other['entries'] as List).removeWhere(
        (e) => e['wordBookId'] == fresh.id,
      );
      expect(
        BackupService.contentHashOf(changed),
        isNot(BackupService.contentHashOf(other)),
      );
    },
  );

  test('malformed stamps and ambiguous aliases reject all writes', () async {
    final a = await TestEnv.create();
    addTearDown(a.dispose);
    await a.seedBook(words: ['alpha', 'beta']);
    final original = await a.backup.buildDataset(now: instant);
    final before = await hash(a);
    for (final bad in [
      {
        'note': {'version': -1, 'updatedAt': 0, 'deviceId': 'a'},
      },
      {
        'unknown': {'version': 1, 'updatedAt': 0, 'deviceId': 'a'},
      },
      {
        'note': {'version': 1, 'updatedAt': 'invalid', 'deviceId': 'a'},
      },
    ]) {
      final data = jsonDecode(jsonEncode(original)) as Map<String, Object?>;
      ((data['words'] as List).first as Map)['fieldVersions'] = bad;
      await expectLater(
        a.backup.mergeDataset(data, now: instant),
        throwsA(isA<BackupException>()),
      );
      expect(await hash(a), before);
    }
    final data = jsonDecode(jsonEncode(original)) as Map<String, Object?>;
    final rows = data['words'] as List;
    (rows.first as Map)['aliases'] = [(rows.last as Map)['id']];
    await expectLater(
      a.backup.mergeDataset(data, now: instant),
      throwsA(isA<BackupException>()),
    );
    expect(await hash(a), before);
  });
}
