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
      tester.view.physicalSize = const Size(420, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(brightness, const Color(0xFF00796B)),
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
