import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/text/dictionary_text.dart';
import '../../services/dictionary_service.dart';
import '../../services/import_service.dart';
import '../../services/word_intake_service.dart';
import '../../shared/widgets/common.dart';

/// Quick add: type a word, the offline dictionary fills in everything it knows,
/// the user adds a note / example and picks a book. Designed for keyboard-only
/// use on macOS (`⌘Enter` saves and continues, `Tab` walks the fields).
///
/// Correctness rules that phase 1 got wrong:
///  * lookups are generation-guarded, so the result of "app" can never land in
///    the form after the user typed "apply";
///  * auto-filled values are tracked separately from user edits, so a new word
///    resets stale auto-fill but never erases something the user typed;
///  * saving an existing word keeps its current meaning and note unless the user
///    actually edited (or cleared) that field;
///  * the word row and the book link are written in one transaction, and the
///    save button cannot fire twice.
class QuickAddPage extends ConsumerStatefulWidget {
  const QuickAddPage({super.key, this.initialBookId});

  final String? initialBookId;

  @override
  ConsumerState<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends ConsumerState<QuickAddPage> {
  final TextEditingController _word = TextEditingController();
  final TextEditingController _phonetic = TextEditingController();
  final TextEditingController _pos = TextEditingController();
  final TextEditingController _translation = TextEditingController();
  final TextEditingController _definition = TextEditingController();
  final TextEditingController _example = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _batch = TextEditingController();
  final FocusNode _wordFocus = FocusNode();

  final SearchGeneration _generation = SearchGeneration();

  Timer? _debounce;
  DictionaryEntry? _lookup;
  bool _looking = false;
  bool _saving = false;
  String? _bookId;
  String? _status;
  String? _error;
  List<WordBook> _books = const <WordBook>[];
  bool _batchMode = false;
  bool _batchPreviewReady = false;
  ImportPreview? _batchPreview;
  Map<String, bool> _batchHasDefinition = <String, bool>{};

  /// Values written by the dictionary for the *current* word.
  final Map<String, String> _autoValues = <String, String>{};

  /// Fields the user typed into since the last word change.
  final Set<String> _dirty = <String>{};

  static const String _lastBookKey = 'quick_add_last_book';

  @override
  void initState() {
    super.initState();
    _bookId = widget.initialBookId;
    _loadBooks();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _wordFocus.requestFocus(),
    );
    for (final MapEntry<String, TextEditingController> entry
        in _controllers.entries) {
      entry.value.addListener(() => _markDirty(entry.key));
    }
  }

  Map<String, TextEditingController> get _controllers =>
      <String, TextEditingController>{
        'phonetic': _phonetic,
        'pos': _pos,
        'translation': _translation,
        'definition': _definition,
        'example': _example,
        'note': _note,
      };

  void _markDirty(String field) {
    // Programmatic writes are marked as auto and excluded from "dirty".
    final String current = _controllers[field]!.text;
    if (_autoValues[field] == current) return;
    if (!_dirty.contains(field)) _dirty.add(field);
  }

  Future<void> _loadBooks() async {
    final List<WordBook> books = await ref
        .read(wordBookRepositoryProvider)
        .listBooks();
    String? remembered =
        _bookId ?? await ref.read(databaseProvider).readMeta(_lastBookKey);
    if (!mounted) return;
    setState(() {
      _books = books;
      if (remembered == null ||
          !books.any((WordBook b) => b.id == remembered)) {
        remembered = books.isEmpty ? null : books.first.id;
      }
      _bookId = remembered;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation.invalidate();
    for (final TextEditingController c in <TextEditingController>[
      _word,
      _phonetic,
      _pos,
      _translation,
      _definition,
      _example,
      _note,
      _batch,
    ]) {
      c.dispose();
    }
    _wordFocus.dispose();
    super.dispose();
  }

  void _onWordChanged(String value) {
    _debounce?.cancel();
    final String query = value.trim();
    // A new word invalidates the previous lookup and its auto-filled fields.
    _generation.invalidate();
    _resetAutoFillForNewWord();
    if (query.isEmpty) {
      setState(() {
        _lookup = null;
        _status = null;
        _error = null;
        _looking = false;
      });
      return;
    }
    setState(() {
      _looking = true;
      _error = null;
      _status = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _lookupWord(query),
    );
  }

  /// Clears values that came from the previous word (never user edits).
  void _resetAutoFillForNewWord() {
    for (final String field in <String>[
      'phonetic',
      'pos',
      'translation',
      'definition',
    ]) {
      if (_dirty.contains(field)) continue;
      final TextEditingController controller = _controllers[field]!;
      if (controller.text.isNotEmpty) {
        controller.clear();
      }
      _autoValues.remove(field);
    }
    _lookup = null;
  }

  Future<void> _lookupWord(String query) async {
    final int generation = _generation.next();
    try {
      final DictionaryService dictionary = await ref.read(
        dictionaryProvider.future,
      );
      final DictionaryEntry? entry = await dictionary.lookup(query);
      if (!mounted || !_generation.isCurrent(generation)) return;
      setState(() {
        _looking = false;
        _lookup = entry;
        if (entry == null) {
          _status = '离线词典未收录，可以手动填写释义后保存。';
        } else {
          _status =
              '已从离线词典补全（${entry.tagLabel.isEmpty ? '通用词条' : entry.tagLabel}）';
          _fillFromEntry(entry);
        }
      });
    } catch (e) {
      if (!mounted || !_generation.isCurrent(generation)) return;
      setState(() {
        _looking = false;
        _status = null;
        _error = '词典查询失败：$e（可以手动填写后保存）';
      });
    }
  }

  /// Only fills fields the user has not touched, and remembers what it wrote.
  void _fillFromEntry(DictionaryEntry entry) {
    void fill(String field, TextEditingController controller, String value) {
      if (_dirty.contains(field)) return;
      final String clean = normalizeDictionaryText(value);
      // Record the value BEFORE writing it: the controller listener checks
      // `_autoValues` and must not mistake our own write for a user edit.
      _autoValues[field] = clean;
      controller.text = clean;
    }

    fill('phonetic', _phonetic, entry.phonetic);
    fill('pos', _pos, entry.partOfSpeech);
    fill('translation', _translation, entry.translation);
    fill('definition', _definition, entry.definition);
  }

  Future<void> _save({required bool continueAdding}) async {
    if (_saving) return;
    final String text = _word.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请输入英文单词');
      return;
    }
    if (_bookId == null) {
      setState(() => _error = '请先创建一个词书');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _status = null;
    });

    final DateTime now = ref.read(clockProvider).now();
    WordIntakeResult result;
    try {
      // One transaction (inside the intake service): the word, its field
      // versions and the book link exist together or not at all.
      result = await ref
          .read(wordIntakeProvider)
          .add(
            WordIntakeRequest(
              text: text,
              user: _userContent(),
              dictionary: _dictionaryContent(),
              source: 'manual',
              examTags: _lookup?.examTags ?? '',
              bncRank: _lookup?.bncRank ?? 0,
              frqRank: _lookup?.frqRank ?? 0,
              allowRevive: true,
            ),
            bookId: _bookId,
            now: now,
          );
    } on WordIntakeException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
      if (e.message.contains('词书已被删除')) await _loadBooks();
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$e';
      });
      return;
    }

    // The data is committed at this point. A failure while refreshing caches or
    // remembering the last book must never be reported as "save failed".
    final String message = result.describe();
    try {
      await ref.read(databaseProvider).writeMeta(_lastBookKey, _bookId!);
      ref.invalidate(todayProgressProvider);
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(statisticsProvider);
    } catch (_) {
      // Non-fatal: the row is already stored; the next refresh will pick it up.
    }
    if (!mounted) return;
    setState(() {
      _status = message;
      _saving = false;
    });
    showMessage(context, message);
    if (continueAdding) {
      _clearForm();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Only fields the user actually typed in. `null` means "leave as stored";
  /// an empty string means "the user cleared it".
  WordContent _userContent() => WordContent(
    phonetic: _dirty.contains('phonetic') ? _phonetic.text : null,
    partOfSpeech: _dirty.contains('pos') ? _pos.text : null,
    translation: _dirty.contains('translation') ? _translation.text : null,
    definition: _dirty.contains('definition') ? _definition.text : null,
    example: _dirty.contains('example') ? _example.text : null,
    note: _dirty.contains('note') ? _note.text : null,
  );

  /// Auto-filled dictionary values. They only ever fill empty fields, so they
  /// can never overwrite a stored meaning or a manual edit.
  WordContent _dictionaryContent() => WordContent(
    phonetic: _dirty.contains('phonetic') ? null : _phonetic.text,
    partOfSpeech: _dirty.contains('pos') ? null : _pos.text,
    translation: _dirty.contains('translation') ? null : _translation.text,
    definition: _dirty.contains('definition') ? null : _definition.text,
  );

  void _clearForm() {
    _word.clear();
    for (final TextEditingController c in _controllers.values) {
      c.clear();
    }
    _autoValues.clear();
    _dirty.clear();
    _generation.invalidate();
    setState(() {
      _lookup = null;
      _status = null;
      _error = null;
      _looking = false;
    });
    _wordFocus.requestFocus();
  }

  Future<void> _previewBatch() async {
    final String raw = _batch.text;
    final List<String> lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((String l) => l.trim())
        .where((String l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      setState(() => _error = '请粘贴单词，每行一个');
      return;
    }
    setState(() {
      _looking = true;
      _error = null;
      _status = null;
    });
    try {
      final ImportService service = ref.read(importServiceProvider);
      final ImportPreview preview = service.parseContent(
        lines.join('\n'),
        format: 'txt',
        name: '批量添加',
      );
      final Map<String, bool> hasDefinition = <String, bool>{};
      final DictionaryService? dictionary = ref.read(dictionaryProvider).value;
      for (final ParsedEntry entry in preview.entries) {
        final Word? existing = await ref
            .read(wordRepositoryProvider)
            .byNormalized(entry.key, includeDeleted: true);
        if (existing != null) {
          hasDefinition[entry.key] =
              existing.translation.trim().isNotEmpty ||
              existing.definition.trim().isNotEmpty;
          continue;
        }
        if (dictionary == null) {
          hasDefinition[entry.key] = false;
          continue;
        }
        final DictionaryEntry? hit = await dictionary.lookup(entry.word);
        hasDefinition[entry.key] =
            hit != null &&
            (hit.translation.trim().isNotEmpty ||
                hit.definition.trim().isNotEmpty);
      }
      if (!mounted) return;
      setState(() {
        _batchPreview = preview;
        _batchHasDefinition = hasDefinition;
        _batchPreviewReady = true;
        _looking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _looking = false;
        _error = '解析失败：$e';
      });
    }
  }

  Future<void> _commitBatch() async {
    final ImportPreview? preview = _batchPreview;
    if (preview == null || _saving || _bookId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ImportOutcome outcome = await ref
          .read(importServiceProvider)
          .commit(
            preview: preview,
            bookId: _bookId!,
            now: ref.read(clockProvider).now(),
          );
      await ref.read(databaseProvider).writeMeta(_lastBookKey, _bookId!);
      ref.invalidate(todayProgressProvider);
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(statisticsProvider);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = outcome.summary;
        _batch.clear();
        _batchPreview = null;
        _batchPreviewReady = false;
      });
      showMessage(context, outcome.summary);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '批量导入失败：$e';
      });
    }
  }

  Future<void> _createBook() async {
    final String? name = await promptForText(
      context,
      title: '新建词书',
      label: '词书名称',
    );
    if (name == null || name.trim().isEmpty) return;
    final WordBook book = await ref
        .read(wordBookRepositoryProvider)
        .create(name: name, now: ref.read(clockProvider).now());
    await _loadBooks();
    if (!mounted) return;
    setState(() => _bookId = book.id);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool desktop = isDesktopPlatform(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          if (_batchMode) {
            _commitBatch();
          } else {
            _save(continueAdding: true);
          }
        },
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (_batchMode) {
            _commitBatch();
          } else {
            _save(continueAdding: true);
          }
        },
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('快速添加单词'),
          actions: <Widget>[
            IconButton(
              tooltip: _batchMode ? '切换到单个添加' : '批量添加',
              icon: Icon(
                _batchMode ? Icons.note_add_outlined : Icons.playlist_add,
              ),
              onPressed: () => setState(() {
                _batchMode = !_batchMode;
                _error = null;
                _status = null;
              }),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            ContentWidth(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_error != null) ErrorBanner(message: _error!),
                  if (_batchMode)
                    ..._batchSection(theme)
                  else ...<Widget>[
                    TextField(
                      controller: _word,
                      focusNode: _wordFocus,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '英文单词',
                        hintText: '输入后自动查询离线词典',
                        prefixIcon: const Icon(Icons.text_fields),
                        suffixIcon: _looking
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: _onWordChanged,
                    ),
                    if (_status != null) ...<Widget>[
                      AppSpacing.h8,
                      Text(_status!, style: theme.textTheme.bodySmall),
                    ],
                    if (_lookup != null) ...<Widget>[
                      AppSpacing.h8,
                      _LookupLine(entry: _lookup!),
                    ],
                    AppSpacing.h12,
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _phonetic,
                            decoration: const InputDecoration(labelText: '音标'),
                          ),
                        ),
                        AppSpacing.w8,
                        Expanded(
                          child: TextField(
                            controller: _pos,
                            decoration: const InputDecoration(labelText: '词性'),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h8,
                    TextField(
                      controller: _translation,
                      decoration: const InputDecoration(
                        labelText: '中文释义',
                        hintText: '可为空，稍后补充',
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                    AppSpacing.h8,
                    TextField(
                      controller: _definition,
                      decoration: const InputDecoration(labelText: '英文释义'),
                      minLines: 1,
                      maxLines: 4,
                    ),
                    AppSpacing.h8,
                    TextField(
                      controller: _example,
                      decoration: const InputDecoration(labelText: '例句（可选）'),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    AppSpacing.h8,
                    TextField(
                      controller: _note,
                      decoration: const InputDecoration(labelText: '个人笔记（可选）'),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    AppSpacing.h12,
                    if (_lookup == null && _word.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '词典未收录也可以直接保存；保存后可在词条详情里继续补充释义。',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                  AppSpacing.h12,
                  _BookField(
                    books: _books,
                    bookId: _bookId,
                    onChanged: (String? id) => setState(() => _bookId = id),
                    onCreate: _createBook,
                  ),
                  AppSpacing.h16,
                  if (_batchMode)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _previewBatch,
                            child: const Text('预览'),
                          ),
                        ),
                        AppSpacing.w8,
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _saving ||
                                    !_batchPreviewReady ||
                                    _bookId == null
                                ? null
                                : _commitBatch,
                            child: Text(_saving ? '导入中…' : '导入到词书'),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _save(continueAdding: true),
                            child: Text(desktop ? '保存并继续（⌘Enter）' : '保存并继续添加'),
                          ),
                        ),
                        AppSpacing.w8,
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving
                                ? null
                                : () => _save(continueAdding: false),
                            child: Text(_saving ? '保存中…' : '保存'),
                          ),
                        ),
                      ],
                    ),
                  AppSpacing.h16,
                  Text(
                    '默认沿用上次选择的词书；已有单词会保留原有释义、笔记和学习进度，'
                    '只有你实际修改的字段才会覆盖。',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _batchSection(ThemeData theme) {
    final ImportPreview? preview = _batchPreview;
    final int withDefinition = _batchHasDefinition.values
        .where((bool v) => v)
        .length;
    final int withoutDefinition = _batchHasDefinition.length - withDefinition;
    return <Widget>[
      TextField(
        controller: _batch,
        minLines: 8,
        maxLines: 16,
        decoration: const InputDecoration(
          labelText: '批量单词（每行一个）',
          hintText: 'apple\napply\nappreciate',
          alignLabelWithHint: true,
        ),
        onChanged: (_) {
          if (_batchPreviewReady) {
            setState(() => _batchPreviewReady = false);
          }
        },
      ),
      if (_batchPreviewReady && preview != null) ...<Widget>[
        AppSpacing.h12,
        Text(
          '识别到 ${preview.entries.length} 个单词'
          '${preview.duplicateCount > 0 ? '，文件内重复 ${preview.duplicateCount} 个已合并' : ''}'
          '${preview.invalidCount > 0 ? '，忽略 ${preview.invalidCount} 行无效内容' : ''}',
          style: theme.textTheme.bodyMedium,
        ),
        AppSpacing.h4,
        Text(
          '已有释义或可由词典补全：$withDefinition 个；需要人工补充：$withoutDefinition 个。'
          '导入时已有学习进度会被保留。',
          style: theme.textTheme.bodySmall,
        ),
        AppSpacing.h8,
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final ParsedEntry entry in preview.entries.take(40))
              TagChip(
                label: entry.word,
                dense: true,
                color: (_batchHasDefinition[entry.key] ?? false)
                    ? AppColors.known
                    : AppColors.hazy,
              ),
          ],
        ),
        if (preview.entries.length > 40)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '…共 ${preview.entries.length} 个',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    ];
  }
}

class _LookupLine extends StatelessWidget {
  const _LookupLine({required this.entry});

  final DictionaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(AppDimens.radius),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.auto_awesome,
            size: AppDimens.iconSizeSmall,
            color: theme.colorScheme.primary,
          ),
          AppSpacing.w8,
          Expanded(
            child: Text(
              [
                entry.display,
                if (entry.phonetic.isNotEmpty) '/${entry.phonetic}/',
                if (entry.translation.isNotEmpty)
                  entry.translation.replaceAll('\n', ' '),
              ].join('  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookField extends StatelessWidget {
  const _BookField({
    required this.books,
    required this.bookId,
    required this.onChanged,
    required this.onCreate,
  });

  final List<WordBook> books;
  final String? bookId;
  final ValueChanged<String?> onChanged;
  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: bookId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '目标词书'),
            items: <DropdownMenuItem<String>>[
              for (final WordBook book in books)
                DropdownMenuItem<String>(
                  value: book.id,
                  child: Text(book.name),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
        AppSpacing.w8,
        IconButton(
          tooltip: '新建词书',
          onPressed: onCreate,
          icon: const Icon(Icons.create_new_folder_outlined),
        ),
      ],
    );
  }
}
