import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/core/errors/app_error.dart';
import 'package:materialword/core/models/enums.dart';
import 'package:materialword/l10n/enum_labels.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/l10n/language_store.dart';
import 'package:materialword/services/word_intake_service.dart';
import 'package:materialword/services/tts_service.dart';

import 'helpers/test_env.dart';

/// Phase 6.3 — localisation, language switching and the accent palette.
///
/// These tests are deliberately about *contracts*: the two ARB files describe the
/// same message set, the language switch changes only `MaterialApp.locale`, the
/// accent palette is exactly the specified list, and no business rule compares
/// translated text.
class _SilentTts extends TtsService {
  @override
  Future<List<TtsVoice>> englishVoices({bool refresh = false}) async =>
      const <TtsVoice>[];

  @override
  Future<bool> speak(
    String text, {
    String? voiceName,
    String? locale,
    int rate = 50,
  }) async => true;

  @override
  Future<void> stop() async {}
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Map<String, Object?> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, Object?>;

Iterable<String> _keys(Map<String, Object?> arb) =>
    arb.keys.where((String key) => !key.startsWith('@'));

/// Every Dart file under `lib/`, excluding generated localisations.
List<File> _libSources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .where((File file) => !file.path.contains('l10n/generated'))
        .toList();

Finder _pageScrollable() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  double delta = 200,
}) async {
  // Already on screen: do not call scrollUntilVisible. Its final
  // ensureVisible aligns the target to the top of the scroll view, which
  // drops earlier rows once the page can scroll further than the viewport.
  if (target.evaluate().isNotEmpty) {
    final Rect rect = tester.getRect(target);
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final bool onScreen =
        rect.top >= 0 &&
        rect.bottom <= screen.height &&
        rect.left >= 0 &&
        rect.right <= screen.width;
    if (onScreen) return;
  }
  await tester.scrollUntilVisible(target, delta, scrollable: _pageScrollable());
  await _settle(tester);
}

Future<TestEnv> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(900, 1200),
  AppLanguage language = AppLanguage.zh,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final TestEnv env = await TestEnv.create();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await env.dispose();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(env.db),
        clockProvider.overrideWithValue(env.clock),
        ttsServiceProvider.overrideWithValue(_SilentTts()),
        languageStoreProvider.overrideWithValue(MemoryLanguageStore(language)),
      ],
      child: const MaterialWordApp(),
    ),
  );
  await _settle(tester);
  return env;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('L10N 国际化基础', () {
    test('L10N01/L10N02 中英文资源键集合一致', () {
      final Map<String, Object?> en = _arb('app_en.arb');
      final Map<String, Object?> zh = _arb('app_zh.arb');
      final Set<String> enKeys = _keys(en).toSet();
      final Set<String> zhKeys = _keys(zh).toSet();
      expect(enKeys.length, greaterThan(500));
      expect(zhKeys.difference(enKeys), isEmpty, reason: '中文多出的键');
      expect(enKeys.difference(zhKeys), isEmpty, reason: '英文多出的键');
      for (final String key in enKeys) {
        expect((en[key] as String).trim(), isNotEmpty, reason: 'en.$key');
        expect((zh[key] as String).trim(), isNotEmpty, reason: 'zh.$key');
      }
    });

    test('L10N03 占位符在两个语言中一致', () {
      final Map<String, Object?> en = _arb('app_en.arb');
      final Map<String, Object?> zh = _arb('app_zh.arb');
      final RegExp placeholder = RegExp(r'\{(\w+)[,}]');
      for (final String key in _keys(en)) {
        final Set<String> enNames = placeholder
            .allMatches(en[key] as String)
            .map((RegExpMatch m) => m.group(1)!)
            .toSet();
        final Set<String> zhNames = placeholder
            .allMatches(zh[key] as String)
            .map((RegExpMatch m) => m.group(1)!)
            .toSet();
        expect(zhNames, enNames, reason: '占位符不一致: $key');
        if (enNames.isNotEmpty) {
          final Map<String, Object?>? meta =
              en['@$key'] as Map<String, Object?>?;
          final Map<String, Object?> declared =
              (meta?['placeholders'] as Map<String, Object?>?) ??
              const <String, Object?>{};
          expect(declared.keys.toSet(), enNames, reason: '@$key 未声明全部占位符');
        }
      }
    });

    test('L10N04 生成的资源可在两种语言下加载', () async {
      final AppLocalizations zh = await AppLocalizations.delegate.load(
        const Locale('zh'),
      );
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(zh.navToday, '今日');
      expect(en.navToday, 'Today');
      expect(zh.startStudying, '开始学习');
      expect(en.startStudying, 'Start Studying');
    });

    test('L10N05 动态数量区分单复数', () async {
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      final AppLocalizations zh = await AppLocalizations.delegate.load(
        const Locale('zh'),
      );
      expect(en.wordCountPlural(1), '1 word');
      expect(en.wordCountPlural(2), '2 words');
      expect(zh.wordCountPlural(2), contains('2'));
      // Zero is its own case, not "1 word" with a zero in front.
      expect(en.wordCountPlural(0), isNot(contains('1 word')));
    });

    test('L10N08 枚举持久化值不受语言影响', () {
      expect(AnswerResult.known.code, 2);
      expect(AnswerResult.hazy.code, 1);
      expect(AnswerResult.unknown.code, 0);
      expect(StudyStage.newWord.code, 0);
      expect(StudyStage.relearning.code, 3);
      expect(StudyMode.mixed.code, 'mixed');
      expect(SpecialReview.sessionMistakes.code, 'session-mistakes');
      expect(PracticeKind.cloze.code, 'cloze');
      expect(ThemePreference.system.code, 'system');
      expect(ManagedSort.lastStudiedDesc.code, 'last');
      expect(ManagedStageFilter.mastered.code, 'mastered');
    });

    test('L10N09/L10N10 业务状态不依赖本地化文案', () {
      // No source file may branch on a translated sentence.
      final RegExp localisedContains = RegExp(
        r'''\.contains\(\s*(context\.l10n|[A-Za-z_]+l10n)\.''',
      );
      final RegExp chineseContains = RegExp(
        r'''\.contains\(\s*'[^']*[\u4e00-\u9fff]''',
      );
      final List<String> offenders = <String>[];
      for (final File file in _libSources()) {
        final String source = file.readAsStringSync();
        if (localisedContains.hasMatch(source) ||
            chineseContains.hasMatch(source)) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty, reason: '这些文件用文案判断业务状态: $offenders');

      // The code path the old implementation used is now a typed value.
      const WordIntakeException error = WordIntakeException(
        AppErrorCode.wordListDeleted,
      );
      expect(error.code, AppErrorCode.wordListDeleted);
    });

    test('L10N12 必填文案没有遗漏（关键页面）', () async {
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      final Map<String, String> samples = <String, String>{
        'navToday': en.navToday,
        'navWordLists': en.navWordLists,
        'startStudying': en.startStudying,
        'reviewOnly': en.reviewOnly,
        'settingsAppearance': en.settingsAppearance,
        'appLanguage': en.appLanguage,
        'syncTitle': en.syncTitle,
        'syncNow': en.syncNow,
        'backupRestore': en.backupRestore,
        'diagnostics': en.diagnostics,
        'importWordList': en.importWordList,
        'deleteWordListTitle': en.deleteWordListTitle,
        'restoreVersionTitle': en.restoreVersionTitle,
      };
      samples.forEach((String key, String value) {
        expect(value.trim(), isNotEmpty, reason: key);
      });
    });
  });

  group('LANG 语言设置', () {
    testWidgets('LANG01-03 入口位于外观分组、强调色之后', (tester) async {
      await _pumpApp(tester, size: const Size(920, 1400));
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('zh'),
      );

      await tester.tap(find.text(l10n.navSettings).last);
      await _settle(tester);

      await _reveal(tester, find.text(l10n.appLanguage));
      expect(find.text(l10n.appLanguage), findsOneWidget);
      expect(find.text(l10n.settingsAppearance), findsWidgets);
      expect(find.text(l10n.accentColor), findsOneWidget);

      final double accentY = tester.getTopLeft(find.text(l10n.accentColor)).dy;
      final double languageY = tester
          .getTopLeft(find.text(l10n.appLanguage))
          .dy;
      expect(languageY, greaterThan(accentY), reason: '语言入口必须在强调色区域下方');

      await _reveal(tester, find.text(l10n.typographyMaterial2018));
      expect(find.text(l10n.typographyMaterial2014), findsOneWidget);
      expect(find.text(l10n.typographyMaterial2018), findsOneWidget);
    });

    testWidgets('LANG05/LANG06/LANG11 切换语言即时生效且不丢路由', (tester) async {
      await _pumpApp(tester, size: const Size(920, 1400));
      final AppLocalizations zh = await AppLocalizations.delegate.load(
        const Locale('zh'),
      );
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );

      await tester.tap(find.text(zh.navSettings).last);
      await _settle(tester);
      await _reveal(tester, find.text(zh.appLanguage));
      await tester.tap(find.text(zh.appLanguage));
      await _settle(tester);

      // The dialog lists every language in its own script.
      expect(find.text(zh.appLanguageEnglish), findsOneWidget);
      await tester.tap(find.text(zh.appLanguageEnglish));
      await _settle(tester);

      // Still on Settings, now in English.
      expect(find.text(en.settingsAppearance), findsWidgets);
      expect(find.text(en.appLanguage), findsOneWidget);
      expect(find.text(zh.settingsAppearance), findsNothing);

      // And back again.
      await tester.tap(find.text(en.appLanguage));
      await _settle(tester);
      await tester.tap(find.text(zh.appLanguageChinese).last);
      await _settle(tester);
      expect(find.text(zh.settingsAppearance), findsWidgets);
    });

    testWidgets('LANG07/LANG08 跟随系统时由 Flutter 解析平台语言', (tester) async {
      expect(AppLanguage.system.locale, isNull);
      expect(AppLanguage.zh.locale, const Locale('zh'));
      expect(AppLanguage.en.locale, const Locale('en'));

      // Unsupported and Traditional Chinese system languages resolve to a
      // supported one instead of an empty localisation.
      final List<Locale> supported = AppLocalizations.supportedLocales;
      expect(
        basicLocaleListResolution(const <Locale>[
          Locale('zh', 'TW'),
        ], supported).languageCode,
        'zh',
      );
      expect(
        basicLocaleListResolution(const <Locale>[
          Locale('fr'),
        ], supported).languageCode,
        'en',
      );

      await _pumpApp(tester, language: AppLanguage.system);
      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.locale, isNull, reason: '跟随系统时不要写死 locale');
    });

    testWidgets('LANG09/LANG13 语言持久化在设备上且与学习数据无关', (tester) async {
      final MemoryLanguageStore store = MemoryLanguageStore(AppLanguage.zh);
      expect(store.current, AppLanguage.zh);
      await store.write(AppLanguage.en);
      expect(store.current, AppLanguage.en);

      // The store writes a language code, never a translated name.
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode('EN'), AppLanguage.en);
      expect(AppLanguage.fromCode('de'), AppLanguage.system);
      expect(AppLanguage.fromCode(null), AppLanguage.system);

      // Localisation keys never carry user content.
      final Map<String, Object?> en = _arb('app_en.arb');
      expect(_keys(en).where((String k) => k.contains('wordText')), isEmpty);
    });

    test('LANG14/LANG15 界面语言不翻译学习内容', () {
      // Word content lives in the database, not in the ARB files: no message
      // may be a lookup key for a word's text.
      final Map<String, Object?> en = _arb('app_en.arb');
      for (final String key in _keys(en)) {
        expect(
          key.startsWith('wordContent'),
          isFalse,
          reason: '学习内容不得进入本地化资源: $key',
        );
      }
    });
  });

  group('THEME 强调色', () {
    test('THEME01-05 预设数量、顺序与 HEX 精确匹配', () {
      expect(classicAccentPalettes, hasLength(11));
      expect(materialAccentPalettes, hasLength(12));
      expect(accentPalettes, hasLength(23));
      expect(accentPalettes.map((AccentPalette p) => p.hex).toList(), <String>[
        '#00A8FC',
        '#0073D4',
        '#DA6945',
        '#F2A227',
        '#65C400',
        '#009C8C',
        '#9B73D3',
        '#3F3DA8',
        '#00CADD',
        '#FF5592',
        '#C763CE',
        '#2196F3',
        '#009688',
        '#4CAF50',
        '#F44336',
        '#FF9800',
        '#9C27B0',
        '#00BCD4',
        '#3F51B5',
        '#E91E63',
        '#607D8B',
        '#FF5722',
        '#8BC34A',
      ]);
      expect(
        accentPalettes.map((AccentPalette p) => p.id).toSet(),
        hasLength(23),
        reason: 'ID 必须唯一',
      );
    });

    test('THEME06/THEME07 颜色名称两个语言都有', () async {
      final AppLocalizations zh = await AppLocalizations.delegate.load(
        const Locale('zh'),
      );
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(
        accentPalettes.map((AccentPalette p) => p.label(zh)).toList(),
        <String>[
          '晴空蓝',
          '深海蓝',
          '流金橙',
          '柠檬黄',
          '青草绿',
          '碧玉绿',
          '魅力紫',
          '靛青蓝',
          '天空蓝',
          '活力红',
          '时尚粉',
          '蓝',
          '青绿',
          '绿',
          '红',
          '橙',
          '紫',
          '青',
          '靛蓝',
          '粉',
          '蓝灰',
          '深橙',
          '浅绿',
        ],
      );
      expect(accentPalettes.first.label(en), 'Clear Sky Blue');
      expect(accentPalettes.last.label(en), 'Light Green');
    });

    test('THEME10/THEME11 默认色、自定义色与旧 ID 都保留', () {
      expect(parseAccent(null), AppColors.defaultAccent);
      expect(parseAccent('#2E7D32'), const Color(0xFF2E7D32));
      expect(parseAccent('2E7D32'), const Color(0xFF2E7D32));
      // Ids stored by 1.2.0 still resolve to the colour the user picked.
      expect(parseAccent('teal'), const Color(0xFF00796B));
      expect(parseAccent('blue'), const Color(0xFF1565C0));
      // New ids resolve too, without being the legacy values.
      expect(parseAccent('material.blue'), const Color(0xFF2196F3));
      expect(parseAccent('classic.clearSkyBlue'), const Color(0xFF00A8FC));
    });

    test('THEME12/THEME13 每个预设都能构建浅色与深色主题', () {
      for (final AccentPalette palette in accentPalettes) {
        for (final Brightness brightness in Brightness.values) {
          final ThemeData theme = AppTheme.of(brightness, palette.color);
          expect(theme.colorScheme.primary, isNotNull);
          expect(theme.appBarTheme.backgroundColor, isNotNull);
        }
      }
    });

    test('Classic filled components keep white foregrounds in both themes', () {
      double whiteContrast(Color background) =>
          1.05 / (background.computeLuminance() + 0.05);

      for (final accent in [
        ...accentPalettes.map((palette) => palette.color),
        Colors.white,
      ]) {
        for (final brightness in Brightness.values) {
          final theme = AppTheme.of(brightness, accent);
          final bar = theme.appBarTheme;
          final button = theme.elevatedButtonTheme.style!;
          final fab = theme.floatingActionButtonTheme;
          expect(bar.foregroundColor, Colors.white);
          expect(bar.titleTextStyle!.color, Colors.white);
          expect(bar.iconTheme!.color, Colors.white);
          expect(bar.actionsIconTheme!.color, Colors.white);
          expect(button.foregroundColor!.resolve({}), Colors.white);
          expect(fab.foregroundColor, Colors.white);
          expect(theme.tabBarTheme.labelColor, Colors.white);
          for (final background in [
            bar.backgroundColor!,
            button.backgroundColor!.resolve({})!,
            fab.backgroundColor!,
          ]) {
            expect(whiteContrast(background), greaterThanOrEqualTo(4.5));
          }
        }
      }
    });

    test('THEME16 学习语义色不受强调色影响', () {
      expect(AppColors.known, const Color(0xFF2E7D32));
      expect(AppColors.hazy, const Color(0xFFEF6C00));
      expect(AppColors.unknown, const Color(0xFFC62828));
      for (final AccentPalette palette in accentPalettes) {
        final ThemeData theme = AppTheme.of(Brightness.light, palette.color);
        expect(theme.colorScheme.error, AppColors.unknown);
      }
      expect(AppColors.forAnswer(2), AppColors.known);
      expect(AppColors.forAnswer(1), AppColors.hazy);
      expect(AppColors.forAnswer(0), AppColors.unknown);
    });
  });

  group('COPY 文案与错误状态', () {
    test('COPY01/COPY02 删除与移除说明不同的数据影响', () async {
      final AppLocalizations zh = await AppLocalizations.delegate.load(
        const Locale('zh'),
      );
      expect(zh.deleteWordsBodyBulk(2), contains('所有词书'));
      expect(zh.deleteWordsBodyBulk(2), contains('学习记录'));
      expect(zh.removeFromListBody(2, 'CET-6'), contains('CET-6'));
      expect(zh.removeFromListBody(2, 'CET-6'), contains('学习进度'));
      expect(zh.deleteWordListBody('CET-6'), contains('单词和学习记录'));
      // 移出词书 ≠ 删除单词：文案不能互换。
      expect(zh.removeFromListBody(2, 'CET-6'), isNot(contains('所有词书')));
    });

    test('COPY03/COPY04 重置与掌握文案准确', () async {
      final AppLocalizations zh = await AppLocalizations.delegate.load(
        const Locale('zh'),
      );
      expect(zh.resetProgressBodyOne, contains('作答历史'));
      expect(zh.markMasteredBodyOne, contains('30 天'));
      expect(zh.markMasteredBodyOne, contains('不计入作答次数'));
      expect(zh.unmarkMasteredBodyOne, contains('恢复到学习阶段'));
    });

    test('COPY05 恢复历史版本提示包含后果与暂停同步', () async {
      final AppLocalizations zh = await AppLocalizations.delegate.load(
        const Locale('zh'),
      );
      expect(zh.restoreVersionBody, contains('移除'));
      expect(zh.restoreVersionBody, contains('暂停同步'));
      expect(zh.deleteBackupBody('a.json'), contains('a.json'));
    });

    test('COPY07 部分成功不报成全部成功', () async {
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(en.syncUploadPending.toLowerCase(), contains('pending'));
      expect(en.syncUploadPending.toLowerCase(), contains('saved'));
    });

    test('COPY10/COPY12 界面文案不含原始异常与凭据', () {
      final Map<String, Object?> en = _arb('app_en.arb');
      final Map<String, Object?> zh = _arb('app_zh.arb');
      final RegExp rawError = RegExp(
        r'(Exception|\$e|stack|token=|SQLITE|Content-Type)',
      );
      for (final Map<String, Object?> arb in <Map<String, Object?>>[en, zh]) {
        for (final String key in _keys(arb)) {
          final String message = arb[key] as String;
          expect(
            rawError.hasMatch(message),
            isFalse,
            reason: '$key 含有原始异常或内部细节: $message',
          );
        }
      }
    });
  });
}
