import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/navigation.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/time_utils.dart';
import 'package:materialword/features/backup/cloud_backup_dialog.dart';
import 'package:materialword/features/backup/cloud_backup_settings.dart';
import 'package:materialword/l10n/backup_labels.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_repository.dart';
import 'package:materialword/shared/widgets/classic_select.dart';

import 'helpers/l10n_fixture.dart';
import 'helpers/test_env.dart';

/// Phase 6.5D-G — the manual cloud-backup surfaces: one classic selector, two
/// primary buttons, a readable local timestamp, and no pill-shaped fill.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<TestEnv> envWith({bool webdav = true, bool s3 = false}) async {
    final TestEnv env = await TestEnv.create();
    final CloudBackupRepository repo = CloudBackupRepository(
      env.settings,
      env.credentials,
    );
    if (s3) {
      await repo.save(
        const CloudBackupConfig(
          providerId: 's3',
          endpoint: 'https://s3.example.com',
          directory: 'materialword-backups/',
          region: 'us-east-1',
          bucket: 'mw-bucket',
          credentialEpoch: '',
        ),
        firstSecret: 'access-key',
        secondSecret: 'secret-key',
      );
    }
    if (webdav) {
      await repo.save(
        const CloudBackupConfig(
          providerId: 'webdav',
          endpoint: 'https://dav.example.com/dav/',
          directory: 'materialword-backups',
          credentialEpoch: '',
        ),
        firstSecret: 'user',
        secondSecret: 'app-password',
      );
    }
    return env;
  }

  Widget app(TestEnv env, Widget home) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(env.db),
      clockProvider.overrideWithValue(env.clock),
      credentialStoreProvider.overrideWithValue(env.credentials),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      theme: AppTheme.light(),
      home: home,
    ),
  );

  Future<void> openDialog(WidgetTester tester, TestEnv env) async {
    await tester.pumpWidget(
      app(
        env,
        Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const CloudBackupDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  testWidgets(
    'T20/T41/T44/T45 the dialog uses a classic select and two classic buttons',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final TestEnv env = await envWith();
      await openDialog(tester, env);

      // One classic field + menu, replacing the covering DropdownButtonFormField.
      expect(find.byType(ClassicSelect<String>), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      // One label only: the field carries the floating label itself.
      expect(find.text(zhText.cloudBackupTarget), findsOneWidget);
      // The target is named by provider, not by a raw endpoint.
      expect(find.textContaining('WebDAV · dav.example.com'), findsOneWidget);

      // Download is the outlined alternative, upload the solid primary action.
      expect(
        find.widgetWithText(OutlinedButton, zhText.cloudBackupDownload),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, zhText.cloudBackupUpload),
        findsOneWidget,
      );
      // Nothing here is a Material 3 pill, and nothing is a `FilledButton`.
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
      await clean(tester);
      await env.dispose();
    },
  );

  testWidgets('T41/T42/T43 the dialog fits 360dp and a large font', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final TestEnv env = await envWith();
    await openDialog(tester, env);

    expect(find.byType(CloudBackupDialog), findsOneWidget);
    // No RenderFlex overflow, no clipped button label.
    expect(tester.takeException(), isNull);
    final Rect dialog = tester.getRect(find.byType(AlertDialog));
    expect(dialog.left, greaterThanOrEqualTo(0));
    expect(dialog.right, lessThanOrEqualTo(360));
    final Iterable<Widget> buttons = tester.widgetList<Widget>(
      find.byWidgetPredicate(
        (Widget w) => w is ElevatedButton || w is OutlinedButton,
      ),
    );
    expect(buttons, isNotEmpty);
    for (final Widget button in buttons) {
      final Rect rect = tester.getRect(find.byWidget(button));
      expect(rect.width, greaterThan(0));
      expect(rect.left, greaterThanOrEqualTo(dialog.left));
      expect(rect.right, lessThanOrEqualTo(dialog.right));
      expect(rect.height, greaterThanOrEqualTo(40));
    }
    await clean(tester);
    await env.dispose();
  });

  testWidgets('T46 an unconfigured install offers only the configuration', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final TestEnv env = await envWith(webdav: false);
    await openDialog(tester, env);

    expect(find.text(zhText.cloudBackupNotConfigured), findsOneWidget);
    expect(find.byType(ClassicSelect<String>), findsNothing);
    expect(
      find.widgetWithText(ElevatedButton, zhText.cloudBackupUpload),
      findsNothing,
    );
    expect(
      find.widgetWithText(OutlinedButton, zhText.cloudBackupDownload),
      findsNothing,
    );
    // Configuration is a real button, not a text link buried in the corner.
    expect(
      find.widgetWithText(ElevatedButton, zhText.cloudBackupConfigure),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await clean(tester);
    await env.dispose();
  });

  test('T57/T58 a stored UTC timestamp is shown in local time, safely', () {
    const String raw = '2026-11-26T03:28:20.779827Z';
    final String shown = cloudBackupTime(zhText, raw);
    expect(shown, formatDateTime(DateTime.parse(raw)));
    // No machine format reaches the user: no `T`, no `Z`, no microseconds.
    expect(shown, isNot(contains('T')));
    expect(shown, isNot(contains('Z')));
    expect(shown, isNot(contains('.')));
    expect(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$').hasMatch(shown), isTrue);

    // Broken or missing values say so instead of rendering 1970.
    expect(
      cloudBackupTime(zhText, 'not-a-date'),
      zhText.cloudBackupUnknownTime,
    );
    expect(cloudBackupTime(zhText, null), zhText.cloudBackupUnknownTime);
    expect(cloudBackupTime(zhText, 17), zhText.cloudBackupUnknownTime);
  });

  test('T59 the size column stays readable', () {
    expect(cloudBackupFileSize(zhText, 512), '512 B');
    expect(cloudBackupFileSize(zhText, 4096), '4.0 KB');
    expect(cloudBackupFileSize(zhText, 262144), '256 KB');
    expect(cloudBackupFileSize(zhText, 1468006), '1.4 MB');
    expect(cloudBackupFileSize(zhText, null), zhText.cloudBackupSizeUnknown);
  });

  testWidgets(
    'T21/T52 the S3 page groups its fields and selects the addressing '
    'style classically',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final TestEnv env = await envWith(webdav: false, s3: true);
      await tester.pumpWidget(
        app(env, const CloudBackupConfigPage(providerId: 's3')),
      );
      await settle(tester);

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.byType(ClassicSelect<String>), findsOneWidget);
      expect(find.text(zhText.cloudBackupAddressing), findsOneWidget);
      await tester.tap(find.byType(ClassicSelect<String>));
      await settle(tester);
      expect(find.text(zhText.cloudBackupAddressingAuto), findsWidgets);
      expect(find.text(zhText.cloudBackupAddressingPath), findsOneWidget);
      expect(find.text(zhText.cloudBackupAddressingVirtual), findsOneWidget);
      await tester.tap(find.text(zhText.cloudBackupAddressingVirtual));
      await settle(tester);

      // Save is the solid primary action, test the outlined alternative.
      expect(
        find.widgetWithText(ElevatedButton, zhText.commonSave),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, zhText.cloudBackupTest),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);

      // The danger zone is its own section and explains what it keeps.
      final Finder hint = find.text(zhText.cloudBackupDeleteHint);
      await tester.scrollUntilVisible(
        hint,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      expect(hint, findsOneWidget);
      expect(tester.takeException(), isNull);
      await clean(tester);
      await env.dispose();
    },
  );

  testWidgets('T53/T54 saved credentials are announced, never displayed', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final TestEnv env = await envWith();
    await tester.pumpWidget(
      app(env, const CloudBackupConfigPage(providerId: 'webdav')),
    );
    await settle(tester);

    expect(find.text(zhText.cloudBackupCredentialsSaved), findsWidgets);
    // The masked hint is a hint: it is never written into the controller, and
    // the stored pair never comes back into a field.
    final Iterable<EditableText> fields = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    for (final EditableText field in fields) {
      expect(field.controller.text, isNot(contains('•')));
      expect(field.controller.text, isNot('app-password'));
      expect(field.controller.text, isNot('user'));
    }
    // Saving with both credential fields empty keeps the stored pair untouched.
    await tester.tap(find.widgetWithText(ElevatedButton, zhText.commonSave));
    await settle(tester);
    final CloudBackupRepository repo = CloudBackupRepository(
      env.settings,
      env.credentials,
    );
    final CloudBackupConfig? stored = await repo.load('webdav');
    expect(await repo.readSecrets(stored!), ('user', 'app-password'));
    await clean(tester);
    await env.dispose();
  });

  testWidgets('the provider list summarises a saved target', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final TestEnv env = await envWith();
    await tester.pumpWidget(
      app(env, const Scaffold(body: CloudBackupSettingsSection())),
    );
    await settle(tester);
    expect(find.text(zhText.cloudBackupTitle), findsOneWidget);
    expect(find.textContaining(zhText.cloudBackupConfigured), findsOneWidget);
    expect(find.textContaining(zhText.cloudBackupNever), findsOneWidget);
    expect(tester.takeException(), isNull);
    await clean(tester);
    await env.dispose();
  });

  testWidgets('T40 every destination keeps its manual backup action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final TestEnv env = await TestEnv.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
        ],
        child: const MaterialWordApp(),
      ),
    );
    for (final AppDestination destination in appDestinations) {
      await tester.tap(find.byKey(ValueKey('nav-${destination.id}')));
      await tester.pump(const Duration(milliseconds: 120));
      final IconButton action = tester.widget<IconButton>(
        find.byKey(const ValueKey('manual-cloud-backup')),
      );
      expect((action.icon as Icon).color, Colors.white);
      expect(find.byKey(const ValueKey('manual-cloud-backup')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('manual-cloud-backup')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(CloudBackupDialog), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text(zhText.cloudBackupNotConfigured), findsOneWidget);
    await tester.tap(find.text(zhText.commonClose));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await env.dispose();
  });
}
