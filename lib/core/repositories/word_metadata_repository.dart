import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'settings_repository.dart';
import 'word_repository.dart';

/// User-owned favorites and tags. Removals are retained for offline sync.
class WordMetadataRepository {
  WordMetadataRepository(this.db);
  final AppDatabase db;

  Stream<bool> watchFavorite(String wordId) =>
      (db.select(db.wordFavorites)..where((t) => t.wordId.equals(wordId)))
          .watchSingleOrNull()
          .map((row) => row?.value ?? false);

  Stream<List<UserTag>> watchTags({String? wordId}) {
    final query = db.select(db.userTags)..where((t) => t.deletedAt.isNull());
    if (wordId != null) {
      query.where(
        (t) => existsQuery(
          db.select(db.wordTags)..where(
            (r) =>
                r.tagId.equalsExp(t.id) &
                r.wordId.equals(wordId) &
                r.deletedAt.isNull(),
          ),
        ),
      );
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.normalized),
      (t) => OrderingTerm(expression: t.id),
    ]);
    return query.watch();
  }

  Future<List<UserTag>> listTags() =>
      (db.select(db.userTags)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm(expression: t.normalized),
              (t) => OrderingTerm(expression: t.id),
            ]))
          .get();

  Future<void> setFavorite(
    Iterable<String> wordIds,
    bool value, {
    required DateTime now,
  }) => db.transaction(() async {
    final device = await SettingsRepository(db).deviceId();
    for (final id in wordIds.toSet()) {
      await _requireWord(id);
      final old = await (db.select(
        db.wordFavorites,
      )..where((t) => t.wordId.equals(id))).getSingleOrNull();
      if (old?.value == value) continue;
      await db
          .into(db.wordFavorites)
          .insert(
            FavoriteRow(
              wordId: id,
              value: value,
              version: (old?.version ?? 0) + 1,
              updatedAt: now.millisecondsSinceEpoch,
              deviceId: device,
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  });

  Future<UserTag> createTag(String name, {required DateTime now}) =>
      db.transaction(() async {
        final clean = _name(name), key = normalizeWordKey(name);
        final existing =
            await (db.select(db.userTags)..where(
                  (t) => t.normalized.equals(key) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (existing != null) return existing;
        final tag = UserTag(
          id: const Uuid().v4(),
          name: clean,
          normalized: key,
          version: 1,
          updatedAt: now.millisecondsSinceEpoch,
          deviceId: await SettingsRepository(db).deviceId(),
          deletedAt: null,
        );
        await db.into(db.userTags).insert(tag);
        return tag;
      });

  Future<void> renameTag(String id, String name, {required DateTime now}) =>
      db.transaction(() async {
        final clean = _name(name);
        final tag = await _requireTag(id);
        if (tag.name == clean) return;
        final duplicate =
            await (db.select(db.userTags)..where(
                  (t) =>
                      t.normalized.equals(normalizeWordKey(clean)) &
                      t.deletedAt.isNull() &
                      t.id.equals(id).not(),
                ))
                .getSingleOrNull();
        if (duplicate != null) throw StateError('同名标签已存在');
        await db
            .update(db.userTags)
            .replace(
              tag.copyWith(
                name: clean,
                normalized: normalizeWordKey(clean),
                version: tag.version + 1,
                updatedAt: now.millisecondsSinceEpoch,
                deviceId: await SettingsRepository(db).deviceId(),
              ),
            );
      });

  Future<void> deleteTag(String id, {required DateTime now}) =>
      db.transaction(() async {
        final tag = await (db.select(
          db.userTags,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (tag == null || tag.deletedAt != null) return;
        final device = await SettingsRepository(db).deviceId(),
            millis = now.millisecondsSinceEpoch;
        await db
            .update(db.userTags)
            .replace(
              tag.copyWith(
                version: tag.version + 1,
                updatedAt: millis,
                deviceId: device,
                deletedAt: Value(millis),
              ),
            );
        final links = await (db.select(
          db.wordTags,
        )..where((t) => t.tagId.equals(id) & t.deletedAt.isNull())).get();
        await db.batch((batch) {
          for (final link in links) {
            batch.replace(
              db.wordTags,
              link.copyWith(
                version: link.version + 1,
                updatedAt: millis,
                deviceId: device,
                deletedAt: Value(millis),
              ),
            );
          }
        });
      });

  Future<void> setTag(
    Iterable<String> wordIds,
    String tagId,
    bool assigned, {
    required DateTime now,
  }) => db.transaction(() async {
    await _requireTag(tagId);
    final device = await SettingsRepository(db).deviceId(),
        millis = now.millisecondsSinceEpoch;
    for (final id in wordIds.toSet()) {
      await _requireWord(id);
      final old =
          await (db.select(db.wordTags)
                ..where((t) => t.wordId.equals(id) & t.tagId.equals(tagId)))
              .getSingleOrNull();
      if (old != null && (old.deletedAt == null) == assigned) continue;
      // Even removing an absent relation writes a tombstone, so an offline
      // version-1 assignment cannot restore it on the next sync.
      await db
          .into(db.wordTags)
          .insert(
            WordTag(
              wordId: id,
              tagId: tagId,
              version: (old?.version ?? 0) + 1,
              updatedAt: millis,
              deviceId: device,
              deletedAt: assigned ? null : millis,
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  });

  Future<void> _requireWord(String id) async {
    final row = await (db.select(
      db.words,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (row == null) throw StateError('单词已删除或不存在');
  }

  Future<UserTag> _requireTag(String id) async {
    final row = await (db.select(
      db.userTags,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (row == null) throw StateError('标签已删除或不存在');
    return row;
  }

  String _name(String raw) {
    final name = raw.trim();
    if (name.isEmpty || name.length > 80) throw StateError('标签名称须为 1–80 个字符');
    return name;
  }
}
