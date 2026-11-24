import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../../shared/widgets/common.dart';
import '../word_management/import_page.dart';
import 'word_book_detail_page.dart';

/// All wordbooks with real progress numbers.
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

    return ListView(
      padding: const EdgeInsets.all(AppDimens.gutter),
      children: <Widget>[
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('我的词书', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: createBook,
                    icon: const Icon(Icons.add),
                    label: const Text('新建词书'),
                  ),
                ],
              ),
              AppSpacing.h16,
              if (books.hasError)
                ErrorBanner(
                  message: '读取词书失败：${books.error}',
                  onRetry: () => ref.invalidate(bookSummariesProvider),
                ),
              if ((books.value ?? const <WordBookSummary>[]).isEmpty)
                EmptyState(
                  icon: Icons.library_books_outlined,
                  title: '还没有词书',
                  message: '创建一个词书，然后导入六级单词表。',
                  action: Wrap(
                    spacing: 12,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: createBook,
                        child: const Text('新建词书'),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const ImportPage(),
                          ),
                        ),
                        child: const Text('导入词表'),
                      ),
                    ],
                  ),
                )
              else
                for (final WordBookSummary summary in books.value!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BookCard(
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
                              currentWordBookId: Value<String?>(
                                summary.book.id,
                              ),
                            );
                        ref.invalidate(todayProgressProvider);
                        ref.invalidate(statisticsProvider);
                      },
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookCard extends ConsumerWidget {
  const _BookCard({
    required this.summary,
    required this.isCurrent,
    required this.onOpen,
    required this.onSetCurrent,
  });

  final WordBookSummary summary;
  final bool isCurrent;
  final VoidCallback onOpen;
  final VoidCallback onSetCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
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
                    onSelected: (String value) async {
                      if (value == 'rename') {
                        final String? name = await promptForText(
                          context,
                          title: '重命名词书',
                          label: '词书名称',
                          initialValue: summary.book.name,
                        );
                        if (name != null && name.trim().isNotEmpty) {
                          await ref
                              .read(wordBookRepositoryProvider)
                              .rename(
                                summary.book.id,
                                name,
                                now: ref.read(clockProvider).now(),
                              );
                          ref.invalidate(bookSummariesProvider);
                        }
                      } else if (value == 'import') {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                ImportPage(initialBookId: summary.book.id),
                          ),
                        );
                        ref.invalidate(bookSummariesProvider);
                      } else if (value == 'delete') {
                        final bool ok = await confirmDialog(
                          context,
                          title: '删除词书',
                          message:
                              '删除「${summary.book.name}」？单词本身和学习记录会保留，只会移除词书及其关联。',
                          confirmLabel: '删除',
                          destructive: true,
                        );
                        if (ok) {
                          await ref
                              .read(wordBookRepositoryProvider)
                              .softDelete(
                                summary.book.id,
                                now: ref.read(clockProvider).now(),
                              );
                          ref.invalidate(bookSummariesProvider);
                          ref.invalidate(todayProgressProvider);
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'rename',
                            child: Text('重命名'),
                          ),
                          PopupMenuItem<String>(
                            value: 'import',
                            child: Text('导入到该词书'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('删除词书'),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.wordCount} 词 · 已学 ${summary.learnedCount} · 到期 ${summary.dueCount}'
                '${summary.book.description.isEmpty ? '' : ' · ${summary.book.description}'}',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: summary.progress,
                  minHeight: 4,
                  backgroundColor: theme.dividerColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
