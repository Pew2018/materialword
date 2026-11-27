import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'content_sync_repository.dart';

const Uuid _uuid = Uuid();

/// A book plus the numbers the book list needs (word count, learned count…).
class WordBookSummary {
  const WordBookSummary({
    required this.book,
    required this.wordCount,
    required this.learnedCount,
    required this.dueCount,
  });

  final WordBook book;
  final int wordCount;
  final int learnedCount;
  final int dueCount;

  double get progress => wordCount == 0 ? 0 : learnedCount / wordCount;
}

class WordBookRepository {
  WordBookRepository(this.db);

  final AppDatabase db;

  Stream<List<WordBookSummary>> watchSummaries({required DateTime now}) {
    final int nowMs = now.millisecondsSinceEpoch;
    return db
        .customSelect(
          '''
SELECT b.id, b.name, b.description, b.source_type, b.source_url,
       b.revision, b.created_at, b.updated_at, b.deleted_at,
       (SELECT COUNT(*) FROM word_book_entries e
          JOIN words w ON w.id = e.word_id
         WHERE e.word_book_id = b.id AND e.deleted_at IS NULL
           AND w.deleted_at IS NULL) AS word_count,
       (SELECT COUNT(*) FROM word_book_entries e
          JOIN words w ON w.id = e.word_id
          JOIN learning_states ls ON ls.word_id = e.word_id
         WHERE e.word_book_id = b.id AND e.deleted_at IS NULL
           AND w.deleted_at IS NULL AND ls.stage != 0) AS learned_count,
       (SELECT COUNT(*) FROM word_book_entries e
          JOIN words w ON w.id = e.word_id
          JOIN learning_states ls ON ls.word_id = e.word_id
         WHERE e.word_book_id = b.id AND e.deleted_at IS NULL
           AND w.deleted_at IS NULL AND ls.stage != 0
           AND ls.next_review_at IS NOT NULL AND ls.next_review_at <= ?) AS due_count
  FROM word_books b
 WHERE b.deleted_at IS NULL
 ORDER BY b.created_at''',
          variables: <Variable<Object>>[Variable<int>(nowMs)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.wordBooks,
            db.wordBookEntries,
            db.words,
            db.learningStates,
          },
        )
        .watch()
        .map(
          (List<QueryRow> rows) => rows
              .map((QueryRow row) {
                return WordBookSummary(
                  book: WordBook(
                    id: row.read<String>('id'),
                    name: row.read<String>('name'),
                    description: row.read<String>('description'),
                    sourceType: row.read<String>('source_type'),
                    sourceUrl: row.read<String>('source_url'),
                    revision: row.read<int>('revision'),
                    createdAt: row.read<int>('created_at'),
                    updatedAt: row.read<int>('updated_at'),
                    deletedAt: row.readNullable<int>('deleted_at'),
                  ),
                  wordCount: row.read<int>('word_count'),
                  learnedCount: row.read<int>('learned_count'),
                  dueCount: row.read<int>('due_count'),
                );
              })
              .toList(growable: false),
        );
  }

  Future<List<WordBook>> listBooks() {
    return (db.select(db.wordBooks)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy(<OrderClauseGenerator<$WordBooksTable>>[
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .get();
  }

  Future<WordBook?> byId(String id) => (db.select(
    db.wordBooks,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<WordBook> create({
    required String name,
    String description = '',
    String sourceType = 'manual',
    String sourceUrl = '',
    required DateTime now,
  }) async {
    final WordBook book = WordBook(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? '未命名词书' : name.trim(),
      description: description,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
      revision: 1,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      deletedAt: null,
    );
    await db.into(db.wordBooks).insert(book);
    return book;
  }

  Future<void> rename(String id, String name, {required DateTime now}) =>
      _edit(id, now: now, name: name.trim());

  Future<void> updateDescription(
    String id,
    String description, {
    required DateTime now,
  }) => _edit(id, now: now, description: description);

  /// Edits where an online book came from. Used when a discarded conflict value
  /// on `sourceType` / `sourceUrl` is restored; still a normal edit.
  Future<void> updateSource(
    String id, {
    String? sourceType,
    String? sourceUrl,
    required DateTime now,
  }) => _edit(id, now: now, sourceType: sourceType, sourceUrl: sourceUrl);

  /// Revives a soft-deleted book. Unlike [_edit] this is allowed to touch a
  /// tombstoned row, because the user explicitly asked for it.
  Future<void> restore(String id, {required DateTime now}) =>
      db.transaction(() async {
        final WordBook? book = await byId(id);
        if (book == null || book.deletedAt == null) return;
        final updated = book.copyWith(
          deletedAt: const Value<int?>(null),
          updatedAt: now.millisecondsSinceEpoch,
          revision: book.revision + 1,
        );
        await ContentSyncRepository(db)
            .recordEdit('book', id, book.toJson(), updated.toJson(), now: now);
        await db.update(db.wordBooks).replace(updated);
      });

  Future<void> _edit(
    String id, {
    required DateTime now,
    String? name,
    String? description,
    String? sourceType,
    String? sourceUrl,
  }) => db.transaction(() async {
    final book = await byId(id);
    if (book == null || book.deletedAt != null) return;
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isEmpty) {
      throw StateError('词书名称不能为空');
    }
    final updated = book.copyWith(
      name: trimmedName,
      description: description,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
      updatedAt: now.millisecondsSinceEpoch,
      revision: book.revision + 1,
    );
    if (!ContentSyncRepository.bookFields.any(
      (field) => book.toJson()[field] != updated.toJson()[field],
    )) {
      return;
    }
    await ContentSyncRepository(db)
        .recordEdit('book', id, book.toJson(), updated.toJson(), now: now);
    await db.update(db.wordBooks).replace(updated);
  });

  /// Soft delete keeps the row (and its sync tombstone) while hiding the book.
  Future<void> softDelete(String id, {required DateTime now}) async {
    await db.transaction(() async {
      final WordBook? book = await byId(id);
      if (book == null) return;
      if (book.deletedAt != null) return;
      final updated = book.copyWith(
        deletedAt: Value(now.millisecondsSinceEpoch),
        updatedAt: now.millisecondsSinceEpoch,
        revision: book.revision + 1,
      );
      await ContentSyncRepository(db)
          .recordEdit('book', id, book.toJson(), updated.toJson(), now: now);
      await db.update(db.wordBooks).replace(updated);
      await (db.update(db.studySettings)
            ..where((t) => t.currentWordBookId.equals(id)))
          .write(const StudySettingsCompanion(currentWordBookId: Value(null)));
    });
  }

  /// Adds words to a book. A previously removed word is *revived* (version + 1)
  /// rather than inserted twice, so "remove then add again" is a well-defined
  /// state instead of a tombstone/insert conflict.
  ///
  /// Returns how many links became live (0 means everything was already there).
  Future<int> addWords(
    String bookId,
    Iterable<String> wordIds, {
    required DateTime now,
  }) async {
    int linked = 0;
    final int millis = now.millisecondsSinceEpoch;
    await db.transaction(() async {
      for (final String wordId in wordIds.toList(growable: false)) {
        final WordBookEntry? existing =
            await (db.select(db.wordBookEntries)..where(
                  (t) => t.wordBookId.equals(bookId) & t.wordId.equals(wordId),
                ))
                .getSingleOrNull();
        if (existing == null) {
          await db
              .into(db.wordBookEntries)
              .insert(
                WordBookEntriesCompanion.insert(
                  wordBookId: bookId,
                  wordId: wordId,
                  addedAt: millis,
                  version: const Value<int>(1),
                  updatedAt: Value<int>(millis),
                ),
                mode: InsertMode.insertOrIgnore,
              );
          linked++;
          continue;
        }
        if (existing.deletedAt == null) continue;
        await db
            .update(db.wordBookEntries)
            .replace(
              existing.copyWith(
                deletedAt: const Value<int?>(null),
                version: existing.version + 1,
                updatedAt: millis,
              ),
            );
        linked++;
      }
    });
    return linked;
  }

  /// Removes one word from one book without touching any other book.
  Future<void> removeWord(
    String bookId,
    String wordId, {
    required DateTime now,
  }) async {
    await removeWords(bookId, <String>[wordId], now: now);
  }

  /// Batch version of [removeWord]: writes tombstones so the removal survives a
  /// merge with an older dataset.
  Future<int> removeWords(
    String bookId,
    Iterable<String> wordIds, {
    required DateTime now,
  }) async {
    int removed = 0;
    final int millis = now.millisecondsSinceEpoch;
    await db.transaction(() async {
      for (final String wordId in wordIds.toList(growable: false)) {
        final WordBookEntry? existing =
            await (db.select(db.wordBookEntries)..where(
                  (t) => t.wordBookId.equals(bookId) & t.wordId.equals(wordId),
                ))
                .getSingleOrNull();
        if (existing == null || existing.deletedAt != null) continue;
        await db
            .update(db.wordBookEntries)
            .replace(
              existing.copyWith(
                deletedAt: Value<int?>(millis),
                version: existing.version + 1,
                updatedAt: millis,
              ),
            );
        removed++;
      }
    });
    return removed;
  }

  /// Live membership of [wordIds] in [bookId]. Tombstoned links are excluded.
  Future<Set<String>> liveWordIds(
    String bookId,
    Iterable<String> wordIds,
  ) async {
    final List<String> ids = wordIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const <String>{};
    final List<WordBookEntry> rows =
        await (db.select(db.wordBookEntries)..where(
              (t) =>
                  t.wordBookId.equals(bookId) &
                  t.wordId.isIn(ids) &
                  t.deletedAt.isNull(),
            ))
            .get();
    return rows.map((WordBookEntry row) => row.wordId).toSet();
  }

  Future<int> wordCount(String bookId) async {
    final QueryRow row = await db
        .customSelect(
          '''
SELECT COUNT(*) AS c
  FROM word_book_entries e
  JOIN words w ON w.id = e.word_id
 WHERE e.word_book_id = ? AND e.deleted_at IS NULL AND w.deleted_at IS NULL''',
          variables: <Variable<Object>>[Variable<String>(bookId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.wordBookEntries,
            db.words,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// Every live word of one book, alphabetically. Used by the exports; a book
  /// export is deliberately *not* a learning backup (no events, states or
  /// settings), and the UI says so.
  Future<List<Word>> wordsInBook(String bookId) async {
    final List<QueryRow> rows = await db
        .customSelect(
          '''
SELECT w.*
  FROM words w
  JOIN word_book_entries e ON e.word_id = w.id
 WHERE e.word_book_id = ? AND e.deleted_at IS NULL AND w.deleted_at IS NULL
 ORDER BY w.normalized, w.id''',
          variables: <Variable<Object>>[Variable<String>(bookId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.wordBookEntries,
            db.words,
          },
        )
        .get();
    return rows.map((QueryRow row) => db.words.map(row.data)).toList();
  }

  Future<void> _cleanupUnusedWord(String wordId) async {
    final List<WordBookEntry> links = await (db.select(
      db.wordBookEntries,
    )..where((t) => t.wordId.equals(wordId) & t.deletedAt.isNull())).get();
    if (links.isNotEmpty) return;
    final List<ReviewEvent> events = await (db.select(
      db.reviewEvents,
    )..where((t) => t.wordId.equals(wordId))).get();
    if (events.isNotEmpty) return; // keep history
    final List<LearningState> states = await (db.select(
      db.learningStates,
    )..where((t) => t.wordId.equals(wordId))).get();
    if (states.isEmpty) {
      await (db.delete(db.words)..where((t) => t.id.equals(wordId))).go();
    }
  }

  /// Drops words that are no longer referenced by any book *and* have no
  /// history. Only used by tests/cleanup, never for user-visible deletion.
  Future<int> pruneOrphans() async {
    final List<Word> words = await (db.select(
      db.words,
    )..where((t) => t.deletedAt.isNull())).get();
    int pruned = 0;
    for (final Word word in words) {
      final int before = await liveLinkCount(word.id);
      if (before == 0) {
        await _cleanupUnusedWord(word.id);
        pruned++;
      }
    }
    return pruned;
  }

  Future<int> liveLinkCount(String wordId) async {
    final QueryRow row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM word_book_entries '
          'WHERE word_id = ? AND deleted_at IS NULL',
          variables: <Variable<Object>>[Variable<String>(wordId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.wordBookEntries,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// Creates the book (if needed) and links every word id.
  ///
  /// Matching is by name so that two devices creating "CET-6" independently
  /// converge instead of showing a duplicate entry after the first sync.
  Future<WordBook> ensureBook({
    required String name,
    String description = '',
    String sourceType = 'manual',
    String sourceUrl = '',
    required DateTime now,
  }) async {
    final String trimmed = name.trim();
    final List<WordBook> books = await listBooks();
    for (final WordBook book in books) {
      if (book.name == trimmed) return book;
    }
    return create(
      name: name,
      description: description,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
      now: now,
    );
  }

  /// Refreshes an online-imported book: adds the new words, never deletes local
  /// ones and never touches notes or review history.
  Future<int> refreshFromSource({
    required String bookId,
    required Iterable<String> wordIds,
    required DateTime now,
  }) async {
    final int linked = await addWords(bookId, wordIds, now: now);
    final WordBook? book = await byId(bookId);
    if (book != null) {
      await db
          .update(db.wordBooks)
          .replace(
            book.copyWith(
              updatedAt: now.millisecondsSinceEpoch,
              revision: book.revision + 1,
            ),
          );
    }
    return linked;
  }
}
