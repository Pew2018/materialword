import 'dart:async';
import 'dart:convert';

import '../../core/database/app_database.dart';
import '../../core/repositories/settings_repository.dart';
import 'sync_coordinator.dart';

/// Debounce local edits while the app is alive and in the foreground.
/// No OS background scheduling, and no network work is awaited by a screen.
class AutoSyncService {
  AutoSyncService({required this.db, required this.coordinator});
  final AppDatabase db;
  final SyncCoordinator coordinator;
  static const debounce = Duration(seconds: 20);
  StreamSubscription<dynamic>? _data;
  StreamSubscription<dynamic>? _plan;
  Timer? _timer;
  bool _foreground = true,
      _started = false,
      _disposed = false,
      _working = false;
  bool _sessionEndPending = false;
  String? _planFingerprint;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _data = db.tableUpdates().listen((updates) {
      if (updates.any(
        (u) => const {
          'words',
          'word_books',
          'word_book_entries',
          'review_events',
          'word_favorites',
          'user_tags',
          'word_tags',
          'content_versions',
        }.contains(u.table),
      )) {
        if (!_sessionEndPending) _schedule(debounce);
      }
    });
    _plan =
        (db.select(db.appMeta)..where(
              (t) => t.key.isIn([
                SettingsRepository.sharedVersionKey,
                SettingsRepository.syncConfigKey,
              ]),
            ))
            .watch()
            .listen((rows) {
              final values = {for (final row in rows) row.key: row.value};
              final keys = values.keys.toList()..sort();
              final fingerprint = jsonEncode({
                for (final key in keys) key: values[key],
              });
              if (_planFingerprint == fingerprint) return;
              _planFingerprint = fingerprint;
              if (!_sessionEndPending) _schedule(debounce);
            });
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _timer?.cancel();
    } else {
      _schedule(debounce);
    }
  }

  void requestSessionEnd() {
    if (_disposed) return;
    start();
    _sessionEndPending = true;
    _schedule(Duration.zero);
  }

  void _schedule(Duration delay) {
    if (_disposed || !_foreground) return;
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  Future<void> _run() async {
    if (_disposed || !_foreground) return;
    if (_working) {
      _schedule(const Duration(seconds: 5));
      return;
    }
    _working = true;
    final trigger = _sessionEndPending ? 'session-end' : 'change';
    try {
      await coordinator.autoSync(trigger: trigger);
      if (_disposed || !_foreground) return;
      final delay = await coordinator.autoRetryDelay(trigger: trigger);
      if (delay == null) {
        _sessionEndPending = false;
        // Session-end may be disabled while data-change sync is enabled.
        if (trigger == 'session-end') _schedule(debounce);
        return;
      }
      if (!await coordinator.hasLocalChanges()) {
        _sessionEndPending = false;
        return;
      }
      // An edit during upload or a cooldown must stay pending until eligible.
      _schedule(
        delay > const Duration(seconds: 5) ? delay : const Duration(seconds: 5),
      );
    } catch (_) {
      // Manual sync remains available; no busy-loop on malformed configuration.
    } finally {
      _working = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _data?.cancel();
    _plan?.cancel();
  }
}
