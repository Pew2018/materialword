import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../core/repositories/settings_repository.dart';
import '../sync/credential_store.dart';
import '../sync/s3_sync_provider.dart';
import '../sync/webdav_paths.dart';

/// Configurations contain target coordinates only. Secrets live in epoch-scoped
/// keychain items, so a failed save cannot invalidate the active configuration.
class CloudBackupConfig {
  const CloudBackupConfig({
    required this.providerId,
    required this.endpoint,
    required this.directory,
    required this.credentialEpoch,
    this.region = '',
    this.bucket = '',
    this.addressing = 'auto',
  });

  final String providerId;
  final String endpoint;
  final String directory;
  final String region;
  final String bucket;
  final String addressing;
  final String credentialEpoch;

  String get fingerprint => sha256
      .convert(
        utf8.encode(
          jsonEncode(<String>[
            providerId,
            endpoint.trim(),
            region.trim(),
            bucket.trim(),
            directory.trim(),
            addressing,
            credentialEpoch,
          ]),
        ),
      )
      .toString();

  Map<String, Object?> toJson() => <String, Object?>{
    'provider': providerId,
    if (providerId == 's3') ...<String, Object?>{
      'endpoint': endpoint,
      'region': region,
      'bucket': bucket,
      'prefix': directory,
      'addressing': addressing,
    } else ...<String, Object?>{'url': endpoint, 'dir': directory},
    'credentialEpoch': credentialEpoch,
  };

  static CloudBackupConfig fromJson(Map<String, dynamic> json) {
    final String id = json['provider'] as String;
    return CloudBackupConfig(
      providerId: id,
      endpoint: (json[id == 's3' ? 'endpoint' : 'url'] as String?) ?? '',
      directory: (json[id == 's3' ? 'prefix' : 'dir'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      bucket: (json['bucket'] as String?) ?? '',
      addressing: (json['addressing'] as String?) ?? 'auto',
      credentialEpoch: (json['credentialEpoch'] as String?) ?? '',
    );
  }

  String? validate() {
    if (providerId == 's3') {
      if (!<String>{'auto', 'path', 'virtual'}.contains(addressing)) {
        return 'Invalid addressing style';
      }
      if (directory.isEmpty ||
          directory.startsWith('/') ||
          !directory.endsWith('/') ||
          directory.contains('//')) {
        return 'Invalid backup prefix';
      }
      return S3Target.problemWith(
        endpoint: endpoint,
        region: region,
        bucket: bucket,
        objectKey: '${directory}materialword-backup-test.json',
      );
    }
    if (providerId == 'webdav') {
      if (!endpoint.startsWith('https://') ||
          WebDavPaths.resolve(
                baseUrl: endpoint,
                remoteDir: directory,
                fileName: 'materialword-backup-test.json',
              ) ==
              null) {
        return 'Invalid WebDAV target';
      }
      return null;
    }
    return 'Invalid provider';
  }
}

class CloudBackupRepository {
  CloudBackupRepository(this.settings, this.credentials);
  final SettingsRepository settings;
  final CredentialStore credentials;

  String _key(String id) => id == 's3'
      ? SettingsRepository.cloudBackupS3ConfigKey
      : SettingsRepository.cloudBackupWebDavConfigKey;

  Future<CloudBackupConfig?> load(String id) async {
    final String? raw = await settings.db.readMeta(_key(id));
    if (raw == null) return null;
    return CloudBackupConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<List<CloudBackupConfig>> configured() async {
    final configs = await Future.wait(<Future<CloudBackupConfig?>>[
      load('s3'),
      load('webdav'),
    ]);
    return configs.whereType<CloudBackupConfig>().toList();
  }

  String _firstKey(String id, String epoch) =>
      '${id == 's3' ? CredentialKeys.backupS3AccessKeyId : CredentialKeys.backupWebdavUsername}.$epoch';
  String _secondKey(String id, String epoch) =>
      '${id == 's3' ? CredentialKeys.backupS3SecretAccessKey : CredentialKeys.backupWebdavPassword}.$epoch';

  Future<(String, String)> readSecrets(CloudBackupConfig config) =>
      CredentialStore.exclusive(() async {
        final first = await credentials.read(
          _firstKey(config.providerId, config.credentialEpoch),
        );
        final second = await credentials.read(
          _secondKey(config.providerId, config.credentialEpoch),
        );
        if (first == null ||
            first.isEmpty ||
            second == null ||
            second.isEmpty) {
          throw StateError('Cloud backup credentials are missing');
        }
        return (first, second);
      });

  Future<CloudBackupConfig> save(
    CloudBackupConfig draft, {
    String? firstSecret,
    String? secondSecret,
  }) async {
    final problem = draft.validate();
    if (problem != null) throw ArgumentError(problem);
    return CredentialStore.exclusive(() async {
      final old = await load(draft.providerId);
      final first = firstSecret?.isNotEmpty == true
          ? firstSecret
          : old == null
          ? null
          : await credentials.read(
              _firstKey(old.providerId, old.credentialEpoch),
            );
      final second = secondSecret?.isNotEmpty == true
          ? secondSecret
          : old == null
          ? null
          : await credentials.read(
              _secondKey(old.providerId, old.credentialEpoch),
            );
      if (first == null || first.isEmpty || second == null || second.isEmpty) {
        throw StateError('Cloud backup credentials are missing');
      }
      final next = CloudBackupConfig(
        providerId: draft.providerId,
        endpoint: draft.endpoint,
        directory: draft.directory,
        region: draft.region,
        bucket: draft.bucket,
        addressing: draft.addressing,
        credentialEpoch: const Uuid().v4(),
      );
      final key1 = _firstKey(next.providerId, next.credentialEpoch);
      final key2 = _secondKey(next.providerId, next.credentialEpoch);
      try {
        await credentials.write(key1, first);
        await credentials.write(key2, second);
        await settings.db.transaction(() async {
          await settings.db.writeMeta(
            _key(next.providerId),
            jsonEncode(next.toJson()),
          );
          final revision =
              int.tryParse(
                await settings.db.readMeta(
                      SettingsRepository.cloudBackupConfigRevisionKey,
                    ) ??
                    '',
              ) ??
              0;
          await settings.db.writeMeta(
            SettingsRepository.cloudBackupConfigRevisionKey,
            '${revision + 1}',
          );
        });
      } catch (_) {
        try {
          await credentials.delete(key1);
        } catch (_) {
          /* preserve original error */
        }
        try {
          await credentials.delete(key2);
        } catch (_) {
          /* preserve original error */
        }
        rethrow;
      }
      // Old items remain harmless if keychain cleanup is unavailable.
      if (old != null) {
        try {
          await credentials.delete(
            _firstKey(old.providerId, old.credentialEpoch),
          );
        } catch (_) {}
        try {
          await credentials.delete(
            _secondKey(old.providerId, old.credentialEpoch),
          );
        } catch (_) {}
      }
      return next;
    });
  }

  Future<void> remove(String id) => CredentialStore.exclusive(() async {
    final old = await load(id);
    await settings.db.deleteMeta(_key(id));
    if (old != null) {
      try {
        await credentials.delete(_firstKey(id, old.credentialEpoch));
      } catch (_) {}
      try {
        await credentials.delete(_secondKey(id, old.credentialEpoch));
      } catch (_) {}
    }
  });

  Future<String?> preferred() =>
      settings.db.readMeta(SettingsRepository.cloudBackupPreferredTargetKey);
  Future<void> setPreferred(String id) => settings.db.writeMeta(
    SettingsRepository.cloudBackupPreferredTargetKey,
    id,
  );

  Future<Map<String, dynamic>?> lastSuccess(CloudBackupConfig config) async {
    final raw = await settings.db.readMeta(
      '${SettingsRepository.cloudBackupLastSuccessKey}_${config.providerId}',
    );
    if (raw == null) return null;
    final value = jsonDecode(raw) as Map<String, dynamic>;
    return value['fingerprint'] == config.fingerprint ? value : null;
  }

  Future<void> recordSuccess(
    CloudBackupConfig config,
    Map<String, Object?> receipt,
  ) => settings.db.writeMeta(
    '${SettingsRepository.cloudBackupLastSuccessKey}_${config.providerId}',
    jsonEncode(<String, Object?>{
      ...receipt,
      'fingerprint': config.fingerprint,
    }),
  );

  Future<void> recordDownload(
    CloudBackupConfig config,
    String objectName,
    DateTime completedAt,
  ) => settings.db.writeMeta(
    '${SettingsRepository.cloudBackupLastDownloadKey}_${config.providerId}',
    jsonEncode(<String, Object?>{
      'fingerprint': config.fingerprint,
      'objectName': objectName,
      'completedAt': completedAt.toUtc().toIso8601String(),
    }),
  );
}
