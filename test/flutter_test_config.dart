import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/platform_golden_comparator.dart';

/// Entry point used by `flutter test` for every test in `test/`.
///
/// Installs the platform-aware exact-match golden comparator. See
/// `test/support/platform_golden_comparator.dart` for the rationale and the
/// resolution order of reference images.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  goldenFileComparator = PlatformGoldenFileComparator(
    Uri.parse('test/flutter_test_config.dart'),
  );
  await testMain();
}
