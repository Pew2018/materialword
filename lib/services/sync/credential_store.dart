import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage for sync secrets (GitHub PAT, WebDAV password).
///
/// The contract is deliberately tiny: tokens are **never** written to the
/// SQLite database, to backup JSON or to logs. [SecureCredentialStore] uses the
/// platform keychain/keystore; [InMemoryCredentialStore] exists for tests only.
abstract class CredentialStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // Keychain unavailable (e.g. unsigned debug build): report "no secret"
      // instead of silently falling back to plain text storage.
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemoryCredentialStore implements CredentialStore {
  InMemoryCredentialStore([Map<String, String>? initial])
    : _values = <String, String>{...?initial};

  final Map<String, String> _values;

  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Well-known credential keys. Never persisted anywhere except the keychain.
class CredentialKeys {
  const CredentialKeys._();

  static const String githubToken = 'sync.github.token';
  static const String webdavPassword = 'sync.webdav.password';
  static const String webdavUsername = 'sync.webdav.username';
}
