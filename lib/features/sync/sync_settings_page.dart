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
import '../../l10n/l10n.dart';
import '../../l10n/sync_labels.dart';
import '../../shared/widgets/common.dart';
import '../settings/diagnostics_page.dart';
import 'webdav_directory_picker.dart';

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
  /// Built per language: the ids are stable, the labels are not.
  static List<({String id, String label, String description})> _optionsOf(
    AppLocalizations l10n,
  ) => <({String id, String label, String description})>[
    (id: 'none', label: l10n.syncOff, description: l10n.syncOffHint),
    (id: 'local-file', label: l10n.localFile, description: l10n.localFileHint),
    (id: 'github', label: l10n.githubPrivateRepo, description: l10n.githubHint),
    (id: 'webdav', label: 'WebDAV', description: l10n.webdavHint),
  ];

  String _provider = 'none';
  String _savedToken = '', _savedUser = '';
  final Map<String, String> _fields = <String, String>{};
  final TextEditingController _githubToken = TextEditingController();
  final TextEditingController _webdavUser = TextEditingController();
  final TextEditingController _webdavPassword = TextEditingController();
  // Driven by a controller because the folder picker writes into it: an
  // uncontrolled field would keep showing the old path after a selection.
  final TextEditingController _webdavDir = TextEditingController();

  bool _loaded = false;
  bool _busy = false;
  bool _allowSecretEdit = false;
  String? _status;
  String? _error;

  /// Last proven capability for the configured WebDAV target. Comes either from
  /// an explicit 测试连接 in this session or from the per-target cache; it is
  /// what the status icon, the automatic-sync gate and 立即同步 consult.
  SyncCapability? _capability;
  int _verificationGeneration = 0;

  /// Shown when the Keychain exists but could not be read (re-signed build, new
  /// Keychain class, locked keychain). The user is asked to type the secret
  /// again; nothing is ever stored in plain text as a fallback.
  String? _credentialNotice;
  DateTime? _lastSyncAt;
  String? _lastResult;

  /// Set when a sync failed because the remote file disappeared. Drives the
  /// "re-upload" affordance without parsing any user-visible text.
  bool _remoteMissing = false;
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
    _webdavDir.dispose();
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
    bool credentialsUnavailable = false;
    try {
      await CredentialStore.exclusive(() async {
        token = await credentials.read(CredentialKeys.githubToken);
        user = await credentials.read(CredentialKeys.webdavUsername);
        hasPassword =
            (await credentials.read(CredentialKeys.webdavPassword)) != null;
      });
    } on CredentialStoreUnavailable {
      // The stored secrets are unreadable, not absent: ask the user to type
      // them again instead of pretending nothing was saved.
      credentialsUnavailable = true;
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
      String? credentialNotice;
      if (credentialsUnavailable) {
        credentialNotice = context.l10n.credentialsUnavailable;
      } else {
        if (_provider == 'github' && (token?.isEmpty ?? true)) {
          credentialNotice = context.l10n.tokenMissing;
        } else if (_provider == 'webdav' && !hasPassword) {
          credentialNotice = context.l10n.passwordMissing;
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
      // Suggested default for a brand-new WebDAV configuration. An explicitly
      // emptied field stays empty, which means "the base collection itself".
      if (_provider == 'webdav' && _fields['dir'] == null) {
        _fields['dir'] = 'materialword';
      }
      _githubToken.text = token ?? '';
      _webdavUser.text = user ?? '';
      _webdavDir.text = _field('dir');
      _webdavPassword.text = hasPassword ? '••••••••' : '';
      _lastSyncAt = lastAt;
      _lastResult = lastResult;
      _pendingChanges = pending;
      _paused = paused;
      _pausedReason = pausedReason;
      _conflicts = conflicts;
      _loaded = true;
    });
    await _refreshCapability();
  }

  /// Reads the remembered capability for the *saved* target.
  ///
  /// Nothing is probed here: opening the page must not cost a dozen HTTP
  /// requests. A verified result from an earlier session is enough to keep the
  /// status icon honest until something invalidates it.
  Future<void> _refreshCapability() async {
    if (_provider != 'webdav') {
      if (mounted && _capability != null) setState(() => _capability = null);
      return;
    }
    final SyncProvider? provider = _buildProvider();
    if (provider is! WebDavSyncProvider) return;
    final int generation = _verificationGeneration;
    try {
      final SyncCapability? cached = await ref
          .read(syncCoordinatorProvider)
          .cachedCapability(provider);
      if (!mounted || generation != _verificationGeneration) return;
      setState(() => _capability = cached);
    } catch (_) {
      // A capability lookup must never stop the page from loading.
    }
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
      showMessage(context, context.l10n.draftNotSaved);
      return;
    }
    try {
      final saved = await settings.updateSyncAutoOption(
        key,
        value,
        expected: config,
      );
      if (!saved && mounted) {
        showMessage(context, context.l10n.configChanged, error: true);
      } else if (saved &&
          value &&
          mounted &&
          _provider == 'webdav' &&
          !(_capability?.safeBidirectionalSync ?? false)) {
        // The preference is kept, but the promise is not: automatic sync will
        // not run until the server passes the safety verification.
        showMessage(context, context.l10n.preferencesSaved);
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, context.l10n.preferencesSaveFailed, error: true);
      }
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
          client: ref.read(syncHttpClientProvider),
          tokenOverride: draft && _githubToken.text.trim().isNotEmpty
              ? _githubToken.text.trim()
              : null,
        );
      case 'webdav':
        return WebDavSyncProvider(
          baseUrl: _field('url'),
          remoteDir: _field('dir'),
          fileName: _field('file', fallback: 'materialword-data.json'),
          identityEpoch: _field('credentialEpoch'),
          credentials: ref.read(credentialStoreProvider),
          client: ref.read(syncHttpClientProvider),
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
      } on CredentialStoreUnavailable {
        if (mounted) {
          setState(() {
            _credentialNotice = context.l10n.credentialsNotStored;
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
          ..['dir'] = _field('dir')
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
    final int generation = ++_verificationGeneration;
    final bool savedCredentials = !_draftCredentialsChanged;
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
      final SyncCapability? capability = result.capability;
      if (mounted &&
          generation == _verificationGeneration &&
          savedCredentials &&
          capability != null &&
          provider is WebDavSyncProvider) {
        // Remember what was just proven, so automatic sync can trust it and the
        // next page load does not have to probe again.
        await ref
            .read(syncCoordinatorProvider)
            .rememberCapability(provider, capability);
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (generation == _verificationGeneration) {
          _testResult = result;
          if (capability != null) _capability = capability;
        }
      });
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (generation == _verificationGeneration) {
          _error = _describeSyncError(e);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (generation == _verificationGeneration) {
          _error = context.l10n.connectionTestFailed;
        }
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

  /// Browses the server instead of guessing a path.
  ///
  /// On 坚果云 the folder shown in Finder and the WebDAV path are not the same
  /// string; letting the user pick the real folder removes that guesswork.
  Future<void> _pickRemoteDirectory() async {
    final SyncProvider? provider = _buildProvider(draft: true);
    if (provider is! WebDavSyncProvider) return;
    setState(() => _busy = true);
    try {
      await provider.captureCredentials();
      if (!mounted) return;
      final String? chosen = await showWebDavDirectoryPicker(
        context: context,
        provider: provider,
        initialPath: _field('dir'),
      );
      if (chosen == null || !mounted) return;
      setState(() {
        _verificationGeneration++;
        _fields['dir'] = chosen;
        _webdavDir.text = chosen;
        _testResult = null;
        _capability = null;
        _status = context.l10n.remoteFolderChosen(
          chosen.isEmpty ? context.l10n.serverRootFolder : chosen,
        );
      });
    } on SyncException {
      if (mounted) {
        showMessage(context, context.l10n.cannotBrowseRemote, error: true);
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, context.l10n.cannotBrowseRemote, error: true);
      }
    } finally {
      provider.clearCapturedCredentials();
      provider.close();
      if (mounted) setState(() => _busy = false);
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
      setState(() => _error = context.l10n.syncInProgress);
      return;
    }

    if (provider is WebDavSyncProvider) {
      final SyncCapability? capability = _capability;
      if (capability != null && !capability.safeBidirectionalSync) {
        await _explainUnsafeTarget(capability);
        return;
      }
    }

    if (!await coordinator.hasSyncedTarget(provider)) {
      if (!mounted) return;
      final bool ok = await confirmDialog(
        context,
        title: context.l10n.firstSyncTitle,
        message: context.l10n.firstSyncBody,
        confirmLabel: context.l10n.startMerging,
      );
      if (!ok) return;
    }

    await _runSync(provider);
  }

  /// What to do when the server cannot protect concurrent writes.
  Future<void> _explainUnsafeTarget(SyncCapability capability) async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(syncCapabilitySummary(context.l10n, capability)),
        scrollable: true,
        content: Text(context.l10n.unsafeServerBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('test'),
            child: Text(context.l10n.retestConnection),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('export'),
            child: Text(context.l10n.exportBackup),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'test') {
      await _runTest();
    } else if (choice == 'export') {
      await _exportBackup();
    }
  }

  Future<void> _runSync(
    SyncProvider provider, {
    bool initializeEmptyRemote = false,
    bool allowRemoteRecreate = false,
  }) async {
    final SyncCoordinator coordinator = ref.read(syncCoordinatorProvider);
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
        initializeEmptyRemote: initializeEmptyRemote,
        allowRemoteRecreate: allowRemoteRecreate,
        onProgress: (SyncStage stage, String detail) {
          if (!mounted) return;
          // The stage is localised; `detail` is a developer string and stays in
          // the diagnostics log only.
          setState(() => _status = syncStageLabel(context.l10n, stage));
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
    } on SyncEmptyRemoteException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = e.message;
      });
      await _offerEmptyRemoteInitialization(e, provider);
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _describeSyncError(e);
        _status = null;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Never the raw exception: the code carries the meaning, the detail goes
        // to diagnostics.
        _remoteMissing = e is SyncRemoteMissingException;
        _error = _remoteMissing
            ? context.l10n.remoteFileMissingNotice
            : context.l10n.syncFailed;
      });
    }
  }

  /// The remote document exists but holds 0 bytes.
  ///
  /// Initializing is a *write to an existing file*, so it needs a confirmation
  /// and the file's own ETag (`If-Match`). The wording differs for a file that
  /// was synced before: that is data loss, not a first run.
  Future<void> _offerEmptyRemoteInitialization(
    SyncEmptyRemoteException error,
    SyncProvider provider,
  ) async {
    if (!mounted) return;
    final bool ok = await confirmDialog(
      context,
      title: error.previouslySynced
          ? context.l10n.remoteBecameEmpty
          : context.l10n.remoteIsEmpty,
      message: error.previouslySynced
          ? '${context.l10n.remoteEmptiedBody}\n\n${context.l10n.remoteEmptiedConfirm}'
          : context.l10n.emptyInitBody,
      confirmLabel: context.l10n.initialiseAndSync,
      destructive: error.previouslySynced,
    );
    if (!ok || !mounted) return;
    await _runSync(provider, initializeEmptyRemote: true);
  }

  /// Explicit user decision after a point-in-time restore: merge the remote into
  /// this device (never the other way round automatically).
  Future<void> _mergeRemoteAfterRestore() async {
    if (_busy) return;
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.mergeRemoteTitle,
      message: context.l10n.mergeRemoteBody,
      confirmLabel: context.l10n.mergeOnlyAddsShort,
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
          _error = context.l10n.noTargetConfigured;
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
        _error = _describeSyncError(e);
      });
      await _load();
    }
  }

  Future<void> _stayPaused() async {
    setState(() => _status = context.l10n.syncStaysPausedRemoteUntouched);
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
      title: context.l10n.recreateRemoteTitle,
      message: context.l10n.recreateRemoteBody,
      confirmLabel: context.l10n.reupload,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _runSync(provider, allowRemoteRecreate: true);
  }

  /// Restoring the discarded value is a **new normal edit**, so the existing
  /// field-version rules decide who wins on the next sync. The field-by-field
  /// decision lives in [SyncConflictResolutionService]; this method only
  /// confirms, calls it and reports.
  Future<void> _restoreConflict(StoredSyncConflict conflict) async {
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.restoreConflictTitle,
      message:
          '${context.l10n.restoreConflictBody(conflict.label.isEmpty ? conflict.entityId : conflict.label, _fieldLabel(conflict.field))}\n\n'
          '${_displayValue(conflict.field, conflict.discardedValue)}',
      confirmLabel: context.l10n.commonRestore,
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
            '${context.l10n.restoredField(_fieldLabel(outcome.field))} '
            '${context.l10n.restoredAsNewEdit}';
        _error = null;
      });
      await _load();
    } on ConflictRestoreException {
      if (!mounted) return;
      setState(() => _error = context.l10n.restoreFailedKept);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.restoreFailedKept);
    }
  }

  Future<void> _dismissConflict(StoredSyncConflict conflict) async {
    await ref.read(syncConflictStoreProvider).dismiss(conflict.id);
    await _load();
  }

  String _fieldLabel(String field) => switch (field) {
    'word' => context.l10n.fieldWord,
    'phonetic' => context.l10n.fieldPhonetic,
    'partOfSpeech' => context.l10n.fieldPos,
    'translation' => context.l10n.fieldTranslation,
    'definition' => context.l10n.fieldDefinition,
    'example' => context.l10n.fieldExample,
    'phrase' => context.l10n.fieldPhrase,
    'note' => context.l10n.fieldNote,
    'source' => context.l10n.fieldSource,
    'examTags' => context.l10n.fieldExamTags,
    'bncRank' => context.l10n.fieldBnc,
    'frqRank' => context.l10n.fieldCoca,
    'deletedAt' => context.l10n.fieldDeleted,
    'name' => context.l10n.fieldBookName,
    'description' => context.l10n.fieldBookDescription,
    'sourceType' => context.l10n.fieldBookSourceType,
    'sourceUrl' => context.l10n.fieldBookSourceUrl,
    _ => field,
  };

  String _displayValue(String field, Object? value) {
    if (field == 'deletedAt') {
      return value == null ? context.l10n.notDeleted : context.l10n.deleted;
    }
    if (value == null) return context.l10n.emptyValue;
    if (value is String) return value.isEmpty ? context.l10n.emptyValue : value;
    return '$value';
  }

  Future<void> _exportBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await BackupFiles(ref.read(backupServiceProvider))
          .export(now: ref.read(clockProvider).now());
      if (saved && mounted) showMessage(context, context.l10n.backupExported);
    } catch (_) {
      if (mounted) {
        showMessage(context, context.l10n.exportPickFailed, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Turns a sync failure into a user sentence.
  ///
  /// The exception's own message is a developer-facing string; it is logged for
  /// diagnostics and never shown, so the interface stays accurate in both
  /// languages and a partial run is never reported as a clean success.
  String _describeSyncError(Object error) {
    if (error is SyncCapabilityException) {
      return syncCapabilitySummary(context.l10n, error.capability);
    }
    if (error is SyncRemoteMissingException) {
      _remoteMissing = true;
      return context.l10n.remoteFileMissingNotice;
    }
    if (error is SyncPartialException) {
      return context.l10n.syncUploadPending;
    }
    if (error is SyncConflictException) {
      return context.l10n.syncConflictRetry;
    }
    if (error is SyncDataException) {
      return context.l10n.syncFileUnreadable;
    }
    return context.l10n.syncFailed;
  }

  Future<void> _disconnect() async {
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.turnOffSync,
      message: context.l10n.turnOffSyncBody,
      confirmLabel: context.l10n.commonClose,
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
      _verificationGeneration++;
      _provider = 'none';
      _capability = null;
      _fields.clear();
      _githubToken.clear();
      _webdavUser.clear();
      _webdavPassword.clear();
      _status = context.l10n.syncTurnedOff;
      _testResult = null;
    });
  }

  void _selectProvider(String id) {
    if (id == _provider) return;
    setState(() {
      _verificationGeneration++;
      _provider = id;
      _capability = null;
      _testResult = null;
      _status = null;
      _error = null;
    });
    if (_provider != 'none') {
      showMessage(context, context.l10n.retestAfterSwitch);
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
    // A structured flag, not a substring of a translated sentence: the text
    // changes with the language, the meaning does not.
    final bool remoteMissing = _remoteMissing;

    return Scaffold(
      appBar: ClassicAppBar(title: Text(context.l10n.syncTitle)),
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
                        Text(
                          context.l10n.syncPausedTitle,
                          style: theme.textTheme.titleSmall,
                        ),
                        AppSpacing.h4,
                        Text(
                          _pausedReason ?? context.l10n.syncPausedRestoreBody,
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
                              child: Text(context.l10n.mergeRemote),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _stayPaused,
                              child: Text(context.l10n.keepLocal),
                            ),
                          ],
                        ),
                        Text(
                          context.l10n.mergeOnlyAdds,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SectionHeader(title: context.l10n.syncMethod),
            SettingsGroup(
              children: <Widget>[
                for (final ({String id, String label, String description})
                    option
                    in _optionsOf(context.l10n))
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
              SectionHeader(title: context.l10n.connectionSettings),
              _configGroup(),
              SectionHeader(title: context.l10n.syncTitle),
              SettingsGroup(
                children: <Widget>[
                  SettingsSwitchTile(
                    value: autoStart,
                    icon: Icons.play_circle_outline,
                    title: context.l10n.syncOnStart,
                    subtitle: context.l10n.syncOnStartHint,
                    onChanged: !canAuto || _busy
                        ? null
                        : (value) => _setAutoOption('autoOnStart', value),
                  ),
                  SettingsSwitchTile(
                    value: autoResume,
                    icon: Icons.refresh,
                    title: context.l10n.syncOnResume,
                    subtitle: context.l10n.syncOnResumeHint,
                    onChanged: !canAuto || _busy
                        ? null
                        : (value) => _setAutoOption('autoOnResume', value),
                  ),
                  SettingsSwitchTile(
                    value: _fields['autoOnChange'] == 'true',
                    icon: Icons.edit_note,
                    title: context.l10n.syncOnChange,
                    subtitle: context.l10n.syncOnChangeHint,
                    onChanged: !canAuto || _busy
                        ? null
                        : (value) => _setAutoOption('autoOnChange', value),
                  ),
                  SettingsSwitchTile(
                    value: _fields['autoAfterSession'] == 'true',
                    icon: Icons.school_outlined,
                    title: context.l10n.syncOnSessionEnd,
                    subtitle: context.l10n.syncOnSessionEndHint,
                    onChanged: !canAuto || _busy
                        ? null
                        : (value) => _setAutoOption('autoAfterSession', value),
                  ),
                  if (!canAuto)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        context.l10n.localFileManualOnly,
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
                          label: Text(context.l10n.testConnection),
                        ),
                        ElevatedButton.icon(
                          onPressed: _busy ? null : _syncNow,
                          icon: const Icon(Icons.sync),
                          label: Text(
                            _busy ? context.l10n.syncing : context.l10n.syncNow,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _exportBackup,
                          icon: const Icon(Icons.save_alt),
                          label: Text(context.l10n.exportBackup),
                        ),
                      ],
                    ),
                  ),
                  if (_provider == 'webdav' &&
                      !(_capability?.safeBidirectionalSync ?? false) &&
                      (autoStart ||
                          autoResume ||
                          _fields['autoOnChange'] == 'true' ||
                          _fields['autoAfterSession'] == 'true'))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        _capability == null
                            ? context.l10n.autoSyncNotEnabled
                            : context.l10n.autoSyncNotEnabledReason(
                                syncCapabilitySummary(
                                  context.l10n,
                                  _capability!,
                                ),
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.hazy,
                        ),
                      ),
                    ),
                  // Status, capability and the technical detail in one block.
                  // It is built from the structured capability rather than from
                  // a single bool, so a green tick can never sit next to
                  // "cannot sync safely".
                  _statusBlock(theme),
                ],
              ),
              if (_conflicts.isNotEmpty) ...<Widget>[
                SectionHeader(title: context.l10n.syncConflicts),
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
                          '${context.l10n.keptValue(_displayValue(conflict.field, conflict.adoptedValue))}\n'
                          '${context.l10n.discardedValue(_displayValue(conflict.field, conflict.discardedValue))}',
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
                                tooltip: context.l10n.restoreOverwritten,
                                icon: const Icon(Icons.undo),
                                onPressed: _busy
                                    ? null
                                    : () => _restoreConflict(conflict),
                              )
                            else
                              Tooltip(
                                message: context.l10n.diagnosticOnly,
                                child: Icon(Icons.info_outline),
                              ),
                            IconButton(
                              tooltip: context.l10n.ignoreRecord,
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
                    context.l10n.conflictExplain,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
              SectionHeader(title: context.l10n.syncStatus),
              SettingsGroup(
                children: <Widget>[
                  SettingsTile(
                    leading: const Icon(Icons.schedule),
                    title: context.l10n.lastSynced,
                    subtitle: _lastSyncAt == null
                        ? context.l10n.neverSynced
                        : formatDateTime(_lastSyncAt!),
                  ),
                  SettingsTile(
                    leading: const Icon(Icons.info_outline),
                    title: context.l10n.syncResult,
                    subtitle: describeStoredSyncResult(
                      context.l10n,
                      _lastResult,
                    ),
                  ),
                  SettingsTile(
                    leading: Icon(
                      _pendingChanges == true
                          ? Icons.cloud_upload_outlined
                          : Icons.cloud_done_outlined,
                    ),
                    title: context.l10n.pendingChanges,
                    subtitle: _pendingChanges == true
                        ? context.l10n.hasLocalChanges
                        : context.l10n.inSyncWithLast,
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
                        child: Text(context.l10n.recreateRemoteAction),
                      ),
                    ),
                  for (final String note in _syncNotes)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('· $note', style: theme.textTheme.bodySmall),
                    ),
                  // One tap from a failed sync to the request log. The log itself
                  // stays behind the diagnostics switch and is redacted.
                  SettingsTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: context.l10n.syncDiagnostics,
                    subtitle: context.l10n.syncDiagnosticsHint,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DiagnosticsPage(),
                      ),
                    ),
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
                title: Text(
                  context.l10n.aboutSync,
                  style: theme.textTheme.bodyLarge,
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: <Widget>[
                  Text(
                    context.l10n.aboutSyncBody,
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
                    label: Text(context.l10n.turnOffSync),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Icon, colour and wording for the current state.
  ///
  /// A single `ok` bool is not enough to describe a sync target: "connected" and
  /// "safe for two devices" are different facts, and showing a green tick for a
  /// server that cannot do conditional writes was actively misleading.
  _StatusVisual _statusVisual(ThemeData theme) {
    final Color neutral = theme.brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final SyncCapability? capability = _testResult?.capability ?? _capability;
    final List<String> details = _testResult?.details ?? const <String>[];

    if (capability == null) {
      if (_testResult != null) {
        // Providers without a capability report (GitHub, local file) keep their
        // own message; there is no conditional-write question to answer.
        return _StatusVisual(
          icon: _testResult!.ok ? Icons.check_circle : Icons.error_outline,
          color: _testResult!.ok ? AppColors.known : AppColors.unknown,
          text: describeSyncTestResult(context.l10n, _testResult!),
          hint: null,
          details: details,
        );
      }
      return _StatusVisual(
        icon: Icons.help_outline,
        color: neutral,
        text: context.l10n.connectionNotVerified,
        hint: _provider == 'webdav'
            ? context.l10n.connectionNotVerifiedHint
            : null,
        details: const <String>[],
      );
    }

    final (IconData, Color) visual = switch (capability.status) {
      SyncCapabilityStatus.safeConditionalWrite => (
        Icons.check_circle,
        AppColors.known,
      ),
      SyncCapabilityStatus.basicReadWrite => (
        Icons.warning_amber_outlined,
        AppColors.hazy,
      ),
      SyncCapabilityStatus.readOnly => (
        Icons.warning_amber_outlined,
        AppColors.hazy,
      ),
      SyncCapabilityStatus.requestRejected => (
        Icons.error_outline,
        AppColors.unknown,
      ),
      SyncCapabilityStatus.directoryUnavailable => (
        Icons.folder_off_outlined,
        AppColors.unknown,
      ),
      SyncCapabilityStatus.authenticationFailed => (
        Icons.lock_outline,
        AppColors.unknown,
      ),
      SyncCapabilityStatus.connectionFailed => (
        Icons.cloud_off_outlined,
        AppColors.unknown,
      ),
      SyncCapabilityStatus.unknown => (Icons.help_outline, neutral),
    };
    return _StatusVisual(
      icon: visual.$1,
      color: visual.$2,
      text: syncCapabilitySummary(context.l10n, capability),
      hint: null,
      facts: <String>[
        if (capability.reachable) context.l10n.webDavServerResponded,
        if (capability.directoryAccessible)
          capability.directoryListingSupported
              ? context.l10n.webDavFolderBrowsable
              : context.l10n.webDavFolderAccessible,
        if (capability.canCreate && capability.canRead && capability.canUpdate)
          context.l10n.webDavProbeReadWrite,
      ],
      details: details,
    );
  }

  Widget _statusBlock(ThemeData theme) {
    final _StatusVisual visual = _statusVisual(theme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                visual.icon,
                size: AppDimens.iconSizeSmall,
                color: visual.color,
              ),
              AppSpacing.w8,
              Expanded(
                child: Text(visual.text, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          if (visual.hint != null && visual.hint!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(visual.hint!, style: theme.textTheme.bodySmall),
            ),
          for (final String fact in visual.facts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(fact, style: theme.textTheme.bodySmall),
            ),
          if (visual.details.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: Text(
                context.l10n.technicalDetails,
                style: theme.textTheme.bodySmall,
              ),
              children: <Widget>[
                for (final String detail in visual.details)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        detail.startsWith('NO_CONDITIONAL_WRITE')
                            ? detail.replaceFirst(
                                'NO_CONDITIONAL_WRITE:',
                                context.l10n.noteLabel,
                              )
                            : '· $detail',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Any edit to the connection data invalidates what was proven for the *old*
  /// configuration: a capability result belongs to one address + directory +
  /// account, and must never be inherited by the next one.
  void _invalidateVerification() {
    _verificationGeneration++;
    if (_capability == null && _testResult == null) return;
    if (mounted) {
      setState(() {
        _capability = null;
        _testResult = null;
      });
    } else {
      _capability = null;
      _testResult = null;
    }
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
        key: ValueKey<String>('sync_field_$key'),
        label: label,
        hint: hint,
        initialValue: _field(key, fallback: fallback),
        onChanged: (String value) {
          _fields[key] = value;
          _invalidateVerification();
        },
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
              context.l10n.syncFilePath,
              hint: '/Users/you/MaterialWord/materialword-data.json',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                context.l10n.mobileFolderLimit,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );
      case 'github':
        return SettingsGroup(
          children: <Widget>[
            field('owner', context.l10n.githubOwner, hint: 'your-name'),
            field('repo', context.l10n.repoName, hint: 'materialword-data'),
            field('branch', context.l10n.branch, fallback: 'main'),
            field(
              'path',
              context.l10n.dataFilePath,
              fallback: 'materialword-data.json',
            ),
            secretField(
              context.l10n.accessToken,
              controller: _githubToken,
              helper: context.l10n.accessTokenHint,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                context.l10n.privateRepoNote,
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
              context.l10n.serverAddress,
              hint: 'https://dav.jianguoyun.com/dav/',
            ),
            _SyncTextField(
              label: context.l10n.username,
              controller: _webdavUser,
              onChanged: (String value) {
                _fields['user'] = value;
                _invalidateVerification();
              },
            ),
            secretField(
              context.l10n.appPassword,
              controller: _webdavPassword,
              helper: context.l10n.leaveBlankToKeep,
              onChanged: (String _) => _invalidateVerification(),
            ),
            _SyncTextField(
              key: const ValueKey<String>('sync_field_dir'),
              label: context.l10n.remoteFolder,
              hint: 'MaterialWord',
              controller: _webdavDir,
              onChanged: (String value) {
                _fields['dir'] = value;
                _invalidateVerification();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickRemoteDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: Text(context.l10n.chooseRemoteFolder),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                context.l10n.remoteFolderHint,
                style: theme.textTheme.bodySmall,
              ),
            ),
            field(
              'file',
              context.l10n.fileName,
              fallback: 'materialword-data.json',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                context.l10n.httpsOnly + context.l10n.etagNote,
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

/// What the status row shows: icon, colour, headline, one-line explanation and
/// the technical details hidden behind a disclosure.
class _StatusVisual {
  const _StatusVisual({
    required this.icon,
    required this.color,
    required this.text,
    required this.details,
    this.hint,
    this.facts = const <String>[],
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? hint;
  final List<String> details;
  final List<String> facts;
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
    super.key,
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
