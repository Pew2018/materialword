# Phase 5 验证记录

本文件只记录**实际执行**的验证。源码实现本身不构成通过（见验收矩阵的"源"列）。

## 1. 本地命令

执行顺序与结果（全部在本机完成）：

| 命令 | 结果 |
|---|---|
| `flutter pub get` | 成功 |
| `dart run build_runner build` | 成功，224 outputs |
| `dart format --output=none --set-exit-if-changed lib test` | 123 文件，0 需要修改 |
| `flutter analyze` | No issues found |
| `flutter test` | **442 通过、2 跳过、0 失败**（exit 0） |
| `bash tool/verify_timezone_replay.sh` | 香港进程 + 纽约进程各 1 项通过 |
| `git diff --check` | 无输出 |

2 项跳过仍是 `test/macos_packaging_test.dart` 的 macOS 产物检查（本地未构建 macOS），
由 CI 的 `macos` job 在构建后执行。

## 2. 测试构成

| 文件 | 数量 | 覆盖 |
|---|---:|---|
| `phase5_intake_test.dart` | 15 | ADD01–ADD14 + 快速添加页真实点击（ADD04-UI） |
| `phase5_import_test.dart` | 19 | IMP01–IMP19 |
| `phase5_export_test.dart` | 12 | EXP01–EXP12（真实 A→文件→B 往返） |
| `phase5_backup_test.dart` | 21 | BAK01–BAK21 |
| `phase5_sync_test.dart` | 26 | SYNC01–SYNC24 + GitHub 远端缺失 + 本地文件限制 |
| `phase5_performance_test.dart` | 6 | 文件型 SQLite 基准、冷/热启动、批量等价与提速 |
| `phase5_regression_test.dart` | 2 | 端到端数据闭环 + Schema/协议版本断言 |
| 既有测试 | 341 | Phase 1–4 全部保留 |

改动 1 项旧断言：`phase3_auto_sync_test.dart` 中"恢复前台后只有一次 change 触发"。
Phase 5 新增了恢复前台的远端探测（独立的 `foreground` 触发），因此断言改为
`['change', 'foreground', 'change']`。这是**新增的契约**（更严格：明确区分本机变更触发与
远端探测触发），不是放宽。

## 3. 关键验证细节

### 数据往返（EXP03）

数据库 A → `WordBookExporter.encodeBook(json)` → `ImportService.parseContent` →
`ImportService.commit` → 数据库 B → 逐字段比较：`word / phonetic / partOfSpeech /
translation / definition / example / phrase / note / examTags + bncRank / frqRank`。
测试关闭词典补全（`ImportService` 未注入 dictionary），因此不可能由自动补全掩盖丢失。

### 多设备收敛（SYNC01–SYNC24）

三台独立数据库 A/B/C + `ScriptedSyncProvider`（与 GitHub/WebDAV 相同的条件写入契约：
过期 `ifRevision` 抛冲突）。每轮比较**数据库内容**与 `BackupService.contentHashOf`，
不比较 UI 文案。SYNC24 连续三轮各自新增、互相同步，最后补齐一轮后三者哈希一致。

### 备份恢复（BAK15/BAK16）

- BAK15：恢复后词条数回到快照值、后加入的词消失、事件仍在、保护性备份内容为恢复前状态。
- BAK16：在"清空所有表之后、合并之前"注入异常，断言词条数仍为恢复前的 4、词书未删除、
  `sync_paused` 仍为 false —— 即整个事务回滚。

### 并发（SYNC16/17/19、IMP19、ADD11）

- 上传回调内写入新作答/新词：本机保留，且 `hasLocalChanges` 仍为 true（下一轮上传带上）。
- 旧快照与导入同时进行：两者都在，引用不丢。
- 远端损坏：`SyncDataException`，本机不变，未发生上传。

### 性能（本机实测，Debug）

同一数据集、同一机器、文件型 SQLite，5 000 词 / 30 000 事件：

| 项 | 逐词合并（`legacyWordMerge: true`） | 批量合并 | 变化 |
|---|---:|---:|---|
| 词条合并阶段 | 2 967 ms | 1 982 ms | **−33%**（1.50x） |

完整合并与重放（内存 SQLite，`phase3_performance_test.dart`，20 000 词 / 100 001 事件）：

| 版本 | 耗时 |
|---|---:|
| Phase 3 记录 | 13 759 ms |
| Phase 4 记录 | 6 866 ms |
| **Phase 5 实测** | **5 854 ms** |

其余分段（Phase 5，1k/10k 与 5k/30k 文件库）：单次新增 6 / 1 ms、导入 500 词 14 / 3 ms、
搜索 10 / 2 ms、导出 JSON 24 / 44 ms、完整备份 423 / 957 ms、备份校验 223 / 543 ms、
快照合并 1 086 / 3 174 ms、200 词重放 125 / 143 ms、冷启动 3 ms。

**这些不是 Release / 真机数据**，只用于同机前后对比。

## 4. 未验证（明确不通过）

1. 三平台真机交互、TTS、常亮、前后台切换的人工验收。
2. 真实 GitHub 私有仓库 + 真实 PAT 的完整矩阵（CI 只跑协议与守卫测试）。
3. 真实 WebDAV 服务（仅有 loopback HTTPS 协议测试）。
4. Android SAF / iOS Files / macOS 沙盒文件选择的真机行为（代码尊重插件给出的
   安全缓存路径并拒绝把 `content://` 当文件路径，但没有真机确认）。
5. Release 模式性能与包体、真机内存。
6. 正式签名、公证与分发（本阶段明确排除）。
7. 断电/DOS 级崩溃下的目录项持久性（无法用 Dart 表达目录 fsync）。

## 5. 与其他文档的差异

- `docs/phase3-verification.md` 记录的 162 项、`docs/phase4-delivery.md` 记录的 341 项
  是各自阶段的历史数字；当前为 440 通过 / 2 跳过。
- `docs/roadmap.md` 的 Phase 3 复选框未完全回写，实际完成情况以 Phase 4/5 文档与测试为准。
