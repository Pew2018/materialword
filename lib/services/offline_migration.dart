import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'backup_manager.dart';
import 'backup_service.dart';
import 'dictionary_packages.dart';

/// Explicit full offline migration. Ordinary backups retain only selections.
class OfflineMigration {
  static const maxBytes = 200 * 1024 * 1024;
  static Future<Uint8List> export(
    BackupService backup,
    DictionaryPackages packages,
    DateTime now,
  ) async {
    final data = await backup.buildDataset(now: now);
    for (final row in data['dictionaryPackages'] as List) {
      if (row['enabled'] == true &&
          (row['id'] != DictionaryPackages.id ||
              row['version'] != DictionaryPackages.revision ||
              row['sha256'] != DictionaryPackages.digest)) {
        throw const FormatException('所选词典版本不可用，无法创建完整离线迁移包');
      }
    }
    if ((await packages.missing()).isNotEmpty) {
      throw const FormatException('词典资源缺失，无法创建完整离线迁移包');
    }
    final bundled = await rootBundle.load('assets/dictionary/ecdict_core.db');
    final files = <String, List<int>>{
      'backup.json': utf8.encode(await encodeDatasetJson(data)),
      'ecdict_core.db': bundled.buffer.asUint8List(
        bundled.offsetInBytes,
        bundled.lengthInBytes,
      ),
      'ECDICT_LICENSE.txt': utf8.encode(
        await rootBundle.loadString('assets/dictionary/ECDICT_LICENSE.txt'),
      ),
    };
    if ((data['dictionaryPackages'] as List).any((r) => r['enabled'] == true)) {
      final content = await (await packages.file()).readAsBytes();
      if (sha256.convert(content).toString() != DictionaryPackages.digest) {
        throw const FormatException('词典资源损坏，无法创建完整离线迁移包');
      }
      files['ecdict_extended.db'] = content;
    }
    files['manifest.json'] = utf8.encode(
      jsonEncode({
        'kind': 'materialword-offline-migration',
        'schemaVersion': 1,
        'files': {
          for (final e in files.entries)
            e.key: {
              'bytes': e.value.length,
              'sha256': sha256.convert(e.value).toString(),
            },
        },
      }),
    );
    if (files.values.fold<int>(0, (n, b) => n + b.length) > maxBytes) {
      throw const FormatException('离线迁移包超过 200 MiB');
    }
    final archive = Archive();
    for (final e in files.entries) {
      archive.addFile(ArchiveFile.noCompress(e.key, e.value.length, e.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static Future<RestoreOutcome> restore(
    List<int> bytes,
    BackupManager manager,
    DictionaryPackages packages,
  ) async {
    if (bytes.length > maxBytes + 4096) throw const FormatException('离线迁移包过大');
    final dir = ZipDirectory.read(InputStream(bytes));
    final names = <String>{};
    var total = 0;
    const allowed = {
      'manifest.json',
      'backup.json',
      'ecdict_core.db',
      'ecdict_extended.db',
      'ECDICT_LICENSE.txt',
    };
    if (dir.numberOfThisDisk != 0 ||
        dir.diskWithTheStartOfTheCentralDirectory != 0 ||
        dir.fileHeaders.length > 5 ||
        dir.totalCentralDirectoryEntries != dir.fileHeaders.length) {
      throw const FormatException('离线迁移文件清单无效');
    }
    for (final h in dir.fileHeaders) {
      final local = h.file!;
      if (!allowed.contains(h.filename) ||
          !names.add(h.filename) ||
          h.filename != local.filename ||
          h.compressionMethod != 0 ||
          local.compressionMethod != 0 ||
          h.uncompressedSize != local.uncompressedSize ||
          h.compressedSize != local.compressedSize ||
          h.compressedSize != h.uncompressedSize ||
          (h.generalPurposeBitFlag & 1) != 0) {
        throw const FormatException('离线迁移包路径或大小无效');
      }
      total += h.uncompressedSize!;
      if (total > maxBytes) throw const FormatException('离线迁移包展开过大');
    }
    if (!names.containsAll({
      'manifest.json',
      'backup.json',
      'ecdict_core.db',
      'ECDICT_LICENSE.txt',
    })) {
      throw const FormatException('离线迁移包缺少资源');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final files = <String, List<int>>{};
    for (final file in archive) {
      if (!file.isFile || file.isSymbolicLink) {
        throw const FormatException('离线迁移包包含特殊文件');
      }
      files[file.name] = file.content as List<int>;
    }
    final manifest = jsonDecode(utf8.decode(files['manifest.json']!)) as Map;
    if (manifest['kind'] != 'materialword-offline-migration' ||
        manifest['schemaVersion'] != 1) {
      throw const FormatException('不支持的离线迁移版本');
    }
    final expected = manifest['files'] as Map;
    if (expected.length != files.length - 1) {
      throw const FormatException('离线迁移清单不完整');
    }
    for (final e in files.entries.where((e) => e.key != 'manifest.json')) {
      final row = expected[e.key] as Map;
      if (row['bytes'] != e.value.length ||
          row['sha256'] != sha256.convert(e.value).toString()) {
        throw const FormatException('离线迁移包校验失败');
      }
    }
    final core = jsonDecode(
      await rootBundle.loadString('assets/dictionary/ecdict_core.db.meta.json'),
    ) as Map;
    if (sha256.convert(files['ecdict_core.db']!).toString() != core['sha256']) {
      throw const FormatException('默认词典版本不同，请使用对应版本应用恢复');
    }
    final data = await manager.backup.decodeDatasetAsync(
      utf8.decode(files['backup.json']!),
    );
    for (final row in (data['dictionaryPackages'] as List?) ?? []) {
      if (row['enabled'] != true) continue;
      if (row['id'] != DictionaryPackages.id ||
          row['version'] != DictionaryPackages.revision ||
          row['sha256'] != DictionaryPackages.digest ||
          files['ecdict_extended.db'] == null) {
        throw const FormatException('离线迁移包缺少所需词典版本');
      }
    }
    if (files.containsKey('ecdict_extended.db')) {
      final ext = files['ecdict_extended.db']!;
      if (ext.length != DictionaryPackages.bytes ||
          sha256.convert(ext).toString() != DictionaryPackages.digest) {
        throw const FormatException('扩展词典内容无效');
      }
      final target = await packages.file();
      final temp = File('${target.path}.tmp');
      await temp.writeAsBytes(ext, flush: true);
      await temp.rename(target.path);
    }
    final temporary = File(
      '${(await manager.directory()).path}/offline-migration-input.json',
    );
    try {
      await temporary.writeAsBytes(files['backup.json']!, flush: true);
      return await manager.restoreSnapshot(temporary);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
