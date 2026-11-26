import 'package:materialword/services/cloud_backup/cloud_backup_provider.dart';
import 'package:materialword/services/cloud_backup/cloud_backup_repository.dart';

class TestBackupHistory implements CloudBackupProvider {
  TestBackupHistory(this.config, this.content);
  final CloudBackupConfig config;
  final List<int> content;
  final files = <String, List<int>>{};
  final denied = <String>{};
  bool failListing = false;
  bool repeatToken = false;
  bool failUpload = false;
  bool loseDeleteResponse = false;
  int pages = 0;
  Future<void> Function()? afterDelete;
  String name(int n) =>
      'materialword-backup-20261126T120000000Z-00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}.json';
  void seed(int n) {
    for (var i = 0; i < n; i++) {
      files[name(i)] = content;
    }
  }

  CloudBackupEntry entry(String name) => CloudBackupEntry(
    providerId: config.providerId,
    objectName: name,
    targetFingerprint: config.fingerprint,
    createdAt: name.startsWith('materialword-backup-20261127')
        ? DateTime.utc(2026, 11, 27)
        : DateTime.utc(2026, 11, 26, 12),
    byteLength: files[name]?.length,
  );
  @override
  Future<CloudBackupPage> listBackups({String? continuationToken}) async {
    pages++;
    if (failListing) throw const CloudBackupException('connection failed');
    final all = files.keys.where(cloudBackupName.hasMatch).toList()..sort();
    final start = int.parse(continuationToken ?? '0');
    final end = (start + 2).clamp(0, all.length);
    return CloudBackupPage(
      all.sublist(start, end).map(entry).toList(),
      continuationToken: repeatToken ? '0' : (end < all.length ? '$end' : null),
    );
  }

  @override
  Future<void> deleteBackup(String name) async {
    if (denied.contains(name)) {
      throw const CloudBackupException('permission denied', status: 403);
    }
    files.remove(name);
    await afterDelete?.call();
    if (loseDeleteResponse) throw const CloudBackupException('outcome unknown');
  }

  @override
  Future<List<int>> downloadBackup(String name) async => files[name]!;
  @override
  Future<CloudBackupObjectState> inspectObject(String name) async =>
      files.containsKey(name)
      ? CloudBackupObjectState.exists
      : CloudBackupObjectState.missing;
  @override
  Future<void> uploadBackup(String name, List<int> bytes) async {
    files[name] = failUpload ? [0] : bytes;
    if (failUpload) throw const CloudBackupException('outcome unknown');
  }

  @override
  Future<void> ensureDirectory() async {}
  @override
  Future<void> deleteProbe(String name) async {}
  @override
  void close() {}
}
