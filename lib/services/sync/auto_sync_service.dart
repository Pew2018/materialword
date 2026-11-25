import 'dart:async';
import 'dart:convert';

import '../../core/database/app_database.dart';
import '../../core/repositories/settings_repository.dart';
import 'sync_coordinator.dart';

/// Debounce local edits while the app is alive and in the foreground.
/// No OS background scheduling, and no network work is awaited by a screen.
///
/// Besides the debounced "this device changed" trigger, a low-frequency
/// foreground poll asks the remote whether *it* changed. The poll is a metadata
/// request ([SyncProvider.probeRemote]), not a download, and it inherits the
/// same cooldown/backoff state, so there is no request storm.
///
/// The poll is enabled by any of the user's automatic-sync switches
/// ([SyncCoordinator.foregroundProbeEnabled]); it has no separate setting,
/// because "check whether the other device wrote something" is not a decision a
/// user should have to make.
class AutoSyncService {
  AutoSyncService({required this.db, required this.coordinator});
  final AppDatabase db;
  final SyncCoordinator coordinator;
  static const debounce = Duration(seconds: 20);

  /// Foreground remote check. Five minutes is frequent enough for a second
  /// device's edits to show up while the app sits open, and far from polling.
  static const Duration foregroundPoll = Duration(minutes: 5);
  StreamSubscription<dynamic>? _data;
  StreamSubscription<dynamic>? _plan;
  Timer? _timer;
  Timer? _poll;
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
                SettingsRepository.syncPausedKey,
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
    _poll?.cancel();
    _poll = Timer.periodic(foregroundPoll, (_) => _runForegroundCheck());
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _timer?.cancel();
    } else {
      _schedule(debounce);
      _runForegroundCheck();
    }
  }

  /// Runs the cheap remote-version check now (start-up / resume / timer).
  void _runForegroundCheck() {
    if (_disposed || !_foreground || _working) return;
    unawaited(_foregroundCheck());
  }

  Future<void> _foregroundCheck() async {
    try {
      final report = await coordinator.autoSync(trigger: 'foreground');
      if (report != null && report.ok) {
        _onSynced?.call(report);
      }
    } catch (_) {
      // Silent by design: the sync page shows the persistent failure state.
    }
  }

  /// Called after a successful automatic sync so the UI can refresh. Kept as a
  /// callback to avoid importing Flutter into the service.
  void Function(SyncReport report)? _onSynced;

  void setOnSynced(void Function(SyncReport report)? callback) {
    _onSynced = callback;
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
    _poll?.cancel();
    _data?.cancel();
    _plan?.cancel();
  }
}
