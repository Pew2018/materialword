import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../services/import_service.dart';
import '../../shared/widgets/common.dart';

/// Wordbook import: pick a TXT / CSV / JSON file (or fetch an HTTPS link), see a
/// preview, choose the target book, then commit in one transaction.
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key, this.initialBookId});

  final String? initialBookId;

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final TextEditingController _newBookName = TextEditingController();
  final TextEditingController _url = TextEditingController();

  ImportPreview? _preview;
  List<WordBook> _books = const <WordBook>[];
  String? _bookId;
  bool _createNew = false;
  bool _busy = false;
  String? _error;
  ImportOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _bookId = widget.initialBookId;
    _loadBooks();
  }

  @override
  void dispose() {
    _newBookName.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    final List<WordBook> books = await ref
        .read(wordBookRepositoryProvider)
        .listBooks();
    if (!mounted) return;
    setState(() {
      _books = books;
      _createNew = books.isEmpty || _bookId == null;
      if (!_createNew) _bookId = _bookId ?? books.first.id;
    });
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _outcome = null;
    });
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        dialogTitle: '选择词书文件',
        type: FileType.custom,
        allowedExtensions: <String>['txt', 'csv', 'json'],
      );
      if (files.isEmpty) return;
      final PlatformFile file = files.first;
      final String? path = file.path;
      if (path == null) {
        setState(() => _error = '无法读取该文件（仅支持本机文件）');
        return;
      }
      setState(() => _busy = true);
      final ImportPreview preview = await ref
          .read(importServiceProvider)
          .parseFile(path, fileName: file.name);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _preview = preview;
        _newBookName.text = preview.detectedBookName;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '解析失败：$e';
      });
    }
  }

  Future<void> _fetchUrl() async {
    final String url = _url.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _outcome = null;
    });
    try {
      final ImportPreview preview = await ref
          .read(importServiceProvider)
          .fetchUrl(url);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _preview = preview;
        _newBookName.text = preview.detectedBookName;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '下载/解析失败：$e';
      });
    }
  }

  Future<void> _commit() async {
    final ImportPreview? preview = _preview;
    if (preview == null || preview.entries.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final DateTime now = ref.read(clockProvider).now();
      String bookId;
      if (_createNew) {
        final String name = _newBookName.text.trim().isEmpty
            ? preview.detectedBookName
            : _newBookName.text.trim();
        final WordBook book = await ref
            .read(wordBookRepositoryProvider)
            .ensureBook(
              name: name,
              sourceType: preview.sourceUrl.isEmpty ? 'file' : 'url',
              sourceUrl: preview.sourceUrl,
              now: now,
            );
        bookId = book.id;
      } else {
        bookId = _bookId!;
      }
      final ImportOutcome outcome = await ref
          .read(importServiceProvider)
          .commit(preview: preview, bookId: bookId, now: now);
      ref.invalidate(todayProgressProvider);
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(statisticsProvider);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _outcome = outcome;
        _preview = null;
      });
      await _loadBooks();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '导入失败（未修改任何已有数据）：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('导入词书')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.gutter),
        children: <Widget>[
          ContentWidth(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_error != null) ErrorBanner(message: _error!),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                SectionCard(
                  title: '1. 选择来源',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _pickFile,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('选择本机文件'),
                            ),
                          ),
                          AppSpacing.w12,
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _showFormatHelp(context),
                              icon: const Icon(Icons.help_outline),
                              label: const Text('格式说明'),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h16,
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _url,
                              decoration: const InputDecoration(
                                labelText: 'HTTPS 链接（TXT / JSON）',
                                hintText: 'https://example.com/cet6.txt',
                              ),
                            ),
                          ),
                          AppSpacing.w12,
                          OutlinedButton(
                            onPressed: _busy ? null : _fetchUrl,
                            child: const Text('下载'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppSpacing.h16,
                if (_preview != null) ...<Widget>[
                  SectionCard(
                    title: '2. 预览',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: <Widget>[
                            StatBlock(
                              value: '${_preview!.validCount}',
                              label: '有效单词',
                            ),
                            StatBlock(
                              value: '${_preview!.duplicateCount}',
                              label: '文件内重复',
                            ),
                            StatBlock(
                              value: '${_preview!.invalidCount}',
                              label: '无效行',
                            ),
                            StatBlock(
                              value: _preview!.format.toUpperCase(),
                              label: '格式',
                            ),
                          ],
                        ),
                        if (_preview!.issues.isNotEmpty) ...<Widget>[
                          AppSpacing.h16,
                          Text(
                            '前 ${_preview!.issues.length} 个问题：',
                            style: theme.textTheme.bodySmall,
                          ),
                          AppSpacing.h4,
                          for (final ImportIssue issue in _preview!.issues.take(
                            5,
                          ))
                            Text(
                              '· ${issue.line} — ${issue.reason}',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.h16,
                  SectionCard(
                    title: '3. 目标词书',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        RadioListTile<bool>(
                          dense: true,
                          value: false,
                          groupValue: _createNew,
                          onChanged: _books.isEmpty
                              ? null
                              : (bool? v) =>
                                    setState(() => _createNew = v ?? false),
                          title: const Text('加入已有词书'),
                        ),
                        if (!_createNew)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 8),
                            child: DropdownButtonFormField<String>(
                              initialValue: _bookId,
                              decoration: const InputDecoration(
                                labelText: '词书',
                              ),
                              items: <DropdownMenuItem<String>>[
                                for (final WordBook book in _books)
                                  DropdownMenuItem<String>(
                                    value: book.id,
                                    child: Text(book.name),
                                  ),
                              ],
                              onChanged: (String? value) =>
                                  setState(() => _bookId = value),
                            ),
                          ),
                        RadioListTile<bool>(
                          dense: true,
                          value: true,
                          groupValue: _createNew,
                          onChanged: (bool? v) =>
                              setState(() => _createNew = v ?? true),
                          title: const Text('新建词书'),
                        ),
                        if (_createNew)
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: TextField(
                              controller: _newBookName,
                              decoration: const InputDecoration(
                                labelText: '词书名称',
                              ),
                            ),
                          ),
                        AppSpacing.h8,
                        Text(
                          '已存在的单词不会重复创建，也不会清空学习进度；只补充缺失信息并把单词关联到目标词书。',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.h24,
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _preview = null),
                          child: const Text('取消'),
                        ),
                      ),
                      AppSpacing.w12,
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy || _preview!.entries.isEmpty
                              ? null
                              : _commit,
                          child: Text(
                            _busy ? '导入中…' : '开始导入（${_preview!.validCount}）',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_outcome != null) ...<Widget>[
                  AppSpacing.h16,
                  SectionCard(
                    title: '导入完成',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          _outcome!.summary,
                          style: theme.textTheme.bodyMedium,
                        ),
                        AppSpacing.h16,
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('返回'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (_preview == null && _outcome == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.file_upload_outlined,
                      title: '尚未选择文件',
                      message: 'TXT 每行一个单词；CSV 需包含 word 列；JSON 需包含 words 数组。',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFormatHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('支持的格式'),
        content: const SingleChildScrollView(
          child: Text(
            'TXT\n每行一个单词，可在制表符或逗号后附带释义：\n  abandon\n  abandon\tv. 放弃\n\n'
            'CSV\n首行表头，必须包含 word 列，可选 phonetic / pos / translation / definition / example / note。\n\n'
            'JSON\n'
            '{\n'
            '  "schemaVersion": 1,\n'
            '  "name": "CET-6 核心词",\n'
            '  "words": [\n'
            '    {"word": "abandon", "translation": "v. 放弃"}\n'
            '  ]\n'
            '}\n\n'
            '导入前会自动用离线词典补全音标与释义；已有单词的学习进度与笔记不会被覆盖。',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
