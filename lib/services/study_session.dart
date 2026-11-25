import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/models/enums.dart';
import '../core/database/app_database.dart';
import '../core/errors/app_error.dart';
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
  final List<String> _eventIds = [];
  // Events are append-only. Counts detect same-millisecond, backward-clock and
  // concurrent equal-causal-order arrivals without relying on wall time.
  final Map<String, int> _observedEventCounts = {};
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
  DateTime? _finishedAt;
  Map<String, Object?>? _lastSubmission;
  String? _deviceId;
  AppErrorCode? _error;
  AppErrorCode? _notice;
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

  /// Stable code, localised by the page. Never a sentence: the session has no
  /// [BuildContext] and must not pick a language.
  AppErrorCode? get error => _error;

  AppErrorCode? get notice => _notice;
  SpecialReview get special => _special;
  String? get bookId => _bookId;

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
    List<String>? focusedWordIds,
    bool shuffle = false,
  }) async {
    _loading = true;
    _error = null;
    _notice = null;
    _special = special;
    _bookId = bookId;
    _mode = mode;
    notifyListeners();
    try {
      await _study.db.transaction(() async {
        _deviceId ??= await _settings.deviceId();
        _planVersion = jsonEncode(await _settings.sharedVersion());
        if (await _restore()) return;
        _startedAt = _clock.now();
        final StudyQueue queue = focusedWordIds != null
            ? await _focusedQueue(focusedWordIds)
            : await _study.buildQueue(
                now: _clock.now(),
                newLimit: newLimit,
                reviewLimit: reviewLimit,
                bookId: bookId,
                mode: special == SpecialReview.none ? mode : StudyMode.special,
                special: special,
              );
        final List<StudyCard> cards = List<StudyCard>.of(queue.cards);
        if (shuffle && cards.length > 1) {
          // Random order only changes the order: the queue still contains every
          // card exactly once, and the persisted session stores the shuffled
          // order so a resume continues where the user stopped.
          cards.shuffle(Random());
        }
        _queue
          ..clear()
          ..addAll(cards);
        _observedEventCounts
          ..clear()
          ..addAll(await _eventCounts(_queue.map((c) => c.word.id)));
        _cursor = 0;
        _lastSubmission = null;
        _revealed = false;
        _newAnswered = 0;
        _reviewAnswered = 0;
        _repeatCards = 0;
        _answeredCardIds.clear();
        _eventIds.clear();
        _finishedAt = null;
        _newAvailable = queue.newAvailable;
        _newQueued = queue.newQueued;
        _reviewAvailable = queue.reviewAvailable;
        _backlog = queue.backlog;
        await _persist();
      });
    } catch (e) {
      _error = AppErrorCode.loadFailed;
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
      final beforeEvents = List<String>.of(_eventIds);
      final beforeFinished = _finishedAt;
      final beforeCounts = Map<String, int>.of(_observedEventCounts);
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
            if (_queue.isNotEmpty && _cursor >= _queue.length) {
              _finishedAt = now;
            }
            _lastSubmission = null;
            _revealed = false;
            await _persist();
            _error = AppErrorCode.wordRemoved;
            return null;
          }
          final count = (await _eventCounts([card.word.id]))[card.word.id] ?? 0;
          if (count != (_observedEventCounts[card.word.id] ?? 0)) {
            _answeredCardIds.remove(cardId);
            final pending = _queue.sublist(_cursor)
              ..removeWhere((c) => c.word.id == card.word.id);
            _queue.replaceRange(_cursor, _queue.length, pending);
            if (_queue.isNotEmpty && _cursor >= _queue.length) {
              _finishedAt = now;
            }
            _lastSubmission = null;
            _revealed = false;
            await _persist();
            _notice = AppErrorCode.stateChanged;
            return null;
          }
          if (word.word != card.word) {
            _answeredCardIds.remove(cardId);
            _replaceWord(word);
            _revealed = false;
            await _persist();
            _notice = AppErrorCode.contentUpdated;
            return null;
          }
          if (_special == SpecialReview.sprint) {
            final plan = await _settings.loadSprintPlan();
            final settings = await _settings.load();
            final invalid =
                !plan.enabled ||
                plan.bookId != _bookId ||
                (plan.daysUntil(now) ?? -1) < 0 ||
                jsonEncode(await _settings.sharedVersion()) != _planVersion;
            final exhausted =
                !plan.allowOverReviewLimit &&
                await _study.todayCount(now: now, type: ReviewType.review) >=
                    settings.dailyReviewLimit;
            if (invalid || exhausted) {
              _answeredCardIds.remove(cardId);
              _error = invalid
                  ? AppErrorCode.sprintChanged
                  : AppErrorCode.reviewLimitReached;
              return null;
            }
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

          _observedEventCounts[card.word.id] = count + 1;
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
          _eventIds.add(record.eventId);
          if (_cursor >= _queue.length) _finishedAt = now;
          _revealed = false;
          _error = null;
          _notice = null;
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
        _eventIds
          ..clear()
          ..addAll(beforeEvents);
        _finishedAt = beforeFinished;
        _observedEventCounts
          ..clear()
          ..addAll(beforeCounts);
        _revealed = true;
        rethrow;
      }
    } catch (e) {
      _answeredCardIds.remove(cardId);
      _error = AppErrorCode.saveFailed;
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, int>> _eventCounts(Iterable<String> wordIds) async {
    final ids = wordIds.toSet().toList();
    final counts = <String, int>{for (final id in ids) id: 0};
    for (var start = 0; start < ids.length; start += 400) {
      final chunk = ids.sublist(start, (start + 400).clamp(0, ids.length));
      final rows = await _study.db
          .customSelect(
            'SELECT word_id, COUNT(*) AS total FROM review_events '
            'WHERE word_id IN (${List.filled(chunk.length, '?').join(',')}) '
            'GROUP BY word_id',
            variables: chunk.map((id) => Variable<String>(id)).toList(),
          )
          .get();
      for (final row in rows) {
        counts[row.read<String>('word_id')] = row.read<int>('total');
      }
    }
    return counts;
  }

  void _replaceWord(ManagedWord row) {
    for (var i = _cursor; i < _queue.length; i++) {
      final card = _queue[i];
      if (card.word.id != row.word.id) continue;
      _queue[i] = StudyCard(
        word: row.word,
        withState: WordWithState(
          word: row.word,
          state: row.state,
          bookCount: row.bookCount,
          lastAnsweredAt: row.lastStudiedAt,
        ),
        type: card.type,
        repeatCount: card.repeatCount,
      );
    }
  }

  String _day(DateTime date) =>
      '${date.toLocal().year}-${date.toLocal().month}-${date.toLocal().day}';

  Future<StudyQueue> _focusedQueue(List<String> ids) async {
    final cards = <StudyCard>[];
    if (_bookId != null) {
      final book = await (_study.db.select(
        _study.db.wordBooks,
      )..where((t) => t.id.equals(_bookId!))).getSingleOrNull();
      if (book == null || book.deletedAt != null) {
        return const StudyQueue(
          cards: [],
          newAvailable: 0,
          reviewAvailable: 0,
          backlog: 0,
        );
      }
    }
    for (final id in ids.toSet()) {
      final row = await _study.managedWord(id);
      if (row == null) continue;
      if (_bookId != null) {
        final link =
            await (_study.db.select(_study.db.wordBookEntries)..where(
                  (t) =>
                      t.wordId.equals(id) &
                      t.wordBookId.equals(_bookId!) &
                      t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (link == null) continue;
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
          type: ReviewType.review,
        ),
      );
    }
    return StudyQueue(
      cards: cards,
      newAvailable: 0,
      reviewAvailable: cards.length,
      backlog: 0,
      mode: StudyMode.special,
    );
  }

  /// Query only this round's event IDs, keeping unrelated answers out of totals.
  Future<StudyRoundSummary> summary() => _study.db.transaction(() async {
    final ids = _eventIds.toSet().toList(), events = <ReviewEvent>[];
    final undone = <String>{};
    for (var start = 0; start < ids.length; start += 400) {
      final chunk = ids.sublist(start, (start + 400).clamp(0, ids.length));
      events.addAll(
        await (_study.db.select(
          _study.db.reviewEvents,
        )..where((t) => t.id.isIn(chunk))).get(),
      );
      final undo = await (_study.db.select(
        _study.db.reviewEvents,
      )..where((t) => t.mode.isIn(chunk.map((id) => 'undo:$id')))).get();
      undone.addAll(
        undo.map((e) => e.mode.substring(ReviewEventMode.undoPrefix.length)),
      );
    }
    final newIds = <String>{},
        reviewIds = <String>{},
        allIds = <String>{},
        difficultIds = <String>{};
    int known = 0, hazy = 0, unknown = 0, repeats = 0;
    for (final event in events) {
      if (undone.contains(event.id) ||
          ReviewEventMode.isManagement(event.mode)) {
        continue;
      }
      allIds.add(event.wordId);
      (event.type == ReviewType.study.code ||
                  (event.mode == ReviewEventMode.specialSprint &&
                      event.stageBefore == StudyStage.newWord.code)
              ? newIds
              : reviewIds)
          .add(event.wordId);
      switch (AnswerResult.fromCode(event.result)) {
        case AnswerResult.known:
          known++;
        case AnswerResult.hazy:
          hazy++;
          difficultIds.add(event.wordId);
        case AnswerResult.unknown:
          unknown++;
          difficultIds.add(event.wordId);
      }
      if (event.mode == ReviewEventMode.repeat) repeats++;
    }
    final difficult = <RoundDifficultWord>[];
    for (final id in difficultIds) {
      final word = await (_study.db.select(
        _study.db.words,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      difficult.add(
        RoundDifficultWord(
          id: id,
          // Placeholder only: a card whose word disappeared is skipped before it
          // can be shown, so this text is never read by the user.
          word: word?.word ?? '—',
          available: word != null && word.deletedAt == null,
        ),
      );
    }
    difficult.sort((a, b) => a.word.compareTo(b.word));
    final elapsed = (_finishedAt ?? _clock.now()).difference(
      _startedAt ?? _clock.now(),
    );
    return StudyRoundSummary(
      newWords: newIds.length,
      reviewWords: reviewIds.length,
      uniqueWords: allIds.length,
      known: known,
      hazy: hazy,
      unknown: unknown,
      repeatAttempts: repeats,
      elapsed: elapsed.isNegative ? Duration.zero : elapsed,
      difficultWords: List.unmodifiable(difficult),
    );
  });

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
        'eventIds': _eventIds,
        'observedEventCounts': _observedEventCounts,
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
    final currentCounts = await _eventCounts(
      entries.map((e) => (e as Map)['wordId'] as String),
    );
    final observedCounts = data['observedEventCounts'] as Map?;
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
      final changedEvents = observedCounts != null
          ? currentCounts[row.word.id] != observedCounts[row.word.id]
          : repeats == 0 &&
                row.lastStudiedAt != null &&
                row.lastStudiedAt!.millisecondsSinceEpoch >
                    ((entry['observedAnswerAt'] as int?) ?? 0);
      if (i >= oldCursor && changedEvents) {
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
    _observedEventCounts
      ..clear()
      ..addAll(currentCounts);
    _revealed = false;
    _startedAt = DateTime.fromMillisecondsSinceEpoch(data['startedAt'] as int);
    _eventIds
      ..clear()
      ..addAll((data['eventIds'] as List?)?.whereType<String>() ?? const []);
    _finishedAt = null;
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
    final events = List<String>.of(_eventIds);
    final finishedAt = _finishedAt;
    final observedCounts = Map<String, int>.of(_observedEventCounts);
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
        _observedEventCounts.addAll(
          await _eventCounts([_queue[_cursor].word.id]),
        );
        _queue.length = previous['queueLength'] as int;
        _newAnswered = previous['newAnswered'] as int;
        _reviewAnswered = previous['reviewAnswered'] as int;
        _repeatCards = previous['repeatCards'] as int;
        _answeredCardIds.remove(previous['cardId']);
        _lastSubmission = null;
        _eventIds.remove(previous['eventId']);
        _finishedAt = null;
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
      _eventIds
        ..clear()
        ..addAll(events);
      _finishedAt = finishedAt;
      _observedEventCounts
        ..clear()
        ..addAll(observedCounts);
      _revealed = revealed;
      _error = AppErrorCode.undoFailed;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Refresh edited content without rebuilding the queue or recording answers.
  Future<void> refreshCurrent() async {
    if (_busy || current == null) return;
    final id = current!.word.id;
    final row = await _study.managedWord(id);
    if (_busy || current?.word.id != id) return;
    if (row == null) {
      await skip();
      return;
    }
    _replaceWord(row);
    _revealed = false;
    notifyListeners();
  }

  /// A skip creates no answer and consumes no daily allowance.
  Future<bool> skip() async {
    if (_busy || current == null) return false;
    final card = current!;
    final previous = _lastSubmission;
    final revealed = _revealed;
    final finishedAt = _finishedAt;
    _busy = true;
    notifyListeners();
    try {
      _queue.removeAt(_cursor);
      if (_queue.isNotEmpty && _cursor >= _queue.length) {
        _finishedAt = _clock.now();
      }
      _lastSubmission = null;
      _revealed = false;
      await _persist();
      return true;
    } catch (_) {
      _queue.insert(_cursor, card);
      _lastSubmission = previous;
      _finishedAt = finishedAt;
      _revealed = revealed;
      _error = AppErrorCode.skipFailed;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  bool get isBusy => _busy;
}
