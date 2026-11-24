import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/repositories/content_sync_repository.dart';
import '../core/repositories/word_repository.dart';

/// Called inside the backup transaction, after canonical words are resolved.
class WordMetadataSync {
  WordMetadataSync(this.db);
  final AppDatabase db;

  Future<Map<String, Object?>> snapshot() async {
    final favorites = await db.select(db.wordFavorites).get();
    final tags = await db.select(db.userTags).get();
    final links = await db.select(db.wordTags).get();
    final aliases = await (db.select(
      db.syncAliases,
    )..where((t) => t.kind.equals('tag'))).get();
    return {
      'favorites': favorites.map((r) => r.toJson()).toList(),
      'tags': tags
          .map(
            (r) => <String, Object?>{
              ...r.toJson(),
              if (aliases.any((a) => a.localId == r.id))
                'aliases': [
                  for (final a in aliases)
                    if (a.localId == r.id) a.aliasId,
                ]..sort(),
            },
          )
          .toList(),
      'wordTags': links.map((r) => r.toJson()).toList(),
    };
  }

  static List<Map<String, dynamic>> rows(
    Map<String, Object?> data,
    String key,
  ) => ((data[key] as List?) ?? [])
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();

  static void validate(
    Map<String, Object?> data,
    Set<String> wordIds,
    Never Function(String) invalid,
  ) {
    for (final key in ['favorites', 'tags', 'wordTags']) {
      if (data[key] != null &&
          (data[key] is! List ||
              (data[key] as List).any((r) => r is! Map<String, dynamic>))) {
        invalid(key);
      }
    }
    void version(Map<String, dynamic> row) {
      if (row['version'] is! int ||
          (row['version'] as int) < 1 ||
          row['updatedAt'] is! int ||
          row['deviceId'] is! String ||
          (row['deviceId'] as String).isEmpty ||
          (row['deletedAt'] != null && row['deletedAt'] is! int)) {
        invalid('metadata:版本');
      }
      for (final key in ['updatedAt', 'deletedAt']) {
        if (row[key] == null) continue;
        try {
          DateTime.fromMillisecondsSinceEpoch(row[key] as int);
        } on RangeError {
          invalid('metadata:时间');
        }
      }
    }

    final tagIds = <String>{}, claimedAliases = <String>{}, names = <String>{};
    for (final row in rows(data, 'tags')) {
      if (row['id'] is! String ||
          (row['id'] as String).isEmpty ||
          !tagIds.add(row['id'] as String) ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty ||
          (row['name'] as String).length > 80 ||
          row['normalized'] != normalizeWordKey(row['name'] as String)) {
        invalid('tags');
      }
      if (row['deletedAt'] == null && !names.add(row['normalized'] as String)) {
        invalid('tags:同名');
      }
      version(row);
      final aliases = row['aliases'];
      if (aliases != null &&
          (aliases is! List ||
              aliases.length > 256 ||
              aliases.any((a) => a is! String || a.isEmpty) ||
              aliases.toSet().length != aliases.length)) {
        invalid('tags:别名');
      }
      final ids = <String>{row['id'] as String, ...?aliases?.cast<String>()};
      if (ids.any(claimedAliases.contains)) invalid('tags:身份');
      claimedAliases.addAll(ids);
    }
    final favoriteIds = <String>{}, relationIds = <String>{};
    for (final row in rows(data, 'favorites')) {
      version(row);
      if (!wordIds.contains(row['wordId']) ||
          row['value'] is! bool ||
          !favoriteIds.add(row['wordId'] as String)) {
        invalid('favorites');
      }
    }
    for (final row in rows(data, 'wordTags')) {
      version(row);
      if (!wordIds.contains(row['wordId']) ||
          !tagIds.contains(row['tagId']) ||
          !relationIds.add(jsonEncode([row['wordId'], row['tagId']]))) {
        invalid('wordTags');
      }
    }
  }

  static bool wins(
    Map<String, dynamic> remote,
    Map<String, dynamic> local, {
    bool favorite = false,
  }) {
    final remoteRemoved = favorite
        ? remote['value'] == false
        : remote['deletedAt'] != null;
    final localRemoved = favorite
        ? local['value'] == false
        : local['deletedAt'] != null;
    if (remote['version'] == local['version'] &&
        remoteRemoved != localRemoved) {
      return remoteRemoved;
    }
    final comparison = ContentSyncRepository.compare(remote, local);
    if (comparison != 0) return comparison > 0;
    // Stable field order even if an external JSON writer reorders its keys.
    String key(Map<String, dynamic> row) {
      final fields = row.keys.where((k) => k != 'id' && k != 'aliases').toList()
        ..sort();
      return jsonEncode({for (final field in fields) field: row[field]});
    }

    return key(remote).compareTo(key(local)) > 0;
  }

  Future<int> merge(
    Map<String, Object?> data,
    Map<String, String> wordIds,
  ) async {
    int changes = 0;
    final content = ContentSyncRepository(db), tagIds = <String, String>{};
    for (final row in rows(data, 'tags')) {
      final remoteId = row['id'] as String;
      final aliases = (row['aliases'] as List?)?.cast<String>() ?? <String>[];
      final resolved = await content.resolve('tag', remoteId, aliases);
      UserTag? local;
      if (resolved != null) {
        local = await (db.select(
          db.userTags,
        )..where((t) => t.id.equals(resolved))).getSingleOrNull();
      } else if (row['deletedAt'] == null) {
        local =
            await (db.select(db.userTags)..where(
                  (t) =>
                      t.normalized.equals(row['normalized'] as String) &
                      t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
      }
      final id = local?.id ?? remoteId;
      tagIds[remoteId] = id;
      await content.remember('tag', id, [remoteId, ...aliases]);
      final incoming = UserTag.fromJson({...row, 'id': id});
      if (local != null) {
        // Tag deletion is final for this ID. Recreating a tag creates a new ID;
        // an offline rename cannot undo deletion even with a skewed clock.
        if (local.deletedAt != null && incoming.deletedAt == null) continue;
        if (!(local.deletedAt == null && incoming.deletedAt != null) &&
            !wins(incoming.toJson(), local.toJson())) {
          continue;
        }
      }
      if (incoming.deletedAt == null) {
        final duplicate =
            await (db.select(db.userTags)..where(
                  (t) =>
                      t.normalized.equals(incoming.normalized) &
                      t.deletedAt.isNull() &
                      t.id.equals(id).not(),
                ))
                .getSingleOrNull();
        if (duplicate != null) throw StateError('标签重命名与已有标签冲突，未合并数据');
      }
      if (local == null) {
        await db.into(db.userTags).insert(incoming);
      } else {
        await db.update(db.userTags).replace(incoming);
      }
      changes++;
    }
    for (final row in rows(data, 'favorites')) {
      final id = wordIds[row['wordId']]!;
      final incoming = FavoriteRow.fromJson({...row, 'wordId': id});
      final local = await (db.select(
        db.wordFavorites,
      )..where((t) => t.wordId.equals(id))).getSingleOrNull();
      if (local != null &&
          !wins(incoming.toJson(), local.toJson(), favorite: true)) {
        continue;
      }
      await db
          .into(db.wordFavorites)
          .insert(incoming, mode: InsertMode.insertOrReplace);
      changes++;
    }
    for (final row in rows(data, 'wordTags')) {
      final wordId = wordIds[row['wordId']]!, tagId = tagIds[row['tagId']]!;
      final incoming = WordTag.fromJson({
        ...row,
        'wordId': wordId,
        'tagId': tagId,
      });
      final local =
          await (db.select(db.wordTags)
                ..where((t) => t.wordId.equals(wordId) & t.tagId.equals(tagId)))
              .getSingleOrNull();
      if (local != null && !wins(incoming.toJson(), local.toJson())) continue;
      await db
          .into(db.wordTags)
          .insert(incoming, mode: InsertMode.insertOrReplace);
      changes++;
    }
    return changes;
  }
}
