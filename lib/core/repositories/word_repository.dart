import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Normalisation key used to detect duplicates ("Hello " and "hello" are the
/// same word). Kept in one place so import, quick-add and search agree.
String normalizeWordKey(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// A word together with its learning state (and how many books contain it).
class WordWithState {
  const WordWithState({
    required this.word,
    this.state,
    this.bookCount = 0,
    this.lastAnsweredAt,
  });

  final Word word;
  final LearningState? state;
  final int bookCount;
  final DateTime? lastAnsweredAt;

  bool get isLearned => (state?.stage ?? 0) != 0;

  DateTime? get nextReviewAt => state?.nextReviewAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          state!.nextReviewAt!,
          isUtc: true,
        ).toLocal();
}

const Uuid _uuid = Uuid();

class WordRepository {
  WordRepository(this.db);

  final AppDatabase db;

  static const int listLimit = 5000;

  Future<Word?> byId(String id) =>
      (db.select(db.words)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Word?> byNormalized(String key, {bool includeDeleted = false}) async {
    final query = db.select(db.words)
      ..where((t) => t.normalized.equals(normalizeWordKey(key)));
    if (!includeDeleted) {
      query.where((t) => t.deletedAt.isNull());
    }
    return query.getSingleOrNull();
  }

  /// Full text-ish search over word, translation and note.
  Stream<List<WordWithState>> watchSearch(
    String query, {
    String? bookId,
    int limit = 200,
  }) {
    final String needle = '%${query.trim().toLowerCase()}%';
    final joined = _joinedWords(bookId);
    if (query.trim().isNotEmpty) {
      joined.where(
        db.words.normalized.like(needle) |
            db.words.translation.like(needle) |
            db.words.definition.like(needle) |
            db.words.note.like(needle),
      );
    }
    joined.orderBy([OrderingTerm(expression: db.words.normalized)]);
    joined.limit(limit);
    return joined.watch().map(_mapRows);
  }

  /// Words of one book (or all words when [bookId] is null).
  Stream<List<WordWithState>> watchWords({
    String? bookId,
    String query = '',
    int limit = listLimit,
  }) {
    return watchSearch(query, bookId: bookId, limit: limit);
  }

  Future<List<WordWithState>> listWords({
    String? bookId,
    String query = '',
    int limit = listLimit,
  }) {
    return watchWords(bookId: bookId, query: query, limit: limit).first;
  }

  Future<int> countWords({String? bookId}) async {
    final Expression<int> count = db.words.id.count();
    final joined = _joinedWords(bookId)
      ..addColumns(<Expression<Object>>[count]);
    final TypedResult row = await joined.getSingle();
    return row.read(count) ?? 0;
  }

  JoinedSelectStatement _joinedWords(String? bookId) {
    final joined = db.select(db.words).join([
      leftOuterJoin(
        db.learningStates,
        db.learningStates.wordId.equalsExp(db.words.id),
      ),
    ]);
    joined.where(db.words.deletedAt.isNull());
    if (bookId != null) {
      joined.where(
        existsQuery(
          db.select(db.wordBookEntries)..where(
            (e) =>
                e.wordBookId.equals(bookId) & e.wordId.equalsExp(db.words.id),
          ),
        ),
      );
    }
    return joined;
  }

  List<WordWithState> _mapRows(List<TypedResult> rows) {
    return rows
        .map((TypedResult row) {
          final Word word = row.readTable(db.words);
          final LearningState? state = row.readTableOrNull(db.learningStates);
          return WordWithState(
            word: word,
            state: state,
            bookCount: 1,
            lastAnsweredAt: state?.lastStudiedAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    state!.lastStudiedAt!,
                    isUtc: true,
                  ).toLocal(),
          );
        })
        .toList(growable: false);
  }

  /// Returns the existing word for [text] or creates a new one. Deleted words
  /// are revived instead of duplicated, which keeps review history attached.
  Future<Word> ensureWord({
    required String text,
    String phonetic = '',
    String partOfSpeech = '',
    String translation = '',
    String definition = '',
    String example = '',
    String phrase = '',
    String note = '',
    String source = 'manual',
    String examTags = '',
    int bncRank = 0,
    int frqRank = 0,
    required DateTime now,
  }) async {
    final String key = normalizeWordKey(text);
    final Word? existing = await byNormalized(key, includeDeleted: true);
    final int millis = now.millisecondsSinceEpoch;
    if (existing != null) {
      if (existing.deletedAt != null) {
        // Revive: keep old progress, refresh empty metadata only.
        final Word revived = existing.copyWith(
          deletedAt: const Value<int?>(null),
          updatedAt: millis,
          revision: existing.revision + 1,
        );
        await db.update(db.words).replace(revived);
        return revived;
      }
      return existing;
    }
    final Word word = Word(
      id: _uuid.v4(),
      word: text.trim(),
      normalized: key,
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      translation: translation,
      definition: definition,
      example: example,
      phrase: phrase,
      note: note,
      source: source,
      examTags: examTags,
      bncRank: bncRank,
      frqRank: frqRank,
      customized: false,
      revision: 1,
      createdAt: millis,
      updatedAt: millis,
      deletedAt: null,
    );
    await db.into(db.words).insert(word);
    return word;
  }

  /// Edits made by the user. Marks the row as customised so that dictionary
  /// refreshes never overwrite it (see [applyDictionaryInfo]).
  Future<Word> updateContent(
    String id, {
    String? text,
    String? phonetic,
    String? partOfSpeech,
    String? translation,
    String? definition,
    String? example,
    String? phrase,
    String? note,
    required DateTime now,
  }) async {
    final Word? existing = await byId(id);
    if (existing == null) {
      throw StateError('word not found: $id');
    }
    final Word updated = existing.copyWith(
      word: text?.trim(),
      normalized: text == null ? null : normalizeWordKey(text),
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      translation: translation,
      definition: definition,
      example: example,
      phrase: phrase,
      note: note,
      customized: true,
      revision: existing.revision + 1,
      updatedAt: now.millisecondsSinceEpoch,
    );
    await db.update(db.words).replace(updated);
    return updated;
  }

  /// Fills in phonetic / translation / definition from the offline dictionary.
  /// Never overwrites content the user typed (T20).
  Future<Word> applyDictionaryInfo({
    required Word word,
    String? phonetic,
    String? partOfSpeech,
    String? translation,
    String? definition,
    String examTags = '',
    int bncRank = 0,
    int frqRank = 0,
    required DateTime now,
  }) async {
    String pick(String current, String? incoming) {
      if (incoming == null || incoming.trim().isEmpty) return current;
      if (current.trim().isNotEmpty) return current;
      return incoming.trim();
    }

    final Word updated = word.copyWith(
      phonetic: pick(word.phonetic, phonetic),
      partOfSpeech: pick(word.partOfSpeech, partOfSpeech),
      translation: pick(word.translation, translation),
      definition: pick(word.definition, definition),
      examTags: word.examTags.isEmpty ? examTags : word.examTags,
      bncRank: word.bncRank == 0 ? bncRank : word.bncRank,
      frqRank: word.frqRank == 0 ? frqRank : word.frqRank,
      updatedAt: now.millisecondsSinceEpoch,
      revision: word.revision + 1,
    );
    await db.update(db.words).replace(updated);
    return updated;
  }

  Future<void> softDelete(String id, {required DateTime now}) async {
    final Word? existing = await byId(id);
    if (existing == null) return;
    await db
        .update(db.words)
        .replace(
          existing.copyWith(
            deletedAt: Value<int?>(now.millisecondsSinceEpoch),
            updatedAt: now.millisecondsSinceEpoch,
            revision: existing.revision + 1,
          ),
        );
  }

  Future<void> hardDeleteIfUnused(String id) async {
    final List<WordBookEntry> entries = await (db.select(
      db.wordBookEntries,
    )..where((t) => t.wordId.equals(id))).get();
    final List<ReviewEvent> events = await (db.select(
      db.reviewEvents,
    )..where((t) => t.wordId.equals(id))).get();
    if (entries.isEmpty && events.isEmpty) {
      await (db.delete(db.words)..where((t) => t.id.equals(id))).go();
    }
  }

  Future<List<ReviewEvent>> eventsForWord(String wordId, {int limit = 50}) {
    return (db.select(db.reviewEvents)
          ..where((t) => t.wordId.equals(wordId))
          ..orderBy(<OrderClauseGenerator<$ReviewEventsTable>>[
            (t) =>
                OrderingTerm(expression: t.answeredAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  Future<LearningState?> stateFor(String wordId) => (db.select(
    db.learningStates,
  )..where((t) => t.wordId.equals(wordId))).getSingleOrNull();

  Future<Map<String, int>> bookIdsForWord(String wordId) async {
    final List<WordBookEntry> entries = await (db.select(
      db.wordBookEntries,
    )..where((t) => t.wordId.equals(wordId))).get();
    return <String, int>{
      for (final WordBookEntry e in entries) e.wordBookId: e.addedAt,
    };
  }
}
