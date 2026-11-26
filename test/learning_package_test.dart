import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/learning_package.dart';
import 'package:materialword/services/wordbook_export.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final format in WordBookExportFormat.values) {
    test(
      '${format.name} package roundtrip, selected scope and repeated merge',
      () async {
        final a = await TestEnv.create();
        final b = await TestEnv.create();
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        final one = await a.seedBook(name: 'One', words: ['alpha', 'beta']);
        final two = await a.seedBook(name: 'Two', words: ['alpha', 'gamma']);
        await a.seedBook(name: 'Private', words: ['secret']);
        await b.seedBook(name: 'Keep', words: ['unrelated']);
        final alpha = (await a.words.byNormalized('alpha'))!;
        await a.study.recordAnswer(
          wordId: alpha.id,
          result: AnswerResult.known,
          type: ReviewType.study,
          eventId: 'a',
          deviceId: 'a',
          now: a.clock.now(),
        );
        final bytes = await LearningPackage.export(
          a.backup,
          {one.id, two.id},
          format,
          a.clock.now(),
        );
        final service = b.importService();
        final preview = service.parseBytes(bytes, name: 'book.zip');
        expect(preview.sectionCount, 2);
        expect(preview.validCount, 3);
        expect((await service.analyze(preview)).newWords, 3);
        expect(preview.progress!['learningStates'], hasLength(1));
        expect(preview.progress!['words'], hasLength(3));
        for (var i = 0; i < 2; i++) {
          await service.commit(
            preview: preview,
            mergeProgress: true,
            now: b.clock.now(),
          );
        }
        final restored = (await b.words.byNormalized('alpha'))!;
        expect((await b.words.stateFor(restored.id))!.correctCount, 1);
        expect(await b.words.byNormalized('secret'), isNull);
        expect(await b.words.byNormalized('unrelated'), isNotNull);
        final books = await b.db.select(b.db.wordBooks).get();
        expect(books.map((b) => b.name), containsAll(['One', 'Two', 'Keep']));
        final contentOnly = await TestEnv.create();
        addTearDown(contentOnly.dispose);
        await contentOnly.importService().commit(
          preview: preview,
          now: contentOnly.clock.now(),
        );
        expect(
          await contentOnly.db.select(contentOnly.db.learningStates).get(),
          isEmpty,
        );
      },
    );
  }

  test(
    'a checksummed package cannot carry library deletion commands',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      final book = await env.seedBook();
      final bytes = await LearningPackage.export(
        env.backup,
        {book.id},
        WordBookExportFormat.json,
        env.clock.now(),
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final files = {
        for (final file in archive)
          file.name: List<int>.from(file.content as List<int>),
      };
      final progress = jsonDecode(utf8.decode(files['progress.json']!)) as Map;
      (progress['words'] as List).first['deletedAt'] =
          '2026-11-26T00:00:00.000Z';
      files['progress.json'] = utf8.encode(jsonEncode(progress));
      final manifest = jsonDecode(utf8.decode(files['manifest.json']!)) as Map;
      manifest['files']['progress.json'] = {
        'bytes': files['progress.json']!.length,
        'sha256': sha256.convert(files['progress.json']!).toString(),
      };
      files['manifest.json'] = utf8.encode(jsonEncode(manifest));
      final altered = Archive();
      for (final entry in files.entries) {
        altered.addFile(
          ArchiveFile.noCompress(
            entry.key,
            entry.value.length,
            InputStream(entry.value),
          ),
        );
      }
      final alteredBytes = ZipEncoder().encode(altered)!;
      expect(
        () => LearningPackage.decode(alteredBytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'scope',
            contains('删除指令'),
          ),
        ),
      );
    },
  );

  test(
    'reject path traversal, compressed entries and excessive file counts',
    () {
      for (final name in ['../progress.json', 'progress.json']) {
        final archive = Archive()
          ..addFile(ArchiveFile(name, 1000000, List.filled(1000000, 0)));
        expect(
          () => LearningPackage.decode(ZipEncoder().encode(archive)!),
          throwsFormatException,
        );
      }
    },
  );
}
