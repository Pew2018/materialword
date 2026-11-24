import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_models.dart';
import '../../core/text/dictionary_text.dart';
import '../../core/time_utils.dart';
import '../../shared/widgets/common.dart';
import 'quick_add_page.dart';
import 'word_detail_page.dart';

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
      if (!mounted) return;
      setState(() {
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
          _error = '读取词书失败，请重试';
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
            search: search,
            stage: stage,
            sort: sort,
            limit: _pageSize,
          ),
          await repository.managedCount(
            bookId: bookId,
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
        _error = '加载失败，请重试';
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
        showMessage(context, '加载失败，请重试', error: true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _runBatch(Future<String> Function() operation) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      final String message = await operation();
      if (!mounted) return;
      ref.invalidate(todayProgressProvider);
      ref.invalidate(statisticsProvider);
      ref.invalidate(bookSummariesProvider);
      showMessage(context, message);
      await _load();
    } catch (_) {
      if (mounted) showMessage(context, '操作失败，数据未更改。请重试', error: true);
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
          .managedWordIds(bookId: _bookId, search: _search.text, stage: _stage);
      if (!mounted || generation != _generation) return;
      setState(() {
        _selected
          ..clear()
          ..addAll(ids);
      });
    } catch (_) {
      if (mounted) showMessage(context, '选择失败，请重试', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _deviceId() => ref.read(settingsRepositoryProvider).deviceId();

  Future<void> _markMastered(Iterable<String> selection) async {
    final List<String> ids = selection.toList(growable: false);
    final bool ok = await confirmDialog(
      context,
      title: '标记为已掌握',
      message:
          '将选中的 ${ids.length} 个单词标记为掌握，30 天后复习。'
          '保留学习历史，不计入作答次数和正确率。',
      confirmLabel: '标记掌握',
    );
    if (!ok) return;
    if (!mounted) return;
    await _runBatch(() async {
      final repository = ref.read(studyRepositoryProvider);
      final device = await _deviceId();
      await repository.db.transaction(() async {
        for (final id in ids) {
          await repository.markMastered(
            wordId: id,
            deviceId: device,
            now: ref.read(clockProvider).now(),
            eventId: _uuid.v4(),
          );
        }
      });
      return '已标记 ${ids.length} 个单词为已掌握';
    });
  }

  Future<void> _resetProgress(Iterable<String> selection) async {
    final List<String> ids = selection.toList(growable: false);
    final bool ok = await confirmDialog(
      context,
      title: '重置学习进度',
      message:
          '将清除选中的 ${ids.length} 个单词的学习状态（次数、间隔、下次复习时间），'
          '单词本身和作答历史仍然保留。重置会记录为可同步的事件。',
      confirmLabel: '重置',
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    await _runBatch(() async {
      await ref
          .read(studyRepositoryProvider)
          .resetProgressBatch(
            wordIds: ids,
            deviceId: await _deviceId(),
            now: ref.read(clockProvider).now(),
            eventIdFor: (_) => _uuid.v4(),
          );
      return '已重置 ${ids.length} 个单词';
    });
  }

  Future<void> _addToBook(Iterable<String> selection) async {
    final List<String> ids = selection.toList(growable: false);
    if (_books.isEmpty) {
      showMessage(context, '还没有词书，请先创建', error: true);
      return;
    }
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('加入词书'),
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
    await _runBatch(() async {
      final linked = await ref
          .read(wordBookRepositoryProvider)
          .addWords(picked, ids, now: ref.read(clockProvider).now());
      return '已加入 $linked 个单词';
    });
  }

  Future<void> _removeFromBook(Iterable<String> selection) async {
    final List<String> ids = selection.toList(growable: false);
    final String? bookId = _bookId;
    if (bookId == null) {
      showMessage(context, '请先在上方选择一个词书，再执行「移出词书」', error: true);
      return;
    }
    final String bookName = _books
        .firstWhere((WordBook b) => b.id == bookId, orElse: () => _books.first)
        .name;
    final bool ok = await confirmDialog(
      context,
      title: '移出词书',
      message:
          '把选中的 ${ids.length} 个单词从「$bookName」移除？'
          '单词和其他词书中的关联不受影响，学习进度保留。',
      confirmLabel: '移出',
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    await _runBatch(() async {
      final removed = await ref
          .read(wordBookRepositoryProvider)
          .removeWords(bookId, ids, now: ref.read(clockProvider).now());
      return '已从词书移出 $removed 个单词';
    });
  }

  Future<void> _deleteWords(Iterable<String> selection) async {
    final List<String> ids = selection.toList(growable: false);
    final bool ok = await confirmDialog(
      context,
      title: '删除单词',
      message:
          '从全部用户词汇中删除选中的 ${ids.length} 个单词？'
          '它们会从所有词书中消失。作答历史作为同步墓碑保留，'
          '旧备份不会让它们复活。\n\n如果只是想从某个词书移除，请用「移出词书」。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    await _runBatch(() async {
      final deleted = await ref
          .read(wordRepositoryProvider)
          .softDeleteMany(ids, now: ref.read(clockProvider).now());
      return '已删除 $deleted 个单词';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('词汇管理${_total > 0 ? '（$_total）' : ''}'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: '添加单词',
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
                    title: '没有符合条件的单词',
                    message: _search.text.isEmpty
                        ? '换个筛选条件，或先添加/导入单词。'
                        : '没有匹配「${_search.text}」的词条。',
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
                isDense: true,
                hintText: '搜索单词 / 中文释义 / 笔记',
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
                  _DropdownChip<String?>(
                    label: '词书',
                    value: _bookId,
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('全部词书'),
                      ),
                      for (final WordBook book in _books)
                        DropdownMenuItem<String?>(
                          value: book.id,
                          child: Text(book.name),
                        ),
                    ],
                    onChanged: (String? value) {
                      setState(() => _bookId = value);
                      _load();
                    },
                  ),
                  AppSpacing.w8,
                  _DropdownChip<ManagedStageFilter>(
                    label: '状态',
                    value: _stage,
                    items: <DropdownMenuItem<ManagedStageFilter>>[
                      for (final ManagedStageFilter filter
                          in ManagedStageFilter.values)
                        DropdownMenuItem<ManagedStageFilter>(
                          value: filter,
                          child: Text(filter.label),
                        ),
                    ],
                    onChanged: (ManagedStageFilter? value) {
                      setState(() => _stage = value ?? ManagedStageFilter.all);
                      _load();
                    },
                  ),
                  AppSpacing.w8,
                  _DropdownChip<ManagedSort>(
                    label: '排序',
                    value: _sort,
                    items: <DropdownMenuItem<ManagedSort>>[
                      for (final ManagedSort sort in ManagedSort.values)
                        DropdownMenuItem<ManagedSort>(
                          value: sort,
                          child: Text(sort.label),
                        ),
                    ],
                    onChanged: (ManagedSort? value) {
                      setState(() => _sort = value ?? ManagedSort.addedDesc);
                      _load();
                    },
                  ),
                  AppSpacing.w8,
                  if (_total > _rows.length)
                    TextButton(
                      onPressed: _busy || _loading ? null : _selectFiltered,
                      child: Text('选择筛选结果全部 $_total 项'),
                    ),
                  TextButton(
                    onPressed: _busy || _loading ? null : _selectAll,
                    child: Text(
                      _selected.length == _rows.length && _rows.isNotEmpty
                          ? '取消选择'
                          : '选择已加载的 ${_rows.length} 项',
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
              '已选 ${_selected.length}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: '加入词书',
            icon: const Icon(Icons.playlist_add),
            onPressed: _busy ? null : () => _addToBook(_selected),
          ),
          IconButton(
            tooltip: '移出当前词书',
            icon: const Icon(Icons.playlist_remove),
            onPressed: _busy || _bookId == null
                ? null
                : () => _removeFromBook(_selected),
          ),
          IconButton(
            tooltip: '标记已掌握',
            icon: const Icon(Icons.verified_outlined),
            onPressed: _busy ? null : () => _markMastered(_selected),
          ),
          IconButton(
            tooltip: '重置进度',
            icon: const Icon(Icons.restart_alt),
            onPressed: _busy ? null : () => _resetProgress(_selected),
          ),
          IconButton(
            tooltip: '删除单词',
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
                  : TextButton(onPressed: _loadMore, child: const Text('加载更多')),
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
                    label: '错 ${(row.errorRate! * 100).round()}%',
                    color: AppColors.unknown,
                    dense: true,
                  ),
                ],
              ],
            ),
            subtitle: Text(
              row.word.translation.isEmpty
                  ? '（无中文释义）'
                  : row.word.translation.replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TagChip(
                  label: row.isMastered ? '已掌握' : row.stage.label,
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
        title: '选择一个单词',
        message: '左侧列表中选择单词查看学习历史与操作。',
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

class _DropdownChip<T> extends StatelessWidget {
  const _DropdownChip({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppDimens.radius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          items: items,
          onChanged: onChanged,
          hint: Text(label),
        ),
      ),
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
      appBar: AppBar(title: const Text('词条详情')),
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
    if (!mounted) return;
    setState(() {
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
      return const EmptyState(icon: Icons.search_off, title: '词条不存在或已删除');
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
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
          translation.isEmpty ? '（无中文释义）' : translation,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        if (definition.isNotEmpty) ...<Widget>[
          AppSpacing.h8,
          Text(
            definition,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
        AppSpacing.h16,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            TagChip(label: row.isMastered ? '已掌握' : row.stage.label),
            TagChip(
              label:
                  '错误率 ${row.errorRate == null ? '无记录' : '${(row.errorRate! * 100).round()}%'}',
              color: (row.errorRate ?? 0) > 0 ? AppColors.unknown : null,
              dense: true,
            ),
            TagChip(label: '作答 ${row.answerCount} 次', dense: true),
            TagChip(label: '所属词书 ${row.bookCount}', dense: true),
          ],
        ),
        AppSpacing.h12,
        Text(
          next == null
              ? '下次复习：无（未学习或已重置）'
              : '下次复习：${formatDateTime(next)}（${relativeTime(next, DateTime.now())}）',
          style: theme.textTheme.bodySmall,
        ),
        if (row.word.note.isNotEmpty) ...<Widget>[
          AppSpacing.h12,
          Text('笔记', style: theme.textTheme.bodyMedium),
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
              label: const Text('编辑词条'),
            ),
            TextButton.icon(
              onPressed: () => _markMastered(),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('标记掌握'),
            ),
            TextButton.icon(
              onPressed: () => _reset(),
              icon: const Icon(Icons.restart_alt),
              label: const Text('重置进度'),
            ),
            TextButton.icon(
              onPressed: () => _delete(),
              style: TextButton.styleFrom(foregroundColor: AppColors.unknown),
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除单词'),
            ),
          ],
        ),
        const Divider(height: 24),
        Text('作答历史（最近 ${_events.length} 条）', style: theme.textTheme.bodyMedium),
        AppSpacing.h8,
        if (_events.isEmpty)
          Text('还没有作答记录。', style: theme.textTheme.bodySmall)
        else
          for (final dynamic event in _events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: <Widget>[
                  TagChip(
                    label: AnswerResult.fromCode(event.result as int).label,
                    color: AppColors.forAnswer(event.result as int),
                    dense: true,
                  ),
                  AppSpacing.w8,
                  Text(
                    ReviewType.fromCode(event.type as String) ==
                            ReviewType.study
                        ? '新词学习'
                        : '复习',
                    style: theme.textTheme.bodySmall,
                  ),
                  if ((event.mode as String) !=
                      ReviewEventMode.normal) ...<Widget>[
                    AppSpacing.w8,
                    Text(
                      (event.mode as String) == ReviewEventMode.reset
                          ? '重置'
                          : (event.mode as String) ==
                                ReviewEventMode.manualMastered
                          ? '手动标记'
                          : '专项',
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

  Future<void> _markMastered() async {
    final bool ok = await confirmDialog(
      context,
      title: '标记为已掌握',
      message: '标记为掌握，30 天后复习。保留学习历史，不计入作答次数和正确率。',
      confirmLabel: '标记',
    );
    if (!ok) return;
    final String device = await ref.read(settingsRepositoryProvider).deviceId();
    await ref
        .read(studyRepositoryProvider)
        .markMastered(
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
      title: '重置学习进度',
      message:
          '清除该单词的学习状态（次数、间隔、下次复习时间）。'
          '单词本身和作答历史保留，重置会记录为可同步的事件。',
      confirmLabel: '重置',
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
      title: '删除单词',
      message:
          '从全部用户词汇中删除该单词（所有词书都会移除）。'
          '如果只想从一个词书移除，请使用「移出词书」。',
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
