import 'dart:convert';

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
import '../../services/diagnostics_service.dart';
import '../../services/screen_awake.dart';
import '../../services/tts_service.dart';

import 'package:file_picker/file_picker.dart';

import '../../shared/widgets/common.dart';
import '../backup/backup_page.dart';
import '../sync/sync_settings_page.dart';

/// Settings: daily targets, study mode, appearance, pronunciation, data.
///
/// Laid out as classic grouped lists (flat surface + hairline dividers) instead
/// of a stack of cards: denser, easier to scan, and every row keeps a 56dp
/// touch target.
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

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        SectionHeader(title: '每日目标（全局）'),
        SettingsGroup(
          children: <Widget>[
            _NumberSetting(
              label: '每日新词',
              value: settings.dailyNewTarget,
              min: 5,
              max: 200,
              step: 5,
              onCommit: (int value) => _save(newTarget: value),
            ),
            _NumberSetting(
              label: '每日复习上限',
              value: settings.dailyReviewLimit,
              min: 10,
              max: 500,
              step: 10,
              onCommit: (int value) => _save(reviewLimit: value),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Text(
                '目标按设备全局计算；词书只决定学习范围。超出复习上限的到期词显示为「积压」，不会丢失。',
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
              child: DropdownButtonFormField<String?>(
                initialValue: settings.currentWordBookId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '当前学习词书'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('全部词书'),
                  ),
                  for (final WordBookSummary summary
                      in books.value ?? const <WordBookSummary>[])
                    DropdownMenuItem<String?>(
                      value: summary.book.id,
                      child: Text(summary.book.name),
                    ),
                ],
                onChanged: (String? value) =>
                    _save(bookValue: Value<String?>(value)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: DropdownButtonFormField<String>(
                initialValue: settings.studyMode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '学习模式'),
                items: <DropdownMenuItem<String>>[
                  for (final StudyMode mode in StudyMode.values)
                    if (mode != StudyMode.special)
                      DropdownMenuItem<String>(
                        value: mode.code,
                        child: Text(mode.label),
                      ),
                ],
                onChanged: (String? value) => _save(
                  mode: value == null ? null : StudyMode.fromCode(value),
                ),
              ),
            ),
            const _RandomOrderSetting(),
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
        SectionHeader(title: '学习'),
        const _ScreenAwakeSection(),
        SectionHeader(title: '数据'),
        SettingsGroup(
          children: <Widget>[
            SettingsTile(
              leading: const Icon(Icons.sync),
              title: '数据同步',
              subtitle: 'GitHub / WebDAV / 本地文件，合并而不是覆盖',
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
              subtitle: '导出 JSON、导入并合并',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const BackupPage(),
                ),
              ),
            ),
          ],
        ),
        SectionHeader(title: '诊断'),
        const _DiagnosticsSection(),
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
                    '离线优先的英语单词学习工具。学习记录保存在本机 SQLite，'
                    '同步时只传输合并后的数据，凭据只存放在系统安全存储。',
                    style: theme.textTheme.bodySmall,
                  ),
                  AppSpacing.h8,
                  Text(
                    '内置词典：ECDICT（$dictionaryLicense 许可，$dictionaryEntryCount 条词条）。'
                    '界面为 Material Design 2 经典样式。',
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
    );
  }
}

/// Slider + stepper that keeps a local draft while the user drags.
///
/// The phase-1 version passed the *persisted* value as `value` and wrote to the
/// database on every `onChanged`, which made the thumb stutter (the provider
/// round-trip was slower than the drag) and hammered SQLite. Now:
///  * `onChanged` only updates local state → the thumb always follows the
///    finger/mouse and the number updates live;
///  * `onChangeEnd`, the steppers and the text field commit exactly one write;
///  * an external change (another device, a merge) is adopted only when the user
///    is not currently dragging.
class _NumberSetting extends StatefulWidget {
  const _NumberSetting({
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

  @override
  State<_NumberSetting> createState() => _NumberSettingState();
}

class _NumberSettingState extends State<_NumberSetting> {
  late int _draft = widget.value;
  bool _dragging = false;
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );

  @override
  void didUpdateWidget(covariant _NumberSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && widget.value != _draft) {
      setState(() {
        _draft = widget.value;
        _controller.text = '${widget.value}';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _quantise(double raw) {
    final int stepped = (raw / widget.step).round() * widget.step;
    return stepped.clamp(widget.min, widget.max);
  }

  void _commit(int value) {
    final int bounded = value.clamp(widget.min, widget.max);
    setState(() {
      _draft = bounded;
      _controller.text = '$bounded';
    });
    if (bounded != widget.value) widget.onCommit(bounded);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(widget.label, style: theme.textTheme.bodyLarge),
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (String value) {
                    final int? parsed = int.tryParse(value);
                    if (parsed == null) {
                      _controller.text = '$_draft';
                      return;
                    }
                    _commit(parsed);
                  },
                ),
              ),
              IconButton(
                tooltip: '减少',
                icon: const Icon(Icons.remove),
                onPressed: _draft > widget.min
                    ? () => _commit(_draft - widget.step)
                    : null,
              ),
              IconButton(
                tooltip: '增加',
                icon: const Icon(Icons.add),
                onPressed: _draft < widget.max
                    ? () => _commit(_draft + widget.step)
                    : null,
              ),
            ],
          ),
          Slider(
            value: _draft.toDouble().clamp(
              widget.min.toDouble(),
              widget.max.toDouble(),
            ),
            min: widget.min.toDouble(),
            max: widget.max.toDouble(),
            // No divisions: a dense row of tick dots was visual noise and made
            // the value jump between unrelated steps.
            label: '$_draft',
            semanticFormatterCallback: (double value) => '${value.round()}',
            onChangeStart: (double _) => setState(() => _dragging = true),
            onChanged: (double value) {
              setState(() => _draft = _quantise(value));
            },
            onChangeEnd: (double value) {
              _dragging = false;
              _controller.text = '${_quantise(value)}';
              _commit(_quantise(value));
            },
          ),
        ],
      ),
    );
  }
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
    final ThemeData theme = Theme.of(context);
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
            final String? selected = voices
                .where(
                  (v) =>
                      v.name == widget.settings.ttsVoice &&
                      v.locale.toLowerCase() ==
                          widget.settings.ttsLocale
                              .replaceAll('_', '-')
                              .toLowerCase(),
                )
                .firstOrNull
                ?.key;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: DropdownButtonFormField<String>(
                key: ValueKey(selected),
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '英语语音'),
                hint: const Text('系统默认'),
                items: <DropdownMenuItem<String>>[
                  for (final TtsVoice voice in voices)
                    DropdownMenuItem<String>(
                      value: voice.key,
                      child: Text(
                        voice.display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (String? name) {
                  final TtsVoice? voice = voices
                      .where((TtsVoice v) => v.key == name)
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
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          value: widget.settings.ttsAutoSpeak,
          onChanged: (bool value) => widget.onSave(null, null, null, value),
          title: const Text('进入单词时自动发音'),
          subtitle: Text(
            '语音是否可离线使用取决于系统安装的语音包',
            style: theme.textTheme.bodySmall,
          ),
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
            divisions: 18,
            label: '${_draft.round()}%',
            onChanged: (double value) => setState(() => _draft = value),
            onChangeEnd: (double value) => widget.onCommit(value.round()),
          ),
        ],
      ),
    );
  }
}

/// Opt-in diagnostics: off by default, bounded, redacted, exportable.
/// Device-local "keep the screen on" switch.
///
/// Deliberately not part of `study_settings`: whether this screen dims is a
/// property of the device in front of you, not of the shared learning plan, so
/// it lives in `app_meta` and never travels through sync.
class _ScreenAwakeSection extends ConsumerWidget {
  const _ScreenAwakeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<bool> value = ref.watch(keepScreenOnProvider);
    final bool supported = ref.read(screenAwakeProvider).isSupported;
    return SettingsGroup(
      children: <Widget>[
        SwitchListTile(
          secondary: const Icon(Icons.lightbulb_outline),
          value: value.value ?? false,
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
          title: const Text('学习时保持屏幕常亮'),
          subtitle: Text(
            supported ? '只在实际的学习或练习页面生效；离开页面或切到后台后自动释放' : '当前平台不支持此功能，学习功能不受影响',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Opt-in diagnostics: off by default, bounded, redacted, exportable.
class _DiagnosticsSection extends ConsumerStatefulWidget {
  const _DiagnosticsSection();

  @override
  ConsumerState<_DiagnosticsSection> createState() =>
      _DiagnosticsSectionState();
}

class _DiagnosticsSectionState extends ConsumerState<_DiagnosticsSection> {
  bool _enabled = DiagnosticsService.instance.enabled;
  bool _busy = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final String id = await ref.read(settingsRepositoryProvider).deviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final String report = await DiagnosticsService.instance.buildReport(
        ref.read(databaseProvider),
        runtime: <String, Object?>{
          'appVersion': appVersion,
          'buildCommit': buildCommit,
          'flutterVersion': '3.50.1',
          'dartVersion': '3.14.0',
          'diagnosticsEnabled': _enabled,
        },
      );
      final Uri? result = await FilePicker.saveFile(
        fileName: 'materialword-diagnostics.txt',
        bytes: utf8.encode(report),
        mimeType: 'text/plain',
        dialogTitle: '保存诊断信息',
      );
      if (!mounted) return;
      showMessage(context, result == null ? '已取消导出' : '诊断信息已导出（不含凭据与学习内容）');
    } catch (e) {
      if (!mounted) return;
      showMessage(context, '导出失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SettingsGroup(
      children: <Widget>[
        SwitchListTile(
          value: _enabled,
          title: const Text('记录详细诊断日志'),
          subtitle: const Text('默认关闭；开启后只保留最近 400 条、24 小时，自动脱敏'),
          onChanged: (bool value) async {
            await DiagnosticsService.instance.setEnabled(
              ref.read(databaseProvider),
              value,
            );
            if (mounted) setState(() => _enabled = value);
          },
        ),
        SettingsTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: '导出诊断信息',
          subtitle: '版本、commit、数据库与词典统计、同步状态；不含凭据和学习内容',
          trailing: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt),
          onTap: _busy ? null : _export,
        ),
        SettingsTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: '清除已记录的诊断日志',
          subtitle: DiagnosticsService.instance.entries.isEmpty
              ? '当前没有记录'
              : '${DiagnosticsService.instance.entries.length} 条记录',
          onTap: () {
            DiagnosticsService.instance.clear();
            setState(() {});
            showMessage(context, '已清除诊断日志');
          },
        ),
        SettingsTile(
          leading: const Icon(Icons.memory_outlined),
          title: '本机设备标识',
          subtitle: _deviceId ?? '读取中…',
          onTap: _deviceId == null
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: _deviceId!));
                  if (!context.mounted) return;
                  showMessage(context, '已复制设备标识（仅用于排查同步问题）');
                },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '诊断信息不会包含 Token、密码、认证头、词条内容或个人笔记；'
            '同步配置只记录方式，不记录地址、账号或路径。',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
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
    return SwitchListTile(
      value: _value ?? false,
      title: const Text('随机学习顺序'),
      subtitle: const Text('只改变呈现顺序，不会遗漏或重复；专项练习与冲刺不受影响'),
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
