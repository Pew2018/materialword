import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/study_models.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../../services/import_service.dart';
import '../../shared/widgets/common.dart';
import '../backup/backup_page.dart';
import '../study/study_page.dart';
import '../word_management/import_page.dart';
import '../word_management/quick_add_page.dart';

/// "Today" screen: everything needed to start learning, all from the database.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, required this.onOpenBookTab});

  final VoidCallback onOpenBookTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TodayProgress> progress = ref.watch(todayProgressProvider);
    final AsyncValue<List<WordBookSummary>> books = ref.watch(
      bookSummariesProvider,
    );
    final AsyncValue<StudySettingsRow> settings = ref.watch(settingsProvider);
    final TodayProgress? today = progress.value;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayProgressProvider);
        await ref.read(todayProgressProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppDimens.gutter),
        children: <Widget>[
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (progress.hasError)
                  ErrorBanner(
                    message: '读取学习进度失败：${progress.error}',
                    onRetry: () => ref.invalidate(todayProgressProvider),
                  ),
                _BookSelector(
                  books: books.value ?? const <WordBookSummary>[],
                  currentBookId: settings.value?.currentWordBookId,
                  onChanged: (String? id) async {
                    await ref
                        .read(settingsRepositoryProvider)
                        .save(currentWordBookId: Value<String?>(id));
                    ref.invalidate(todayProgressProvider);
                    ref.invalidate(statisticsProvider);
                  },
                  onManage: onOpenBookTab,
                ),
                AppSpacing.h16,
                if (today == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...<Widget>[
                  _TodayCard(progress: today),
                  AppSpacing.h16,
                  if (today.totalWords == 0)
                    const _FirstRunCard()
                  else ...<Widget>[
                    _StartActions(progress: today),
                    AppSpacing.h16,
                    if (today.backlog > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '还有 ${today.backlog} 个到期单词超出今日复习上限，会顺延到明天，不会丢失。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const _ShortcutCard(),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookSelector extends StatelessWidget {
  const _BookSelector({
    required this.books,
    required this.currentBookId,
    required this.onChanged,
    required this.onManage,
  });

  final List<WordBookSummary> books;
  final String? currentBookId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool bookMissing =
        currentBookId != null &&
        !books.any((WordBookSummary b) => b.book.id == currentBookId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: <Widget>[
            const Icon(Icons.menu_book, size: AppDimens.iconSize),
            AppSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('当前学习词书', style: theme.textTheme.bodySmall),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: bookMissing ? null : currentBookId,
                      hint: const Text('全部词书'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('全部词书'),
                        ),
                        for (final WordBookSummary summary in books)
                          DropdownMenuItem<String?>(
                            value: summary.book.id,
                            child: Text(
                              '${summary.book.name}（${summary.wordCount} 词）',
                            ),
                          ),
                      ],
                      onChanged: onChanged,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onManage, child: const Text('管理')),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.progress});

  final TodayProgress progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      title: '今日任务',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ProgressRow(
            label: '新词',
            done: progress.newDone,
            total: progress.newTarget,
            color: theme.colorScheme.primary,
          ),
          AppSpacing.h16,
          ProgressRow(
            label: '复习',
            done: progress.reviewDone,
            total: progress.reviewLimit,
            color: AppColors.hazy,
          ),
          const Divider(height: 32),
          Row(
            children: <Widget>[
              Expanded(
                child: StatBlock(
                  value: '${progress.dueNow}',
                  label: '当前到期',
                  color: progress.dueNow > 0 ? AppColors.hazy : null,
                ),
              ),
              Expanded(
                child: StatBlock(
                  value: '${progress.newRemaining}',
                  label: '剩余新词',
                ),
              ),
              Expanded(
                child: StatBlock(
                  value: '${progress.hardWords}',
                  label: '困难词',
                  color: AppColors.unknown,
                ),
              ),
              Expanded(
                child: StatBlock(
                  value: '${progress.learnedWords}/${progress.totalWords}',
                  label: '已学/总数',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartActions extends ConsumerWidget {
  const _StartActions({required this.progress});

  final TodayProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canStudy = progress.newRemaining > 0 || progress.dueNow > 0;
    final bool canReview = progress.dueNow > 0 && progress.reviewRemaining > 0;

    Future<void> open({required bool reviewOnly}) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => StudyPage(reviewOnly: reviewOnly),
        ),
      );
      ref.invalidate(todayProgressProvider);
      ref.invalidate(statisticsProvider);
      ref.invalidate(bookSummariesProvider);
    }

    return Wrap(
      spacing: AppDimens.compactGutter,
      runSpacing: AppDimens.compactGutter,
      children: <Widget>[
        ElevatedButton.icon(
          onPressed: canStudy ? () => open(reviewOnly: false) : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(
            canStudy ? '开始学习（新词 ${progress.newRemaining}）' : '今日任务已完成',
          ),
        ),
        OutlinedButton.icon(
          onPressed: canReview ? () => open(reviewOnly: true) : null,
          icon: const Icon(Icons.replay),
          label: Text(
            canReview ? '只做复习（${progress.reviewRemaining}）' : '暂无到期复习',
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const QuickAddPage(),
              ),
            );
            ref.invalidate(todayProgressProvider);
            ref.invalidate(bookSummariesProvider);
          },
          icon: const Icon(Icons.add),
          label: const Text('快速添加单词'),
        ),
      ],
    );
  }
}

class _ShortcutCard extends ConsumerWidget {
  const _ShortcutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('导入词书'),
            subtitle: const Text('TXT / CSV / JSON，支持本机文件与 HTTPS 链接'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const ImportPage(),
                ),
              );
              ref.invalidate(todayProgressProvider);
              ref.invalidate(bookSummariesProvider);
            },
          ),
          Divider(height: 1, color: theme.dividerColor),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('备份与同步'),
            subtitle: const Text('导出 / 合并 JSON，跨设备手动同步'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const BackupPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstRunCard extends ConsumerWidget {
  const _FirstRunCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('还没有单词', style: theme.textTheme.titleMedium),
            AppSpacing.h8,
            Text(
              '导入你自己的六级单词表（每行一个单词即可），或先载入一份示例词书熟悉学习流程。',
              style: theme.textTheme.bodyMedium,
            ),
            AppSpacing.h16,
            Wrap(
              spacing: AppDimens.compactGutter,
              runSpacing: AppDimens.compactGutter,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const ImportPage(),
                      ),
                    );
                    ref.invalidate(todayProgressProvider);
                    ref.invalidate(bookSummariesProvider);
                  },
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('导入词表'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final String message = await loadSampleWordbook(ref);
                      if (context.mounted) showMessage(context, message);
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '载入失败：$e', error: true);
                      }
                    }
                    ref.invalidate(todayProgressProvider);
                    ref.invalidate(bookSummariesProvider);
                  },
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('载入示例词书'),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const QuickAddPage(),
                      ),
                    );
                    ref.invalidate(todayProgressProvider);
                    ref.invalidate(bookSummariesProvider);
                  },
                  child: const Text('手动添加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads the bundled demo word list (30 CET-6 words, from ECDICT, MIT) so a
/// brand-new install can try the learning loop immediately.
Future<String> loadSampleWordbook(WidgetRef ref) async {
  final ImportService service = ref.read(importServiceProvider);
  final String content = await rootBundle.loadString(
    'assets/wordbooks/sample_cet6.json',
  );
  final ImportPreview preview = service.parseContent(
    content,
    format: 'json',
    name: 'sample_cet6.json',
  );
  if (preview.entries.isEmpty) {
    throw const FormatException('示例词表为空');
  }
  final WordBook book = await ref
      .read(wordBookRepositoryProvider)
      .ensureBook(
        name: preview.detectedBookName,
        description: '示例词书：30 个 CET-6 单词（ECDICT，MIT 许可）',
        sourceType: 'sample',
        now: DateTime.now(),
      );
  final ImportOutcome outcome = await service.commit(
    preview: preview,
    bookId: book.id,
    now: DateTime.now(),
  );
  await ref
      .read(settingsRepositoryProvider)
      .save(currentWordBookId: Value<String?>(book.id));
  return '已载入「${book.name}」：${outcome.created} 个单词';
}
