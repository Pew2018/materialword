import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/backup_labels.dart';
import '../../l10n/error_labels.dart';
import '../../l10n/l10n.dart';
import '../../services/cloud_backup/cloud_backup_repository.dart';
import '../../services/sync/credential_store.dart';
import '../../services/sync/webdav_sync_provider.dart';
import '../../shared/widgets/classic_select.dart';
import '../../shared/widgets/common.dart';
import '../sync/webdav_directory_picker.dart';

class CloudBackupSettingsSection extends ConsumerStatefulWidget {
  const CloudBackupSettingsSection({super.key});
  @override
  ConsumerState<CloudBackupSettingsSection> createState() =>
      _CloudBackupSettingsSectionState();
}

class _CloudBackupSettingsSectionState
    extends ConsumerState<CloudBackupSettingsSection> {
  List<CloudBackupConfig> _configs = const [];
  Map<String, Map<String, dynamic>?> _last = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final configs = await ref.read(cloudBackupRepositoryProvider).configured();
    final last = <String, Map<String, dynamic>?>{};
    for (final config in configs) {
      last[config.providerId] = await ref
          .read(cloudBackupRepositoryProvider)
          .lastSuccess(config);
    }
    if (mounted) {
      setState(() {
        _configs = configs;
        _last = last;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.cloudBackupTitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l10n.cloudBackupIndependentHint),
        ),
        SettingsGroup(
          children: [
            for (final String id in ['s3', 'webdav'])
              SettingsTile(
                leading: Icon(
                  id == 's3' ? Icons.cloud_outlined : Icons.folder_outlined,
                ),
                title: id == 's3' ? l10n.cloudBackupS3 : l10n.cloudBackupWebDav,
                subtitle: _configs.any((c) => c.providerId == id)
                    ? '${l10n.cloudBackupConfigured} · '
                          '${l10n.cloudBackupLastSuccess}: '
                          '${_last[id] == null ? l10n.cloudBackupNever : cloudBackupTime(l10n, _last[id]?['completedAt'])}'
                    : l10n.cloudBackupNotConfiguredShort,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => CloudBackupConfigPage(providerId: id),
                    ),
                  );
                  _load();
                },
              ),
          ],
        ),
      ],
    );
  }
}

class CloudBackupConfigPage extends ConsumerStatefulWidget {
  const CloudBackupConfigPage({required this.providerId, super.key});
  final String providerId;
  @override
  ConsumerState<CloudBackupConfigPage> createState() =>
      _CloudBackupConfigPageState();
}

class _CloudBackupConfigPageState extends ConsumerState<CloudBackupConfigPage> {
  final endpoint = TextEditingController();
  final region = TextEditingController(text: 'us-east-1');
  final bucket = TextEditingController();
  final directory = TextEditingController();
  final first = TextEditingController();
  final second = TextEditingController();
  String addressing = 'auto';
  CloudBackupConfig? saved;
  bool busy = false;
  String? message;
  bool messageIsError = false;

  /// True only when *both* credentials for the saved epoch are actually
  /// present in the keychain. An empty username field next to a saved
  /// configuration otherwise looks like "nothing was saved".
  bool credentialsSaved = false;

  bool get isS3 => widget.providerId == 's3';

  @override
  void initState() {
    super.initState();
    directory.text = isS3 ? 'materialword-backups/' : 'materialword-backups';
    _load();
  }

  Future<void> _load() async {
    final config = await ref
        .read(cloudBackupRepositoryProvider)
        .load(widget.providerId);
    if (!mounted || config == null) return;
    setState(() {
      saved = config;
      endpoint.text = config.endpoint;
      region.text = config.region;
      bucket.text = config.bucket;
      directory.text = config.directory;
      addressing = config.addressing;
    });
    await _probeCredentials(config);
  }

  /// Asks the keychain whether a complete credential pair exists.
  ///
  /// The values themselves never leave this method: only the boolean reaches
  /// the widget state, so a configuration screenshot or a state dump can never
  /// carry a secret.
  Future<void> _probeCredentials(CloudBackupConfig config) async {
    bool complete;
    try {
      final (String one, String two) = await ref
          .read(cloudBackupRepositoryProvider)
          .readSecrets(config);
      complete = one.isNotEmpty && two.isNotEmpty;
    } catch (_) {
      // Missing, unreadable or partially written: claim nothing.
      complete = false;
    }
    if (mounted) setState(() => credentialsSaved = complete);
  }

  @override
  void dispose() {
    endpoint.dispose();
    region.dispose();
    bucket.dispose();
    directory.dispose();
    first.dispose();
    second.dispose();
    super.dispose();
  }

  CloudBackupConfig get draft => CloudBackupConfig(
    providerId: widget.providerId,
    endpoint: endpoint.text.trim(),
    directory: directory.text.trim(),
    region: region.text.trim(),
    bucket: bucket.text.trim(),
    addressing: addressing,
    credentialEpoch: saved?.credentialEpoch ?? '',
  );

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
      messageIsError = false;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          message = describeCloudBackupError(context.l10n, e);
          messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<(String, String)> _secrets() async {
    final old = saved;
    if (old == null) return (first.text.trim(), second.text);
    final (one, two) = await ref
        .read(cloudBackupRepositoryProvider)
        .readSecrets(old);
    return (
      first.text.trim().isEmpty ? one : first.text.trim(),
      second.text.isEmpty ? two : second.text,
    );
  }

  Future<void> _save() => _run(() async {
    final config = await ref
        .read(cloudBackupRepositoryProvider)
        .save(
          draft,
          firstSecret: first.text.trim().isEmpty ? null : first.text.trim(),
          secondSecret: second.text.isEmpty ? null : second.text,
        );
    first.clear();
    second.clear();
    if (mounted) {
      setState(() {
        saved = config;
        credentialsSaved = true;
        message = context.l10n.commonDone;
        messageIsError = false;
      });
    }
  });

  Future<void> _test() => _run(() async {
    final (one, two) = await _secrets();
    final result = await ref
        .read(cloudBackupCoordinatorProvider)
        .testConnection(draft, one, two);
    if (mounted) {
      setState(() {
        message = !result.canUpload
            ? context.l10n.cloudBackupReadOnly
            : result.canList
            ? context.l10n.cloudBackupReady
            : context.l10n.cloudBackupUploadOnly;
        messageIsError = false;
      });
    }
  });

  Future<void> _browse() => _run(() async {
    if (draft.validate() != null) throw ArgumentError(draft.validate());
    final (username, password) = await _secrets();
    final pickerProvider = WebDavSyncProvider(
      baseUrl: endpoint.text.trim(),
      remoteDir: directory.text.trim(),
      fileName: 'materialword-backup-picker.json',
      usernameOverride: username,
      passwordOverride: password,
      client: ref.read(syncHttpClientProvider),
      traceDiagnostics: false,
    );
    try {
      final chosen = await showWebDavDirectoryPicker(
        context: context,
        provider: pickerProvider,
        initialPath: directory.text.trim(),
      );
      if (chosen != null && mounted) setState(() => directory.text = chosen);
    } finally {
      pickerProvider.close();
    }
  });

  Future<void> _copy() async {
    final sync = await ref.read(settingsRepositoryProvider).syncConfig();
    if (sync?['provider'] != widget.providerId) {
      if (mounted) {
        setState(() {
          message = context.l10n.cloudBackupNoSyncConfig;
          messageIsError = false;
        });
      }
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cloudBackupCopySync),
        content: Text(context.l10n.cloudBackupIndependentHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonCopy),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      final store = ref.read(credentialStoreProvider);
      final keys = isS3
          ? (CredentialKeys.s3AccessKeyId, CredentialKeys.s3SecretAccessKey)
          : (CredentialKeys.webdavUsername, CredentialKeys.webdavPassword);
      final one = await store.read(keys.$1);
      final two = await store.read(keys.$2);
      if (one == null || two == null) {
        throw StateError('Missing sync credentials');
      }
      endpoint.text = (sync![isS3 ? 'endpoint' : 'url'] as String?) ?? '';
      region.text = (sync['region'] as String?) ?? 'us-east-1';
      bucket.text = (sync['bucket'] as String?) ?? '';
      addressing = (sync['addressing'] as String?) ?? 'auto';
      directory.text = isS3 ? 'materialword-backups/' : 'materialword-backups';
      first.text = one;
      second.text = two;
      final config = await ref
          .read(cloudBackupRepositoryProvider)
          .save(draft, firstSecret: one, secondSecret: two);
      first.clear();
      second.clear();
      if (mounted) {
        setState(() {
          saved = config;
          credentialsSaved = true;
          message = context.l10n.commonDone;
          messageIsError = false;
        });
      }
    });
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.commonDelete),
        content: Text(context.l10n.cloudBackupConfirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(cloudBackupRepositoryProvider).remove(widget.providerId);
      if (mounted) Navigator.pop(context);
    });
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      obscureText: secret,
      // The 4dp radius, divider border, focus colour and paddings all come
      // from `InputDecorationTheme`; a local `OutlineInputBorder()` would
      // silently drop the theme's focused colour.
      decoration: InputDecoration(
        labelText: label,
        hintText: secret && credentialsSaved ? '••••••••' : null,
        helperText: secret && credentialsSaved
            ? context.l10n.cloudBackupCredentialsSaved
            : null,
      ),
    ),
  );

  /// One section of labelled fields on the classic flat surface.
  Widget _fields(List<Widget> children) => SettingsGroup(
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: ClassicAppBar(title: Text(isS3 ? 'S3' : 'WebDAV')),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            if (busy) const LinearProgressIndicator(),
            SectionHeader(title: l10n.cloudBackupSectionServer),
            _fields(<Widget>[
              field(l10n.cloudBackupEndpoint, endpoint),
              if (isS3) field(l10n.cloudBackupRegion, region),
              if (isS3) field(l10n.cloudBackupBucket, bucket),
              field(l10n.cloudBackupDirectory, directory),
              if (!isS3)
                // The picker belongs to the directory field, not to the bottom
                // of the form: it edits exactly that value.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: busy ? null : _browse,
                    icon: const Icon(
                      Icons.folder_open,
                      size: AppDimens.iconSizeSmall,
                    ),
                    label: Text(l10n.chooseRemoteFolder),
                  ),
                ),
              if (isS3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ClassicSelect<String>(
                    label: l10n.cloudBackupAddressing,
                    value: addressing,
                    enabled: !busy,
                    options: <ClassicOption<String>>[
                      ClassicOption<String>(
                        value: 'auto',
                        label: l10n.cloudBackupAddressingAuto,
                      ),
                      ClassicOption<String>(
                        value: 'path',
                        label: l10n.cloudBackupAddressingPath,
                      ),
                      ClassicOption<String>(
                        value: 'virtual',
                        label: l10n.cloudBackupAddressingVirtual,
                      ),
                    ],
                    onChanged: (String value) =>
                        setState(() => addressing = value),
                  ),
                ),
            ]),
            SectionHeader(title: l10n.cloudBackupSectionAuth),
            _fields(<Widget>[
              field(
                isS3 ? l10n.cloudBackupAccessKeyId : l10n.cloudBackupUsername,
                first,
                secret: true,
              ),
              field(
                isS3
                    ? l10n.cloudBackupSecretAccessKey
                    : l10n.cloudBackupPassword,
                second,
                secret: true,
              ),
            ]),
            SectionHeader(title: l10n.cloudBackupSectionActions),
            SettingsGroup(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (message != null) ...<Widget>[
                        _status(l10n, theme),
                        AppSpacing.h12,
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          TextButton(
                            onPressed: busy ? null : _copy,
                            child: Text(l10n.cloudBackupCopySync),
                          ),
                          OutlinedButton(
                            onPressed: busy ? null : _test,
                            child: Text(l10n.cloudBackupTest),
                          ),
                          ElevatedButton(
                            onPressed: busy ? null : _save,
                            child: Text(l10n.commonSave),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (saved != null) ...<Widget>[
              SectionHeader(title: l10n.cloudBackupSectionDanger),
              SettingsGroup(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.cloudBackupDeleteHint,
                          style: theme.textTheme.bodySmall,
                        ),
                        AppSpacing.h8,
                        TextButton(
                          onPressed: busy ? null : _remove,
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          child: Text(l10n.commonDelete),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Connection-test / save feedback in the app's own status vocabulary
  /// instead of a bare `Text(message)`.
  Widget _status(AppLocalizations l10n, ThemeData theme) {
    final bool error = messageIsError;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          error ? Icons.error_outline : Icons.check_circle,
          size: AppDimens.iconSizeSmall,
          color: error ? theme.colorScheme.error : AppColors.known,
        ),
        AppSpacing.w8,
        Expanded(
          child: Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: error ? theme.colorScheme.error : null,
            ),
          ),
        ),
      ],
    );
  }
}
