import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:materialword/features/word_management/import_page.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/features/backup/cloud_backup_dialog.dart';
import 'package:materialword/features/wordbooks/library_page.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_coordinator.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_repository.dart';
import 'package:materialword/services/dictionary_packages.dart';
import 'package:materialword/services/dictionary_service.dart';

import 'helpers/test_env.dart';
import 'helpers/cloud_backup_history.dart';

final class ExamplePickedFile extends PlatformFile {
  ExamplePickedFile(this.file);
  final File file;
  @override
  String get name => file.uri.pathSegments.last;
  @override
  Uri get uri => file.uri;
  @override
  Never get xFile => throw UnimplementedError('Not used by this flow');
  @override
  int? lengthSync() => file.lengthSync();
  @override
  Future<int?> length() => file.length();
  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);
}

class ExampleFilePicker extends FilePickerPlatform {
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    expect(allowedExtensions, contains('zip'));
    final file = File('examples/learning-json.zip').absolute;
    return [ExamplePickedFile(file)];
  }
}

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final roboto = File(
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/Roboto-Regular.ttf',
    );
    final loader = FontLoader('Roboto')
      ..addFont(roboto.readAsBytes().then((b) => b.buffer.asByteData()));
    await loader.load();
    if (Platform.environment['CAPTURE_UI'] != '1') return;
    final cjk = FontLoader('EvidenceCJK')
      ..addFont(
        File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf')
            .readAsBytes()
            .then((b) => b.buffer.asByteData()),
      );
    await cjk.load();
  });
  ThemeData evidenceTheme(ThemeData theme) {
    ButtonStyle style(ButtonStyle? source) =>
        (source ?? const ButtonStyle()).copyWith(
          textStyle: WidgetStatePropertyAll(
            (source?.textStyle?.resolve({}) ?? theme.textTheme.labelLarge!)
                .copyWith(
                  fontFamily: 'Roboto',
                  fontFamilyFallback: ['EvidenceCJK'],
                ),
          ),
        );
    return theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamilyFallback: ['EvidenceCJK']),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamilyFallback: ['EvidenceCJK'],
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle:
            (theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge!)
                .copyWith(
                  fontFamily: 'Roboto',
                  fontFamilyFallback: ['EvidenceCJK'],
                ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: style(theme.textButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: style(theme.elevatedButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: style(theme.outlinedButtonTheme.style),
      ),
    );
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (Platform.environment['CAPTURE_UI'] != '1') return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('work/ui')..createSync(recursive: true);
      await File('${folder.path}/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  final cases = [
    (width: 320.0, dark: false, language: 'zh', scale: 1.6),
    (width: 360.0, dark: true, language: 'en', scale: 1.6),
    (width: 411.0, dark: false, language: 'en', scale: 1.0),
    (width: 720.0, dark: true, language: 'zh', scale: 1.0),
    (width: 1024.0, dark: false, language: 'en', scale: 1.6),
  ];
  for (final c in cases) {
    testWidgets(
      'library and exam preview ${c.width} ${c.language} ${c.scale}',
      (tester) async {
        tester.view.physicalSize = Size(c.width, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = c.dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final env = await TestEnv.create();
        final dictionary = DictionaryService.openFile(
          'assets/dictionary/ecdict_core.db',
        );
        final packages = DictionaryPackages(
          env.db,
          directory: () async => env.backupDirectory,
          client: MockClient((_) async => http.Response('', 503)),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(env.db),
              clockProvider.overrideWithValue(env.clock),
              dictionaryProvider.overrideWith((_) async => dictionary),
              dictionaryPackagesProvider.overrideWithValue(packages),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale(c.language),
              theme: evidenceTheme(
                AppTheme.light(accent: const Color(0xFFFFB300)),
              ),
              darkTheme: evidenceTheme(
                AppTheme.dark(accent: const Color(0xFF8E24AA)),
              ),
              themeMode: ThemeMode.system,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(c.scale)),
                child: RepaintBoundary(key: key, child: child!),
              ),
              home: const LibraryPage(),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'library-${c.width.toInt()}-${c.language}');
        await tester.scrollUntilVisible(
          find.text('IELTS'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('IELTS')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('IELTS'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          key,
          'exam-preview-${c.width.toInt()}-${c.language}',
        );
        if (c.width == 360) {
          final l = lookupAppLocalizations(Locale(c.language));
          await tester.tap(find.text(l.commonCancel));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text(l.installDictionary),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(find.text(l.installDictionary)),
            alignment: 0.7,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.installDictionary));
          for (var i = 0; i < 50; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(find.text(l.dictionaryOperationFailed), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(tester, key, 'dictionary-download-failure-360-en');
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        dictionary.close();
        packages.close();
        await env.dispose();
      },
    );
  }

  testWidgets(
    'learning ZIP preview and merge option at 360px English large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = ExampleFilePicker();
      addTearDown(() => FilePickerPlatform.instance = originalPicker);
      final env = await TestEnv.create();
      final key = GlobalKey();
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(env.db),
            clockProvider.overrideWithValue(env.clock),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: evidenceTheme(AppTheme.light()),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: RepaintBoundary(key: key, child: child!),
            ),
            home: const ImportPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.chooseFile));
      for (
        var i = 0;
        i < 100 && find.text(l.mergePackageProgress).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.scrollUntilVisible(
        find.text(l.mergePackageProgress),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text(l.mergePackageProgress)),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'learning-package-preview-360-en');
      await tester.tap(find.text(l.mergePackageProgress));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(await env.db.select(env.db.words).get(), isEmpty);
      await capture(tester, key, 'learning-package-merge-option-360-en');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await env.dispose();
    },
  );

  testWidgets('cleanup and single delete dialogs at 360px English large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final env = await TestEnv.create();
    final repo = CloudBackupRepository(env.settings, env.credentials);
    final config = await repo.save(
      const CloudBackupConfig(
        providerId: 's3',
        endpoint: 'https://example.test',
        directory: 'backup/',
        region: 'us-east-1',
        bucket: 'test-bucket',
        credentialEpoch: '',
      ),
      firstSecret: 'key',
      secondSecret: 'secret',
    );
    final history = TestBackupHistory(config, const [])..seed(4);
    history.files.updateAll((_, _) => []);
    // The real coordinator validates the retained files before the dialog opens.
    final content = (await tester.runAsync(
      () => env.backup.exportToJson(now: env.clock.now()),
    ))!;
    history.files.updateAll((_, _) => utf8.encode(content));
    final coordinator = CloudBackupCoordinator(
      repository: repo,
      backup: env.backup,
      clock: env.clock,
      factory: (_, _, _) => history,
    );
    Future<void> settleTestBackupHistory() async {
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
        if (!coordinator.isRunning &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    final key = GlobalKey();
    final l = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
          credentialStoreProvider.overrideWithValue(env.credentials),
          cloudBackupCoordinatorProvider.overrideWithValue(coordinator),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: evidenceTheme(AppTheme.dark()),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: RepaintBoundary(key: key, child: child!),
          ),
          home: const CloudBackupBrowser(providerId: 's3'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l.cloudBackupCleanup));
    for (
      var i = 0;
      i < 100 && find.byType(AlertDialog).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 25));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'cleanup-confirm-360-en');
    await tester.tap(find.text(l.commonCancel));
    await settleTestBackupHistory();
    await tester.tap(find.byTooltip(l.commonDelete).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'single-delete-confirm-360-en');
    await tester.tap(find.text(l.commonCancel));
    await settleTestBackupHistory();
    expect(history.files.length, 4);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    coordinator.dispose();
    await env.dispose();
  });
}
