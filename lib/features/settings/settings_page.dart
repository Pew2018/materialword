import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_info.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../../services/screen_awake.dart';
import '../../services/tts_service.dart';
import '../../shared/widgets/classic_select.dart';
import '../../shared/widgets/common.dart';
import '../backup/backup_page.dart';
import '../sync/sync_settings_page.dart';
import 'diagnostics_page.dart';

/// Settings: daily targets, study mode, appearance, pronunciation, data.
///
/// Information architecture: five top-level sections (学习 / 外观 / 发音 / 数据 /
/// 关于). Anything long or diagnostic lives on its own page, so this screen stays
/// a scannable list instead of an endless scroll.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Future<void> _save({
    int? newTarget,
    int? reviewLimit,
    Value<String?>? bookValue,
    StudyMode? mode,
    ThemePreference? theme,
    String? accentColor,
    String? ttsVoice,
    String? ttsLocale,
    int? ttsRate,
    bool? ttsAutoSpeak,
  }) async {
    await ref
        .read(settingsRepositoryProvider)
        .save(
          dailyNewTarget: newTarget,
          dailyReviewLimit: reviewLimit,
          currentWordBookId: bookValue,
          studyMode: mode,
          theme: theme,
          accentColor: accentColor,
          ttsVoice: ttsVoice,
          ttsLocale: ttsLocale,
          ttsRate: ttsRate,
          ttsAutoSpeak: ttsAutoSpeak,
        );
    // Only the derived "today" numbers depend on the targets; statistics do
    // not, so they are not invalidated here.
    if (newTarget != null || reviewLimit != null || bookValue != null) {
      ref.invalidate(todayProgressProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<StudySettingsRow> settingsAsync = ref.watch(
      settingsProvider,
    );
    final AsyncValue<List<WordBookSummary>> books = ref.watch(
      bookSummariesProvider,
    );
    final StudySettingsRow? settings = settingsAsync.value;
    if (settings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List<WordBookSummary> bookList =
        books.value ?? const <WordBookSummary>[];
    final bool bookMissing =
        settings.currentWordBookId != null &&
        !bookList.any((b) => b.book.id == settings.currentWordBookId);

    return ContentColumn(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          SectionHeader(title: '每日目标'),
          SettingsGroup(
            children: <Widget>[
              _StepperSetting(
                label: '每日新词',
                value: settings.dailyNewTarget,
                min: 5,
                max: 200,
                step: 5,
                onCommit: (int value) => _save(newTarget: value),
              ),
              _StepperSetting(
                label: '每日复习上限',
                value: settings.dailyReviewLimit,
                min: 10,
                max: 500,
                step: 10,
                onCommit: (int value) => _save(reviewLimit: value),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  '目标按设备计算；词书只决定学习范围。超出复习上限的到期词会显示为「积压」，不会丢失。',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          SectionHeader(title: '学习'),
          SettingsGroup(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: ClassicSelect<String>(
                  label: '当前学习词书',
                  value: bookMissing ? '' : (settings.currentWordBookId ?? ''),
                  options: <ClassicOption<String>>[
                    const ClassicOption<String>(value: '', label: '全部词书'),
                    for (final WordBookSummary summary in bookList)
                      ClassicOption<String>(
                        value: summary.book.id,
                        label: summary.book.name,
                      ),
                  ],
                  onChanged: (String value) => _save(
                    bookValue: Value<String?>(value.isEmpty ? null : value),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ClassicSelect<String>(
                  label: '学习模式',
                  value: settings.studyMode,
                  options: <ClassicOption<String>>[
                    for (final StudyMode mode in StudyMode.values)
                      if (mode != StudyMode.special)
                        ClassicOption<String>(
                          value: mode.code,
                          label: mode.label,
                        ),
                  ],
                  onChanged: (String value) =>
                      _save(mode: StudyMode.fromCode(value)),
                ),
              ),
              const _RandomOrderSetting(),
              const _KeepScreenOnTile(),
            ],
          ),
          SectionHeader(title: '外观'),
          SettingsGroup(
            children: <Widget>[
              for (final ThemePreference preference in ThemePreference.values)
                RadioListTile<String>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  value: preference.code,
                  groupValue: settings.themeMode,
                  onChanged: (String? value) =>
                      _save(theme: ThemePreference.fromCode(value)),
                  title: Text(preference.label),
                ),
              _AccentColorSection(
                current: parseAccent(settings.accentColor),
                onPick: (String hex) => _save(accentColor: hex),
              ),
            ],
          ),
          SectionHeader(title: '发音'),
          _TtsSection(
            settings: settings,
            onSave: (String? voice, String? locale, int? rate, bool? auto) =>
                _save(
                  ttsVoice: voice,
                  ttsLocale: locale,
                  ttsRate: rate,
                  ttsAutoSpeak: auto,
                ),
          ),
          SectionHeader(title: '数据'),
          SettingsGroup(
            children: <Widget>[
              SettingsTile(
                leading: const Icon(Icons.sync),
                title: '数据同步',
                subtitle: '在多台设备间同步学习进度',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const SyncSettingsPage(),
                  ),
                ),
              ),
              SettingsTile(
                leading: const Icon(Icons.backup_outlined),
                title: '备份与恢复',
                subtitle: '备份、恢复或迁移学习数据',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const BackupPage(),
                  ),
                ),
              ),
              SettingsTile(
                leading: const Icon(Icons.troubleshoot_outlined),
                title: '诊断信息',
                subtitle: '版本信息、运行日志与问题反馈',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const DiagnosticsPage(),
                  ),
                ),
              ),
            ],
          ),
          SectionHeader(title: '关于'),
          SettingsGroup(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'MaterialWord $appVersion',
                      style: theme.textTheme.bodyMedium,
                    ),
                    AppSpacing.h4,
                    Text(
                      '离线优先的英语单词学习工具。学习记录保存在本机，'
                      '开启同步后会在多台设备间保持一致。',
                      style: theme.textTheme.bodySmall,
                    ),
                    AppSpacing.h8,
                    Text(
                      '内置离线词典：$dictionaryEntryCount 条词条'
                      '（ECDICT，$dictionaryLicense 许可）。',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SettingsTile(
                leading: const Icon(Icons.description_outlined),
                title: '开源许可证',
                subtitle: 'Flutter、Drift、ECDICT 及其他依赖',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'MaterialWord',
                  applicationVersion: appVersion,
                  applicationLegalese: 'ECDICT 词典数据以 MIT 许可分发。',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Numeric setting with exactly one input model: a stepper.
///
/// The old row offered a text field, a minus button, a plus button *and* a
/// slider for the same number — three competing ways to do one thing, and the
/// slider alone was taller than the rest of the row. Now:
///  * −/+ adjust by the user-visible step (5 or 10) and commit once per tap;
///  * tapping the value opens a small dialog when an exact number is needed;
///  * an external change (another device, a merge) is adopted immediately.
class _StepperSetting extends StatelessWidget {
  const _StepperSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onCommit,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onCommit;

  Future<void> _edit(BuildContext context) async {
    final int? result = await _askNumber(
      context,
      title: label,
      initial: value,
      min: min,
      max: max,
    );
    if (result != null && result != value) onCommit(result);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          IconButton(
            tooltip: '减少',
            icon: const Icon(Icons.remove),
            onPressed: value > min
                ? () => onCommit((value - step).clamp(min, max))
                : null,
          ),
          Tooltip(
            message: '输入具体数值',
            child: InkWell(
              onTap: () => _edit(context),
              child: Container(
                constraints: const BoxConstraints(minWidth: 64),
                height: AppDimens.minTouchTarget,
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '增加',
            icon: const Icon(Icons.add),
            onPressed: value < max
                ? () => onCommit((value + step).clamp(min, max))
                : null,
          ),
        ],
      ),
    );
  }
}

Future<int?> _askNumber(
  BuildContext context, {
  required String title,
  required int initial,
  required int min,
  required int max,
}) async {
  // The shared prompt owns its controller and disposes it with the route; a
  // locally created controller would be disposed while the dialog is still
  // animating out (and the field would throw on the next frame).
  final String? raw = await promptForText(
    context,
    title: title,
    label: '数值（$min–$max）',
    initialValue: '$initial',
    confirmLabel: '确定',
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
    ],
  );
  if (raw == null) return null;
  final int? parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    if (context.mounted) {
      showMessage(context, '请输入 $min–$max 之间的数字', error: true);
    }
    return null;
  }
  return parsed.clamp(min, max);
}

/// 14 classic Material palettes + a custom HEX entry + restore-default.
class _AccentColorSection extends StatelessWidget {
  const _AccentColorSection({required this.current, required this.onPick});

  final Color current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('强调色', style: theme.textTheme.bodyLarge)),
              Text(hexOf(current), style: theme.textTheme.bodySmall),
            ],
          ),
          AppSpacing.h8,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final AccentPalette palette in accentPalettes)
                _Swatch(
                  color: palette.color,
                  label: palette.label,
                  selected: hexOf(palette.color) == hexOf(current),
                  onTap: () => onPick(palette.hex),
                ),
            ],
          ),
          AppSpacing.h8,
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _pickCustom(context),
                icon: const Icon(Icons.colorize, size: AppDimens.iconSizeSmall),
                label: const Text('自定义 HEX'),
              ),
              TextButton.icon(
                onPressed: () => onPick(hexOf(AppColors.defaultAccent)),
                icon: const Icon(
                  Icons.restart_alt,
                  size: AppDimens.iconSizeSmall,
                ),
                label: const Text('恢复默认'),
              ),
            ],
          ),
          Text(
            '强调色即时生效，影响顶栏、底栏、按钮、开关、滑块与焦点框；'
            '「认识/模糊/不认识」的颜色与主题无关。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    final String? value = await promptForText(
      context,
      title: '自定义强调色',
      label: 'HEX 颜色',
      initialValue: hexOf(current),
      confirmLabel: '应用',
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
        LengthLimitingTextInputFormatter(7),
      ],
    );
    if (value == null || !context.mounted) return;
    final String raw = value.trim().replaceAll('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) {
      if (context.mounted) {
        showMessage(context, '请输入 6 位 HEX 颜色，例如 #1565C0', error: true);
      }
      return;
    }
    onPick('#${raw.toUpperCase()}');
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '强调色 $label',
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? theme.textTheme.bodyLarge?.color ?? Colors.black
                    : theme.dividerColor,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? Icon(Icons.check, size: 18, color: AppTheme.onColor(color))
                : null,
          ),
        ),
      ),
    );
  }
}

class _TtsSection extends ConsumerStatefulWidget {
  const _TtsSection({required this.settings, required this.onSave});

  final StudySettingsRow settings;
  final void Function(String? voice, String? locale, int? rate, bool? auto)
  onSave;

  @override
  ConsumerState<_TtsSection> createState() => _TtsSectionState();
}

class _TtsSectionState extends ConsumerState<_TtsSection> {
  late Future<List<TtsVoice>> _voices;

  @override
  void initState() {
    super.initState();
    _voices = ref.read(ttsServiceProvider).englishVoices();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      children: <Widget>[
        FutureBuilder<List<TtsVoice>>(
          future: _voices,
          builder: (BuildContext context, AsyncSnapshot<List<TtsVoice>> snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SettingsTile(
                leading: Icon(Icons.record_voice_over_outlined),
                title: '英语语音',
                subtitle: '正在读取系统语音…',
              );
            }
            final List<TtsVoice> voices = snap.data ?? const <TtsVoice>[];
            if (voices.isEmpty) {
              return SettingsTile(
                leading: const Icon(Icons.volume_off_outlined),
                title: '英语语音',
                subtitle:
                    '系统未提供英语语音：学习页面会显示「语音不可用」，不影响背词。'
                    '请先在系统设置中安装英语语音。',
              );
            }
            final String selected =
                voices
                    .where(
                      (v) =>
                          v.name == widget.settings.ttsVoice &&
                          v.locale.toLowerCase() ==
                              widget.settings.ttsLocale
                                  .replaceAll('_', '-')
                                  .toLowerCase(),
                    )
                    .firstOrNull
                    ?.key ??
                '';
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ClassicSelect<String>(
                label: '英语语音',
                value: selected,
                options: <ClassicOption<String>>[
                  const ClassicOption<String>(value: '', label: '系统默认'),
                  for (final TtsVoice voice in voices)
                    ClassicOption<String>(
                      value: voice.key,
                      label: voice.display,
                    ),
                ],
                onChanged: (String key) {
                  final TtsVoice? voice = voices
                      .where((TtsVoice v) => v.key == key)
                      .firstOrNull;
                  widget.onSave(voice?.name, voice?.locale, null, null);
                },
              ),
            );
          },
        ),
        _TtsRateSetting(
          rate: widget.settings.ttsRate,
          onCommit: (int value) => widget.onSave(null, null, value, null),
        ),
        SettingsSwitchTile(
          value: widget.settings.ttsAutoSpeak,
          icon: Icons.volume_up_outlined,
          title: '进入单词时自动发音',
          subtitle: '语音是否可离线使用取决于系统安装的语音包',
          onChanged: (bool value) => widget.onSave(null, null, null, value),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新语音列表'),
                  onPressed: () {
                    final voices = ref
                        .read(ttsServiceProvider)
                        .englishVoices(refresh: true);
                    setState(() {
                      _voices = voices;
                    });
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final TtsService tts = ref.read(ttsServiceProvider);
                    final bool ok = await tts.speak(
                      'vocabulary',
                      voiceName: widget.settings.ttsVoice.isEmpty
                          ? null
                          : widget.settings.ttsVoice,
                      locale: widget.settings.ttsLocale,
                      rate: widget.settings.ttsRate,
                    );
                    if (!context.mounted) return;
                    showMessage(
                      context,
                      ok ? '测试朗读完成' : (tts.lastError ?? '系统语音不可用'),
                      error: !ok,
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('测试发音'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TtsRateSetting extends StatefulWidget {
  const _TtsRateSetting({required this.rate, required this.onCommit});

  final int rate;
  final ValueChanged<int> onCommit;

  @override
  State<_TtsRateSetting> createState() => _TtsRateSettingState();
}

class _TtsRateSettingState extends State<_TtsRateSetting> {
  late double _draft = widget.rate.toDouble();

  @override
  void didUpdateWidget(covariant _TtsRateSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rate != widget.rate) _draft = widget.rate.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '发音速度',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text('${_draft.round()}%'),
            ],
          ),
          Slider(
            value: _draft.clamp(10, 100),
            min: 10,
            max: 100,
            // No `divisions`: with 18 divisions over 10–100 the thumb could
            // only land on 5% steps, so a slow drag moved in visible jumps.
            // Continuous tracking follows the pointer pixel by pixel; the
            // number next to the label still reads as a whole percent and the
            // value is still written once, on release.
            label: '${_draft.round()}%',
            onChanged: (double value) => setState(() => _draft = value),
            onChangeEnd: (double value) => widget.onCommit(value.round()),
          ),
        ],
      ),
    );
  }
}

/// Device-local "keep the screen on" switch.
///
/// Deliberately not part of `study_settings`: whether this screen dims is a
/// property of the device in front of you, not of the shared learning plan, so
/// it lives in `app_meta` and never travels through sync.
class _KeepScreenOnTile extends ConsumerWidget {
  const _KeepScreenOnTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> value = ref.watch(keepScreenOnProvider);
    final bool supported = ref.read(screenAwakeProvider).isSupported;
    return SettingsSwitchTile(
      value: value.value ?? false,
      icon: Icons.lightbulb_outline,
      title: '学习时保持屏幕常亮',
      subtitle: supported
          ? '只在实际的学习或练习页面生效；离开页面或切到后台后自动释放'
          : '当前平台不支持此功能，学习功能不受影响',
      onChanged: supported
          ? (bool enabled) async {
              final AppDatabase db = ref.read(databaseProvider);
              await db.writeMeta(
                ScreenAwakeService.preferenceKey,
                enabled ? '1' : '0',
              );
              ref.invalidate(keepScreenOnProvider);
              if (!enabled) {
                await ref.read(screenAwakeProvider).disable();
              }
            }
          : null,
    );
  }
}

/// Device-local study order preference. Stored in `app_meta`, so it is never
/// synced and never changes *which* cards a session contains.
class _RandomOrderSetting extends ConsumerStatefulWidget {
  const _RandomOrderSetting();

  @override
  ConsumerState<_RandomOrderSetting> createState() =>
      _RandomOrderSettingState();
}

class _RandomOrderSettingState extends ConsumerState<_RandomOrderSetting> {
  static const String key = 'study_random_order';
  bool? _value;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String? raw = await ref.read(databaseProvider).readMeta(key);
    if (mounted) setState(() => _value = raw == '1');
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchTile(
      value: _value ?? false,
      icon: Icons.shuffle,
      title: '随机学习顺序',
      subtitle: '只改变呈现顺序，不会遗漏或重复；专项练习与冲刺不受影响',
      onChanged: _value == null
          ? null
          : (bool value) async {
              await ref
                  .read(databaseProvider)
                  .writeMeta(key, value ? '1' : '0');
              if (mounted) setState(() => _value = value);
            },
    );
  }
}
