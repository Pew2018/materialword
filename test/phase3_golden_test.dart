import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/navigation.dart';
import 'package:materialword/app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final brightness in Brightness.values) {
    testWidgets('Classic theme golden ${brightness.name}', (tester) async {
      // Pin every input the rasteriser can see: surface size, pixel ratio,
      // target platform (ThemeData derives typography, visual density and
      // scroll physics from it) and text scale. The reference image is still
      // compared pixel-for-pixel; see test/support/platform_golden_comparator.dart
      // for why the reference is resolved per host rasteriser.
      tester.view.physicalSize = const Size(420, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(
            brightness,
            const Color(0xFF00796B),
            // Explicit: the golden must not depend on the host's
            // `defaultTargetPlatform`, which differs between macOS and the
            // Ubuntu CI runner and selects a different text typography.
            platform: TargetPlatform.android,
          ),
          home: RepaintBoundary(
            key: const ValueKey('golden'),
            child: Scaffold(
              appBar: AppBar(title: const Text('MaterialWord')),
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('vocabulary', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 12),
                    const Text('Learn a little every day.'),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Continue'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Review'),
                    ),
                    const SizedBox(height: 24),
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      value: true,
                      onChanged: (_) {},
                      title: const Text('Automatic pronunciation'),
                    ),
                    const Divider(),
                    SwitchListTile(
                      value: true,
                      onChanged: (_) {},
                      title: const Text('Random order'),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: ClassicBottomNavigationBar(
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/classic_${brightness.name}.png'),
      );
    });
  }
}
