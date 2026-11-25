import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/features/sync/sync_settings_page.dart';
import 'package:materialword/services/sync/credential_store.dart';

import 'helpers/test_env.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await settle(tester);
  }

  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('UI restores bool auto options and saves only selected flag', (
    tester,
  ) async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    final credentials = InMemoryCredentialStore();
    await credentials.write(CredentialKeys.githubToken, 'synthetic-test-token');
    await e.settings.setSyncConfig({
      'provider': 'github',
      'owner': 'test-user',
      'repo': 'data',
      'branch': 'main',
      'path': 'backup.json',
      'autoOnStart': true,
      'autoOnResume': true,
      'autoOnChange': true,
      'autoAfterSession': true,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(e.db),
          clockProvider.overrideWithValue(e.clock),
          credentialStoreProvider.overrideWithValue(credentials),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          home: const SyncSettingsPage(),
        ),
      ),
    );
    await settle(tester);
    final tile = find.widgetWithText(SwitchListTile, '更改后同步');
    await reveal(tester, tile);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    await tester.tap(tile.hitTestable());
    await settle(tester);
    final config = (await e.settings.syncConfig())!;
    expect(config['autoOnChange'], isFalse);
    expect(config['autoOnStart'], isTrue);
    expect(config['autoAfterSession'], isTrue);
    expect(config['path'], 'backup.json');
    expect(
      await credentials.read(CredentialKeys.githubToken),
      'synthetic-test-token',
    );
    expect(tester.takeException(), isNull);
    await clean(tester);
  });

  testWidgets('UI local-file automatic options stay disabled', (tester) async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    await e.settings.setSyncConfig({
      'provider': 'local-file',
      'path': '/tmp/synthetic-backup.json',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(e.db),
          clockProvider.overrideWithValue(e.clock),
          credentialStoreProvider.overrideWithValue(InMemoryCredentialStore()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          home: const SyncSettingsPage(),
        ),
      ),
    );
    await settle(tester);
    final tile = find.widgetWithText(SwitchListTile, '更改后同步');
    await reveal(tester, tile);
    expect(tester.widget<SwitchListTile>(tile).onChanged, isNull);
    expect(tester.takeException(), isNull);
    await clean(tester);
  });

  test('AUTO concurrent option edits preserve each other and reject changed connection', () async {
    final e = await TestEnv.create();
    addTearDown(e.dispose);
    final expected = <String, Object?>{
      'provider': 'github',
      'owner': 'user',
      'repo': 'data',
    };
    await e.settings.setSyncConfig(expected);
    final results = await Future.wait([
      e.settings.updateSyncAutoOption('autoOnChange', true, expected: expected),
      e.settings.updateSyncAutoOption(
        'autoAfterSession',
        true,
        expected: expected,
      ),
    ]);
    expect(results, everyElement(isTrue));
    expect((await e.settings.syncConfig())!['autoOnChange'], isTrue);
    expect((await e.settings.syncConfig())!['autoAfterSession'], isTrue);
    await e.settings.setSyncConfig({...expected, 'repo': 'other'});
    expect(
      await e.settings.updateSyncAutoOption(
        'autoOnChange',
        false,
        expected: expected,
      ),
      isFalse,
    );
    expect((await e.settings.syncConfig())!['repo'], 'other');
  });
}
