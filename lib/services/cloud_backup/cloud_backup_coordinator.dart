import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/time_utils.dart';
import '../backup_service.dart';
import '../diagnostics_service.dart';
import 'cloud_backup_provider.dart';
import 'cloud_backup_repository.dart';

enum CloudBackupStage {
  idle,
  exporting,
  uploading,
  verifying,
  listing,
  downloading,
  validating,
  completed,
  failed,
  outcomeUnknown,
}

class CloudBackupProgress {
  const CloudBackupProgress(
    this.stage, {
    this.providerId,
    this.operationId,
    this.error,
  });
  final CloudBackupStage stage;
  final String? providerId;
  final String? operationId;
  final String? error;
}

class CloudBackupReceipt {
  const CloudBackupReceipt({
    required this.operationId,
    required this.providerId,
    required this.objectName,
    required this.targetFingerprint,
    required this.completedAt,
    required this.byteLength,
    required this.checksum,
  });
  final String operationId;
  final String providerId;
  final String objectName;
  final String targetFingerprint;
  final DateTime completedAt;
  final int byteLength;
  final String checksum;
}

class CloudBackupDownload {
  const CloudBackupDownload(this.entry, this.bytes, this.dataset);
  final CloudBackupEntry entry;
  final List<int> bytes;
  final Map<String, Object?> dataset;
}

typedef CloudBackupProviderFactory = CloudBackupProvider Function(
  CloudBackupConfig config,
  String first,
  String second,
);

/// Application-wide single transfer lane. A target and its credentials are
/// captured before any network request and never re-read midway through it.
class CloudBackupCoordinator extends ChangeNotifier {
  CloudBackupCoordinator({
    required this.repository,
    required this.backup,
    required this.clock,
    http.Client? client,
    CloudBackupProviderFactory? factory,
  }) : _factory =
           factory ??
           ((config, first, second) => config.providerId == 's3'
               ? S3BackupProvider(config, first, second, client: client)
               : WebDavBackupProvider(config, first, second, client: client));

  final CloudBackupRepository repository;
  final BackupService backup;
  final Clock clock;
  final CloudBackupProviderFactory _factory;
  bool _running = false;
  bool get isRunning => _running;
  CloudBackupProgress progress = const CloudBackupProgress(
    CloudBackupStage.idle,
  );
  CloudBackupReceipt? lastUploadReceipt;
  void Function(CloudBackupProgress)? onProgress;

  void _set(CloudBackupStage stage, String id, String op, {String? error}) {
    progress = CloudBackupProgress(
      stage,
      providerId: id,
      operationId: op,
      error: error,
    );
    onProgress?.call(progress);
    DiagnosticsService.instance.log(
      'cloud_backup',
      '${id == 's3' ? 's3' : 'webdav'} ${stage.name} operation=$op',
    );
    notifyListeners();
  }

  Future<T> _operation<T>(
    String id,
    CloudBackupStage start,
    Future<T> Function(CloudBackupConfig, CloudBackupProvider, String) body,
  ) async {
    if (_running) throw const CloudBackupException('Cloud backup is busy');
    _running = true;
    final op = const Uuid().v4();
    _set(start, id, op);
    CloudBackupProvider? provider;
    try {
      final config = await repository.load(id);
      if (config == null || config.validate() != null) {
        throw const CloudBackupException('Cloud backup is not configured');
      }
      final (first, second) = await repository.readSecrets(config);
      provider = _factory(config, first, second);
      final result = await body(config, provider, op);
      _set(CloudBackupStage.completed, id, op);
      return result;
    } catch (error) {
      _set(
        error is CloudBackupException && error.message.contains('unknown')
            ? CloudBackupStage.outcomeUnknown
            : CloudBackupStage.failed,
        id,
        op,
        error: error.toString(),
      );
      rethrow;
    } finally {
      provider?.close();
      _running = false;
    }
  }

  String _newName() {
    final now = clock.now().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'materialword-backup-${now.year}${two(now.month)}${two(now.day)}'
        'T${two(now.hour)}${two(now.minute)}${two(now.second)}'
        '${now.millisecond.toString().padLeft(3, '0')}Z-${const Uuid().v4()}.json';
  }

  Future<({bool canUpload, bool canList, bool canDeleteProbe})> testConnection(
    CloudBackupConfig config,
    String first,
    String second,
  ) async {
    if (_running) throw const CloudBackupException('Cloud backup is busy');
    final problem = config.validate();
    if (problem != null) throw CloudBackupException(problem);
    _running = true;
    final op = const Uuid().v4();
    final provider = _factory(config, first, second);
    final name = '.materialword-backup-probe-${const Uuid().v4()}';
    const bytes = <int>[77, 97, 116, 101, 114, 105, 97, 108, 87, 111, 114, 100];
    var uploaded = false;
    var listed = false;
    var deleted = false;
    try {
      try {
        await provider.listBackups();
        listed = true;
      } catch (_) {
        // Listing permission is independent of the ability to create and GET.
      }
      try {
        await provider.ensureDirectory();
        if (await provider.inspectObject(name) !=
            CloudBackupObjectState.missing) {
          throw const CloudBackupException('Probe object already exists');
        }
        _set(CloudBackupStage.uploading, config.providerId, op);
        await provider.uploadBackup(name, bytes);
        uploaded = true;
      } catch (_) {
        if (!listed) rethrow;
      }
      if (uploaded) {
        _set(CloudBackupStage.verifying, config.providerId, op);
        final received = await provider.downloadBackup(name);
        if (sha256.convert(received) != sha256.convert(bytes)) {
          throw const CloudBackupException('Probe checksum mismatch');
        }
      }
      try {
        await provider.deleteProbe(name);
        deleted = true;
      } catch (_) {}
      _set(CloudBackupStage.completed, config.providerId, op);
      return (canUpload: uploaded, canList: listed, canDeleteProbe: deleted);
    } catch (error) {
      _set(
        CloudBackupStage.failed,
        config.providerId,
        op,
        error: error.toString(),
      );
      rethrow;
    } finally {
      if (!deleted) {
        try {
          await provider.deleteProbe(name);
        } catch (_) {}
      }
      provider.close();
      _running = false;
    }
  }

  Future<CloudBackupReceipt> upload(
    String id,
  ) => _operation(id, CloudBackupStage.exporting, (config, provider, op) async {
    final json = await backup.exportToJson(
      now: clock.now(),
      pretty: false,
      includeDeviceSettings: true,
    );
    final bytes = utf8.encode(json);
    if (bytes.length > cloudBackupMaxBytes) {
      throw const CloudBackupException('Backup exceeds 100 MB');
    }
    final checksum = sha256.convert(bytes).toString();
    String? name;
    for (var i = 0; i < 3; i++) {
      final candidate = _newName();
      if (await provider.inspectObject(candidate) ==
          CloudBackupObjectState.missing) {
        name = candidate;
        break;
      }
    }
    if (name == null) {
      throw const CloudBackupException('Could not reserve unique backup name');
    }
    await provider.ensureDirectory();
    _set(CloudBackupStage.uploading, id, op);
    try {
      await provider.uploadBackup(name, bytes);
    } catch (error) {
      // A lost response may follow a successful PUT. Read back this same
      // immutable payload; never export again or blindly overwrite it.
      try {
        final recovered = await provider.downloadBackup(name);
        if (sha256.convert(recovered).toString() != checksum) {
          throw const CloudBackupException('Cloud backup outcome unknown');
        }
      } catch (_) {
        throw const CloudBackupException('Cloud backup outcome unknown');
      }
    }
    _set(CloudBackupStage.verifying, id, op);
    final verified = await provider.downloadBackup(name);
    if (sha256.convert(verified).toString() != checksum) {
      throw const CloudBackupException('Cloud backup checksum mismatch');
    }
    await backup.decodeDatasetAsync(utf8.decode(verified));
    final completed = clock.now().toUtc();
    final receipt = CloudBackupReceipt(
      operationId: op,
      providerId: id,
      objectName: name,
      targetFingerprint: config.fingerprint,
      completedAt: completed,
      byteLength: bytes.length,
      checksum: checksum,
    );
    try {
      await repository.recordSuccess(config, <String, Object?>{
        'operationId': op,
        'objectName': name,
        'completedAt': completed.toIso8601String(),
        'byteLength': bytes.length,
        'sha256': checksum,
      });
    } catch (_) {
      throw const CloudBackupException(
        'Cloud file verified, but the local success record could not be saved',
      );
    }
    lastUploadReceipt = receipt;
    return receipt;
  });

  Future<CloudBackupPage> list(String id, {String? continuationToken}) =>
      _operation(
        id,
        CloudBackupStage.listing,
        (config, provider, op) =>
            provider.listBackups(continuationToken: continuationToken),
      );

  Future<CloudBackupDownload> download(CloudBackupEntry entry) => _operation(
    entry.providerId,
    CloudBackupStage.downloading,
    (config, provider, op) async {
      if (entry.targetFingerprint != config.fingerprint) {
        throw const CloudBackupException('Cloud backup target changed');
      }
      if (entry.byteLength != null && entry.byteLength! > cloudBackupMaxBytes) {
        throw const CloudBackupException('Backup exceeds 100 MB');
      }
      final bytes = await provider.downloadBackup(entry.objectName);
      _set(CloudBackupStage.validating, entry.providerId, op);
      final dataset = await backup.decodeDatasetAsync(utf8.decode(bytes));
      final trusted = await repository.lastSuccess(config);
      if (trusted?['objectName'] == entry.objectName &&
          trusted?['sha256'] != sha256.convert(bytes).toString()) {
        throw const CloudBackupException('Cloud backup checksum mismatch');
      }
      await repository.recordDownload(config, entry.objectName, clock.now());
      return CloudBackupDownload(entry, bytes, dataset);
    },
  );
}
