import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/models/enums.dart';
import '../core/models/study_models.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/study_repository.dart';
import '../core/time_utils.dart';

const Uuid _uuid = Uuid();

/// One generated drill question.
class PracticeQuestion {
  const PracticeQuestion({
    required this.word,
    required this.kind,
    required this.prompt,
    required this.answer,
    this.options = const <String>[],
    this.correctIndex,
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

  /// True when the exercise could not be built from real data (no example
  /// sentence, too few distinct distractors). Such a word is skipped instead of
  /// being turned into a fabricated or ambiguous question.
  bool get isSkipped => kind == PracticeKind.choice && options.length < 2;
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
class PracticeSession extends ChangeNotifier {
  PracticeSession(this._study, this._settings, this._clock);

  final StudyRepository _study;
  final SettingsRepository _settings;
  final Clock _clock;

  static const int defaultLimit = 20;

  final List<PracticeQuestion> _questions = <PracticeQuestion>[];
  int _cursor = 0;
  bool _loading = false;
  bool _busy = false;
  bool _revealed = false;
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
  final Set<String> _answeredWordIds = <String>{};
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
  bool get isLoading => _loading;
  bool get isBusy => _busy;
  bool get isRevealed => _revealed;
  String? get error => _error;
  bool get isEmpty => !_loading && _questions.isEmpty;
  bool get isFinished =>
      !_loading && _questions.isNotEmpty && _cursor >= _questions.length;
  bool get canUndo => _lastSubmission != null && !_busy;
  PracticeQuestion? get current =>
      _cursor < _questions.length ? _questions[_cursor] : null;
  int get position => math.min(_cursor, _questions.length);
  int get total => _questions.length;
  int get correctCount => _correct;
  int get answeredCount => _answered;

  double? get accuracy => _answered == 0 ? null : _correct / _answered;

  /// Loads a fresh drill. [limit] caps the number of words asked about.
  Future<void> load({
    required PracticeKind kind,
    String? bookId,
    int limit = defaultLimit,
  }) async {
    _loading = true;
    _error = null;
    _kind = kind;
    _bookId = bookId;
    notifyListeners();
    try {
      _deviceId ??= await _settings.deviceId();
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
      _answeredWordIds.clear();
      _lastSubmission = null;
      _revealed = false;
      _startedAt = _clock.now();
    } catch (e) {
      _error = '练习加载失败：$e';
    } finally {
      _loading = false;
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
    switch (_kind) {
      case PracticeKind.spelling:
        return PracticeQuestion(
          word: word,
          kind: _kind,
          prompt: meaning,
          answer: answer,
        );
      case PracticeKind.dictation:
        return PracticeQuestion(
          word: word,
          kind: _kind,
          prompt: '',
          answer: answer,
        );
      case PracticeKind.cloze:
        final String? sentence = StudyRepository.clozeSentenceFor(word);
        if (sentence == null) return null;
        return PracticeQuestion(
          word: word,
          kind: _kind,
          prompt: _blankOut(sentence, answer),
          answer: answer,
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
        );
    }
  }

  /// Deterministic distractors: no duplicate spelling, no option whose Chinese
  /// meaning is the same as the answer's, and no near-identical option pair, so
  /// the question never has two defensible answers.
  List<String> _optionsFor(Word word, String meaning, List<Word> pool) {
    final String answer = word.word.trim();
    final String normalizedMeaning = _normalizeMeaning(meaning);
    final math.Random random = math.Random(
      word.id.codeUnits.fold<int>(7, (int a, int b) => a * 31 + b),
    );
    final List<Word> candidates =
        pool
            .where(
              (Word other) =>
                  _normalizeWord(other.word) != _normalizeWord(answer) &&
                  _normalizeMeaning(other.translation) != normalizedMeaning &&
                  other.translation.trim().isNotEmpty,
            )
            .toList()
          ..shuffle(random);
    final List<String> options = <String>[answer];
    final Set<String> seenMeanings = <String>{normalizedMeaning};
    for (final Word other in candidates) {
      if (options.length >= 4) break;
      final String candidateMeaning = _normalizeMeaning(other.translation);
      if (seenMeanings.contains(candidateMeaning)) continue;
      seenMeanings.add(candidateMeaning);
      options.add(other.word.trim());
    }
    options.shuffle(random);
    return options;
  }

  static String _normalizeMeaning(String value) {
    final String first = value
        .split(RegExp(r'[\n;；,，]'))
        .map((String part) => part.trim())
        .firstWhere((String part) => part.isNotEmpty, orElse: () => '');
    return first
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.。!！?？]'), '');
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
    if (_revealed || current == null) return;
    _revealed = true;
    notifyListeners();
  }

  /// Grades a typed answer (spelling / dictation / cloze).
  Future<PracticeOutcome?> submitTyped(String input) async {
    final PracticeQuestion? question = current;
    if (question == null || _busy || !question.kind.isTyped) return null;
    return _record(
      question,
      correct: matches(question.answer, input),
      input: input,
    );
  }

  /// Grades a multiple-choice answer.
  Future<PracticeOutcome?> submitChoice(int index) async {
    final PracticeQuestion? question = current;
    if (question == null || _busy) return null;
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
    if (!_answeredWordIds.add('${question.word.id}#$_cursor')) return null;
    _busy = true;
    final int cursorBefore = _cursor;
    final int correctBefore = _correct;
    final int answeredBefore = _answered;
    final Map<String, Object?>? previousUndo = _lastSubmission;
    final Set<String> wrongBefore = Set<String>.of(_wrongWords);
    notifyListeners();
    try {
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
        'cursor': cursorBefore,
        'correct': correctBefore,
        'answered': answeredBefore,
        'wrongWords': wrongBefore.toList(),
        'wordId': question.word.id,
      };
      _cursor++;
      _revealed = false;
      _error = null;
      return PracticeOutcome(
        correct: correct,
        answer: question.answer,
        submitted: input,
      );
    } catch (e) {
      _answeredWordIds.remove('${question.word.id}#$_cursor');
      _lastSubmission = previousUndo;
      _correct = correctBefore;
      _answered = answeredBefore;
      _wrongWords
        ..clear()
        ..addAll(wrongBefore);
      _error = '保存练习结果失败：$e';
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Reverts the last practice answer (writes a real undo event, so the other
  /// devices converge on the same state).
  Future<bool> undo() async {
    final Map<String, Object?>? previous = _lastSubmission;
    if (previous == null || _busy) return false;
    _busy = true;
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
      _wrongWords
        ..clear()
        ..addAll((previous['wrongWords'] as List).whereType<String>());
      _answeredWordIds.remove('${previous['wordId']}#$_cursor');
      _lastSubmission = null;
      _revealed = false;
      return true;
    } catch (_) {
      _error = '撤销失败，请重试';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Moves past a word without recording anything (no answer, no allowance).
  void skip() {
    if (current == null || _busy) return;
    _skipped++;
    _cursor++;
    _revealed = false;
    notifyListeners();
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
}
