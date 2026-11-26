import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../../services/cloud_backup/cloud_backup_repository.dart';
import '../../services/sync/credential_store.dart';
import '../../services/sync/webdav_sync_provider.dart';
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(title: context.l10n.cloudBackupTitle),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(context.l10n.cloudBackupIndependentHint),
      ),
      SettingsGroup(
        children: [
          for (final id in ['s3', 'webdav'])
            ListTile(
              leading: Icon(
                id == 's3' ? Icons.cloud_outlined : Icons.folder_outlined,
              ),
              title: Text(
                id == 's3'
                    ? context.l10n.cloudBackupS3
                    : context.l10n.cloudBackupWebDav,
              ),
              subtitle: Text(
                _configs.any((c) => c.providerId == id)
                    ? '${context.l10n.cloudBackupConfigured} · ${context.l10n.cloudBackupLastSuccess}: ${_last[id]?['completedAt'] ?? context.l10n.cloudBackupNever}'
                    : context.l10n.cloudBackupNotConfiguredShort,
              ),
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
  bool hasMatchingSync = false;
  @override
  void initState() {
    super.initState();
    directory.text = widget.providerId == 's3'
        ? 'materialword-backups/'
        : 'materialword-backups';
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
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
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
        message = context.l10n.commonDone;
      });
    }
  });
  Future<void> _test() => _run(() async {
    final (one, two) = await _secrets();
    final result = await ref
        .read(cloudBackupCoordinatorProvider)
        .testConnection(draft, one, two);
    if (mounted) {
      setState(
        () => message = !result.canUpload
            ? context.l10n.cloudBackupReadOnly
            : result.canList
            ? context.l10n.cloudBackupReady
            : '${context.l10n.cloudBackupReady} · ${context.l10n.cloudBackupBrowse}: —',
      );
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
        setState(() => message = context.l10n.cloudBackupNoSyncConfig);
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
      final keys = widget.providerId == 's3'
          ? (CredentialKeys.s3AccessKeyId, CredentialKeys.s3SecretAccessKey)
          : (CredentialKeys.webdavUsername, CredentialKeys.webdavPassword);
      final one = await store.read(keys.$1);
      final two = await store.read(keys.$2);
      if (one == null || two == null) {
        throw StateError('Missing sync credentials');
      }
      endpoint.text =
          (sync![widget.providerId == 's3' ? 'endpoint' : 'url'] as String?) ??
          '';
      region.text = (sync['region'] as String?) ?? 'us-east-1';
      bucket.text = (sync['bucket'] as String?) ?? '';
      addressing = (sync['addressing'] as String?) ?? 'auto';
      directory.text = widget.providerId == 's3'
          ? 'materialword-backups/'
          : 'materialword-backups';
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
          message = context.l10n.commonDone;
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
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: controller,
      obscureText: secret,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        hintText: secret && saved != null ? '••••••••' : null,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ClassicAppBar(
      title: Text(widget.providerId == 's3' ? 'S3' : 'WebDAV'),
    ),
    body: ContentColumn(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(message!),
            ),
          if (busy) const LinearProgressIndicator(),
          field(context.l10n.cloudBackupEndpoint, endpoint),
          if (widget.providerId == 's3') ...[
            field(context.l10n.cloudBackupRegion, region),
            field(context.l10n.cloudBackupBucket, bucket),
          ],
          field(context.l10n.cloudBackupDirectory, directory),
          if (widget.providerId == 's3')
            DropdownButtonFormField<String>(
              initialValue: addressing,
              decoration: InputDecoration(
                labelText: context.l10n.cloudBackupAddressing,
              ),
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('Auto')),
                DropdownMenuItem(value: 'path', child: Text('Path')),
                DropdownMenuItem(value: 'virtual', child: Text('Virtual')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => addressing = value);
              },
            ),
          field(
            widget.providerId == 's3'
                ? 'Access Key ID'
                : context.l10n.cloudBackupUsername,
            first,
            secret: true,
          ),
          field(
            widget.providerId == 's3'
                ? 'Secret Access Key'
                : context.l10n.cloudBackupPassword,
            second,
            secret: true,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.providerId == 'webdav')
                OutlinedButton(
                  onPressed: busy ? null : _browse,
                  child: Text(context.l10n.chooseRemoteFolder),
                ),
              OutlinedButton(
                onPressed: busy ? null : _copy,
                child: Text(context.l10n.cloudBackupCopySync),
              ),
              OutlinedButton(
                onPressed: busy ? null : _test,
                child: Text(context.l10n.cloudBackupTest),
              ),
              FilledButton(
                onPressed: busy ? null : _save,
                child: Text(context.l10n.commonSave),
              ),
              if (saved != null)
                TextButton(
                  onPressed: busy ? null : _remove,
                  child: Text(context.l10n.commonDelete),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
