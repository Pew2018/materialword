# 构建指南

## 本机环境（本次实际检查结果）

| 项 | 值 |
| --- | --- |
| macOS | 27.0.1 (26A434)，arm64（Apple Silicon） |
| Git | 2.53.0 |
| GitHub CLI | 已登录 `Pew2018`，scopes: gist / read:org / repo / workflow |
| Flutter | 3.50.1 stable（`~/development/flutter`），Dart 3.14.0 |
| Xcode | **未安装**（只有 Command Line Tools 27.0）→ 本地无法构建 macOS / iOS |
| CocoaPods | 未安装（Flutter 3.50 默认使用 Swift Package Manager，iOS/macOS 插件不再必须） |
| Android SDK | `~/Library/Android/sdk`，platforms 34/36/37，build-tools 34/36 |
| cmdline-tools | 已把 Homebrew 的 `android-commandlinetools` 软链到 `~/Library/Android/sdk/cmdline-tools/latest` |
| JDK | OpenJDK 17.0.21（Homebrew） |
| 可用磁盘 | 约 109 GiB |

`flutter doctor` 现状：Flutter ✓ / Android toolchain ✓ / Xcode ✗ / Chrome ✗（本项目不需要 web）。
Xcode 缺失是本阶段唯一的硬性阻塞，处理方式见下文。

## 本地命令

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Library/Android/sdk"

flutter pub get
dart run build_runner build          # 生成 app_database.g.dart
dart format lib test
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

产物：`build/app/outputs/flutter-apk/app-release.apk`（arm64-v8a，约 20 MB）。

### 关于 macOS / iOS 的本地构建

`flutter build macos` 与 `flutter build ios` 都要求完整 Xcode（`xcodebuild`）。
本机只有 Command Line Tools，因此：

- 本地**不伪称**构建成功；
- macOS `.app` 与 iOS 编译验证在 GitHub Actions 的 `macos-latest` runner 上完成；
- 想在本机构建时，安装 Xcode 后执行
  `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
  再重新运行对应命令，不需要改任何项目配置。

## GitHub Actions

工作流：`.github/workflows/ci.yml`，触发条件 `push: [main]`（忽略纯文档改动）与 `workflow_dispatch`。

| Job | Runner | 内容 | 超时 |
| --- | --- | --- | --- |
| `validate` | ubuntu-latest | pub get → build_runner → format 检查 → analyze → test | 25 min |
| `android` | ubuntu-latest | 构建 arm64 release APK，上传 artifact | 30 min |
| `macos` | macos-latest | `flutter build macos --release`，用 `ditto` 打包 `.app` 保符号链接，上传 ZIP | 40 min |
| `ios` | macos-latest | `flutter build ios --release --no-codesign`，上传未签名构建报告 | 35 min |

其他约定：

- Flutter 版本用 `FLUTTER_VERSION: 3.50.1` 与本地严格一致，`subosito/flutter-action` 带 `cache: true`；
- 四个 job 互相独立，任一平台失败不影响其他平台产物；
- `concurrency` + `cancel-in-progress` 防止同一 ref 重复跑（私有仓库 macOS 分钟数按 10 倍计费）；
- Android job 单独缓存 `~/.gradle`；
- 只上传构建产物 + `build-info-*.txt`（含 commit SHA、Flutter 版本、架构、签名状态），
  不上传中间文件。

## 签名状态

| 平台 | 现状 | 说明 |
| --- | --- | --- |
| Android | **debug keystore 临时签名** | `android/app/build.gradle.kts` 里 release 使用 `signingConfigs.getByName("debug")`。可以侧载安装并使用；但**长期升级必须换成固定的 release key**，否则签名不一致无法覆盖安装。私钥/密码绝不入库，用 CI secret 注入 `key.properties`。 |
| macOS | ad-hoc / 未签名 | 没有 Developer ID 证书，因此**未公证**。首次打开需要「右键 → 打开」绕过 Gatekeeper。 |
| iOS | 未签名 | `--no-codesign` 只证明工程能编译。**未签名产物不是 IPA，也不能装到 iPhone/iPad**。要出可安装 IPA 需要 Apple Developer 账号 + Team + provisioning profile。 |

## 数据文件位置（已实测）

- 用户库：`drift_flutter` 默认放在应用的 Documents 目录 —
  macOS 实测为
  `~/Library/Containers/com.pew2018.materialword/Data/Documents/materialword.sqlite`
  （7 张表 + 索引，`PRAGMA user_version = 1`）；
- 词典库：`path_provider` 的 Application Support 目录下 `dictionary/ecdict_core.db`，
  首次需要查询时从 bundle 复制（资源长度变化会重新复制）；
- 两者都**不入库、不同步原始文件**；跨设备只同步 JSON 备份。

## 常见问题

**`flutter build apk` 报 `cmdline-tools component is missing`**
把 cmdline-tools 放到 `$ANDROID_HOME/cmdline-tools/latest`，再执行
`sdkmanager --licenses` 接受许可。

**`flutter test` 报找不到 `sqlite3`**
单元测试用的是宿主机的 SQLite（macOS 自带）。Linux CI 上 `flutter test` 通过
`sqlite3_flutter_libs`/native assets 提供，无需额外安装。

**`build_runner` 之后 `app_database.g.dart` 有变动**
不要手改生成文件；改动 `lib/core/database/tables.dart` 后重新生成并一起提交，
CI 会重新生成但不会提交。
