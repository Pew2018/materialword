import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/models/enums.dart';
import '../core/models/study_models.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/study_repository.dart';
import '../core/time_utils.dart';

const Uuid _uuid = Uuid();

/// Where the drill is in its own lifecycle.
///
/// The cursor only moves on [PracticeSession.advance], never when an answer is
/// saved. That is what keeps the question on screen and the question the
/// session considers current the same thing during feedback.
enum PracticePhase {
  /// A batch is being built.
  loading,

  /// A question is on screen and accepts an answer.
  question,

  /// An answer is being written to the event log.
  submitting,

  /// The answer is saved and its feedback is shown for the same question.
  feedback,

  /// Every question in the batch has been left behind.
  finished,
}

/// One generated drill question.
class PracticeQuestion {
  const PracticeQuestion({
    required this.word,
    required this.kind,
    required this.prompt,
    required this.answer,
    this.options = const <String>[],
    this.correctIndex,
    this.contentSignature = '',
  });

  final Word word;
  final PracticeKind kind;

  /// What the user sees: a Chinese meaning, a cloze sentence, or (for
  /// dictation) an empty prompt plus a pronunciation button.
  final String prompt;

  /// The expected English word, already trimmed.
  final String answer;

  /// Multiple-choice options; empty for typed drills.
  final List<String> options;
  final int? correctIndex;

  /// Fingerprint of the word content the question was built from. A drill
  /// refuses to grade against content that changed behind its back.
  final String contentSignature;

  /// True when the exercise could not be built from real data (no example
  /// sentence, too few distinct distractors). Such a word is skipped instead of
  /// being turned into a fabricated or ambiguous question.
  bool get isSkipped => kind == PracticeKind.choice && options.length < 2;

  Map<String, Object?> toJson() => <String, Object?>{
    'wordId': word.id,
    'prompt': prompt,
    'answer': answer,
    'options': options,
    'correctIndex': correctIndex,
    'signature': contentSignature,
  };

  /// Rebuilds a question from a persisted batch. Only the identity and the
  /// already-rendered text are restored; the [Word] row is re-read by the
  /// caller and validated, so a stale row can never be graded.
  static PracticeQuestion? fromJson(
    Map<String, Object?> json,
    Word word,
    PracticeKind kind,
  ) {
    final Object? prompt = json['prompt'];
    final Object? answer = json['answer'];
    if (prompt is! String || answer is! String || answer.trim().isEmpty) {
      return null;
    }
    final List<String> options = <String>[
      for (final Object? option
          in (json['options'] as List? ?? const <Object>[]))
        if (option is String) option,
    ];
    final Object? index = json['correctIndex'];
    return PracticeQuestion(
      word: word,
      kind: kind,
      prompt: prompt,
      answer: answer,
      options: options,
      correctIndex: index is int && index >= 0 && index < options.length
          ? index
          : null,
      contentSignature: json['signature'] as String? ?? '',
    );
  }
}

/// One graded answer.
class PracticeOutcome {
  const PracticeOutcome({
    required this.correct,
    required this.answer,
    required this.submitted,
  });

  final bool correct;
  final String answer;
  final String submitted;
}

/// Summary of a finished drill.
class PracticeSummary {
  const PracticeSummary({
    required this.kind,
    required this.answered,
    required this.correct,
    required this.uniqueWords,
    required this.skipped,
    required this.wrongWords,
  });

  final PracticeKind kind;
  final int answered;
  final int correct;
  final int uniqueWords;
  final int skipped;
  final List<String> wrongWords;

  int get wrong => answered - correct;
  double? get accuracy => answered == 0 ? null : correct / answered;
}

/// Drives a practice drill.
///
/// A drill is *not* a review session: it reuses the event log so answers are
/// undoable, syncable and countable, but the long-term interval of every word
/// stays untouched (`ReviewEventMode.isPractice`).
///
/// The session owns an explicit state machine:
///
/// ```text
/// loading → question → submitting → feedback → question …  → finished
///                 ↑         ↓            │
///                 └── error ┘            └─ undo → question
/// ```
///
/// Invariants:
///  * the cursor moves only in [advance] (or back in [undo]);
///  * an answer can only be started from [PracticePhase.question], so a double
///    tap, a keyboard "done" racing a button, or a late async result can never
///    write the same answer twice;
///  * the last question also reaches [PracticePhase.feedback] before the
///    summary, so its feedback is never skipped;
///  * the batch survives a process restart through `app_meta`, without touching
///    the normal study session and without being synced as shared state.
class PracticeSession extends ChangeNotifier {
  PracticeSession(this._study, this._settings, this._clock);

  final StudyRepository _study;
  final SettingsRepository _settings;
  final Clock _clock;

  static const int defaultLimit = 20;

  /// Local-only key. Deliberately separate from
  /// `StudySession.persistenceKey`, and never part of the sync payload: a drill
  /// is a local attempt, not a shared learning plan.
  static const String persistenceKey = 'active_practice_session_v1';

  /// Share of a round reserved for words that have waited longest, mirroring
  /// the sprint scheduler's 80/20 idea. Hard words keep a real priority without
  /// being able to occupy every round forever.
  static const double coverageShare = 0.4;

  final List<PracticeQuestion> _questions = <PracticeQuestion>[];
  int _cursor = 0;
  PracticePhase _phase = PracticePhase.loading;
  PracticeOutcome? _outcome;
  bool _disposed = false;
  String? _error;
  String? _deviceId;
  String? _bookId;
  PracticeKind _kind = PracticeKind.spelling;
  DateTime? _startedAt;
  int _correct = 0;
  int _answered = 0;
  int _skipped = 0;
  final Set<String> _wrongWords = <String>{};
  Map<String, Object?>? _lastSubmission;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  PracticeKind get kind => _kind;
  PracticePhase get phase => _phase;
  bool get isLoading => _phase == PracticePhase.loading;
  bool get isBusy => _phase == PracticePhase.submitting;
  bool get isRevealed => _revealed;
  bool get isFeedback => _phase == PracticePhase.feedback;
  String? get error => _error;
  bool get isEmpty => _phase != PracticePhase.loading && _questions.isEmpty;
  bool get isFinished => _phase == PracticePhase.finished;
  bool get canUndo => _lastSubmission != null && !isBusy;
  bool _revealed = false;

  /// The question currently on screen. During feedback this is still the
  /// question that was answered — never the next one.
  PracticeQuestion? get current =>
      _cursor >= 0 &&
          _cursor < _questions.length &&
          _phase != PracticePhase.finished
      ? _questions[_cursor]
      : null;

  /// How many questions the drill has already left behind (0 … [total]).
  int get position => math.min(_cursor, _questions.length);

  /// One-based number of the question on screen, for the progress label.
  int get questionNumber =>
      _questions.isEmpty || _phase == PracticePhase.finished
      ? _questions.length
      : math.min(_cursor + 1, _questions.length);

  /// True when the question on screen is the last one in the batch.
  bool get isLastQuestion =>
      _questions.isNotEmpty && _cursor >= _questions.length - 1;

  int get total => _questions.length;
  int get correctCount => _correct;
  int get answeredCount => _answered;
  int get skippedCount => _skipped;

  /// Feedback for the question on screen, or null while it is unanswered.
  PracticeOutcome? get outcome => _outcome;

  double? get accuracy => _answered == 0 ? null : _correct / _answered;

  /// Loads a drill, resuming the persisted attempt when it still applies.
  ///
  /// [resume] must be true only when the user deliberately re-opens the same
  /// drill (e.g. the app was killed); a brand-new drill starts from scratch.
  Future<void> load({
    required PracticeKind kind,
    String? bookId,
    int limit = defaultLimit,
    bool resume = true,
  }) async {
    _phase = PracticePhase.loading;
    _error = null;
    _kind = kind;
    _bookId = bookId;
    _outcome = null;
    _revealed = false;
    notifyListeners();
    try {
      _deviceId ??= await _settings.deviceId();
      if (resume && await _restore(limit: limit)) {
        _phase = _questions.isEmpty
            ? PracticePhase.finished
            : PracticePhase.question;
        return;
      }
      final PracticeBatch batch = await _study.practiceBatch(
        now: _clock.now(),
        bookId: bookId,
        kind: kind,
        limit: limit,
      );
      _questions
        ..clear()
        ..addAll(_buildQuestions(batch));
      _cursor = 0;
      _correct = 0;
      _answered = 0;
      _skipped = 0;
      _wrongWords.clear();
      _lastSubmission = null;
      _startedAt = _clock.now();
      _phase = _questions.isEmpty
          ? PracticePhase.finished
          : PracticePhase.question;
      await _persist();
    } catch (e) {
      _error = '练习加载失败：$e';
      _phase = PracticePhase.finished;
    } finally {
      notifyListeners();
    }
  }

  List<PracticeQuestion> _buildQuestions(PracticeBatch batch) {
    final List<PracticeQuestion> questions = <PracticeQuestion>[];
    for (final Word word in batch.words) {
      final PracticeQuestion? question = _questionFor(word, batch.pool);
      if (question != null) questions.add(question);
    }
    return questions;
  }

  PracticeQuestion? _questionFor(Word word, List<Word> pool) {
    final String answer = word.word.trim();
    final String meaning = word.translation.trim();
    if (answer.isEmpty || meaning.isEmpty) return null;
    final String signature = contentSignatureOf(word);
    switch (_kind) {
      case PracticeKind.spelling:
        return PracticeQuestion(
          word: word,
          kind: _kind,
          prompt: meaning,
          answer: answer,
          contentSignature: signature,
        );
      case PracticeKind.dictation:
        return PracticeQuestion(
          word: word,
          kind: _kind,
          prompt: '',
          answer: answer,
          contentSignature: signature,
        );
      case PracticeKind.cloze:
        final String? sentence = StudyRepository.clozeSentenceFor(word);
        if (sentence == null) return null;
        return PracticeQuestion(
          word: word,
          kind: _kind,
          prompt: _blankOut(sentence, answer),
          answer: answer,
          contentSignature: signature,
        );
      case PracticeKind.choice:
        final List<String> options = _optionsFor(word, meaning, pool);
        if (options.length < 2) return null;
        return PracticeQuestion(
          word: word,
          kind: _kind,
          prompt: meaning,
          answer: answer,
          options: options,
          correctIndex: options.indexOf(answer),
          contentSignature: signature,
        );
    }
  }

  /// Fingerprint of the fields a drill depends on.
  static String contentSignatureOf(Word word) {
    final String joined = <String>[
      word.id,
      word.word.trim(),
      word.translation.trim(),
      word.example.trim(),
    ].join('\u0000');
    return sha256.convert(utf8.encode(joined)).toString().substring(0, 24);
  }

  /// Deterministic distractors: no duplicate spelling, no option that shares a
  /// real sense with the answer, and no near-identical option pair, so the
  /// question never has two defensible answers.
  ///
  /// This is a string/segment heuristic. It removes the obvious synonyms and
  /// the polysemous traps that the old first-segment-only check let through; it
  /// cannot prove semantic uniqueness, so a question that still has too few
  /// clean options is dropped instead of being padded.
  List<String> _optionsFor(Word word, String meaning, List<Word> pool) {
    final String answer = word.word.trim();
    final Set<String> answerSegments = meaningSegments(meaning);
    final math.Random random = math.Random(
      word.id.codeUnits.fold<int>(7, (int a, int b) => a * 31 + b),
    );
    final List<Word> candidates = pool.where((Word other) {
      if (_normalizeWord(other.word) == _normalizeWord(answer)) {
        return false;
      }
      if (other.translation.trim().isEmpty) return false;
      if (other.example.trim() == word.example.trim() &&
          other.example.trim().isNotEmpty) {
        return false;
      }
      final Set<String> segments = meaningSegments(other.translation);
      if (segments.isEmpty) return false;
      return segments.intersection(answerSegments).isEmpty;
    }).toList()..shuffle(random);
    final List<String> options = <String>[answer];
    final Set<String> seenWords = <String>{_normalizeWord(answer)};
    final Set<String> seenMeanings = <String>{};
    for (final Word other in candidates) {
      if (options.length >= 4) break;
      final String normalizedWord = _normalizeWord(other.word);
      if (seenWords.contains(normalizedWord)) continue;
      final Set<String> segments = meaningSegments(other.translation);
      if (segments.any(seenMeanings.contains)) continue;
      seenWords.add(normalizedWord);
      seenMeanings.addAll(segments);
      options.add(other.word.trim());
    }
    options.shuffle(random);
    return options;
  }

  /// Every distinct sense of a Chinese meaning, normalised for comparison.
  ///
  /// "n. 收获；收成" and "v. 收割" split into `收获/收成` and `收割`, so a word
  /// that merely shares one sense with the answer is recognised even when its
  /// first sense is different.
  static Set<String> meaningSegments(String value) {
    final Set<String> segments = <String>{};
    for (final String raw in value.split(RegExp(r'[\n;；,，、/|]'))) {
      String part = raw.trim().toLowerCase();
      if (part.isEmpty) continue;
      // Drop a leading part-of-speech marker such as "n." or "[adj.]".
      part = part.replaceFirst(
        RegExp(
          r'^[\[(（]?\s*(?:n|v|vt|vi|adj|adv|prep|conj|pron|num|art|int|aux)\.?\s*[\])）]?\.?\s*',
        ),
        '',
      );
      part = part
          .replaceAll(RegExp(r'[\s]+'), ' ')
          .replaceAll(RegExp(r'[.。!！?？:：]$'), '')
          .trim();
      if (part.isEmpty) continue;
      segments.add(part);
    }
    return segments;
  }

  /// Case-insensitive, whitespace-normalised comparison. Different words are
  /// never treated as equivalent: there is no fuzzy matching and no distance
  /// threshold.
  static String _normalizeWord(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool matches(String expected, String submitted) =>
      _normalizeWord(expected) == _normalizeWord(submitted);

  static String _blankOut(String sentence, String word) {
    final RegExp pattern = RegExp(
      '(?<![A-Za-z])${RegExp.escape(word)}(?![A-Za-z])',
      caseSensitive: false,
    );
    return sentence.replaceFirst(pattern, '____');
  }

  void reveal() {
    if (_revealed || current == null || _phase == PracticePhase.feedback) {
      return;
    }
    _revealed = true;
    notifyListeners();
  }

  /// Grades a typed answer (spelling / dictation / cloze).
  Future<PracticeOutcome?> submitTyped(String input) async {
    final PracticeQuestion? question = current;
    if (question == null || _phase != PracticePhase.question) return null;
    if (!question.kind.isTyped) return null;
    return _record(
      question,
      correct: matches(question.answer, input),
      input: input,
    );
  }

  /// Grades a multiple-choice answer.
  Future<PracticeOutcome?> submitChoice(int index) async {
    final PracticeQuestion? question = current;
    if (question == null || _phase != PracticePhase.question) return null;
    if (question.kind != PracticeKind.choice) return null;
    final bool correct = question.correctIndex == index;
    final String submitted = index >= 0 && index < question.options.length
        ? question.options[index]
        : '';
    return _record(question, correct: correct, input: submitted);
  }

  Future<PracticeOutcome?> _record(
    PracticeQuestion question, {
    required bool correct,
    required String input,
  }) async {
    // Claimed synchronously: a second tap, a keyboard "done" or a late async
    // result now finds the session in `submitting` and is ignored.
    _phase = PracticePhase.submitting;
    _error = null;
    notifyListeners();
    try {
      final String? stale = await _staleReason(question);
      if (stale != null) {
        _phase = PracticePhase.question;
        _error = stale;
        notifyListeners();
        return null;
      }
      final DateTime now = _clock.now();
      final AnswerRecord record = await _study.recordAnswer(
        wordId: question.word.id,
        result: correct ? AnswerResult.known : AnswerResult.unknown,
        type: ReviewType.review,
        eventId: _uuid.v4(),
        deviceId: _deviceId ?? 'unknown-device',
        now: now,
        mode: ReviewEventMode.forPractice(question.kind),
      );
      _answered++;
      if (correct) {
        _correct++;
      } else {
        _wrongWords.add(question.answer);
      }
      _lastSubmission = <String, Object?>{
        'eventId': record.eventId,
        'cursor': _cursor,
        'correct': _correct - (correct ? 1 : 0),
        'answered': _answered - 1,
        'wrongWords': _wrongWords.where((w) => w != question.answer).toList(),
        'wordId': question.word.id,
        'skipped': _skipped,
      };
      _outcome = PracticeOutcome(
        correct: correct,
        answer: question.answer,
        submitted: input,
      );
      _revealed = false;
      _phase = PracticePhase.feedback;
      await _persist();
      return _outcome;
    } catch (e) {
      _answered--;
      if (correct) {
        _correct--;
      } else {
        _wrongWords.remove(question.answer);
      }
      _lastSubmission = null;
      _outcome = null;
      _error = '保存练习结果失败：$e';
      _phase = PracticePhase.question;
      return null;
    } finally {
      notifyListeners();
    }
  }

  /// Whether the question can still be graded against the content it was built
  /// from.
  ///
  /// The question is stale when the word was deleted, removed from the target
  /// book, or its spelling / meaning / example changed — locally or by a sync
  /// merge. A stale question is never graded: the drill would otherwise write a
  /// wrong answer event under an old identity.
  Future<String?> _staleReason(PracticeQuestion question) async {
    final ManagedWord? row = await _study.managedWord(question.word.id);
    if (row == null) return '这个词已被删除，本组练习将重新开始';
    if (contentSignatureOf(row.word) != question.contentSignature) {
      return '这个词的内容已更新，请重新开始本组练习';
    }
    if (_bookId != null) {
      final link =
          await (_study.db.select(_study.db.wordBookEntries)..where(
                (t) =>
                    t.wordId.equals(question.word.id) &
                    t.wordBookId.equals(_bookId!) &
                    t.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (link == null) return '这个词已移出当前词书，本组练习将重新开始';
    }
    return null;
  }

  /// Leaves the answered question and moves on. Returns false when there is no
  /// feedback to leave (so "next" can never skip an unanswered question).
  bool advance() {
    if (_phase != PracticePhase.feedback) return false;
    _outcome = null;
    _revealed = false;
    if (_cursor + 1 >= _questions.length) {
      _cursor = _questions.length;
      _phase = PracticePhase.finished;
      unawaited(_clearPersisted());
    } else {
      _cursor++;
      _phase = PracticePhase.question;
      unawaited(_persist());
    }
    notifyListeners();
    return true;
  }

  /// Reverts the last practice answer (writes a real undo event, so the other
  /// devices converge on the same state).
  Future<bool> undo() async {
    final Map<String, Object?>? previous = _lastSubmission;
    if (previous == null || isBusy) return false;
    _phase = PracticePhase.submitting;
    _outcome = null;
    notifyListeners();
    try {
      await _study.undoAnswer(
        eventId: previous['eventId'] as String,
        undoId: _uuid.v4(),
        deviceId: _deviceId!,
        now: _clock.now(),
      );
      _cursor = previous['cursor'] as int;
      _correct = previous['correct'] as int;
      _answered = previous['answered'] as int;
      _skipped = previous['skipped'] as int? ?? _skipped;
      _wrongWords
        ..clear()
        ..addAll((previous['wrongWords'] as List).whereType<String>());
      _lastSubmission = null;
      _revealed = false;
      _phase = PracticePhase.question;
      await _persist();
      return true;
    } catch (_) {
      _error = '撤销失败，请重试';
      _phase = _questions.isEmpty
          ? PracticePhase.finished
          : PracticePhase.question;
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Moves past a word without recording anything (no answer, no allowance).
  ///
  /// Only possible while a question is actually on screen: pressing skip during
  /// feedback used to skip the *next* word and skew the counters.
  bool skip() {
    if (_phase != PracticePhase.question || current == null) return false;
    _skipped++;
    _revealed = false;
    if (_cursor + 1 >= _questions.length) {
      _cursor = _questions.length;
      _phase = PracticePhase.finished;
      unawaited(_clearPersisted());
    } else {
      _cursor++;
      unawaited(_persist());
    }
    notifyListeners();
    return true;
  }

  PracticeSummary summary() => PracticeSummary(
    kind: _kind,
    answered: _answered,
    correct: _correct,
    uniqueWords: _questions.length,
    skipped: _skipped,
    wrongWords: _wrongWords.toList()..sort(),
  );

  String? get bookId => _bookId;
  DateTime? get startedAt => _startedAt;

  // ------------------------------------------------------------ persistence

  /// Serialises every write to `app_meta`.
  ///
  /// Advancing and skipping persist without blocking the UI, so two writes can
  /// otherwise land out of order and leave an older snapshot behind — the exact
  /// shape of bug that makes a "resumed" drill jump backwards.
  Future<void> _writeChain = Future<void>.value();

  Future<void> _enqueueWrite(Future<void> Function() write) {
    final Future<void> next = _writeChain.then((_) => write());
    _writeChain = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  String _day(DateTime date) =>
      '${date.toLocal().year}-${date.toLocal().month}-${date.toLocal().day}';

  /// Writes the attempt to `app_meta`. Deliberately best-effort: a failed write
  /// costs a resume, never the drill itself.
  Future<void> _persist() => _enqueueWrite(() async {
    if (_questions.isEmpty) return;
    try {
      await _study.db.writeMeta(
        persistenceKey,
        jsonEncode(<String, Object?>{
          'version': 1,
          'kind': _kind.code,
          'bookId': _bookId,
          'day': _day(_clock.now()),
          'startedAt': (_startedAt ?? _clock.now()).millisecondsSinceEpoch,
          'cursor': _cursor,
          'answered': _answered,
          'correct': _correct,
          'skipped': _skipped,
          'wrongWords': _wrongWords.toList(),
          'lastSubmission': _lastSubmission,
          'questions': <Map<String, Object?>>[
            for (final PracticeQuestion question in _questions)
              question.toJson(),
          ],
        }),
      );
    } catch (_) {
      // Diagnostics only; the drill keeps working from memory.
    }
  });

  Future<void> _clearPersisted() => _enqueueWrite(() async {
    try {
      await _study.db.deleteMeta(persistenceKey);
    } catch (_) {
      // Same reasoning as _persist.
    }
  });

  /// Completes once every queued local write has landed.
  ///
  /// The UI does not block on disk writes, so anything that must observe the
  /// final state (tests, or a page about to pop) awaits this instead.
  Future<void> flush() => _writeChain;

  /// Restores a persisted attempt when it still describes this drill.
  ///
  /// Every question is re-validated against the current rows: a word that was
  /// deleted, removed from the book or edited is dropped, and the cursor is
  /// remapped so the user continues at the same *word*, not at the same index.
  Future<bool> _restore({required int limit}) async {
    final String? raw = await _study.db.readMeta(persistenceKey);
    if (raw == null) return false;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      await _clearPersisted();
      return false;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['kind'] != _kind.code ||
        decoded['bookId'] != _bookId ||
        decoded['day'] != _day(_clock.now())) {
      return false;
    }
    final Object? rawQuestions = decoded['questions'];
    if (rawQuestions is! List || rawQuestions.isEmpty) {
      await _clearPersisted();
      return false;
    }
    if (rawQuestions.length > math.max(limit * 4, 80)) {
      // A guard against a corrupted or hand-edited blob.
      await _clearPersisted();
      return false;
    }
    final List<PracticeQuestion> restored = <PracticeQuestion>[];
    final int oldCursor = (decoded['cursor'] as int?) ?? 0;
    int newCursor = 0;
    for (int i = 0; i < rawQuestions.length; i++) {
      final Object? entry = rawQuestions[i];
      if (entry is! Map) continue;
      final Object? wordId = entry['wordId'];
      if (wordId is! String) continue;
      final ManagedWord? row = await _study.managedWord(wordId);
      if (row == null) continue;
      if (contentSignatureOf(row.word) != (entry['signature'] ?? '')) {
        continue;
      }
      if (_bookId != null) {
        final link =
            await (_study.db.select(_study.db.wordBookEntries)..where(
                  (t) =>
                      t.wordId.equals(wordId) &
                      t.wordBookId.equals(_bookId!) &
                      t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (link == null) continue;
      }
      final PracticeQuestion? question = PracticeQuestion.fromJson(
        Map<String, Object?>.from(entry),
        row.word,
        _kind,
      );
      if (question == null) continue;
      if (i < oldCursor) newCursor++;
      restored.add(question);
    }
    if (restored.isEmpty) {
      await _clearPersisted();
      return false;
    }
    _questions
      ..clear()
      ..addAll(restored);
    _cursor = newCursor.clamp(0, _questions.length);
    _answered = (decoded['answered'] as int?) ?? 0;
    _correct = (decoded['correct'] as int?) ?? 0;
    _skipped = (decoded['skipped'] as int?) ?? 0;
    _wrongWords
      ..clear()
      ..addAll(
        (decoded['wrongWords'] as List? ?? const <Object>[])
            .whereType<String>(),
      );
    final Object? startedAt = decoded['startedAt'];
    _startedAt = startedAt is int
        ? DateTime.fromMillisecondsSinceEpoch(startedAt, isUtc: true)
        : _clock.now();
    final Object? last = decoded['lastSubmission'];
    _lastSubmission = last is Map ? Map<String, Object?>.from(last) : null;
    // A restored attempt always resumes on an unanswered question: feedback is
    // transient UI state and re-showing it after a restart would strand the
    // drill on a question the user already dealt with.
    _outcome = null;
    _revealed = false;
    return true;
  }
}
