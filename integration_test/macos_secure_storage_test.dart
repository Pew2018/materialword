import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:materialword/services/sync/credential_store.dart';

/// MAC07 — the macOS Keychain path, exercised on a real macOS build.
///
/// This is the only test that can prove the classic-keychain configuration
/// (`usesDataProtectionKeychain: false`, no `keychain-access-groups`) actually
/// stores and returns a secret. A unit test cannot: there is no Keychain under
/// `flutter test`, and mocking it would test the mock.
///
/// Run it with:
///
///   flutter test integration_test/macos_secure_storage_test.dart -d macos
///
/// It uses a dedicated test key and a dummy value. It never touches a real
/// GitHub token or WebDAV password, and it cleans up after itself.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String key = 'mac07.selftest.credential';
  // Deliberately not shaped like a real PAT, so a value escaping into a log or
  // an issue tracker is obviously worthless.
  const String value = 'mac07-dummy-value-not-a-real-token';

  testWidgets('macOS 安全凭据：写入 → 读取 → 删除', (WidgetTester tester) async {
    final SecureCredentialStore store = SecureCredentialStore();

    // Start from a known state, so a previous failed run cannot mask a bug.
    await store.delete(key);
    expect(await store.read(key), isNull, reason: '删除后必须读不到');

    await store.write(key, value);
    expect(
      await store.read(key),
      value,
      reason: '写入后必须能原样读回（说明传统 Keychain 可用）',
    );
  });

  testWidgets('macOS 安全凭据：新实例（模拟重启）仍可读取', (WidgetTester tester) async {
    // A fresh store instance is what a relaunched app gets; the value must come
    // from the Keychain, not from memory.
    final SecureCredentialStore reopened = SecureCredentialStore();
    expect(
      await reopened.read(key),
      value,
      reason: '重启后仍能读取，否则每次启动都要重新输入 Token',
    );

    await reopened.delete(key);
    expect(await reopened.read(key), isNull);
  });
}
