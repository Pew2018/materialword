import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 2.1 release-configuration regressions.
///
/// These run everywhere `flutter test` runs (no Xcode required). The bundle and
/// ZIP checks re-use tool/verify_macos_bundle.sh, so what CI enforces and what
/// a developer sees locally is literally the same code path.
///
///  * MAC01 — an ad-hoc build must not carry unauthorised Keychain Access Groups.
///  * MAC02 — bundle files, permissions and symlinks are intact.
///  * MAC03 — the signature survives the ZIP round trip a user performs.
///  * MAC09 — the iOS / Android configuration is untouched by the macOS change.

/// The bundle `flutter build macos --release` produces. Only present after a
/// macOS build, so MAC02/MAC03 are skipped elsewhere and marked as skipped.
const String _bundlePath =
    'build/macos/Build/Products/Release/MaterialWord.app';

void main() {
  group('MAC01 临时签名不携带未授权 Keychain Access Groups', () {
    for (final String name in <String>[
      'Release.entitlements',
      'DebugProfile.entitlements',
    ]) {
      test('$name 不含 keychain-access-groups / AppIdentifierPrefix', () {
        final File file = File('macos/Runner/$name');
        expect(file.existsSync(), isTrue, reason: '缺少 $name');

        final String xml = file.readAsStringSync();
        // Match the actual entitlement key, not the explanatory comment that
        // documents why it is absent.
        expect(
          xml,
          isNot(contains('<key>keychain-access-groups</key>')),
          reason: '受限 entitlement 会让 ad-hoc 签名被 launchd 直接拒绝 spawn',
        );
        expect(
          xml,
          isNot(contains(r'$(AppIdentifierPrefix)')),
          reason: '没有 provisioning profile 时该变量会被展开成空前缀',
        );
        expect(
          xml,
          isNot(contains('com.apple.application-identifier')),
          reason: '同样是需要 profile 授权的受限 entitlement',
        );
      });
    }

    test('Release 保留沙箱、网络与用户选择文件权限', () {
      final String xml = File('macos/Runner/Release.entitlements')
          .readAsStringSync();
      for (final String key in <String>[
        'com.apple.security.app-sandbox',
        'com.apple.security.network.client',
        'com.apple.security.files.user-selected.read-write',
      ]) {
        expect(xml, contains('<key>$key</key>'), reason: '不能为了启动而放弃 $key');
      }
    });

    test('Debug 保留 JIT，Release 不保留', () {
      final String debug = File('macos/Runner/DebugProfile.entitlements')
          .readAsStringSync();
      final String release = File('macos/Runner/Release.entitlements')
          .readAsStringSync();
      expect(debug, contains('com.apple.security.cs.allow-jit'));
      expect(release, isNot(contains('allow-jit')));
    });

    test('Release 关闭 Xcode 注入的 get-task-allow', () {
      final String xcconfig = File('macos/Runner/Configs/Release.xcconfig')
          .readAsStringSync();
      expect(
        xcconfig,
        contains('CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO'),
        reason: '否则发布包里会带上可调试的 get-task-allow',
      );
    });

    test('凭据存储改用传统 macOS Keychain', () {
      final String source = File('lib/services/sync/credential_store.dart')
          .readAsStringSync();
      expect(
        source,
        contains('usesDataProtectionKeychain: false'),
        reason: 'data protection keychain 需要访问组，而访问组需要 profile',
      );
      expect(
        source,
        isNot(contains('groupId:')),
        reason: '传 groupId 会重新引入受限 entitlement',
      );
    });

    test('CI 的 macos job 真实验收产物而不是只看编译成功', () {
      final File workflow = File('.github/workflows/ci.yml');
      expect(workflow.existsSync(), isTrue);
      final String yml = workflow.readAsStringSync();
      expect(yml, contains('tool/verify_macos_bundle.sh'));
      expect(yml, contains('--launch'), reason: '必须真实启动，而不是只检查文件');
      expect(
        containsUnzippedVerification(yml),
        isTrue,
        reason: '必须对用户真正下载的 ZIP 复验',
      );
    });
  });

  group('MAC02 / MAC03 构建产物检查', () {
    final bool hasBundle =
        Platform.isMacOS && Directory(_bundlePath).existsSync();

    test('MAC02 Bundle 文件、权限与符号链接完整', () {
      final ProcessResult result = Process.runSync(
        'tool/verify_macos_bundle.sh',
        <String>['--app', _bundlePath, '--expect-arch', 'universal'],
      );
      expect(
        result.exitCode,
        0,
        reason: '脚本输出：\n${result.stdout}\n${result.stderr}',
      );
    }, skip: hasBundle ? false : '未构建 macOS 产物（CI 的 macos job 会先构建再执行本测试）');

    test('MAC03 ZIP 解压后签名与结构保持完整', () {
      final List<File> zips =
          Directory('dist')
              .listSync()
              .whereType<File>()
              .where((File f) => f.path.endsWith('-macos.zip'))
              .toList()
            ..sort((File a, File b) => a.path.compareTo(b.path));
      if (zips.isEmpty) {
        markTestSkipped('dist/ 下没有 macos zip，跳过（由 CI 打包步骤产生）');
        return;
      }
      final ProcessResult result = Process.runSync(
        'tool/verify_macos_bundle.sh',
        <String>['--zip', zips.last.path],
      );
      expect(
        result.exitCode,
        0,
        reason: '脚本输出：\n${result.stdout}\n${result.stderr}',
      );
    }, skip: hasBundle ? false : '未构建 macOS 产物，跳过 ZIP 复验');
  });

  group('MAC09 Android / iOS 不受 macOS 配置调整影响', () {
    test('iOS 与 Android 的工程文件里没有出现 Keychain Access Groups', () {
      for (final String dir in <String>['ios', 'android']) {
        final Directory root = Directory(dir);
        expect(root.existsSync(), isTrue, reason: '缺少 $dir 工程');
        for (final FileSystemEntity entity in root.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (entity.path.endsWith('.entitlements')) {
            expect(
              entity.readAsStringSync(),
              isNot(contains('keychain-access-groups')),
              reason: '${entity.path} 不应被本次 macOS 修改波及',
            );
          }
        }
      }
    });

    test('安全存储在 iOS / Android 上保持原有配置', () {
      final String source = File('lib/services/sync/credential_store.dart')
          .readAsStringSync();
      expect(source, contains('AndroidOptions()'), reason: 'Android 行为不变');
      expect(
        source,
        contains('KeychainAccessibility.first_unlock'),
        reason: 'iOS 仍使用 first_unlock 可访问性',
      );
      // The macOS-only switch must not leak into the iOS options.
      final int iosBlock = source.indexOf('iOptions: IOSOptions(');
      final int macBlock = source.indexOf('mOptions: MacOsOptions(');
      expect(iosBlock, greaterThan(-1));
      expect(macBlock, greaterThan(iosBlock));
      expect(
        source.substring(iosBlock, macBlock),
        isNot(contains('usesDataProtectionKeychain')),
        reason: 'usesDataProtectionKeychain 是 macOS 专有参数',
      );
    });
  });
}

/// True when the workflow re-extracts and re-verifies the ZIP it publishes.
bool containsUnzippedVerification(String workflow) {
  return workflow.contains('--zip');
}
