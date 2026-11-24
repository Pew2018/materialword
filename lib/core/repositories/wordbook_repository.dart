import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

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
       b.created_at, b.updated_at, b.deleted_at,
       (SELECT COUNT(*) FROM word_book_entries e
          JOIN words w ON w.id = e.word_id
         WHERE e.word_book_id = b.id AND w.deleted_at IS NULL) AS word_count,
       (SELECT COUNT(*) FROM word_book_entries e
          JOIN learning_states ls ON ls.word_id = e.word_id
         WHERE e.word_book_id = b.id AND ls.stage != 0) AS learned_count,
       (SELECT COUNT(*) FROM word_book_entries e
          JOIN learning_states ls ON ls.word_id = e.word_id
         WHERE e.word_book_id = b.id AND ls.stage != 0
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
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      deletedAt: null,
    );
    await db.into(db.wordBooks).insert(book);
    return book;
  }

  Future<void> rename(String id, String name, {required DateTime now}) async {
    final WordBook? book = await byId(id);
    if (book == null) return;
    await db
        .update(db.wordBooks)
        .replace(
          book.copyWith(
            name: name.trim(),
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> updateDescription(
    String id,
    String description, {
    required DateTime now,
  }) async {
    final WordBook? book = await byId(id);
    if (book == null) return;
    await db
        .update(db.wordBooks)
        .replace(
          book.copyWith(
            description: description,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
  }

  /// Soft delete keeps the row (and its sync tombstone) while hiding the book.
  Future<void> softDelete(String id, {required DateTime now}) async {
    final WordBook? book = await byId(id);
    if (book == null) return;
    await db
        .update(db.wordBooks)
        .replace(
          book.copyWith(
            deletedAt: Value<int?>(now.millisecondsSinceEpoch),
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
  }

  /// Adds words to a book, ignoring duplicates. Returns how many links were
  /// created (0 means everything was already in the book).
  Future<int> addWords(
    String bookId,
    Iterable<String> wordIds, {
    required DateTime now,
  }) async {
    int added = 0;
    await db.batch((Batch batch) {
      for (final String wordId in wordIds) {
        batch.insert(
          db.wordBookEntries,
          WordBookEntriesCompanion.insert(
            wordBookId: bookId,
            wordId: wordId,
            addedAt: now.millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
        added++;
      }
    });
    return added;
  }

  Future<void> removeWord(String bookId, String wordId) async {
    await (db.delete(db.wordBookEntries)
          ..where((t) => t.wordBookId.equals(bookId) & t.wordId.equals(wordId)))
        .go();
    await _cleanupUnusedWord(wordId);
  }

  Future<int> wordCount(String bookId) async {
    final Expression<int> count = db.wordBookEntries.wordId.count();
    final TypedResult row =
        await (db.selectOnly(db.wordBookEntries)
              ..addColumns(<Expression<Object>>[count])
              ..where(db.wordBookEntries.wordBookId.equals(bookId)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> _cleanupUnusedWord(String wordId) async {
    final List<WordBookEntry> links = await (db.select(
      db.wordBookEntries,
    )..where((t) => t.wordId.equals(wordId))).get();
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

  /// Creates the book (if needed) and links every word id.
  Future<WordBook> ensureBook({
    required String name,
    String description = '',
    String sourceType = 'manual',
    String sourceUrl = '',
    required DateTime now,
  }) async {
    final List<WordBook> books = await listBooks();
    for (final WordBook book in books) {
      if (book.name == name.trim()) return book;
    }
    return create(
      name: name,
      description: description,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
      now: now,
    );
  }
}
