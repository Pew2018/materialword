import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/repositories/word_repository.dart';
import '../../services/dictionary_service.dart';
import '../../shared/widgets/common.dart';

/// Offline dictionary search. Words can be pushed straight into the current book.
class DictionaryPage extends ConsumerStatefulWidget {
  const DictionaryPage({super.key, this.searchFocusNode});

  final FocusNode? searchFocusNode;

  @override
  ConsumerState<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends ConsumerState<DictionaryPage> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  List<DictionaryEntry> _results = const <DictionaryEntry>[];
  List<WordWithState> _mine = const <WordWithState>[];
  bool _searching = false;
  String _term = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 220),
      () => _run(value.trim()),
    );
  }

  Future<void> _run(String term) async {
    if (!mounted) return;
    setState(() {
      _term = term;
      _searching = term.isNotEmpty;
    });
    if (term.isEmpty) {
      setState(() {
        _results = const <DictionaryEntry>[];
        _mine = const <WordWithState>[];
        _searching = false;
      });
      return;
    }
    final DictionaryService dictionary = await ref.read(
      dictionaryProvider.future,
    );
    final List<DictionaryEntry> found = await dictionary.suggest(
      term,
      limit: 20,
    );
    final List<WordWithState> mine = await ref
        .read(wordRepositoryProvider)
        .watchSearch(term, limit: 20)
        .first;
    if (!mounted) return;
    setState(() {
      _results = found;
      _mine = mine;
      _searching = false;
    });
  }

  Future<void> _add(DictionaryEntry entry) async {
    final StudySettingsRow settings = await ref
        .read(settingsRepositoryProvider)
        .load();
    String? bookId = settings.currentWordBookId;
    if (bookId == null) {
      final List<WordBook> books = await ref
          .read(wordBookRepositoryProvider)
          .listBooks();
      if (books.isEmpty) {
        if (!mounted) return;
        final String? name = await promptForText(
          context,
          title: '新建词书',
          label: '词书名称',
        );
        if (name == null || name.trim().isEmpty) return;
        final WordBook book = await ref
            .read(wordBookRepositoryProvider)
            .create(name: name, now: ref.read(clockProvider).now());
        bookId = book.id;
      } else {
        bookId = books.first.id;
      }
    }
    final DateTime now = ref.read(clockProvider).now();
    final Word word = await ref
        .read(wordRepositoryProvider)
        .ensureWord(
          text: entry.display,
          phonetic: entry.phonetic,
          partOfSpeech: entry.partOfSpeech,
          translation: entry.translation,
          definition: entry.definition,
          source: 'dictionary',
          examTags: entry.examTags,
          bncRank: entry.bncRank,
          frqRank: entry.frqRank,
          now: now,
        );
    await ref.read(wordBookRepositoryProvider).addWords(bookId, <String>[
      word.id,
    ], now: now);
    ref.invalidate(bookSummariesProvider);
    ref.invalidate(todayProgressProvider);
    if (!mounted) return;
    showMessage(context, '已加入词书：${entry.display}');
    await _run(_term);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppDimens.gutter),
      children: <Widget>[
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _query,
                focusNode: widget.searchFocusNode,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: '查询离线词典（⌘F）',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _term.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _query.clear();
                            _run('');
                          },
                        ),
                ),
                onChanged: _onChanged,
              ),
              if (_searching) ...<Widget>[
                AppSpacing.h8,
                const LinearProgressIndicator(minHeight: 2),
              ],
              AppSpacing.h16,
              if (_term.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: '离线词典',
                    message:
                        '内置 ECDICT 精简词库（约 2.6 万词，覆盖中高考、四六级、考研、雅思托福 GRE）。'
                        '输入单词开始查询，可直接加入当前词书。',
                  ),
                )
              else ...<Widget>[
                if (_mine.isNotEmpty)
                  SectionCard(
                    title: '我的词条',
                    child: Column(
                      children: <Widget>[
                        for (final WordWithState row in _mine.take(6))
                          ListTile(
                            dense: true,
                            title: Text(row.word.word),
                            subtitle: Text(
                              row.word.translation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                      ],
                    ),
                  ),
                if (_mine.isNotEmpty) AppSpacing.h16,
                SectionCard(
                  title: '词典结果',
                  child: _results.isEmpty
                      ? Text(
                          '离线词典中没有匹配项，可手动添加。',
                          style: theme.textTheme.bodySmall,
                        )
                      : Column(
                          children: <Widget>[
                            for (final DictionaryEntry entry in _results)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Text(
                                                entry.display,
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                              if (entry
                                                  .phonetic
                                                  .isNotEmpty) ...<Widget>[
                                                AppSpacing.w8,
                                                Text(
                                                  '/${entry.phonetic}/',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                              ],
                                              if (entry
                                                  .tagLabel
                                                  .isNotEmpty) ...<Widget>[
                                                AppSpacing.w8,
                                                TagChip(
                                                  label: entry.tagLabel,
                                                  dense: true,
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            entry.translation.isEmpty
                                                ? entry.definition
                                                : entry.translation,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '加入词书',
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      onPressed: () => _add(entry),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                AppSpacing.h16,
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _add(
                      DictionaryEntry(
                        word: _term.toLowerCase(),
                        display: _term,
                        phonetic: '',
                        partOfSpeech: '',
                        translation: '',
                        definition: '',
                        examTags: '',
                        bncRank: 0,
                        frqRank: 0,
                        collins: 0,
                        oxford: 0,
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text('把「$_term」作为新词条加入'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
