import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/repositories/word_repository.dart';
import '../../shared/widgets/common.dart';
import '../word_management/import_page.dart';
import '../word_management/quick_add_page.dart';
import '../word_management/word_detail_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_book?.name ?? '词书'),
        actions: <Widget>[
          IconButton(
            tooltip: '添加单词',
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
            tooltip: '导入到该词书',
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
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: '搜索单词、释义或笔记',
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
                      return ErrorBanner(message: '读取失败：${snapshot.error}');
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<WordWithState> rows = snapshot.data!;
                    if (rows.isEmpty) {
                      return EmptyState(
                        icon: Icons.inbox_outlined,
                        title: _query.isEmpty ? '词书还是空的' : '没有匹配的单词',
                        message: _query.isEmpty ? '使用右上角的按钮添加单词或导入词表。' : null,
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
                                child: const Text('添加单词'),
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
                                label: stage.label,
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
                                    '错 ${row.state!.wrongCount} 次',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.unknown,
                                      fontSize: 11,
                                    ),
                                  ),
                                )
                              else if (next != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${next.month}/${next.day}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                    ),
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
