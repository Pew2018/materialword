import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/database/app_database.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/common.dart';

Future<String?> pickUserTag(BuildContext context, WidgetRef ref) async {
  final tags = await ref.read(wordMetadataRepositoryProvider).listTags();
  if (!context.mounted) return null;
  if (tags.isEmpty) {
    showMessage(context, context.l10n.tagCreateFirst);
    return null;
  }
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.chooseTag),
      children: [
        for (final tag in tags)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, tag.id),
            child: Text(tag.name),
          ),
      ],
    ),
  );
}

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({super.key, required this.wordId});
  final String wordId;
  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    key: ValueKey(widget.wordId),
    stream: ref
        .watch(wordMetadataRepositoryProvider)
        .watchFavorite(widget.wordId),
    builder: (context, snapshot) {
      final favorite = snapshot.data ?? false;
      return IconButton(
        tooltip: favorite
            ? context.l10n.unfavoriteWord
            : context.l10n.favoriteWord,
        icon: Icon(favorite ? Icons.star : Icons.star_border),
        onPressed: _busy || !snapshot.hasData
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await ref
                      .read(wordMetadataRepositoryProvider)
                      .setFavorite(
                        [widget.wordId],
                        !favorite,
                        now: ref.read(clockProvider).now(),
                      );
                } catch (_) {
                  if (context.mounted) {
                    showMessage(
                      context,
                      context.l10n.favoriteFailed,
                      error: true,
                    );
                  }
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
      );
    },
  );
}

class WordTagsEditor extends ConsumerStatefulWidget {
  const WordTagsEditor({super.key, required this.wordId});
  final String wordId;
  @override
  ConsumerState<WordTagsEditor> createState() => _WordTagsEditorState();
}

class _WordTagsEditorState extends ConsumerState<WordTagsEditor> {
  bool _busy = false;
  Future<void> _change(String id, bool assigned) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(wordMetadataRepositoryProvider)
          .setTag(
            [widget.wordId],
            id,
            assigned,
            now: ref.read(clockProvider).now(),
          );
    } catch (_) {
      if (mounted) {
        showMessage(context, context.l10n.tagOperationFailed, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<UserTag>>(
    stream: ref
        .watch(wordMetadataRepositoryProvider)
        .watchTags(wordId: widget.wordId),
    builder: (context, snapshot) => Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tag in snapshot.data ?? <UserTag>[])
          InputChip(
            label: Text(tag.name),
            deleteButtonTooltipMessage: context.l10n.removeTagNamed(tag.name),
            onDeleted: _busy ? null : () => _change(tag.id, false),
          ),
        TextButton.icon(
          icon: const Icon(Icons.label_outline),
          label: Text(context.l10n.addTag),
          onPressed: _busy
              ? null
              : () async {
                  final tagId = await pickUserTag(context, ref);
                  if (tagId != null && mounted) await _change(tagId, true);
                },
        ),
        TextButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const TagsPage()),
          ),
          child: Text(context.l10n.manageTags),
        ),
      ],
    ),
  );
}

class TagsPage extends ConsumerStatefulWidget {
  const TagsPage({super.key});
  @override
  ConsumerState<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends ConsumerState<TagsPage> {
  bool _busy = false;
  Future<void> _edit([UserTag? tag]) async {
    final name = await promptForText(
      context,
      title: tag == null ? context.l10n.createTag : context.l10n.renameTag,
      label: context.l10n.tagName,
      initialValue: tag?.name ?? '',
    );
    if (name == null || !mounted || _busy) return;
    await _run(() async {
      final repo = ref.read(wordMetadataRepositoryProvider),
          now = ref.read(clockProvider).now();
      if (tag == null) {
        await repo.createTag(name, now: now);
      } else {
        await repo.renameTag(tag.id, name, now: now);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, context.l10n.errorGeneric, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(UserTag tag) async {
    final ok = await confirmDialog(
      context,
      title: context.l10n.deleteTag,
      message: context.l10n.deleteTagBody(tag.name),
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );
    if (!ok || !mounted || _busy) return;
    await _run(
      () => ref
          .read(wordMetadataRepositoryProvider)
          .deleteTag(tag.id, now: ref.read(clockProvider).now()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ClassicAppBar(
      title: Text(context.l10n.tagsManagement),
      actions: [
        IconButton(
          tooltip: context.l10n.createTag,
          onPressed: _busy ? null : () => _edit(),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: StreamBuilder<List<UserTag>>(
      stream: ref.watch(wordMetadataRepositoryProvider).watchTags(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(context.l10n.tagsLoadFailed));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tags = snapshot.data!;
        if (tags.isEmpty) {
          return EmptyState(
            icon: Icons.label_outline,
            title: context.l10n.noTagsYet,
            action: TextButton(
              onPressed: _busy ? null : () => _edit(),
              child: Text(context.l10n.createTag),
            ),
          );
        }
        return ListView.builder(
          itemCount: tags.length,
          itemBuilder: (context, index) {
            final tag = tags[index];
            return ListTile(
              title: Text(tag.name),
              leading: const Icon(Icons.label_outline),
              onTap: _busy ? null : () => _edit(tag),
              trailing: IconButton(
                tooltip: context.l10n.tagDeleteAction(tag.name),
                onPressed: _busy ? null : () => _delete(tag),
                icon: const Icon(Icons.delete_outline),
              ),
            );
          },
        );
      },
    ),
  );
}
