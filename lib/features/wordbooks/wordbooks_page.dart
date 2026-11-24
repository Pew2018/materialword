import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../../services/import_service.dart';
import '../../shared/widgets/common.dart';
import '../word_management/import_page.dart';
import '../word_management/word_management_page.dart';
import 'word_book_detail_page.dart';

/// All wordbooks with real progress numbers, as a compact classic list.
class WordBooksPage extends ConsumerWidget {
  const WordBooksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WordBookSummary>> books = ref.watch(
      bookSummariesProvider,
    );
    final ThemeData theme = Theme.of(context);
    final String? currentBookId = ref
        .watch(settingsProvider)
        .value
        ?.currentWordBookId;

    Future<void> createBook() async {
      final String? name = await promptForText(
        context,
        title: '新建词书',
        label: '词书名称',
      );
      if (name == null || name.trim().isEmpty) return;
      await ref
          .read(wordBookRepositoryProvider)
          .create(name: name, now: ref.read(clockProvider).now());
      ref.invalidate(bookSummariesProvider);
    }

    Future<void> openImport() async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const ImportPage(),
        ),
      );
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(todayProgressProvider);
    }

    Future<void> refreshOnline(WordBookSummary summary) async {
      final String url = summary.book.sourceUrl;
      if (url.isEmpty) return;
      try {
        final ImportPreview preview = await ref
            .read(importServiceProvider)
            .fetchUrl(url);
        if (!context.mounted) return;
        final bool? ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('刷新在线词书'),
            content: Text(
              '来源：$url\n\n'
              '本次解析到 ${preview.validCount} 个单词'
              '${preview.duplicateCount > 0 ? '（文件内重复 ${preview.duplicateCount} 个）' : ''}。\n\n'
              '刷新只会新增缺失的单词：不会删除本地词条、不会覆盖个人笔记、'
              '不会重置任何学习进度。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('预览并合并'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        final ImportOutcome outcome = await ref
            .read(importServiceProvider)
            .commit(
              preview: preview,
              bookId: summary.book.id,
              now: ref.read(clockProvider).now(),
            );
        ref.invalidate(bookSummariesProvider);
        ref.invalidate(todayProgressProvider);
        if (!context.mounted) return;
        showMessage(context, '在线词书刷新完成：${outcome.summary}');
      } catch (e) {
        if (!context.mounted) return;
        showMessage(context, '刷新失败：$e', error: true);
      }
    }

    Future<void> openManagement() async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const WordManagementPage(),
        ),
      );
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(todayProgressProvider);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          child: Row(
            children: <Widget>[
              Expanded(child: Text('我的词书', style: theme.textTheme.titleLarge)),
              TextButton.icon(
                onPressed: openManagement,
                icon: const Icon(
                  Icons.table_rows_outlined,
                  size: AppDimens.iconSizeSmall,
                ),
                label: const Text('全部词汇'),
              ),
              IconButton(
                tooltip: '导入词表',
                icon: const Icon(Icons.file_upload_outlined),
                onPressed: openImport,
              ),
              IconButton(
                tooltip: '新建词书',
                icon: const Icon(Icons.add),
                onPressed: createBook,
              ),
            ],
          ),
        ),
        if (books.hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ErrorBanner(
              message: '读取词书失败：${books.error}',
              onRetry: () => ref.invalidate(bookSummariesProvider),
            ),
          ),
        if ((books.value ?? const <WordBookSummary>[]).isEmpty)
          EmptyState(
            icon: Icons.library_books_outlined,
            title: '还没有词书',
            message: '创建一个词书，然后导入你的单词表（每行一个单词即可）。',
            action: Wrap(
              spacing: 8,
              children: <Widget>[
                ElevatedButton(
                  onPressed: createBook,
                  child: const Text('新建词书'),
                ),
                OutlinedButton(
                  onPressed: openImport,
                  child: const Text('导入词表'),
                ),
              ],
            ),
          )
        else
          SettingsGroup(
            children: <Widget>[
              for (final WordBookSummary summary in books.value!)
                _BookRow(
                  summary: summary,
                  isCurrent: summary.book.id == currentBookId,
                  onOpen: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            WordBookDetailPage(bookId: summary.book.id),
                      ),
                    );
                    ref.invalidate(bookSummariesProvider);
                    ref.invalidate(todayProgressProvider);
                  },
                  onSetCurrent: () async {
                    await ref
                        .read(settingsRepositoryProvider)
                        .save(
                          currentWordBookId: Value<String?>(summary.book.id),
                        );
                    ref.invalidate(todayProgressProvider);
                  },
                  onImport: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            ImportPage(initialBookId: summary.book.id),
                      ),
                    );
                    ref.invalidate(bookSummariesProvider);
                  },
                  onRename: () async {
                    final String? name = await promptForText(
                      context,
                      title: '重命名词书',
                      label: '词书名称',
                      initialValue: summary.book.name,
                    );
                    if (name == null || name.trim().isEmpty) return;
                    await ref
                        .read(wordBookRepositoryProvider)
                        .rename(
                          summary.book.id,
                          name,
                          now: ref.read(clockProvider).now(),
                        );
                    ref.invalidate(bookSummariesProvider);
                  },
                  onRefreshOnline: summary.book.sourceUrl.isEmpty
                      ? null
                      : () => refreshOnline(summary),
                  onDelete: () async {
                    final bool ok = await confirmDialog(
                      context,
                      title: '删除词书',
                      message:
                          '删除「${summary.book.name}」？单词本身和学习记录会保留，只移除词书及其关联。',
                      confirmLabel: '删除',
                      destructive: true,
                    );
                    if (!ok) return;
                    await ref
                        .read(wordBookRepositoryProvider)
                        .softDelete(
                          summary.book.id,
                          now: ref.read(clockProvider).now(),
                        );
                    ref.invalidate(bookSummariesProvider);
                    ref.invalidate(todayProgressProvider);
                  },
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '「全部词汇」可以按词书、学习状态、困难程度筛选，并批量加入词书 / 移出 / 删除。',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.summary,
    required this.isCurrent,
    required this.onOpen,
    required this.onSetCurrent,
    required this.onImport,
    required this.onRename,
    required this.onDelete,
    this.onRefreshOnline,
  });

  final WordBookSummary summary;
  final bool isCurrent;
  final VoidCallback onOpen;
  final VoidCallback onSetCurrent;
  final VoidCallback onImport;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onRefreshOnline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          summary.book.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (isCurrent) ...<Widget>[
                        AppSpacing.w8,
                        const TagChip(label: '当前', dense: true),
                      ],
                    ],
                  ),
                ),
                if (!isCurrent)
                  TextButton(
                    onPressed: onSetCurrent,
                    child: const Text('设为当前'),
                  ),
                PopupMenuButton<String>(
                  tooltip: '更多',
                  onSelected: (String value) {
                    switch (value) {
                      case 'rename':
                        onRename();
                      case 'import':
                        onImport();
                      case 'refresh':
                        onRefreshOnline?.call();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'rename',
                          child: Text('重命名'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'import',
                          child: Text('导入到该词书'),
                        ),
                        if (onRefreshOnline != null)
                          const PopupMenuItem<String>(
                            value: 'refresh',
                            child: Text('刷新在线词书'),
                          ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('删除词书'),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${summary.wordCount} 词 · 已学 ${summary.learnedCount} · 到期 ${summary.dueCount}',
              style: theme.textTheme.bodySmall,
            ),
            if (summary.book.description.isNotEmpty)
              Text(
                summary.book.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: summary.progress,
                  minHeight: 3,
                  backgroundColor: theme.dividerColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
