import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:materialword/services/dictionary_packages.dart';
import 'package:materialword/services/dictionary_service.dart';
import 'package:materialword/services/offline_migration.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'core provenance, exam coverage and forms remain queryable offline',
    () async {
      final dictionary = DictionaryService.openFile(
        'assets/dictionary/ecdict_core.db',
      );
      addTearDown(dictionary.close);
      expect(await dictionary.count(), 57835);
      for (final tag in ['ielts', 'toefl', 'gre', 'cet4', 'cet6', 'ky']) {
        expect((await dictionary.examWords(tag)).length, greaterThan(1000));
      }
      expect((await dictionary.lookup('go'))!.exchange, isNotEmpty);
    },
  );

  test('range resume, validation, shared selection and uninstall protect user data', () async {
    final env = await TestEnv.create();
    final other = await TestEnv.create();
    addTearDown(env.dispose);
    addTearDown(other.dispose);
    await env.seedBook();
    final directory = Directory('${env.backupDirectory.path}/packages')
      ..createSync();
    final resource = await File('resources/dictionaries/ecdict_extended.db.gz')
        .readAsBytes();
    final partial = File(
      '${directory.path}/${DictionaryPackages.digest}.db.gz.part',
    );
    await partial.writeAsBytes(resource.sublist(0, 1000));
    var corrupt = false;
    final packages = DictionaryPackages(
      env.db,
      directory: () async => directory,
      client: MockClient((request) async {
        if (corrupt) return http.Response.bytes([0], 200);
        expect(request.headers['range'], 'bytes=1000-');
        return http.Response.bytes(
          resource.sublist(1000),
          206,
          headers: {
            'content-range':
                'bytes 1000-${resource.length - 1}/${resource.length}',
          },
        );
      }),
    );
    addTearDown(packages.close);
    await packages.install();
    expect(await packages.installed(), isTrue);
    expect(await packages.enabled(), isTrue);
    corrupt = true;
    await expectLater(packages.install(), throwsFormatException);
    expect(await packages.installed(), isTrue);
    final snapshot = await env.backup.buildDataset(now: env.clock.now());
    await other.backup.mergeDataset(snapshot, now: other.clock.now());
    expect(
      await DictionaryPackages.snapshot(other.db),
      await DictionaryPackages.snapshot(env.db),
    );
    await packages.uninstall();
    expect(await packages.installed(), isFalse);
    expect(await packages.enabled(), isFalse);
    expect(await env.words.byNormalized('alpha'), isNotNull);
  });

  test(
    'offline migration carries resources and restores without network',
    () async {
      final env = await TestEnv.create();
      final other = await TestEnv.create();
      addTearDown(env.dispose);
      addTearDown(other.dispose);
      await env.seedBook();
      final firstDir = Directory('${env.backupDirectory.path}/packages')
        ..createSync();
      final secondDir = Directory('${other.backupDirectory.path}/packages')
        ..createSync();
      final a = DictionaryPackages(env.db, directory: () async => firstDir);
      final b = DictionaryPackages(other.db, directory: () async => secondDir);
      addTearDown(a.close);
      addTearDown(b.close);
      await (await a.file()).writeAsBytes(
        gzip.decode(
          await File('resources/dictionaries/ecdict_extended.db.gz')
              .readAsBytes(),
        ),
      );
      await a.setEnabled(true);
      final bytes = await OfflineMigration.export(
        env.backup,
        a,
        env.clock.now(),
      );
      final result = await OfflineMigration.restore(bytes, other.backups, b);
      expect(result.syncPaused, isTrue);
      expect(await b.installed(), isTrue);
      expect(await b.missing(), isEmpty);
      expect(await other.words.byNormalized('alpha'), isNotNull);
    },
  );
}
