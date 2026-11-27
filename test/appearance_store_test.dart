import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/appearance_store.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/database/app_database.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/l10n/language_store.dart';
import 'package:materialword/shared/widgets/common.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('外观快照文件', () {
    test('light + #009688 写入后再读回', () async {
      final Directory support = await _temp('mw_appearance_round');
      final Directory documents = await _temp('mw_docs_round');
      final AppearanceStore created = await DeviceAppearanceStore.load(
        supportDirectory: support,
        documentsDirectory: documents,
      );
      await created.write(
        theme: ThemePreference.light,
        accentColor: '#009688',
        typography: TypographyScale.material2014,
      );

      final AppearanceStore loaded = await DeviceAppearanceStore.load(
        supportDirectory: support,
        documentsDirectory: documents,
      );
      expect(loaded.current.trusted, isTrue);
      expect(loaded.current.theme, ThemePreference.light);
      expect(loaded.current.accentColor, '#009688');
      expect(loaded.current.typography, TypographyScale.material2014);
    });

    test('两行旧快照仍是 Material 2014', () async {
      final Directory support = await _temp('mw_appearance_legacy');
      final Directory documents = await _temp('mw_docs_legacy_type');
      File(
        '${support.path}${Platform.pathSeparator}'
        '${DeviceAppearanceStore.fileName}',
      ).writeAsStringSync('dark\n#009688\n');
      final AppearanceStore loaded = await DeviceAppearanceStore.load(
        supportDirectory: support,
        documentsDirectory: documents,
      );
      expect(loaded.current.trusted, isTrue);
      expect(loaded.current.theme, ThemePreference.dark);
      expect(loaded.current.accentColor, '#009688');
      expect(loaded.current.typography, TypographyScale.material2014);
    });

    test('第三行记下 Material 2018', () async {
      final Directory support = await _temp('mw_appearance_2018');
      final Directory documents = await _temp('mw_docs_2018');
      final AppearanceStore created = await DeviceAppearanceStore.load(
        supportDirectory: support,
        documentsDirectory: documents,
      );
      await created.write(
        theme: ThemePreference.light,
        accentColor: '#1565C0',
        typography: TypographyScale.material2018,
      );
      final AppearanceStore loaded = await DeviceAppearanceStore.load(
        supportDirectory: support,
        documentsDirectory: documents,
      );
      expect(loaded.current.typography, TypographyScale.material2018);
    });

    test('坏内容视为没有快照：旧安装不可信，新安装回退默认可信', () async {
      // Unreadable contents are not a snapshot. The same rule as a missing
      // file then applies: an existing learning database must not be painted
      // with the classic blue, and a machine with no database is a fresh
      // install (trusted system + #1565C0).
      final Directory upgradedSupport = await _temp('mw_appearance_bad_old');
      final Directory upgradedDocs = await _temp('mw_docs_bad_old');
      File(
        '${upgradedSupport.path}${Platform.pathSeparator}'
        '${DeviceAppearanceStore.fileName}',
      ).writeAsStringSync('light\nnot-a-color\n');
      File(
        '${upgradedDocs.path}${Platform.pathSeparator}'
        '${DeviceLanguageStore.legacyDatabaseName}',
      ).writeAsStringSync('legacy');

      final AppearanceStore upgraded = await DeviceAppearanceStore.load(
        supportDirectory: upgradedSupport,
        documentsDirectory: upgradedDocs,
      );
      expect(upgraded.current.trusted, isFalse);
      expect(upgraded.current.theme, ThemePreference.system);
      expect(upgraded.current.accentColor, hexOf(AppColors.defaultAccent));
      expect(
        File(
          '${upgradedSupport.path}${Platform.pathSeparator}'
          '${DeviceAppearanceStore.fileName}',
        ).readAsStringSync(),
        'light\nnot-a-color\n',
        reason: '不可信时不能把默认蓝写回去冒充用户的选择',
      );

      final Directory freshSupport = await _temp('mw_appearance_bad_new');
      final Directory freshDocs = await _temp('mw_docs_bad_new');
      File(
        '${freshSupport.path}${Platform.pathSeparator}'
        '${DeviceAppearanceStore.fileName}',
      ).writeAsStringSync('totally junk');
      final AppearanceStore fresh = await DeviceAppearanceStore.load(
        supportDirectory: freshSupport,
        documentsDirectory: freshDocs,
      );
      expect(fresh.current.trusted, isTrue);
      expect(fresh.current.theme, ThemePreference.system);
      expect(fresh.current.accentColor, hexOf(AppColors.defaultAccent));
    });

    test('没有快照且学习库已在：旧安装，第一帧不能当成默认蓝', () async {
      final Directory support = await _temp('mw_appearance_upgrade');
      final Directory documents = await _temp('mw_docs_upgrade');
      File(
        '${documents.path}${Platform.pathSeparator}'
        '${DeviceLanguageStore.legacyDatabaseName}',
      ).writeAsStringSync('legacy');

      final AppearanceStore store = await DeviceAppearanceStore.load(
        supportDirectory: support,
        documentsDirectory: documents,
      );
      expect(store.current.trusted, isFalse);
      expect(store.current.theme, ThemePreference.system);
      expect(store.current.accentColor, hexOf(AppColors.defaultAccent));
      expect(
        File(
          '${support.path}${Platform.pathSeparator}'
          '${DeviceAppearanceStore.fileName}',
        ).existsSync(),
        isFalse,
      );
    });

    test('没有快照也没有学习库：新安装记下默认可信快照', () async {
      final Directory support = await _temp('mw_appearance_fresh');
      final Directory documents = await _temp('mw_docs_fresh');
      final AppearanceStore first = await DeviceAppearanceStore.load(
        supportDirectory: support,
        documentsDirectory: documents,
      );
      expect(first.current.trusted, isTrue);
      expect(first.current.theme, ThemePreference.system);
      expect(first.current.accentColor, hexOf(AppColors.defaultAccent));

      final AppearanceStore second = await DeviceAppearanceStore.load(
        supportDirectory: support,
        documentsDirectory: documents,
      );
      expect(second.current.trusted, isTrue);
      expect(second.current.theme, ThemePreference.system);
      expect(second.current.accentColor, hexOf(AppColors.defaultAccent));
    });

    test('文件读失败退回内存默认，且不抛出', () async {
      final Directory support = await _temp('mw_appearance_unreadable');
      final Directory documents = await _temp('mw_docs_unreadable');
      final File snapshot = File(
        '${support.path}${Platform.pathSeparator}'
        '${DeviceAppearanceStore.fileName}',
      );
      snapshot.writeAsStringSync('light\n#009688\n');
      Process.runSync('chmod', <String>['000', snapshot.path]);
      addTearDown(
        () => Process.runSync('chmod', <String>['644', snapshot.path]),
      );

      final AppearanceStore store = await DeviceAppearanceStore.load(
        supportDirectory: support,
        documentsDirectory: documents,
      );
      expect(store, isA<MemoryAppearanceStore>());
      expect(store.current.trusted, isTrue);
      expect(store.current.theme, ThemePreference.system);
      expect(store.current.accentColor, hexOf(AppColors.defaultAccent));
    });

    test('目录不可写时 write 只留在内存里', () async {
      final Directory documents = await _temp('mw_docs_readonly');
      final Directory parent = await _temp('mw_appearance_readonly');
      final File blocker = File(
        '${parent.path}${Platform.pathSeparator}blocked',
      );
      blocker.writeAsStringSync('x');

      final AppearanceStore store = await DeviceAppearanceStore.load(
        supportDirectory: Directory(
          '${blocker.path}${Platform.pathSeparator}support',
        ),
        documentsDirectory: documents,
      );
      await store.write(
        theme: ThemePreference.dark,
        accentColor: '#009688',
        typography: TypographyScale.material2018,
      );
      expect(store.current.trusted, isTrue);
      expect(store.current.theme, ThemePreference.dark);
      expect(store.current.accentColor, '#009688');
      expect(store.current.typography, TypographyScale.material2018);
    });
  });

  group('启动第一帧', () {
    testWidgets('旧安装且快照不可信时不画默认蓝顶栏，设置到达后直接用真实颜色', (WidgetTester tester) async {
      final Color defaultLight = AppTheme.light().appBarTheme.backgroundColor!;
      final Color defaultDark = AppTheme.dark().appBarTheme.backgroundColor!;
      final Color expected = AppTheme.dark(accent: parseAccent('#DA6945'))
          .appBarTheme
          .backgroundColor!;
      expect(expected, isNot(defaultLight));
      expect(expected, isNot(defaultDark));

      final StreamController<StudySettingsRow> settings =
          StreamController<StudySettingsRow>.broadcast();
      final List<Color?> seen = <Color?>[];
      final TestEnv env = await _pump(
        tester,
        appearance: MemoryAppearanceStore(
          AppearanceSnapshot.defaults(trusted: false),
        ),
        settings: settings,
      );
      await tester.pump();
      seen.add(_appBarColor(tester));
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(ClassicAppBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.lightBackground,
      );

      await tester.pump(const Duration(milliseconds: 400));
      seen.add(_appBarColor(tester));
      expect(find.byType(AppBar), findsNothing);

      settings.add(_settings(themeMode: 'dark', accentColor: '#DA6945'));
      await tester.pump();
      seen.add(_appBarColor(tester));
      await tester.pump();
      seen.add(_appBarColor(tester));

      expect(seen.whereType<Color>(), isNot(contains(defaultLight)));
      expect(seen.whereType<Color>(), isNot(contains(defaultDark)));
      expect(_appBarColor(tester), expected);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await _finish(tester, env, settings: settings);
    });

    testWidgets('已有可信快照时，loading 的顶栏已是该色，相同设置到达后不变', (
      WidgetTester tester,
    ) async {
      final Color expected = AppTheme.light(accent: parseAccent('#65C400'))
          .appBarTheme
          .backgroundColor!;
      expect(expected, isNot(AppTheme.light().appBarTheme.backgroundColor));

      final StreamController<StudySettingsRow> settings =
          StreamController<StudySettingsRow>.broadcast();
      final TestEnv env = await _pump(
        tester,
        appearance: MemoryAppearanceStore(
          const AppearanceSnapshot(
            theme: ThemePreference.light,
            accentColor: '#65C400',
            trusted: true,
          ),
        ),
        settings: settings,
      );
      await tester.pump();
      expect(_appBarColor(tester), expected);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );

      settings.add(_settings(themeMode: 'light', accentColor: '#65C400'));
      await tester.pump();
      expect(_appBarColor(tester), expected);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_appBarColor(tester), expected);
      await _finish(tester, env, settings: settings);
    });

    testWidgets('新安装默认：loading 就是 system + #1565C0，默认行到达后仍是该色', (
      WidgetTester tester,
    ) async {
      final Color expected = AppTheme.light().appBarTheme.backgroundColor!;
      final StreamController<StudySettingsRow> settings =
          StreamController<StudySettingsRow>.broadcast();
      final TestEnv env = await _pump(
        tester,
        appearance: MemoryAppearanceStore(),
        settings: settings,
      );
      await tester.pump();
      final MaterialApp loading = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(loading.themeMode, ThemeMode.system);
      expect(loading.theme!.colorScheme.primary, AppColors.defaultAccent);
      expect(_appBarColor(tester), expected);

      settings.add(_settings());
      await tester.pump();
      final MaterialApp ready = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(ready.themeMode, ThemeMode.system);
      expect(ready.theme!.colorScheme.primary, AppColors.defaultAccent);
      expect(_appBarColor(tester), expected);
      await _finish(tester, env, settings: settings);
    });
  });

  testWidgets('设置里改明暗或强调色后，内存快照的当前值跟着变', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final TestEnv env = await TestEnv.create();
    final MemoryAppearanceStore store = MemoryAppearanceStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
          appearanceStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialWordApp(),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey<String>('nav-settings')));
    await _settle(tester);
    await tester.ensureVisible(find.text('深色'));
    await tester.tap(find.text('深色'));
    await _settle(tester);
    expect(store.current.theme, ThemePreference.dark);
    expect(store.current.accentColor, hexOf(AppColors.defaultAccent));
    expect(store.current.trusted, isTrue);

    await tester.ensureVisible(find.byTooltip('青绿'));
    await tester.tap(find.byTooltip('青绿'));
    await _settle(tester);
    expect(store.current.theme, ThemePreference.dark);
    expect(store.current.accentColor, '#009688');
    expect(store.current.trusted, isTrue);
    expect(tester.takeException(), isNull);
    await _finish(tester, env);
  });
}

Future<Directory> _temp(String prefix) async {
  final Directory directory = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

StudySettingsRow _settings({
  String themeMode = 'system',
  String accentColor = '#1565C0',
  String typographyScale = 'material2014',
}) {
  return StudySettingsRow(
    id: 1,
    dailyNewTarget: 30,
    dailyReviewLimit: 100,
    studyMode: 'mixed',
    themeMode: themeMode,
    accentColor: accentColor,
    typographyScale: typographyScale,
    ttsVoice: '',
    ttsLocale: 'en-US',
    ttsRate: 50,
    ttsAutoSpeak: false,
  );
}

Future<TestEnv> _pump(
  WidgetTester tester, {
  required AppearanceStore appearance,
  required StreamController<StudySettingsRow> settings,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final TestEnv env = await TestEnv.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(env.db),
        clockProvider.overrideWithValue(env.clock),
        appearanceStoreProvider.overrideWithValue(appearance),
        settingsProvider.overrideWith((Ref ref) => settings.stream),
      ],
      child: const MaterialWordApp(),
    ),
  );
  return env;
}

/// Lets AppShell's startup query finish, then closes the database while the
/// test can still flush the zero-duration timers Drift schedules on cancel.
Future<void> _finish(
  WidgetTester tester,
  TestEnv env, {
  StreamController<StudySettingsRow>? settings,
}) async {
  await tester.pump(const Duration(milliseconds: 300));
  await env.dispose();
  await settings?.close();
  await tester.pump();
}

Color? _appBarColor(WidgetTester tester) {
  final Finder bars = find.byType(AppBar);
  if (bars.evaluate().isEmpty) return null;
  return Theme.of(tester.element(bars.first)).appBarTheme.backgroundColor;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}
