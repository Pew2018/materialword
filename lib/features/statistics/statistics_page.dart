import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_models.dart';
import '../../core/repositories/word_repository.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../../shared/widgets/classic_select.dart';
import '../../shared/widgets/common.dart';
import '../word_management/word_detail_page.dart';

/// Statistics with an explicit scope filter.
///
/// Content numbers (total / learned / hard words) follow the selected book;
/// "today" counts are device-wide because the daily goal is device-wide. The
/// header says so, so the two numbers can never be mistaken for each other.
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StudyStatistics> stats = ref.watch(statisticsProvider);
    final AsyncValue<List<WordBookSummary>> books = ref.watch(
      bookSummariesProvider,
    );
    final String? selected = ref.watch(statisticsBookFilterProvider);
    final bool invalid =
        selected != null &&
        books.hasValue &&
        !books.value!.any((b) => b.book.id == selected);
    final String? filter = invalid ? null : selected;
    if (invalid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(statisticsBookFilterProvider.notifier).select(null);
        }
      });
    }
    final ThemeData theme = Theme.of(context);
    final StudyStatistics? data = stats.value;

    return ContentColumn(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          Material(
            color: theme.cardColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.filter_alt_outlined,
                    size: AppDimens.iconSizeSmall,
                  ),
                  AppSpacing.w8,
                  ClassicSelectChip<String>(
                    label: '全部词书',
                    value: filter ?? '',
                    options: <ClassicOption<String>>[
                      const ClassicOption<String>(value: '', label: '全部词书'),
                      for (final WordBookSummary summary
                          in books.value ?? const <WordBookSummary>[])
                        ClassicOption<String>(
                          value: summary.book.id,
                          label: summary.book.name,
                        ),
                    ],
                    onChanged: (String value) => ref
                        .read(statisticsBookFilterProvider.notifier)
                        .select(value.isEmpty ? null : value),
                  ),
                ],
              ),
            ),
          ),
          if (stats.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ErrorBanner(
                message: '读取统计失败：${stats.error}',
                onRetry: () => ref.invalidate(statisticsProvider),
              ),
            ),
          if (data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            SectionHeader(title: data.scopedToBook ? '总览（当前词书）' : '总览（全部词书）'),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: StatBlock(
                          value: '${data.totalWords}',
                          label: '总词数',
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.learnedWords}',
                          label: '已学习',
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.unlearnedWords}',
                          label: '未学习',
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: data.accuracyOrNull == null
                              ? '—'
                              : '${(data.accuracyOrNull! * 100).round()}%',
                          label: data.accuracyOrNull == null
                              ? '正确率（无记录）'
                              : '历史正确率',
                          color: data.accuracyOrNull == null
                              ? null
                              : (data.accuracyOrNull! >= 0.8
                                    ? AppColors.known
                                    : AppColors.hazy),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SectionHeader(title: '今日（全设备）'),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: StatBlock(
                          value: '${data.todayNew}',
                          label: '今日新词',
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.todayReview}',
                          label: '今日复习',
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.todayAnswers}',
                          label: '今日实际作答',
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: data.todayAnswers == 0
                              ? '—'
                              : '${(data.todayCorrect / data.todayAnswers * 100).round()}%',
                          label: data.todayAnswers == 0 ? '正确率（无记录）' : '今日正确率',
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: StatBlock(
                          value: '${data.correctCount}',
                          label: '累计正确',
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.wrongCount}',
                          label: '累计错误',
                          color: data.wrongCount > 0 ? AppColors.unknown : null,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.hazyCount}',
                          label: '累计模糊',
                          color: AppColors.hazy,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.distinctAnsweredWords}',
                          label: '独立词条',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SectionHeader(title: '作答构成（累计）'),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _LineRow(
                        label: '普通学习/复习',
                        value: '${data.breakdown.normal} 次',
                      ),
                      _LineRow(
                        label: '专项复习（困难词、错词等）',
                        value: '${data.breakdown.special} 次',
                      ),
                      _LineRow(
                        label: '练习模式',
                        value: '${data.breakdown.practice} 次',
                      ),
                      for (final PracticeKind kind in PracticeKind.values)
                        if ((data.breakdown.practiceByKind[kind] ?? 0) > 0)
                          _LineRow(
                            label: '　· ${kind.label}',
                            value: '${data.breakdown.practiceByKind[kind]} 次',
                            subtle: true,
                          ),
                      _LineRow(
                        label: '同轮复练',
                        value: '${data.breakdown.repeat} 次',
                      ),
                      _LineRow(
                        label: '独立词条（有真实作答）',
                        value: '${data.distinctAnsweredWords} 个',
                      ),
                      _LineRow(
                        label: '已撤销作答（不计入统计）',
                        value: '${data.undoneAnswers} 次',
                      ),
                      AppSpacing.h8,
                      Text(
                        '练习模式真实计次，但不改变长期复习间隔；人工掌握/重置属于管理事件，不计入作答。',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SectionHeader(title: '近 7 天作答'),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _TrendChart(points: data.trend7),
                ),
              ],
            ),
            SectionHeader(title: '未来 7 天到期复习'),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final DueForecastDay day in data.dueForecast)
                        _LineRow(label: day.day, value: '${day.count} 个'),
                      if (data.dueForecast.isEmpty)
                        Text('没有计划中的到期复习。', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if ((books.value ?? const <WordBookSummary>[])
                .isNotEmpty) ...<Widget>[
              SectionHeader(title: '词书完成度'),
              SettingsGroup(
                children: <Widget>[
                  for (final WordBookSummary book
                      in (books.value ?? const <WordBookSummary>[]).take(20))
                    SettingsTile(
                      title: book.book.name,
                      subtitle:
                          '${book.wordCount} 词 · 已学 ${book.learnedCount} · 到期 ${book.dueCount}',
                      trailing: Text(
                        '${(book.progress * 100).round()}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onTap: () => ref
                          .read(statisticsBookFilterProvider.notifier)
                          .select(book.book.id),
                    ),
                ],
              ),
            ],
            SectionHeader(title: '字词表现'),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: StatBlock(
                          value: data.lastStudyDay ?? '—',
                          label: '最近学习日',
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.undoneAnswers}',
                          label: '已撤销作答',
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    data.hasAnswers
                        ? '正确率 = 认识次数 ÷ 全部作答次数（累计）。'
                        : '还没有作答记录，完成一次学习后这里会显示真实比例。',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (data.hardWords.isNotEmpty) ...<Widget>[
              SectionHeader(title: '困难词（错误次数最多）'),
              SettingsGroup(
                children: <Widget>[
                  for (final WordWithState row in data.hardWords)
                    SettingsTile(
                      title: row.word.word,
                      subtitle: row.word.translation.replaceAll('\n', ' '),
                      trailing: Text(
                        '错 ${row.state?.wrongCount ?? 0} · 模糊 ${row.state?.hazyCount ?? 0}',
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              WordDetailPage(wordId: row.word.id),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// "label ————— value" row used by the breakdown and forecast blocks.
class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.label,
    required this.value,
    this.subtle = false,
  });

  final String label;
  final String value;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: subtle
                  ? theme.textTheme.bodySmall
                  : theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seven daily bars. Deliberately a plain widget — no chart package, no
/// animation, and it scales to the available width.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<DailyAnswers> points;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (points.isEmpty) {
      return Text('最近 7 天还没有作答记录。', style: theme.textTheme.bodySmall);
    }
    final int max = points
        .map((DailyAnswers p) => p.answers)
        .fold<int>(0, (int a, int b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final DailyAnswers point in points)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('${point.answers}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Container(
                    height: max == 0 ? 2 : 6 + 54 * (point.answers / max),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    point.day.substring(5),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
