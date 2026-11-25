import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'settings_repository.dart';

/// One field where both devices wrote a different value and one side had to win.
///
/// The losing value is kept so the user can see what was discarded and restore
/// it as a *new* edit (through the normal version rules), instead of the app
/// silently dropping their work.
class FieldConflict {
  const FieldConflict({
    required this.kind,
    required this.id,
    required this.field,
    required this.localValue,
    required this.remoteValue,
    required this.chosenRemote,
    required this.localVersion,
    required this.remoteVersion,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    this.deviceId = '',
    this.label = '',
  });

  final String kind;
  final String id;
  final String field;
  final Object? localValue;
  final Object? remoteValue;

  /// Human-readable entity name (the word itself or the book name), captured at
  /// merge time so a conflict can be shown even after a later rename.
  final String label;

  /// True when the remote value won.
  final bool chosenRemote;
  final int localVersion;
  final int remoteVersion;
  final int localUpdatedAt;
  final int remoteUpdatedAt;
  final String deviceId;

  Object? get adoptedValue => chosenRemote ? remoteValue : localValue;

  Object? get discardedValue => chosenRemote ? localValue : remoteValue;
}

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

  /// Batch form of [saveVersions] for a merge: one INSERT batch for every
  /// entity instead of one batch per row.
  Future<void> saveVersionsBulk(
    String kind,
    Map<String, Map<String, Map<String, Object?>>> byEntity,
  ) async {
    final List<ContentVersionsCompanion> rows = <ContentVersionsCompanion>[];
    for (final MapEntry<String, Map<String, Map<String, Object?>>> entity
        in byEntity.entries) {
      for (final MapEntry<String, Map<String, Object?>> field
          in entity.value.entries) {
        rows.add(
          ContentVersionsCompanion.insert(
            kind: kind,
            entityId: entity.key,
            field: field.key,
            version: field.value['version'] as int,
            updatedAt: epoch(field.value['updatedAt']),
            deviceId: field.value['deviceId'] as String,
          ),
        );
      }
    }
    if (rows.isEmpty) return;
    await db.batch(
      (batch) => batch.insertAll(
        db.contentVersions,
        rows,
        mode: InsertMode.insertOrReplace,
      ),
    );
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
    final result = await mergeWithStamps(
      kind,
      id,
      local,
      remote,
      await versions(kind, id),
    );
    return (
      row: result.row,
      changed: result.changed,
      conflict: result.conflicts.isNotEmpty,
    );
  }

  /// Same rules as [merge], but the caller may supply the local stamps it
  /// already loaded (a 20 000-word merge must not issue 20 000 SELECTs).
  ///
  /// Only the rows whose stamps came from the database are persisted here; a
  /// batched caller is expected to save them itself.
  Future<
    ({
      Map<String, Object?> row,
      bool changed,
      bool conflict,
      List<FieldConflict> conflicts,
      Map<String, Map<String, Object?>> stamps,
    })
  >
  mergeWithStamps(
    String kind,
    String id,
    Map<String, Object?> local,
    Map<String, Object?> remote,
    Map<String, Map<String, Object?>> localStamps, {
    bool persistStamps = true,
  }) async {
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
    final conflicts = <FieldConflict>[];
    bool stampChanged = false, conflict = false, learnedStamps = false;
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
        conflicts.add(
          FieldConflict(
            kind: kind,
            id: id,
            field: field,
            localValue: local[field],
            remoteValue: remote[field],
            chosenRemote: order > 0,
            localVersion: old['version'] as int,
            remoteVersion: incoming['version'] as int,
            localUpdatedAt: epoch(old['updatedAt']),
            remoteUpdatedAt: epoch(incoming['updatedAt']),
            deviceId: (incoming['deviceId'] as String?) ?? '',
            label: kind == 'word'
                ? (local['word'] as String?) ?? ''
                : (local['name'] as String?) ?? '',
          ),
        );
      }
      if (order > 0) {
        merged[field] = remote[field];
        stamps[field] = incoming;
      } else if (!localStamps.containsKey(field) &&
          remoteStamps.containsKey(field)) {
        // The remote knows this field was edited and this device has no stamp
        // row at all. Adopt the remote stamp even when the value is identical,
        // otherwise the two databases would keep different version metadata
        // and never reach the same content hash.
        stamps[field] = incoming;
        learnedStamps = true;
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
    if (persistStamps && (localStamps.isNotEmpty || remoteStamps.isNotEmpty)) {
      // Include effective baseline stamps when one side has not edited this row
      // yet; otherwise the next edit could mistake a merged field for a new one.
      await saveVersions(kind, id, stamps);
    }
    return (
      row: merged,
      changed: changed || stampChanged || learnedStamps,
      conflict: conflict,
      conflicts: conflicts,
      stamps: stamps,
    );
  }

  /// Batched alias write: one INSERT per alias, inside a single batch instead
  /// of a read-then-insert round trip each.
  Future<void> rememberAll(
    String kind,
    Iterable<({String localId, Iterable<String> aliases})> groups,
    Map<String, String> knownAliases,
  ) async {
    final List<SyncAliasesCompanion> rows = <SyncAliasesCompanion>[];
    for (final ({String localId, Iterable<String> aliases}) group in groups) {
      for (final String alias in group.aliases.toSet()) {
        if (alias == group.localId) continue;
        final String? existing = knownAliases[alias];
        if (existing != null && existing != group.localId) {
          throw StateError('词条身份冲突，已停止合并');
        }
        knownAliases[alias] = group.localId;
        rows.add(
          SyncAliasesCompanion.insert(
            kind: kind,
            aliasId: alias,
            localId: group.localId,
          ),
        );
      }
    }
    if (rows.isEmpty) return;
    await db.batch(
      (batch) => batch.insertAll(
        db.syncAliases,
        rows,
        mode: InsertMode.insertOrIgnore,
      ),
    );
  }

  Future<String?> resolve(
    String kind,
    String remoteId,
    List<String> aliases,
  ) async {
    final candidates = {remoteId, ...aliases};
    final table = kind == 'word'
        ? db.words.actualTableName
        : kind == 'tag'
        ? db.userTags.actualTableName
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
