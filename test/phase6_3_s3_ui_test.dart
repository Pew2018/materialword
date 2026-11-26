import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/providers.dart';
import 'package:materialword/features/sync/sync_settings_page.dart';
import 'package:materialword/l10n/l10n.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/s3_sync_provider.dart';
import 'package:materialword/services/sync/sync_capability_cache.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';

import 'helpers/test_env.dart';

/// Phase 6.3 UI: S3 is offered next to WebDAV, with the same style, the same
/// per-target status block and the same "auto sync needs proof" rule.
///
/// No request leaves the widget test: a *verified* capability is seeded into the
/// per-target cache (which is exactly what a successful 测试连接 writes), so the
/// page has to render from stored state. The transport itself is covered against
/// a real loopback HTTPS endpoint in `phase6_3_s3_sync_test.dart`.
void main() {
  const String endpoint = 'https://s3.us-east-1.amazonaws.com';
  const String bucket = 'materialword-sync';
  const String key = 'materialword/materialword-data.json';

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  S3SyncProvider providerFor(InMemoryCredentialStore store) => S3SyncProvider(
    endpoint: endpoint,
    region: 'us-east-1',
    bucket: bucket,
    objectKey: key,
    credentials: store,
  );

  Future<TestEnv> pumpPage(
    WidgetTester tester, {
    Map<String, Object?> extra = const <String, Object?>{},
    SyncCapability? capability,
  }) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final TestEnv env = await TestEnv.create();
    addTearDown(env.dispose);
    final InMemoryCredentialStore credentials = InMemoryCredentialStore(
      <String, String>{
        CredentialKeys.s3AccessKeyId: 'AKIDEXAMPLE',
        CredentialKeys.s3SecretAccessKey: 'secret-local-only',
      },
    );
    await env.credentials.write(CredentialKeys.s3AccessKeyId, 'AKIDEXAMPLE');
    await env.settings.setSyncConfig(<String, Object?>{
      'provider': 's3',
      'endpoint': endpoint,
      'region': 'us-east-1',
      'bucket': bucket,
      'key': key,
      ...extra,
    });
    if (capability != null) {
      final S3SyncProvider provider = providerFor(credentials);
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
          credentialStoreProvider.overrideWithValue(credentials),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const SyncSettingsPage(),
        ),
      ),
    );
    await settle(tester);
    return env;
  }

  testWidgets('S3 is offered with its own connection fields', (tester) async {
    await pumpPage(tester);

    expect(find.text('S3'), findsOneWidget);
    expect(find.text('同步到 S3 兼容存储桶（AWS S3、Cloudflare R2）'), findsOneWidget);

    // The S3 configuration is already selected, so its fields are visible.
    expect(find.text('Endpoint'), findsOneWidget);
    expect(find.text('Region'), findsOneWidget);
    expect(find.text('Bucket'), findsOneWidget);
    expect(find.text('对象键'), findsOneWidget);
    expect(find.text('Access Key ID'), findsOneWidget);
    expect(find.text('Secret Access Key'), findsOneWidget);
    // Credentials are never echoed with their real value.
    expect(find.text('secret-local-only'), findsNothing);

    // Nothing was proven for this target yet.
    expect(find.text('尚未验证连接'), findsOneWidget);
  });

  testWidgets('a verified S3 target reads as ready, with the real address', (
    tester,
  ) async {
    await pumpPage(
      tester,
      capability: const SyncCapability(
        status: SyncCapabilityStatus.safeConditionalWrite,
        reachable: true,
        authenticated: true,
        directoryAccessible: true,
        canRead: true,
        canCreate: true,
        canUpdate: true,
        canDelete: true,
        supportsStrongEtag: true,
        supportsConditionalRead: true,
        supportsIfMatch: true,
        supportsIfNoneMatch: true,
      ),
    );

    expect(find.text('连接成功，可以同步'), findsOneWidget);
    expect(find.text('尚未验证连接'), findsNothing);
    expect(find.text('服务器已响应。'), findsOneWidget);
  });

  testWidgets('auto sync stays off until the target is verified', (
    tester,
  ) async {
    await pumpPage(tester, extra: const <String, Object?>{'autoOnStart': true});

    expect(find.text('自动同步已暂停。请先通过「测试连接」验证安全写入。'), findsOneWidget);
  });
}
