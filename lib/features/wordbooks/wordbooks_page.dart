import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/errors/app_error.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../../l10n/export_labels.dart';
import '../../l10n/l10n.dart';
import '../../services/import_service.dart';
import '../../services/wordbook_export.dart';
import '../../services/learning_package.dart';
import '../../shared/widgets/common.dart';
import '../word_management/import_page.dart';
import '../word_management/word_management_page.dart';
import 'word_book_detail_page.dart';
import 'library_page.dart';

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
        title: context.l10n.newWordList,
        label: context.l10n.wordListName,
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
            title: Text(context.l10n.refreshOnlineList),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <String>[
                  context.l10n.sourceUrlLabel(url),
                  '',
                  context.l10n.onlineListTotal(preview.validCount),
                  context.l10n.refreshExisting(stats.existingWords),
                  context.l10n.refreshToAdd(stats.newWords),
                  context.l10n.refreshDuplicate(preview.duplicateCount),
                  context.l10n.refreshInvalid(preview.invalidCount),
                  if (preview.droppedRows > 0)
                    context.l10n.refreshDropped(preview.droppedRows),
                  if (stats.restorableWords > 0)
                    context.l10n.refreshDeletedByUser(stats.restorableWords),
                  context.l10n.refreshLocalOnly(localOnly),
                  '',
                  context.l10n.refreshNote,
                ].map((String line) => Text(line)).toList(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.confirmRefresh),
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
        showMessage(
          context,
          context.l10n.refreshDone(
            outcome.created,
            outcome.updated,
            outcome.existing,
          ),
        );
      } on ImportCancelledException {
        if (!context.mounted) return;
        showMessage(context, context.l10n.refreshCancelled);
      } catch (e) {
        if (!context.mounted) return;
        showMessage(context, context.l10n.refreshFailed, error: true);
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
      // Captured up front: the picker is opened after several awaits.
      final String exportTitle = context.l10n.exportListTitle;
      if (all.isEmpty) {
        showMessage(context, context.l10n.nothingToExport);
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
                title: Text(context.l10n.exportListTitle),
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
                            subtitle: Text(
                              context.l10n.wordCountPlural(summary.wordCount),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.exportContentNote,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.l10n.commonCancel),
                  ),
                  TextButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(true),
                    child: Text(context.l10n.exportSelected(selected.length)),
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
              title: Text(context.l10n.chooseFormat),
              children: <Widget>[
                for (final WordBookExportFormat format
                    in WordBookExportFormat.values)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(context).pop(format),
                    child: Text(exportFormatLabel(context.l10n, format)),
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
        final bytes = await LearningPackage.export(
          ref.read(backupServiceProvider),
          selected,
          format,
          ref.read(clockProvider).now(),
        );
        final String fileName = exports.length == 1
            ? '${exports.first.book.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.zip'
            : 'materialword-wordbooks-${exports.length}.zip';
        final Uri? saved = await FilePicker.saveFile(
          fileName: fileName,
          bytes: bytes,
          mimeType: 'application/zip',
          dialogTitle: exportTitle,
        );
        if (!context.mounted) return;
        final int total = exports.fold<int>(
          0,
          (int sum, WordBookExport export) => sum + export.words.length,
        );
        showMessage(
          context,
          saved == null
              ? context.l10n.exportCancelled
              : context.l10n.exportDone(exports.length, total),
        );
      } catch (e) {
        if (!context.mounted) return;
        showMessage(context, context.l10n.exportFailed, error: true);
      }
    }

    return ContentColumn(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.myWordLists,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: openManagement,
                  icon: const Icon(
                    Icons.table_rows_outlined,
                    size: AppDimens.iconSizeSmall,
                  ),
                  label: Text(context.l10n.navAllWords),
                ),
                IconButton(
                  tooltip: context.l10n.exportListTitle,
                  icon: const Icon(Icons.ios_share),
                  onPressed: () =>
                      exportBooks(books.value ?? const <WordBookSummary>[]),
                ),
                IconButton(
                  tooltip: context.l10n.importWordList,
                  icon: const Icon(Icons.file_upload_outlined),
                  onPressed: openImport,
                ),
                IconButton(
                  tooltip: context.l10n.newWordList,
                  icon: const Icon(Icons.add),
                  onPressed: createBook,
                ),
              ],
            ),
          ),
          SettingsTile(
            leading: const Icon(Icons.local_library_outlined),
            title: context.l10n.libraryTitle,
            subtitle: context.l10n.librarySubtitle,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const LibraryPage()),
            ),
          ),
          if (books.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ErrorBanner(
                message: context.l10n.wordListsLoadFailed,
                onRetry: () => ref.invalidate(bookSummariesProvider),
              ),
            ),
          if ((books.value ?? const <WordBookSummary>[]).isEmpty)
            EmptyState(
              icon: Icons.library_books_outlined,
              title: context.l10n.noWordLists,
              message: context.l10n.noWordListsMessage,
              action: Wrap(
                spacing: 8,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: createBook,
                    child: Text(context.l10n.newWordList),
                  ),
                  OutlinedButton(
                    onPressed: openImport,
                    child: Text(context.l10n.importWordList),
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
                        title: context.l10n.renameWordList,
                        label: context.l10n.wordListName,
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
                        title: context.l10n.deleteWordListTitle,
                        message: context.l10n.deleteWordListBody(
                          summary.book.name,
                        ),
                        confirmLabel: context.l10n.commonDelete,
                        destructive: true,
                      );
                      if (!ok) return;
                      // Deleting a book detaches up to thousands of links at once.
                      final AppErrorCode? backupFailure = await ref
                          .read(backupManagerProvider)
                          .protectiveBackupFailure('delete-word-list');
                      if (backupFailure != null) {
                        if (context.mounted) {
                          showMessage(
                            context,
                            context.l10n.protectiveBackupFailed,
                            error: true,
                          );
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
              context.l10n.allWordsNote,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
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
                        TagChip(label: context.l10n.currentTag, dense: true),
                      ],
                    ],
                  ),
                ),
                if (!isCurrent)
                  TextButton(
                    onPressed: onSetCurrent,
                    child: Text(context.l10n.setForStudy),
                  ),
                PopupMenuButton<String>(
                  tooltip: context.l10n.moreActions,
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
                        PopupMenuItem<String>(
                          value: 'rename',
                          child: Text(context.l10n.commonRename),
                        ),
                        PopupMenuItem<String>(
                          value: 'import',
                          child: Text(context.l10n.importIntoList),
                        ),
                        if (onRefreshOnline != null)
                          PopupMenuItem<String>(
                            value: 'refresh',
                            child: Text(context.l10n.refreshOnlineList),
                          ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(context.l10n.commonDelete),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              context.l10n.wordListRowStats(
                summary.wordCount,
                summary.learnedCount,
                summary.dueCount,
              ),
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
