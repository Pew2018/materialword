import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/services/diagnostics_service.dart';
import 'package:materialword/services/wordbook_export.dart';

import 'helpers/test_env.dart';

/// Phase 4F: the diagnostic report must stay machine-readable after truncation
/// without ever weakening credential protection, and the CSV export must not be
/// a spreadsheet formula carrier.
///
/// Every credential below is fabricated for the test; none is a real token.
void main() {
  late TestEnv env;
  late DiagnosticsService diagnostics;

  setUp(() async {
    env = await TestEnv.create();
    diagnostics = DiagnosticsService();
  });

  tearDown(() async {
    await env.dispose();
  });

  group('4F-02 diagnostics redaction', () {
    test('Bearer tokens, PATs and Basic auth are removed', () {
      final String safe = DiagnosticsService.redact(
        'Authorization: Bearer abcdefgh12345678\n'
        'X-Token: ghp_0123456789abcdefghijABCDEF\n'
        'pat: github_pat_11ABCDEFG0123456789_abcdefghijklmnop\n'
        'Authorization: Basic dXNlcjpwYXNzd29yZA==\n',
      );
      expect(safe, isNot(contains('abcdefgh12345678')));
      expect(safe, isNot(contains('ghp_0123456789abcdefghijABCDEF')));
      expect(safe, isNot(contains('github_pat_11ABCDEFG')));
      expect(safe, isNot(contains('dXNlcjpwYXNzd29yZA==')));
    });

    test('credentials embedded in a URL or its query string are removed', () {
      final String safe = DiagnosticsService.redact(
        'GET https://alice:s3cr3t-pass@example.com/dav/data.json\n'
        'GET https://example.com/dav/data.json?token=abc123secret&x=1\n',
      );
      expect(safe, isNot(contains('s3cr3t-pass')));
      expect(safe, contains('example.com'));
      expect(safe, isNot(contains('abc123secret')));
    });

    test('a quoted password with spaces is fully removed', () {
      final String safe = DiagnosticsService.redact(
        'connect failed password = "my secret pass phrase" retry',
      );
      expect(safe, isNot(contains('secret')));
      expect(safe, isNot(contains('pass phrase')));
      expect(safe, contains('retry'));
    });

    test('a multi-line exception message is redacted line by line', () {
      final String safe = DiagnosticsService.redact(
        'SocketException: failed\n'
        '  uri: https://bob:hunter2@example.com/x\n'
        '  headers: {authorization: Bearer zzzzzzzzzzzz9999}\n'
        '  token=plainTextToken123\n',
      );
      expect(safe, isNot(contains('hunter2')));
      expect(safe, isNot(contains('zzzzzzzzzzzz9999')));
      expect(safe, isNot(contains('plainTextToken123')));
      expect(safe, contains('SocketException'));
    });

    test('a legitimate build commit survives while arbitrary text does not', () async {
      // A real 40-character SHA looks exactly like the opaque strings the
      // redactor removes; the build metadata is the one trusted source.
      const String commit = '764efac557d25e7366f5d8e728e95072b979a36d';
      await diagnostics.setEnabled(env.db, true);
      diagnostics.log('app', 'started');
      final String report = await diagnostics.buildReport(
        env.db,
        runtime: <String, Object?>{
          'appVersion': '1.2.0',
          'buildCommit': commit,
        },
      );
      expect(report, contains(commit));
      expect(report, contains('1.2.0'));

      // The same string appearing in a trace is *not* trusted: it is redacted,
      // so preserving the build SHA never loosens the rule for anything else.
      final DiagnosticsService other = DiagnosticsService();
      await other.setEnabled(env.db, true);
      other.log('sync', 'object $commit requested');
      final String otherReport = await other.buildReport(env.db);
      expect(otherReport, isNot(contains(commit)));
    });

    test(
      'a truncated report is still valid JSON and keeps the build SHA',
      () async {
        const String commit = '24faea96feda8a6f19f722505731715a18920882';
        await diagnostics.setEnabled(env.db, true);
        // Long but not long enough to be treated as one opaque secret.
        final String noise = List<String>.generate(
          120,
          (int i) => 'w$i',
        ).join(' ');
        for (int i = 0; i < DiagnosticsService.maxEntries; i++) {
          diagnostics.log('noise', '$i $noise');
        }
        final String report = await diagnostics.buildReport(
          env.db,
          runtime: <String, Object?>{'buildCommit': commit},
        );

        expect(
          report.length,
          lessThanOrEqualTo(DiagnosticsService.maxReportChars),
        );
        final Object? decoded = jsonDecode(report);
        expect(decoded, isA<Map<String, Object?>>());
        final Map<String, Object?> map = decoded! as Map<String, Object?>;
        expect(map['truncated'], isTrue);
        expect(
          (map['runtime']! as Map<String, Object?>)['buildCommit'],
          commit,
        );
        expect(map['database'], isA<Map<String, Object?>>());
        // Truncation drops whole trace lines and says how many.
        expect(map['droppedTraceLines'], isA<int>());
        expect(map['droppedTraceLines'] as int, greaterThan(0));
      },
    );

    test(
      'a huge error message cannot push the report past the budget',
      () async {
        await diagnostics.setEnabled(env.db, true);
        final String huge = 'x' * 400000;
        diagnostics.log('crash', huge, error: true);
        final String report = await diagnostics.buildReport(
          env.db,
          runtime: <String, Object?>{'buildCommit': 'abc1234'},
        );
        expect(
          report.length,
          lessThanOrEqualTo(DiagnosticsService.maxReportChars),
        );
        expect(jsonDecode(report), isA<Map<String, Object?>>());
      },
    );

    test(
      'JSON special characters in a message stay encoded, not broken',
      () async {
        await diagnostics.setEnabled(env.db, true);
        diagnostics.log('parse', r'bad "json" {key: "va\"lue"} \ backslash');
        final String report = await diagnostics.buildReport(env.db);
        final Object? decoded = jsonDecode(report);
        expect(decoded, isA<Map<String, Object?>>());
        final List<Object?> traces =
            (decoded! as Map<String, Object?>)['traces']! as List<Object?>;
        expect(traces.last as String, contains('bad'));
      },
    );

    test('a malformed runtime value is redacted like any other text', () async {
      await diagnostics.setEnabled(env.db, true);
      final String report = await diagnostics.buildReport(
        env.db,
        runtime: <String, Object?>{
          // Not a commit, not a version: the key alone must not grant trust.
          'buildCommit': 'ghp_abcdefghijklmnopqrstuvwxyz0123',
          'note': 'https://user:pw@example.com/x',
        },
      );
      expect(report, isNot(contains('ghp_abcdefghijklmnopqrstuvwxyz0123')));
      expect(report, isNot(contains('pw@')));
      expect(jsonDecode(report), isA<Map<String, Object?>>());
    });
  });

  group('4F-01 persistent diagnostics', () {
    late Directory temp;
    late File file;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mw-diag-');
      file = File('${temp.path}/diagnostics.log');
    });

    tearDown(() async {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('a crash before the restart is still reportable', () async {
      diagnostics.attachFile(file);
      await diagnostics.setEnabled(env.db, true);
      diagnostics.log('sync', 'uploading 1200 events');
      diagnostics.log('sync', 'failed: 412 conflict', error: true);
      await diagnostics.flushToDisk();

      // "Restart": a new service over the same file and database.
      final DiagnosticsService reopened = DiagnosticsService()
        ..attachFile(file);
      expect(await reopened.load(env.db), isTrue);
      expect(
        reopened.entries.last.message,
        contains('412'),
        reason: 'trace lines written before the restart are restored',
      );
      final String report = await reopened.buildReport(env.db);
      expect(report, contains('412'));
      expect(jsonDecode(report), isA<Map<String, Object?>>());
    });

    test('logging stays off by default and writes nothing to disk', () async {
      diagnostics.attachFile(file);
      diagnostics.log('sync', 'uploading 1200 events');
      await diagnostics.flushToDisk();
      expect(await file.exists(), isFalse);
    });

    test('the file is rotated and never grows without bound', () async {
      diagnostics.attachFile(file);
      await diagnostics.setEnabled(env.db, true);
      final String noise = List<String>.generate(
        60,
        (int i) => 'x$i',
      ).join(' ');
      for (int round = 0; round < 150; round++) {
        for (int i = 0; i < DiagnosticsService.flushThreshold; i++) {
          diagnostics.log('bulk', '$round/$i $noise');
        }
        await diagnostics.flushToDisk();
      }
      final int size = await file.length();
      expect(size, lessThanOrEqualTo(DiagnosticsService.maxFileBytes));
      // One rotated generation is kept, so a burst does not erase history.
      expect(await File('${file.path}.1').exists(), isTrue);
      // The buffer itself never exceeds its documented bound either.
      expect(
        diagnostics.entries.length,
        lessThanOrEqualTo(DiagnosticsService.maxEntries),
      );
    });

    test('clearing removes the buffered lines and the file', () async {
      diagnostics.attachFile(file);
      await diagnostics.setEnabled(env.db, true);
      diagnostics.log('sync', 'something');
      await diagnostics.flushToDisk();
      expect(await file.exists(), isTrue);

      diagnostics.clear();
      await diagnostics.flushToDisk();
      expect(diagnostics.entries, isEmpty);
      expect(await file.exists(), isFalse);
      expect(await File('${file.path}.1').exists(), isFalse);
    });

    test('turning the switch off deletes what was written', () async {
      diagnostics.attachFile(file);
      await diagnostics.setEnabled(env.db, true);
      diagnostics.log('sync', 'something');
      await diagnostics.flushToDisk();
      await diagnostics.setEnabled(env.db, false);
      expect(await file.exists(), isFalse);
    });
  });

  group('4F-03 CSV export safety', () {
    Future<List<Word>> wordWith(Map<String, String> fields) async {
      final Word word = await env.words.ensureWord(
        text: fields['word'] ?? 'alpha',
        translation: fields['translation'] ?? '释义',
        example: fields['example'] ?? '',
        note: fields['note'] ?? '',
        phrase: fields['phrase'] ?? '',
        now: env.clock.now(),
      );
      return <Word>[word];
    }

    test('a formula cell is neutralised and stays readable', () async {
      final List<Word> words = await wordWith(<String, String>{
        'word': 'alpha',
        'translation': '=HYPERLINK("http://evil.example","click")',
        'note': '+cmd|calc',
        'example': '@SUM(A1:A2)',
        'phrase': '-2+3',
      });
      final String csv = WordBookExporter.encode(
        words,
        WordBookExportFormat.csv,
      );
      final List<String> lines = csv.split('\n');
      expect(lines.first, startsWith('word,'));
      // Each dangerous cell now begins with an apostrophe, inside its quotes.
      expect(lines[1], contains('"\'=HYPERLINK'));
      expect(lines[1], contains('+cmd|calc'.replaceFirst('+', "'+")));
      expect(lines[1], contains("'@SUM"));
      expect(lines[1], contains("'-2+3"));
    });

    test('ordinary words, quotes, commas and newlines are unchanged', () async {
      final List<Word> words = await wordWith(<String, String>{
        'word': 'take off',
        'translation': '起飞；脱下',
        'example': 'He said, "take off" today.',
        'note': 'first line\nsecond line',
      });
      final String csv = WordBookExporter.encode(
        words,
        WordBookExportFormat.csv,
      );
      expect(csv, contains('take off'));
      expect(csv, contains('"He said, ""take off"" today."'));
      expect(csv, contains('"first line\nsecond line"'));
      // No apostrophe guard on ordinary text.
      expect(csv, isNot(contains("'起飞")));
    });

    test('the guard is export-only and never reaches the database', () async {
      final List<Word> words = await wordWith(<String, String>{
        'word': 'alpha',
        'translation': '=1+1',
      });
      WordBookExporter.encode(words, WordBookExportFormat.csv);
      final Word stored = (await env.words.byId(words.single.id))!;
      expect(stored.translation, '=1+1');
    });

    test('TXT and JSON keep the raw semantics', () async {
      final List<Word> words = await wordWith(<String, String>{
        'word': 'alpha',
        'translation': '=1+1',
      });
      final String txt = WordBookExporter.encode(
        words,
        WordBookExportFormat.txt,
      );
      expect(txt.trim(), 'alpha');

      final String json = WordBookExporter.encode(
        words,
        WordBookExportFormat.json,
      );
      final List<Object?> decoded = jsonDecode(json) as List<Object?>;
      expect((decoded.single! as Map<String, Object?>)['translation'], '=1+1');
    });
  });
}
