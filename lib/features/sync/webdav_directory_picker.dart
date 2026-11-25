import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/sync/sync_provider.dart';
import '../../services/sync/webdav_sync_provider.dart';
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
  String title = '选择远程文件夹',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _WebDavDirectoryDialog(
      provider: provider,
      initialPath: initialPath,
      title: title,
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
        _error = '无法读取目录：$e';
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
      title: '新建文件夹',
      label: '文件夹名称',
      confirmLabel: '创建',
    );
    if (name == null || name.trim().isEmpty) return;
    final String child = _path.isEmpty ? name.trim() : '$_path/${name.trim()}';
    try {
      await widget.provider.createDirectory(child);
      if (!mounted) return;
      setState(() => _path = _normalize(child));
      await _load();
    } on SyncException catch (e) {
      if (!mounted) return;
      showMessage(context, e.message, error: true);
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
              '服务器：${widget.provider.baseUrl.trim()}',
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
                  tooltip: '刷新',
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
          child: const Text('新建文件夹'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(_path),
          child: const Text('选择此文件夹'),
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
          title: const Text('上一级'),
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
          '这个位置没有子文件夹。可以直接选择当前文件夹，或新建一个。',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    return ListView(children: rows);
  }
}
