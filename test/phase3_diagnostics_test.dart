import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/services/diagnostics_service.dart';

import 'helpers/test_env.dart';

/// Diagnostics must be opt-in, bounded and incapable of leaking a credential or
/// personal learning content into an exported file.
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

  test('redaction removes tokens, passwords and credentials in URLs', () {
    const String raw = '''
GET https://user:sup3rs3cret@example.com/dav/data.json
Authorization: Basic dXNlcjpwYXNz
token=ghp_abcdefghijklmnopqrstuvwxyz0123
{"password":"hunter2","api_key":"abcdef123456"}
opaque 0123456789abcdef0123456789abcdef
''';
    final String safe = DiagnosticsService.redact(raw);
    expect(safe, isNot(contains('sup3rs3cret')));
    expect(safe, isNot(contains('dXNlcjpwYXNz')));
    expect(safe, isNot(contains('ghp_abcdefghijklmnopqrstuvwxyz0123')));
    expect(safe, isNot(contains('hunter2')));
    expect(safe, isNot(contains('abcdef123456')));
    expect(safe, isNot(contains('0123456789abcdef0123456789abcdef')));
    // The non-secret part of the URL survives, so the report stays useful.
    expect(safe, contains('example.com'));
  });

  test('logging is off by default and keeps only the last error', () {
    expect(diagnostics.enabled, isFalse);
    diagnostics.log('sync', 'uploading 1200 events');
    expect(diagnostics.entries, isEmpty);
    expect(diagnostics.lastError, isNull);

    diagnostics.log(
      'sync',
      'failed: 412 token=ghp_abcdefghijklmnopqrst',
      error: true,
    );
    expect(diagnostics.lastError, isNotNull);
    expect(diagnostics.lastError, isNot(contains('ghp_')));
    expect(diagnostics.entries, isEmpty);
  });

  test('the switch persists and bounds the buffer', () async {
    await diagnostics.setEnabled(env.db, true);
    expect(diagnostics.enabled, isTrue);

    // A second instance (a restart) sees the persisted value.
    final DiagnosticsService reopened = DiagnosticsService();
    expect(await reopened.load(env.db), isTrue);

    for (int i = 0; i < DiagnosticsService.maxEntries + 50; i++) {
      diagnostics.log('test', 'line $i');
    }
    expect(
      diagnostics.entries.length,
      lessThanOrEqualTo(DiagnosticsService.maxEntries),
    );
    expect(diagnostics.entries.last.message, 'line 449');

    await diagnostics.setEnabled(env.db, false);
    expect(diagnostics.entries, isEmpty);
    expect(await DiagnosticsService().load(env.db), isFalse);
  });

  test(
    'the report carries counts and versions but no learning content',
    () async {
      await env.seedBook(words: <String>['confidentialword', 'secondword']);
      await diagnostics.setEnabled(env.db, true);
      diagnostics.log('app', 'started');

      final String report = await diagnostics.buildReport(
        env.db,
        runtime: <String, Object?>{
          'appVersion': '1.2.0',
          'buildCommit': 'abc1234',
        },
      );
      expect(report, contains('"schemaVersion"'));
      expect(report, contains('"reviewEvents"'));
      expect(report, contains('abc1234'));
      expect(report, contains('started'));
      // Never the words themselves, and never a credentials field.
      expect(report.toLowerCase(), isNot(contains('confidentialword')));
      expect(report.toLowerCase(), isNot(contains('释义')));
      expect(report, isNot(contains('token":')));
    },
  );

  test('a report is truncated at the documented size', () async {
    await diagnostics.setEnabled(env.db, true);
    // Short tokens only: a long run of characters is itself redacted, which
    // would keep the report small and hide the truncation under test.
    final String noise = List<String>.generate(140, (int i) => 'w$i').join(' ');
    for (int i = 0; i < DiagnosticsService.maxEntries; i++) {
      diagnostics.log('noise', noise);
    }
    final String report = await diagnostics.buildReport(env.db);
    expect(
      report.length,
      lessThanOrEqualTo(DiagnosticsService.maxReportChars + 32),
    );
    expect(report, contains('truncated'));
  });
}
