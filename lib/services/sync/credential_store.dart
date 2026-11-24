import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Raised when the platform secure storage exists but cannot be used right now
/// — the Keychain refused the request, the sandbox denied access, or the app
/// signature no longer matches the one that wrote the item.
///
/// It is deliberately distinct from `read() == null`, which only means
/// "nothing stored under that key". Callers must show a message and ask the
/// user to re-enter the secret; they must **never** fall back to plain-text
/// storage, a log line, or the SQLite database.
class CredentialStoreUnavailable implements Exception {
  const CredentialStoreUnavailable(this.reason, {this.cause});

  /// Short, user-presentable explanation (no secret material).
  final String reason;

  /// Original platform error, kept for diagnostics. Never contains a secret.
  final Object? cause;

  @override
  String toString() => 'CredentialStoreUnavailable($reason)';
}

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
    : _storage = storage ?? defaultStorage;

  /// Platform options used by the shipped app.
  ///
  /// * Android / iOS keep the original behaviour (first_unlock accessibility).
  /// * macOS uses the **classic login keychain** (`usesDataProtectionKeychain:
  ///   false`). The data-protection keychain on macOS requires the app to be
  ///   signed for a Keychain access group, which in turn requires a
  ///   provisioning profile. MaterialWord is ad-hoc signed, so requesting an
  ///   access group makes launchd refuse to start the bundle at all. The
  ///   classic keychain needs no entitlement: the implicit access group is the
  ///   app's own signature, and items are still encrypted by the system
  ///   keychain, still per-app, and still never written in clear text.
  ///
  /// `groupId` is intentionally left null — passing it would re-introduce the
  /// restricted `keychain-access-groups` entitlement.
  static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
      usesDataProtectionKeychain: false,
    ),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      // Do not report "no secret": the item may exist but be unreadable.
      throw CredentialStoreUnavailable(_describe(e), cause: e);
    } on MissingPluginException catch (e) {
      throw CredentialStoreUnavailable('安全存储插件不可用', cause: e);
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (e) {
      throw CredentialStoreUnavailable(_describe(e), cause: e);
    } on MissingPluginException catch (e) {
      throw CredentialStoreUnavailable('安全存储插件不可用', cause: e);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on PlatformException catch (e) {
      throw CredentialStoreUnavailable(_describe(e), cause: e);
    } on MissingPluginException catch (e) {
      throw CredentialStoreUnavailable('安全存储插件不可用', cause: e);
    }
  }

  /// Maps the platform error to a message the UI can show. `code` and `message`
  /// never contain the secret, only the Keychain status.
  static String _describe(PlatformException e) {
    final String code = e.code;
    return switch (code) {
      '-34018' => '系统钥匙串拒绝访问（缺少访问权限，可能需要重新输入凭据）',
      '-25300' => '系统钥匙串中不存在该项目',
      '-25293' => '系统钥匙串已锁定',
      '-25308' => '系统钥匙串交互被拒绝',
      _ => '系统钥匙串不可用（${e.code}）',
    };
  }
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

/// A store whose backing keychain is unavailable, used by tests and by the
/// "keychain refused" code paths to prove that offline study still works.
class UnavailableCredentialStore implements CredentialStore {
  const UnavailableCredentialStore([this.reason = '系统钥匙串不可用']);

  final String reason;

  @override
  Future<String?> read(String key) async =>
      throw CredentialStoreUnavailable(reason);

  @override
  Future<void> write(String key, String value) async =>
      throw CredentialStoreUnavailable(reason);

  @override
  Future<void> delete(String key) async =>
      throw CredentialStoreUnavailable(reason);
}

/// Well-known credential keys. Never persisted anywhere except the keychain.
class CredentialKeys {
  const CredentialKeys._();

  static const String githubToken = 'sync.github.token';
  static const String webdavPassword = 'sync.webdav.password';
  static const String webdavUsername = 'sync.webdav.username';
}
