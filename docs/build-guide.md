# 构建指南

## 工具链

- Flutter 3.50.1 stable / Dart 3.14.0（本机 `~/development/flutter/bin`）
- Android SDK 36 + JDK（Android Studio 自带）
- macOS / iOS 需要**完整 Xcode**（不是 Command Line Tools）+ CocoaPods

## 本地命令

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter pub get
dart run build_runner build
dart format lib test tool
flutter analyze
flutter test
flutter build macos --release
flutter build apk --release --target-platform android-arm64
# 无签名编译验证（不代表可安装）
flutter build ios --release --no-codesign
```

本次实际结果：
- `flutter pub get` / `build_runner` / `dart format` / `flutter analyze` / `flutter test` 本地通过，
  **102 项测试全部通过**。
- Android ARM64 构建本机因 Maven/Google Maven 返回 503 未能下载 Gradle 依赖；
  CI 的 `android` job 负责产出 APK。
- 本机 Xcode 与 CocoaPods 不可用（只有 Command Line Tools），macOS / iOS 构建只能通过 CI。
- CI 四个 job：`validate`、`android`、`macos`、`ios`，推送 `main` 自动触发。

## 平台权限与签名

- **Android**：`AndroidManifest.xml` 声明 `INTERNET`；不发明文 HTTP 请求。
  Release 仍使用 debug 签名以保证既有用户可覆盖安装。**签名身份未改变**。
- **macOS**：沙箱 + `com.apple.security.network.client` + 用户选择文件读写 +
  `keychain-access-groups`（flutter_secure_storage 存 Token）。
- **iOS**：HTTPS 默认允许；Keychain 由 `flutter_secure_storage` 管理；
  未配置签名，CI 只做 `--no-codesign` 编译验证。
- 没有为了联网而放宽 TLS 校验；WebDAV 只接受 HTTPS，跨域重定向拒绝携带凭据。

## 凭据与数据隐私

- GitHub Fine-grained PAT / WebDAV 密码只写入平台安全存储（Keychain / Keystore），
  不进入 SQLite、备份 JSON、日志或 Git。
- 备份 JSON 不包含 token/password（SYNC13 有回归测试）。
- 不提交任何个人学习数据；示例词书与 ECDICT 子集均为开源数据。

## 产物位置

CI 成功后从对应 Actions Run 的 Artifacts 下载：
- `android-arm64-apk`：`app-arm64-v8a-release.apk`
- `macos-app`：Release `.app`（打包保留符号链接与权限）
- `ios-unsigned-build`：编译验证产物（不可安装）

本地测试用词典桩见 `test/helpers/test_dictionary.dart`，不依赖 6 MB 内置数据库资源。
词典资产旁必须有 `assets/dictionary/ecdict_core.db.meta.json`（由
`tool/build_dictionary.py` 自动生成），应用据此校验私有目录中的缓存版本。
