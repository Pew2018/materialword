import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/enums.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/l10n.dart';
import '../../l10n/relative_time.dart';
import '../../core/models/study_models.dart';
import '../../core/text/dictionary_text.dart';
import '../../core/time_utils.dart';
import '../../shared/widgets/classic_select.dart';
import '../../shared/widgets/common.dart';
import 'quick_add_page.dart';
import 'word_detail_page.dart';
import 'word_metadata_widgets.dart';
import '../study/study_page.dart';

const Uuid _uuid = Uuid();

/// Word management: *all* user vocabulary (as opposed to the built-in ECDICT
/// search). Filter by book / learning state / difficulty, sort, search, inspect
/// history, mark mastered, reset progress and run batch operations.
///
/// The three destructive actions are kept strictly separate, because phase 1
/// conflated them:
///  * 移出词书 — removes the link to *one* book only;
///  * 删除单词 — tombstones the word in the whole library;
///  * 重置进度 — appends a reset event, the word stays where it is.
class WordManagementPage extends ConsumerStatefulWidget {
  const WordManagementPage({super.key});

  @override
  ConsumerState<WordManagementPage> createState() => _WordManagementPageState();
}

class _WordManagementPageState extends ConsumerState<WordManagementPage> {
  final TextEditingController _search = TextEditingController();
  String? _bookId;
  String? _tagId;
  bool _favoritesOnly = false;
  List<UserTag> _tags = const [];
  ManagedStageFilter _stage = ManagedStageFilter.all;
  ManagedSort _sort = ManagedSort.addedDesc;
  List<WordBook> _books = const <WordBook>[];
  List<ManagedWord> _rows = const <ManagedWord>[];
  final Set<String> _selected = <String>{};
  String? _focusedWordId;
  bool _loading = true;
  String? _error;
  int _total = 0;
  bool _busy = false;

  static const int _pageSize = 100;
  Timer? _searchDebounce;
  Timer? _dataDebounce;
  StreamSubscription<dynamic>? _dataChanges;
  int _generation = 0;
  bool _loadingMore = false;
  bool _twoPane = false;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _dataChanges = ref.read(databaseProvider).tableUpdates().listen((updates) {
      if (!updates.any(
        (u) => <String>{
          'words',
          'learning_states',
          'word_book_entries',
          'word_books',
          'word_favorites',
          'user_tags',
          'word_tags',
        }.contains(u.table),
      )) {
        return;
      }
      _generation++;
      _dataDebounce?.cancel();
      _dataDebounce = Timer(const Duration(milliseconds: 120), () {
        if (mounted && !_busy) _bootstrap();
      });
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _generation++;
    _dataDebounce?.cancel();
    _dataChanges?.cancel();
    _searchDebounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final books = await ref.read(wordBookRepositoryProvider).listBooks();
      final tags = await ref.read(wordMetadataRepositoryProvider).listTags();
      if (!mounted) return;
      setState(() {
        _tags = tags;
        if (_tagId != null && !tags.any((t) => t.id == _tagId)) _tagId = null;
        _books = books;
        if (_bookId != null && !books.any((b) => b.id == _bookId)) {
          _bookId = null;
        }
      });
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.l10n.wordListsLoadFailed;
        });
      }
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    _searchDebounce?.cancel();
    final int generation = ++_generation;
    final String search = _search.text;
    final String? bookId = _bookId;
    final favoritesOnly = _favoritesOnly, tagId = _tagId;
    final ManagedStageFilter stage = _stage;
    final ManagedSort sort = _sort;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _selected.clear();
    });
    try {
      final repository = ref.read(studyRepositoryProvider);
      final result = await repository.db.transaction(
        () async => (
          await repository.managedWords(
            bookId: bookId,
            favoritesOnly: favoritesOnly,
            tagId: tagId,
            search: search,
            stage: stage,
            sort: sort,
            limit: _pageSize,
          ),
          await repository.managedCount(
            bookId: bookId,
            favoritesOnly: favoritesOnly,
            tagId: tagId,
            search: search,
            stage: stage,
          ),
        ),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows = result.$1;
        _total = result.$2;
        _loading = false;
        if (!_rows.any((r) => r.word.id == _focusedWordId)) {
          _focusedWordId = _rows.firstOrNull?.word.id;
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = context.l10n.errorLoadFailed;
      });
    }
  }

  void _searchChanged(String value) {
    // Invalidate in-flight work immediately, before the debounce expires.
    _generation++;
    _searchDebounce?.cancel();
    setState(() {});
    if (value.trim().isEmpty) {
      _load();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), _load);
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _rows.length >= _total) return;
    final int generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final rows = await ref
          .read(studyRepositoryProvider)
          .managedWords(
            bookId: _bookId,
            favoritesOnly: _favoritesOnly,
            tagId: _tagId,
            search: _search.text,
            stage: _stage,
            sort: _sort,
            limit: _pageSize,
            offset: _rows.length,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows = [..._rows, ...rows];
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        showMessage(context, context.l10n.errorLoadFailed, error: true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _runBatch(
    Future<String> Function(AppLocalizations l10n) operation,
  ) async {
    if (_busy || !mounted) return;
    // Captured here, before the first await: the closure then formats its result
    // without reaching back into a possibly-unmounted [BuildContext].
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final String message = await operation(l10n);
      if (!mounted) return;
      ref.invalidate(todayProgressProvider);
      ref.invalidate(statisticsProvider);
      ref.invalidate(bookSummariesProvider);
      showMessage(context, message);
      await _load();
    } catch (_) {
      if (mounted) {
        showMessage(context, l10n.operationFailedNothingChanged, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleSelect(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _selectAll() {
    setState(() {
      if (_selected.length == _rows.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_rows.map((ManagedWord r) => r.word.id));
      }
    });
  }

  Future<void> _selectFiltered() async {
    final generation = _generation;
    setState(() => _busy = true);
    try {
      final ids = await ref
          .read(studyRepositoryProvider)
          .managedWordIds(
            bookId: _bookId,
            search: _search.text,
            stage: _stage,
            favoritesOnly: _favoritesOnly,
            tagId: _tagId,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _selected
          ..clear()
          ..addAll(ids);
      });
    } catch (_) {
      if (mounted) {
        showMessage(context, context.l10n.selectionFailed, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _batchMetadata(String action) async {
    final ids = _selected.toList(growable: false);
    if (_busy || ids.isEmpty) return;
    String? tagId;
    if (action.startsWith('tag-')) {
      tagId = await pickUserTag(context, ref);
      if (tagId == null || !mounted) return;
    }
    await _runBatch((AppLocalizations l10n) async {
      final repo = ref.read(wordMetadataRepositoryProvider),
          now = ref.read(clockProvider).now();
      if (tagId != null) {
        await repo.setTag(ids, tagId, action == 'tag-add', now: now);
      } else {
        await repo.setFavorite(ids, action == 'favorite-add', now: now);
      }
      return l10n.updatedWordsCount(ids.length);
    });
  }

  Future<String> _deviceId() => ref.read(settingsRepositoryProvider).deviceId();

  Future<void> _markMastered(
    Iterable<String> selection, {
    bool undo = false,
  }) async {
    final List<String> ids = selection.toList(growable: false);
    final bool ok = await confirmDialog(
      context,
      title: undo
          ? context.l10n.unmarkMasteredTitle
          : context.l10n.markMasteredTitle,
      message: undo
          ? context.l10n.unmarkMasteredBody
          : context.l10n.markMasteredBody(ids.length),
      confirmLabel: undo
          ? context.l10n.unmarkMastered
          : context.l10n.markMastered,
    );
    if (!ok) return;
    if (!mounted) return;
    await _runBatch((AppLocalizations l10n) async {
      final repository = ref.read(studyRepositoryProvider);
      final device = await _deviceId();
      int changed = 0;
      await repository.db.transaction(() async {
        for (final id in ids) {
          if (undo && !await repository.hasManualMastery(id)) continue;
          changed++;
          await (undo ? repository.unmarkMastered : repository.markMastered)(
            wordId: id,
            deviceId: device,
            now: ref.read(clockProvider).now(),
            eventId: _uuid.v4(),
          );
        }
      });
      return undo
          ? l10n.unmarkMasteredDone(changed)
          : l10n.markMasteredDone(changed);
    });
  }

  Future<void> _resetProgress(Iterable<String> selection) async {
    final List<String> ids = selection.toList(growable: false);
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.resetProgressTitle,
      message: context.l10n.resetProgressBodyBulk(ids.length),
      confirmLabel: context.l10n.reset,
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    // A batch reset changes a lot of derived state at once: keep a recovery
    // copy first, and abort if it cannot be written.
    final AppErrorCode? backupFailure = await ref
        .read(backupManagerProvider)
        .protectiveBackupFailure('reset-progress-batch');
    if (backupFailure != null) {
      if (mounted) {
        showMessage(context, context.l10n.protectiveBackupFailed, error: true);
      }
      return;
    }
    if (!mounted) return;
    await _runBatch((AppLocalizations l10n) async {
      await ref
          .read(studyRepositoryProvider)
          .resetProgressBatch(
            wordIds: ids,
            deviceId: await _deviceId(),
            now: ref.read(clockProvider).now(),
            eventIdFor: (_) => _uuid.v4(),
          );
      return l10n.resetDone(ids.length);
    });
  }

  Future<void> _addToBook(Iterable<String> selection) async {
    final List<String> ids = selection.toList(growable: false);
    if (_books.isEmpty) {
      showMessage(context, context.l10n.addListFirst, error: true);
      return;
    }
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(context.l10n.addToWordList),
        children: <Widget>[
          for (final WordBook book in _books)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(book.id),
              child: Text(book.name),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    await _runBatch((AppLocalizations l10n) async {
      final linked = await ref
          .read(wordBookRepositoryProvider)
          .addWords(picked, ids, now: ref.read(clockProvider).now());
      return l10n.addedToWordList(linked);
    });
  }

  Future<void> _removeFromBook(Iterable<String> selection) async {
    final List<String> ids = selection.toList(growable: false);
    final String? bookId = _bookId;
    if (bookId == null) {
      showMessage(context, context.l10n.chooseListFirst, error: true);
      return;
    }
    final String bookName = _books
        .firstWhere((WordBook b) => b.id == bookId, orElse: () => _books.first)
        .name;
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.removeFromWordList,
      message: context.l10n.removeFromListBody(ids.length, bookName),
      confirmLabel: context.l10n.commonRemove,
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    await _runBatch((AppLocalizations l10n) async {
      final removed = await ref
          .read(wordBookRepositoryProvider)
          .removeWords(bookId, ids, now: ref.read(clockProvider).now());
      return l10n.removedFromWordList(removed);
    });
  }

  Future<void> _deleteWords(Iterable<String> selection) async {
    final List<String> ids = selection.toList(growable: false);
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.deleteWordsTitle,
      message: context.l10n.deleteWordsBodyBulk(ids.length),
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    final AppErrorCode? backupFailure = await ref
        .read(backupManagerProvider)
        .protectiveBackupFailure('delete-words-batch');
    if (backupFailure != null) {
      if (mounted) {
        showMessage(context, context.l10n.protectiveBackupFailed, error: true);
      }
      return;
    }
    if (!mounted) return;
    await _runBatch((AppLocalizations l10n) async {
      final deleted = await ref
          .read(wordRepositoryProvider)
          .softDeleteMany(ids, now: ref.read(clockProvider).now());
      return l10n.deletedWordsCount(deleted);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: ClassicAppBar(
        title: Text(
          _total > 0
              ? context.l10n.navAllWordsWithCount(_total)
              : context.l10n.navAllWords,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.specialFavorites,
            icon: const Icon(Icons.star_border),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const StudyPage(
                  special: SpecialReview.favorites,
                  useGlobalScope: true,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.tagsManagement,
            icon: const Icon(Icons.label_outline),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const TagsPage()),
            ),
          ),
          IconButton(
            tooltip: context.l10n.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: context.l10n.actionAddWord,
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const QuickAddPage(),
                ),
              );
              await _load();
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _filterBar(theme),
          if (_selected.isNotEmpty) _batchBar(theme),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ErrorBanner(message: _error!, onRetry: _load),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                ? EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: context.l10n.noMatchingWordsGroup,
                    message: _search.text.isEmpty
                        ? context.l10n.emptyFilterHint
                        : context.l10n.noMatchForQuery(_search.text),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      _twoPane =
                          constraints.maxWidth >= AppDimens.twoPaneBreakpoint;
                      return AdaptiveTwoPane(
                        list: _list(theme),
                        detail: _detailPane(theme),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar(ThemeData theme) {
    return Material(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: context.l10n.searchWordsHint,
                prefixIcon: const Icon(
                  Icons.search,
                  size: AppDimens.iconSizeSmall,
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: AppDimens.iconSizeSmall,
                        ),
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                      ),
              ),
              onSubmitted: (_) => _load(),
              onChanged: _searchChanged,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  FilterChip(
                    label: Text(context.l10n.favoritesOnly),
                    selected: _favoritesOnly,
                    onSelected: (value) {
                      setState(() => _favoritesOnly = value);
                      _load();
                    },
                  ),
                  AppSpacing.w8,
                  ClassicSelectChip<String>(
                    label: context.l10n.tags,
                    icon: Icons.label_outline,
                    value: _tagId ?? '',
                    options: <ClassicOption<String>>[
                      ClassicOption<String>(
                        value: '',
                        label: context.l10n.allTags,
                      ),
                      for (final tag in _tags)
                        ClassicOption<String>(value: tag.id, label: tag.name),
                    ],
                    onChanged: (String value) {
                      setState(() => _tagId = value.isEmpty ? null : value);
                      _load();
                    },
                  ),
                  AppSpacing.w8,
                  ClassicSelectChip<String>(
                    label: context.l10n.navWordLists,
                    icon: Icons.menu_book_outlined,
                    value: _bookId ?? '',
                    options: <ClassicOption<String>>[
                      ClassicOption<String>(
                        value: '',
                        label: context.l10n.allWordLists,
                      ),
                      for (final WordBook book in _books)
                        ClassicOption<String>(value: book.id, label: book.name),
                    ],
                    onChanged: (String value) {
                      setState(() => _bookId = value.isEmpty ? null : value);
                      _load();
                    },
                  ),
                  AppSpacing.w8,
                  ClassicSelectChip<ManagedStageFilter>(
                    label: context.l10n.statusLabel,
                    icon: Icons.filter_list,
                    value: _stage,
                    options: <ClassicOption<ManagedStageFilter>>[
                      for (final ManagedStageFilter filter
                          in ManagedStageFilter.values)
                        ClassicOption<ManagedStageFilter>(
                          value: filter,
                          label: filter.label(context.l10n),
                        ),
                    ],
                    onChanged: (ManagedStageFilter value) {
                      setState(() => _stage = value);
                      _load();
                    },
                  ),
                  AppSpacing.w8,
                  ClassicSelectChip<ManagedSort>(
                    label: context.l10n.sortLabel,
                    icon: Icons.sort,
                    value: _sort,
                    options: <ClassicOption<ManagedSort>>[
                      for (final ManagedSort sort in ManagedSort.values)
                        ClassicOption<ManagedSort>(
                          value: sort,
                          label: sort.label(context.l10n),
                        ),
                    ],
                    onChanged: (ManagedSort value) {
                      setState(() => _sort = value);
                      _load();
                    },
                  ),
                  AppSpacing.w8,
                  if (_total > _rows.length)
                    TextButton(
                      onPressed: _busy || _loading ? null : _selectFiltered,
                      child: Text(context.l10n.selectAllResults(_total)),
                    ),
                  TextButton(
                    onPressed: _busy || _loading ? null : _selectAll,
                    child: Text(
                      _selected.length == _rows.length && _rows.isNotEmpty
                          ? context.l10n.clearSelection
                          : context.l10n.selectLoaded(_rows.length),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batchBar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              context.l10n.selectedCount(_selected.length),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.batchFavoritesAndTags,
            enabled: !_busy,
            icon: const Icon(Icons.label_outline),
            onSelected: _batchMetadata,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'favorite-add',
                child: Text(context.l10n.favoriteSelected),
              ),
              PopupMenuItem(
                value: 'favorite-remove',
                child: Text(context.l10n.unfavoriteSelected),
              ),
              PopupMenuItem(value: 'tag-add', child: Text(context.l10n.addTag)),
              PopupMenuItem(
                value: 'tag-remove',
                child: Text(context.l10n.removeTag),
              ),
            ],
          ),
          IconButton(
            tooltip: context.l10n.addToWordList,
            icon: const Icon(Icons.playlist_add),
            onPressed: _busy ? null : () => _addToBook(_selected),
          ),
          IconButton(
            tooltip: context.l10n.removeFromCurrentList,
            icon: const Icon(Icons.playlist_remove),
            onPressed: _busy || _bookId == null
                ? null
                : () => _removeFromBook(_selected),
          ),
          IconButton(
            tooltip: context.l10n.markMastered,
            icon: const Icon(Icons.verified_outlined),
            onPressed: _busy ? null : () => _markMastered(_selected),
          ),
          IconButton(
            tooltip: context.l10n.unmarkMastered,
            icon: const Icon(Icons.verified),
            onPressed: _busy
                ? null
                : () => _markMastered(_selected, undo: true),
          ),
          IconButton(
            tooltip: context.l10n.resetProgress,
            icon: const Icon(Icons.restart_alt),
            onPressed: _busy ? null : () => _resetProgress(_selected),
          ),
          IconButton(
            tooltip: context.l10n.deleteWordsTitle,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.unknown,
            onPressed: _busy ? null : () => _deleteWords(_selected),
          ),
        ],
      ),
    );
  }

  Widget _list(ThemeData theme) {
    return ListView.separated(
      controller: _scroll,
      itemCount: _rows.length + (_rows.length < _total ? 1 : 0),
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 56, color: theme.dividerColor),
      itemBuilder: (BuildContext context, int index) {
        if (index == _rows.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _loadMore,
                      child: Text(context.l10n.loadMore),
                    ),
            ),
          );
        }
        final ManagedWord row = _rows[index];
        final bool selected = _selected.contains(row.word.id);
        final bool focused = _focusedWordId == row.word.id;
        return Material(
          color: focused
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : theme.cardColor,
          child: ListTile(
            selected: focused,
            contentPadding: const EdgeInsets.only(left: 4, right: 8),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Checkbox(
                  value: selected,
                  onChanged: _busy ? null : (_) => _toggleSelect(row.word.id),
                ),
              ],
            ),
            title: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    row.word.word,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (row.errorRate != null && row.errorRate! > 0) ...<Widget>[
                  AppSpacing.w8,
                  TagChip(
                    label: context.l10n.errorRateChip(
                      (row.errorRate! * 100).round(),
                    ),
                    color: AppColors.unknown,
                    dense: true,
                  ),
                ],
              ],
            ),
            subtitle: Text(
              row.word.translation.isEmpty
                  ? context.l10n.noChineseMeaningShort
                  : row.word.translation.replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TagChip(
                  label: row.isMastered
                      ? context.l10n.mastered
                      : row.stage.label(context.l10n),
                  dense: true,
                  color: row.stage.code == 0
                      ? theme.disabledColor
                      : (row.isMastered ? AppColors.known : null),
                ),
                const Icon(Icons.chevron_right, size: AppDimens.iconSizeSmall),
              ],
            ),
            onTap: () {
              if (_twoPane) {
                setState(() => _focusedWordId = row.word.id);
              } else {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => _WordDetailScreen(
                      wordId: row.word.id,
                      onChanged: _load,
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _detailPane(ThemeData theme) {
    final ManagedWord? row = _rows
        .where((ManagedWord r) => r.word.id == _focusedWordId)
        .firstOrNull;
    if (row == null) {
      return EmptyState(
        icon: Icons.touch_app_outlined,
        title: context.l10n.selectAWord,
        message: context.l10n.selectAWordHint,
      );
    }
    return _WordDetailPane(
      key: ValueKey<String>(row.word.id),
      wordId: row.word.id,
      bookId: _bookId,
      onChanged: _load,
    );
  }
}

/// Detail as a standalone page (phones).
class _WordDetailScreen extends StatelessWidget {
  const _WordDetailScreen({required this.wordId, required this.onChanged});

  final String wordId;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ClassicAppBar(title: Text(context.l10n.wordDetailTitle)),
      body: _WordDetailPane(wordId: wordId, onChanged: onChanged),
    );
  }
}

/// Detail pane: state, error rate, next review, history and the three
/// explicitly separated operations.
class _WordDetailPane extends ConsumerStatefulWidget {
  const _WordDetailPane({
    super.key,
    required this.wordId,
    required this.onChanged,
    this.bookId,
  });

  final String wordId;
  final String? bookId;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_WordDetailPane> createState() => _WordDetailPaneState();
}

class _WordDetailPaneState extends ConsumerState<_WordDetailPane> {
  ManagedWord? _row;
  List<dynamic> _events = const <dynamic>[];
  bool _loading = true;
  bool _manualMastery = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ManagedWord? row = await ref
        .read(studyRepositoryProvider)
        .managedWord(widget.wordId);
    final events = await ref
        .read(wordRepositoryProvider)
        .eventsForWord(widget.wordId, limit: 30);
    final manualMastery = await ref
        .read(studyRepositoryProvider)
        .hasManualMastery(widget.wordId);
    if (!mounted) return;
    setState(() {
      _manualMastery = manualMastery;
      _row = row;
      _events = events;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final ManagedWord? row = _row;
    if (row == null) {
      return EmptyState(
        icon: Icons.search_off,
        title: context.l10n.wordNotFound,
      );
    }
    final String translation = normalizeDictionaryText(row.word.translation);
    final String definition = normalizeDictionaryText(row.word.definition);
    final DateTime? next = row.nextReviewAt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                row.word.word,
                style: theme.classicStyle(
                  theme.textTheme.headlineSmall,
                  weight: FontWeight.w500,
                ),
              ),
            ),
            if (row.word.phonetic.isNotEmpty)
              Text('/${row.word.phonetic}/', style: theme.textTheme.bodySmall),
          ],
        ),
        if (row.word.partOfSpeech.isNotEmpty)
          Text(row.word.partOfSpeech, style: theme.textTheme.bodySmall),
        AppSpacing.h12,
        Text(
          translation.isEmpty
              ? context.l10n.noChineseMeaningShort
              : translation,
          style: theme.classicStyle(theme.textTheme.bodyLarge, height: 1.5),
        ),
        if (definition.isNotEmpty) ...<Widget>[
          AppSpacing.h8,
          Text(
            definition,
            style: theme.classicStyle(theme.textTheme.bodySmall, height: 1.5),
          ),
        ],
        AppSpacing.h16,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            TagChip(
              label: row.isMastered
                  ? context.l10n.mastered
                  : row.stage.label(context.l10n),
            ),
            TagChip(
              label: context.l10n.errorRateLabel(
                row.errorRate == null
                    ? context.l10n.noRecord
                    : '${(row.errorRate! * 100).round()}%',
              ),
              color: (row.errorRate ?? 0) > 0 ? AppColors.unknown : null,
              dense: true,
            ),
            TagChip(
              label: context.l10n.answersTimes(row.answerCount),
              dense: true,
            ),
            TagChip(
              label: context.l10n.inWordLists(row.bookCount),
              dense: true,
            ),
          ],
        ),
        AppSpacing.h12,
        Text(
          next == null
              ? context.l10n.nextReviewNone
              : context.l10n.nextReviewAt(
                  formatDateTime(next),
                  relativeTime(next, DateTime.now(), context.l10n),
                ),
          style: theme.textTheme.bodySmall,
        ),
        if (row.word.note.isNotEmpty) ...<Widget>[
          AppSpacing.h12,
          Text(context.l10n.notes, style: theme.textTheme.bodyMedium),
          Text(row.word.note, style: theme.textTheme.bodySmall),
        ],
        AppSpacing.h16,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => WordDetailPage(
                      wordId: widget.wordId,
                      bookId: widget.bookId,
                    ),
                  ),
                );
                await _load();
                await widget.onChanged();
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.l10n.editWord),
            ),
            TextButton.icon(
              onPressed: () => _markMastered(undo: _manualMastery),
              icon: const Icon(Icons.verified_outlined),
              label: Text(
                _manualMastery
                    ? context.l10n.unmarkMastered
                    : context.l10n.markMastered,
              ),
            ),
            TextButton.icon(
              onPressed: () => _reset(),
              icon: const Icon(Icons.restart_alt),
              label: Text(context.l10n.resetProgress),
            ),
            TextButton.icon(
              onPressed: () => _delete(),
              style: TextButton.styleFrom(foregroundColor: AppColors.unknown),
              icon: const Icon(Icons.delete_outline),
              label: Text(context.l10n.wordManagementDeleteWord),
            ),
          ],
        ),
        const Divider(height: 24),
        Text(
          context.l10n.answerHistory(_events.length),
          style: theme.textTheme.bodyMedium,
        ),
        AppSpacing.h8,
        if (_events.isEmpty)
          Text(context.l10n.noAnswerHistory, style: theme.textTheme.bodySmall)
        else
          for (final dynamic event in _events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: <Widget>[
                  TagChip(
                    label: AnswerResult.fromCode(event.result as int)
                        .label(context.l10n),
                    color: AppColors.forAnswer(event.result as int),
                    dense: true,
                  ),
                  AppSpacing.w8,
                  Text(
                    ReviewType.fromCode(event.type as String) ==
                            ReviewType.study
                        ? context.l10n.eventNewStudy
                        : context.l10n.eventReview,
                    style: theme.textTheme.bodySmall,
                  ),
                  if ((event.mode as String) !=
                      ReviewEventMode.normal) ...<Widget>[
                    AppSpacing.w8,
                    Text(
                      (event.mode as String) == ReviewEventMode.reset
                          ? context.l10n.eventReset
                          : (event.mode as String) ==
                                ReviewEventMode.manualMastered
                          ? context.l10n.eventManual
                          : context.l10n.eventSpecial,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    formatDateTime(
                      DateTime.fromMillisecondsSinceEpoch(
                        event.answeredAt as int,
                        isUtc: true,
                      ),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _markMastered({bool undo = false}) async {
    final bool ok = await confirmDialog(
      context,
      title: undo
          ? context.l10n.unmarkMasteredTitle
          : context.l10n.markMasteredTitle,
      message: undo
          ? context.l10n.unmarkMasteredBodyOne
          : context.l10n.markMasteredBodyOne,
      confirmLabel: undo
          ? context.l10n.unmarkMastered
          : context.l10n.markMastered,
    );
    if (!ok || !mounted) return;
    final String device = await ref.read(settingsRepositoryProvider).deviceId();
    final repo = ref.read(studyRepositoryProvider);
    await (undo ? repo.unmarkMastered : repo.markMastered)(
      wordId: widget.wordId,
      deviceId: device,
      now: ref.read(clockProvider).now(),
      eventId: _uuid.v4(),
    );
    ref.invalidate(todayProgressProvider);
    ref.invalidate(statisticsProvider);
    if (!mounted) return;
    await _load();
    await widget.onChanged();
  }

  Future<void> _reset() async {
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.resetProgressTitle,
      message: context.l10n.resetProgressBodyOne,
      confirmLabel: context.l10n.reset,
      destructive: true,
    );
    if (!ok) return;
    final String device = await ref.read(settingsRepositoryProvider).deviceId();
    await ref
        .read(studyRepositoryProvider)
        .resetProgress(
          wordId: widget.wordId,
          deviceId: device,
          now: ref.read(clockProvider).now(),
          eventId: _uuid.v4(),
        );
    ref.invalidate(todayProgressProvider);
    ref.invalidate(statisticsProvider);
    if (!mounted) return;
    await _load();
    await widget.onChanged();
  }

  Future<void> _delete() async {
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.deleteWordsTitle,
      message: context.l10n.deleteWordsBodyOne,
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(wordRepositoryProvider)
        .softDelete(widget.wordId, now: ref.read(clockProvider).now());
    ref.invalidate(bookSummariesProvider);
    ref.invalidate(statisticsProvider);
    ref.invalidate(todayProgressProvider);
    if (!mounted) return;
    Navigator.of(context).maybePop();
    await widget.onChanged();
  }
}
