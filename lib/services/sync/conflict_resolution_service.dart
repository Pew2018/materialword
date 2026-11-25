import '../../core/database/app_database.dart';
import '../../core/repositories/word_repository.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../word_intake_service.dart';
import 'conflict_store.dart';

/// Thrown when a conflict cannot be restored, e.g. because the field is not one
/// the product lets a user recover. The conflict record is left in place.
class ConflictRestoreException implements Exception {
  const ConflictRestoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a successful recovery did, so the caller can describe it precisely.
class ConflictRestoreOutcome {
  const ConflictRestoreOutcome({
    required this.kind,
    required this.entityId,
    required this.field,
    required this.restoredValue,
  });

  final String kind;
  final String entityId;
  final String field;
  final Object? restoredValue;
}

/// Restores the value a merge had to discard.
///
/// Two guarantees this service exists for:
///
///  1. **No fake success.** Every field that can appear in a conflict record has
///     an explicit branch here; an unknown field is rejected before anything is
///     written. The old implementation lived in the widget, silently ignored
///     `examTags` / `bncRank` / `frqRank` / `source` / book `sourceType` /
///     `sourceUrl` / `deletedAt`, and still reported "已恢复".
///  2. **It is a new edit.** Every write goes through the normal repositories,
///     which call `ContentSyncRepository.recordEdit`, so the recovery gets a
///     fresh field version and propagates on the next sync. History is never
///     rewritten.
///
/// The conflict record is dismissed **only after** the write succeeded, so a
/// failure leaves the user with a retryable entry instead of a lost value.
class SyncConflictResolutionService {
  SyncConflictResolutionService({
    required this.db,
    required this.words,
    required this.wordBooks,
    required this.intake,
    required this.conflicts,
  });

  final AppDatabase db;
  final WordRepository words;
  final WordBookRepository wordBooks;
  final WordIntakeService intake;
  final SyncConflictStore conflicts;

  /// Word fields a user may recover, i.e. everything a field conflict can be
  /// recorded for. `ContentSyncRepository.wordFields` is exactly this set.
  static const Set<String> wordRestorableFields = <String>{
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
  };

  static const Set<String> bookRestorableFields = <String>{
    'name',
    'description',
    'sourceType',
    'sourceUrl',
    'deletedAt',
  };

  static Set<String> restorableFields(String kind) =>
      kind == 'word' ? wordRestorableFields : bookRestorableFields;

  /// True when the UI may offer a "恢复" button. A conflict whose field is not
  /// recoverable stays visible as a diagnostic record with no action.
  static bool canRestore(StoredSyncConflict conflict) =>
      (conflict.kind == 'word' || conflict.kind == 'book') &&
      restorableFields(conflict.kind).contains(conflict.field);

  /// Writes the discarded value back as a new local edit and dismisses the
  /// record. Throws [ConflictRestoreException] without dismissing on failure.
  Future<ConflictRestoreOutcome> restoreDiscardedValue(
    StoredSyncConflict conflict, {
    required DateTime now,
  }) async {
    if (!canRestore(conflict)) {
      throw ConflictRestoreException('该字段不支持恢复：${conflict.field}');
    }
    final Object? value = conflict.discardedValue;
    try {
      if (conflict.kind == 'word') {
        await _restoreWord(conflict, value, now);
      } else {
        await _restoreBook(conflict, value, now);
      }
    } on WordIntakeException catch (e) {
      throw ConflictRestoreException('intake rejected: ${e.code.name}');
    } on StateError catch (e) {
      throw ConflictRestoreException(e.message);
    }
    await conflicts.dismiss(conflict.id);
    return ConflictRestoreOutcome(
      kind: conflict.kind,
      entityId: conflict.entityId,
      field: conflict.field,
      restoredValue: value,
    );
  }

  Future<void> _restoreWord(
    StoredSyncConflict conflict,
    Object? value,
    DateTime now,
  ) async {
    final String id = conflict.entityId;
    switch (conflict.field) {
      case 'deletedAt':
        // `deletedAt == null` means the word is ALIVE, so restoring a null
        // discarded value must revive it; a non-null value must delete it.
        // (The previous implementation had these two the wrong way round.)
        if (value == null) {
          await intake.reviveById(id, now: now);
        } else {
          await words.softDelete(id, now: now);
        }
        return;
      case 'word':
        await words.updateContent(id, text: _text(value), now: now);
        return;
      case 'phonetic':
        await words.updateContent(id, phonetic: _text(value), now: now);
        return;
      case 'partOfSpeech':
        await words.updateContent(id, partOfSpeech: _text(value), now: now);
        return;
      case 'translation':
        await words.updateContent(id, translation: _text(value), now: now);
        return;
      case 'definition':
        await words.updateContent(id, definition: _text(value), now: now);
        return;
      case 'example':
        await words.updateContent(id, example: _text(value), now: now);
        return;
      case 'phrase':
        await words.updateContent(id, phrase: _text(value), now: now);
        return;
      case 'note':
        await words.updateContent(id, note: _text(value), now: now);
        return;
      case 'source':
        await words.updateMetadata(id, source: _text(value), now: now);
        return;
      case 'examTags':
        await words.updateMetadata(id, examTags: _text(value), now: now);
        return;
      case 'bncRank':
        await words.updateMetadata(id, bncRank: _int(value), now: now);
        return;
      case 'frqRank':
        await words.updateMetadata(id, frqRank: _int(value), now: now);
        return;
      default:
        throw ConflictRestoreException('该字段不支持恢复：${conflict.field}');
    }
  }

  Future<void> _restoreBook(
    StoredSyncConflict conflict,
    Object? value,
    DateTime now,
  ) async {
    final String id = conflict.entityId;
    final WordBook? book = await wordBooks.byId(id);
    if (book == null) throw const ConflictRestoreException('词书已不存在，无法恢复');
    switch (conflict.field) {
      case 'deletedAt':
        // Same direction rule as words: a null discarded value means "was
        // alive", so reviving is the restore.
        if (value == null) {
          await wordBooks.restore(id, now: now);
        } else {
          await wordBooks.softDelete(id, now: now);
        }
        return;
      case 'name':
        final String name = _text(value).trim();
        if (name.isEmpty) {
          throw const ConflictRestoreException('词书名称不能为空，无法恢复该值');
        }
        await wordBooks.rename(id, name, now: now);
        return;
      case 'description':
        await wordBooks.updateDescription(id, _text(value), now: now);
        return;
      case 'sourceType':
        await wordBooks.updateSource(id, sourceType: _text(value), now: now);
        return;
      case 'sourceUrl':
        await wordBooks.updateSource(id, sourceUrl: _text(value), now: now);
        return;
      default:
        throw ConflictRestoreException('该字段不支持恢复：${conflict.field}');
    }
  }

  /// Merge values come from JSON, where a text column can legitimately arrive as
  /// `null`; the columns themselves are non-null, so it restores as empty.
  static String _text(Object? value) => value?.toString() ?? '';

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }
}
