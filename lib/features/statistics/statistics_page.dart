import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models/study_models.dart';
import '../../core/repositories/word_repository.dart';
import '../../core/repositories/wordbook_repository.dart';
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

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.filter_alt_outlined,
                size: AppDimens.iconSizeSmall,
              ),
              AppSpacing.w8,
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    isDense: true,
                    value: filter,
                    hint: const Text('全部词书'),
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
                    onChanged: (String? value) => ref
                        .read(statisticsBookFilterProvider.notifier)
                        .select(value),
                  ),
                ),
              ),
            ],
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
                  ],
                ),
              ),
            ],
          ),
          SectionHeader(title: '字词表现'),
          SettingsGroup(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: StatBlock(
                            value: '${data.hardWords.length}',
                            label: '困难词（错误/模糊≥1）',
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
                            value: data.lastStudyDay ?? '—',
                            label: '最近学习日',
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h8,
                    Text(
                      data.hasAnswers
                          ? '正确率 = 认识 /（认识 + 模糊 + 不认识）次作答，口径为累计作答记录。'
                          : '还没有作答记录，因此没有正确率。完成一次学习后这里会显示真实比例。',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
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
    );
  }
}
