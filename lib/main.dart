import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One database instance for the whole app; tests override this provider with
  // an in-memory database. Opening is cheap: the file is opened lazily.
  final AppDatabase database = AppDatabase.open();

  // Repair dictionary text written by older builds (literal `\n` escapes) before
  // the first frame paints it. Guarded by a meta flag, so it is a no-op on a
  // healthy database and idempotent if it was interrupted.
  try {
    await database.repairDictionaryText();
  } catch (e) {
    debugPrint('dictionary text repair skipped: $e');
  }

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const MaterialWordApp(),
    ),
  );
}
