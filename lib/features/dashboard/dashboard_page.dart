import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_models.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../../services/import_service.dart';
import '../../shared/widgets/common.dart';
import '../backup/backup_page.dart';
import '../study/study_page.dart';
import '../word_management/import_page.dart';
import '../word_management/quick_add_page.dart';

/// "Today" screen: everything needed to start learning, all from the database.
///
/// Every number here is derived from real rows — the previous version could
/// announce "30 new words left" on an empty library because it only subtracted
/// finished cards from the goal.
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
    final resume = ref.watch(pausedSessionProvider).value;
    final canResume =
        resume != null &&
        (resume.bookId == null ||
            (books.value?.any((b) => b.book.id == resume.bookId) ?? false));
    final TodayProgress? today = progress.value;
    final ThemeData theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayProgressProvider);
        ref.invalidate(bookSummariesProvider);
        await ref.read(todayProgressProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          if (progress.hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ErrorBanner(
                message: '读取学习进度失败：${progress.error}',
                onRetry: () => ref.invalidate(todayProgressProvider),
              ),
            ),
          _BookSelector(
            books: books.value ?? const <WordBookSummary>[],
            currentBookId: settings.value?.currentWordBookId,
            onChanged: (String? id) async {
              await ref
                  .read(settingsRepositoryProvider)
                  .save(currentWordBookId: Value<String?>(id));
              ref.invalidate(todayProgressProvider);
            },
            onManage: onOpenBookTab,
          ),
          if (canResume)
            SettingsTile(
              leading: const Icon(Icons.play_circle_outline),
              title: '继续学习',
              subtitle: '已完成 ${resume.position} / ${resume.total} 项',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => StudyPage(
                    reviewOnly: resume.mode == StudyMode.reviewOnly,
                    special: resume.special,
                    bookIdOverride: resume.bookId,
                    useGlobalScope: resume.bookId == null,
                  ),
                ),
              ),
            ),
          if (today == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (today.totalWords == 0) ...<Widget>[
            SectionHeader(
              title: '今日任务',
              trailing: Text(
                today.scopedToBook ? '范围：当前词书' : '范围：全部词书',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const _FirstRunPanel(),
          ] else ...<Widget>[
            SectionHeader(
              title: '今日任务',
              trailing: Text(
                today.scopedToBook ? '范围：当前词书' : '范围：全部词书',
                style: theme.textTheme.bodySmall,
              ),
            ),
            _TodayPanel(progress: today),
            SectionHeader(title: '开始学习'),
            _StartActions(progress: today),
            if (today.backlog > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '${today.backlog} 个到期单词超出今日复习上限，会顺延到明天，不会丢失。',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            SectionHeader(title: '快捷操作'),
            SettingsGroup(
              children: <Widget>[
                SettingsTile(
                  leading: const Icon(Icons.add),
                  title: '快速添加单词',
                  subtitle: '输入即查离线词典，⌘N / Ctrl+N',
                  onTap: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const QuickAddPage(),
                      ),
                    );
                    ref.invalidate(todayProgressProvider);
                    ref.invalidate(bookSummariesProvider);
                  },
                ),
                SettingsTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: '导入词书',
                  subtitle: 'TXT / CSV / JSON，支持 HTTPS 链接',
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
                SettingsTile(
                  leading: const Icon(Icons.sync_outlined),
                  title: '同步与备份',
                  subtitle: '导出 / 合并 JSON，跨设备同步',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const BackupPage(),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.menu_book,
            size: AppDimens.iconSizeSmall,
            color: theme.colorScheme.primary,
          ),
          AppSpacing.w8,
          Text('当前学习词书', style: theme.textTheme.bodySmall),
          AppSpacing.w8,
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                isDense: true,
                value: bookMissing ? null : currentBookId,
                hint: Text('全部词书', style: theme.textTheme.bodyLarge),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
          TextButton(onPressed: onManage, child: const Text('词书')),
        ],
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.progress});

  final TodayProgress progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ProgressRow(
              label: '新词',
              done: progress.newDone,
              total: progress.newGoal,
              color: theme.colorScheme.primary,
              hint: progress.unlearnedTotal == 0
                  ? '当前范围内已没有未学习的单词'
                  : '剩余额度 ${progress.newRemainingAllowance}，未学习单词 ${progress.unlearnedTotal}',
            ),
            AppSpacing.h12,
            ProgressRow(
              label: '复习',
              done: progress.reviewDone,
              total: progress.reviewGoal,
              color: AppColors.hazy,
              hint: progress.dueTotal == 0
                  ? '当前没有到期单词'
                  : '到期 ${progress.dueTotal}，剩余额度 ${progress.reviewRemainingAllowance}',
            ),
            const Divider(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: StatBlock(
                    value: '${progress.newAvailableToday}',
                    label: '今日可学新词',
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    value: '${progress.reviewAvailableToday}',
                    label: '今日可复习',
                    color: progress.reviewAvailableToday > 0
                        ? AppColors.hazy
                        : null,
                  ),
                ),
                Expanded(
                  child: StatBlock(value: '${progress.backlog}', label: '积压复习'),
                ),
                Expanded(
                  child: StatBlock(
                    value: '${progress.hardWords}',
                    label: '困难词',
                    color: progress.hardWords > 0 ? AppColors.unknown : null,
                  ),
                ),
              ],
            ),
            AppSpacing.h8,
            Text(
              '已学 ${progress.learnedWords} / ${progress.totalWords}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StartActions extends ConsumerWidget {
  const _StartActions({required this.progress});

  final TodayProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    if (!progress.hasWork) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.done_all,
              size: AppDimens.iconSizeSmall,
              color: AppColors.known,
            ),
            AppSpacing.w8,
            Expanded(
              child: Text(
                '今天的任务已完成，没有可开始的学习队列。可以调整每日目标、导入新词，或稍后回来复习。',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    Future<void> open({
      SpecialReview special = SpecialReview.none,
      bool reviewOnly = false,
    }) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              StudyPage(reviewOnly: reviewOnly, special: special),
        ),
      );
      ref.invalidate(todayProgressProvider);
      ref.invalidate(statisticsProvider);
      ref.invalidate(bookSummariesProvider);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          ElevatedButton.icon(
            onPressed: progress.canStartNew || progress.canStartReview
                ? () => open()
                : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              '开始学习（新 ${progress.newAvailableToday} · 复习 ${progress.reviewAvailableToday}）',
            ),
          ),
          OutlinedButton.icon(
            onPressed: progress.canStartReview
                ? () => open(reviewOnly: true)
                : null,
            icon: const Icon(Icons.replay),
            label: Text('只做复习（${progress.reviewAvailableToday}）'),
          ),
          if (progress.hardWords > 0)
            TextButton.icon(
              onPressed: () => open(special: SpecialReview.hard),
              icon: const Icon(Icons.local_fire_department_outlined),
              label: Text('困难词专项（${progress.hardWords}）'),
            ),
          TextButton.icon(
            onPressed: () => open(special: SpecialReview.recentMistakes),
            icon: const Icon(Icons.error_outline),
            label: const Text('近期错误专项'),
          ),
        ],
      ),
    );
  }
}

class _FirstRunPanel extends ConsumerWidget {
  const _FirstRunPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('还没有单词', style: theme.textTheme.titleLarge),
          AppSpacing.h8,
          Text(
            '导入你自己的单词表（每行一个单词即可），或先载入一份示例词书熟悉学习流程。'
            '也可以直接点右下角「+」手动添加。',
            style: theme.textTheme.bodyMedium,
          ),
          AppSpacing.h16,
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
            ],
          ),
        ],
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
