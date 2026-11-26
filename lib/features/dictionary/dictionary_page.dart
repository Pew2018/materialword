import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/app_info.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/repositories/word_repository.dart' show WordWithState;
import '../../l10n/enum_labels.dart';
import '../../l10n/intake_labels.dart';
import '../../l10n/l10n.dart';
import '../../services/dictionary_service.dart';
import '../../services/word_form_guesser.dart';
import '../../services/word_intake_service.dart';
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
  List<WordFormCandidate> _forms = const <WordFormCandidate>[];
  List<String> _recent = const <String>[];
  static const String _recentKey = 'dictionary_recent_searches';
  static const int _recentLimit = 8;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final String? raw = await ref.read(databaseProvider).readMeta(_recentKey);
    if (!mounted || raw == null) return;
    final List<String> terms = raw
        .split('\n')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    setState(() => _recent = terms);
  }

  /// Recent searches are a local convenience only: they are never synced and
  /// never leave the device.
  Future<void> _remember(String term) async {
    final String value = term.trim();
    if (value.isEmpty) return;
    final List<String> next = <String>[
      value,
      ..._recent.where(
        (String item) => item.toLowerCase() != value.toLowerCase(),
      ),
    ].take(_recentLimit).toList();
    await ref.read(databaseProvider).writeMeta(_recentKey, next.join('\n'));
    if (mounted) setState(() => _recent = next);
  }

  Future<void> _clearRecent() async {
    await ref.read(databaseProvider).deleteMeta(_recentKey);
    if (mounted) setState(() => _recent = const <String>[]);
  }

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
        _forms = const <WordFormCandidate>[];
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
      // Base-form hints are only ever shown when the candidate really exists in
      // the dictionary; the app never invents a relation or merges two entries.
      final List<WordFormCandidate> forms = <WordFormCandidate>[];
      final String needle = term.toLowerCase();
      final bool exact = found.any(
        (DictionaryEntry entry) => entry.display.toLowerCase() == needle,
      );
      if (!exact && WordFormGuesser.candidates(term).isNotEmpty) {
        for (final WordFormCandidate candidate in WordFormGuesser.candidates(
          term,
        )) {
          final DictionaryEntry? lemma = await dictionary.lookup(
            candidate.lemma,
          );
          if (lemma != null && forms.length < 3) forms.add(candidate);
        }
      }
      if (!mounted || !_generation.isCurrent(generation)) return;
      setState(() {
        _results = found;
        _mine = mine;
        _forms = forms;
        _searching = false;
        _error = null;
      });
      await _remember(term);
    } catch (e) {
      if (!mounted || !_generation.isCurrent(generation)) return;
      setState(() {
        _searching = false;
        _error = context.l10n.dictionarySearchFailed;
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
            title: context.l10n.newWordList,
            label: context.l10n.wordListName,
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
      // One path for every "add this word" action, so a deleted word is
      // restored (not silently skipped) and the book link is written in the
      // same transaction.
      final WordIntakeResult result = await ref
          .read(wordIntakeProvider)
          .add(
            WordIntakeRequest(
              text: entry.display,
              dictionary: WordContent(
                phonetic: entry.phonetic,
                partOfSpeech: entry.partOfSpeech,
                translation: entry.translation,
                definition: entry.definition,
              ),
              source: 'ECDICT',
              examTags: entry.examTags,
              bncRank: entry.bncRank,
              frqRank: entry.frqRank,
            ),
            bookId: bookId,
            now: now,
          );
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(todayProgressProvider);
      if (!mounted) return;
      showMessage(context, describeIntake(context.l10n, result));
      await _run(_term);
    } catch (e) {
      if (!mounted) return;
      showMessage(context, context.l10n.addFailed, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool desktop = isDesktopPlatform(context);
    return ContentColumn(
      child: ListView(
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
                hintText: desktop
                    ? context.l10n.searchWordHint
                    : context.l10n.searchWordHintPlain,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _term.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.l10n.commonClear,
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
          if (_term.isEmpty) ...<Widget>[
            if (_recent.isNotEmpty) ...<Widget>[
              SectionHeader(
                title: context.l10n.recentSearch,
                trailing: TextButton(
                  onPressed: _clearRecent,
                  child: Text(context.l10n.commonClear),
                ),
              ),
              SettingsGroup(
                children: <Widget>[
                  for (final String term in _recent)
                    SettingsTile(
                      leading: const Icon(Icons.history),
                      title: term,
                      onTap: () {
                        _query.text = term;
                        _onChanged(term);
                      },
                    ),
                ],
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
              child: EmptyState(
                icon: Icons.menu_book_outlined,
                title: context.l10n.offlineDictionary,
                message: context.l10n.dictionaryEmptyBody(dictionaryEntryCount),
              ),
            ),
          ] else ...<Widget>[
            if (_forms.isNotEmpty) ...<Widget>[
              SectionHeader(title: context.l10n.relatedWords),
              SettingsGroup(
                children: <Widget>[
                  for (final WordFormCandidate candidate in _forms)
                    SettingsTile(
                      leading: const Icon(Icons.subdirectory_arrow_right),
                      title: candidate.lemma,
                      subtitle: context.l10n.wordFormHint(
                        candidate.relation.label(context.l10n),
                      ),
                      onTap: () {
                        _query.text = candidate.lemma;
                        _onChanged(candidate.lemma);
                      },
                    ),
                ],
              ),
            ],
            if (_mine.isNotEmpty) ...<Widget>[
              SectionHeader(title: context.l10n.myWordsCount(_mine.length)),
              SettingsGroup(
                children: <Widget>[
                  for (final WordWithState row in _mine.take(6))
                    SettingsTile(
                      leading: const Icon(Icons.bookmark_border),
                      title: row.word.word,
                      subtitle: row.word.translation,
                      trailing: TagChip(
                        label: row.isLearned
                            ? context.l10n.learnedLabel
                            : context.l10n.unlearnedLabel,
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
            SectionHeader(
              title: context.l10n.dictionaryResultsCount(_results.length),
            ),
            if (_results.isEmpty && !_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.noDictionaryMatch,
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
                      label: Text(context.l10n.addTermAsWord(_term)),
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
                        tooltip: context.l10n.addToWordList,
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
                  context.l10n.dictionaryHint,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
