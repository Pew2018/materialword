import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/models/enums.dart';
import '../core/models/study_models.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/study_repository.dart';
import '../core/repositories/word_repository.dart';
import '../core/time_utils.dart';
import 'study_scheduler.dart';

const Uuid _uuid = Uuid();

class PausedStudySession {
  const PausedStudySession({
    required this.bookId,
    required this.mode,
    required this.special,
    required this.position,
    required this.total,
  });
  final String? bookId;
  final StudyMode mode;
  final SpecialReview special;
  final int position, total;
}

/// Drives one study or review session.
///
/// Deliberately a plain [ChangeNotifier] (no widgets, no Riverpod) so the whole
/// learning loop can be unit tested against an in-memory database.
class StudySession extends ChangeNotifier {
  StudySession(this._study, this._settings, this._clock);

  final StudyRepository _study;
  final SettingsRepository _settings;
  final Clock _clock;

  final List<StudyCard> _queue = <StudyCard>[];
  final Set<String> _answeredCardIds = <String>{};
  int _cursor = 0;
  bool _revealed = false;
  bool _busy = false;
  bool _loading = false;
  static const String persistenceKey = 'active_study_session_v1';
  bool _disposed = false;
  String? _bookId;
  StudyMode _mode = StudyMode.mixed;
  String _planVersion = '';
  DateTime? _startedAt;
  Map<String, Object?>? _lastSubmission;
  String? _deviceId;
  String? _error;
  SpecialReview _special = SpecialReview.none;

  int _newAnswered = 0;
  int _reviewAnswered = 0;
  int _repeatCards = 0;
  int _newAvailable = 0;
  int _newQueued = 0;
  int _reviewAvailable = 0;
  int _backlog = 0;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get canUndo => _lastSubmission != null && !_busy;
  bool get isLoading => _loading;
  bool get isRevealed => _revealed;
  bool get isFinished =>
      !_loading && _queue.isNotEmpty && _cursor >= _queue.length;
  bool get isEmpty => !_loading && _queue.isEmpty;
  String? get error => _error;
  SpecialReview get special => _special;

  StudyCard? get current => _cursor < _queue.length ? _queue[_cursor] : null;

  int get totalCards => _queue.length;
  int get position => _cursor >= _queue.length ? _queue.length : _cursor;
  int get newAnswered => _newAnswered;
  int get reviewAnswered => _reviewAnswered;
  int get repeatCards => _repeatCards;
  int get newAvailable => _newAvailable;
  int get newQueued => _newQueued;
  int get reviewAvailable => _reviewAvailable;
  int get backlog => _backlog;

  double get progress =>
      _queue.isEmpty ? 0 : (_cursor / _queue.length).clamp(0, 1);

  /// Builds the queue from the database. Safe to call again after a hot restart:
  /// everything the user already answered is persisted, so the new queue simply
  /// contains what is left.
  ///
  /// [newLimit] / [reviewLimit] are the *remaining* daily allowance. For a
  /// special review the queue is built from its own filter but still counted
  /// against the review allowance, so it cannot permanently starve the normal
  /// due queue.
  Future<void> load({
    required int newLimit,
    required int reviewLimit,
    String? bookId,
    StudyMode mode = StudyMode.mixed,
    SpecialReview special = SpecialReview.none,
  }) async {
    _loading = true;
    _error = null;
    _special = special;
    _bookId = bookId;
    _mode = mode;
    notifyListeners();
    try {
      _deviceId ??= await _settings.deviceId();
      _planVersion = jsonEncode(await _settings.sharedVersion());
      if (await _restore()) return;
      _startedAt = _clock.now();
      final StudyQueue queue = await _study.buildQueue(
        now: _clock.now(),
        newLimit: newLimit,
        reviewLimit: reviewLimit,
        bookId: bookId,
        mode: special == SpecialReview.none ? mode : StudyMode.special,
        special: special,
      );
      _queue
        ..clear()
        ..addAll(queue.cards);
      _cursor = 0;
      _lastSubmission = null;
      _revealed = false;
      _newAnswered = 0;
      _reviewAnswered = 0;
      _repeatCards = 0;
      _answeredCardIds.clear();
      _newAvailable = queue.newAvailable;
      _newQueued = queue.newQueued;
      _reviewAvailable = queue.reviewAvailable;
      _backlog = queue.backlog;
      await _persist();
    } catch (e) {
      _error = '加载失败：$e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Shows the meaning of the current card. Answers are only accepted after the
  /// meaning has been revealed, which also makes accidental double taps on the
  /// answer buttons harmless.
  void reveal() {
    if (_revealed || current == null || _busy) return;
    _revealed = true;
    notifyListeners();
  }

  /// Records the answer for the current card. Returns null when the call was
  /// ignored (not revealed yet, still saving, session finished) or failed.
  Future<AnswerRecord?> submit(AnswerResult result) async {
    final StudyCard? card = current;
    if (card == null || !_revealed || _busy) return null;

    final String cardId = '${card.word.id}#$_cursor';
    if (_answeredCardIds.contains(cardId)) return null;

    _busy = true;
    _answeredCardIds.add(cardId);
    notifyListeners();

    try {
      final DateTime now = _clock.now();
      final beforeQueue = List<StudyCard>.of(_queue);
      final beforeCursor = _cursor;
      final beforeNew = _newAnswered;
      final beforeReview = _reviewAnswered;
      final beforeRepeats = _repeatCards;
      final previousUndo = _lastSubmission;
      try {
        return await _study.db.transaction(() async {
          final word = await _study.managedWord(card.word.id);
          final link = _bookId == null
              ? true
              : await (_study.db.select(_study.db.wordBookEntries)..where(
                          (t) =>
                              t.wordId.equals(card.word.id) &
                              t.wordBookId.equals(_bookId!) &
                              t.deletedAt.isNull(),
                        ))
                        .getSingleOrNull() !=
                    null;
          final book = _bookId == null
              ? null
              : await (_study.db.select(
                  _study.db.wordBooks,
                )..where((t) => t.id.equals(_bookId!))).getSingleOrNull();
          final favoriteEligible =
              _special != SpecialReview.favorites ||
              (await (_study.db.select(_study.db.wordFavorites)..where(
                        (t) =>
                            t.wordId.equals(card.word.id) &
                            t.value.equals(true),
                      ))
                      .getSingleOrNull()) !=
                  null;
          if (word == null ||
              !favoriteEligible ||
              !link ||
              (_bookId != null && (book == null || book.deletedAt != null))) {
            _answeredCardIds.remove(cardId);
            _queue.removeAt(_cursor);
            _lastSubmission = null;
            _revealed = false;
            await _persist();
            _error = '当前单词已移除，已跳过';
            return null;
          }
          final AnswerRecord record = await _study.recordAnswer(
            wordId: card.word.id,
            result: result,
            type: card.type,
            eventId: _uuid.v4(),
            deviceId: _deviceId ?? 'unknown-device',
            now: now,
            mode: card.repeatCount > 0
                ? ReviewEventMode.repeat
                : ReviewEventMode.forSpecial(_special),
          );

          if (card.repeatCount == 0) {
            if (card.type == ReviewType.study) {
              _newAnswered++;
            } else {
              _reviewAnswered++;
            }
          }

          // Special queues do not re-queue a failed card inside the session: the
          // user explicitly asked for a focused pass, and repeating it endlessly
          // would make the "N words" counter meaningless.
          if (record.repeatInSession &&
              _special == SpecialReview.none &&
              card.repeatCount < StudyScheduler.maxSessionRepeats) {
            _queue.add(card.copyWith(repeatCount: card.repeatCount + 1));
            _repeatCards++;
          }

          _lastSubmission = {
            'eventId': record.eventId,
            'cursor': beforeCursor,
            'queueLength': beforeQueue.length,
            'newAnswered': beforeNew,
            'reviewAnswered': beforeReview,
            'repeatCards': beforeRepeats,
            'cardId': cardId,
          };
          _cursor++;
          _revealed = false;
          _error = null;
          await _persist();
          return record;
        });
      } catch (_) {
        _queue
          ..clear()
          ..addAll(beforeQueue);
        _cursor = beforeCursor;
        _newAnswered = beforeNew;
        _reviewAnswered = beforeReview;
        _repeatCards = beforeRepeats;
        _lastSubmission = previousUndo;
        _revealed = true;
        rethrow;
      }
    } catch (e) {
      _answeredCardIds.remove(cardId);
      _error = '保存失败：$e';
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _day(DateTime date) =>
      '${date.toLocal().year}-${date.toLocal().month}-${date.toLocal().day}';

  Future<void> _persist() async {
    if (_queue.isEmpty || _cursor >= _queue.length) {
      await _study.db.deleteMeta(persistenceKey);
      return;
    }
    await _study.db.writeMeta(
      persistenceKey,
      jsonEncode({
        'version': 1,
        'planVersion': _planVersion,
        'day': _day(_clock.now()),
        'bookId': _bookId,
        'mode': _mode.code,
        'special': _special.code,
        'startedAt': (_startedAt ?? _clock.now()).millisecondsSinceEpoch,
        'cursor': _cursor,
        'newAnswered': _newAnswered,
        'reviewAnswered': _reviewAnswered,
        'repeatCards': _repeatCards,
        'newAvailable': _newAvailable,
        'newQueued': _newQueued,
        'reviewAvailable': _reviewAvailable,
        'backlog': _backlog,
        'lastSubmission': _lastSubmission,
        'queue': _queue
            .map(
              (card) => {
                'wordId': card.word.id,
                'type': card.type.code,
                'repeatCount': card.repeatCount,
                'observedAnswerAt':
                    card.withState.lastAnsweredAt?.millisecondsSinceEpoch,
              },
            )
            .toList(),
      }),
    );
  }

  Future<bool> _restore() async {
    final raw = await _study.db.readMeta(persistenceKey);
    if (raw == null) return false;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      await _study.db.deleteMeta(persistenceKey);
      return false;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['day'] != _day(_clock.now()) ||
        decoded['planVersion'] != _planVersion ||
        decoded['bookId'] != _bookId ||
        decoded['mode'] != _mode.code ||
        decoded['special'] != _special.code) {
      return false;
    }
    final data = decoded;
    if (_bookId != null) {
      final book = await (_study.db.select(
        _study.db.wordBooks,
      )..where((t) => t.id.equals(_bookId!))).getSingleOrNull();
      if (book == null || book.deletedAt != null) return false;
    }
    final cards = <StudyCard>[];
    int cursor = 0;
    bool changed = false;
    final oldCursor = data['cursor'] as int;
    final entries = data['queue'] as List;
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i] as Map;
      final row = await _study.managedWord(entry['wordId'] as String);
      if (row == null) {
        changed = true;
        continue;
      }
      if (_special == SpecialReview.favorites) {
        final favorite =
            await (_study.db.select(_study.db.wordFavorites)..where(
                  (t) => t.wordId.equals(row.word.id) & t.value.equals(true),
                ))
                .getSingleOrNull();
        if (favorite == null) {
          changed = true;
          continue;
        }
      }
      if (_bookId != null) {
        final link =
            await (_study.db.select(_study.db.wordBookEntries)..where(
                  (t) =>
                      t.wordId.equals(row.word.id) &
                      t.wordBookId.equals(_bookId!) &
                      t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (link == null) {
          changed = true;
          continue;
        }
      }
      final repeats = entry['repeatCount'] as int;
      if (i >= oldCursor &&
          repeats == 0 &&
          row.lastStudiedAt != null &&
          row.lastStudiedAt!.millisecondsSinceEpoch >
              ((entry['observedAnswerAt'] as int?) ?? 0)) {
        changed = true;
        continue;
      }
      cards.add(
        StudyCard(
          word: row.word,
          withState: WordWithState(
            word: row.word,
            state: row.state,
            bookCount: row.bookCount,
            lastAnsweredAt: row.lastStudiedAt,
          ),
          type: ReviewType.fromCode(entry['type'] as String),
          repeatCount: repeats,
        ),
      );
      if (i < oldCursor) cursor++;
    }
    if (cards.isEmpty || cursor >= cards.length) return false;
    _queue
      ..clear()
      ..addAll(cards);
    _cursor = cursor;
    _revealed = false;
    _startedAt = DateTime.fromMillisecondsSinceEpoch(data['startedAt'] as int);
    _newAnswered = data['newAnswered'] as int;
    _reviewAnswered = data['reviewAnswered'] as int;
    _repeatCards = data['repeatCards'] as int;
    _newAvailable = data['newAvailable'] as int;
    _newQueued = data['newQueued'] as int;
    _reviewAvailable = data['reviewAvailable'] as int;
    _backlog = data['backlog'] as int;
    _lastSubmission = !changed && data['lastSubmission'] is Map
        ? Map<String, Object?>.from(data['lastSubmission'] as Map)
        : null;
    _answeredCardIds.clear();
    await _persist();
    return true;
  }

  Future<bool> undo() async {
    final previous = _lastSubmission;
    if (previous == null || _busy) return false;
    final queue = List<StudyCard>.of(_queue);
    final cursor = _cursor,
        newAnswered = _newAnswered,
        reviewAnswered = _reviewAnswered,
        repeats = _repeatCards;
    final answered = Set<String>.of(_answeredCardIds);
    final revealed = _revealed;
    _busy = true;
    notifyListeners();
    try {
      await _study.db.transaction(() async {
        await _study.undoAnswer(
          eventId: previous['eventId'] as String,
          undoId: _uuid.v4(),
          deviceId: _deviceId!,
          now: _clock.now(),
        );
        _cursor = previous['cursor'] as int;
        _queue.length = previous['queueLength'] as int;
        _newAnswered = previous['newAnswered'] as int;
        _reviewAnswered = previous['reviewAnswered'] as int;
        _repeatCards = previous['repeatCards'] as int;
        _answeredCardIds.remove(previous['cardId']);
        _lastSubmission = null;
        _revealed = false;
        await _persist();
      });
      return true;
    } catch (_) {
      _queue
        ..clear()
        ..addAll(queue);
      _cursor = cursor;
      _newAnswered = newAnswered;
      _reviewAnswered = reviewAnswered;
      _repeatCards = repeats;
      _answeredCardIds
        ..clear()
        ..addAll(answered);
      _lastSubmission = previous;
      _revealed = revealed;
      _error = '撤销失败，请重试';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// A skip creates no answer and consumes no daily allowance.
  Future<bool> skip() async {
    if (_busy || current == null) return false;
    final card = current!;
    final previous = _lastSubmission;
    final revealed = _revealed;
    _busy = true;
    notifyListeners();
    try {
      _queue.removeAt(_cursor);
      _lastSubmission = null;
      _revealed = false;
      await _persist();
      return true;
    } catch (_) {
      _queue.insert(_cursor, card);
      _lastSubmission = previous;
      _revealed = revealed;
      _error = '跳过失败，请重试';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  bool get isBusy => _busy;
}
