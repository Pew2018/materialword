# Phase 5.1 验证记录（核心数据功能收口）

本文件只记录**实际执行**的验证。源码实现本身不构成通过。

## 0. 结论

> 除最终 UI 精修与需要真实外部设备/账号才能完成的验收以外，MaterialWord 已经不存在
> 必须继续开发的 P0/P1 核心功能缺陷。核心功能层可以冻结。

依据：第 2 节的 8 项缺陷全部修复并有对应测试；第 4 节本地全量回归、第 5 节三平台 CI
全部通过；第 6 节列出的剩余事项都属于"需要外部凭据/真机/发布流程"，不属于核心代码缺陷。

## 1. 基线与终态

| 项 | 值 |
|---|---|
| 审计基线（外部审计确认的远程 main HEAD） | `22b17ba0f4e549bcc663ede96a91cb9b57ee5ba1` |
| 开始前远程 main HEAD | `22b17ba0f4e549bcc663ede96a91cb9b57ee5ba1`（与基线相同，基线之后没有其他提交） |
| 开始前工作区 | 干净（`git status` 无输出） |
| 本阶段代码 HEAD | `b913fcc81c42954c063253ec384764f850f1c606` |
| 分支 | `main`（未新建分支、未创建 PR） |

基线之后确认**没有**其他 Agent / 用户的提交，因此不存在"推翻他人有效代码"的风险；
Phase 3/4/5 的同步、备份、导入、学习与性能实现均按原样保留，只做定点修复。

## 2. 已确认并修复的问题

审计在基线上逐条复现，再对照最新源码确认仍存在，然后修复。

### 2.1 CONFLICT：一键恢复（P0）

| 编号 | 问题 | 修复 |
|---|---|---|
| 5A-01 | `deletedAt` 恢复方向写反：`discardedValue == null`（词条当时是存活的）却调用 `softDelete`，非空墓碑反而调用 `reviveById` | 方向纠正：`null` → revive，非空 → softDelete；词条与词书共用同一规则 |
| 5A-02 | 恢复逻辑写在 Widget 的 `switch` 里，只覆盖 9 个字段；`source`、`examTags`、`bncRank`、`frqRank`、词书 `sourceType`/`sourceUrl` 会产生冲突记录却无法恢复，界面仍显示"已恢复" | 新增 `SyncConflictResolutionService`，覆盖 `ContentSyncRepository.wordFields` 与 `bookFields` 的**全部**字段；未知字段在写入前明确拒绝 |
| — | 词书冲突**根本没有被记录**：词书合并用的是 `merge()`（丢弃逐字段明细），只累加了一个计数，所以 R08/R09/R10 在真实使用中不会出现可恢复记录 | 词书合并改用 `mergeWithStamps`，与词条一样把 `FieldConflict` 写入 `SyncConflictStore` |
| — | 恢复失败时仍可能移除记录 / 恢复成功后没有新版本 | 记录只在写成功后 dismiss；所有写入走 repository，因此自动获得 `recordEdit` 的字段版本 |
| — | 无变化的重复新增返回了"未写入"的行（`revision + 1` 只存在于内存） | 无变化时返回磁盘上的行 |

界面只保留展示、确认、调用 service、显示结果；不可恢复字段显示为仅诊断（无恢复按钮），
不再出现"显示已恢复但数据库没变"。

### 2.2 前台远端探测（P0/P1）

| 编号 | 问题 | 修复 |
|---|---|---|
| 5B-01 | 前台探测要求 `autoOnForeground`，而 `SettingsRepository.updateSyncAutoOption` 的允许列表与设置页都只写另外 4 个键 → 真实用户路径下 `foreground` 触发永远返回 null，另一台设备的修改只能靠手动同步 | 采用方案 A：前台低频探测是"启用自动同步后的内部可靠性机制"，任一自动同步开关开启即生效；删除幽灵键 `autoOnForeground`，不新增用户设置 |
| 5B-02 | `remoteRevision()` 对"文件不存在"和"无法判断"都返回 `null`，`remoteChanged` 于是把"远端被删除"当成"没有变化"，静默永远返回 false | 新增 `SyncProvider.probeRemote()` → `revision` / `missing` / `unsupported` 三态；`missing` 视为"远端发生了变化"，由受保护的同步路径抛出 `remoteMissing` |
| — | 自动同步发现远端缺失后，页面只在手动同步的 `_error` 里显示"重新创建远端"按钮，自动同步的结果（`last_sync_result`）看不到入口 | 按钮改为同时匹配 `_error` 与 `last_sync_result`，自动发现也能主动重建 |
| — | — | 远端缺失后自动同步不会自动重传整个数据库（`allowRemoteRecreate` 仍只由用户显式动作提供），并进入 5–60 分钟退避 |

### 2.3 指定版本恢复（P0/P1）

| 编号 | 问题 | 修复 |
|---|---|---|
| 5C-01 | 快照恢复清空了词条/事件/词书，但共享设置仍按 Lamport 版本比较：旧快照 `counter=1` 输给当前 `counter=5`，结果是"历史词条 + 当前每日目标" | `mergeValidatedInTransaction` 新增 `forceSharedSettings`，仅由 `restoreSnapshot` 使用：`dailyNewTarget` / `dailyReviewLimit` / `studyMode` / `sprintPlan` **以及共享设置版本**强制取自快照 |
| 5C-02 | `currentWordBookId` 是设备本地选择，快照里没有该词书时会留下悬空引用 | 恢复事务内校验：目标词书仍存在（且未删除）则保留，否则清空；结果通过 `RestoreOutcome.currentBookCleared` 报告 |
| — | `sprintPlan.bookId` 引用缺失 | 按既有产品语义**不**改写计划（冲刺页已明确提示"目标词书不可用，请重新选择；不会自动改成全部词书"），BAK-R04 证明这是安全降级而非崩溃 |
| — | 无法验证"设置与数据一起回滚" | `restoreSnapshot` 增加 `afterMerge` 注入点（在共享设置写入之后），BAK-R05 用它证明整体回滚 |

合并恢复（`restoreMerge`）完全没有改变，仍严格遵循版本规则，BAK-R02 单独钉住这一点，
证明两种恢复语义没有被混淆。

### 2.4 导入的 metadata-only 更新（P1）

| 编号 | 问题 | 修复 |
|---|---|---|
| 5D | `_composeExisting()` 会算出新的 `examTags`/`bncRank`/`frqRank`，但"是否写库"只看文本解析器填充的 `changedFields`，于是本机文本已完整、只有元数据变化的导入被整条丢弃 | 写库判断改为对**整行**做 before/after 语义 diff（`ContentSyncRepository.wordFields` 全部字段 + 本地 `customized`）；`changedFields` 只用于 UI 描述 |

`source` 仍不被导入覆盖（首次来源是事实，不是可覆盖内容），但它在 diff 集合内，
因此任何真实的 `source` 变更都会走 `recordEdit`。

## 3. 新增测试（30 项）

| 文件 | 数量 | 覆盖 |
|---|---:|---|
| `test/phase5_1_conflict_restore_test.dart` | 11 | CONFLICT-R01…R11 |
| `test/phase5_1_foreground_probe_test.dart` | 7 | AUTO-R01…R05（含 R01b/R01c 两条边界） |
| `test/phase5_1_intake_metadata_test.dart` | 6 | INTAKE-R01…R06 |
| `test/phase5_1_snapshot_restore_test.dart` | 6 | BAK-R01…R05（含 R03b） |

要点：

- **冲突恢复**都从**真实合并**产生的冲突出发（两台独立数据库 + 与 GitHub/WebDAV 相同
  条件写入契约的 provider），恢复后再双向同步，断言**数据库内容**与
  `BackupService.contentHashOf` 收敛，而不是只断言返回值。
- CONFLICT-R03/R04 先构造出双方都 >1 的 `deletedAt` 版本（删除→恢复→删除），
  再让一方胜出，确保被测的确实是"恢复方向"而不是"复活语义"；R03 断言恢复后
  `deletedAt` 为 null 且 `revision` 增加，R04 断言恢复后真的写入墓碑且词条从列表消失。
- CONFLICT-R11 断言不可恢复字段 `canRestore == false`、调用被拒绝、**记录未被移除**。
- AUTO-R01 走**真实保存路径**（`setSyncConfig` + `updateSyncAutoOption`），再重建
  Coordinator；AUTO-R01c 断言 `autoOnForeground` 会被设置仓库拒绝（幽灵键不会回来）。
- AUTO-R03/R04 断言远端缺失时 `stage == remoteMissing`、上传次数不变；R05 断言
  用户显式"重新创建远端"后恢复正常，且探测继续工作。
- INTAKE-R05 用第二台设备证明元数据更新产生新的字段版本并能同步过去；
  INTAKE-R06 断言无变化重复新增不会抬高 `revision`/`updatedAt`，也不会生成字段版本。
- BAK-R01 断言共享设置**与版本**都回到快照；BAK-R03 断言 `currentWordBookId` 被清理、
  BAK-R03b 断言仍然存在的选择被保留；BAK-R05 在设置写入之后注入异常，断言词条与
  共享设置（含版本）一起回滚。

原有 Phase 1–5 的 442 项测试全部保留，未删除、未跳过、未放宽断言。

## 4. 本地验证

| 命令 | 结果 |
|---|---|
| `flutter pub get` | 成功 |
| `dart run build_runner build` | 成功，207 outputs；`lib/**/*.g.dart` 无改动（生成代码与源码一致） |
| `dart format --output=none --set-exit-if-changed lib test` | 129 文件，0 需要修改 |
| `flutter analyze` | No issues found |
| `flutter test` | **472 通过、2 跳过、0 失败**（exit 0） |
| `bash tool/verify_timezone_replay.sh` | 香港进程 + 纽约进程各 1 项通过 |
| `git diff --check` | 无输出 |

2 项跳过仍是 `test/macos_packaging_test.dart` 的 macOS 产物检查（本地未构建 macOS），
由 CI 的 `macos` job 在构建后执行。

### 性能（修复不能靠退化换正确性）

同一机器、同一数据集，文件型 SQLite：

| 项 | Phase 5 记录 | Phase 5.1 实测 | 变化 |
|---|---:|---:|---|
| 5 000 词 / 30 000 事件 快照合并 | 3 174 ms | 3 150 ms | 持平 |
| 词条合并阶段（逐词 2 928 ms） | 1.50x | **1.55x**（批量 1 895 ms） | 略优 |
| 20 000 词 / 100 000 事件（`MW_BENCH_FULL=1`） | — | 合并 11 218 ms、备份 3 464 ms、校验 1 948 ms、导出 187 ms | 新增记录 |

`phase5_performance_test.dart` 的逐词 vs 批量**逐字段等价**测试（PERF04）继续通过，
批量身份解析、事件批量写入、状态分块重放全部保留；本阶段没有把任何批量路径退回 N+1。

## 5. GitHub Actions

| 项 | 值 |
|---|---|
| 运行 | [45577997099](https://github.com/Pew2018/materialword/actions/runs/45577997099)（commit `b913fcc`） |
| Validate (analyze + test) | success |
| Android ARM64 APK | success |
| macOS `.app` | success |
| iOS unsigned build | success |

同时确认前一阶段提交已推上 CI 并全绿（run 45576955202，commit `2cc643a`），
本阶段没有通过删除测试、`continue-on-error`、跳过构建或屏蔽 analyzer 换取绿色。

## 6. 剩余事项（分类）

### A. 阻止进入 UI 精修的核心代码缺陷

**无。** 审计未发现新的 P0/P1 数据正确性问题；第 2 节 8 项已全部关闭并有测试保护。

### B. 可以与 UI 精修并行的测试/验收

1. 真实 GitHub 私有仓库 + Fine-grained PAT 的完整矩阵（本阶段只验证 mock、API 契约与
   guard 测试；数据同步目标**未**使用源码仓库 `Pew2018/materialword`）。
2. 真实公网 WebDAV 服务联调（当前只有 loopback HTTPS 的真实协议测试）。
3. Android / iOS / macOS 真机：FilePicker、TTS、屏幕常亮、前后台切换、同步凭据读写。
4. Release 模式性能、包体与真机内存（本阶段数字均为 Debug）。

### C. 最终发布事项

1. Android release 签名（现为 debug keystore，仅可覆盖安装）。
2. iOS 正式签名与描述文件（当前仅 `--no-codesign` 编译验证，不可安装）。
3. macOS 公证与分发、应用图标定稿。

## 7. 与 Phase 5 文档的差异

- README 曾写"前台每 5 分钟做一次廉价的远端版本探测"，但基线代码里该行为依赖一个
  从未被写入的配置键（见 5B-01）。本阶段之后该描述才真正成立。
- `docs/phase5-verification.md` 记录的 442 项测试已变为 472 项；其余数字未变化。
