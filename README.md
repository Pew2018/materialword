# MaterialWord

离线优先的英语单词学习应用（Flutter，经典 Material Design 2 风格）。
目标很直接：**能立刻用来背六级单词**，而不是一个漂亮的空壳。

- 平台：Android / iOS / macOS，同一套 Dart 代码与 Flutter UI（无 WebView、无 Electron）
- 主题：`useMaterial3: false` + `Typography.material2014` + `InkSplash`，还原 Android 7 时代的 Material 视觉
- 数据：本机 SQLite（Drift），词条 / 词书 / 作答历史全部本地
- 词典：内置离线 ECDICT 精简词库（26,282 词，MIT），随包分发，无需联网
- 同步：本地 JSON 导出 / 合并已完整可用；GitHub / WebDAV 仅完成接口与协议规划

## 当前版本

| 项 | 值 |
| --- | --- |
| 版本 | 1.0.0 (Phase 1) |
| Flutter | **3.50.1**（stable，Dart 3.14.0） |
| 关键依赖 | drift 2.35.4 / sqlite3 3.9.2 / flutter_riverpod 3.5.0 / file_picker 13.4.1 / http 1.6.0 / uuid 4.6.0 / path_provider 2.1.6 |
| 应用 ID | `com.pew2018.materialword` |
| 数据库 schemaVersion | 1（用户库）、1（词典库） |
| 备份协议 | schemaVersion 1 |

为什么是 3.50.1：它是当前 stable，并且**仍然完整支持 `ThemeData(useMaterial3: false)`**
（M2 的 `splashFactory`、`Typography.material2014`、传统阴影都在）。这一点在选型时直接查了
SDK 源码确认，不是凭印象。

## 快速开始

```bash
# 1. Flutter 3.50.1（stable）
flutter --version

# 2. 依赖与代码生成
flutter pub get
dart run build_runner build

# 3. 运行（macOS 需要 Xcode；本地若无 Xcode，用 CI 产物）
flutter run -d macos
flutter run -d <android-device>

# 4. 校验
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

# 5. 构建
flutter build macos --release
flutter build apk --release --target-platform android-arm64
flutter build ios --release --no-codesign   # 未签名，不可直接装真机
```

首次启动 → 首页点「导入词表」载入自己的六级单词表（TXT 每行一个词即可），
或点「载入示例词书」先用 30 个词体验学习闭环。

## 目录结构

```
lib/
  main.dart                 启动、注入数据库
  app/                      app 壳、主题、导航、Riverpod providers
  core/
    database/               Drift 表定义、数据库、行映射
    models/                 枚举与领域模型
    repositories/           词条 / 词书 / 学习 / 设置 仓储
  features/
    dashboard/              今日任务
    study/                  学习 / 复习界面
    wordbooks/              词书列表与词书详情
    dictionary/             离线词典查询
    word_management/        快速添加、导入、词条编辑
    settings/               设置
    statistics/             统计
    backup/                 备份、恢复、同步入口
  services/                 调度算法、会话、词典、导入、备份、同步 Provider
  shared/widgets/           通用控件
assets/dictionary/          离线词典 SQLite（ECDICT，MIT）+ 许可证
assets/wordbooks/           示例词书
tool/build_dictionary.py    从 ECDICT CSV 生成词典 SQLite 的脚本
test/                       单元 / Widget 测试（34 个用例，覆盖 T01–T20）
```

## 文档

- [docs/architecture.md](docs/architecture.md) — 分层、数据库、主题与平台差异
- [docs/study-scheduler.md](docs/study-scheduler.md) — 学习算法与队列规则
- [docs/sync-protocol.md](docs/sync-protocol.md) — 数据交换协议与合并规则
- [docs/build-guide.md](docs/build-guide.md) — 本地构建、CI、签名状态
- [docs/roadmap.md](docs/roadmap.md) — 下一阶段计划

## 词典数据与许可

内置词典由 [`tool/build_dictionary.py`](tool/build_dictionary.py) 从
[ECDICT](https://github.com/skywind3000/ECDICT) 的 `ecdict.csv` 生成子集：

- 只保留考试标签词（中考 / 高考 / 四级 / 六级 / 考研 / 托福 / 雅思 / GRE）与词频前 2 万的单词，
  共 **26,282** 条，6.1 MB；
- ECDICT 使用 **MIT 许可**，许可证原文随包放在 `assets/dictionary/ECDICT_LICENSE.txt`；
- 词典与用户数据**分库存储**：更新词典不会影响用户词条与笔记；
- 不抓取任何商业软件的私有内容或非公开接口。

重新生成词典（可选，需要 ECDICT 的 `ecdict.csv`）：

```bash
python3 tool/build_dictionary.py ~/Downloads/ecdict.csv assets/dictionary/ecdict_core.db
```

## 已知限制

- 本机未安装 Xcode，因此 **macOS / iOS 的构建验证在 GitHub Actions 上完成**（见 docs/build-guide.md）。
  本地完成 `flutter analyze`、`flutter test` 与 Android APK 构建。
- Android release APK 目前使用 **debug keystore 临时签名**：可以安装使用，但长期迭代需要换成固定的
  release 签名，否则无法覆盖安装升级。
- iOS 只做无签名编译验证，**未生成可安装 IPA**（没有 Apple 开发者账号与描述文件）。
- GitHub / WebDAV 同步未实现，界面中明确标注「未实现」，不会伪造可用状态。
- 例句、短语字段依赖数据源，词典没有的内容保持空白，不编造。
