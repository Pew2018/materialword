import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:crypto/crypto.dart';

import '../core/database/app_database.dart';
import 'backup_service.dart';
import 'wordbook_export.dart';

/// A selected-book exchange, never a full-library replacement.
class LearningPackage {
  static const kind = 'materialword-learning-package';
  static const version = 1;
  static const maxBytes = 8 * 1024 * 1024;

  static Future<Uint8List> export(
    BackupService backup,
    Set<String> bookIds,
    WordBookExportFormat format,
    DateTime now,
  ) async {
    final data = await backup.buildDataset(now: now);
    List<Map<String, Object?>> rows(String key) => (data[key] as List)
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList();
    final books = rows('wordBooks')
        .where((b) => bookIds.contains(b['id']) && b['deletedAt'] == null)
        .toList();
    if (books.isEmpty || books.length != bookIds.length) {
      throw const FormatException('所选词书已变更，请刷新后重试');
    }
    final entries = rows('entries')
        .where(
          (e) => bookIds.contains(e['wordBookId']) && e['deletedAt'] == null,
        )
        .toList();
    final liveWords = rows('words')
        .where((w) => w['deletedAt'] == null)
        .toList();
    final ids = entries
        .map((e) => e['wordId'])
        .toSet()
        .intersection(liveWords.map((w) => w['id']).toSet());
    data['words'] = liveWords.where((w) => ids.contains(w['id'])).toList();
    data['wordBooks'] = books;
    data['entries'] = entries.where((e) => ids.contains(e['wordId'])).toList();
    for (final key in [
      'reviewEvents',
      'learningStates',
      'favorites',
      'wordTags',
    ]) {
      data[key] = rows(key).where((r) => ids.contains(r['wordId'])).toList();
    }
    final tagIds = rows('wordTags').map((r) => r['tagId']).toSet();
    data['tags'] = rows('tags').where((r) => tagIds.contains(r['id'])).toList();
    data.remove('settings');
    data['progressEventDigest'] = BackupService.eventDigest(
      data['reviewEvents'] as List,
    );
    backup.validateDataset(data);
    final wordById = {
      for (final w in data['words'] as List)
        w['id']: Word.fromJson({
          ...Map<String, dynamic>.from(w as Map),
          for (final field in ['createdAt', 'updatedAt', 'deletedAt'])
            field: w[field] == null
                ? null
                : DateTime.parse(w[field] as String).millisecondsSinceEpoch,
        }),
    };
    final exports = <WordBookExport>[
      for (final b in books)
        WordBookExport(
          book: WordBook.fromJson({
            ...b,
            for (final field in ['createdAt', 'updatedAt', 'deletedAt'])
              field: b[field] == null
                  ? null
                  : DateTime.parse(b[field] as String).millisecondsSinceEpoch,
          }),
          words: [
            for (final e in data['entries'] as List)
              if (e['wordBookId'] == b['id']) wordById[e['wordId']]!,
          ],
        ),
    ];
    final files = <String, List<int>>{
      'words.${format.extension}': utf8.encode(
        WordBookExporter.encodeBooks(exports, format, exportedAt: now),
      ),
      'progress.json': utf8.encode(jsonEncode(data)),
      'sources.json': utf8.encode(
        jsonEncode({
          'sources':
              (data['words'] as List).map((w) => w['source']).toSet().toList()
                ..sort(),
          'dictionary': {
            'source': 'https://github.com/skywind3000/ECDICT',
            'license': 'MIT',
            'note': 'Word source fields retain provenance; custom content belongs to its author.',
          },
        }),
      ),
    };
    final manifest = {
      'kind': kind,
      'schemaVersion': version,
      'bookIds': bookIds.toList()..sort(),
      'wordCount': ids.length,
      'eventCount': (data['reviewEvents'] as List).length,
      'files': {
        for (final entry in files.entries)
          entry.key: {
            'bytes': entry.value.length,
            'sha256': sha256.convert(entry.value).toString(),
          },
      },
    };
    files['manifest.json'] = utf8.encode(jsonEncode(manifest));
    if (files.values.fold<int>(0, (n, b) => n + b.length) > maxBytes) {
      throw const FormatException('学习包超过 8 MB，请减少所选词书');
    }
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(
        ArchiveFile.noCompress(entry.key, entry.value.length, entry.value),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// No extraction to disk. Only stored entries are accepted, with matching
  /// central/local sizes, before any content is read. This bounds memory even
  /// for hostile compression bombs. The application writes this ZIP subset.
  static Map<String, Object?> decode(List<int> bytes) {
    try {
      if (bytes.length > maxBytes + 4096) throw const FormatException('学习包过大');
      final dir = ZipDirectory.read(InputStream(bytes));
      if (dir.numberOfThisDisk != 0 ||
          dir.diskWithTheStartOfTheCentralDirectory != 0 ||
          dir.fileHeaders.length != 4 ||
          dir.totalCentralDirectoryEntries != 4) {
        throw const FormatException('学习包文件清单无效');
      }
      var total = 0;
      final names = <String>{};
      for (final header in dir.fileHeaders) {
        final local = header.file!;
        final name = header.filename;
        if (!RegExp(
              r'^(manifest\.json|progress\.json|sources\.json|words\.(txt|csv|json))$',
            ).hasMatch(name) ||
            !names.add(name) ||
            local.filename != name ||
            header.compressionMethod != 0 ||
            local.compressionMethod != 0 ||
            header.uncompressedSize != local.uncompressedSize ||
            header.compressedSize != local.compressedSize ||
            header.compressedSize != header.uncompressedSize ||
            (header.generalPurposeBitFlag & 1) != 0) {
          throw const FormatException('学习包路径或压缩方式不受支持');
        }
        total += header.uncompressedSize!;
        if (total > maxBytes) throw const FormatException('学习包展开大小超过上限');
      }
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final files = <String, List<int>>{};
      for (final file in archive) {
        if (!file.isFile || file.isSymbolicLink) {
          throw const FormatException('学习包包含特殊文件');
        }
        files[file.name] = file.content as List<int>;
      }
      Map<String, Object?> json(String name) => Map<String, Object?>.from(
        jsonDecode(utf8.decode(files[name]!)) as Map,
      );
      final manifest = json('manifest.json');
      if (manifest['kind'] != kind || manifest['schemaVersion'] != version) {
        throw const FormatException('学习包版本不受支持，请升级应用');
      }
      final listed = manifest['files'] as Map;
      if (listed.length != 3 ||
          !names.containsAll([
            'manifest.json',
            'progress.json',
            'sources.json',
          ])) {
        throw const FormatException('学习包缺少文件');
      }
      for (final entry in files.entries.where(
        (e) => e.key != 'manifest.json',
      )) {
        final expected = listed[entry.key] as Map;
        if (expected['bytes'] != entry.value.length ||
            expected['sha256'] != sha256.convert(entry.value).toString()) {
          throw const FormatException('学习包校验失败');
        }
      }
      json('sources.json');
      final data = json('progress.json');
      if (data.containsKey('settings') ||
          data.containsKey('deviceSettings') ||
          data['schemaVersion'] != 5) {
        throw const FormatException('学习包数据范围无效');
      }
      final bookIds = (data['wordBooks'] as List).map((b) => b['id']).toSet();
      final declared = (manifest['bookIds'] as List).toSet();
      final wordIds = (data['words'] as List).map((w) => w['id']).toSet();
      final linked = (data['entries'] as List).map((e) => e['wordId']).toSet();
      if (bookIds.length != declared.length ||
          !bookIds.containsAll(declared) ||
          wordIds.length != linked.length ||
          !wordIds.containsAll(linked) ||
          manifest['wordCount'] != wordIds.length ||
          manifest['eventCount'] != (data['reviewEvents'] as List).length) {
        throw const FormatException('学习包范围与摘要不一致');
      }
      return data;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('学习包损坏或格式不受支持');
    }
  }
}
