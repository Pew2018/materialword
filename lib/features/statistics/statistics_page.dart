import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models/study_models.dart';
import '../../core/repositories/word_repository.dart';
import '../../shared/widgets/common.dart';
import '../word_management/word_detail_page.dart';

/// Simple statistics: counts, accuracy and the words that keep failing.
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StudyStatistics> stats = ref.watch(statisticsProvider);
    final ThemeData theme = Theme.of(context);
    final StudyStatistics? data = stats.value;

    if (stats.hasError) {
      return ErrorBanner(
        message: '读取统计失败：${stats.error}',
        onRetry: () => ref.invalidate(statisticsProvider),
      );
    }
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimens.gutter),
      children: <Widget>[
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionCard(
                title: '总览',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
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
                            value: '${data.totalWords}',
                            label: '总词数',
                          ),
                        ),
                        Expanded(
                          child: StatBlock(
                            value: '${(data.accuracy * 100).round()}%',
                            label: '历史正确率',
                            color: data.accuracy >= 0.8
                                ? AppColors.known
                                : AppColors.hazy,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
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
                            color: AppColors.unknown,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: StatBlock(
                            value: data.lastStudyDay ?? '—',
                            label: '最近学习日期',
                          ),
                        ),
                        Expanded(
                          child: StatBlock(
                            value: '${data.totalAnswers}',
                            label: '累计作答',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.h16,
              SectionCard(
                title: '困难词（错误 / 模糊次数最多）',
                child: data.hardWords.isEmpty
                    ? Text('暂时没有困难词。', style: theme.textTheme.bodySmall)
                    : Column(
                        children: <Widget>[
                          for (final WordWithState row in data.hardWords)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(row.word.word),
                              subtitle: Text(
                                row.word.translation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    '错 ${row.state?.wrongCount ?? 0} · 模糊 ${row.state?.hazyCount ?? 0}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: AppDimens.iconSizeSmall,
                                  ),
                                ],
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
              ),
              AppSpacing.h16,
              Text(
                '正确率 = 认识 /（认识 + 模糊 + 不认识）次作答。'
                '统计口径包含所有词书的单词，只统计已保存到本地的真实作答记录。',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
