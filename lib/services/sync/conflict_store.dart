import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/database/app_database.dart';
import '../../core/repositories/content_sync_repository.dart';

/// One recorded conflict: which field of which entity had two candidate values,
/// which one the deterministic merge rule kept, and which one was discarded.
class StoredSyncConflict {
  const StoredSyncConflict({
    required this.id,
    required this.kind,
    required this.entityId,
    required this.label,
    required this.field,
    required this.adoptedValue,
    required this.discardedValue,
    required this.adoptedVersion,
    required this.discardedVersion,
    required this.adoptedAt,
    required this.discardedAt,
    required this.deviceId,
    required this.recordedAt,
  });

  /// Stable dedupe key (kind|entity|field|adopted|discarded).
  final String id;
  final String kind;
  final String entityId;
  final String label;
  final String field;
  final Object? adoptedValue;
  final Object? discardedValue;
  final int adoptedVersion;
  final int discardedVersion;
  final int adoptedAt;
  final int discardedAt;
  final String deviceId;
  final DateTime recordedAt;

  bool get isWord => kind == 'word';

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind,
    'entityId': entityId,
    'label': label,
    'field': field,
    'adopted': adoptedValue,
    'discarded': discardedValue,
    'adoptedVersion': adoptedVersion,
    'discardedVersion': discardedVersion,
    'adoptedAt': adoptedAt,
    'discardedAt': discardedAt,
    'deviceId': deviceId,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  };

  static StoredSyncConflict? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? recorded = raw['recordedAt'];
    final DateTime? at = recorded is String
        ? DateTime.tryParse(recorded)
        : null;
    if (raw['id'] is! String ||
        raw['kind'] is! String ||
        raw['entityId'] is! String ||
        raw['field'] is! String ||
        at == null) {
      return null;
    }
    return StoredSyncConflict(
      id: raw['id'] as String,
      kind: raw['kind'] as String,
      entityId: raw['entityId'] as String,
      label: (raw['label'] as String?) ?? '',
      field: raw['field'] as String,
      adoptedValue: raw['adopted'],
      discardedValue: raw['discarded'],
      adoptedVersion: (raw['adoptedVersion'] as int?) ?? 0,
      discardedVersion: (raw['discardedVersion'] as int?) ?? 0,
      adoptedAt: (raw['adoptedAt'] as int?) ?? 0,
      discardedAt: (raw['discardedAt'] as int?) ?? 0,
      deviceId: (raw['deviceId'] as String?) ?? '',
      recordedAt: at.toLocal(),
    );
  }
}

/// Device-local conflict log, stored in `app_meta`.
///
/// Why `app_meta` and not a new table: the log is a bounded, disposable
/// diagnostic aid. Putting it in the database would mean a schema migration and
/// a new thing to sync, for data that must never leave this device.
///
/// The log only *records* what the deterministic merge did. Restoring the
/// discarded value is a brand-new ordinary edit, so it goes through the normal
/// field-version rules instead of rewriting history.
class SyncConflictStore {
  SyncConflictStore(this.db);

  final AppDatabase db;

  static const String storageKey = 'sync_conflicts_v1';
  static const int maxEntries = 50;

  Future<List<StoredSyncConflict>> list() async {
    final String? raw = await db.readMeta(storageKey);
    if (raw == null || raw.isEmpty) return const <StoredSyncConflict>[];
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const <StoredSyncConflict>[];
    }
    if (decoded is! List) return const <StoredSyncConflict>[];
    return <StoredSyncConflict>[
      for (final Object? item in decoded)
        if (StoredSyncConflict.fromJson(item) != null)
          StoredSyncConflict.fromJson(item)!,
    ];
  }

  /// Records conflicts, newest first, deduplicated and capped at [maxEntries].
  /// Returns how many *new* entries were added.
  Future<int> record(Iterable<FieldConflict> conflicts, {DateTime? now}) async {
    if (conflicts.isEmpty) return 0;
    final List<StoredSyncConflict> existing = await list();
    final Set<String> known = <String>{for (final c in existing) c.id};
    final List<StoredSyncConflict> added = <StoredSyncConflict>[];
    final DateTime at = now ?? DateTime.now();
    for (final FieldConflict conflict in conflicts) {
      final String id = conflictId(
        kind: conflict.kind,
        entityId: conflict.id,
        field: conflict.field,
        adopted: conflict.adoptedValue,
        discarded: conflict.discardedValue,
      );
      if (known.add(id)) {
        added.add(
          StoredSyncConflict(
            id: id,
            kind: conflict.kind,
            entityId: conflict.id,
            label: conflict.label,
            field: conflict.field,
            adoptedValue: conflict.adoptedValue,
            discardedValue: conflict.discardedValue,
            adoptedVersion: conflict.chosenRemote
                ? conflict.remoteVersion
                : conflict.localVersion,
            discardedVersion: conflict.chosenRemote
                ? conflict.localVersion
                : conflict.remoteVersion,
            adoptedAt: conflict.chosenRemote
                ? conflict.remoteUpdatedAt
                : conflict.localUpdatedAt,
            discardedAt: conflict.chosenRemote
                ? conflict.localUpdatedAt
                : conflict.remoteUpdatedAt,
            deviceId: conflict.deviceId,
            recordedAt: at,
          ),
        );
      }
    }
    if (added.isEmpty) return 0;
    final List<StoredSyncConflict> merged = <StoredSyncConflict>[
      ...added,
      ...existing,
    ].take(maxEntries).toList(growable: false);
    await db.writeMeta(
      storageKey,
      jsonEncode(<Map<String, Object?>>[
        for (final StoredSyncConflict entry in merged) entry.toJson(),
      ]),
    );
    return added.length;
  }

  Future<void> dismiss(String id) async {
    final List<StoredSyncConflict> entries = (await list())
        .where((StoredSyncConflict entry) => entry.id != id)
        .toList(growable: false);
    await _write(entries);
  }

  Future<void> clear() => db.deleteMeta(storageKey);

  Future<void> _write(List<StoredSyncConflict> entries) async {
    if (entries.isEmpty) {
      await db.deleteMeta(storageKey);
      return;
    }
    await db.writeMeta(
      storageKey,
      jsonEncode(<Map<String, Object?>>[
        for (final StoredSyncConflict entry in entries) entry.toJson(),
      ]),
    );
  }

  static String conflictId({
    required String kind,
    required String entityId,
    required String field,
    required Object? adopted,
    required Object? discarded,
  }) {
    final String material = <String>[
      kind,
      entityId,
      field,
      jsonEncode(adopted),
      jsonEncode(discarded),
    ].join('\u0001');
    return sha1.convert(utf8.encode(material)).toString().substring(0, 16);
  }
}

/// Books and words differ in how a discarded value is written back; the caller
/// implements the actual edit so the normal repository rules apply.
class ConflictResolution {
  const ConflictResolution({
    required this.kind,
    required this.entityId,
    required this.field,
    required this.value,
  });

  final String kind;
  final String entityId;
  final String field;
  final Object? value;
}
