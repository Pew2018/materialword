import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'l10n.dart';

/// Where the app language is stored.
///
/// Deliberately **device-local**: it is a small file next to the app's private
/// support data, never a row in the learning database and never part of a
/// backup, a GitHub/WebDAV payload or a shared settings snapshot. Two devices
/// signed into the same sync account may therefore use different languages.
abstract class LanguageStore {
  /// The value already stored, or the value resolved at start-up.
  AppLanguage get current;

  Future<void> write(AppLanguage language);
}

/// Reads and writes `<application support>/app_language`.
///
/// A file (rather than the SQLite database) keeps start-up free of any database
/// work: the value is available before the first frame, so an existing user
/// never sees the interface switch language a moment after launch.
class DeviceLanguageStore implements LanguageStore {
  DeviceLanguageStore._(this._file, this.current);

  static const String fileName = 'app_language';

  /// The drift database created by every build up to 1.2.0. Its presence is
  /// what distinguishes "upgraded from an earlier version" from "fresh
  /// install", which decides the default for users who never chose a language.
  static const String legacyDatabaseName = 'materialword.sqlite';

  final File _file;

  @override
  final AppLanguage current;

  /// Resolves the stored value, seeding the default on first run.
  ///
  /// * stored value present -> use it, whatever the platform language is;
  /// * no stored value, but the learning database already exists -> the user
  ///   has been running a Chinese-only build, so stay in Chinese;
  /// * no stored value and no database -> fresh install, follow the system.
  static Future<LanguageStore> load() async {
    final Directory support;
    try {
      support = await getApplicationSupportDirectory();
    } catch (_) {
      return MemoryLanguageStore(AppLanguage.system);
    }
    final File file = File('${support.path}${Platform.pathSeparator}$fileName');

    AppLanguage? stored;
    try {
      if (file.existsSync()) {
        final String raw = await file.readAsString();
        if (raw.trim().isNotEmpty) stored = AppLanguage.fromCode(raw);
      }
    } catch (_) {
      // An unreadable file is treated as "not set" instead of blocking launch.
    }
    if (stored != null) return DeviceLanguageStore._(file, stored);

    AppLanguage resolved = AppLanguage.system;
    if (await _hasExistingInstall()) {
      resolved = AppLanguage.zh;
    }
    final DeviceLanguageStore store = DeviceLanguageStore._(file, resolved);
    // Persist the resolved default so the next launch is immediate and stable.
    unawaitedWrite(store, resolved);
    return store;
  }

  static Future<bool> _hasExistingInstall() async {
    try {
      final Directory documents = await getApplicationDocumentsDirectory();
      return File(
        '${documents.path}${Platform.pathSeparator}$legacyDatabaseName',
      ).existsSync();
    } catch (_) {
      return false;
    }
  }

  static void unawaitedWrite(LanguageStore store, AppLanguage language) {
    // Fire and forget: a failed write only means the default is resolved again
    // on the next launch, which is harmless because it is deterministic.
    store.write(language).catchError((_) {});
  }

  @override
  Future<void> write(AppLanguage language) async {
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(language.code, flush: true);
    } catch (_) {
      // Read-only or sandboxed directory: the in-memory value still applies for
      // this session and the deterministic default is used next time.
    }
  }
}

/// In-memory store used by tests and by any environment without a writable
/// application directory.
class MemoryLanguageStore implements LanguageStore {
  MemoryLanguageStore(this.current);

  @override
  AppLanguage current;

  @override
  Future<void> write(AppLanguage language) async {
    current = language;
  }
}
