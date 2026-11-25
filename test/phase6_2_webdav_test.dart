import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/sync/webdav_sync_provider.dart';

import 'helpers/test_env.dart';
import 'helpers/webdav_server.dart';

/// Phase 6.2 — WebDAV compatibility, capability probing, safe initialization and
/// capability caching.
///
/// Everything here runs against a loopback HTTPS server whose certificate is
/// generated per test; no request ever leaves the machine and no real credential
/// is used.
void main() {
  final InMemoryCredentialStore credentials = InMemoryCredentialStore(
    <String, String>{
      CredentialKeys.webdavUsername: 'test',
      CredentialKeys.webdavPassword: 'local-only',
    },
  );

  WebDavSyncProvider provider(
    WebDavServer server, {
    String dir = 'materialword',
    String file = 'materialword-data.json',
    String epoch = '',
    String? baseUrl,
  }) => WebDavSyncProvider(
    baseUrl: baseUrl ?? server.baseUrl,
    remoteDir: dir,
    fileName: file,
    identityEpoch: epoch,
    credentials: credentials,
    client: server.client,
    traceDiagnostics: false,
  );

  SyncCoordinator coordinator(TestEnv env) => SyncCoordinator(
    db: env.db,
    backup: env.backup,
    study: env.study,
    settings: env.settings,
    credentials: credentials,
    clock: env.clock,
  );

  group('DAV 路径与目录', () {
    test('DAV01/DAV02 基础集合可读，且从不作为 MKCOL 目标', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();

      expect(result.ok, isTrue);
      expect(result.capability!.safeBidirectionalSync, isTrue);
      expect(
        server.baseMkcolAttempted,
        isFalse,
        reason: 'MKCOL /dav/ 是 403 的来源，绝不能发出',
      );
      expect(server.mkcolPaths, <String>['/dav/materialword/']);
    });

    test('DAV03 已存在的目录不会被重复创建', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);
      server.addCollection('/dav/materialword/');

      final SyncTestResult result = await provider(server).testConnection();

      expect(result.capability!.safeBidirectionalSync, isTrue);
      expect(server.mkcolPaths, isEmpty);
    });

    test('DAV04 只创建缺失的相对路径，逐级验证', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);

      final SyncTestResult result = await provider(
        server,
        dir: 'a/b/c',
      ).testConnection();

      expect(result.capability!.safeBidirectionalSync, isTrue);
      expect(server.mkcolPaths, <String>[
        '/dav/a/',
        '/dav/a/b/',
        '/dav/a/b/c/',
      ]);
      expect(server.baseMkcolAttempted, isFalse);
    });

    test('DAV05 根集合可读，但直接写入被拒绝时只报告只读', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);

      final SyncTestResult result = await provider(
        server,
        dir: '',
      ).testConnection();

      final SyncCapability capability = result.capability!;
      expect(capability.directoryAccessible, isTrue);
      expect(capability.canCreate, isFalse);
      expect(capability.status, SyncCapabilityStatus.readOnly);
      expect(capability.detail, contains('403'));
      expect(result.ok, isTrue, reason: '连接成功不等于可以安全同步');
      expect(result.supportsConditionalWrites, isFalse);
      expect(server.dataset, isNull);
    });

    test('DAV06 普通子目录允许写入时报告安全同步可用', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();

      expect(result.capability!.canCreate, isTrue);
      expect(result.capability!.canUpdate, isTrue);
      expect(result.capability!.canDelete, isTrue);
      expect(
        result.capability!.status,
        SyncCapabilityStatus.safeConditionalWrite,
      );
    });

    test('DAV07 PROPFIND Depth:1 返回真实目录并区分文件', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);
      server.addCollection('/dav/Alpha/');
      server.addCollection('/dav/Beta/');
      server.seed('/dav/Beta/notes.json', '{}');

      final List<WebDavDirectoryEntry> entries = await provider(server)
          .listDirectories();

      final List<String> names = entries.map((e) => e.name).toList();
      expect(names, containsAll(<String>['Alpha', 'Beta']));
      expect(
        entries
            .where((WebDavDirectoryEntry e) => e.isCollection)
            .every((WebDavDirectoryEntry e) => !e.path.contains('..')),
        isTrue,
      );

      final List<WebDavDirectoryEntry> insideBeta = await provider(server)
          .listDirectories(path: 'Beta');
      final WebDavDirectoryEntry notes = insideBeta.singleWhere(
        (WebDavDirectoryEntry e) => e.name == 'notes.json',
      );
      expect(notes.isCollection, isFalse);
      expect(notes.path, 'Beta/notes.json');
    });

    test('DAV08 中文与空格目录按一次编码处理', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);
      final WebDavSyncProvider p = provider(server, dir: '学习 资料');

      expect(
        p.directoryUri!.path,
        '/dav/%E5%AD%A6%E4%B9%A0%20%E8%B5%84%E6%96%99/',
      );
      final SyncTestResult result = await p.testConnection();
      expect(result.capability!.safeBidirectionalSync, isTrue);
      expect(
        server.collections,
        contains('/dav/%E5%AD%A6%E4%B9%A0%20%E8%B5%84%E6%96%99/'),
      );
    });

    test('DAV09 已经百分号编码的目录不会二次编码', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);
      final WebDavSyncProvider p = provider(server, dir: 'Material%20Word');

      expect(p.directoryUri!.path, '/dav/Material%20Word/');
      expect(p.directoryUri!.path, isNot(contains('%2520')));
      expect(p.fileUri!.path, '/dav/Material%20Word/materialword-data.json');
    });

    test('DAV10 路径穿越被拒绝', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);

      expect(provider(server, dir: '../etc').isConfigured, isFalse);
      expect(provider(server, dir: 'a/../../etc').isConfigured, isFalse);
      expect(provider(server, dir: '%2e%2e/etc').isConfigured, isFalse);
      expect(provider(server, file: '../evil.json').isConfigured, isFalse);
      expect(provider(server, file: 'a/b.json').isConfigured, isFalse);
    });

    test('DAV11 同源重定向会被跟随', () async {
      final server = await WebDavServer.start(
        options: const WebDavOptions(
          redirectPrefix: '/dav/old',
          redirectTo: '/dav',
        ),
      );
      addTearDown(server.close);

      final SyncTestResult result = await provider(
        server,
        baseUrl: '${server.baseUrl}/old',
      ).testConnection();

      expect(result.ok, isTrue, reason: result.message);
      expect(result.capability!.safeBidirectionalSync, isTrue);
      expect(server.mkcolPaths, <String>['/dav/materialword/']);
    });

    test('DAV12 跨源重定向拒绝继续携带凭据', () async {
      final server = await WebDavServer.start(
        options: const WebDavOptions(
          crossOriginRedirectTo: 'https://evil.example.com/steal',
        ),
      );
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();

      expect(result.ok, isFalse);
      expect(result.capability!.status, SyncCapabilityStatus.connectionFailed);
      expect(result.capability!.detail, contains('重定向'));
      expect(server.collections, isNot(contains('/dav/materialword/')));
    });
  });

  group('CAP 能力探测', () {
    test('CAP01 探测使用普通 JSON 临时文件，内容无隐私', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);

      await provider(server).testConnection();

      final List<String> probes = server.putBodies.keys
          .where((String path) => path.contains('materialword-probe-'))
          .toList();
      expect(probes, isNotEmpty);
      for (final String path in probes) {
        final String name = path.split('/').last;
        expect(name.endsWith('.json'), isTrue, reason: name);
        expect(name.startsWith('.'), isFalse, reason: name);
      }
      final Map<String, Object?> body =
          jsonDecode(server.putBodies[probes.first]!) as Map<String, Object?>;
      expect(body['probe'], isA<String>());
      expect(body.containsKey('words'), isFalse);
    });

    test('CAP02 隐藏文件被拒绝时仍能通过普通 JSON 探测', () async {
      final server = await WebDavServer.start(
        options: const WebDavOptions(allowHiddenFiles: false),
      );
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();

      expect(result.capability!.safeBidirectionalSync, isTrue);
      expect(
        server.putBodies.keys.where((String path) => path.contains('/.')),
        isEmpty,
      );
    });

    test('CAP03 普通 PUT 可用但条件请求被忽略时只报告基础读写', () async {
      final server = await WebDavServer.start(
        options: const WebDavOptions(
          ignoreIfMatch: true,
          ignoreIfNoneMatch: true,
        ),
      );
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();
      final SyncCapability capability = result.capability!;

      expect(capability.canCreate, isTrue);
      expect(capability.canUpdate, isTrue);
      expect(capability.supportsIfMatch, isFalse);
      expect(capability.status, SyncCapabilityStatus.basicReadWrite);
      expect(result.ok, isTrue);
      expect(result.supportsConditionalWrites, isFalse);
      expect(result.details.join(' '), contains('NO_CONDITIONAL_WRITE'));
    });

    test('CAP04/CAP10 强 ETag 与正确的 If-Match 更新可用', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();
      final SyncCapability capability = result.capability!;

      expect(capability.supportsStrongEtag, isTrue);
      expect(capability.supportsIfMatch, isTrue);
      expect(capability.supportsIfNoneMatch, isTrue);
      expect(capability.canUpdate, isTrue);
      expect(capability.canRead, isTrue);
      expect(capability.safeBidirectionalSync, isTrue);
    });

    test('CAP05 弱 ETag 不会被当成强 ETag', () async {
      final server = await WebDavServer.start(etagMode: 'weak');
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();

      expect(result.capability!.supportsStrongEtag, isFalse);
      expect(result.capability!.status, SyncCapabilityStatus.basicReadWrite);
      expect(result.supportsConditionalWrites, isFalse);
    });

    test('CAP06 缺少 ETag 时不允许自动双向同步', () async {
      final server = await WebDavServer.start(etagMode: 'none');
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();

      expect(result.capability!.supportsStrongEtag, isFalse);
      expect(result.capability!.safeBidirectionalSync, isFalse);
      expect(result.details.join(' '), contains('NO_CONDITIONAL_WRITE'));
    });

    test('CAP07 服务端忽略 If-Match 时被识别', () async {
      final server = await WebDavServer.start(
        options: const WebDavOptions(ignoreIfMatch: true),
      );
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();

      expect(result.capability!.supportsIfMatch, isFalse);
      expect(result.capability!.supportsIfNoneMatch, isTrue);
      expect(result.capability!.safeBidirectionalSync, isFalse);
    });

    test('CAP08 服务端忽略 If-None-Match 时被识别', () async {
      final server = await WebDavServer.start(
        options: const WebDavOptions(ignoreIfNoneMatch: true),
      );
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();

      expect(result.capability!.supportsIfNoneMatch, isFalse);
      expect(result.capability!.supportsIfMatch, isTrue);
      expect(result.capability!.safeBidirectionalSync, isFalse);
    });

    test('CAP09/CAP12 条件失败与探测失败都不会改动真实数据文件', () async {
      final List<({bool obeys, String etag, WebDavOptions options})> cases =
          <({bool obeys, String etag, WebDavOptions options})>[
            (obeys: false, etag: 'strong', options: const WebDavOptions()),
            (obeys: true, etag: 'weak', options: const WebDavOptions()),
            (obeys: true, etag: 'none', options: const WebDavOptions()),
            (
              obeys: true,
              etag: 'strong',
              options: const WebDavOptions(ignoreIfMatch: true),
            ),
          ];
      for (final testCase in cases) {
        final server = await WebDavServer.start(
          obeysConditions: testCase.obeys,
          etagMode: testCase.etag,
          options: testCase.options,
        );
        addTearDown(server.close);
        server.replace('{"original":true}');
        final String? original = server.dataset;

        final SyncTestResult result = await provider(server).testConnection();

        expect(result.ok, isTrue);
        expect(result.capability!.safeBidirectionalSync, isFalse);
        expect(server.dataset, original, reason: '真实数据文件不得被探测修改');
        expect(server.dataWrites, 0);
        expect(server.probeCount, 0, reason: '探测文件必须清理');
      }
    });

    test('CAP11 探测文件全部清理，不残留临时资源', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);

      await provider(server).testConnection();

      expect(server.probeCount, 0);
      expect(
        server.traffic.where((String line) => line.startsWith('DELETE')),
        isNotEmpty,
      );
    });

    test('CAP13 403 能定位到 directory_creation 阶段', () async {
      final server = await WebDavServer.start(
        options: const WebDavOptions(rejectMkcol: true),
      );
      addTearDown(server.close);

      final SyncTestResult result = await provider(server).testConnection();

      final SyncCapability capability = result.capability!;
      expect(capability.status, SyncCapabilityStatus.directoryUnavailable);
      expect(capability.failureStage, 'directory_creation');
      expect(capability.failureMethod, 'MKCOL');
      expect(capability.failureStatus, 403);
      expect(result.ok, isFalse);
    });

    test('CAP14 404 能定位到 base_collection_probe 阶段', () async {
      final server = await WebDavServer.start();
      addTearDown(server.close);

      final SyncTestResult result = await provider(
        server,
        baseUrl: '${server.baseUrl}/nope',
      ).testConnection();

      final SyncCapability capability = result.capability!;
      expect(capability.status, SyncCapabilityStatus.directoryUnavailable);
      expect(capability.failureStage, 'base_collection_probe');
      expect(capability.failureStatus, 404);
      expect(capability.detail, contains('/nope'));
    });
  });

  group('INIT 空文件与首次同步', () {
    test('INIT01 远程文件不存在时正常首次创建', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);

      final SyncReport report = await coordinator(env).sync(provider(server));

      expect(report.uploaded, isTrue);
      expect(server.dataWrites, 1);
      final List<({String method, String path, String? match, String? none})>
      writes = server.requests
          .where((r) => r.method == 'PUT' && r.path == WebDavServer.dataPath)
          .toList();
      expect(writes, hasLength(1));
      expect(writes.single.none, '*');
      expect(writes.single.match, isNull);
    });

    test('INIT02 首次同步遇到 0 字节文件不会自动覆盖', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      server.seedEmptyDocument();
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);

      await expectLater(
        coordinator(env).sync(provider(server)),
        throwsA(
          isA<SyncEmptyRemoteException>().having(
            (SyncEmptyRemoteException e) => e.previouslySynced,
            'previouslySynced',
            isFalse,
          ),
        ),
      );
      expect(server.dataset, '');
      expect(server.dataWrites, 0);
    });

    test('INIT03/INIT04 明确授权后用空文件自己的 ETag 初始化', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      server.seedEmptyDocument();
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha', 'beta']);

      final SyncReport report = await coordinator(env)
          .sync(provider(server), initializeEmptyRemote: true);

      expect(report.uploaded, isTrue);
      expect(server.dataWrites, 1);
      final writes = server.requests.where(
        (r) => r.method == 'PUT' && r.path == WebDavServer.dataPath,
      );
      expect(writes.single.match, '"r1"', reason: '必须带上空文件当前的 ETag');
      expect(writes.single.none, isNull);
      expect(
        (jsonDecode(server.dataset!) as Map)['words'] as List,
        hasLength(2),
      );
    });

    test('INIT05/INIT06 初始化期间被其他设备修改时重新读取并合并', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      server.seedEmptyDocument();
      final TestEnv env = await TestEnv.create();
      final TestEnv other = await TestEnv.create();
      addTearDown(env.dispose);
      addTearDown(other.dispose);
      await env.seedBook(words: <String>['alpha']);
      await other.seedBook(words: <String>['beta']);
      server.conflictOnce = true;
      server.concurrentBody = await other.backup.exportToJson(
        now: other.clock.now(),
      );

      final SyncReport report = await coordinator(env)
          .sync(provider(server), initializeEmptyRemote: true);

      expect(report.attempts, 2);
      final Map<String, dynamic> remote =
          jsonDecode(server.dataset!) as Map<String, dynamic>;
      final List<String> texts = (remote['words'] as List)
          .map((dynamic w) => (w as Map)['word'] as String)
          .toList();
      expect(texts, containsAll(<String>['alpha', 'beta']));
      expect(
        BackupService.contentHashOf(remote),
        BackupService.contentHashOf(
          await env.backup.buildDataset(now: env.clock.now()),
        ),
      );
    });

    test('INIT07 已成功同步的目标突然变空时视为异常', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);
      final SyncCoordinator sync = coordinator(env);
      await sync.sync(provider(server));
      expect(server.dataset, isNotNull);

      server.seedEmptyDocument();

      await expectLater(
        sync.sync(provider(server)),
        throwsA(
          isA<SyncEmptyRemoteException>()
              .having(
                (SyncEmptyRemoteException e) => e.previouslySynced,
                'previouslySynced',
                isTrue,
              )
              .having(
                (SyncEmptyRemoteException e) => e.message,
                'message',
                contains('空文件'),
              ),
        ),
      );
      expect(server.dataset, '');
    });

    test('INIT08 损坏 JSON 不会被自动覆盖', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      server.seed(WebDavServer.dataPath, '{"broken":');
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);

      await expectLater(
        coordinator(env).sync(provider(server)),
        throwsA(isA<SyncDataException>()),
      );
      expect(server.dataset, '{"broken":');
      expect(server.dataWrites, 0);
    });

    test('INIT09 空 JSON 对象不被当成有效数据集', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      server.seed(WebDavServer.dataPath, '{}');
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);

      await expectLater(
        coordinator(env).sync(provider(server)),
        throwsA(isA<SyncDataException>()),
      );
      expect(server.dataset, '{}');
      expect(server.dataWrites, 0);
    });

    test('INIT10 初始化失败保留全部本机数据', () async {
      final WebDavServer server = await WebDavServer.start(
        options: const WebDavOptions(rejectDataPut: true),
      );
      addTearDown(server.close);
      server.seedEmptyDocument();
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      final book = await env.seedBook(words: <String>['alpha', 'beta']);

      await expectLater(
        coordinator(env).sync(provider(server), initializeEmptyRemote: true),
        throwsA(isA<SyncException>()),
      );
      expect(
        await env.words.listWords(bookId: book.id),
        hasLength(2),
        reason: '初始化失败不得丢词',
      );
      expect(server.dataset, '');
    });
  });

  group('CACHE 能力缓存', () {
    test('CACHE01/CACHE02 首次验证后正常同步不再完整探测', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);
      final SyncCoordinator sync = coordinator(env);
      final WebDavSyncProvider p = provider(server);

      await sync.sync(p);
      expect(
        server.requests.where((r) => r.path.contains('materialword-probe-')),
        isNotEmpty,
      );

      server.requests.clear();
      await sync.sync(p);

      expect(
        server.requests.where((r) => r.path.contains('materialword-probe-')),
        isEmpty,
        reason: '缓存有效时不应再创建探测文件',
      );
      expect(server.dataWrites, 1);
    });

    test('CACHE03 用户主动测试连接会绕过缓存', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);
      final SyncCoordinator sync = coordinator(env);
      final WebDavSyncProvider p = provider(server);
      await sync.sync(p);

      server.requests.clear();
      final SyncCapability capability = await sync.ensureCapability(
        p,
        force: true,
      );

      expect(capability.safeBidirectionalSync, isTrue);
      expect(
        server.requests.where((r) => r.path.contains('materialword-probe-')),
        isNotEmpty,
      );
    });

    test('CACHE04/CACHE05/CACHE06 目录、地址或凭据变化使缓存失效', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);
      final SyncCoordinator sync = coordinator(env);
      await sync.sync(provider(server));

      expect(await sync.cachedCapability(provider(server)), isNotNull);
      expect(
        await sync.cachedCapability(provider(server, dir: 'other')),
        isNull,
      );
      expect(
        await sync.cachedCapability(
          provider(
            server,
            baseUrl: server.baseUrl.replaceFirst('127.0.0.1', 'localhost'),
          ),
        ),
        isNull,
      );
      expect(
        await sync.cachedCapability(provider(server, epoch: 'credential-2')),
        isNull,
      );
    });

    test('CACHE07 缓存过期后重新验证', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);
      final SyncCoordinator sync = coordinator(env);
      await sync.sync(provider(server));
      expect(await sync.cachedCapability(provider(server)), isNotNull);

      sync.capabilityCache.ttl = Duration.zero;
      env.clock.advance(const Duration(seconds: 1));

      expect(await sync.cachedCapability(provider(server)), isNull);
    });

    test('CACHE08 能力不再安全时缓存被清除', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);
      final SyncCoordinator sync = coordinator(env);
      final WebDavSyncProvider p = provider(server);
      await sync.sync(p);
      expect(await sync.cachedCapability(p), isNotNull);

      await sync.rememberCapability(
        p,
        const SyncCapability(status: SyncCapabilityStatus.basicReadWrite),
      );

      expect(await sync.cachedCapability(p), isNull);
    });

    test('CACHE09 未验证或不支持安全同步时自动任务不启动', () async {
      final WebDavServer server = await WebDavServer.start(
        options: const WebDavOptions(ignoreIfMatch: true),
      );
      addTearDown(server.close);
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      final WebDavSyncProvider p = provider(server);
      await env.settings.setSyncConfig(<String, Object?>{
        'provider': 'webdav',
        'url': server.baseUrl,
        'dir': 'materialword',
        'file': 'materialword-data.json',
        'autoOnStart': true,
      });
      // Pretend this target synced before, so only the capability gate is left.
      await env.db.writeMeta(
        'sync_target:${SyncCoordinator.targetKey(p)}',
        jsonEncode(<String, Object?>{'hash': 'x', 'revision': '"r1"'}),
      );
      final SyncCoordinator sync = coordinator(env);

      expect(await sync.autoSync(trigger: 'start'), isNull);
      expect(await sync.autoRetryDelay(trigger: 'change'), isNull);
    });

    test('CACHE10 正式上传始终保留并发保护', () async {
      final WebDavServer server = await WebDavServer.start();
      addTearDown(server.close);
      final TestEnv env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook(words: <String>['alpha']);
      final SyncCoordinator sync = coordinator(env);
      await sync.sync(provider(server));
      await env.words.ensureWord(text: 'beta', now: env.clock.now());
      await sync.sync(provider(server));

      final List<({String method, String path, String? match, String? none})>
      writes = server.requests
          .where((r) => r.method == 'PUT' && r.path == WebDavServer.dataPath)
          .toList();
      expect(writes, hasLength(2));
      expect(writes.first.none, '*');
      expect(writes.last.match, isNotNull);
    });
  });
}
