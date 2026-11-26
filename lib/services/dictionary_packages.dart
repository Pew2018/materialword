import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../core/database/app_database.dart';
import '../core/repositories/settings_repository.dart';

/// Shared selection metadata, independent of local downloaded files.
class DictionaryPackages {
  DictionaryPackages(
    this.db, {
    Future<Directory> Function()? directory,
    http.Client? client,
  }) : directory = directory ?? defaultDirectory,
       client = client ?? http.Client();
  final AppDatabase db;
  final Future<Directory> Function() directory;
  final http.Client client;
  bool _busy = false;
  static const key = 'dictionary_packages_v1';
  static const id = 'ecdict-extended';
  static const revision = '39cfb9672c0906b63569e0453c2e6abfb9ab182a';
  static const digest =
      '5191d463881d63be80494928db778bd5a2bb90b5daac5f532098dc4e9cd840c5';
  static const downloadDigest =
      'e9cbfbb11a37443e545f17ee5b158f643f74db088a61e401059d791e66afe774';
  static const bytes = 96681984;
  static const downloadBytes = 39539385;
  static const count = 722442;
  static const source = 'https://github.com/skywind3000/ECDICT';
  static final url = Uri.parse(
    'https://raw.githubusercontent.com/Pew2018/materialword/51d27bb/resources/dictionaries/ecdict_extended.db.gz',
  );

  static Future<Directory> defaultDirectory() async => Directory(
    '${(await getApplicationSupportDirectory()).path}/dictionary/packages',
  )..createSync(recursive: true);

  static Future<List<Map<String, Object?>>> snapshot(AppDatabase db) async =>
      ((jsonDecode(await db.readMeta(key) ?? '[]')) as List)
          .map((e) => Map<String, Object?>.from(e as Map))
          .toList();

  static void validate(Object? raw) {
    if (raw is! List || raw.length > 20) throw const FormatException('词典清单无效');
    const fields = {
      'id',
      'version',
      'source',
      'license',
      'sha256',
      'enabled',
      'counter',
      'deviceId',
    };
    final seen = <String>{};
    for (final row in raw) {
      if (row is! Map ||
          row.keys.any((key) => !fields.contains(key)) ||
          row['id'] is! String ||
          !seen.add(row['id'] as String) ||
          row['version'] is! String ||
          row['source'] is! String ||
          row['license'] is! String ||
          row['sha256'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(row['sha256'] as String) ||
          row['enabled'] is! bool ||
          row['counter'] is! int ||
          (row['counter'] as int) < 0 ||
          row['deviceId'] is! String) {
        throw const FormatException('词典清单无效');
      }
    }
  }

  static Future<void> merge(
    AppDatabase db,
    Object? raw, {
    bool replace = false,
  }) async {
    if (raw == null) return;
    validate(raw);
    final all = <String, Map<String, Object?>>{
      if (!replace)
        for (final row in await snapshot(db)) row['id'] as String: row,
    };
    for (final node in raw as List) {
      final row = Map<String, Object?>.from(node as Map);
      final previous = all[row['id']];
      final order = previous == null
          ? 1
          : (row['counter'] as int).compareTo(previous['counter'] as int);
      if (order > 0 ||
          (order == 0 && jsonEncode(row).compareTo(jsonEncode(previous)) > 0)) {
        all[row['id'] as String] = row;
      }
    }
    final keys = all.keys.toList()..sort();
    await db.writeMeta(key, jsonEncode([for (final id in keys) all[id]]));
  }

  Future<void> setEnabled(bool enabled) => db.transaction(() async {
    final rows = await snapshot(db);
    final previous = rows.where((r) => r['id'] == id).firstOrNull;
    await merge(db, [
      {
        'id': id,
        'version': revision,
        'source': source,
        'license': 'MIT',
        'sha256': digest,
        'enabled': enabled,
        'counter': ((previous?['counter'] as int?) ?? 0) + 1,
        'deviceId': await SettingsRepository(db).deviceId(),
      },
    ]);
  });

  Future<File> file() async => File('${(await directory()).path}/$digest.db');
  Future<bool> installed() async {
    final resource = await file();
    return await resource.exists() &&
        await resource.length() == bytes &&
        sha256.convert(await resource.readAsBytes()).toString() == digest;
  }

  Future<bool> enabled() async => (await snapshot(db)).any(
    (r) =>
        r['id'] == id &&
        r['enabled'] == true &&
        r['version'] == revision &&
        r['sha256'] == digest,
  );
  Future<List<String>> missing() async {
    final result = <String>[];
    for (final row in await snapshot(db)) {
      if (row['enabled'] != true) continue;
      if (row['id'] != id ||
          row['sha256'] != digest ||
          row['version'] != revision ||
          !await installed()) {
        result.add('${row['id']} (${row['version']})');
      }
    }
    return result;
  }

  /// Resume only the immutable, hash-pinned resource. Interrupted .part files
  /// remain retryable; a bad download never replaces a working database.
  Future<void> install({void Function(int, int)? onProgress}) async {
    if (_busy) throw StateError('词典操作正在进行');
    _busy = true;
    try {
      final destination = await file();
      final partial = File('${destination.path}.gz.part');
      final offset = partial.existsSync() ? await partial.length() : 0;
      if (offset > downloadBytes) await partial.delete();
      final start = offset > downloadBytes ? 0 : offset;
      if (start < downloadBytes) {
        final request = http.Request('GET', url)..followRedirects = false;
        if (start > 0) request.headers['range'] = 'bytes=$start-';
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 30));
        final resumed =
            start > 0 &&
            response.statusCode == 206 &&
            response.headers['content-range'] ==
                'bytes $start-${downloadBytes - 1}/$downloadBytes';
        if (response.statusCode != 200 && !resumed) {
          throw const FormatException('词典下载失败，请重试');
        }
        var received = resumed ? start : 0;
        final sink = partial.openWrite(
          mode: resumed ? FileMode.append : FileMode.write,
        );
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 30),
          )) {
            received += chunk.length;
            if (received > downloadBytes) {
              throw const FormatException('词典下载大小无效');
            }
            sink.add(chunk);
            onProgress?.call(received, downloadBytes);
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      }
      final compressed = await partial.readAsBytes();
      if (compressed.length != downloadBytes ||
          sha256.convert(compressed).toString() != downloadDigest) {
        await partial.delete();
        throw const FormatException('词典下载校验失败，请重试');
      }
      final unpacked = gzip.decode(compressed);
      if (unpacked.length != bytes ||
          sha256.convert(unpacked).toString() != digest) {
        throw const FormatException('词典内容校验失败');
      }
      final temp = File('${destination.path}.tmp');
      await temp.writeAsBytes(unpacked, flush: true);
      final database = sqlite3.open(temp.path, mode: OpenMode.readOnly);
      try {
        if (database.userVersion != 2 ||
            database.select('PRAGMA quick_check').first.values.first != 'ok' ||
            database
                    .select('SELECT COUNT(*) AS n FROM dictionary')
                    .first['n'] !=
                count) {
          throw const FormatException('词典数据库无效');
        }
      } finally {
        database.close();
      }
      await temp.rename(destination.path);
      await partial.delete();
      await setEnabled(true);
    } finally {
      _busy = false;
    }
  }

  Future<void> uninstall() async {
    if (_busy) throw StateError('词典操作正在进行');
    _busy = true;
    try {
      await setEnabled(false);
      final installedFile = await file();
      if (await installedFile.exists()) await installedFile.delete();
    } finally {
      _busy = false;
    }
  }

  void close() => client.close();
}
