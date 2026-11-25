# Phase 4 交付报告

## 1. 最终 HEAD

| 项 | 值 |
|---|---|
| 源码提交 | `a7364823f288317dcd168e91074ed5300bc0d75c` |
| 分支 | `main` |
| 提交标题 | `feat(phase4): reliable practice drills, safer data paths and a 2x faster merge` |
| 构建来源 SHA | `a7364823f288317dcd168e91074ed5300bc0d75c`（与本文件所在提交的源码部分完全一致） |
| 版本 | 1.2.0+3 |
| 数据库 Schema | 3（**本阶段未升级**） |
| 备份协议 | 3 |

Phase 4 未引入任何数据库 Schema 变更。练习会话的持久化复用 `app_meta`
（键 `active_practice_session_v1`），屏幕常亮偏好同样存于 `app_meta`
（键 `keep_screen_on`）。因此不需要 Schema 4，也不需要新的迁移与回滚测试。

## 2. Actions Run

- 运行：<https://github.com/Pew2018/materialword/actions/runs/45556847283>
- 触发提交：`a736482`，创建于 2026-11-25T05:54:57Z，结束于 05:59:58Z
- 结论：**success**

| Job | 结果 |
|---|---|
| Validate (analyze + test) | ✅ success |
| Android ARM64 APK | ✅ success |
| macOS .app | ✅ success |
| iOS unsigned build | ✅ success |

## 3. 三平台产物

| 产物 | Artifact | 大小 | 下载 |
|---|---|---:|---|
| Android ARM64 APK | `android-arm64-apk` | 13,817,016 B | <https://api.github.com/repos/Pew2018/materialword/actions/artifacts/14996351618/zip> |
| macOS `.app` ZIP | `macos-app` | 26,045,341 B | <https://api.github.com/repos/Pew2018/materialword/actions/artifacts/14994984983/zip> |
| iOS 无签名 `Runner.app` ZIP | `ios-unsigned` | 12,668,477 B | <https://api.github.com/repos/Pew2018/materialword/actions/artifacts/14995728188/zip> |

文件名：`MaterialWord-a736482-android-arm64.apk`、`MaterialWord-a736482-macos.zip`、
ios-unsigned 内的 `Runner.app`。产物保留 14 天。

### 构建验证细节（来自 CI 日志）

- **Android**：APK 内仅含 `lib/arm64-v8a/libflutter.so`，无 v7a/x86_64 引擎；
  `aapt dump badging` 确认 `com.pew2018.materialword`；`apksigner verify` 通过。
  签名仍为临时 debug keystore，与上一阶段一致（本阶段明确不整改正式签名）。
- **macOS**：Mach-O 架构 `x86_64 arm64`（universal）；签名 `adhoc`；
  bundle 结构/权限/符号链接、ZIP 解压后签名与结构、MAC02/MAC03 构建产物回归
  全部 PASS；**真实启动验证 `launch-verification: executed-pass`**。
- **iOS**：`flutter build ios --release --no-codesign` 成功产出 `Runner.app`（29.4 MB）。
  无签名，**不可安装**。

## 4. 完成的任务

| 阶段 | 内容 |
|---|---|
| 4A | 重新核验远程 HEAD（与任务书基线一致）、工作区干净、286 项基线通过；建立三份 Phase 4 文档 |
| 4B | 练习公平覆盖、挖空分页资格、答题状态机、会话持久化、过期题目保护、干扰项质量、TTS 时序、完整回归 |
| 4C | 同步闭环复核、练习事件的合并/撤销/重放验证、重复导入幂等、单数据集重复 ID 拒绝 |
| 4D | 分段计时定位、事件批量写入、状态分块重放、同机前后对比、批量与逐词重放等价性 |
| 4E | 屏幕常亮（设备本地、生命周期释放、平台降级） |
| 4F | 诊断结构化脱敏与合法 JSON 截断、Commit SHA 白名单保留、诊断日志落盘轮转、CSV 公式注入、README 更新 |
| 4G | 全量回归、格式、analyze、跨时区重放、REG-01…REG-21 矩阵 |
| 4H | 提交、推送、持续跟进 Actions 至四 job 全绿、交付报告 |

## 5. 修复的具体缺陷及根因

| 编号 | 缺陷 | 根因 |
|---|---|---|
| D-01 | 连续多轮练习总是同一批词 | `practiceBatch` 按 `last_studied_at DESC` 取前 N；练习作答本身会刷新该字段，刚练过的词立刻回到队首，没有任何跨轮覆盖记录 |
| D-02 | 词书有例句却提示"没有可练习的单词" | 先取固定窗口 `max(limit*6,60)` 再过滤例句；窗口内的词都没有例句时不会继续向后找 |
| D-03 | 听写提前播下一题、最后一题无反馈、反馈期跳过错位、重复提交 | `_record()` 保存后立即 `_cursor++`，页面另存 `_answeredQuestion` 显示反馈，两套状态并行；`isFinished` 与 `skip()` 都读这个已推进的游标 |
| D-04 | 进程被杀后本轮练习丢失 | 题目/游标/统计只在内存，未复用 `StudySession` 已有的 `app_meta` 持久化 |
| D-05 | 词条被改/删/移出词书后仍按旧内容判分 | 提交前不做任何身份与内容校验 |
| D-06 | 选择题出现两个都成立的选项 | 干扰项只比较"第一段释义"是否相等，多义词与同义词漏过 |
| D-07 | 诊断报告截断后不是 JSON，且 Commit SHA 被误删 | 先 `jsonEncode` 再按字符截断，然后对整段文本跑正则脱敏（`[A-Za-z0-9_-]{32,}` 命中 40 位 SHA） |
| D-08 | CSV 可被电子表格当作公式执行 | 只做 RFC 4180 引号转义，未处理 `=` `+` `-` `@` `Tab` `CR` 开头 |
| D-09 | 崩溃日志随进程消失 | `DiagnosticsService` 纯内存缓冲 |
| D-10 | 学习时屏幕会自动熄灭 | 无常亮能力 |
| D-11 | 合并/重放 14 秒，原因不明 | 无分段计时；事件逐条 `SELECT` + 逐条 `INSERT`，重放逐词独立查询 |

另修正一处测试断言：`phase3_practice_test` 中"提交后 `position == 1`"编码的正是 D-03
的错误行为，已改为断言新契约（提交后仍停在同一题的反馈态、`advance()` 后才前移），
并补充了对应说明。

## 6. 关键文件与代码变更

| 文件 | 变更 |
|---|---|
| `lib/services/practice_session.dart` | 新增 `PracticePhase` 状态机；游标仅在 `advance()` 前移；`app_meta` 持久化与恢复（含内容签名校验）；提交前 `_staleReason()`；`meaningSegments()` 全释义分段去重；串行化磁盘写入 `_writeChain`/`flush()` |
| `lib/core/repositories/study_repository.dart` | `practiceBatch()` 重写为"优先级 60% + 覆盖 40%"双序合并；`_practiceCandidates()` 分页资格查找；`_practicePool()` 双窗口干扰池；`rebuildStateFromEvents` 抽出纯函数 `_replay()` 并新增 `rebuildStatesForWords()` |
| `lib/features/study/practice_page.dart` | 完全按 `session.phase` 渲染；反馈期间题目身份取自 session；发音代际保护；`WidgetsBindingObserver` 后台停止发音并释放常亮；最后一题按钮改为"查看本组结果" |
| `lib/services/backup_service.dart` | 事件合并改为一次读 ID 集合 + 批量插入；重放改批量入口；新增 `onPhase` 计时钩子 |
| `lib/services/diagnostics_service.dart` | `redact(keep:)`、`redactStructured()`、`_encodeWithinBudget()`（丢整行保持 JSON 合法）、`attachFile()/flushToDisk()/轮转/恢复`、`_quotedSecret` |
| `lib/services/wordbook_export.dart` | `sanitizeCsvCell()` 公式前缀中和 |
| `lib/services/screen_awake.dart`（新） | 常亮服务，可注入 setter，平台能力判断与降级 |
| `lib/features/study/study_page.dart`、`practice_page.dart` | 接入常亮与生命周期释放/恢复 |
| `lib/app/providers.dart`、`features/settings/settings_page.dart` | `screenAwakeProvider`、`keepScreenOnProvider`、设置开关 |
| `lib/main.dart`、`lib/app/navigation.dart` | 诊断日志落盘接入；进入后台时刷盘 |
| `macos/Flutter/GeneratedPluginRegistrant.swift`、`pubspec.yaml/lock` | 新增 `wakelock_plus 1.8.2`（传递引入 `package_info_plus`） |

## 7. 测试

| 项 | 数量 |
|---|---|
| 改动前基线 | 286 通过 / 2 跳过 |
| 改动后 | **341 通过 / 2 跳过 / 0 失败** |
| 新增 | 55 项（`phase4_practice_test` 20、`phase4_security_test` 18、`phase4_native_test` 7、`phase4_performance_test` 5、`phase3_practice_test` +5） |
| 保留 | 原有 286 项全部保留，仅修正 1 条编码了旧缺陷的断言并说明原因 |
| 平台条件跳过 | 2 项 macOS 打包测试，在 CI `macos` job 中实际执行并通过（MAC02/MAC03） |

本地与 CI 均为同一数字：`+341 ~2: All tests passed`。跨时区重放脚本两个进程各 1 项通过。

## 8. 性能对比

同机、同测试（`test/phase3_performance_test.dart`）、同数据集、独立运行，
Debug + 内存 SQLite，20000 词 / 100001 事件：

| 指标 | 改动前 | 改动后 | 变化 |
|---|---:|---:|---|
| 完整合并与重放 | 13759.0 ms | 6866.4 ms | **−50.1%** |
| 一致性快照 | 664.5 ms | 630.0 ms | 持平 |
| 统计 | 330.1 ms | 331.3 ms | 持平 |
| JSON 解码+校验 | 1176.0 ms | 1156.0 ms | 持平 |
| 单次作答 | 12.5 ms | 13.4 ms | 噪声内 |
| 分页 / 搜索 / 队列 | 4.1 / 9.5 / 7.5 ms | 4.1 / 10.0 / 7.1 ms | 噪声内 |
| 备份大小 | 39,140,963 B | 39,140,963 B | 不变 |

优化后分段（同一测试的 `onPhase` 输出）：校验 1003 ms、词条合并 2967 ms、
事件合并 1460 ms、状态重放 1532 ms、其余 <2 ms。

**这不是 Release 或真机基准**，只能用于本机前后对比。

## 9. 数据库与同步兼容性

- Schema 仍为 3，无迁移；旧库直接可用。
- 备份协议仍为 3；`practice-*` 事件模式在 Phase 3 已纳入校验白名单，本阶段新增的
  练习事件沿用同一模式，合并/重放/撤销路径不变。
- 新增的 `app_meta` 键（`active_practice_session_v1`、`keep_screen_on`）**不进入同步**：
  练习存档是本机临时状态，常亮是设备偏好。
- 合并语义未变：事务边界、事件因果顺序、撤销语义、字段级冲突规则、删除墓碑、
  内容哈希收敛规则全部保持；批量重放与逐词重放写出的状态行逐字段一致（已测）。

## 10. 实际执行的验证

- 本地：`flutter pub get`、`dart run build_runner build`、
  `dart format --output=none --set-exit-if-changed lib test`（114 文件，0 改动）、
  `flutter analyze`（无问题）、`flutter test`（341/2/0）、
  `tool/verify_timezone_replay.sh`、`git diff --check`。
- CI：`Validate`（格式 + analyze + 341 测试 + golden + 跨时区重放）、
  Android ARM64 APK（含 ABI/包名/签名校验）、macOS `.app`（universal + 签名 +
  ZIP 往返 + MAC02/MAC03 + 真实启动 `executed-pass`）、iOS 无签名构建。

## 11. 尚未验证的真实服务与真机功能

明确**未执行**，且不得表述为已通过：

1. 三平台真机交互、发音、常亮、前后台切换的人工验收。
2. 真实 GitHub 私有仓库 + 真实 PAT 的完整同步矩阵（CI 只做协议与守卫测试）。
3. 真实 WebDAV 服务（仅有 loopback HTTPS 协议测试）。
4. Release 模式、文件型 SQLite 大库的性能数据。
5. iOS/macOS 的正式签名、公证与分发（本阶段明确排除）。
6. Android 正式签名与固定 Keystore（本阶段明确排除）。

## 12. 外部阻塞与剩余风险

| 项 | 说明 |
|---|---|
| 无 Xcode / Apple SDK / 模拟器 | 本机不能编译 macOS/iOS；平台验证完全依赖 GitHub Actions，问题反馈周期约 2–3 分钟/次 |
| 无真实同步服务凭据 | 无法执行真实 GitHub / WebDAV 联调，只能做可控协议测试 |
| `wakelock_plus` 新增依赖 | 传递引入 `package_info_plus`；三平台仅编译验证，未真机确认常亮行为 |
| 词条合并阶段仍慢 | 约 2967 ms，已定位为每词 3–5 次单行查询（`resolve`×2、`byNormalized`、`remember`×2），本阶段未实施以免在交付末期引入同步正确性风险 |
| 诊断日志上限 | 文件 256 KiB + 1 份轮转、内存 400 行 / 24 h；极端情况下仍可能丢失最老记录（设计如此） |

## 13. 后续最终 UI 精修阶段的建议

1. 先做真机基线：在三平台各录一次「学习 → 练习 → 冲刺 → 同步」全流程，标出实际卡顿
   与动画瑕疵，再改视觉；避免用 Widget 测试代替真机判断。
2. 练习模式的反馈动效与发音时序需要真机确认后再定；当前状态机已把时序约束写进代码，
   视觉层不应绕过 `PracticePhase`。
3. 屏幕常亮设置目前位于「学习」分区，UI 精修时可与其他学习偏好合并成一组，但不要把它
   移入同步字段。
4. 若继续做性能：优先处理 `words` 段的 N+1（别名缓存 + 批量 `remember`），再做
   Release 模式与文件型 SQLite 基准；任何优化都必须保留"批量 == 逐词"的等价性测试。
5. 诊断报告已是合法 JSON，UI 精修时可考虑在导出前展示一个可折叠的摘要，但不要改变
   脱敏层次（结构化脱敏 + 白名单保留构建 SHA）。
