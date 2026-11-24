import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'settings_repository.dart';

/// Per-field edit stamps and retained identities; values stay in the entity
/// tables. A missing legacy field is never interpreted as an explicit erase.
class ContentSyncRepository {
  ContentSyncRepository(this.db);
  final AppDatabase db;
  static const wordFields = [
    'word',
    'phonetic',
    'partOfSpeech',
    'translation',
    'definition',
    'example',
    'phrase',
    'note',
    'source',
    'examTags',
    'bncRank',
    'frqRank',
    'deletedAt',
  ];
  static const bookFields = [
    'name',
    'description',
    'sourceType',
    'sourceUrl',
    'deletedAt',
  ];
  static List<String> fields(String kind) =>
      kind == 'word' ? wordFields : bookFields;

  static int epoch(Object? value) => value is int
      ? value
      : value is String
      ? DateTime.parse(value).toUtc().millisecondsSinceEpoch
      : 0;
  static Map<String, Object?> baseline(
    Map<String, Object?> row,
    String field,
  ) => {
    'version': field == 'deletedAt' && row[field] == null
        ? 0
        : (row['revision'] as int? ?? 1),
    'updatedAt': field == 'deletedAt' && row[field] == null
        ? 0
        : epoch(row['updatedAt']),
    'deviceId': '',
  };
  static int compare(Map<String, Object?> a, Map<String, Object?> b) {
    int result = (a['version'] as int).compareTo(b['version'] as int);
    if (result == 0) {
      result = epoch(a['updatedAt']).compareTo(epoch(b['updatedAt']));
    }
    if (result == 0) {
      result = (a['deviceId'] as String).compareTo(b['deviceId'] as String);
    }
    return result;
  }

  Future<Map<String, Map<String, Object?>>> versions(
    String kind,
    String id,
  ) async {
    final rows = await (db.select(
      db.contentVersions,
    )..where((t) => t.kind.equals(kind) & t.entityId.equals(id))).get();
    return {
      for (final row in rows)
        row.field: {
          'version': row.version,
          'updatedAt': row.updatedAt,
          'deviceId': row.deviceId,
        },
    };
  }

  Future<void> saveVersions(
    String kind,
    String id,
    Map<String, Map<String, Object?>> values,
  ) async {
    await db.batch(
      (batch) => batch.insertAll(
        db.contentVersions,
        values.entries
            .map(
              (entry) => ContentVersionsCompanion.insert(
                kind: kind,
                entityId: id,
                field: entry.key,
                version: entry.value['version'] as int,
                updatedAt: epoch(entry.value['updatedAt']),
                deviceId: entry.value['deviceId'] as String,
              ),
            )
            .toList(),
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  Future<void> recordEdit(
    String kind,
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after, {
    required DateTime now,
  }) async {
    final stamps = await versions(kind, id);
    for (final field in fields(kind)) {
      stamps.putIfAbsent(field, () => baseline(before, field));
    }
    final device = await SettingsRepository(db).deviceId();
    for (final field in fields(kind)) {
      if (before[field] != after[field]) {
        stamps[field] = {
          'version': (stamps[field]!['version'] as int) + 1,
          'updatedAt': now.millisecondsSinceEpoch,
          'deviceId': device,
        };
      }
    }
    await saveVersions(kind, id, stamps);
  }

  Future<({Map<String, Object?> row, bool changed, bool conflict})> merge(
    String kind,
    String id,
    Map<String, Object?> local,
    Map<String, Object?> remote,
  ) async {
    final localStamps = await versions(kind, id);
    final rawRemote = remote['fieldVersions'] as Map?;
    final remoteStamps = rawRemote == null
        ? <String, Map<String, Object?>>{}
        : rawRemote.map(
            (key, value) => MapEntry(
              key as String,
              Map<String, Object?>.from(value as Map),
            ),
          );
    final merged = Map<String, Object?>.of(local);
    final stamps = <String, Map<String, Object?>>{};
    bool stampChanged = false, conflict = false;
    for (final field in fields(kind)) {
      final old = localStamps[field] ?? baseline(local, field);
      stamps[field] = old;
      if (!remote.containsKey(field)) continue;
      final incoming = remoteStamps[field] ?? baseline(remote, field);
      int order = compare(incoming, old);
      // Concurrent deletion wins over an unacknowledged alive value. Revival
      // must increment the deletion stamp after observing the tombstone.
      if (field == 'deletedAt' &&
          incoming['version'] == old['version'] &&
          (remote[field] == null) != (local[field] == null)) {
        order = remote[field] == null ? -1 : 1;
      }
      if (order == 0 && remote[field] != local[field]) {
        order = jsonEncode(remote[field]).compareTo(jsonEncode(local[field]));
      }
      if (local[field] != remote[field] &&
          (old['version'] as int) > 1 &&
          (incoming['version'] as int) > 1) {
        conflict = true;
      }
      if (order > 0) {
        merged[field] = remote[field];
        stamps[field] = incoming;
      }
      if (jsonEncode(stamps[field]) != jsonEncode(old)) stampChanged = true;
    }
    merged['revision'] = math.max(
      local['revision'] as int? ?? 1,
      remote['revision'] as int? ?? 1,
    );
    merged['updatedAt'] = math.max(
      epoch(local['updatedAt']),
      epoch(remote['updatedAt']),
    );
    if (kind == 'word') {
      merged['customized'] =
          local['customized'] == true || remote['customized'] == true;
    }
    final changed =
        fields(kind).any((field) => merged[field] != local[field]) ||
        merged['revision'] != local['revision'] ||
        epoch(merged['updatedAt']) != epoch(local['updatedAt']);
    if (localStamps.isNotEmpty || remoteStamps.isNotEmpty) {
      // Include effective baseline stamps when one side has not edited this row
      // yet; otherwise the next edit could mistake a merged field for a new one.
      await saveVersions(kind, id, stamps);
    }
    return (row: merged, changed: changed || stampChanged, conflict: conflict);
  }

  Future<String?> resolve(
    String kind,
    String remoteId,
    List<String> aliases,
  ) async {
    final candidates = {remoteId, ...aliases};
    final table = kind == 'word'
        ? db.words.actualTableName
        : db.wordBooks.actualTableName;
    final slots = List.filled(candidates.length, '?').join(',');
    final variables = [for (final id in candidates) Variable<String>(id)];
    final direct = await db
        .customSelect(
          'SELECT id FROM $table WHERE id IN ($slots)',
          variables: variables,
        )
        .get();
    final mapped = await (db.select(
      db.syncAliases,
    )..where((t) => t.kind.equals(kind) & t.aliasId.isIn(candidates))).get();
    final found = {
      ...direct.map((r) => r.read<String>('id')),
      ...mapped.map((r) => r.localId),
    };
    if (found.length > 1) throw StateError('远程身份指向多个本机词条，请先处理重命名冲突');
    return found.firstOrNull;
  }

  Future<void> remember(
    String kind,
    String localId,
    Iterable<String> aliases,
  ) async {
    for (final alias in aliases.toSet()) {
      if (alias == localId) continue;
      final existing =
          await (db.select(db.syncAliases)
                ..where((t) => t.kind.equals(kind) & t.aliasId.equals(alias)))
              .getSingleOrNull();
      if (existing != null && existing.localId != localId) {
        throw StateError('词条身份冲突，已停止合并');
      }
      await db
          .into(db.syncAliases)
          .insert(
            SyncAliasesCompanion.insert(
              kind: kind,
              aliasId: alias,
              localId: localId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}
