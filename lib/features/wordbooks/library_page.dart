import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/offline_migration.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../services/dictionary_packages.dart';
import '../../services/import_service.dart';
import '../../shared/widgets/common.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});
  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _busy = false;
  bool _installed = false;
  bool _enabled = false;
  String? _problem;
  double? _progress;
  final _counts = <String, int>{};
  static const tags = [
    'cet4',
    'cet6',
    'ky',
    'ielts',
    'toefl',
    'gre',
    'zk',
    'gk',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final packages = ref.read(dictionaryPackagesProvider);
      final dictionary = await ref.read(dictionaryProvider.future);
      final counts = <String, int>{};
      for (final tag in tags) {
        counts[tag] = (await dictionary.examWords(tag)).length;
      }
      final installed = await packages.installed();
      final enabled = await packages.enabled();
      final missing = await packages.missing();
      if (mounted) {
        setState(() {
          _counts.addAll(counts);
          _installed = installed;
          _enabled = enabled;
          _problem = missing.isEmpty
              ? null
              : '${context.l10n.dictionaryMissing}: ${missing.join(', ')}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _problem = context.l10n.dictionaryOperationFailed);
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await action();
      ref.invalidate(dictionaryProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _problem = context.l10n.dictionaryOperationFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
    await _load();
  }

  Future<void> _preview(String tag) async {
    final dictionary = await ref.read(dictionaryProvider.future);
    final words = await dictionary.examWords(tag);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tag.toUpperCase()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.communityExamNote),
              AppSpacing.h8,
              Text(
                'ECDICT · MIT · ${DictionaryPackages.revision.substring(0, 8)} · ${words.length}',
              ),
              AppSpacing.h8,
              for (final word in words.take(10))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${word.display} — ${word.translation}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.addCatalogBook),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      final preview = ImportPreview.single(
        entries: [
          for (final w in words)
            ParsedEntry(
              word: w.display,
              phonetic: w.phonetic,
              partOfSpeech: w.partOfSpeech,
              translation: w.translation,
              definition: w.definition,
              examTags: w.examTags,
              bncRank: w.bncRank,
              frqRank: w.frqRank,
            ),
        ],
        format: 'catalog',
        detectedBookName: 'ECDICT ${tag.toUpperCase()}',
        totalRows: words.length,
        dictionaryEnrichable: false,
      );
      await ref
          .read(importServiceProvider)
          .commit(
            preview: preview,
            bookDescription:
                'ECDICT ${DictionaryPackages.revision} · MIT · ${DictionaryPackages.source}',
            sourceType: 'catalog:ecdict:$tag:${DictionaryPackages.revision}',
            now: ref.read(clockProvider).now(),
            allowRevive: false,
            enrichFromDictionary: false,
          );
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(todayProgressProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final packages = ref.read(dictionaryPackagesProvider);
    return Scaffold(
      appBar: ClassicAppBar(title: Text(l.libraryTitle)),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SectionHeader(title: l.offlineMigrationTitle),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final bytes = await OfflineMigration.export(
                              ref.read(backupServiceProvider),
                              packages,
                              ref.read(clockProvider).now(),
                            );
                            await FilePicker.saveFile(
                              fileName: 'materialword-offline.zip',
                              bytes: bytes,
                              mimeType: 'application/zip',
                            );
                          }),
                    child: Text(l.exportOfflineMigration),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final files = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['zip'],
                            );
                            if (files.isEmpty ||
                                files.first.path == null ||
                                !context.mounted) {
                              return;
                            }
                            final input = File(files.first.path!);
                            if (await input.length() >
                                OfflineMigration.maxBytes + 4096) {
                              if (mounted) {
                                setState(
                                  () => _problem =
                                      context.l10n.dictionaryOperationFailed,
                                );
                              }
                              return;
                            }
                            final bytes = await input.readAsBytes();
                            if (!context.mounted) return;
                            final ok = await confirmDialog(
                              context,
                              title: l.restoreOfflineMigration,
                              message: l.offlineMigrationWarning,
                              confirmLabel: l.restore,
                              destructive: true,
                            );
                            if (ok) {
                              await _run(() async {
                                await OfflineMigration.restore(
                                  bytes,
                                  ref.read(backupManagerProvider),
                                  packages,
                                );
                                ref.invalidate(bookSummariesProvider);
                                ref.invalidate(todayProgressProvider);
                                ref.invalidate(statisticsProvider);
                              });
                            }
                          },
                    child: Text(l.restoreOfflineMigration),
                  ),
                ],
              ),
            ),
            SectionHeader(title: l.defaultDictionary),
            SettingsTile(
              title: 'ECDICT',
              subtitle:
                  '${l.offlineDictionaryNote}\n57,835 · MIT · ${DictionaryPackages.revision.substring(0, 8)}',
            ),
            SectionHeader(title: l.optionalStudyBooks),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l.communityExamNote),
            ),
            for (final tag in tags)
              SettingsTile(
                title: tag.toUpperCase(),
                subtitle: 'ECDICT · MIT · ${_counts[tag] ?? "…"}',
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _preview(tag),
              ),
            SectionHeader(title: l.extensionDictionary),
            SettingsTile(
              title: 'ECDICT Extended',
              subtitle:
                  '722,442 · MIT · ${DictionaryPackages.revision.substring(0, 8)}\n37.71 MiB → 92.20 MiB',
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _problem!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_busy)
              Padding(
                padding: const EdgeInsets.all(16),
                child: LinearProgressIndicator(value: _progress),
              ),
            SettingsSwitchTile(
              title: l.enableDictionary,
              subtitle: l.dictionarySelectionNote,
              value: _enabled,
              onChanged: _busy || !_installed
                  ? null
                  : (value) => _run(() => packages.setEnabled(value)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => packages.install(
                              onProgress: (done, total) {
                                if (mounted) {
                                  setState(() => _progress = done / total);
                                }
                              },
                            ),
                          ),
                    child: Text(
                      _installed ? l.reinstallDictionary : l.installDictionary,
                    ),
                  ),
                  if (_installed)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: _busy
                          ? null
                          : () async {
                              final ok = await confirmDialog(
                                context,
                                title: l.uninstallDictionary,
                                message: l.uninstallDictionaryNote,
                                confirmLabel: l.commonDelete,
                                destructive: true,
                              );
                              if (ok) {
                                ref.invalidate(dictionaryProvider);
                                await _run(packages.uninstall);
                              }
                            },
                      child: Text(l.uninstallDictionary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showMissingDictionaryNotice(
  BuildContext context,
  WidgetRef ref,
) async {
  ref.invalidate(dictionaryProvider);
  final missing = await ref.read(dictionaryPackagesProvider).missing();
  if (missing.isEmpty || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.dictionaryMissing),
      content: SingleChildScrollView(child: Text(missing.join('\n'))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonClose),
        ),
      ],
    ),
  );
}
