import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/sync/sync_provider.dart';
import '../../services/sync/webdav_sync_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/common.dart';

/// Lets the user pick a *real* folder on their WebDAV server instead of typing
/// a path and hoping it matches.
///
/// The 坚果云 test showed why this matters: the folder Finder shows
/// (`Nutstore`) and the path the WebDAV endpoint accepts are not always the
/// same thing, so a guessed `remoteDir` produced a 403/404 that looked like a
/// permissions bug.
///
/// The dialog is deliberately classic Material 2: square-cornered dialog,
/// plain list rows, no pills or cards.
Future<String?> showWebDavDirectoryPicker({
  required BuildContext context,
  required WebDavSyncProvider provider,
  String initialPath = '',
  String? title,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _WebDavDirectoryDialog(
      provider: provider,
      initialPath: initialPath,
      title: title ?? context.l10n.chooseRemoteFolder,
    ),
  );
}

class _WebDavDirectoryDialog extends StatefulWidget {
  const _WebDavDirectoryDialog({
    required this.provider,
    required this.initialPath,
    required this.title,
  });

  final WebDavSyncProvider provider;
  final String initialPath;
  final String title;

  @override
  State<_WebDavDirectoryDialog> createState() => _WebDavDirectoryDialogState();
}

class _WebDavDirectoryDialogState extends State<_WebDavDirectoryDialog> {
  String _path = '';
  List<WebDavDirectoryEntry> _entries = const <WebDavDirectoryEntry>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _path = _normalize(widget.initialPath);
    _load();
  }

  static String _normalize(String raw) => raw
      .split(RegExp(r'[/\\]'))
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .join('/');

  String get _displayPath => _path.isEmpty ? '/' : '/$_path/';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<WebDavDirectoryEntry> entries = await widget.provider
          .listDirectories(path: _path);
      if (!mounted) return;
      setState(() {
        _entries = entries
            .where((WebDavDirectoryEntry e) => e.isCollection)
            .toList();
        _loading = false;
      });
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Keep whatever is on screen: a failed listing must not look like an
        // empty server.
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.cannotReadFolder;
      });
    }
  }

  String? get _parent {
    if (_path.isEmpty) return null;
    final List<String> parts = _path.split('/');
    parts.removeLast();
    return parts.join('/');
  }

  Future<void> _createFolder() async {
    final String? name = await promptForText(
      context,
      title: context.l10n.newFolder,
      label: context.l10n.folderName,
      confirmLabel: context.l10n.create,
    );
    if (name == null || name.trim().isEmpty) return;
    final String child = _path.isEmpty ? name.trim() : '$_path/${name.trim()}';
    try {
      await widget.provider.createDirectory(child);
      if (!mounted) return;
      setState(() => _path = _normalize(child));
      await _load();
    } on SyncException {
      if (!mounted) return;
      // The exception message is diagnostic; the user gets a sentence they can act on.
      showMessage(context, context.l10n.createFolderFailed, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? parent = _parent;
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.serverLabel(widget.provider.baseUrl.trim()),
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            AppSpacing.h4,
            Row(
              children: <Widget>[
                const Icon(
                  Icons.folder_outlined,
                  size: AppDimens.iconSizeSmall,
                ),
                AppSpacing.w8,
                Expanded(
                  child: Text(
                    _displayPath,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.commonRefresh,
                  icon: const Icon(Icons.refresh),
                  onPressed: _loading ? null : _load,
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _body(theme, parent),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.unknown,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _loading ? null : _createFolder,
          child: Text(context.l10n.newFolder),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(_path),
          child: Text(context.l10n.chooseThisFolder),
        ),
      ],
    );
  }

  Widget _body(ThemeData theme, String? parent) {
    final List<Widget> rows = <Widget>[
      if (parent != null)
        ListTile(
          dense: true,
          leading: const Icon(Icons.arrow_upward),
          title: Text(context.l10n.parentFolder),
          onTap: () {
            setState(() => _path = parent);
            _load();
          },
        ),
      for (final WebDavDirectoryEntry entry in _entries)
        ListTile(
          dense: true,
          leading: const Icon(Icons.folder),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            setState(() => _path = entry.path);
            _load();
          },
        ),
    ];
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          context.l10n.noSubfolders,
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    return ListView(children: rows);
  }
}
