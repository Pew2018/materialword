import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/database/app_database.dart';
import 'services/diagnostics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One database instance for the whole app; tests override this provider with
  // an in-memory database. Opening is cheap: the file is opened lazily and
  // Drift runs the schema migration inside `beforeOpen`, so no query can reach
  // a half-migrated schema.
  final AppDatabase database = AppDatabase.open();

  // The first frame never waits for the database. A blocked first frame is
  // indistinguishable from "the app did not start" — the macOS window simply
  // never appears — and the repair below is a no-op on a healthy install.
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const MaterialWordApp(),
    ),
  );

  unawaited(_repairDictionaryTextAfterFirstFrame(database));
  // Restores the (default off) diagnostics switch and, when it is on, the tail
  // of the previous session's trace file.
  unawaited(_initialiseDiagnostics(database));
}

/// Points diagnostics at an app-private file, then reads the persisted switch.
///
/// Kept after the first frame for the same reason as the dictionary repair: the
/// window must appear even if the file system is slow or read-only.
Future<void> _initialiseDiagnostics(AppDatabase database) async {
  try {
    final Directory directory = await getApplicationSupportDirectory();
    DiagnosticsService.instance.attachFile(
      File('${directory.path}/diagnostics.log'),
    );
  } catch (_) {
    // No writable directory: diagnostics stay in memory only.
  }
  try {
    await DiagnosticsService.instance.load(database);
  } catch (_) {
    // A diagnostics failure must never stop the app from starting.
  }
}

/// Rewrites dictionary rows written by older builds (literal `\n` escapes).
///
/// Runs after the UI is already on screen. Two guards make that safe:
///  * Drift's `beforeOpen` already performs this repair for a created or
///    upgraded database, and blocks every query until the migration is done,
///    so this is normally a single indexed read of the meta flag;
///  * the repair itself is guarded by a meta key and is idempotent, so an
///    interrupted run repeats harmlessly on the next start.
///
/// A failure here must never take the app down: the text is cosmetic, the
/// learning data is not touched.
Future<void> _repairDictionaryTextAfterFirstFrame(AppDatabase database) async {
  try {
    // Wait until the first frame is actually scheduled, so the window appears
    // before any extra database work starts.
    await WidgetsBinding.instance.endOfFrame;
    await database.repairDictionaryText();
  } catch (e) {
    debugPrint('dictionary text repair skipped: $e');
  }
}
