import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/services/learning_package.dart';
import 'package:materialword/services/wordbook_export.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all documented bare examples actually parse and import', () async {
    for (final file in [
      'words.txt',
      'words.csv',
      'wordbook.json',
      'wordbooks.csv',
      'wordbooks.json',
    ]) {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      final service = env.importService();
      final preview = await service.parseFile('examples/$file');
      expect(preview.invalidCount, 0, reason: file);
      expect(preview.droppedRows, 0, reason: file);
      await service.commit(preview: preview, now: env.clock.now());
      expect(await env.words.byNormalized('alpha'), isNotNull);
      if (file.startsWith('wordbooks')) {
        expect(await env.db.select(env.db.wordBooks).get(), hasLength(2));
        expect(await env.words.byNormalized('journey'), isNotNull);
        final alpha = (await env.words.byNormalized('alpha'))!;
        final memberships = await (env.db.select(
          env.db.wordBookEntries,
        )..where((t) => t.wordId.equals(alpha.id))).get();
        expect(memberships, hasLength(2));
      }
    }
  });
  test('README fenced data examples parse and commit', () async {
    final readme = await File('README.md').readAsString();
    final examples = RegExp(r'```(text|csv|json)\n([\s\S]*?)```')
        .allMatches(readme);
    expect(examples, hasLength(5));
    for (final example in examples) {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      final service = env.importService();
      final preview = service.parseContent(
        example.group(2)!,
        format: example.group(1) == 'text' ? 'txt' : example.group(1)!,
        name: 'readme',
      );
      expect(preview.invalidCount, 0);
      await service.commit(preview: preview, now: env.clock.now());
      expect(await env.words.byNormalized('alpha'), isNotNull);
    }
  });
  test('documented learning packages roundtrip with real progress', () async {
    final env = await TestEnv.create(now: DateTime.utc(2026, 11, 26, 9));
    addTearDown(env.dispose);
    final book = await env.seedBook(name: 'Everyday', words: ['alpha', 'beta']);
    final alpha = (await env.words.byNormalized('alpha'))!;
    await env.study.recordAnswer(
      wordId: alpha.id,
      result: AnswerResult.known,
      type: ReviewType.study,
      eventId: 'example-answer-alpha',
      deviceId: 'example-device',
      now: env.clock.now(),
    );
    for (final format in WordBookExportFormat.values) {
      final file = File('examples/learning-${format.name}.zip');
      if (Platform.environment['GENERATE_EXAMPLES'] == '1') {
        await file.writeAsBytes(
          await LearningPackage.export(
            env.backup,
            {book.id},
            format,
            env.clock.now(),
          ),
        );
      }
      final other = await TestEnv.create();
      addTearDown(other.dispose);
      final preview = await other.importService().parseFile(file.path);
      await other.importService().commit(
        preview: preview,
        mergeProgress: true,
        now: other.clock.now(),
      );
      final word = (await other.words.byNormalized('alpha'))!;
      expect((await other.words.stateFor(word.id))!.correctCount, 1);
    }
  });
}
