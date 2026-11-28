import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/export_labels.dart';
import '../../l10n/l10n.dart';
import '../../core/repositories/word_repository.dart';
import '../../services/wordbook_export.dart';
import '../../services/learning_package.dart';
import '../../shared/widgets/common.dart';
import '../word_management/import_page.dart';
import '../word_management/quick_add_page.dart';
import '../word_management/word_detail_page.dart';
import '../study/study_page.dart';

/// Words inside one book, with search, state badges and quick management.
class WordBookDetailPage extends ConsumerStatefulWidget {
  const WordBookDetailPage({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<WordBookDetailPage> createState() => _WordBookDetailPageState();
}

class _WordBookDetailPageState extends ConsumerState<WordBookDetailPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  WordBook? _book;
  late Stream<List<WordWithState>> _stream = _buildStream();

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Stream<List<WordWithState>> _buildStream() {
    return ref
        .read(wordRepositoryProvider)
        .watchWords(bookId: widget.bookId, query: _query);
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      _stream = _buildStream();
    });
  }

  Future<void> _loadBook() async {
    final WordBook? book = await ref
        .read(wordBookRepositoryProvider)
        .byId(widget.bookId);
    if (mounted) setState(() => _book = book);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Writes the book's *content* to a user-chosen file. Not a backup: learning
  /// history stays in the database and in the real backup file.
  Future<void> _export(WordBookExportFormat format) async {
    // Captured before the await so the picker title never reads a stale context.
    final String exportTitle = context.l10n.exportListTitle;
    final WordBook? book = _book;
    if (book == null) return;
    try {
      final List<Word> words = await ref
          .read(wordBookRepositoryProvider)
          .wordsInBook(widget.bookId);
      final bytes = await LearningPackage.export(
        ref.read(backupServiceProvider),
        {book.id},
        format,
        ref.read(clockProvider).now(),
      );
      final String safeName = book.name.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final Uri? saved = await FilePicker.saveFile(
        fileName: '$safeName.zip',
        bytes: bytes,
        mimeType: 'application/zip',
        dialogTitle: exportTitle,
      );
      if (!mounted) return;
      showMessage(
        context,
        saved == null
            ? context.l10n.exportCancelled
            : context.l10n.exportDoneSingle(words.length),
      );
    } catch (e) {
      if (!mounted) return;
      showMessage(
        context,
        e is FormatException && e.message.contains('8 MB')
            ? context.l10n.learningPackageTooLarge
            : context.l10n.exportFailed,
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: ClassicAppBar(
        title: Text(_book?.name ?? context.l10n.navWordLists),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.specialBook,
            icon: const Icon(Icons.replay_outlined),
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => StudyPage(
                    special: SpecialReview.inBook,
                    bookIdOverride: widget.bookId,
                  ),
                ),
              );
              ref.invalidate(bookSummariesProvider);
              ref.invalidate(todayProgressProvider);
            },
          ),
          IconButton(
            tooltip: context.l10n.actionAddWord,
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      QuickAddPage(initialBookId: widget.bookId),
                ),
              );
              ref.invalidate(bookSummariesProvider);
            },
          ),
          IconButton(
            tooltip: context.l10n.importIntoList,
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      ImportPage(initialBookId: widget.bookId),
                ),
              );
              ref.invalidate(bookSummariesProvider);
            },
          ),
          AppBarPopupMenuButton<WordBookExportFormat>(
            tooltip: context.l10n.exportListTitle,
            icon: const Icon(Icons.ios_share),
            onSelected: _export,
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<WordBookExportFormat>>[
                  for (final WordBookExportFormat format
                      in WordBookExportFormat.values)
                    PopupMenuItem<WordBookExportFormat>(
                      value: format,
                      child: Text(exportFormatLabel(context.l10n, format)),
                    ),
                ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: context.l10n.searchWordsHint,
                prefixIcon: const Icon(
                  Icons.search,
                  size: AppDimens.iconSizeSmall,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: AppDimens.iconSizeSmall,
                        ),
                        onPressed: () {
                          _search.clear();
                          _setQuery('');
                        },
                      ),
              ),
              onChanged: _setQuery,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<WordWithState>>(
              stream: _stream,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<WordWithState>> snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return ErrorBanner(
                        message: context.l10n.wordListLoadFailed,
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<WordWithState> rows = snapshot.data!;
                    if (rows.isEmpty) {
                      return EmptyState(
                        icon: Icons.inbox_outlined,
                        title: _query.isEmpty
                            ? context.l10n.wordListEmpty
                            : context.l10n.noMatchingWords,
                        message: _query.isEmpty
                            ? context.l10n.wordListEmptyMessage
                            : null,
                        action: _query.isEmpty
                            ? ElevatedButton(
                                onPressed: () async {
                                  await Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (BuildContext context) =>
                                          QuickAddPage(
                                            initialBookId: widget.bookId,
                                          ),
                                    ),
                                  );
                                  ref.invalidate(bookSummariesProvider);
                                },
                                child: Text(context.l10n.actionAddWord),
                              )
                            : null,
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: rows.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (BuildContext context, int index) {
                        final WordWithState row = rows[index];
                        final StudyStage stage = StudyStage.fromCode(
                          row.state?.stage ?? 0,
                        );
                        final DateTime? next = row.nextReviewAt;
                        return ListTile(
                          title: Text(
                            row.word.word,
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            <String>[
                              if (row.word.phonetic.isNotEmpty)
                                '/${row.word.phonetic}/',
                              if (row.word.translation.isNotEmpty)
                                row.word.translation.replaceAll('\n', ' '),
                            ].join('  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              TagChip(
                                label: stage.label(context.l10n),
                                dense: true,
                                color: switch (stage) {
                                  StudyStage.newWord => theme.hintColor,
                                  StudyStage.learning => AppColors.hazy,
                                  StudyStage.review => AppColors.known,
                                  StudyStage.relearning => AppColors.unknown,
                                },
                              ),
                              if ((row.state?.wrongCount ?? 0) > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    context.l10n.wrongCountChip(
                                      row.state!.wrongCount,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.unknown,
                                    ),
                                  ),
                                )
                              else if (next != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${next.month}/${next.day}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) =>
                                    WordDetailPage(
                                      wordId: row.word.id,
                                      bookId: widget.bookId,
                                    ),
                              ),
                            );
                            ref.invalidate(bookSummariesProvider);
                          },
                        );
                      },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}
