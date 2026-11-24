import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/repositories/word_repository.dart';
import '../../services/dictionary_service.dart';
import '../../shared/widgets/common.dart';

/// Quick add: type a word, the offline dictionary fills in everything it knows,
/// the user adds a note / example and picks a book. Designed for keyboard-only
/// use on macOS (`Tab` walks the fields, `⌘Enter` saves and continues).
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
  final FocusNode _wordFocus = FocusNode();

  Timer? _debounce;
  DictionaryEntry? _lookup;
  bool _looking = false;
  bool _saving = false;
  bool _autoFilled = false;
  String? _bookId;
  List<WordBook> _books = const <WordBook>[];
  String? _status;

  @override
  void initState() {
    super.initState();
    _bookId = widget.initialBookId;
    _loadBooks();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _wordFocus.requestFocus(),
    );
  }

  Future<void> _loadBooks() async {
    final List<WordBook> books = await ref
        .read(wordBookRepositoryProvider)
        .listBooks();
    if (!mounted) return;
    setState(() {
      _books = books;
      if (_bookId == null || !books.any((WordBook b) => b.id == _bookId)) {
        _bookId = books.isEmpty ? null : books.first.id;
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _word.dispose();
    _phonetic.dispose();
    _pos.dispose();
    _translation.dispose();
    _definition.dispose();
    _example.dispose();
    _note.dispose();
    _wordFocus.dispose();
    super.dispose();
  }

  void _onWordChanged(String value) {
    _debounce?.cancel();
    final String query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _lookup = null;
        _status = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _looking = true);
      final DictionaryService dictionary = await ref.read(
        dictionaryProvider.future,
      );
      final DictionaryEntry? entry = await dictionary.lookup(query);
      if (!mounted) return;
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
    });
  }

  /// Only fills fields the user has left empty.
  void _fillFromEntry(DictionaryEntry entry) {
    void fill(TextEditingController controller, String value) {
      if (controller.text.trim().isEmpty && value.trim().isNotEmpty) {
        controller.text = value.trim();
        _autoFilled = true;
      }
    }

    fill(_phonetic, entry.phonetic);
    fill(_pos, entry.partOfSpeech);
    fill(_translation, entry.translation);
    fill(_definition, entry.definition);
  }

  Future<void> _save({required bool continueAdding}) async {
    final String text = _word.text.trim();
    if (text.isEmpty) {
      setState(() => _status = '请输入英文单词');
      return;
    }
    if (_bookId == null) {
      setState(() => _status = '请先创建一个词书');
      return;
    }
    setState(() => _saving = true);
    final DateTime now = ref.read(clockProvider).now();
    try {
      final WordRepository words = ref.read(wordRepositoryProvider);
      final Word? existing = await words.byNormalized(
        text,
        includeDeleted: true,
      );
      final Word word;
      if (existing == null) {
        word = await words.ensureWord(
          text: text,
          phonetic: _phonetic.text.trim(),
          partOfSpeech: _pos.text.trim(),
          translation: _translation.text.trim(),
          definition: _definition.text.trim(),
          example: _example.text.trim(),
          note: _note.text.trim(),
          source: 'manual',
          examTags: _lookup?.examTags ?? '',
          bncRank: _lookup?.bncRank ?? 0,
          frqRank: _lookup?.frqRank ?? 0,
          now: now,
        );
      } else {
        word = await words.updateContent(
          existing.id,
          text: text,
          phonetic: _phonetic.text.trim(),
          partOfSpeech: _pos.text.trim(),
          translation: _translation.text.trim(),
          definition: _definition.text.trim(),
          example: _example.text.trim(),
          note: _note.text.trim(),
          now: now,
        );
      }
      final int linked = await ref.read(wordBookRepositoryProvider).addWords(
        _bookId!,
        <String>[word.id],
        now: now,
      );
      ref.invalidate(todayProgressProvider);
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(statisticsProvider);
      if (!mounted) return;
      final String message = existing == null
          ? '已添加「$text」'
          : '单词已存在，已加入词书（学习进度保留）';
      setState(() {
        _status = linked > 0 ? message : '$message（原本就在该词书中）';
        _saving = false;
      });
      showMessage(context, _status!);
      if (continueAdding) {
        _clearForm();
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = '保存失败：$e';
      });
    }
  }

  void _clearForm() {
    _word.clear();
    _phonetic.clear();
    _pos.clear();
    _translation.clear();
    _definition.clear();
    _example.clear();
    _note.clear();
    setState(() {
      _lookup = null;
      _autoFilled = false;
      _status = null;
    });
    _wordFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () =>
            _save(continueAdding: true),
      },
      child: Focus(
        autofocus: false,
        child: Scaffold(
          appBar: AppBar(title: const Text('快速添加单词')),
          body: ListView(
            padding: const EdgeInsets.all(AppDimens.gutter),
            children: <Widget>[
              ContentWidth(
                maxWidth: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: _word,
                      focusNode: _wordFocus,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '英文单词',
                        hintText: '输入后自动查询离线词典',
                        prefixIcon: Icon(Icons.text_fields),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: _onWordChanged,
                    ),
                    if (_looking) ...<Widget>[
                      AppSpacing.h8,
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (_status != null) ...<Widget>[
                      AppSpacing.h8,
                      Text(
                        _status!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _status!.startsWith('保存失败')
                              ? AppColors.unknown
                              : null,
                        ),
                      ),
                    ],
                    if (_lookup != null) AppSpacing.h16,
                    if (_lookup != null)
                      _LookupCard(entry: _lookup!, autoFilled: _autoFilled),
                    AppSpacing.h16,
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _phonetic,
                            decoration: const InputDecoration(labelText: '音标'),
                          ),
                        ),
                        AppSpacing.w12,
                        Expanded(
                          child: TextField(
                            controller: _pos,
                            decoration: const InputDecoration(labelText: '词性'),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h12,
                    TextField(
                      controller: _translation,
                      decoration: const InputDecoration(
                        labelText: '中文释义',
                        hintText: '词条允许暂时不完整',
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                    AppSpacing.h12,
                    TextField(
                      controller: _definition,
                      decoration: const InputDecoration(labelText: '英文释义'),
                      minLines: 1,
                      maxLines: 4,
                    ),
                    AppSpacing.h12,
                    TextField(
                      controller: _example,
                      decoration: const InputDecoration(labelText: '例句（可选）'),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    AppSpacing.h12,
                    TextField(
                      controller: _note,
                      decoration: const InputDecoration(labelText: '个人笔记（可选）'),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    AppSpacing.h16,
                    _BookField(
                      books: _books,
                      bookId: _bookId,
                      onChanged: (String? id) => setState(() => _bookId = id),
                      onCreate: _createBook,
                    ),
                    AppSpacing.h24,
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _save(continueAdding: true),
                            child: const Text('保存并继续添加 (⌘Enter)'),
                          ),
                        ),
                        AppSpacing.w12,
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
                    AppSpacing.h32,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}

class _LookupCard extends StatelessWidget {
  const _LookupCard({required this.entry, required this.autoFilled});

  final DictionaryEntry entry;
  final bool autoFilled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
        borderRadius: BorderRadius.circular(AppDimens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${entry.display}  ${entry.phonetic.isEmpty ? '' : '/${entry.phonetic}/'}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (autoFilled) const TagChip(label: '已自动填充', dense: true),
            ],
          ),
          if (entry.tagLabel.isNotEmpty) ...<Widget>[
            AppSpacing.h4,
            Text(entry.tagLabel, style: theme.textTheme.bodySmall),
          ],
          AppSpacing.h8,
          Text(
            entry.translation.isEmpty ? '（词典无中文释义）' : entry.translation,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
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
