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
import '../../l10n/enum_labels.dart';
import '../../l10n/l10n.dart';
import '../../l10n/voice_labels.dart';
import '../../services/tts_service.dart';
import '../../shared/widgets/classic_select.dart';
import '../../shared/widgets/common.dart';
import '../backup/backup_page.dart';
import '../sync/sync_settings_page.dart';
import 'diagnostics_page.dart';

/// Settings: daily targets, study mode, appearance, pronunciation, data.
///
/// Information architecture: five top-level sections (Study / Appearance /
/// Pronunciation / Data / About). Anything long or diagnostic lives on its own page, so this screen stays
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
    // Theme and accent are device-local. Mirror them into the startup snapshot
    // in this same save so the next launch does not wait for the settings
    // stream to backfill the file. Other fields never touch that file.
    if (theme != null || accentColor != null) {
      final StudySettingsRow row = await ref
          .read(settingsRepositoryProvider)
          .load();
      await ref
          .read(appearanceStoreProvider)
          .write(
            theme: ThemePreference.fromCode(row.themeMode),
            accentColor: row.accentColor,
          );
    }
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

    final AppLocalizations l10n = context.l10n;
    return ContentColumn(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          SectionHeader(title: l10n.sectionDailyGoals),
          SettingsGroup(
            children: <Widget>[
              _StepperSetting(
                label: l10n.dailyNewWords,
                value: settings.dailyNewTarget,
                min: 5,
                max: 200,
                step: 5,
                onCommit: (int value) => _save(newTarget: value),
              ),
              _StepperSetting(
                label: l10n.dailyReviewLimit,
                value: settings.dailyReviewLimit,
                min: 10,
                max: 500,
                step: 10,
                onCommit: (int value) => _save(reviewLimit: value),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  l10n.dailyGoalsNote,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          SectionHeader(title: l10n.sectionStudy),
          SettingsGroup(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: ClassicSelect<String>(
                  label: l10n.studyWordList,
                  value: bookMissing ? '' : (settings.currentWordBookId ?? ''),
                  options: <ClassicOption<String>>[
                    ClassicOption<String>(value: '', label: l10n.allWordLists),
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
                  label: l10n.studyMode,
                  value: settings.studyMode,
                  options: <ClassicOption<String>>[
                    for (final StudyMode mode in StudyMode.values)
                      if (mode != StudyMode.special)
                        ClassicOption<String>(
                          value: mode.code,
                          label: mode.label(l10n),
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
          SectionHeader(title: l10n.settingsAppearance),
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
                  title: Text(preference.label(l10n)),
                ),
              _AccentColorSection(
                current: parseAccent(settings.accentColor),
                onPick: (String hex) => _save(accentColor: hex),
              ),
              // Language is a device preference, like the accent colour, so it
              // sits in Appearance right under the colour picker and never
              // travels through sync.
              const _LanguageSetting(),
            ],
          ),
          SectionHeader(title: l10n.sectionPronunciation),
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
          SectionHeader(title: l10n.sectionData),
          SettingsGroup(
            children: <Widget>[
              SettingsTile(
                leading: const Icon(Icons.sync),
                title: l10n.syncTitle,
                subtitle: l10n.syncSubtitle,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const SyncSettingsPage(),
                  ),
                ),
              ),
              SettingsTile(
                leading: const Icon(Icons.backup_outlined),
                title: l10n.backupRestore,
                subtitle: l10n.backupRestoreSubtitle,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const BackupPage(),
                  ),
                ),
              ),
              SettingsTile(
                leading: const Icon(Icons.troubleshoot_outlined),
                title: l10n.diagnostics,
                subtitle: l10n.diagnosticsSubtitle,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const DiagnosticsPage(),
                  ),
                ),
              ),
            ],
          ),
          SectionHeader(title: l10n.sectionAbout),
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
                    Text(l10n.aboutBlurb, style: theme.textTheme.bodySmall),
                    AppSpacing.h8,
                    Text(
                      l10n.aboutDictionary(
                        dictionaryEntryCount,
                        dictionaryLicense,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SettingsTile(
                leading: const Icon(Icons.description_outlined),
                title: l10n.openSourceLicenses,
                subtitle: l10n.licensesSubtitle,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'MaterialWord',
                  applicationVersion: appVersion,
                  applicationLegalese: l10n.legalNotice,
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
            tooltip: context.l10n.decrease,
            icon: const Icon(Icons.remove),
            onPressed: value > min
                ? () => onCommit((value - step).clamp(min, max))
                : null,
          ),
          Tooltip(
            message: context.l10n.enterExactValue,
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
            tooltip: context.l10n.increase,
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
    label: context.l10n.valueRange(min, max),
    initialValue: '$initial',
    confirmLabel: context.l10n.ok,
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
    ],
  );
  if (raw == null) return null;
  final int? parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    if (context.mounted) {
      showMessage(
        context,
        context.l10n.enterNumberInRange(min, max),
        error: true,
      );
    }
    return null;
  }
  return parsed.clamp(min, max);
}

/// The accent presets, a custom HEX entry and restore-default.
///
/// The layout is unchanged on purpose: plain round swatches in a [Wrap] that
/// reflows on a narrow window. Only the palette data changed (23 presets).
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
              Expanded(
                child: Text(
                  context.l10n.accentColor,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
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
                  label: palette.label(context.l10n),
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
                label: Text(context.l10n.accentCustom),
              ),
              TextButton.icon(
                onPressed: () => onPick(hexOf(AppColors.defaultAccent)),
                icon: const Icon(
                  Icons.restart_alt,
                  size: AppDimens.iconSizeSmall,
                ),
                label: Text(context.l10n.accentRestoreDefault),
              ),
            ],
          ),
          Text(context.l10n.accentColorHint, style: theme.textTheme.bodySmall),
          AppSpacing.h4,
          Text(context.l10n.accentAnswerNote, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    final String? value = await promptForText(
      context,
      title: context.l10n.customAccentTitle,
      label: context.l10n.accentHex,
      initialValue: hexOf(current),
      confirmLabel: context.l10n.apply,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
        LengthLimitingTextInputFormatter(7),
      ],
    );
    if (value == null || !context.mounted) return;
    final String raw = value.trim().replaceAll('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) {
      if (context.mounted) {
        showMessage(context, context.l10n.invalidHexColor, error: true);
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
      label: context.l10n.accentSwatchSemantics(label),
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
              return SettingsTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: context.l10n.englishVoice,
                subtitle: context.l10n.loadingVoices,
              );
            }
            final List<TtsVoice> voices = snap.data ?? const <TtsVoice>[];
            if (voices.isEmpty) {
              return SettingsTile(
                leading: const Icon(Icons.volume_off_outlined),
                title: context.l10n.englishVoice,
                subtitle: context.l10n.noEnglishVoice,
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
                label: context.l10n.englishVoice,
                value: selected,
                options: <ClassicOption<String>>[
                  ClassicOption<String>(
                    value: '',
                    label: context.l10n.systemDefault,
                  ),
                  for (final TtsVoice voice in voices)
                    ClassicOption<String>(
                      value: voice.key,
                      label: ttsVoiceLabel(context.l10n, voice),
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
          title: context.l10n.autoPronounce,
          subtitle: context.l10n.autoPronounceHint,
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
                  label: Text(context.l10n.refreshVoices),
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
                    // A working preview is audible: no snackbar needed. Only a
                    // failure has to be reported.
                    if (!context.mounted || ok) return;
                    showMessage(
                      context,
                      context.l10n.voiceUnavailable,
                      error: true,
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: Text(context.l10n.previewVoice),
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
                  context.l10n.speakingRate,
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
      title: context.l10n.keepScreenAwake,
      subtitle: supported
          ? context.l10n.keepScreenAwakeHint
          : context.l10n.keepScreenAwakeUnsupported,
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
      title: context.l10n.randomOrder,
      subtitle: context.l10n.randomOrderHint,
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

/// Language picker row.
///
/// Lives inside the Appearance group, directly after the accent colours, and
/// uses the same [ClassicSelect] field and menu as Study Mode and Word List: a
/// language is one more enumerated preference, not a reason for its own dialog.
class _LanguageSetting extends ConsumerWidget {
  const _LanguageSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppLanguage language = ref.watch(languageProvider);
    // The same field + menu as Study Mode and Word List, instead of a separate
    // centred radio dialog that looked like a different app.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClassicSelect<AppLanguage>(
        label: l10n.appLanguage,
        value: language,
        options: <ClassicOption<AppLanguage>>[
          for (final AppLanguage value in AppLanguage.values)
            ClassicOption<AppLanguage>(value: value, label: value.label(l10n)),
        ],
        // Applies immediately: only MaterialApp.locale changes, so the current
        // route, the running study session, the scroll positions and every
        // other setting survive the switch.
        onChanged: (AppLanguage value) async {
          await ref.read(languageProvider.notifier).select(value);
        },
      ),
    );
  }
}
