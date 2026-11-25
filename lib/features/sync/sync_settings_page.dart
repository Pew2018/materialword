import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/time_utils.dart';
import '../../services/backup_files.dart';
import '../../services/sync/conflict_resolution_service.dart';
import '../../services/sync/conflict_store.dart';
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
          description: '推荐使用一个单独的数据仓库，只存放学习数据',
        ),
        (id: 'webdav', label: 'WebDAV', description: '自建或支持安全多设备同步的 WebDAV 目录'),
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
  bool _paused = false;
  String? _pausedReason;
  List<StoredSyncConflict> _conflicts = const <StoredSyncConflict>[];

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
    final bool paused = await settings.syncPaused();
    final String? pausedReason = await settings.syncPausedReason();
    final List<StoredSyncConflict> conflicts = await ref
        .read(syncConflictStoreProvider)
        .list();
    if (!mounted) return;
    setState(() {
      _provider = (config?['provider'] as String?) ?? 'none';
      // A provider is configured but its secret came back empty: the item was
      // written under a different signature / Keychain class, or the Keychain
      // denied access. Either way the fix is the same — type it again.
      if (credentialNotice == null) {
        if (_provider == 'github' && (token?.isEmpty ?? true)) {
          credentialNotice = '未读取到已保存的访问令牌，请重新输入后再同步。';
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
      _paused = paused;
      _pausedReason = pausedReason;
      _conflicts = conflicts;
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
            _credentialNotice = '${e.reason}。凭据没有保存，请重新输入；离线学习不受影响。';
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
      if (provider is GitHubSyncProvider) {
        provider.clearCapturedCredentials();
        provider.close();
      }
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
            '首次同步会把远程数据与本机数据合并，'
            '不会用远程数据覆盖本地学习进度，也不会删除本地单词。\n\n继续吗？',
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

  /// Explicit user decision after a point-in-time restore: merge the remote into
  /// this device (never the other way round automatically).
  Future<void> _mergeRemoteAfterRestore() async {
    if (_busy) return;
    final bool ok = await confirmDialog(
      context,
      title: '合并远端数据？',
      message:
          '会解除同步暂停，并把远端设备的数据合并到本机（只补充缺失内容，'
          '不删除本机内容）。合并结果会随后上传，因此远端会包含本机恢复后的数据。',
      confirmLabel: '合并',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final settings = ref.read(settingsRepositoryProvider);
      await settings.setSyncPaused(false);
      final provider = ref
          .read(syncCoordinatorProvider)
          .providerFromConfig(await settings.syncConfig());
      if (provider == null) {
        setState(() {
          _busy = false;
          _error = '尚未配置同步目标';
        });
        await _load();
        return;
      }
      final report = await ref
          .read(syncCoordinatorProvider)
          .sync(provider, resumeAfterRestore: true);
      ref.invalidate(todayProgressProvider);
      ref.invalidate(bookSummariesProvider);
      ref.invalidate(statisticsProvider);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = report.message;
      });
      await _load();
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      await _load();
    }
  }

  Future<void> _stayPaused() async {
    setState(() => _status = '同步保持暂停，远端数据未被修改');
    await _load();
  }

  /// The remote file disappeared after a successful sync. Re-creating it uploads
  /// the whole local dataset, so it needs an explicit confirmation.
  Future<void> _recreateRemote() async {
    final Map<String, Object?>? config = await ref
        .read(settingsRepositoryProvider)
        .syncConfig();
    if (!mounted) return;
    final provider = ref
        .read(syncCoordinatorProvider)
        .providerFromConfig(config);
    if (provider == null) return;
    final bool ok = await confirmDialog(
      context,
      title: '重新创建远端数据？',
      message:
          '远端数据文件已不存在（可能是仓库文件被删除，或权限/路径变化）。'
          '继续会把本机当前数据重新上传到该位置。\n\n'
          '如果你并不想删除远端数据，请先取消并检查仓库与配置。',
      confirmLabel: '重新上传',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final report = await ref
          .read(syncCoordinatorProvider)
          .sync(provider, allowRemoteRecreate: true);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = report.message;
        _error = null;
      });
      await _load();
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  /// Restoring the discarded value is a **new normal edit**, so the existing
  /// field-version rules decide who wins on the next sync. The field-by-field
  /// decision lives in [SyncConflictResolutionService]; this method only
  /// confirms, calls it and reports.
  Future<void> _restoreConflict(StoredSyncConflict conflict) async {
    final bool ok = await confirmDialog(
      context,
      title: '恢复被覆盖的内容？',
      message:
          '「${conflict.label.isEmpty ? conflict.entityId : conflict.label}」的 '
          '${_fieldLabel(conflict.field)} 将改回：\n'
          '${_displayValue(conflict.field, conflict.discardedValue)}\n\n'
          '这会作为一次新的修改同步到其他设备。',
      confirmLabel: '恢复',
    );
    if (!ok || !mounted) return;
    try {
      final outcome = await ref
          .read(syncConflictResolutionProvider)
          .restoreDiscardedValue(conflict, now: ref.read(clockProvider).now());
      ref.invalidate(todayProgressProvider);
      ref.invalidate(bookSummariesProvider);
      if (!mounted) return;
      setState(() {
        _status =
            '已恢复「${_fieldLabel(outcome.field)}」'
            '（将作为一次新的编辑同步）';
        _error = null;
      });
      await _load();
    } on ConflictRestoreException catch (e) {
      if (!mounted) return;
      setState(() => _error = '恢复失败：${e.message}（冲突记录已保留）');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '恢复失败：$e（冲突记录已保留）');
    }
  }

  Future<void> _dismissConflict(StoredSyncConflict conflict) async {
    await ref.read(syncConflictStoreProvider).dismiss(conflict.id);
    await _load();
  }

  String _fieldLabel(String field) => switch (field) {
    'word' => '单词',
    'phonetic' => '音标',
    'partOfSpeech' => '词性',
    'translation' => '释义',
    'definition' => '英文释义',
    'example' => '例句',
    'phrase' => '短语',
    'note' => '笔记',
    'source' => '来源',
    'examTags' => '考试标签',
    'bncRank' => 'BNC 词频',
    'frqRank' => 'COCA 词频',
    'deletedAt' => '删除状态',
    'name' => '词书名称',
    'description' => '词书描述',
    'sourceType' => '词书来源类型',
    'sourceUrl' => '词书来源链接',
    _ => field,
  };

  String _displayValue(String field, Object? value) {
    if (field == 'deletedAt') return value == null ? '未删除' : '已删除';
    if (value == null) return '（空）';
    if (value is String) return value.isEmpty ? '（空）' : value;
    return '$value';
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
      title: '关闭同步',
      message:
          '本机保存的同步设置和凭据（访问令牌 / 密码）会被删除。远程数据不会被删除，'
          '学习记录仍然保存在本机。',
      confirmLabel: '关闭',
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
      _status = '已关闭同步';
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
      showMessage(context, '切换同步方式后请重新测试连接。');
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

    /// The remote file disappeared after a successful sync. Re-creating it is a
    /// deliberate user decision, so the affordance must appear for an automatic
    /// run's result too — not only for a manual one that set [_error].
    final bool remoteMissing =
        (_error ?? '').contains('远程数据文件已被删除') ||
        (_lastResult ?? '').contains('远程数据文件已被删除');

    return Scaffold(
      appBar: ClassicAppBar(title: const Text('数据同步')),
      body: ContentColumn(
        child: ListView(
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
            if (_paused)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: AppColors.hazy.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('同步已暂停', style: theme.textTheme.titleSmall),
                        AppSpacing.h4,
                        Text(
                          _pausedReason ?? '本机数据来自历史恢复。确认远端如何处理之前，自动同步不会运行。',
                          style: theme.textTheme.bodySmall,
                        ),
                        AppSpacing.h8,
                        Wrap(
                          spacing: 8,
                          children: <Widget>[
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : _mergeRemoteAfterRestore,
                              child: const Text('合并远端数据'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _stayPaused,
                              child: const Text('保持本机状态'),
                            ),
                          ],
                        ),
                        Text(
                          '不会自动用任一方的数据覆盖另一方：合并只补充缺失内容。',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SectionHeader(title: '同步方式'),
            SettingsGroup(
              children: <Widget>[
                for (final ({String id, String label, String description})
                    option
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
                  SettingsSwitchTile(
                    value: autoStart,
                    icon: Icons.play_circle_outline,
                    title: '启动时同步',
                    subtitle: '不阻塞启动：应用始终先显示本地数据',
                    onChanged: !canAuto || _busy
                        ? null
                        : (value) => _setAutoOption('autoOnStart', value),
                  ),
                  SettingsSwitchTile(
                    value: autoResume,
                    icon: Icons.refresh,
                    title: '返回应用时同步',
                    subtitle: '切回应用后自动检查更新；失败时会稍后重试',
                    onChanged: !canAuto || _busy
                        ? null
                        : (value) => _setAutoOption('autoOnResume', value),
                  ),
                  SettingsSwitchTile(
                    value: _fields['autoOnChange'] == 'true',
                    icon: Icons.edit_note,
                    title: '数据变化后自动同步',
                    subtitle: '停止操作约 20 秒后自动同步，不会在每次作答后立即联网',
                    onChanged: !canAuto || _busy
                        ? null
                        : (value) => _setAutoOption('autoOnChange', value),
                  ),
                  SettingsSwitchTile(
                    value: _fields['autoAfterSession'] == 'true',
                    icon: Icons.school_outlined,
                    title: '本轮学习结束后同步',
                    subtitle: '学习结束后自动同步，不影响结束流程',
                    onChanged: !canAuto || _busy
                        ? null
                        : (value) => _setAutoOption('autoAfterSession', value),
                  ),
                  if (!canAuto)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '本地文件只用于手动合并；需要自动同步时请选择 GitHub 私有仓库或 WebDAV。',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        // One primary action per screen: 立即同步 is the filled
                        // button, the other two are secondary and keep the same
                        // outline treatment so a wrapped row never looks like a
                        // stray line of accent text.
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
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _exportBackup,
                          icon: const Icon(Icons.save_alt),
                          label: const Text('导出备份'),
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
              if (_conflicts.isNotEmpty) ...<Widget>[
                SectionHeader(title: '被覆盖的内容（最多 50 条）'),
                SettingsGroup(
                  children: <Widget>[
                    for (final StoredSyncConflict conflict in _conflicts)
                      ListTile(
                        dense: true,
                        title: Text(
                          '${conflict.label.isEmpty ? conflict.entityId : conflict.label}'
                          ' · ${_fieldLabel(conflict.field)}',
                        ),
                        subtitle: Text(
                          '保留：${_displayValue(conflict.field, conflict.adoptedValue)}\n'
                          '被覆盖：${_displayValue(conflict.field, conflict.discardedValue)}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            // A field this build cannot write back must not offer a
                            // button that would only pretend to restore.
                            if (SyncConflictResolutionService.canRestore(
                              conflict,
                            ))
                              IconButton(
                                tooltip: '恢复被覆盖的内容',
                                icon: const Icon(Icons.undo),
                                onPressed: _busy
                                    ? null
                                    : () => _restoreConflict(conflict),
                              )
                            else
                              const Tooltip(
                                message: '这一项仅用于诊断，无法恢复',
                                child: Icon(Icons.info_outline),
                              ),
                            IconButton(
                              tooltip: '忽略这条记录',
                              icon: const Icon(Icons.close),
                              onPressed: _busy
                                  ? null
                                  : () => _dismissConflict(conflict),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    '另一台设备也修改了同一项内容。MaterialWord 保留了较新的版本，'
                    '把另一份内容留在这里备用。恢复会把它改回来，并作为一次新的修改同步到其他设备；'
                    '没有恢复按钮的记录只用于排查问题。',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
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
                    title: '待同步的更改',
                    subtitle: _pendingChanges == true
                        ? '有本地修改尚未上传'
                        : '本地与上次同步一致',
                  ),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(_status!, style: theme.textTheme.bodySmall),
                    ),
                  if (remoteMissing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: OutlinedButton(
                        onPressed: _busy ? null : _recreateRemote,
                        child: const Text('重新创建远端数据…'),
                      ),
                    ),
                  for (final String note in _syncNotes)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('· $note', style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
              // Everything below is deliberately collapsed: the main page has
              // to read like a settings screen, not like a protocol document.
              // Deduplication keys, delete markers, tie-breaking and the
              // credential store live here, one tap away.
              ExpansionTile(
                leading: const Icon(
                  Icons.help_outline,
                  size: AppDimens.iconSize,
                ),
                title: Text('同步与合并说明', style: theme.textTheme.bodyLarge),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: <Widget>[
                  Text(
                    '远程数据和本机数据会合并，不会互相覆盖。\n'
                    '· 同一个单词只保留一条记录；\n'
                    '· 每次作答都单独保留，合并后重新计算学习状态；\n'
                    '· 已经删除的单词和词书不会被旧备份恢复；\n'
                    '· 两台设备改了同一项时，保留较新的一次，另一份留在'
                    '「被覆盖的内容」里，可以随时改回来。\n'
                    '令牌与密码只保存在本机系统安全存储（钥匙串 / Keystore）中，'
                    '不会写进数据库、备份文件或日志。',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _disconnect,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.unknown,
                    ),
                    icon: const Icon(Icons.link_off),
                    label: const Text('关闭同步'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _configGroup() {
    final ThemeData theme = Theme.of(context);

    /// One field style for every connection setting: same margins, same
    /// content padding (from the theme), same label/helper scale. The business
    /// controllers stay where they are — this is only the shell.
    Widget field(
      String key,
      String label, {
      String hint = '',
      String fallback = '',
    }) {
      return _SyncTextField(
        label: label,
        hint: hint,
        initialValue: _field(key, fallback: fallback),
        onChanged: (String value) => _fields[key] = value,
      );
    }

    Widget secretField(
      String label, {
      required TextEditingController controller,
      String? helper,
      ValueChanged<String>? onChanged,
    }) {
      return _SyncTextField(
        label: label,
        helper: helper,
        controller: controller,
        obscureText: true,
        onChanged: (String value) {
          onChanged?.call(value);
          if (!_allowSecretEdit) setState(() => _allowSecretEdit = true);
        },
      );
    }

    switch (_provider) {
      case 'local-file':
        return SettingsGroup(
          children: <Widget>[
            field(
              'path',
              '同步文件路径',
              hint: '/Users/you/MaterialWord/materialword-data.json',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '手机上无法长期访问任意文件夹，请使用应用内的文件，'
                '或改用「备份与恢复」中的导出 / 导入。',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );
      case 'github':
        return SettingsGroup(
          children: <Widget>[
            field('owner', 'GitHub 用户名或组织', hint: 'your-name'),
            field('repo', '仓库名', hint: 'materialword-data'),
            field('branch', '分支', fallback: 'main'),
            field('path', '数据文件路径', fallback: 'materialword-data.json'),
            secretField(
              '访问令牌（Access Token）',
              controller: _githubToken,
              helper: '用于访问你的私有仓库，仅保存在本机系统安全存储中',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '建议新建一个专用私有仓库保存学习数据，请勿使用公开仓库。',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );
      case 'webdav':
        return SettingsGroup(
          children: <Widget>[
            field(
              'url',
              '服务器地址（HTTPS）',
              hint: 'https://dav.example.com/remote.php/dav/files/me/',
            ),
            _SyncTextField(
              label: '用户名',
              controller: _webdavUser,
              onChanged: (String value) => _fields['user'] = value,
            ),
            secretField(
              '密码 / 服务专用密码',
              controller: _webdavPassword,
              helper: '留空表示保持不变',
            ),
            field('dir', '远程目录', fallback: 'materialword'),
            field('file', '数据文件名', fallback: 'materialword-data.json'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '只使用 HTTPS，不会关闭证书校验。'
                '如果服务器无法可靠地处理多设备同时修改，可以用「立即同步」手动合并。',
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

/// One visual shell for every connection field on this page.
///
/// The four inputs used to be a mix of `TextFormField` and `TextField` with
/// hand-written paddings, so the GitHub token sat at a different height than
/// the fields above it. This wrapper fixes the outer margins, the content
/// padding (from the theme), the label/helper scale and the border; the
/// controllers and the save logic stay exactly where they were.
class _SyncTextField extends StatelessWidget {
  const _SyncTextField({
    required this.label,
    this.initialValue,
    this.controller,
    this.hint,
    this.helper,
    this.obscureText = false,
    this.onChanged,
  }) : assert(
         controller == null || initialValue == null,
         'a field is either uncontrolled or driven by a controller',
       );

  final String label;
  final String? initialValue;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final InputDecoration decoration = InputDecoration(
      labelText: label,
      hintText: (hint ?? '').isEmpty ? null : hint,
      helperText: helper,
      helperMaxLines: 2,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.gutter,
        8,
        AppDimens.gutter,
        8,
      ),
      child: controller == null
          ? TextFormField(
              initialValue: initialValue ?? '',
              obscureText: obscureText,
              decoration: decoration,
              onChanged: onChanged,
            )
          : TextField(
              controller: controller,
              obscureText: obscureText,
              decoration: decoration,
              onChanged: onChanged,
            ),
    );
  }
}
