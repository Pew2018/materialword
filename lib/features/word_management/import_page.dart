import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../services/import_service.dart';
import '../../services/word_intake_service.dart';
import '../../shared/widgets/classic_select.dart';
import '../../l10n/backup_labels.dart';
import '../../l10n/error_labels.dart';
import '../../l10n/l10n.dart';
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
  ImportPreviewStats? _stats;
  List<WordBook> _books = const <WordBook>[];
  String? _bookId;
  bool _createNew = false;
  bool _mergeProgress = false;
  bool _busy = false;
  String? _error;
  ImportOutcome? _outcome;

  /// Bumped for every parse. A commit only accepts the preview that matches the
  /// current source, so "preview A, then import B" cannot happen.
  int _previewGeneration = 0;
  int _statsGeneration = 0;
  int _downloadGeneration = 0;

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
        dialogTitle: context.l10n.chooseWordListFile,
        type: FileType.custom,
        allowedExtensions: <String>['txt', 'csv', 'json', 'zip'],
      );
      if (files.isEmpty) return;
      final PlatformFile file = files.first;
      final String? path = file.path;
      if (path == null) {
        setState(() => _error = context.l10n.cannotReadFile);
        return;
      }
      setState(() => _busy = true);
      final ImportPreview preview = await ref
          .read(importServiceProvider)
          .parseFile(path, fileName: file.name);
      if (!mounted) return;
      await _acceptPreview(preview);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.l10n.parseFailed;
      });
    }
  }

  /// Stores a preview and computes its read-only statistics. The preview is
  /// discarded when a newer parse starts, which is what keeps a stale file from
  /// being committed after the user picks another one.
  Future<void> _acceptPreview(ImportPreview preview) async {
    final int generation = ++_previewGeneration;
    final int statsGeneration = ++_statsGeneration;
    final ImportPreviewStats stats = await ref
        .read(importServiceProvider)
        .analyze(preview, bookId: _createNew ? null : _bookId);
    if (!mounted || generation != _previewGeneration) return;
    setState(() {
      _busy = false;
      _preview = preview;
      if (statsGeneration == _statsGeneration) _stats = stats;
      if (_newBookName.text.trim().isEmpty) {
        _newBookName.text = preview.detectedBookName;
      }
    });
  }

  /// Recomputes the read-only "what would this do" numbers after the target
  /// book changes. Runs outside any write transaction.
  Future<void> _refreshStats() async {
    final ImportPreview? preview = _preview;
    if (preview == null) {
      return;
    }
    final int generation = ++_statsGeneration;
    final ImportPreviewStats stats = await ref
        .read(importServiceProvider)
        .analyze(preview, bookId: _createNew ? null : _bookId);
    if (!mounted || generation != _statsGeneration) return;
    setState(() => _stats = stats);
  }

  Future<void> _fetchUrl() async {
    final String url = _url.text.trim();
    if (url.isEmpty) return;
    final int generation = ++_downloadGeneration;
    setState(() {
      _busy = true;
      _error = null;
      _outcome = null;
    });
    try {
      final ImportPreview preview = await ref
          .read(importServiceProvider)
          .fetchUrl(url);
      if (!mounted || generation != _downloadGeneration) return;
      await _acceptPreview(preview);
    } catch (e) {
      if (!mounted || generation != _downloadGeneration) return;
      setState(() {
        _busy = false;
        _error = context.l10n.downloadParseFailed;
      });
    }
  }

  void _cancelDownload() {
    _downloadGeneration++;
    ref.read(importServiceProvider).cancel();
    setState(() {
      _busy = false;
      _error = context.l10n.downloadCancelled;
    });
  }

  Future<void> _commit() async {
    final ImportPreview? preview = _preview;
    if (preview == null || preview.entries.isEmpty) return;
    if (preview.progress == null && !_createNew && _bookId == null) {
      setState(() => _error = context.l10n.chooseTargetList);
      return;
    }
    final int generation = _previewGeneration;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final DateTime now = ref.read(clockProvider).now();
      final String name = _newBookName.text.trim().isEmpty
          ? preview.detectedBookName
          : _newBookName.text.trim();
      // The book and the words are created in the same transaction inside the
      // service, so a failure cannot leave an empty book behind.
      final ImportOutcome outcome = await ref
          .read(importServiceProvider)
          .commit(
            preview: preview,
            mergeProgress: _mergeProgress,
            bookId: _createNew ? null : _bookId,
            newBookName: _createNew ? name : null,
            sourceType: preview.sourceUrl.isEmpty ? 'file' : 'url',
            sourceUrl: preview.sourceUrl,
            now: now,
          );
      if (!mounted || generation != _previewGeneration) return;
      ref.invalidate(todayProgressProvider);
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(statisticsProvider);
      setState(() {
        _busy = false;
        _outcome = outcome;
        _preview = null;
        _stats = null;
      });
      await _loadBooks();
    } on WordIntakeException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describeAppError(context.l10n, e.code);
      });
      await _loadBooks();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.l10n.importFailedUnchanged;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: ClassicAppBar(title: Text(context.l10n.importWordListTitle)),
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
                  title: context.l10n.stepChooseSource,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _pickFile,
                              icon: const Icon(Icons.folder_open),
                              label: Text(context.l10n.chooseFile),
                            ),
                          ),
                          AppSpacing.w12,
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _showFormatHelp(context),
                              icon: const Icon(Icons.help_outline),
                              label: Text(context.l10n.formatHelp),
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
                              decoration: InputDecoration(
                                labelText: context.l10n.downloadLink,
                                hintText: 'https://example.com/cet6.txt',
                              ),
                              onChanged: (_) {
                                if (_preview != null) {
                                  setState(() {
                                    _preview = null;
                                    _stats = null;
                                  });
                                }
                              },
                            ),
                          ),
                          AppSpacing.w12,
                          OutlinedButton(
                            onPressed: _busy ? _cancelDownload : _fetchUrl,
                            child: Text(
                              _busy
                                  ? context.l10n.cancelDownload
                                  : context.l10n.download,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppSpacing.h16,
                if (_preview != null) ...<Widget>[
                  SectionCard(
                    title: context.l10n.stepPreview,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: <Widget>[
                            StatBlock(
                              value: '${_preview!.validCount}',
                              label: context.l10n.statImportable,
                            ),
                            if (_stats != null) ...<Widget>[
                              StatBlock(
                                value: '${_stats!.newWords}',
                                label: context.l10n.statNewWords,
                              ),
                              StatBlock(
                                value: '${_stats!.existingWords}',
                                label: context.l10n.statExistingWords,
                              ),
                              StatBlock(
                                value: '${_stats!.restorableWords}',
                                label: context.l10n.statRestorable,
                              ),
                              StatBlock(
                                value: '${_stats!.linkAdds}',
                                label: context.l10n.statWillLink,
                              ),
                            ],
                            StatBlock(
                              value: '${_preview!.duplicateCount}',
                              label: context.l10n.statDuplicates,
                            ),
                            StatBlock(
                              value: '${_preview!.invalidCount}',
                              label: context.l10n.statInvalid,
                            ),
                            StatBlock(
                              value: _preview!.format.toUpperCase(),
                              label: context.l10n.statFormat,
                            ),
                            StatBlock(
                              value: '${_preview!.sectionCount}',
                              label: context.l10n.statLists,
                            ),
                          ],
                        ),
                        AppSpacing.h8,
                        Text(
                          _preview!.progress == null
                              ? context.l10n.bareContentNote
                              : context.l10n.packageProgressSummary(
                                  (_preview!.progress!['reviewEvents'] as List)
                                      .length,
                                ),
                        ),
                        if (_preview!.progress != null)
                          SettingsSwitchTile(
                            title: context.l10n.mergePackageProgress,
                            subtitle: context.l10n.packageProgressChoiceNote,
                            value: _mergeProgress,
                            onChanged: (value) =>
                                setState(() => _mergeProgress = value),
                          ),
                        if (_preview!.progress != null)
                          Text(
                            context.l10n.packageScopeNote,
                            style: theme.textTheme.bodySmall,
                          ),
                        if (_preview!.droppedRows > 0) ...<Widget>[
                          AppSpacing.h12,
                          Text(
                            context.l10n.fileRowsSummary(
                              _preview!.totalRows,
                              _preview!.droppedRows,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.unknown,
                            ),
                          ),
                        ],
                        if (_stats != null &&
                            _stats!.restorableWords > 0) ...<Widget>[
                          AppSpacing.h8,
                          Text(
                            context.l10n.restorableNote(
                              _stats!.restorableWords,
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        if (_preview!.issues.isNotEmpty) ...<Widget>[
                          AppSpacing.h16,
                          Text(
                            context.l10n.issuesHeader(_preview!.issues.length),
                            style: theme.textTheme.bodySmall,
                          ),
                          AppSpacing.h4,
                          for (final ImportIssue issue in _preview!.issues.take(
                            5,
                          ))
                            Text(
                              '· ${issue.line.isEmpty ? context.l10n.importIssueEmpty : issue.line}'
                              ' — ${describeImportIssue(context.l10n, issue)}',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.h16,
                  if (_preview!.progress == null || !_mergeProgress)
                    SectionCard(
                      title: context.l10n.stepTargetList,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          RadioListTile<bool>(
                            dense: true,
                            value: false,
                            groupValue: _createNew,
                            onChanged: _books.isEmpty
                                ? null
                                : (bool? v) {
                                    setState(() => _createNew = v ?? false);
                                    _refreshStats();
                                  },
                            title: Text(context.l10n.addToExistingList),
                          ),
                          if (!_createNew)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                bottom: 8,
                              ),
                              child: ClassicSelect<String>(
                                label: context.l10n.targetList,
                                value: _bookId ?? '',
                                options: <ClassicOption<String>>[
                                  if (_bookId == null)
                                    ClassicOption<String>(
                                      value: '',
                                      label: context.l10n.chooseWordList,
                                    ),
                                  for (final WordBook book in _books)
                                    ClassicOption<String>(
                                      value: book.id,
                                      label: book.name,
                                    ),
                                ],
                                onChanged: (String value) {
                                  setState(() => _bookId = value);
                                  _refreshStats();
                                },
                              ),
                            ),
                          RadioListTile<bool>(
                            dense: true,
                            value: true,
                            groupValue: _createNew,
                            onChanged: (bool? v) {
                              setState(() => _createNew = v ?? true);
                              _refreshStats();
                            },
                            title: Text(context.l10n.newWordList),
                          ),
                          if (_createNew)
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: TextField(
                                controller: _newBookName,
                                decoration: InputDecoration(
                                  labelText: context.l10n.wordListName,
                                ),
                              ),
                            ),
                          AppSpacing.h8,
                          Text(
                            context.l10n.importMergeNote,
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
                          child: Text(context.l10n.commonCancel),
                        ),
                      ),
                      AppSpacing.w12,
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy || _preview!.entries.isEmpty
                              ? null
                              : _commit,
                          child: Text(
                            _busy
                                ? context.l10n.importing
                                : context.l10n.startImportCount(
                                    _preview!.validCount,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_outcome != null) ...<Widget>[
                  AppSpacing.h16,
                  SectionCard(
                    title: context.l10n.importComplete,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          context.l10n.refreshDone(
                            _outcome!.created,
                            _outcome!.updated,
                            _outcome!.existing,
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                        AppSpacing.h16,
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(context.l10n.commonDone),
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
                      title: context.l10n.noFileChosen,
                      message: context.l10n.formatSummary,
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
        title: Text(context.l10n.supportedFormats),
        content: SingleChildScrollView(
          child: Text(
            <String>[
              context.l10n.formatHelpTxt,
              context.l10n.formatHelpCsv,
              context.l10n.formatHelpJson,
              context.l10n.formatHelpZip,
              context.l10n.formatHelpFooter(
                ImportService.maxEntries,
                ImportService.maxFileBytes ~/ (1024 * 1024),
              ),
            ].join('\n\n'),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
