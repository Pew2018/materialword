import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/models/enums.dart';
import '../l10n/language_store.dart';
import 'theme.dart';

/// Device-local light/dark preference and accent, read before the first frame.
///
/// The learning database is opened lazily so a stuck file never blocks the
/// window. Without this snapshot the shell would paint [AppColors.defaultAccent]
/// and then repaint once `study_settings` arrives. The snapshot is a small file
/// next to [DeviceLanguageStore], never a database row and never part of a
/// backup, a cloud backup, a sync payload or an export.
abstract class AppearanceStore {
  /// Last resolved appearance. [AppearanceSnapshot.trusted] is false only when
  /// this install already has a learning database and no readable snapshot yet:
  /// the defaults must not be painted as if the user had chosen them.
  AppearanceSnapshot get current;

  /// Remembers [theme] and [accentColor] for the next launch.
  ///
  /// A failed write is swallowed. The in-memory [current] still updates, so
  /// this session stays consistent and only the following launch is affected.
  Future<void> write({
    required ThemePreference theme,
    required String accentColor,
  });
}

/// Parsed contents of the appearance file.
class AppearanceSnapshot {
  const AppearanceSnapshot({
    required this.theme,
    required this.accentColor,
    required this.trusted,
  });

  final ThemePreference theme;

  /// Stored accent text (`#RRGGBB` or a preset id). Not normalised, so a
  /// round-trip returns the same string.
  final String accentColor;

  /// When false, the shell must stay a neutral surface until settings arrive.
  final bool trusted;

  static AppearanceSnapshot defaults({bool trusted = true}) =>
      AppearanceSnapshot(
        theme: ThemePreference.system,
        accentColor: hexOf(AppColors.defaultAccent),
        trusted: trusted,
      );
}

/// Reads and writes `<application support>/appearance`.
///
/// Two lines: the [ThemePreference.code], then the accent string. Anything
/// [ThemePreference.fromCode] or [parseAccent] would silently rewrite counts
/// as "no snapshot".
class DeviceAppearanceStore implements AppearanceStore {
  DeviceAppearanceStore._(this._file, this.current);

  static const String fileName = 'appearance';

  final File _file;

  @override
  AppearanceSnapshot current;

  /// Resolves the stored appearance without opening the database.
  ///
  /// [supportDirectory] and [documentsDirectory] exist so tests can point at a
  /// temporary folder. Production calls [load] with neither set.
  ///
  /// * directory lookup or file read throws → in-memory defaults, trusted
  ///   (a stuck platform channel must not block the window);
  /// * file present and both fields parse → that pair, trusted;
  /// * no readable snapshot, and `materialword.sqlite` already exists in the
  ///   documents directory → defaults, **not** trusted (upgraded install);
  /// * no readable snapshot and no learning database → fresh install, trusted
  ///   defaults, and the file is seeded so the next launch does not look like
  ///   an upgrade once the database has been created.
  static Future<AppearanceStore> load({
    Directory? supportDirectory,
    Directory? documentsDirectory,
  }) async {
    final Directory support;
    try {
      support = supportDirectory ?? await getApplicationSupportDirectory();
    } catch (_) {
      return MemoryAppearanceStore();
    }
    final File file = File('${support.path}${Platform.pathSeparator}$fileName');

    try {
      if (file.existsSync()) {
        final AppearanceSnapshot? stored = _tryParse(await file.readAsString());
        if (stored != null) return DeviceAppearanceStore._(file, stored);
      }
    } catch (_) {
      return MemoryAppearanceStore();
    }

    if (await _hasExistingInstall(documentsDirectory)) {
      return DeviceAppearanceStore._(
        file,
        AppearanceSnapshot.defaults(trusted: false),
      );
    }
    final DeviceAppearanceStore store = DeviceAppearanceStore._(
      file,
      AppearanceSnapshot.defaults(),
    );
    await store.write(
      theme: store.current.theme,
      accentColor: store.current.accentColor,
    );
    return store;
  }

  static Future<bool> _hasExistingInstall(Directory? documents) async {
    try {
      final Directory directory =
          documents ?? await getApplicationDocumentsDirectory();
      return File(
        '${directory.path}${Platform.pathSeparator}'
        '${DeviceLanguageStore.legacyDatabaseName}',
      ).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> write({
    required ThemePreference theme,
    required String accentColor,
  }) async {
    final String stored = _canonicalAccent(accentColor);
    current = AppearanceSnapshot(
      theme: theme,
      accentColor: stored,
      trusted: true,
    );
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString('${theme.code}\n$stored\n', flush: true);
    } catch (_) {
      // Read-only directory: this session keeps [current]; the next launch
      // resolves again.
    }
  }
}

/// In-memory store used by tests, by the provider default, and when the
/// support directory cannot be read. Widget tests never touch a real disk.
class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([AppearanceSnapshot? current])
    : current = current ?? AppearanceSnapshot.defaults();

  @override
  AppearanceSnapshot current;

  @override
  Future<void> write({
    required ThemePreference theme,
    required String accentColor,
  }) async {
    current = AppearanceSnapshot(
      theme: theme,
      accentColor: _canonicalAccent(accentColor),
      trusted: true,
    );
  }
}

/// Returns a trusted snapshot, or null when [raw] is not one.
///
/// A theme code is accepted only when [ThemePreference.fromCode] keeps it
/// (unknown codes collapse to `system` and must not be stored as that). An
/// accent is accepted only when [parseAccent] is actually reading it, not
/// substituting [AppColors.defaultAccent] for garbage.
AppearanceSnapshot? _tryParse(String raw) {
  final List<String> lines = raw
      .split(RegExp(r'\r?\n'))
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();
  if (lines.length != 2) return null;
  final String themeCode = lines[0];
  final ThemePreference theme = ThemePreference.fromCode(themeCode);
  if (theme.code != themeCode) return null;
  if (!_isExplicitAccent(lines[1])) return null;
  return AppearanceSnapshot(theme: theme, accentColor: lines[1], trusted: true);
}

String _canonicalAccent(String accentColor) {
  final String value = accentColor.trim();
  if (_isExplicitAccent(value)) return value;
  return hexOf(parseAccent(value));
}

bool _isExplicitAccent(String value) {
  if (value.isEmpty) return false;
  final Color parsed = parseAccent(value);
  if (parsed.toARGB32() != AppColors.defaultAccent.toARGB32()) return true;
  final String lower = value.toLowerCase();
  if (lower == 'blue' ||
      lower == '#1565c0' ||
      lower == '1565c0' ||
      lower == '#ff1565c0' ||
      lower == 'ff1565c0') {
    return true;
  }
  for (final AccentPalette palette in accentPalettes) {
    if (palette.id.toLowerCase() == lower) return true;
  }
  return false;
}
