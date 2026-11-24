import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../../shared/widgets/common.dart';
import '../backup/backup_page.dart';

/// Settings: daily targets, study mode, theme, active book, data tools.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StudySettingsRow> settingsAsync = ref.watch(
      settingsProvider,
    );
    final AsyncValue<List<WordBookSummary>> books = ref.watch(
      bookSummariesProvider,
    );
    final ThemeData theme = Theme.of(context);
    final StudySettingsRow? settings = settingsAsync.value;

    if (settings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    Future<void> save({
      int? newTarget,
      int? reviewLimit,
      Value<String?>? bookValue,
      StudyMode? mode,
      ThemePreference? theme,
    }) async {
      await ref
          .read(settingsRepositoryProvider)
          .save(
            dailyNewTarget: newTarget,
            dailyReviewLimit: reviewLimit,
            currentWordBookId: bookValue,
            studyMode: mode,
            theme: theme,
          );
      ref.invalidate(todayProgressProvider);
      ref.invalidate(statisticsProvider);
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimens.gutter),
      children: <Widget>[
        ContentWidth(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionCard(
                title: '每日目标',
                child: Column(
                  children: <Widget>[
                    _NumberSetting(
                      label: '每日新词',
                      value: settings.dailyNewTarget,
                      min: 5,
                      max: 200,
                      onChanged: (int value) => save(newTarget: value),
                    ),
                    const Divider(height: 24),
                    _NumberSetting(
                      label: '每日复习上限',
                      value: settings.dailyReviewLimit,
                      min: 10,
                      max: 500,
                      onChanged: (int value) => save(reviewLimit: value),
                    ),
                    AppSpacing.h8,
                    Text(
                      '未完成的复习不会丢失：超出每日上限的到期单词会显示为“积压”，第二天继续。',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AppSpacing.h16,
              SectionCard(
                title: '学习',
                child: Column(
                  children: <Widget>[
                    DropdownButtonFormField<String?>(
                      initialValue: settings.currentWordBookId,
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
                          save(bookValue: Value<String?>(value)),
                    ),
                    AppSpacing.h16,
                    DropdownButtonFormField<String>(
                      initialValue: settings.studyMode,
                      decoration: const InputDecoration(labelText: '学习模式'),
                      items: <DropdownMenuItem<String>>[
                        for (final StudyMode mode in StudyMode.values)
                          DropdownMenuItem<String>(
                            value: mode.code,
                            child: Text(mode.label),
                          ),
                      ],
                      onChanged: (String? value) => save(
                        mode: value == null ? null : StudyMode.fromCode(value),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.h16,
              SectionCard(
                title: '外观',
                child: Column(
                  children: <Widget>[
                    for (final ThemePreference preference
                        in ThemePreference.values)
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: preference.code,
                        groupValue: settings.themeMode,
                        onChanged: (String? value) =>
                            save(theme: ThemePreference.fromCode(value)),
                        title: Text(preference.label),
                      ),
                    AppSpacing.h4,
                    Text(
                      '经典 Material Design 2 主题：56dp 顶栏、低圆角、传统阴影、InkSplash 水波纹。',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AppSpacing.h16,
              SectionCard(
                title: '数据',
                child: Column(
                  children: <Widget>[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.backup_outlined),
                      title: const Text('备份、恢复与同步'),
                      subtitle: const Text('导出 JSON，导入时合并而不是覆盖'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) => const BackupPage(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: theme.dividerColor),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.memory_outlined),
                      title: const Text('设备 ID'),
                      subtitle: FutureBuilder<String>(
                        future: ref.read(settingsRepositoryProvider).deviceId(),
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<String> snapshot,
                            ) => Text(
                              snapshot.data ?? '读取中…',
                              style: theme.textTheme.bodySmall,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.h16,
              SectionCard(
                title: '关于',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'MaterialWord 1.0.0（Phase 1）',
                      style: theme.textTheme.bodyMedium,
                    ),
                    AppSpacing.h8,
                    Text(
                      '离线优先的英语单词学习工具。内置词典来自 ECDICT（MIT 许可），'
                      '学习记录全部保存在本机 SQLite 数据库中。',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AppSpacing.h32,
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text('$value', style: theme.textTheme.titleMedium),
            AppSpacing.w8,
            IconButton(
              tooltip: '减少',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > min
                  ? () => onChanged((value - stepFor(value)).clamp(min, max))
                  : null,
            ),
            IconButton(
              tooltip: '增加',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: value < max
                  ? () => onChanged((value + stepFor(value)).clamp(min, max))
                  : null,
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ 5,
          label: '$value',
          onChanged: (double v) => onChanged((v / 5).round() * 5),
        ),
      ],
    );
  }

  int stepFor(int value) => value >= 100 ? 10 : 5;
}
