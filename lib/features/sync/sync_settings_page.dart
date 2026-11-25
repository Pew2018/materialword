import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/time_utils.dart';
import '../../services/backup_files.dart';
import '../../services/sync/credential_store.dart';
import '../../services/sync/github_sync_provider.dart';
import '../../services/sync/local_file_sync_provider.dart';
import '../../services/sync/sync_coordinator.dart';
import '../../services/sync/sync_provider.dart';
import '../../services/sync/webdav_sync_provider.dart';
import '../../shared/widgets/common.dart';

/// One place for every sync option: pick exactly one provider, fill in its
/// connection data, test it, sync manually, and see what happened last time.
///
/// There is deliberately **no** "overwrite remote" or "replace local" button:
/// every sync merges both sides, and the destructive-looking operations simply
/// do not exist.
class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  static const List<({String id, String label, String description})> _options =
      <({String id, String label, String description})>[
        (id: 'none', label: '不同步', description: '只使用本机数据，随时可以导出备份'),
        (
          id: 'local-file',
          label: '本地文件',
          description: '读写一个 JSON 文件，适合网盘同步目录或手动拷贝',
        ),
        (
          id: 'github',
          label: 'GitHub 私有仓库',
          description: '推荐使用独立的私有数据仓库 + Fine-grained PAT',
        ),
        (
          id: 'webdav',
          label: 'WebDAV',
          description: '自建或支持 ETag 条件写入的 WebDAV 目录',
        ),
      ];

  String _provider = 'none';
  String _savedToken = '', _savedUser = '';
  final Map<String, String> _fields = <String, String>{};
  final TextEditingController _githubToken = TextEditingController();
  final TextEditingController _webdavUser = TextEditingController();
  final TextEditingController _webdavPassword = TextEditingController();

  bool _loaded = false;
  bool _busy = false;
  bool _allowSecretEdit = false;
  String? _status;
  String? _error;

  /// Shown when the Keychain exists but could not be read (re-signed build, new
  /// Keychain class, locked keychain). The user is asked to type the secret
  /// again; nothing is ever stored in plain text as a fallback.
  String? _credentialNotice;
  DateTime? _lastSyncAt;
  String? _lastResult;
  bool? _pendingChanges;
  SyncTestResult? _testResult;
  List<String> _syncNotes = const <String>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _githubToken.dispose();
    _webdavUser.dispose();
    _webdavPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsRepositoryProvider);
    final Map<String, Object?>? config = await settings.syncConfig();
    final DateTime? lastAt = await settings.lastSyncAt();
    final String? lastResult = await settings.lastSyncResult();
    final CredentialStore credentials = ref.read(credentialStoreProvider);
    String? token;
    String? user;
    bool hasPassword = false;
    String? credentialNotice;
    try {
      await CredentialStore.exclusive(() async {
        token = await credentials.read(CredentialKeys.githubToken);
        user = await credentials.read(CredentialKeys.webdavUsername);
        hasPassword =
            (await credentials.read(CredentialKeys.webdavPassword)) != null;
      });
    } on CredentialStoreUnavailable catch (e) {
      // The stored secrets are unreadable, not absent: ask the user to type
      // them again instead of pretending nothing was saved.
      credentialNotice = '${e.reason}。已保存的同步凭据无法读取，请重新输入；离线学习不受影响。';
    }
    bool pending = false;
    try {
      pending = await ref.read(syncCoordinatorProvider).hasLocalChanges();
    } catch (_) {
      pending = true;
    }
    if (!mounted) return;
    setState(() {
      _provider = (config?['provider'] as String?) ?? 'none';
      // A provider is configured but its secret came back empty: the item was
      // written under a different signature / Keychain class, or the Keychain
      // denied access. Either way the fix is the same — type it again.
      if (credentialNotice == null) {
        if (_provider == 'github' && (token?.isEmpty ?? true)) {
          credentialNotice = '未读取到已保存的 GitHub Token，请重新输入后再同步。';
        } else if (_provider == 'webdav' && !hasPassword) {
          credentialNotice = '未读取到已保存的 WebDAV 密码，请重新输入后再同步。';
        }
      }
      _credentialNotice = credentialNotice;
      _fields
        ..clear()
        ..addAll(<String, String>{
          for (final MapEntry<String, Object?> entry
              in (config ?? const <String, Object?>{}).entries)
            if (entry.value is String || entry.value is bool)
              entry.key: '${entry.value}',
        });
      _savedToken = token ?? '';
      _savedUser = user ?? '';
      _githubToken.text = token ?? '';
      _webdavUser.text = user ?? '';
      _webdavPassword.text = hasPassword ? '••••••••' : '';
      _lastSyncAt = lastAt;
      _lastResult = lastResult;
      _pendingChanges = pending;
      _loaded = true;
    });
  }

  String _field(String key, {String fallback = ''}) => _fields[key] ?? fallback;

  bool get _draftCredentialsChanged =>
      (_provider == 'github' &&
          _githubToken.text.trim() != _savedToken.trim()) ||
      (_provider == 'webdav' &&
          (_webdavUser.text.trim() != _savedUser.trim() ||
              (_webdavPassword.text.isNotEmpty &&
                  _webdavPassword.text != '••••••••')));

  Future<void> _setAutoOption(String key, bool value) async {
    setState(() => _fields[key] = value.toString());
    final settings = ref.read(settingsRepositoryProvider);
    final config = await settings.syncConfig();
    if (!mounted) return;
    final draftChanged =
        config == null ||
        config['provider'] != _provider ||
        config.entries.any(
          (e) => e.value is String && _fields[e.key] != e.value,
        ) ||
        (_provider == 'github' &&
            _githubToken.text.trim() != _savedToken.trim()) ||
        (_provider == 'webdav' &&
            (_webdavUser.text.trim() != _savedUser.trim() ||
                (_webdavPassword.text.isNotEmpty &&
                    _webdavPassword.text != '••••••••')));
    if (draftChanged) {
      showMessage(context, '连接草稿尚未保存，自动选项将在「立即同步」时一并保存和验证');
      return;
    }
    try {
      final saved = await settings.updateSyncAutoOption(
        key,
        value,
        expected: config,
      );
      if (!saved && mounted) {
        showMessage(context, '连接配置已改变，请重新打开同步页后设置', error: true);
      }
    } catch (_) {
      if (mounted) showMessage(context, '自动同步选项保存失败，请重试', error: true);
    }
  }

  SyncProvider? _buildProvider({bool draft = false}) {
    switch (_provider) {
      case 'local-file':
        return LocalFileSyncProvider(filePath: _field('path'));
      case 'github':
        return GitHubSyncProvider(
          owner: _field('owner'),
          repo: _field('repo'),
          branch: _field('branch', fallback: 'main'),
          path: _field('path', fallback: 'materialword-data.json'),
          identityEpoch: _field('credentialEpoch'),
          credentials: ref.read(credentialStoreProvider),
          tokenOverride: draft && _githubToken.text.trim().isNotEmpty
              ? _githubToken.text.trim()
              : null,
        );
      case 'webdav':
        return WebDavSyncProvider(
          baseUrl: _field('url'),
          remoteDir: _field('dir', fallback: 'materialword'),
          fileName: _field('file', fallback: 'materialword-data.json'),
          identityEpoch: _field('credentialEpoch'),
          credentials: ref.read(credentialStoreProvider),
          usernameOverride: draft && _webdavUser.text.trim().isNotEmpty
              ? _webdavUser.text.trim()
              : null,
          passwordOverride:
              draft &&
                  _webdavPassword.text.isNotEmpty &&
                  _webdavPassword.text != '••••••••'
              ? _webdavPassword.text
              : null,
        );
      default:
        return null;
    }
  }

  /// Persists the non-secret config, and the secrets when asked.
  ///
  /// Returns `false` when a secret could not be written to the Keychain. The
  /// caller must not continue with a connection test in that case: the test
  /// would silently run without the token the user just typed.
  Future<bool> _saveConfig({bool persistSecrets = true}) async {
    final CredentialStore credentials = ref.read(credentialStoreProvider);
    if (persistSecrets) {
      try {
        await CredentialStore.exclusive(() async {
          if (_provider == 'github' && _githubToken.text.trim().isNotEmpty) {
            await credentials.write(
              CredentialKeys.githubToken,
              _githubToken.text.trim(),
            );
          }
          if (_provider == 'webdav') {
            if (_webdavUser.text.trim().isNotEmpty) {
              await credentials.write(
                CredentialKeys.webdavUsername,
                _webdavUser.text.trim(),
              );
            }
            if (_webdavPassword.text.isNotEmpty &&
                _webdavPassword.text != '••••••••') {
              await credentials.write(
                CredentialKeys.webdavPassword,
                _webdavPassword.text,
              );
            }
          }
        });
      } on CredentialStoreUnavailable catch (e) {
        if (mounted) {
          setState(() {
            _credentialNotice =
                '${e.reason}。凭据没有保存（也不会以明文保存），'
                '请在系统钥匙串可用后重新输入；离线学习不受影响。';
          });
        }
        return false;
      }
    }

    final Map<String, Object?> config = <String, Object?>{
      'provider': _provider,
      'autoOnStart': _fields['autoOnStart'] == 'true',
      'autoOnResume': _fields['autoOnResume'] == 'true',
      'autoOnChange': _fields['autoOnChange'] == 'true',
      'autoAfterSession': _fields['autoAfterSession'] == 'true',
      'credentialEpoch': _field('credentialEpoch'),
    };
    switch (_provider) {
      case 'local-file':
        config['path'] = _field('path');
      case 'github':
        config
          ..['owner'] = _field('owner')
          ..['repo'] = _field('repo')
          ..['branch'] = _field('branch', fallback: 'main')
          ..['path'] = _field('path', fallback: 'materialword-data.json');
      case 'webdav':
        config
          ..['url'] = _field('url')
          ..['dir'] = _field('dir', fallback: 'materialword')
          ..['file'] = _field('file', fallback: 'materialword-data.json');
    }
    await ref
        .read(settingsRepositoryProvider)
        .setSyncConfig(_provider == 'none' ? null : config);
    return true;
  }

  Future<void> _runTest() async {
    final SyncProvider? provider = _buildProvider(draft: true);
    if (provider == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
      _testResult = null;
    });
    try {
      if (provider is GitHubSyncProvider) await provider.captureCredentials();
      if (provider is WebDavSyncProvider) await provider.captureCredentials();
      final SyncTestResult result = await provider.testConnection();
      if (!mounted) return;
      setState(() {
        _testResult = result;
        _busy = false;
      });
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '连接测试失败：$e';
      });
    } finally {
      if (provider is GitHubSyncProvider) provider.clearCapturedCredentials();
      if (provider is WebDavSyncProvider) {
        provider.clearCapturedCredentials();
        provider.close();
      }
    }
  }

  Future<void> _syncNow() async {
    if (_draftCredentialsChanged) {
      _fields['credentialEpoch'] = const Uuid().v4();
    }
    final SyncProvider? provider = _buildProvider();
    if (provider == null) return;
    final SyncCoordinator coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator.isRunning) {
      setState(() => _error = '同步正在进行中');
      return;
    }

    if (!await coordinator.hasSyncedTarget(provider)) {
      if (!mounted) return;
      final bool ok = await confirmDialog(
        context,
        title: '首次同步',
        message:
            '首次同步会把远程数据与本机数据合并（按单词、作答记录去重），'
            '不会用远程数据覆盖本地学习进度，也不会删除本地单词。'
            '如果远程已有大量数据，合并后可能出现重复词条以外的额外记录。\n\n继续吗？',
        confirmLabel: '开始合并',
      );
      if (!ok) return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _status = null;
      _syncNotes = const <String>[];
    });
    if (!await _saveConfig()) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      final SyncReport report = await coordinator.sync(
        provider,
        onProgress: (SyncStage stage, String detail) {
          if (!mounted) return;
          setState(() => _status = '${stage.label}：$detail');
        },
      );
      ref.invalidate(todayProgressProvider);
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(statisticsProvider);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = report.message;
        _syncNotes = report.notes;
        _error = report.ok ? null : report.message;
      });
      await _load();
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
        _status = null;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '同步失败：$e';
      });
    }
  }

  Future<void> _exportBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await BackupFiles(ref.read(backupServiceProvider))
          .export(now: ref.read(clockProvider).now());
      if (saved && mounted) showMessage(context, '备份已导出');
    } catch (_) {
      if (mounted) showMessage(context, '导出失败，请重新选择保存位置', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final bool ok = await confirmDialog(
      context,
      title: '解除同步配置',
      message:
          '将删除本机保存的同步配置和凭据（Token / 密码）。'
          '远程数据不会被删除，本地学习数据不受影响。',
      confirmLabel: '解除',
      destructive: true,
    );
    if (!ok) return;
    final CredentialStore credentials = ref.read(credentialStoreProvider);
    await CredentialStore.exclusive(() async {
      await credentials.delete(CredentialKeys.githubToken);
      await credentials.delete(CredentialKeys.webdavPassword);
      await credentials.delete(CredentialKeys.webdavUsername);
    });
    await ref.read(settingsRepositoryProvider).setSyncConfig(null);
    if (!mounted) return;
    setState(() {
      _provider = 'none';
      _fields.clear();
      _githubToken.clear();
      _webdavUser.clear();
      _webdavPassword.clear();
      _status = '已解除同步配置';
      _testResult = null;
    });
  }

  void _selectProvider(String id) {
    if (id == _provider) return;
    setState(() {
      _provider = id;
      _testResult = null;
      _status = null;
      _error = null;
    });
    if (_provider != 'none') {
      showMessage(context, '切换同步方式后请重新测试连接；切换只改变传输通道，合并规则完全相同。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool autoStart = _fields['autoOnStart'] == 'true';
    final bool autoResume = _fields['autoOnResume'] == 'true';
    final bool canAuto = _provider != 'local-file';

    return Scaffold(
      appBar: AppBar(title: const Text('数据同步')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: <Widget>[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ErrorBanner(message: _error!),
            ),
          if (_credentialNotice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: NoticeBanner(message: _credentialNotice!),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          SectionHeader(title: '同步方式（同一时间只启用一种）'),
          SettingsGroup(
            children: <Widget>[
              for (final ({String id, String label, String description}) option
                  in _options)
                RadioListTile<String>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  value: option.id,
                  groupValue: _provider,
                  onChanged: (String? value) =>
                      _selectProvider(value ?? 'none'),
                  title: Text(option.label),
                  subtitle: Text(
                    option.description,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          if (_provider != 'none') ...<Widget>[
            SectionHeader(title: '连接配置'),
            _configGroup(),
            SectionHeader(title: '同步'),
            SettingsGroup(
              children: <Widget>[
                SwitchListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: autoStart,
                  onChanged: !canAuto || _busy
                      ? null
                      : (value) => _setAutoOption('autoOnStart', value),
                  title: const Text('启动时同步'),
                  subtitle: Text(
                    '不阻塞启动：应用始终先显示本地数据',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: autoResume,
                  onChanged: !canAuto || _busy
                      ? null
                      : (value) => _setAutoOption('autoOnResume', value),
                  title: const Text('恢复前台时同步'),
                  subtitle: Text(
                    '最多每分钟一次，失败退避 5–60 分钟，重启后仍保留',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                SwitchListTile(
                  value: _fields['autoOnChange'] == 'true',
                  onChanged: !canAuto || _busy
                      ? null
                      : (value) => _setAutoOption('autoOnChange', value),
                  title: const Text('数据变化后自动同步'),
                  subtitle: const Text('停止修改 20 秒后检查；持续背词不会每次请求网络'),
                ),
                SwitchListTile(
                  value: _fields['autoAfterSession'] == 'true',
                  onChanged: !canAuto || _busy
                      ? null
                      : (value) => _setAutoOption('autoAfterSession', value),
                  title: const Text('本轮学习结束后同步'),
                  subtitle: const Text('遵守同一冷却与退避规则，不阻塞学习'),
                ),
                if (!canAuto)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('本地文件仅用于手动合并；自动双向同步请选择支持条件写入的远程目标。'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _runTest,
                        icon: const Icon(Icons.wifi_tethering),
                        label: const Text('测试连接'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _syncNow,
                        icon: const Icon(Icons.sync),
                        label: Text(_busy ? '同步中…' : '立即同步'),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : _exportBackup,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('导出本地备份'),
                      ),
                    ],
                  ),
                ),
                if (_testResult != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              _testResult!.ok
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              size: AppDimens.iconSizeSmall,
                              color: _testResult!.ok
                                  ? AppColors.known
                                  : AppColors.unknown,
                            ),
                            AppSpacing.w8,
                            Expanded(
                              child: Text(
                                _testResult!.message,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        for (final String detail in _testResult!.details)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              detail.startsWith('NO_CONDITIONAL_WRITE')
                                  ? detail.replaceFirst(
                                      'NO_CONDITIONAL_WRITE:',
                                      '注意：',
                                    )
                                  : '· $detail',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            SectionHeader(title: '同步状态'),
            SettingsGroup(
              children: <Widget>[
                SettingsTile(
                  leading: const Icon(Icons.schedule),
                  title: '最近同步时间',
                  subtitle: _lastSyncAt == null
                      ? '从未同步'
                      : formatDateTime(_lastSyncAt!),
                ),
                SettingsTile(
                  leading: const Icon(Icons.info_outline),
                  title: '最近同步结果',
                  subtitle: _lastResult ?? '—',
                ),
                SettingsTile(
                  leading: Icon(
                    _pendingChanges == true
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_done_outlined,
                  ),
                  title: '本地待同步修改',
                  subtitle: _pendingChanges == true ? '有本地修改尚未上传' : '本地与上次同步一致',
                ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Text(_status!, style: theme.textTheme.bodySmall),
                  ),
                for (final String note in _syncNotes)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('· $note', style: theme.textTheme.bodySmall),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '合并规则：单词按拼写去重；作答记录按 ID 去重并重算学习状态；'
                        '词书关联带删除标记，旧备份不会让已删除内容复活。'
                        '同步不会删除本地笔记，也不会覆盖较新的学习记录。',
                        style: theme.textTheme.bodySmall,
                      ),
                      AppSpacing.h8,
                      Text(
                        '凭据只保存在系统安全存储（钥匙串/Keystore），'
                        '不会写入数据库、备份文件或日志。',
                        style: theme.textTheme.bodySmall,
                      ),
                      AppSpacing.h8,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _busy ? null : _disconnect,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.unknown,
                          ),
                          icon: const Icon(Icons.link_off),
                          label: const Text('解除同步配置'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _configGroup() {
    final ThemeData theme = Theme.of(context);
    Widget plainField(
      String key,
      String label, {
      String hint = '',
      String fallback = '',
    }) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextFormField(
          initialValue: _field(key, fallback: fallback),
          decoration: InputDecoration(labelText: label, hintText: hint),
          onChanged: (String value) => _fields[key] = value,
        ),
      );
    }

    switch (_provider) {
      case 'local-file':
        return SettingsGroup(
          children: <Widget>[
            plainField(
              'path',
              '同步文件路径',
              hint: '/Users/you/MaterialWord/materialword-data.json',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Android / iOS 无法永久授权任意外部路径：请使用应用目录内的文件，'
                '或改用「导出到… / 导入并合并」手动模式。',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );
      case 'github':
        return SettingsGroup(
          children: <Widget>[
            plainField('owner', '仓库 owner', hint: 'your-name'),
            plainField('repo', '仓库名', hint: 'materialword-data'),
            plainField('branch', '分支', fallback: 'main'),
            plainField('path', '数据文件路径', fallback: 'materialword-data.json'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _githubToken,
                obscureText: true,
                onChanged: (_) {
                  if (!_allowSecretEdit) {
                    setState(() => _allowSecretEdit = true);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Fine-grained Personal Access Token',
                  helperText: '仅需目标仓库的 Contents 读写权限；保存在系统安全存储',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '不要使用程序源码仓库：学习数据属于个人隐私。'
                '如果仓库是公开的，连接测试会给出提醒。',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );
      case 'webdav':
        return SettingsGroup(
          children: <Widget>[
            plainField(
              'url',
              '服务器地址（HTTPS）',
              hint: 'https://dav.example.com/remote.php/dav/files/me/',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _webdavUser,
                decoration: const InputDecoration(labelText: '用户名'),
                onChanged: (String value) => _fields['user'] = value,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _webdavPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码 / 服务专用密码',
                  helperText: '保存在系统安全存储；留空表示保持不变',
                ),
                onChanged: (_) {
                  if (!_allowSecretEdit) {
                    setState(() => _allowSecretEdit = true);
                  }
                },
              ),
            ),
            plainField('dir', '远程目录', fallback: 'materialword'),
            plainField('file', '数据文件名', fallback: 'materialword-data.json'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '只使用 HTTPS，不会关闭证书校验；认证信息不会跟随跨域重定向。'
                '如果服务器不返回 ETag，将无法检测并发修改，自动同步可能产生冲突提示。',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
