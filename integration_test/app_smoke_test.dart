import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:materialword/main.dart' as app;

/// End-to-end smoke test that runs on a real device / macOS window.
///
/// It is intentionally *not* part of `flutter test` (which has no Flutter
/// engine); run it with:
///
///   flutter test integration_test/app_smoke_test.dart -d macos
///
/// Requires a working Xcode (macOS) or an attached Android device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('应用启动并显示今日页面', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('今日'), findsWidgets);
    expect(find.text('今日任务'), findsOneWidget);
  });
}
