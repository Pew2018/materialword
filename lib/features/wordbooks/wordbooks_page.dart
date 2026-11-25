import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../../services/import_service.dart';
import '../../services/wordbook_export.dart';
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
        final ImportService service = ref.read(importServiceProvider);
        final ImportPreview preview = await service.fetchUrl(url);
        final ImportPreviewStats stats = await service.analyze(
          preview,
          bookId: summary.book.id,
        );
        final Set<String> sourceKeys = <String>{
          for (final ParsedEntry entry in preview.entries) entry.key,
        };
        final List<Word> localWords = await ref
            .read(wordBookRepositoryProvider)
            .wordsInBook(summary.book.id);
        final int localOnly = localWords
            .where((Word word) => !sourceKeys.contains(word.normalized))
            .length;
        if (!context.mounted) return;
        final bool? ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('刷新在线词书'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <String>[
                  '来源：$url',
                  '',
                  '在线词书共 ${preview.validCount} 个词条。',
                  '· 本机已有：${stats.existingWords} 个',
                  '· 将新增：${stats.newWords} 个',
                  '· 文件内重复：${preview.duplicateCount} 个',
                  '· 无效词条：${preview.invalidCount} 个',
                  if (preview.droppedRows > 0)
                    '· 不会导入的行：${preview.droppedRows} 行',
                  if (stats.restorableWords > 0)
                    '· 你曾删除、本次不会自动恢复：${stats.restorableWords} 个',
                  '· 来源已移除、仍保留在本机：$localOnly 个',
                  '',
                  '刷新只新增缺失的单词：不删除本机词条、不恢复你主动删除的词条、'
                      '不覆盖个人笔记与自定义释义、不重置任何学习进度。'
                      '取消不会修改任何数据。',
                ].map((String line) => Text(line)).toList(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确认刷新'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        final ImportOutcome outcome = await service.commit(
          preview: preview,
          bookId: summary.book.id,
          sourceType: 'url',
          sourceUrl: url,
          allowRevive: false,
          now: ref.read(clockProvider).now(),
        );
        ref.invalidate(bookSummariesProvider);
        ref.invalidate(todayProgressProvider);
        if (!context.mounted) return;
        showMessage(context, '在线词书刷新完成：${outcome.summary}');
      } on ImportCancelledException {
        if (!context.mounted) return;
        showMessage(context, '已取消刷新，未修改任何数据');
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

    /// Export one book, the selected books, or every book. Book membership is
    /// preserved in JSON/CSV so re-importing does not create duplicates.
    Future<void> exportBooks(List<WordBookSummary> all) async {
      if (all.isEmpty) {
        showMessage(context, '还没有可导出的词书');
        return;
      }
      final Set<String> selected = <String>{
        for (final WordBookSummary summary in all) summary.book.id,
      };
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) => AlertDialog(
                title: const Text('导出词书内容'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final WordBookSummary summary in all)
                          CheckboxListTile(
                            dense: true,
                            value: selected.contains(summary.book.id),
                            onChanged: (bool? value) => setDialogState(() {
                              if (value == true) {
                                selected.add(summary.book.id);
                              } else {
                                selected.remove(summary.book.id);
                              }
                            }),
                            title: Text(summary.book.name),
                            subtitle: Text('${summary.wordCount} 个单词'),
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          '只导出词条内容：不含学习记录、笔记历史与同步凭据。'
                          '需要完整备份请到「设置 → 备份与恢复」。',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(true),
                    child: Text('导出 ${selected.length} 个词书'),
                  ),
                ],
              ),
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final WordBookExportFormat? format =
          await showDialog<WordBookExportFormat>(
            context: context,
            builder: (BuildContext context) => SimpleDialog(
              title: const Text('选择格式'),
              children: <Widget>[
                for (final WordBookExportFormat format
                    in WordBookExportFormat.values)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(context).pop(format),
                    child: Text(format.label),
                  ),
              ],
            ),
          );
      if (format == null || !context.mounted) return;
      try {
        final List<WordBookExport> exports = <WordBookExport>[];
        for (final WordBookSummary summary in all) {
          if (!selected.contains(summary.book.id)) continue;
          exports.add(
            WordBookExport(
              book: summary.book,
              words: await ref
                  .read(wordBookRepositoryProvider)
                  .wordsInBook(summary.book.id),
            ),
          );
        }
        final String body = exports.length == 1
            ? WordBookExporter.encodeBook(
                exports.first,
                format,
                exportedAt: ref.read(clockProvider).now(),
              )
            : WordBookExporter.encodeBooks(
                exports,
                format,
                exportedAt: ref.read(clockProvider).now(),
              );
        final String fileName = exports.length == 1
            ? '${exports.first.book.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.${format.extension}'
            : 'materialword-wordbooks-${exports.length}.${format.extension}';
        final Uri? saved = await FilePicker.saveFile(
          fileName: fileName,
          bytes: utf8.encode(body),
          mimeType: switch (format) {
            WordBookExportFormat.txt => 'text/plain',
            WordBookExportFormat.csv => 'text/csv',
            WordBookExportFormat.json => 'application/json',
          },
          dialogTitle: '导出词书内容',
        );
        if (!context.mounted) return;
        final int total = exports.fold<int>(
          0,
          (int sum, WordBookExport export) => sum + export.words.length,
        );
        showMessage(
          context,
          saved == null
              ? '已取消导出'
              : '已导出 ${exports.length} 个词书、$total 条词条内容（不含学习记录）',
        );
      } catch (e) {
        if (!context.mounted) return;
        showMessage(context, '导出失败：$e', error: true);
      }
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
                tooltip: '导出词书内容',
                icon: const Icon(Icons.ios_share),
                onPressed: () =>
                    exportBooks(books.value ?? const <WordBookSummary>[]),
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
                    // Deleting a book detaches up to thousands of links at once.
                    final String? backupFailure = await ref
                        .read(backupManagerProvider)
                        .protectiveBackupFailure('删除词书「${summary.book.name}」');
                    if (backupFailure != null) {
                      if (context.mounted) {
                        showMessage(context, backupFailure, error: true);
                      }
                      return;
                    }
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
