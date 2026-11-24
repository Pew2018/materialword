import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/models/enums.dart';
import '../core/models/study_models.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/study_repository.dart';
import '../core/time_utils.dart';
import 'study_scheduler.dart';

const Uuid _uuid = Uuid();

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
  String? _deviceId;
  String? _error;

  int _newAnswered = 0;
  int _reviewAnswered = 0;
  int _repeatCards = 0;
  int _newAvailable = 0;
  int _reviewAvailable = 0;
  int _backlog = 0;

  bool get isLoading => _loading;
  bool get isRevealed => _revealed;
  bool get isFinished =>
      !_loading && _queue.isNotEmpty && _cursor >= _queue.length;
  bool get isEmpty => !_loading && _queue.isEmpty;
  String? get error => _error;

  StudyCard? get current => _cursor < _queue.length ? _queue[_cursor] : null;

  int get totalCards => _queue.length;
  int get position => _cursor >= _queue.length ? _queue.length : _cursor;
  int get newAnswered => _newAnswered;
  int get reviewAnswered => _reviewAnswered;
  int get repeatCards => _repeatCards;
  int get newAvailable => _newAvailable;
  int get reviewAvailable => _reviewAvailable;
  int get backlog => _backlog;

  double get progress =>
      _queue.isEmpty ? 0 : (_cursor / _queue.length).clamp(0, 1);

  /// Builds the queue from the database. Safe to call again after a hot restart:
  /// everything the user already answered is persisted, so the new queue simply
  /// contains what is left.
  Future<void> load({
    required int newLimit,
    required int reviewLimit,
    String? bookId,
    StudyMode mode = StudyMode.mixed,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _deviceId ??= await _settings.deviceId();
      final StudyQueue queue = await _study.buildQueue(
        now: _clock.now(),
        newLimit: newLimit,
        reviewLimit: reviewLimit,
        bookId: bookId,
        mode: mode,
      );
      _queue
        ..clear()
        ..addAll(queue.cards);
      _cursor = 0;
      _revealed = false;
      _newAnswered = 0;
      _reviewAnswered = 0;
      _repeatCards = 0;
      _answeredCardIds.clear();
      _newAvailable = queue.newAvailable;
      _reviewAvailable = queue.reviewAvailable;
      _backlog = queue.backlog;
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
      final AnswerRecord record = await _study.recordAnswer(
        wordId: card.word.id,
        result: result,
        type: card.type,
        eventId: _uuid.v4(),
        deviceId: _deviceId ?? 'unknown-device',
        now: now,
      );

      if (card.type == ReviewType.study) {
        _newAnswered++;
      } else {
        _reviewAnswered++;
      }

      if (record.repeatInSession &&
          card.repeatCount < StudyScheduler.maxSessionRepeats) {
        _queue.add(card.copyWith(repeatCount: card.repeatCount + 1));
        _repeatCards++;
      }

      _cursor++;
      _revealed = false;
      _error = null;
      return record;
    } catch (e) {
      _answeredCardIds.remove(cardId);
      _error = '保存失败：$e';
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  bool get isBusy => _busy;
}
