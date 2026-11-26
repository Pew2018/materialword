import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/app/theme.dart';
import 'package:materialword/features/settings/diagnostics_page.dart';
import 'package:materialword/features/sync/sync_settings_page.dart';
import 'package:materialword/features/sync/webdav_directory_picker.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/sync_capability_cache.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/sync/webdav_sync_provider.dart';
import 'package:materialword/shared/widgets/common.dart';

import 'helpers/test_env.dart';
import 'helpers/webdav_mock_client.dart';

/// Phase 6.2 UI: the status block must describe what the server can actually do,
/// not whether `testConnection().ok` happened to be true.
///
/// The transport is an in-memory WebDAV endpoint (widget tests run in a fake
/// async zone, where a real socket never completes). The same scenarios against
/// a real loopback HTTPS server live in `phase6_2_webdav_test.dart`.
void main() {
  const String dataFile = 'materialword-data.json';

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    // Let dialog/route transitions finish; without this a closed dialog still
    // owns its action buttons for a few frames.
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  InMemoryCredentialStore newStore() =>
      InMemoryCredentialStore(<String, String>{
        CredentialKeys.webdavUsername: 'test',
        CredentialKeys.webdavPassword: 'local-only',
      });

  WebDavSyncProvider providerFor(
    WebDavMock mock,
    InMemoryCredentialStore store, {
    String dir = 'materialword',
  }) => WebDavSyncProvider(
    baseUrl: mock.baseUrl,
    remoteDir: dir,
    fileName: dataFile,
    credentials: store,
    client: mock.client,
    traceDiagnostics: false,
  );

  /// Seeds a capability record directly in the per-target cache.
  ///
  /// A *failed* probe is never cached in production, so tests that only check how
  /// a state is rendered write the record instead of pretending the server is
  /// reachable.
  Future<void> seedCapability(
    TestEnv env,
    WebDavSyncProvider provider,
    SyncCapability capability,
  ) async {
    await env.db.writeMeta(
      'sync_capability:${SyncCoordinator.targetKey(provider)}',
      jsonEncode(<String, Object?>{
        'v': SyncCapabilityCache.version,
        'at': env.clock.now().toUtc().toIso8601String(),
        'fingerprint': await provider.capabilityFingerprint(),
        'capability': capability.toJson(),
      }),
    );
  }

  Future<TestEnv> pumpPage(
    WidgetTester tester,
    WebDavMock mock, {
    Map<String, Object?> extra = const <String, Object?>{},
    InMemoryCredentialStore? store,
    Future<void> Function(TestEnv env)? beforePump,
  }) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final TestEnv env = await TestEnv.create();
    addTearDown(env.dispose);
    final InMemoryCredentialStore credentials = store ?? newStore();
    await env.settings.setSyncConfig(<String, Object?>{
      'provider': 'webdav',
      'url': mock.baseUrl,
      'dir': 'materialword',
      'file': dataFile,
      ...extra,
    });
    if (beforePump != null) await beforePump(env);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
          credentialStoreProvider.overrideWithValue(credentials),
          syncHttpClientProvider.overrideWithValue(mock.client),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          home: const SyncSettingsPage(),
        ),
      ),
    );
    await settle(tester);
    return env;
  }

  Future<void> tapTest(WidgetTester tester) async {
    final Finder test = find.widgetWithText(OutlinedButton, '测试连接');
    await reveal(tester, test);
    await tester.tap(test);
    await settle(tester);
  }

  group('SYNCUI 同步状态与能力', () {
    testWidgets('UI01 连接成功且安全同步可用时显示绿色成功', (WidgetTester tester) async {
      final WebDavMock mock = WebDavMock();
      await pumpPage(tester, mock);

      await tapTest(tester);

      expect(find.text('连接成功，可以同步'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_circle).first).color,
        AppColors.known,
      );
      expect(find.text('尚未验证连接'), findsNothing);
    });

    testWidgets('UI02 只能读写但无法验证并发安全时显示警告', (WidgetTester tester) async {
      final WebDavMock mock = WebDavMock(obeysConditions: false);
      final InMemoryCredentialStore store = newStore();
      await pumpPage(
        tester,
        mock,
        store: store,
        beforePump: (TestEnv env) => seedCapability(
          env,
          providerFor(mock, store),
          const SyncCapability(
            status: SyncCapabilityStatus.basicReadWrite,
            reachable: true,
            authenticated: true,
            directoryAccessible: true,
            canRead: true,
            canCreate: true,
            canUpdate: true,
            canDelete: true,
            detail: '服务器未拒绝过期的 If-Match',
          ),
        ),
      );

      expect(find.text('基础读写可用，未能验证安全同步'), findsOneWidget);
      expect(
        tester
            .widget<Icon>(find.byIcon(Icons.warning_amber_outlined).first)
            .color,
        AppColors.hazy,
      );
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('UI03 认证失败时显示红色错误', (WidgetTester tester) async {
      final WebDavMock mock = WebDavMock();
      final InMemoryCredentialStore store = newStore();
      await pumpPage(
        tester,
        mock,
        store: store,
        beforePump: (TestEnv env) => seedCapability(
          env,
          providerFor(mock, store),
          const SyncCapability(
            status: SyncCapabilityStatus.authenticationFailed,
            reachable: true,
            detail: '用户名或密码不正确',
          ),
        ),
      );

      expect(find.text('认证失败：账号或密码不正确'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.lock_outline).first).color,
        AppColors.unknown,
      );
    });

    testWidgets('UI04 目录权限不足时给出准确提示', (WidgetTester tester) async {
      final WebDavMock mock = WebDavMock(rejectMkcol: true);
      await pumpPage(tester, mock);

      await tapTest(tester);

      expect(find.text('已连接，但无法访问此文件夹'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.folder_off_outlined).first).color,
        AppColors.unknown,
      );
    });

    testWidgets('UI05 未验证的目标不会声称自动同步已启用', (WidgetTester tester) async {
      final WebDavMock mock = WebDavMock();
      final InMemoryCredentialStore store = newStore();
      final TestEnv env = await pumpPage(
        tester,
        mock,
        store: store,
        extra: <String, Object?>{'autoOnStart': true},
      );
      await env.db.writeMeta(
        'sync_target:${SyncCoordinator.targetKey(providerFor(mock, store))}',
        jsonEncode(<String, Object?>{'hash': 'x', 'revision': '"r1"'}),
      );

      expect(find.text('自动同步已暂停。请先通过「测试连接」验证安全写入。'), findsOneWidget);
      final Finder tile = find.widgetWithText(SwitchListTile, '启动时同步');
      await reveal(tester, tile);
      expect(
        tester.widget<SwitchListTile>(tile).value,
        isTrue,
        reason: '偏好可以保存',
      );
      expect(
        await env.coordinator.autoSync(trigger: 'start'),
        isNull,
        reason: '未验证时不得真正运行',
      );
    });

    testWidgets('UI06 切换配置后旧的验证结果失效', (WidgetTester tester) async {
      final WebDavMock mock = WebDavMock();
      await pumpPage(tester, mock);

      await tapTest(tester);
      expect(find.text('连接成功，可以同步'), findsOneWidget);

      final Finder dirField = find.byKey(
        const ValueKey<String>('sync_field_dir'),
      );
      await reveal(tester, dirField);
      await tester.enterText(dirField, 'AnotherFolder');
      await settle(tester);

      expect(find.text('连接成功，可以同步'), findsNothing);
      expect(find.text('尚未验证连接'), findsOneWidget);
    });

    testWidgets('A draft password cannot verify the saved credentials', (
      tester,
    ) async {
      final mock = WebDavMock();
      final store = newStore();
      final env = await pumpPage(tester, mock, store: store);
      final password = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.obscureText,
      );
      await reveal(tester, password);
      await tester.enterText(password, 'draft-secret');
      await tester.pump();
      await tapTest(tester);

      expect(find.text('连接成功，可以同步'), findsOneWidget);
      expect(
        await env.coordinator.cachedCapability(providerFor(mock, store)),
        isNull,
      );
    });

    testWidgets('UI09 技术详情与普通文案分离', (WidgetTester tester) async {
      final WebDavMock mock = WebDavMock();
      await pumpPage(tester, mock);

      await tapTest(tester);

      expect(find.text('连接成功，可以同步'), findsOneWidget);
      expect(find.text('服务器已响应。'), findsOneWidget);
      expect(find.text('文件夹可访问，也可浏览。'), findsOneWidget);
      expect(find.text('临时测试文件已成功写入并读回。'), findsOneWidget);
      expect(find.text('技术详情'), findsOneWidget);
      expect(
        find.text('· 基础读写验证通过：创建、读回、更新、删除'),
        findsNothing,
        reason: '细节默认收起，普通文案只保留结论',
      );
    });

    testWidgets('UI10 同步失败后可以进入诊断信息', (WidgetTester tester) async {
      final WebDavMock mock = WebDavMock();
      await pumpPage(tester, mock);

      final Finder tile = find.widgetWithText(SettingsTile, '同步诊断信息');
      await reveal(tester, tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.byType(DiagnosticsPage), findsOneWidget);
      expect(find.text('诊断信息'), findsOneWidget);
      expect(find.text('导出诊断报告'), findsOneWidget);
    });
  });

  group('SYNCUI 远程目录与初始化', () {
    testWidgets('UI07 可以浏览并选择真实远程目录', (WidgetTester tester) async {
      final WebDavMock mock = WebDavMock();
      mock.addCollection('/dav/Alpha/');
      mock.addCollection('/dav/Beta/');
      final InMemoryCredentialStore store = newStore();
      final WebDavSyncProvider provider = providerFor(mock, store);

      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    chosen = await showWebDavDirectoryPicker(
                      context: context,
                      provider: provider,
                      initialPath: 'Alpha',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);

      expect(find.text('选择远程文件夹'), findsOneWidget);
      expect(find.text('/Alpha/'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, '上一级'));
      await settle(tester);
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Beta'));
      await settle(tester);
      await tester.tap(find.text('选择此文件夹'));
      await settle(tester);

      expect(chosen, 'Beta');
    });

    testWidgets('UI08 空文件初始化必须由用户明确确认', (WidgetTester tester) async {
      final WebDavMock mock = WebDavMock();
      mock.seedEmptyDocument();
      final TestEnv env = await pumpPage(tester, mock);
      await env.seedBook(words: <String>['alpha']);

      final Finder syncButton = find.widgetWithText(ElevatedButton, '立即同步');
      await reveal(tester, syncButton);
      await tester.tap(syncButton);
      await settle(tester);

      expect(find.text('首次同步'), findsOneWidget);
      await tester.tap(find.text('开始合并'));
      await settle(tester);

      // The empty file blocks the run and asks first.
      final Finder emptyDialog = find.widgetWithText(AlertDialog, '远程文件为空');
      expect(emptyDialog, findsOneWidget);
      expect(find.text('初始化并同步'), findsOneWidget);

      await tester.tap(
        find.descendant(of: emptyDialog, matching: find.text('取消')),
      );
      await settle(tester);

      expect(mock.dataset, '', reason: '取消后不得写入，也不得静默重建远程文件');
      expect(
        mock.traffic.where((String line) => line == 'PUT ${mock.dataPath}'),
        isEmpty,
      );
    });
  });
}
