import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/services/backup_service.dart';
import 'package:materialword/services/sync/aws_signature_v4.dart';
import 'package:materialword/services/sync/credential_store.dart';
import 'package:materialword/services/sync/s3_sync_provider.dart';
import 'package:materialword/services/sync/sync_coordinator.dart';
import 'package:materialword/services/sync/sync_provider.dart';
import 'package:materialword/services/word_intake_service.dart';

import 'helpers/s3_server.dart';
import 'helpers/test_env.dart';

/// Phase 6.3 — S3 as a second, *verified* bidirectional sync transport.
///
/// Every test below talks to a loopback HTTPS server that verifies the SigV4
/// signature from the bytes it received and enforces `If-Match` /
/// `If-None-Match`. Nothing is stubbed at the provider boundary: the signature,
/// the encoded path and the conditional headers are the real ones.
void main() {
  // Deliberately no TestWidgetsFlutterBinding: it installs an HttpOverrides
  // that answers every request with 400 without touching the network, which
  // would make a real TLS + signature test meaningless.
  const String accessKeyId = 'AKIDEXAMPLE';
  const String secretKey = 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY';
  const String dataKey = 'materialword/materialword-data.json';

  S3SyncProvider providerFor(
    S3Server server, {
    String key = dataKey,
    String region = 'us-east-1',
    String? secretOverride,
    String bucketOverride = '',
  }) => S3SyncProvider(
    endpoint: server.endpoint,
    region: region,
    bucket: bucketOverride.isEmpty ? server.bucket : bucketOverride,
    objectKey: key,
    client: server.client,
    accessKeyIdOverride: accessKeyId,
    secretAccessKeyOverride: secretOverride ?? secretKey,
  );

  group('SigV4 reference vectors', () {
    // Values produced by botocore's S3SigV4Auth for the same inputs; see
    // docs/phase6.3-s3-sync.md. A signature that drifts from these is a
    // SignatureDoesNotMatch on every real endpoint.
    const String date = '20261126T013048Z';
    final DateTime now = DateTime.utc(2026, 11, 26, 1, 30, 48);

    String authFor(
      String method,
      String url, {
      required String region,
      Map<String, String> headers = const <String, String>{},
      List<int>? body,
    }) {
      final SignedRequestHeaders signed =
          AwsV4Signer(
            credentials: const AwsCredentials(
              accessKeyId: accessKeyId,
              secretAccessKey: secretKey,
            ),
            region: region,
          ).sign(
            method: method,
            url: Uri.parse(url),
            now: now,
            headers: headers,
            body: body,
          );
      expect(signed.headers['x-amz-date'], date);
      return signed.headers['authorization']!;
    }

    const String awsHost = 'https://s3.us-east-1.amazonaws.com';
    const String objectPath = '/mw-test/materialword/materialword-data.json';

    test('HEAD and GET without conditional headers', () {
      expect(
        authFor('HEAD', '$awsHost$objectPath', region: 'us-east-1'),
        'AWS4-HMAC-SHA256 Credential=$accessKeyId/20261126/us-east-1/'
        's3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, '
        'Signature=e855048ac0437d43006b812f3b8164936b37f9eeed531e8de6a3a4ef4c44fba7',
      );
      expect(
        authFor('GET', '$awsHost$objectPath', region: 'us-east-1'),
        'AWS4-HMAC-SHA256 Credential=$accessKeyId/20261126/us-east-1/'
        's3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, '
        'Signature=14ca505f4b7f9b33ad2e40bc92ae71df7c2e31352ca19760f823a728b319c881',
      );
    });

    test('first create signs If-None-Match', () {
      expect(
        authFor(
          'PUT',
          '$awsHost$objectPath',
          region: 'us-east-1',
          headers: const <String, String>{
            'if-none-match': '*',
            'content-type': 'application/json; charset=utf-8',
          },
          body: utf8.encode('{"a":1}'),
        ),
        'AWS4-HMAC-SHA256 Credential=$accessKeyId/20261126/us-east-1/'
        's3/aws4_request, SignedHeaders=content-type;host;if-none-match;'
        'x-amz-content-sha256;x-amz-date, '
        'Signature=125a0bba2f3039e969022cc158073a128ca848566742b9494660f0b929964388',
      );
    });

    test('update signs If-Match', () {
      expect(
        authFor(
          'PUT',
          '$awsHost$objectPath',
          region: 'us-east-1',
          headers: const <String, String>{
            'if-match': '"9d3f0a"',
            'content-type': 'application/json; charset=utf-8',
          },
          body: utf8.encode('{"a":2}'),
        ),
        'AWS4-HMAC-SHA256 Credential=$accessKeyId/20261126/us-east-1/'
        's3/aws4_request, SignedHeaders=content-type;host;if-match;'
        'x-amz-content-sha256;x-amz-date, '
        'Signature=f7839b86aaf054904c636bc86b4eaf2d31d1c9f4a139b518849b149291af8f0b',
      );
    });

    test('Unicode, space, plus, percent and nested prefixes', () {
      const String key = '中文 词库/a+b/c%d/data file.json';
      final String encoded = AwsV4Signer.encodeKey(key);
      expect(
        encoded,
        '%E4%B8%AD%E6%96%87%20%E8%AF%8D%E5%BA%93/a%2Bb/c%25d/data%20file.json',
      );
      final Uri url = Uri.parse(
        'https://s3.us-east-2.amazonaws.com/mw-test/$encoded',
      );
      // The path that is signed is the path that is sent.
      expect(url.path, '/mw-test/$encoded');
      expect(
        authFor(
          'PUT',
          url.toString(),
          region: 'us-east-2',
          headers: const <String, String>{
            'if-none-match': '*',
            'content-type': 'application/json; charset=utf-8',
          },
          body: utf8.encode('{"b":"中文 +% 空格"}'),
        ),
        'AWS4-HMAC-SHA256 Credential=$accessKeyId/20261126/us-east-2/'
        's3/aws4_request, SignedHeaders=content-type;host;if-none-match;'
        'x-amz-content-sha256;x-amz-date, '
        'Signature=31c2278d7f521b29e1be41880746c5eb25ce5ff2f9dd7fdb2677f8412c36eb1e',
      );
    });

    test('virtual-hosted AWS and path-style R2 addresses', () {
      expect(
        authFor(
          'GET',
          'https://mw-test.s3.eu-west-1.amazonaws.com/materialword/materialword-data.json',
          region: 'eu-west-1',
        ),
        'AWS4-HMAC-SHA256 Credential=$accessKeyId/20261126/eu-west-1/'
        's3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, '
        'Signature=f65b404152768a7dd18680457cca82dd7664dcdf08cd425964febf28d813b9ab',
      );
      expect(
        authFor(
          'GET',
          'https://acct123.r2.cloudflarestorage.com/mw-test/materialword-data.json',
          region: 'auto',
        ),
        'AWS4-HMAC-SHA256 Credential=$accessKeyId/20261126/auto/'
        's3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, '
        'Signature=8c8a48bdfc0da19493a14ced2f66532ca4e0d7c9b19da1c038e3390f84f50103',
      );
    });

    test('a non-default port is part of the signed host', () {
      expect(
        authFor(
          'DELETE',
          'https://127.0.0.1:9000/mw-test/materialword-probe-1234.json',
          region: 'us-east-1',
          headers: const <String, String>{'if-match': '"abcd"'},
        ),
        'AWS4-HMAC-SHA256 Credential=$accessKeyId/20261126/us-east-1/'
        's3/aws4_request, SignedHeaders=host;if-match;x-amz-content-sha256;'
        'x-amz-date, '
        'Signature=c19bb21896062c44117554d0ce413f0158ef8cda8330945eb88f51b58b8966e3',
      );
    });

    test('addressing style is derived from the endpoint', () {
      S3Target resolve(String endpoint, String bucket) => S3Target.resolve(
        endpoint: endpoint,
        region: 'us-east-1',
        bucket: bucket,
        objectKey: 'a/b.json',
      )!;
      expect(
        resolve('https://s3.us-east-1.amazonaws.com', 'mwb').usesVirtualHost,
        isTrue,
      );
      expect(
        resolve('https://acct.r2.cloudflarestorage.com', 'mwb').usesVirtualHost,
        isFalse,
      );
      // A dotted bucket cannot use a wildcard certificate.
      expect(
        resolve(
          'https://s3.us-east-1.amazonaws.com',
          'my.bucket',
        ).usesVirtualHost,
        isFalse,
      );
      expect(
        resolve(
          'https://s3.us-east-1.amazonaws.com',
          'mwb',
        ).objectUri.toString(),
        'https://mwb.s3.us-east-1.amazonaws.com/a/b.json',
      );
      expect(
        resolve(
          'https://acct.r2.cloudflarestorage.com',
          'mwb',
        ).objectUri.toString(),
        'https://acct.r2.cloudflarestorage.com/mwb/a/b.json',
      );
    });

    test('configuration problems are named, not guessed', () {
      String? problem({
        String endpoint = 'https://s3.us-east-1.amazonaws.com',
        String region = 'us-east-1',
        String bucket = 'mw-test',
        String key = 'a.json',
      }) => S3Target.problemWith(
        endpoint: endpoint,
        region: region,
        bucket: bucket,
        objectKey: key,
      );
      expect(problem(endpoint: 'http://s3.amazonaws.com'), contains('HTTPS'));
      expect(problem(endpoint: 'https://h/bucket'), contains('Endpoint'));
      expect(problem(bucket: 'Bad_Bucket'), contains('Bucket'));
      expect(problem(key: '/a.json'), contains('斜杠'));
      expect(problem(key: 'a/../b.json'), contains('..'));
      expect(problem(), isNull);
    });
  });

  group('conditional-write capability', () {
    late S3Server server;

    tearDown(() async => server.close());

    test(
      'a conforming endpoint is proven safe and the probe is cleaned up',
      () async {
        server = await S3Server.start();
        final S3SyncProvider provider = providerFor(server);
        final SyncTestResult result = await provider.testConnection();
        final SyncCapability capability = result.capability!;

        expect(capability.status, SyncCapabilityStatus.safeConditionalWrite);
        expect(capability.safeBidirectionalSync, isTrue);
        expect(capability.supportsIfNoneMatch, isTrue);
        expect(capability.supportsIfMatch, isTrue);
        expect(capability.supportsConditionalRead, isTrue);
        expect(capability.supportsStrongEtag, isTrue);
        expect(capability.probeCleanedUp, isTrue);
        // The probe never touched the real document and left nothing behind.
        expect(server.objects, isEmpty);
        expect(server.hasLeftoverProbe, isFalse);
        // Every write the probe made carried a condition.
        for (final S3SeenRequest request in server.requests.where(
          (S3SeenRequest r) => r.method == 'PUT',
        )) {
          expect(
            request.ifMatch != null || request.ifNoneMatch != null,
            isTrue,
            reason: 'unconditional PUT ${request.path}',
          );
        }
      },
    );

    test(
      'a server that ignores If-None-Match is only basic read/write',
      () async {
        server = await S3Server.start(
          options: const S3Options(obeysIfNoneMatch: false),
        );
        final SyncTestResult result = await providerFor(server)
            .testConnection();
        final SyncCapability capability = result.capability!;
        expect(capability.status, SyncCapabilityStatus.basicReadWrite);
        expect(capability.supportsIfNoneMatch, isFalse);
        expect(capability.safeBidirectionalSync, isFalse);
        expect(capability.detail, contains('If-None-Match'));
        expect(result.supportsConditionalWrites, isFalse);
        expect(
          result.details.any(
            (String d) => d.startsWith('NO_CONDITIONAL_WRITE'),
          ),
          isTrue,
        );
      },
    );

    test('a server that ignores If-Match is only basic read/write', () async {
      server = await S3Server.start(
        options: const S3Options(obeysIfMatch: false),
      );
      final SyncCapability capability = (await providerFor(
        server,
      ).testConnection()).capability!;
      expect(capability.status, SyncCapabilityStatus.basicReadWrite);
      expect(capability.supportsIfMatch, isFalse);
      expect(capability.detail, contains('If-Match'));
    });

    test('an endpoint without ETags cannot be versioned safely', () async {
      server = await S3Server.start(
        options: const S3Options(
          omitPutEtag: true,
          omitHeadEtag: true,
          omitGetEtag: true,
        ),
      );
      final SyncCapability capability = (await providerFor(
        server,
      ).testConnection()).capability!;
      expect(capability.status, SyncCapabilityStatus.basicReadWrite);
      expect(capability.supportsStrongEtag, isFalse);
      expect(capability.detail, contains('ETag'));
      expect(capability.safeBidirectionalSync, isFalse);
    });

    test('a missing bucket is reported as a missing bucket', () async {
      server = await S3Server.start(
        options: const S3Options(bucketMissing: true),
      );
      final SyncCapability capability = (await providerFor(
        server,
      ).testConnection()).capability!;
      expect(capability.status, SyncCapabilityStatus.directoryUnavailable);
      expect(capability.detail, contains('Bucket'));
    });

    test(
      'a denied key is a permission problem, not a connection problem',
      () async {
        server = await S3Server.start(options: const S3Options(denyAll: true));
        final SyncCapability capability = (await providerFor(
          server,
        ).testConnection()).capability!;
        expect(capability.status, SyncCapabilityStatus.permissionDenied);
        expect(capability.safeBidirectionalSync, isFalse);
        expect(server.requests, isNotEmpty);
      },
    );

    test('a wrong secret is an authentication failure', () async {
      server = await S3Server.start();
      final SyncCapability capability = (await providerFor(
        server,
        secretOverride: 'not-the-secret',
      ).testConnection()).capability!;
      expect(capability.status, SyncCapabilityStatus.authenticationFailed);
      expect(server.rejected, isNotEmpty);
      // Every request of the probe was refused by the signature check, and no
      // write ever reached the bucket.
      expect(
        server.rejected.map((S3SeenRequest r) => r.code).toSet(),
        <String?>{'SignatureDoesNotMatch'},
      );
      expect(server.objects, isEmpty);
    });

    test('a region mismatch names the region the server expects', () async {
      server = await S3Server.start(
        options: const S3Options(regionMismatchRegion: 'eu-central-1'),
      );
      final SyncCapability capability = (await providerFor(
        server,
      ).testConnection()).capability!;
      expect(capability.status, SyncCapabilityStatus.connectionFailed);
      expect(capability.detail, contains('eu-central-1'));
    });
  });

  group('data object', () {
    late S3Server server;
    late S3SyncProvider provider;

    setUp(() async {
      server = await S3Server.start();
      provider = providerFor(server);
    });

    tearDown(() async => server.close());

    Future<Map<String, Object?>> dataset(String word) async {
      final TestEnv env = await TestEnv.create();
      await env.intake.add(
        WordIntakeRequest(
          text: word,
          user: const WordContent(translation: 'x'),
        ),
      );
      final Map<String, Object?> built = await env.backup.buildDataset(
        now: env.clock.now(),
      );
      await env.dispose();
      return built;
    }

    test('first create is conditional and returns the new revision', () async {
      final Map<String, Object?> first = await dataset('alpha');
      final SyncUploadResult result = await provider.upload(first);
      expect(result.ok, isTrue);
      expect(result.revision, isNotNull);
      expect(server.textOf(dataKey), isNotNull);
      final S3SeenRequest write = server.requests.lastWhere(
        (S3SeenRequest r) => r.method == 'PUT',
      );
      expect(write.ifNoneMatch, '*');
      expect(write.ifMatch, isNull);
    });

    test(
      'a second unconditional create is refused, never overwrites',
      () async {
        await provider.upload(await dataset('alpha'));
        final String? before = server.textOf(dataKey);
        await expectLater(
          provider.upload(await dataset('beta')),
          throwsA(isA<SyncConflictException>()),
        );
        expect(server.textOf(dataKey), before);
      },
    );

    test('a stale revision is refused and a current one wins', () async {
      final SyncUploadResult created = await provider.upload(
        await dataset('alpha'),
      );
      final String stale = created.revision!;
      // Someone else wrote in between.
      final SyncUploadResult second = await provider.upload(
        await dataset('beta'),
        ifRevision: stale,
      );
      await expectLater(
        provider.upload(await dataset('gamma'), ifRevision: stale),
        throwsA(isA<SyncConflictException>()),
      );
      expect(second.revision, isNot(stale));
      expect(await provider.probeRemote(), isA<RemoteProbe>());
      expect((await provider.probeRemote()).revision, second.revision);
    });

    test('every write to the data object carries a condition', () async {
      await provider.upload(await dataset('alpha'));
      await provider.upload(
        await dataset('beta'),
        ifRevision: (await provider.probeRemote()).revision,
      );
      final Iterable<S3SeenRequest> writes = server.requests.where(
        (S3SeenRequest r) =>
            r.method == 'PUT' && r.path.endsWith('materialword-data.json'),
      );
      expect(writes, isNotEmpty);
      for (final S3SeenRequest write in writes) {
        expect(write.ifMatch != null || write.ifNoneMatch != null, isTrue);
        // The conditional header is under the signature, so it cannot be
        // stripped in transit.
        expect(write.signedHeaders, contains('if-'));
      }
    });

    test(
      'an upload whose response is lost is verified before retrying',
      () async {
        server.loseNextUploadResponse = true;
        final Map<String, Object?> payload = await dataset('alpha');
        final SyncUploadResult result = await provider.upload(payload);
        expect(result.ok, isTrue);
        expect(result.revision, isNotNull);
        expect(result.revision, server.etagOf(dataKey));
        expect(server.textOf(dataKey), isNotNull);
      },
    );

    test('a 409 in-flight conflict becomes a retryable conflict', () async {
      await provider.upload(await dataset('alpha'));
      final String revision = (await provider.probeRemote()).revision!;
      server.conflictOnce = true;
      await expectLater(
        provider.upload(await dataset('beta'), ifRevision: revision),
        throwsA(isA<SyncConflictException>()),
      );
    });

    test(
      'missing, empty, corrupt and valid remote states stay apart',
      () async {
        expect(
          (await provider.fetchRemote()).state,
          RemoteDatasetState.missing,
        );

        server.seed(dataKey, <int>[]);
        final RemoteDataset empty = await provider.fetchRemote();
        expect(empty.state, RemoteDatasetState.empty);
        expect(empty.revision, isNotNull);
        await expectLater(
          provider.download(),
          throwsA(isA<SyncEmptyRemoteException>()),
        );

        server.seedJson(dataKey, '{not json');
        await expectLater(
          provider.fetchRemote(),
          throwsA(isA<SyncDataException>()),
        );

        server.seedJson(dataKey, '[1,2,3]');
        await expectLater(
          provider.fetchRemote(),
          throwsA(isA<SyncDataException>()),
        );

        final Map<String, Object?> good = await dataset('alpha');
        server.seedJson(dataKey, jsonEncode(good));
        final RemoteDataset valid = await provider.fetchRemote();
        expect(valid.state, RemoteDatasetState.valid);
        expect(valid.revision, server.etagOf(dataKey));
      },
    );

    test('probeRemote keeps missing apart from "cannot confirm"', () async {
      expect((await provider.probeRemote()).isMissing, isTrue);

      server.seedJson(dataKey, '{"words":[]}');
      final RemoteProbe present = await provider.probeRemote();
      expect(present.kind, RemoteProbeKind.revision);
      expect(present.revision, server.etagOf(dataKey));
    });

    test('a 403 on a missing object is "unknown", never "missing"', () async {
      await server.close();
      server = await S3Server.start(
        options: const S3Options(hideMissingAsForbidden: true),
      );
      provider = providerFor(server);
      final RemoteProbe probe = await provider.probeRemote();
      expect(probe.kind, RemoteProbeKind.unsupported);
    });

    test('an unusable version token stops the write', () async {
      await provider.upload(await dataset('alpha'));
      await expectLater(
        provider.upload(await dataset('beta'), ifRevision: 'not-an-etag'),
        throwsA(
          isA<SyncException>().having(
            (SyncException e) => e.message,
            'message',
            contains('ETag'),
          ),
        ),
      );
    });
  });

  group('two devices through the coordinator', () {
    late S3Server server;
    late TestEnv a;
    late TestEnv b;

    Future<void> addWord(TestEnv env, String text, String translation) async {
      await env.intake.add(
        WordIntakeRequest(
          text: text,
          user: WordContent(translation: translation),
        ),
      );
    }

    Future<String> hashOf(TestEnv env) async => BackupService.contentHashOf(
      await env.backup.buildDataset(now: env.clock.now()),
    );

    Future<SyncReport> sync(TestEnv env) async {
      final SyncProvider provider = env.coordinator.providerFromConfig(
        await env.settings.syncConfig(),
      )!;
      return env.coordinator.sync(provider);
    }

    setUp(() async {
      server = await S3Server.start();
      a = await TestEnv.create(now: DateTime(2026, 11, 26, 9));
      b = await TestEnv.create(now: DateTime(2026, 11, 26, 10));
      for (final TestEnv env in <TestEnv>[a, b]) {
        env.httpClient = server.client;
        await env.settings.setSyncConfig(<String, Object?>{
          'provider': 's3',
          'endpoint': server.endpoint,
          'region': 'us-east-1',
          'bucket': server.bucket,
          'key': dataKey,
          'autoOnStart': true,
        });
        await env.credentials.write(CredentialKeys.s3AccessKeyId, accessKeyId);
        await env.credentials.write(
          CredentialKeys.s3SecretAccessKey,
          secretKey,
        );
      }
    });

    tearDown(() async {
      await a.dispose();
      await b.dispose();
      await server.close();
    });

    test('concurrent first sync converges on both devices', () async {
      await addWord(a, 'alpha', 'A');
      await addWord(b, 'beta', 'B');

      final List<Object?> outcomes = await Future.wait<Object?>(
        <Future<Object?>>[
          sync(a)
              .then<Object?>((SyncReport r) => r)
              .catchError((Object e) => e),
          sync(b)
              .then<Object?>((SyncReport r) => r)
              .catchError((Object e) => e),
        ],
      );
      // A conflict is an expected outcome of a true race; the losing device
      // must have kept its own data and retried, not overwritten anything.
      for (final Object? outcome in outcomes) {
        expect(outcome, anyOf(isA<SyncReport>(), isA<SyncException>()));
      }

      await sync(a);
      await sync(b);
      await sync(a);

      expect(await hashOf(a), await hashOf(b));
      for (final TestEnv env in <TestEnv>[a, b]) {
        expect(await env.words.byNormalized('alpha'), isNotNull);
        expect(await env.words.byNormalized('beta'), isNotNull);
      }
    });

    test('offline edits on both sides merge instead of replacing', () async {
      await addWord(a, 'alpha', 'A');
      await sync(a);

      // Both devices edit while the other cannot see it.
      await addWord(a, 'gamma', 'A-gamma');
      await addWord(b, 'beta', 'B-beta');
      await sync(b);
      await sync(a);
      // B pulls the merged result A published last; only then are both sides
      // described by the same dataset.
      await sync(b);

      expect(await hashOf(a), await hashOf(b));
      expect(await a.words.byNormalized('beta'), isNotNull);
      expect(await b.words.byNormalized('gamma'), isNotNull);
      // Learning data merges too, not just the word list.
      final int eventsA =
          ((await a.backup.buildDataset(now: a.clock.now()))['reviewEvents']!
                  as List<Object?>)
              .length;
      final int eventsB =
          ((await b.backup.buildDataset(now: b.clock.now()))['reviewEvents']!
                  as List<Object?>)
              .length;
      expect(eventsA, eventsB);
    });

    test('a deleted remote stops the sync until the user decides', () async {
      await addWord(a, 'alpha', 'A');
      await sync(a);
      server.remove(dataKey);
      await expectLater(sync(a), throwsA(isA<SyncRemoteMissingException>()));
      // Nothing was uploaded behind the user's back.
      expect(server.bodyOf(dataKey), isNull);
      // An explicit decision recreates it.
      final SyncProvider provider = a.coordinator.providerFromConfig(
        await a.settings.syncConfig(),
      )!;
      final SyncReport report = await a.coordinator.sync(
        provider,
        allowRemoteRecreate: true,
      );
      expect(report.ok, isTrue);
      expect(server.bodyOf(dataKey), isNotNull);
    });

    test(
      'automatic sync waits for a proven capability and a first sync',
      () async {
        // Nothing proven yet: no request is allowed to leave the device.
        final Object? before = await a.coordinator.autoSync(trigger: 'start');
        expect(before, isNull);
        expect(server.requests, isEmpty);

        await addWord(a, 'alpha', 'A');
        await sync(a);

        a.clock.advance(const Duration(minutes: 2));
        final SyncReport? report = await a.coordinator.autoSync(
          trigger: 'start',
        );
        expect(report, isNotNull);
        expect(report!.ok, isTrue);

        // Losing the verified capability switches automatic sync off again.
        final SyncProvider provider = a.coordinator.providerFromConfig(
          await a.settings.syncConfig(),
        )!;
        await a.coordinator.invalidateCapability(provider);
        a.clock.advance(const Duration(minutes: 5));
        expect(await a.coordinator.autoSync(trigger: 'start'), isNull);
      },
    );

    test(
      'a changed target has its own state and no inherited capability',
      () async {
        await addWord(a, 'alpha', 'A');
        await sync(a);
        final SyncProvider provider = a.coordinator.providerFromConfig(
          await a.settings.syncConfig(),
        )!;
        expect(
          (await a.coordinator.cachedCapability(provider))
              ?.safeBidirectionalSync,
          isTrue,
        );

        final S3SyncProvider otherKey = providerFor(
          server,
          key: 'other/data.json',
        );
        expect(await a.coordinator.cachedCapability(otherKey), isNull);
        expect(await a.coordinator.hasSyncedTarget(otherKey), isFalse);
        // ... and the original target still holds its own record.
        expect(await a.coordinator.hasSyncedTarget(provider), isTrue);
      },
    );
  });

  group('existing transports still work', () {
    test('the coordinator refuses an unproven S3 target', () async {
      final S3Server server = await S3Server.start(
        options: const S3Options(obeysIfNoneMatch: false),
      );
      final TestEnv env = await TestEnv.create();
      env.httpClient = server.client;
      await env.settings.setSyncConfig(<String, Object?>{
        'provider': 's3',
        'endpoint': server.endpoint,
        'region': 'us-east-1',
        'bucket': server.bucket,
        'key': dataKey,
      });
      await env.credentials.write(CredentialKeys.s3AccessKeyId, accessKeyId);
      await env.credentials.write(CredentialKeys.s3SecretAccessKey, secretKey);
      final SyncProvider provider = env.coordinator.providerFromConfig(
        await env.settings.syncConfig(),
      )!;
      await expectLater(
        env.coordinator.sync(provider),
        throwsA(isA<SyncCapabilityException>()),
      );
      // The real document was never written.
      expect(server.bodyOf(dataKey), isNull);
      await env.dispose();
      await server.close();
    });

    test('a scripted provider keeps the conflict retry contract', () async {
      final TestEnv env = await TestEnv.create();
      final ScriptedSyncProvider remote = ScriptedSyncProvider(
        conflictOnce: true,
      );
      await env.intake.add(
        WordIntakeRequest(text: 'alpha', user: const WordContent()),
      );
      final SyncReport report = await env.coordinator.sync(
        remote,
        skipConnectionTest: true,
      );
      expect(report.ok, isTrue);
      expect(report.attempts, 2);
      await env.dispose();
    });
  });
}
