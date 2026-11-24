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
///
/// Every keystroke starts a new *generation*; a slow lookup from an earlier
/// generation is dropped instead of overwriting the newer result.
class DictionaryPage extends ConsumerStatefulWidget {
  const DictionaryPage({super.key, this.searchFocusNode});

  final FocusNode? searchFocusNode;

  @override
  ConsumerState<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends ConsumerState<DictionaryPage> {
  final TextEditingController _query = TextEditingController();
  final SearchGeneration _generation = SearchGeneration();
  Timer? _debounce;
  List<DictionaryEntry> _results = const <DictionaryEntry>[];
  List<WordWithState> _mine = const <WordWithState>[];
  bool _searching = false;
  String? _error;
  String _term = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _generation.invalidate();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final String term = value.trim();
    // Typing again invalidates any in-flight lookup immediately, so a late
    // result can never be painted for a different term.
    _generation.invalidate();
    if (term.isEmpty) {
      _run('');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () => _run(term));
  }

  Future<void> _run(String term) async {
    final int generation = _generation.next();
    if (!mounted) return;
    setState(() {
      _term = term;
      _searching = term.isNotEmpty;
      _error = null;
      if (term.isEmpty) {
        _results = const <DictionaryEntry>[];
        _mine = const <WordWithState>[];
      }
    });
    if (term.isEmpty) return;

    try {
      final DictionaryService dictionary = await ref.read(
        dictionaryProvider.future,
      );
      final List<DictionaryEntry> found = await dictionary.suggest(
        term,
        limit: 30,
      );
      final List<WordWithState> mine = await ref
          .read(wordRepositoryProvider)
          .listWords(query: term, limit: 20);
      if (!mounted || !_generation.isCurrent(generation)) return;
      setState(() {
        _results = found;
        _mine = mine;
        _searching = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || !_generation.isCurrent(generation)) return;
      setState(() {
        _searching = false;
        _error = '查询失败：$e';
      });
    }
  }

  Future<void> _add(DictionaryEntry entry) async {
    try {
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
      final WordRepository words = ref.read(wordRepositoryProvider);
      final Word? existing = await words.byNormalized(
        entry.display,
        includeDeleted: true,
      );
      final Word word =
          existing ??
          await words.ensureWord(
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
      final int linked = await ref.read(wordBookRepositoryProvider).addWords(
        bookId,
        <String>[word.id],
        now: now,
      );
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(todayProgressProvider);
      if (!mounted) return;
      showMessage(
        context,
        existing != null
            ? (linked > 0 ? '已把已有词条加入词书（进度保留）' : '该词条已在词书中')
            : '已加入词书：${entry.display}',
      );
      await _run(_term);
    } catch (e) {
      if (!mounted) return;
      showMessage(context, '加入失败：$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool desktop = isDesktopPlatform(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _query,
            focusNode: widget.searchFocusNode,
            autofocus: false,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: desktop ? '查询离线词典（⌘F）' : '查询离线词典',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _term.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _query.clear();
                        _onChanged('');
                      },
                    ),
            ),
            onChanged: _onChanged,
            onSubmitted: _run,
          ),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ErrorBanner(message: _error!, onRetry: () => _run(_term)),
          ),
        if (_term.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40, left: 16, right: 16),
            child: EmptyState(
              icon: Icons.menu_book_outlined,
              title: '离线词典',
              message:
                  '内置 ECDICT 精简词库（约 2.6 万词，覆盖中高考、四六级、考研、'
                  '雅思托福 GRE）。输入单词开始查询，可直接加入当前词书。',
            ),
          )
        else ...<Widget>[
          if (_mine.isNotEmpty) ...<Widget>[
            SectionHeader(title: '我的词条（${_mine.length}）'),
            SettingsGroup(
              children: <Widget>[
                for (final WordWithState row in _mine.take(6))
                  SettingsTile(
                    leading: const Icon(Icons.bookmark_border),
                    title: row.word.word,
                    subtitle: row.word.translation,
                    trailing: TagChip(
                      label: row.isLearned ? '已学' : '未学',
                      dense: true,
                    ),
                    onTap: () => _add(
                      DictionaryEntry(
                        word: row.word.normalized,
                        display: row.word.word,
                        phonetic: row.word.phonetic,
                        partOfSpeech: row.word.partOfSpeech,
                        translation: row.word.translation,
                        definition: row.word.definition,
                        examTags: row.word.examTags,
                        bncRank: row.word.bncRank,
                        frqRank: row.word.frqRank,
                        collins: 0,
                        oxford: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SectionHeader(title: '词典结果（${_results.length}）'),
          if (_results.isEmpty && !_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '离线词典没有匹配项。可以把它作为新词条手动添加，稍后补充释义。',
                    style: theme.textTheme.bodySmall,
                  ),
                  AppSpacing.h8,
                  OutlinedButton.icon(
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
                ],
              ),
            )
          else
            SettingsGroup(
              children: <Widget>[
                for (final DictionaryEntry entry in _results)
                  SettingsTile(
                    title: entry.display,
                    subtitle: [
                      if (entry.phonetic.isNotEmpty) '/${entry.phonetic}/',
                      if (entry.translation.isNotEmpty)
                        entry.translation.replaceAll('\n', ' ')
                      else
                        entry.definition.replaceAll('\n', ' '),
                    ].join('  '),
                    trailing: IconButton(
                      tooltip: '加入词书',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _add(entry),
                    ),
                  ),
              ],
            ),
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '点击右侧「+」把词条加入当前词书；已有词条会保留学习进度和笔记。',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}
