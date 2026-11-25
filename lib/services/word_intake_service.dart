import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/repositories/content_sync_repository.dart';
import '../core/repositories/word_repository.dart';
import '../core/repositories/wordbook_repository.dart';
import '../core/text/dictionary_text.dart';

/// Thrown when an add/re-add request cannot be applied. The message is meant for
/// the user, not for a log.
class WordIntakeException implements Exception {
  const WordIntakeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The seven dictionary-owned text fields of a word, plus `note`.
///
/// `null` means "not provided". An empty string means "the user cleared it" —
/// that distinction is the whole reason this type exists instead of positional
/// `String` arguments with `''` defaults.
class WordContent {
  const WordContent({
    this.phonetic,
    this.partOfSpeech,
    this.translation,
    this.definition,
    this.example,
    this.phrase,
    this.note,
  });

  final String? phonetic;
  final String? partOfSpeech;
  final String? translation;
  final String? definition;
  final String? example;
  final String? phrase;
  final String? note;

  static const WordContent empty = WordContent();

  bool get isEmpty =>
      phonetic == null &&
      partOfSpeech == null &&
      translation == null &&
      definition == null &&
      example == null &&
      phrase == null &&
      note == null;

  /// True when at least one field carries real text (an explicit `''` does not).
  bool get hasText => <String?>[
    phonetic,
    partOfSpeech,
    translation,
    definition,
    example,
    phrase,
    note,
  ].any((String? value) => value != null && value.trim().isNotEmpty);

  /// A request is "user authored" when the caller states a field value at all,
  /// including an explicit clear.
  bool get hasExplicitValues => !isEmpty;
}

/// What kind of change one intake request produced.
enum IntakeKind {
  /// A brand-new row was inserted.
  created,

  /// A soft-deleted row was revived (same UUID, same history).
  revived,

  /// An existing live row had at least one field updated.
  updated,

  /// The word already existed with exactly this content; nothing was written.
  unchanged,

  /// The word exists but is deleted and the caller did not ask for a revival.
  deletedSkipped,
}

class WordIntakeResult {
  const WordIntakeResult({
    required this.word,
    required this.kind,
    this.linkAdded = false,
    this.alreadyLinked = false,
    this.changedFields = const <String>[],
  });

  final Word word;
  final IntakeKind kind;

  /// True when the word was newly linked (or re-linked) to the target book.
  final bool linkAdded;

  /// True when the link already existed, so no book change happened.
  final bool alreadyLinked;

  final List<String> changedFields;

  bool get isNew => kind == IntakeKind.created;
  bool get isRevived => kind == IntakeKind.revived;

  /// A user-facing line that never claims more than what happened.
  String describe() => switch (kind) {
    IntakeKind.created => '已添加「${word.word}」',
    IntakeKind.revived =>
      linkAdded
          ? '已恢复「${word.word}」并加入词书（学习记录保留）'
          : '已恢复「${word.word}」（学习记录保留）',
    IntakeKind.updated =>
      changedFields.isEmpty
          ? '「${word.word}」内容无变化'
          : '已更新「${word.word}」的 ${changedFields.length} 个字段',
    IntakeKind.unchanged =>
      alreadyLinked ? '「${word.word}」已在词书中' : '「${word.word}」已存在，内容无变化',
    IntakeKind.deletedSkipped => '「${word.word}」已被删除，未自动恢复',
  };
}

/// One request to create, reuse or restore a word.
///
/// The three content blocks are applied in a fixed order and have different
/// authority, which is what keeps a dictionary refresh from overwriting user
/// text:
///
///  1. [user] — explicit user input: overwrites existing values, `''` clears;
///  2. [content] — file content from an import: only fills empty fields, and
///     marks the word as customised so later dictionary refreshes leave it
///     alone;
///  3. [dictionary] — the offline dictionary: only fills empty fields and never
///     marks the word as customised.
class WordIntakeRequest {
  const WordIntakeRequest({
    required this.text,
    this.user = WordContent.empty,
    this.content = WordContent.empty,
    this.dictionary = WordContent.empty,
    this.source = 'manual',
    this.examTags = '',
    this.bncRank = 0,
    this.frqRank = 0,
    this.allowRevive = true,
  });

  final String text;
  final WordContent user;
  final WordContent content;
  final WordContent dictionary;
  final String source;

  /// Dictionary metadata: never overwrites an existing value.
  final String examTags;
  final int bncRank;
  final int frqRank;

  /// Explicit re-add. When false (automatic word-book refresh), a deleted word
  /// stays deleted instead of being silently resurrected.
  final bool allowRevive;
}

/// The single write path for "add a word".
///
/// Every screen that adds words — quick add, batch paste, dictionary page, file
/// import, online word-book import and refresh — goes through here, so duplicate
/// detection, revival semantics, field-level versions and book links cannot
/// drift apart. Pages only collect input and render results.
class WordIntakeService {
  WordIntakeService({
    required this.db,
    required this.words,
    required this.wordBooks,
  });

  final AppDatabase db;
  final WordRepository words;
  final WordBookRepository wordBooks;

  /// Adds one word. Wrapped in a transaction so the word and its book link are
  /// written together or not at all.
  Future<WordIntakeResult> add(
    WordIntakeRequest request, {
    String? bookId,
    DateTime? now,
  }) => db.transaction(
    () => _add(request, bookId: bookId, now: now ?? DateTime.now()),
  );

  /// Adds many words in one transaction. Returns one result per request so the
  /// caller can report created / restored / unchanged / skipped separately.
  Future<List<WordIntakeResult>> addAll(
    Iterable<WordIntakeRequest> requests, {
    String? bookId,
    DateTime? now,
  }) => db.transaction(() async {
    final DateTime at = now ?? DateTime.now();
    if (bookId != null) await _requireLiveBook(bookId);
    final List<WordIntakeResult> results = <WordIntakeResult>[];
    for (final WordIntakeRequest request in requests) {
      results.add(await _add(request, bookId: bookId, now: at));
    }
    return results;
  });

  /// Explicitly restores a deleted word by id (used by the detail page and the
  /// "undo delete" affordance). Keeps the UUID, aliases and every review event.
  Future<WordIntakeResult> reviveById(
    String id, {
    String? bookId,
    DateTime? now,
  }) async {
    final Word? existing = await words.byId(id);
    if (existing == null) throw const WordIntakeException('词条不存在');
    return add(
      WordIntakeRequest(text: existing.word, allowRevive: true),
      bookId: bookId,
      now: now,
    );
  }

  Future<void> _requireLiveBook(String bookId) async {
    final WordBook? book = await wordBooks.byId(bookId);
    if (book == null || book.deletedAt != null) {
      throw const WordIntakeException('目标词书已被删除，请重新选择词书后再保存');
    }
  }

  Future<WordIntakeResult> _add(
    WordIntakeRequest request, {
    String? bookId,
    required DateTime now,
  }) async {
    final String text = request.text.trim();
    final String key = normalizeWordKey(text);
    if (key.isEmpty) throw const WordIntakeException('单词不能为空');
    if (text.length > 64) throw const WordIntakeException('单词过长（最多 64 个字符）');
    if (bookId != null) await _requireLiveBook(bookId);

    final Word? found = await words.byNormalized(key, includeDeleted: true);
    if (found == null) {
      final Word created = _composeNew(text, key, request, now);
      await db.into(db.words).insert(created);
      final bool linked = bookId == null
          ? false
          : await wordBooks.addWords(bookId, <String>[created.id], now: now) >
                0;
      return WordIntakeResult(
        word: created,
        kind: IntakeKind.created,
        linkAdded: linked,
        alreadyLinked: bookId != null && !linked,
        changedFields: <String>[
          if (created.phonetic.isNotEmpty) 'phonetic',
          if (created.partOfSpeech.isNotEmpty) 'partOfSpeech',
          if (created.translation.isNotEmpty) 'translation',
          if (created.definition.isNotEmpty) 'definition',
          if (created.example.isNotEmpty) 'example',
          if (created.phrase.isNotEmpty) 'phrase',
          if (created.note.isNotEmpty) 'note',
        ],
      );
    }

    final bool reviving = found.deletedAt != null;
    if (reviving && !request.allowRevive) {
      return WordIntakeResult(word: found, kind: IntakeKind.deletedSkipped);
    }

    final _Composed composed = _composeExisting(found, request, now, reviving);
    final Word updated = composed.word;
    // Whether to write is decided by the real before/after comparison inside
    // [_composeExisting], not by "did a text resolver fire". A metadata-only
    // re-add (import supplies examTags / bncRank / frqRank while every text
    // field already matches) used to compose a new row and then skip the
    // UPDATE, so the metadata was silently dropped.
    final bool changed = composed.changed;
    if (changed) {
      // recordEdit stamps exactly the fields that differ, with this device's id
      // and this instant, so the change wins a field-level conflict on another
      // device without touching the fields the user did not change.
      await ContentSyncRepository(db).recordEdit(
        'word',
        found.id,
        found.toJson(),
        updated.toJson(),
        now: now,
      );
      await db.update(db.words).replace(updated);
    }

    final bool linked = bookId == null
        ? false
        : await wordBooks.addWords(bookId, <String>[updated.id], now: now) > 0;
    return WordIntakeResult(
      word: updated,
      kind: reviving
          ? IntakeKind.revived
          : changed
          ? IntakeKind.updated
          : IntakeKind.unchanged,
      linkAdded: linked,
      alreadyLinked: bookId != null && !linked,
      changedFields: composed.changedFields,
    );
  }

  Word _composeNew(
    String text,
    String key,
    WordIntakeRequest request,
    DateTime now,
  ) {
    final int millis = now.millisecondsSinceEpoch;
    String choose(String? explicit, String? content, String? dict) {
      if (explicit != null) return explicit;
      if (content != null && content.trim().isNotEmpty) return content;
      if (dict != null && dict.trim().isNotEmpty) return dict;
      return '';
    }

    final WordContent user = request.user;
    final WordContent content = request.content;
    final WordContent dict = request.dictionary;
    final bool userAuthored = user.hasExplicitValues || content.hasText;
    return Word(
      id: _newId(),
      word: text,
      normalized: key,
      phonetic: normalizeDictionaryText(
        choose(user.phonetic, content.phonetic, dict.phonetic),
      ),
      partOfSpeech: normalizeDictionaryText(
        choose(user.partOfSpeech, content.partOfSpeech, dict.partOfSpeech),
      ),
      translation: normalizeDictionaryText(
        choose(user.translation, content.translation, dict.translation),
      ),
      definition: normalizeDictionaryText(
        choose(user.definition, content.definition, dict.definition),
      ),
      example: normalizeDictionaryText(
        choose(user.example, content.example, dict.example),
      ),
      phrase: normalizeDictionaryText(
        choose(user.phrase, content.phrase, dict.phrase),
      ),
      note: choose(user.note, content.note, dict.note),
      source: request.source,
      examTags: request.examTags,
      bncRank: request.bncRank,
      frqRank: request.frqRank,
      customized: userAuthored,
      revision: 1,
      createdAt: millis,
      updatedAt: millis,
      deletedAt: null,
    );
  }

  _Composed _composeExisting(
    Word found,
    WordIntakeRequest request,
    DateTime now,
    bool reviving,
  ) {
    final WordContent user = request.user;
    final WordContent content = request.content;
    final WordContent dict = request.dictionary;
    bool contentApplied = false;

    /// Explicit value wins (including `''`); otherwise keep a non-empty current
    /// value; otherwise take file content, then dictionary data.
    String resolve(
      String current,
      String? explicit,
      String? imported,
      String? dictionary, {
      bool normalize = true,
    }) {
      if (explicit != null) {
        return normalize ? normalizeDictionaryText(explicit) : explicit;
      }
      if (current.trim().isNotEmpty) return current;
      if (imported != null && imported.trim().isNotEmpty) {
        contentApplied = true;
        return normalize ? normalizeDictionaryText(imported) : imported;
      }
      if (dictionary != null && dictionary.trim().isNotEmpty) {
        return normalize ? normalizeDictionaryText(dictionary) : dictionary;
      }
      return current;
    }

    final Word updated = found.copyWith(
      phonetic: resolve(
        found.phonetic,
        user.phonetic,
        content.phonetic,
        dict.phonetic,
      ),
      partOfSpeech: resolve(
        found.partOfSpeech,
        user.partOfSpeech,
        content.partOfSpeech,
        dict.partOfSpeech,
      ),
      translation: resolve(
        found.translation,
        user.translation,
        content.translation,
        dict.translation,
      ),
      definition: resolve(
        found.definition,
        user.definition,
        content.definition,
        dict.definition,
      ),
      example: resolve(
        found.example,
        user.example,
        content.example,
        dict.example,
      ),
      phrase: resolve(found.phrase, user.phrase, content.phrase, dict.phrase),
      note: resolve(
        found.note,
        user.note,
        content.note,
        dict.note,
        normalize: false,
      ),
      examTags: found.examTags.isEmpty ? request.examTags : found.examTags,
      bncRank: found.bncRank == 0 ? request.bncRank : found.bncRank,
      frqRank: found.frqRank == 0 ? request.frqRank : found.frqRank,
      customized: found.customized || user.hasExplicitValues || contentApplied,
      deletedAt: reviving
          ? const Value<int?>(null)
          : const Value<int?>.absent(),
      revision: found.revision + 1,
      updatedAt: now.millisecondsSinceEpoch,
    );

    // One semantic diff for the whole row: every synced field plus the local
    // `customized` flag. `changedFields` is only a description for the UI; the
    // write decision is `changed`. The two JSON maps are built once — a 20 000
    // word import must not rebuild them per field.
    final Map<String, Object?> before = found.toJson();
    final Map<String, Object?> after = updated.toJson();
    final List<String> changed = <String>[
      for (final String field in ContentSyncRepository.wordFields)
        if (before[field] != after[field]) field,
      if (found.customized != updated.customized) 'customized',
    ];
    return _Composed(changed.isEmpty ? found : updated, changed);
  }

  static String _newId() => const Uuid().v4();
}

/// Internal result of composing an update: the row plus exactly which fields
/// changed, so the caller can skip a pointless write and report accurately.
class _Composed {
  const _Composed(this.word, this.changedFields);

  /// The row to persist. Identical to the row found on disk when nothing
  /// changed, so a caller can never report a revision that was never written.
  final Word word;
  final List<String> changedFields;

  bool get changed => changedFields.isNotEmpty;
}
