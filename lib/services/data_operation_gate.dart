import '../core/database/app_database.dart';

/// A synchronous per-database gate shared by sync and explicit restore paths.
/// Acquisition happens before the first await, closing the sync/restore race.
class DataOperationGate {
  DataOperationGate._();
  static final Set<AppDatabase> _active = <AppDatabase>{};

  static bool tryEnter(AppDatabase db) => _active.add(db);
  static void leave(AppDatabase db) => _active.remove(db);
}
