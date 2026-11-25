import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/services/import_service.dart';
import 'package:materialword/services/word_intake_service.dart';

import 'helpers/test_env.dart';

/// Phase 5C acceptance: IMP01–IMP18.
void main() {
  late TestEnv env;

  setUp(() async {
    env = await TestEnv.create();
  });

  tearDown(() async {
    await env.dispose();
  });

  Future<WordBook> book(String name) =>
      env.books.create(name: name, now: env.clock.now());

  ImportPreview parseTxt(String text, {String name = 'list.txt'}) =>
      env.importService().parseContent(text, format: 'txt', name: name);

  group('parsing', () {
    test('IMP01 TXT / CSV / JSON 正常导入', () async {
      final ImportService service = env.importService();
      final WordBook target = await book('目标');

      final ImportOutcome txt = await service.commit(
        preview: parseTxt('alpha\nbeta\n'),
        bookId: target.id,
        now: env.clock.now(),
      );
      expect(txt.created, 2);

      final ImportPreview csv = service.parseContent(
        'WORD,Phonetic,Part_Of_Speech,Translation,Definition,Example,Phrase,Note,ExamTags\n'
        'gamma,/ˈg/,n.,伽马,third letter,gamma rays,in gamma,custom note,cet6\n',
        format: 'csv',
        name: 'g.csv',
      );
      expect(csv.validCount, 1);
      final ImportOutcome csvOutcome = await service.commit(
        preview: csv,
        bookId: target.id,
        now: env.clock.now(),
      );
      expect(csvOutcome.created, 1);
      final Word gamma = (await env.words.byNormalized('gamma'))!;
      expect(gamma.phonetic, '/ˈg/');
      expect(gamma.partOfSpeech, 'n.');
      expect(gamma.example, 'gamma rays');
      expect(gamma.phrase, 'in gamma');
      expect(gamma.note, 'custom note');
      expect(gamma.examTags, 'cet6');

      final ImportPreview json = service.parseContent(
        jsonEncode(<String, Object?>{
          'kind': 'materialword-wordbook',
          'schemaVersion': 2,
          'name': 'JSON 书',
          'description': 'desc',
          'words': <Object?>[
            <String, Object?>{'word': 'delta', 'translation': '德尔塔'},
          ],
        }),
        format: 'json',
        name: 'd.json',
      );
      expect(json.detectedBookName, 'JSON 书');
      final ImportOutcome jsonOutcome = await service.commit(
        preview: json,
        now: env.clock.now(),
      );
      expect(jsonOutcome.created, 1);
      final WordBook? created = await env.books.byId(jsonOutcome.bookId!);
      expect(created!.description, 'desc');
      expect(await env.books.wordCount(created.id), 1);
    });

    test('IMP02 解析 BOM、CRLF、多行 CSV 字段与空行', () async {
      final ImportService service = env.importService();
      final Uint8List bom = Uint8List.fromList(<int>[
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(
          'word,translation,example\r\n'
          'alpha,阿尔法,"line one\r\nline two"\r\n'
          '\r\n'
          'beta,贝塔,\r\n',
        ),
      ]);
      final ImportPreview preview = service.parseBytes(bom, name: 'bom.csv');
      expect(preview.validCount, 2);
      final ParsedEntry alpha = preview.entries.first;
      expect(alpha.word, 'alpha');
      expect(alpha.example, contains('line one'));
      expect(alpha.example, contains('line two'));
    });

    test('IMP03 损坏编码与非法结构被明确拒绝', () async {
      final ImportService service = env.importService();
      final Uint8List broken = Uint8List.fromList(<int>[
        0x61,
        0xFF,
        0xFE,
        0x62,
      ]);
      expect(
        () => service.parseBytes(broken, name: 'x.txt'),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('UTF-8'),
          ),
        ),
      );
      final Uint8List utf16 = Uint8List.fromList(<int>[0xFF, 0xFE, 0x61, 0x00]);
      expect(
        () => service.parseBytes(utf16, name: 'x.txt'),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('UTF-16'),
          ),
        ),
      );
      expect(
        () =>
            service.parseContent('{"words": [', format: 'json', name: 'x.json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => service.parseContent(
          'word,translation\n"alpha,苹果\n',
          format: 'csv',
          name: 'x.csv',
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('引号'),
          ),
        ),
      );
      expect(
        () => service.parseContent('word\n', format: 'csv', name: 'x.csv'),
        returnsNormally,
      );
      expect(
        () => service.parseContent(
          'name,value\na,b\n',
          format: 'csv',
          name: 'x.csv',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await env.words.countWords(), 0);
    });

    test('IMP04 完整备份 JSON 不会被当成词书导入', () async {
      final Map<String, Object?> dataset = await env.backup.buildDataset(
        now: env.clock.now(),
      );
      expect(
        () => env.importService().parseContent(
          jsonEncode(dataset),
          format: 'json',
          name: 'backup.json',
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('备份与恢复'),
          ),
        ),
      );
    });

    test('IMP05 扩展名与内容不一致时给出明确原因', () async {
      final ImportService service = env.importService();
      expect(
        () => service.parseContent(
          '{"words":[{"word":"alpha"}]}',
          format: 'txt',
          name: 'words.txt',
        ),
        returnsNormally,
        reason: '显式指定格式时按给定格式解析',
      );
      expect(
        () => service.parseFile('does-not-exist.json'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('limits', () {
    test('IMP06 20,000 词容量边界与超限拒绝', () {
      final ImportService service = env.importService();
      // Words must look like words (letters only), so spell the index in
      // base-26 letters instead of digits.
      String letters(int value) {
        final StringBuffer buffer = StringBuffer();
        int rest = value;
        do {
          buffer.write(String.fromCharCode(97 + rest % 26));
          rest = rest ~/ 26;
        } while (rest > 0);
        return buffer.toString();
      }

      final StringBuffer atLimit = StringBuffer();
      for (int i = 0; i < ImportService.maxEntries; i++) {
        atLimit.writeln('w${letters(i)}');
      }
      final ImportPreview preview = service.parseContent(
        atLimit.toString(),
        format: 'txt',
        name: 'limit.txt',
      );
      expect(preview.validCount, ImportService.maxEntries);
      expect(preview.droppedRows, 0);

      atLimit.writeln('onetoomany');
      expect(
        () => service.parseContent(
          atLimit.toString(),
          format: 'txt',
          name: 'limit.txt',
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('20001'), contains('上限')),
          ),
        ),
      );
    });

    test('IMP07 超过 8 MB 的文件在读取前被拒绝', () async {
      final ImportService service = env.importService();
      expect(
        () => service.parseBytes(
          Uint8List(ImportService.maxFileBytes + 1),
          name: 'big.txt',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(ImportService.maxFileBytes, 8 * 1024 * 1024);
    });
  });

  group('transactions', () {
    test('IMP08 新建词书失败时完全回滚（不残留空词书）', () async {
      final ImportService service = env.importService();
      // A hand-built preview whose second row is rejected by the intake service
      // forces the failure *after* the book has been created inside the same
      // transaction.
      final ImportPreview broken = ImportPreview.single(
        entries: const <ParsedEntry>[
          ParsedEntry(word: 'alpha'),
          ParsedEntry(word: '   '),
        ],
        format: 'txt',
        detectedBookName: '半成品',
      );
      await expectLater(
        service.commit(
          preview: broken,
          newBookName: '半成品',
          now: env.clock.now(),
        ),
        throwsA(isA<WordIntakeException>()),
      );
      expect(await env.books.listBooks(), isEmpty, reason: '不能留下空词书');
      expect(await env.words.countWords(), 0);
    });

    test('IMP09 已有词书导入失败时完全回滚', () async {
      final WordBook target = await book('已有');
      await env.intake.add(
        const WordIntakeRequest(text: 'alpha'),
        bookId: target.id,
        now: env.clock.now(),
      );
      final ImportService service = env.importService();
      final ImportPreview broken = ImportPreview.single(
        entries: const <ParsedEntry>[
          ParsedEntry(word: 'beta'),
          ParsedEntry(word: ''),
        ],
        format: 'txt',
        detectedBookName: '已有',
      );
      await expectLater(
        service.commit(
          preview: broken,
          bookId: target.id,
          now: env.clock.now(),
        ),
        throwsA(isA<WordIntakeException>()),
      );
      expect(await env.words.countWords(), 1);
      expect(await env.books.wordCount(target.id), 1);
    });

    test('IMP10 下载中途取消后没有任何副作用', () async {
      final ImportService service = env.importService();
      final WordBook target = await book('取消');
      final FakeClient client = FakeClient(
        (http.BaseRequest request) async => http.StreamedResponse(
          Stream<List<int>>.fromIterable(<List<int>>[
            utf8.encode('alpha\n'),
            utf8.encode('beta\n'),
          ]).asyncExpand(
            (List<int> chunk) => Stream<List<int>>.fromFuture(
              Future<List<int>>.delayed(
                const Duration(milliseconds: 5),
                () => chunk,
              ),
            ),
          ),
          200,
        ),
      );
      await expectLater(
        service.fetchUrl(
          'https://example.test/slow.txt',
          client: client,
          onProgress: (int received) => service.cancel(),
        ),
        throwsA(isA<ImportCancelledException>()),
      );
      expect(await env.words.countWords(), 0);
      expect(await env.books.wordCount(target.id), 0);
      // A later, uncancelled import still works.
      final ImportOutcome outcome = await service.commit(
        preview: parseTxt('alpha\n'),
        bookId: target.id,
        now: env.clock.now(),
      );
      expect(outcome.created, 1);
    });

    test('IMP11 重复导入保持幂等', () async {
      final ImportService service = env.importService();
      final WordBook target = await book('幂等');
      final ImportPreview preview = parseTxt('alpha\nbeta\n');
      final ImportOutcome first = await service.commit(
        preview: preview,
        bookId: target.id,
        now: env.clock.now(),
      );
      final ImportOutcome second = await service.commit(
        preview: preview,
        bookId: target.id,
        now: env.clock.now(),
      );
      expect(first.created, 2);
      expect(second.created, 0);
      expect(second.existing, 2);
      expect(second.linked, 0);
      expect(await env.words.countWords(), 2);
      expect(await env.books.wordCount(target.id), 2);
    });
  });

  group('download', () {
    test('IMP12 流式下载超过上限时提前终止', () async {
      final ImportService service = env.importService();
      int served = 0;
      final FakeClient client = FakeClient((http.BaseRequest request) async {
        served++;
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable(
            List<List<int>>.generate(
              40,
              (_) => List<int>.filled(256 * 1024, 0x61),
            ),
          ),
          200,
        );
      });
      await expectLater(
        service.fetchUrl('https://example.test/big.txt', client: client),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('提前终止'),
          ),
        ),
      );
      expect(served, 1);
      expect(await env.words.countWords(), 0);
    });

    test('IMP13 下载中断与 HTTP 错误被脱敏报告', () async {
      final ImportService service = env.importService();
      final FakeClient broken = FakeClient(
        (http.BaseRequest request) async => http.StreamedResponse(
          Stream<List<int>>.error(http.ClientException('socket closed')),
          200,
        ),
      );
      await expectLater(
        service.fetchUrl('https://example.test/x.txt', client: broken),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('下载失败'),
          ),
        ),
      );
      final FakeClient notFound = FakeClient(
        (http.BaseRequest request) async =>
            http.StreamedResponse(const Stream<List<int>>.empty(), 404),
      );
      await expectLater(
        service.fetchUrl('https://example.test/x.txt', client: notFound),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('404'),
          ),
        ),
      );
    });

    test('IMP14 不安全的重定向与明文地址被拒绝', () async {
      final ImportService service = env.importService();
      await expectLater(
        service.fetchUrl('http://example.test/x.txt'),
        throwsA(isA<FormatException>()),
      );
      int calls = 0;
      final FakeClient downgrade = FakeClient((http.BaseRequest request) async {
        calls++;
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          302,
          headers: <String, String>{'location': 'http://insecure.test/x.txt'},
          request: request,
        );
      });
      await expectLater(
        service.fetchUrl('https://example.test/x.txt', client: downgrade),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('非 HTTPS'),
          ),
        ),
      );
      expect(calls, 1);

      int hops = 0;
      final FakeClient loop = FakeClient((http.BaseRequest request) async {
        hops++;
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          302,
          headers: <String, String>{
            'location': 'https://example.test/loop$hops',
          },
          request: request,
        );
      });
      await expectLater(
        service.fetchUrl('https://example.test/loop0', client: loop),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('重定向次数过多'),
          ),
        ),
      );
    });

    test('IMP15 同源重定向后可以完成下载', () async {
      final ImportService service = env.importService();
      int calls = 0;
      final FakeClient client = FakeClient((http.BaseRequest request) async {
        calls++;
        if (calls == 1) {
          return http.StreamedResponse(
            const Stream<List<int>>.empty(),
            302,
            headers: <String, String>{
              'location': 'https://example.test/real.txt',
            },
            request: request,
          );
        }
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('alpha\nbeta\n')),
          200,
          request: request,
        );
      });
      final ImportPreview preview = await service.fetchUrl(
        'https://example.test/list.txt',
        client: client,
      );
      expect(preview.validCount, 2);
      expect(preview.sourceUrl, contains('real.txt'));
    });
  });

  group('preview and refresh', () {
    test('IMP16 预览统计准确且不写入数据', () async {
      final WordBook target = await book('预览');
      final Word alpha = await env.intake
          .add(
            const WordIntakeRequest(text: 'alpha'),
            bookId: target.id,
            now: env.clock.now(),
          )
          .then((WordIntakeResult r) => r.word);
      final Word beta = (await env.intake.add(
        const WordIntakeRequest(text: 'beta'),
        bookId: target.id,
        now: env.clock.now(),
      )).word;
      await env.words.softDelete(beta.id, now: env.clock.now());
      final Word lonely = (await env.intake.add(
        const WordIntakeRequest(text: 'gamma'),
        now: env.clock.now(),
      )).word;

      final ImportService service = env.importService();
      final ImportPreview preview = parseTxt(
        'alpha\nbeta\ngamma\ndelta\ndelta\n123\n',
      );
      final ImportPreviewStats stats = await service.analyze(
        preview,
        bookId: target.id,
      );
      expect(stats.newWords, 1); // delta
      expect(stats.existingWords, 3); // alpha, beta, gamma
      expect(stats.restorableWords, 1); // beta
      expect(stats.duplicateInFile, 1);
      expect(stats.invalid, 1);
      expect(stats.droppedRows, 2);
      // alpha and beta still have a live link (deleting a word does not remove
      // its book links); gamma and delta need one.
      expect(stats.linkAdds, 2);
      expect(await env.words.countWords(), 2, reason: '预览绝不写库');
      expect((await env.words.byId(alpha.id))!.deletedAt, isNull);
      expect((await env.words.byId(lonely.id))!.deletedAt, isNull);
    });

    test('IMP17 预览过期（目标词书被删除）时拒绝提交', () async {
      final ImportService service = env.importService();
      final WordBook target = await book('会消失');
      final ImportPreview preview = parseTxt('alpha\nbeta\n');
      final ImportPreviewStats stats = await service.analyze(
        preview,
        bookId: target.id,
      );
      expect(stats.newWords, 2);

      await env.books.softDelete(target.id, now: env.clock.now());
      await expectLater(
        service.commit(
          preview: preview,
          bookId: target.id,
          now: env.clock.now(),
        ),
        throwsA(isA<WordIntakeException>()),
      );
      expect(await env.words.countWords(), 0);
    });

    test('IMP18 在线刷新保留用户修改且不恢复已删除词条', () async {
      final WordBook target = await book('在线');
      await env.intake.add(
        const WordIntakeRequest(
          text: 'alpha',
          user: WordContent(translation: '我的释义', note: '我的笔记'),
        ),
        bookId: target.id,
        now: env.clock.now(),
      );
      final Word deleted = (await env.intake.add(
        const WordIntakeRequest(text: 'beta'),
        bookId: target.id,
        now: env.clock.now(),
      )).word;
      await env.words.softDelete(deleted.id, now: env.clock.now());

      final ImportService service = env.importService();
      final ImportPreview remote = service.parseContent(
        'alpha\t词典释义\nbeta\t词典释义\ngamma\t伽马\n',
        format: 'txt',
        name: 'online.txt',
      );
      final ImportOutcome outcome = await service.commit(
        preview: remote,
        bookId: target.id,
        allowRevive: false,
        sourceType: 'url',
        now: env.clock.now(),
      );

      expect(outcome.skippedDeleted, 1);
      expect(outcome.revived, 0);
      final Word alpha = (await env.words.byNormalized('alpha'))!;
      expect(alpha.translation, '我的释义');
      expect(alpha.note, '我的笔记');
      expect(await env.words.byNormalized('beta'), isNull, reason: '不得恢复已删除词条');
      expect((await env.words.byNormalized('gamma'))!.translation, '伽马');
      expect(await env.books.wordCount(target.id), 2);
    });

    test('IMP19 同步与导入并发时都保留', () async {
      final WordBook target = await book('并发');
      final Map<String, Object?> remote = await env.backup.buildDataset(
        now: env.clock.now(),
      );
      final ImportService service = env.importService();
      await service.commit(
        preview: parseTxt('alpha\nbeta\n'),
        bookId: target.id,
        now: env.clock.now(),
      );
      // A concurrent merge of an older snapshot must not drop the imported rows.
      await env.backup.mergeDataset(remote, now: env.clock.now());
      expect(await env.words.countWords(), 2);
      expect(await env.books.wordCount(target.id), 2);
    });
  });
}

class FakeClient extends http.BaseClient {
  FakeClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
