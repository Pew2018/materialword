import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models/enums.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/l10n.dart';
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
                    label: context.l10n.allWordLists,
                    value: filter ?? '',
                    options: <ClassicOption<String>>[
                      ClassicOption<String>(
                        value: '',
                        label: context.l10n.allWordLists,
                      ),
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
                message: context.l10n.statsLoadFailed,
                onRetry: () => ref.invalidate(statisticsProvider),
              ),
            ),
          if (data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            SectionHeader(title: context.l10n.statsOverview),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: StatBlock(
                          value: '${data.totalWords}',
                          label: context.l10n.totalWordsLabel,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.learnedWords}',
                          label: context.l10n.learnedLabel,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.unlearnedWords}',
                          label: context.l10n.unlearnedLabel,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: data.accuracyOrNull == null
                              ? '—'
                              : '${(data.accuracyOrNull! * 100).round()}%',
                          label: data.accuracyOrNull == null
                              ? context.l10n.accuracyLabel
                              : context.l10n.overallAccuracy,
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
            SectionHeader(title: context.l10n.todayStudy),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: StatBlock(
                          value: '${data.todayNew}',
                          label: context.l10n.todayNewWords,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.todayReview}',
                          label: context.l10n.todayReviews,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.todayAnswers}',
                          label: context.l10n.answersCount,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: data.todayAnswers == 0
                              ? '—'
                              : '${(data.todayCorrect / data.todayAnswers * 100).round()}%',
                          label: context.l10n.accuracyLabel,
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
                          label: context.l10n.cumulativeCorrect,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.wrongCount}',
                          label: context.l10n.cumulativeWrong,
                          color: data.wrongCount > 0 ? AppColors.unknown : null,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.hazyCount}',
                          label: context.l10n.cumulativeHazy,
                          color: AppColors.hazy,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.distinctAnsweredWords}',
                          label: context.l10n.distinctAnsweredWords,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SectionHeader(title: context.l10n.answerBreakdown),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _LineRow(
                        label: context.l10n.breakdownStudyReview,
                        value: context.l10n.valueTimes(data.breakdown.normal),
                      ),
                      _LineRow(
                        label: context.l10n.breakdownSpecial,
                        value: context.l10n.valueTimes(data.breakdown.special),
                      ),
                      _LineRow(
                        label: context.l10n.breakdownPractice,
                        value: context.l10n.valueTimes(data.breakdown.practice),
                      ),
                      for (final PracticeKind kind in PracticeKind.values)
                        if ((data.breakdown.practiceByKind[kind] ?? 0) > 0)
                          _LineRow(
                            label: '• ${kind.label(context.l10n)}',
                            value: context.l10n.valueTimes(
                              data.breakdown.practiceByKind[kind]!,
                            ),
                            indent: 16,
                          ),
                      _LineRow(
                        label: context.l10n.breakdownRepeat,
                        value: context.l10n.valueTimes(data.breakdown.repeat),
                      ),
                      _LineRow(
                        label: context.l10n.distinctWordsAnswered,
                        value: context.l10n.wordCountPlural(
                          data.distinctAnsweredWords,
                        ),
                      ),
                      _LineRow(
                        label: context.l10n.undoneAnswers,
                        value: context.l10n.valueTimes(data.undoneAnswers),
                      ),
                      AppSpacing.h8,
                      Text(
                        context.l10n.breakdownNote,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SectionHeader(title: context.l10n.answersLast7Days),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _TrendChart(points: data.trend7),
                ),
              ],
            ),
            SectionHeader(title: context.l10n.reviewsNext7Days),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final DueForecastDay day in data.dueForecast)
                        _LineRow(label: day.day, value: '${day.count}'),
                      if (data.dueForecast.isEmpty)
                        Text(
                          context.l10n.noScheduledReviews,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if ((books.value ?? const <WordBookSummary>[])
                .isNotEmpty) ...<Widget>[
              SectionHeader(title: context.l10n.wordListProgress),
              SettingsGroup(
                children: <Widget>[
                  for (final WordBookSummary book
                      in (books.value ?? const <WordBookSummary>[]).take(20))
                    SettingsTile(
                      title: book.book.name,
                      subtitle: context.l10n.wordListRowStats(
                        book.wordCount,
                        book.learnedCount,
                        book.dueCount,
                      ),
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
            SectionHeader(title: context.l10n.wordPerformance),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: StatBlock(
                          value: data.lastStudyDay ?? '—',
                          label: context.l10n.lastStudiedDay,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${data.undoneAnswers}',
                          label: context.l10n.undoneAnswers,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    context.l10n.noAnswersYet,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (data.hardWords.isNotEmpty) ...<Widget>[
              SectionHeader(title: context.l10n.difficultWords),
              SettingsGroup(
                children: <Widget>[
                  for (final WordWithState row in data.hardWords)
                    SettingsTile(
                      title: row.word.word,
                      subtitle: row.word.translation.replaceAll('\n', ' '),
                      trailing: Text(
                        context.l10n.wordErrorHazyStat(
                          row.state?.wrongCount ?? 0,
                          row.state?.hazyCount ?? 0,
                        ),
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
  const _LineRow({required this.label, required this.value, this.indent = 0});

  final String label;
  final String value;

  /// Real layout indent in logical pixels for child rows (e.g. one practice
  /// mode under Practice). Indent only — same type scale as the parent row.
  final double indent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // One bodyMedium style for every row and both sides. Child rows keep an
    // indent but never drop to bodySmall.
    final TextStyle? style = theme.textTheme.bodyMedium;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: style)),
            Text(
              value,
              style: style?.copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
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
      return Text(
        context.l10n.noAnswersLast7Days,
        style: theme.textTheme.bodySmall,
      );
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
