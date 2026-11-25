# Phase 3 最终交付报告

审计参考基线 `ddf0221e05546485d7de4c721bd767d712e0ac27` → 本次交付起点 `e3f16f7f4a5dc5a42a5d7840019fd76171938cd4`。

**构建来源 SHA：`24faea96feda8a6f19f722505731715a18920882`**（Run 45547631573，四 job 全绿）。
本文件所在提交只改 `docs/`，不参与构建（CI `paths-ignore: docs/**`、`**.md`）；可用
`git diff --stat 24faea9..HEAD` 复核源码零差异。

## 1. 交付物

| 产物 | 内容 | 大小 | 入口 |
|---|---|---:|---|
| Android ARM64 APK | `MaterialWord-24faea9-android-arm64.apk` | 13,782,021 B | Run artifact `android-arm64-apk` |
| macOS `.app` ZIP | `MaterialWord-24faea9-macos.zip`（ditto，保留符号链接） | 25,962,157 B | Run artifact `macos-app` |
| iOS 无签名构建 | `MaterialWord-24faea9-ios-unsigned.zip` | 12,622,949 B | Run artifact `ios-unsigned` |

Run：https://github.com/Pew2018/materialword/actions/runs/45547631573

## 2. 平台验证结果（全部来自本次 SHA）

- **Android**：arm64 引擎（`lib/arm64-v8a/libflutter.so`、`libapp.so`、`libsqlite3.so`），无 v7a/x86_64 `libflutter.so`；`package name=com.pew2018.materialword versionCode=3 versionName=1.2.0`；`apksigner verify --print-certs` 通过，V2 签名证书 `C=US, O=Android, CN=Android Debug`（**runner 临时 debug 身份，不具备生产覆盖升级条件**）。
- **macOS**：`bundle-id=com.pew2018.materialword`，`arch=x86_64 arm64`（universal），`min-macos=12.0`，`signing=adhoc`（无 Developer ID、无 provisioning profile、未公证）；bundle 结构/签名/Entitlements 校验 PASS，ZIP 往返校验 PASS，**真实启动验证 `executed-pass`**（按 Finder 方式启动并到达首屏，非仅进程存在）。
- **iOS**：`flutter build ios --release --no-codesign` 成功，产物已上传；**无签名 ≠ 可安装 IPA**，真机安装需要 Apple 团队与描述文件。
- **Validate**：`dart format --set-exit-if-changed`、`flutter analyze`、`flutter test`（含 Golden）、跨时区重放脚本全部通过。

## 3. 本地质量闸门（同一工作区，交付前最后一次）

- `flutter pub get` / `dart run build_runner build`：成功。
- `dart format --output=none --set-exit-if-changed lib test`：0 changed。
- `flutter analyze`：No issues found。
- `flutter test`：**286 通过、2 项平台条件跳过**（跳过项需要真实 macOS Bundle/ZIP，在 macOS job 中执行）。
- `tool/verify_timezone_replay.sh`：香港/纽约双进程各 1 项通过。
- `git diff --check`：无空白错误。

## 4. Stage 状态

| Stage | 状态 | 说明 |
|---|---|---|
| 00 基线 | 完成 | Golden 按栅格器建立精确基线；Gradle 依赖重试 + 构建退避；APK 校验步骤 |
| 01 数据/同步/备份 | 基本完成 | 新增恢复副本管理、导出；同步冲突矩阵与凭据审计沿用既有测试；平台长期 URI 授权仍为手动导入导出（明确降级） |
| 02 录入/词书/词典 | 完成（词形为规则+数据校验） | 词书导出 TXT/CSV/JSON、词典最近搜索、原型词候选 |
| 03 UI/跨平台 | 部分完成 | 设置分组、诊断区、随机顺序、上滑显示释义已做；全应用控件逐项视觉复核与真机验收未完成 |
| 04 学习/练习 | 完成（常亮除外） | 拼写/听写/选择/挖空真实实现；常亮需原生插件，未引入 |
| 05 统计/性能/诊断/基础 | 完成（图标除外） | 统计扩展、诊断导出、关于页、性能整改；应用图标仍为模板资源 |
| 06 回归矩阵 | 完成 | `docs/phase3-acceptance-matrix.md` |
| 07 构建交付 | 完成 | 四 job 全绿，产物校验与真实启动通过 |

## 5. 明确未完成 / 外部阻塞

1. **屏幕常亮**：需引入原生插件（wakelock 类），本批不新增原生依赖以免影响三平台构建稳定性 —— 未实现，不冒充。
2. **原创应用图标 / 启动画面**：仍为 Flutter 模板资源（`05-05` 未完成）。
3. **真实 WebDAV 服务与真实 GitHub PAT**：仅有 Mock、本机真实 HTTPS loopback 服务与公开仓库权限矩阵；用户生产服务未验证。
4. **真机验收**：三平台触控、IME、返回手势、实际语音发声、DPI/多窗口均未在真机执行。
5. **签名**：Android 为 debug keystore；macOS 为 ad-hoc 未公证；iOS 无签名。三者都不能当作可分发版本。
6. **合并/重放性能**：20k 词 / 100k 事件 debug 下约 13.9 s，仍是最大瓶颈；本轮只优化了统计查询（461→338 ms），未做结构性重写。
7. **Stage 03 的逐控件视觉审计**：只完成分组重组与关键交互，未做全应用 Dialog/Slider/PopupMenu 的逐项真机复核。

## 6. 回归保护结果

- 245 项既有测试全部保留并通过；本轮新增 41 项（练习 11 + 练习 UI 3 + 统计 4 + 诊断 5 + 导出/词形 8 + 学习交互 3 + 到期刷新 4 + Golden 支持 3），未删除、未 skip、未放宽任何旧断言。
- 新增 UI 测试在真实点击路径上抓到一个真 bug（练习页在 `dispose()` 里读 provider），已改为 `initState` 解析，属于"测试发现缺陷"而非"测试迁就实现"。
- Schema 未变更（仍为 3），无迁移风险；练习事件使用既有事件表与 `mode` 前缀，撤销/同步/重放路径完全复用。
