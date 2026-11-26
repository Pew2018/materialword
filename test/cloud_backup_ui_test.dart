import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app.dart';
import 'package:materialword/app/navigation.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/features/backup/cloud_backup_dialog.dart';

import 'helpers/test_env.dart';

void main() {
  testWidgets('all five destinations share the white backup action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final env = await TestEnv.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
        ],
        child: const MaterialWordApp(),
      ),
    );
    for (final destination in appDestinations) {
      await tester.tap(find.byKey(ValueKey('nav-${destination.id}')));
      await tester.pump(const Duration(milliseconds: 120));
      final action = tester.widget<IconButton>(
        find.byKey(const ValueKey('manual-cloud-backup')),
      );
      expect((action.icon as Icon).color, Colors.white);
      expect(find.byKey(const ValueKey('manual-cloud-backup')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('manual-cloud-backup')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(CloudBackupDialog), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('尚未配置云端备份。'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await env.dispose();
  });
}
