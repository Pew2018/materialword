# 构建指南

## 工具链

- Flutter 3.50.1 stable / Dart 3.14.0（本机 `~/development/flutter/bin`）
- Android SDK 36 + JDK（Android Studio 自带）
- macOS / iOS 的完整 Xcode 与 CocoaPods 仅使用 GitHub Actions macOS Runner 已有环境；禁止在用户本机安装或升级 Xcode、CLT、Apple SDK 和模拟器。

## 本地命令

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter pub get
dart run build_runner build
dart format lib test tool
flutter analyze
flutter test
```

Phase 2 历史结果（当前 Phase 3 结果见 phase3-verification.md）：
- `flutter pub get` / `build_runner` / `dart format` / `flutter analyze` / `flutter test` 本地通过，
  **102 项测试全部通过**。
- Android ARM64 构建本机因 Maven/Google Maven 返回 503 未能下载 Gradle 依赖；
  CI 的 `android` job 负责产出 APK。
- 本机 Xcode 与 CocoaPods 不可用（只有 Command Line Tools），macOS / iOS 构建只能通过 CI。
- CI 四个 job：`validate`、`android`、`macos`、`ios`，推送 `main` 自动触发。

## 平台权限与签名

- **Android**：`AndroidManifest.xml` 声明 `INTERNET`；不发明文 HTTP 请求。
  Release 当前使用 runner 的临时 debug keystore，跨 runner 构建的证书可能不同，**不能保证覆盖安装**。不得自行更换安装身份；固定签名与已有安装迁移仍需验证。
- **macOS**：沙箱 + `com.apple.security.network.client` + 用户选择文件读写。
  **不再声明 `keychain-access-groups`**：那是受限 entitlement，只有带 provisioning
  profile 的签名才能生效；本项目是 ad-hoc 签名，带上它会让 launchd 直接拒绝
  spawn 应用（Finder 只会显示“应用程序无法打开”）。凭据改走传统 login keychain
  （`usesDataProtectionKeychain: false`），不需要任何 entitlement。
- **iOS**：HTTPS 默认允许；Keychain 由 `flutter_secure_storage` 管理；
  未配置签名，CI 只做 `--no-codesign` 编译验证。

## iOS 产物与安装

CI 的 `ios` job 上传 `ios-unsigned`，里面有两个等价的东西：

| 文件 | 内容 | 用途 |
| --- | --- | --- |
| `MaterialWord-<sha>-unsigned.ipa` | `Payload/Runner.app`（arm64） | 交给重签名工具（Sideloadly / AltStore） |
| `MaterialWord-<sha>-ios-unsigned.zip` | 同一个 `Runner.app` | 拖进 Xcode → Window → Devices |

两者都是**未签名**的：iOS 只安装“有开发者签名 + 与设备匹配的 provisioning
profile”的包，所以它们不能直接双击/拖拽安装，这是签名缺失，不是打包缺陷。
`build-info-ios.txt` 里也写明了这一点，CI 会在上传前校验 IPA 内确实有
`Payload/Runner.app/Info.plist` 与可执行文件。

要得到可安装的包，必须在一台装了完整 Xcode 的机器上自备 Apple 团队：

```bash
# 1) Xcode 打开 ios/Runner.xcworkspace → Runner → Signing & Capabilities
#    勾选 Automatically manage signing，Team 选自己的 Apple ID（免费账号 7 天）
#    Bundle Identifier 改成唯一值，如 cn.<yourname>.materialword
# 2) 然后二选一：
open ios/Runner.xcworkspace            # 直接 Run 到已连接的设备
flutter build ipa --export-method development   # 产出 build/ios/ipa/*.ipa
```

没有付费开发者账号时，免费账号签名的应用 7 天后失效，且同时最多 3 个；
首次安装后需在「设置 → 通用 → VPN与设备管理」里信任该开发者证书。
长期分发（TestFlight / App Store / Ad Hoc）必须使用付费的 Apple Developer Program。
- 没有为了联网而放宽 TLS 校验；WebDAV 只接受 HTTPS，跨域重定向拒绝携带凭据。

## 凭据与数据隐私

- GitHub Fine-grained PAT / WebDAV 密码只写入平台安全存储（Keychain / Keystore），
  不进入 SQLite、备份 JSON、日志或 Git。
- 备份 JSON 不包含 token/password（SYNC13 有回归测试）。
- 不提交任何个人学习数据；示例词书与 ECDICT 子集均为开源数据。

## 产物位置

CI 成功后从对应 Actions Run 的 Artifacts 下载：
- `android-arm64-apk`：`app-arm64-v8a-release.apk`
- `macos-app`：Release `.app`（`ditto` 打包，保留符号链接与权限）+
  `build-info-macos.txt`、`verify-*.txt`
- `ios-unsigned-build`：编译验证产物（不可安装）

## macOS 产物验收

`flutter build macos --release` 成功**不代表**应用能启动。`macos` job 在打包前后各跑
一次 `tool/verify_macos_bundle.sh`：

```bash
# 本地复验一个已构建的产物
tool/verify_macos_bundle.sh --app build/macos/Build/Products/Release/MaterialWord.app --launch
tool/verify_macos_bundle.sh --zip dist/MaterialWord-<sha>-macos.zip
```

检查项：Bundle 结构、Info.plist、`CFBundleExecutable` 与执行权限、Mach-O 架构、
Framework 与 `@rpath` 依赖、符号链接、`codesign --verify --deep --strict`、
受限 entitlement、ZIP 解压后的签名与权限，以及**真实启动**。

真实启动通过 LaunchServices（`open`，与 Finder 双击同一路径）发起，要求进程存活、
数据库被创建（说明越过了 `main()` 并跑完首个页面）、且没有新的崩溃报告。
沙箱应用不能用 shell 直接 exec 主程序——那会让 `libsystem_secinit` 直接 trap，
与产物质量无关。

GitHub 的 macOS runner 如果没有可用的图形会话，启动项会记为
`not-executed-no-gui-session` 并写进 `build-info-macos.txt`；**不会**计为通过。
此时需在真机按上面的命令补做一次。

未公证的 ad-hoc 产物被 Gatekeeper 拒绝属于预期的分发限制，脚本会单独标注，
与“签名本身损坏”区分开。

本地测试用词典桩见 `test/helpers/test_dictionary.dart`，不依赖 6 MB 内置数据库资源。
词典资产旁必须有 `assets/dictionary/ecdict_core.db.meta.json`（由
`tool/build_dictionary.py` 自动生成），应用据此校验私有目录中的缓存版本。
