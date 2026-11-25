# Phase 4 审计与任务清单

本文件记录 Phase 4 的源码级审计结论。所有结论均以交叉核验源码为准，不采信文档自述。

## 4A-01 基线

| 项目 | 实测值 |
|---|---|
| 远程 main HEAD | `764efac557d25e7366f5d8e728e95072b979a36d` |
| 本地工作区 | main，与 `origin/main` 一致，工作树干净（`git status` 无输出） |
| HEAD 提交时间 | 2026-11-25 12:44:26 +0800 |
| 最近成功构建源码 | `24faea96feda8a6f19f722505731715a18920882`（CI run 45547631573） |
| 版本 | 1.2.0+3（`pubspec.yaml`） |
| 数据库 Schema | 3（`AppDatabase.currentSchemaVersion`） |
| Flutter / Dart | 3.50.1 stable / 3.14.0 |
| lib Dart 文件 | 58 |
| test Dart 文件 | 51 |

审计起点与任务书给出的 HEAD 完全一致，说明期间没有其他 Agent 的后续提交。此后每次提交前重新核验。

### 与文档的差异

- `docs/phase3-verification.md` 记录的测试数为 162，实测为 **286 通过、2 跳过**。Phase 3 之后新增了大量测试而未回写该文档，属于文档滞后，不是测试缺失。
- `README.md` 的测试数与版本信息同样滞后，将在 4F-05 统一更新。

## 4A-02 回归基线

在 `flutter pub get` / `dart run build_runner build` 之后执行：

| 命令 | 结果 |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 109 个文件，0 个需要修改 |
| `flutter analyze` | No issues found |
| `flutter test --reporter expanded` | **286 通过、2 跳过、0 失败**（exit 0） |
| `tool/verify_timezone_replay.sh` | 香港进程 + 纽约进程各 1 项通过 |
| `git diff --check` | 无问题 |

2 项跳过的原因（`test/macos_packaging_test.dart`）：

- `未构建 macOS 产物（CI 的 macos job 会先构建再执行本测试）`
- `未构建 macOS 产物，跳过 ZIP 复验`

这两项是平台条件跳过，在 CI 的 `macos` job 中实际执行，本地不计入通过。

基线日志：`work/p4-baseline-test.log`（本地临时产物，不提交）。

## 4A-03 已确认的缺陷与根因

### D-01 练习题目覆盖不公平（4B-01）

`StudyRepository.practiceBatch()` 的排序为
`last_studied_at DESC → (wrong*2 + hazy) DESC → normalized`，再 `LIMIT max(limit*6, 60)` 取前 `limit` 个。

根因：练习作答本身会刷新 `learning_states.last_studied_at`（`recordAnswer` 在 practice 模式下仍更新该字段），于是刚练过的词立刻回到队首。缺少任何「本轮/跨轮已覆盖」的状态，20 个词的窗口被同一批词长期占用。冲刺模式已有 80/20 优先级+覆盖的做法（`rankSprintCandidates`），练习模式没有复用这一思想。

### D-02 挖空题候选池截断（4B-02）

`practiceBatch()` 先取 `max(limit*6, 60)` 个候选，**之后**才用 `clozeSentenceFor()` 过滤例句。若前 120 个词恰好都没有可用例句，即使词书后面有大量合法题目，界面也会显示「没有可练习的单词」。这是排序窗口与资格判断顺序颠倒导致的截断。

### D-03 答题状态机错误（4B-03）

`PracticeSession._record()` 在写完事件后立即 `_cursor++`，而 `PracticePage` 用 `_answeredQuestion` 保留旧题显示反馈，两套状态并行。

由此产生：

- `_onChanged()` 以 `'${word.id}:${position}'` 判定换题，`_cursor` 已变，于是每次作答都会触发一次「换题」副作用，包括听写自动发音和焦点请求——听写提交后立即播报下一题的发音。
- `isFinished` 在 `_cursor >= length` 时立即为真，最后一题提交的瞬间界面直接跳到总结，反馈从未显示。
- 反馈状态下 `skip()` 仍然可用（只判断 `current != null && !_busy`），跳过的是**下一题**且 `_skipped++` 记账错位。
- `_answeredWordIds` 以 `'${wordId}#$_cursor'` 作键，撤销时用 `'${previous['wordId']}#$_cursor'`（此时 `_cursor` 已被赋回旧值）移除，键不一致，撤销后的同一题可能被再次计入保护集合的残留项。

### D-04 练习会话无持久化（4B-04）

`PracticeSession` 的题目、游标、统计全部只在内存。`StudySession` 已有 `app_meta` 键 `active_study_session_v1` 的持久化+恢复机制（含队列校验、事件计数比对、删除/移出词书过滤），练习会话完全没有复用。进程回收即丢失本轮。

### D-05 过期题目无保护（4B-05）

`StudySession` 有 stale 保护（`observedAnswerAt`、`_eventCounts` 比对），`PracticeSession` 在提交前不校验词条是否仍存在、是否仍在目标词书、内容是否已被修改或同步覆盖，直接按加载时的 `answer` 判分。

### D-06 选择题干扰项质量（4B-06）

`_optionsFor()` 只用 `_normalizeMeaning()`（取第一段释义）做相等性排除，多义词和有重合释义的同义词会同时成为选项，出现两个都成立的答案。

### D-07 诊断报告截断破坏 JSON 且误删 Commit SHA（4F-02）

`buildReport()` 先 `jsonEncode` 再 `substring(0, 64KiB)`，截断后的文本不再是合法 JSON。随后 `redact()` 在整个文本上再跑一遍，`_longOpaque`（`[A-Za-z0-9_-]{32,}`）会把 40 位 Git Commit SHA 一并替换为 `<redacted>`，破坏构建版本溯源。

### D-08 CSV 公式注入（4F-03）

`_csvField()` 只做 RFC 4180 引号转义，未处理以 `=`、`+`、`-`、`@`、Tab、CR 开头的字段。外部导入的词条释义/笔记被 Excel/Numbers 打开时会被当作公式执行。

### D-09 诊断日志无持久化（4F-01）

`DiagnosticsService` 的 `_entries` 是纯内存列表，进程退出即丢。用户复现故障后重启应用导出报告，里面只有重启后的记录。

### D-10 屏幕常亮未实现（4E-01）

`pubspec.yaml` 无 `wakelock` 类依赖，`study_page.dart` / `practice_page.dart` 无任何常亮调用。Phase 3 审计已标注「上滑/常亮/随机设置待实施」。

### D-11 性能瓶颈未分段定位（4D-02）

`phase3_performance_test.dart` 只测总耗时（完整合并与重放 ~10–14 s），没有分段计时，无法判断成本在解析、映射、字段合并、逐条写入还是重放。

## 证据等级约定

后续 `docs/phase4-verification.md` 与 `docs/phase4-acceptance-matrix.md` 严格区分：

- **源码**：代码已实现并可指认位置。
- **自动**：`flutter test` / 脚本实际执行通过。
- **构建**：CI 或本地实际产出三平台产物。
- **真机**：真实设备上人工确认。
- **真实服务**：真实 GitHub 私有仓库 / 真实 WebDAV 服务联调。

只有**自动**、**构建**、**真机**、**真实服务**可以标记为「通过」；源码实现本身不构成验证。
