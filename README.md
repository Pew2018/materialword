# MaterialWord

离线优先的英语单词学习应用（Flutter，经典 Material Design 2 风格）。
目标：**能立刻用来背单词，并且能安全地在 Android / macOS / iOS 之间同步进度**。

- 平台：Android ARM64 / iOS / macOS，一套 Dart 代码（无 WebView、无 Electron）
- 主题：`useMaterial3: false` + `Typography.material2014` + `InkSplash`；12+ 经典强调色 + 自定义 HEX
- 数据：本机 SQLite（Drift v2），词条 / 词书 / 作答历史全部本地
- 词典：内置 ECDICT 精简词库（26,282 词，MIT），按内容哈希更新缓存，字面 `\n` 统一规范化
- 同步：本地文件（原子写入） / GitHub 私有仓库 Contents API / WebDAV ETag，全部走同一合并协议
- 发音：系统 TTS（Android / macOS / iOS），语音不可用时给出提示但不阻断学习

## 当前版本

| 项 | 值 |
| --- | --- |
| 版本 | 1.2.0 (Phase 5 + 5.1 数据收口) |
| Flutter | **3.50.1** stable（Dart 3.14.0） |
| 关键依赖 | drift 2.35.4 / flutter_riverpod 3.5.0 / flutter_tts 4.2.5 / flutter_secure_storage 11.2.0 / http 1.6.0 / crypto 3.0.8 / wakelock_plus 1.8.2 |
| 应用 ID | `com.pew2018.materialword` |
| 数据库 schemaVersion | 3（用户库，Phase 5 未升级）、1（词典库） |
| 备份协议 | schemaVersion 4（备份文件可含设备设置；同步数据集仍为 3；兼容导入 1/2/3） |
| 自动化检查 | 472 项测试通过 / 2 项平台条件跳过；`flutter analyze` 无问题；格式检查通过 |

## 快速开始

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter pub get
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

首次启动 → 首页点「导入词表」载入自己的单词表（TXT 每行一个词即可），
或点「载入示例词书」先用 30 个词体验学习闭环。右上角「＋」或 `⌘N` 快速添加。

原生平台完整构建仅在 GitHub Actions 运行；本机禁止安装 Xcode、Apple SDK、CLT 或新模拟器。

## Phase 5.1：核心数据功能收口（UI 精修前功能冻结）

在进入最终 UI 精修之前，对"新增 / 导入 / 导出 / 备份 / 同步"再做一次正确性收口，
修掉四处"界面说成功、数据没变"的缺陷：

- **冲突一键恢复**：`deletedAt` 的恢复方向原来是反的（丢弃值是"未删除"却执行删除）；
  恢复逻辑只覆盖 9 个文本字段，`examTags` / `bncRank` / `frqRank` / `source` 与词书的
  `sourceType` / `sourceUrl` / `deletedAt` 会被报"已恢复"却没有写库，词书冲突甚至没有被
  记录。现在由 `SyncConflictResolutionService` 统一处理全部可冲突字段，未知字段明确拒绝，
  写入走正常 repository（新的字段版本、下一轮同步传播），失败不移除记录。
- **前台远端探测**：探测曾经依赖一个从未被写入的配置键 `autoOnForeground`，真实用户路径下
  永远不执行；现在它是"启用自动同步后的内部机制"，不再有幽灵配置项。
- **远端删除**：`remoteRevision()` 对"文件不存在"和"无法判断"都返回 null，导致远端被删除
  被当成"没有变化"；现在区分 revision / missing / unsupported，远端缺失会进入
  `remoteMissing`（不自动重传、需用户显式重建）。
- **指定版本恢复**：快照恢复原本仍按版本规则处理共享设置，旧快照会输给当前设置，得到
  "历史词条 + 当前每日目标"的混合状态；现在快照设置与共享版本强制恢复，
  `currentWordBookId` 悬空引用在同一事务内清理。
- **导入元数据**：只有 `examTags` / `bncRank` / `frqRank` 变化的导入曾整条丢失
  （写库判断只看文本字段）；现在按整行 before/after 语义 diff 决定是否写库。

验证与证据见 [Phase 5.1 验证记录](docs/phase5-1-verification.md)。

## Phase 5：核心数据功能闭环

Phase 5 把"新增 / 导入 / 导出 / 备份 / 同步"从多条近似路径收敛成一条可靠链路：

- **统一新增入口**：`WordIntakeService` 成为唯一的"加单词"写入路径（快速添加、批量粘贴、
  文件导入、在线词书、词典页共用）。删除后的词条由用户显式恢复，保留 UUID、aliases、
  笔记与学习记录；普通编辑与重新添加是两种不同语义。新增走单个事务，页面只负责输入与反馈。
- **导入**：建词书与写词条在同一事务内（失败不留空词书）；超过 20 000 条直接拒绝而不是
  静默截断；严格 UTF-8 校验、CSV 引号闭合检查、备份 JSON 误用拦截、流式下载与字节级上限；
  预览显示新增/已有/可恢复/将新增关联/无效行，并重新校验目标词书。
- **导出**：统一字段协议（含 `phrase`、`examTags`、`bncRank`、`frqRank`），版本化词书 JSON
  与历史裸数组兼容，支持多词书导出并保留归属；真实 A→文件→B 往返逐字段比对。
- **备份与灾难恢复**：临时文件 + 回读校验 + 原子替换；自动备份（每天、仅数据变化时、
  保留 5 份）；高风险操作前保护性备份；恢复副本可直接查看/校验/合并恢复/指定版本恢复/
  导出/删除；指定版本恢复用单事务替换并暂停同步，绝不用任一方覆盖另一方。
- **同步**：区分"本机已合并但上传未完成"、远端文件缺失、认证失败、配置变化等状态；
  前台每 5 分钟做一次廉价的远端版本探测（不是全量下载）；字段冲突留痕并可一键恢复被覆盖
  的内容；三台设备 24 个收敛场景全部自动化验证。
- **性能**：词条合并改为批量身份/版本解析（同一数据集批量 1982 ms vs 逐词 2967 ms），
  20000 词 / 100000 事件的完整合并与重放由 6866 ms 降至 5854 ms。

逐项范围与根因见 [Phase 5 审计](docs/phase5-audit.md)，证据见
[Phase 5 验证记录](docs/phase5-verification.md) 与
[验收矩阵](docs/phase5-acceptance-matrix.md)，交付信息见
[Phase 5 交付](docs/phase5-delivery.md)。格式契约见
[词书交换格式](docs/wordbook-exchange-format.md) 与
[备份与灾难恢复](docs/backup-and-recovery.md)。

## Phase 4：可靠性、数据安全与性能收尾

Phase 4 不新增功能面，只让已有功能更可靠：

- **练习模式（重点整改）**：独立的公平覆盖调度（连续多轮逐步走遍词书，困难词保留
  但有上限的优先级）；挖空题按资格分页查找，不再因固定候选窗口误报"没有题目"；
  显式答题状态机（加载/作答/提交/反馈/完成），反馈期间题目身份不变、游标不动、
  最后一题同样展示反馈；本轮练习可跨进程恢复且不重复写入；提交前校验词条是否被删除、
  移出词书或改写；选择题干扰项按完整释义分段排除同义/多义冲突。
- **数据可靠性**：诊断报告改为结构化脱敏，截断后仍是合法 JSON，构建 Commit SHA 只在
  构建元数据白名单下保留；CSV 导出中和电子表格公式注入；诊断日志可落盘、轮转、清除。
- **性能**：完整合并与重放（20000 词 / 100000 事件）同机同测试由 13759 ms 降至
  6866 ms（−50.1%），事件合并改为批量插入、状态重放改为分块读取，批量与逐词重放
  结果逐字段一致。
- **原生能力**：学习/练习期间屏幕常亮（默认关闭、设备本地、离开页面即释放、不支持
  平台明确降级）。

逐项范围与根因见 [Phase 4 审计](docs/phase4-audit.md)，实际证据见
[Phase 4 验证记录](docs/phase4-verification.md) 与
[验收矩阵](docs/phase4-acceptance-matrix.md)，交付信息见
[Phase 4 交付](docs/phase4-delivery.md)。

## Phase 3 历史实现

已加入稳定分页、明确范围的批量选择、取消无副作用、管理事件与真实答题分离、会话恢复与撤销、本轮真实总结和错词复练、独立考前冲刺、共享设置版本、事务快照、字段级合并与重命名身份、收藏和多标签、因果事件顺序、学习中编辑和语音刷新、持久化自动同步与配置并发保护、WebDAV 强 ETag/条件读取及经典 Material 交互整改。

逐项范围见 [任务审计](docs/phase3-audit.md)，实际证据见 [验证记录](docs/phase3-verification.md)。

## Phase 2 历史实现

### 交互与数据正确性
- 底栏改为项目内 InkSplash + 独立 hover / focus / pressed / selected 反馈，选中时尺寸位置不变
- 首次访问页面才挂载，切换标签保留搜索与滚动状态
- 滑块拖动期间不写 SQLite，松手提交；设置改字段级 UPDATE，并发保存不互相覆盖
- 词典文本统一规范化；查询带代际，旧结果不会覆盖新词
- 剩余新词 = `min(剩余额度, 真实未学数)`；空词库显示 0；删除词不计入统计
- 启动 / 恢复前台 / 跨日刷新任务数据；无作答时正确率显示"—"

### 词汇管理与学习
- 全局「词汇管理」：筛选、排序、搜索、多选、批量加入/移出/删除、历史、错误率、下次复习
- 手动「标记掌握」/「重置进度」写成可同步事件，不直接篡改派生状态
- 快速添加按字段区分自动填充与用户编辑；批量粘贴预览；在线词书主动刷新只新增
- 学习页中文释义优先、英文释义折叠、释义内容可滚动、作答区固定
- 困难词 / 近期错误 / 词书内专项复习，仍记录全部作答事件
- 系统 TTS：语音选择、语速、可选自动发音

### 同步
- schemaVersion 2 无损迁移；词条 ID 映射；关联删除墓碑；事务内状态重建
- 统一同步协调器：互斥、条件上传、冲突重试、内容哈希（无变化不上传）
- GitHub 私有仓库（Fine-grained PAT + blob SHA）、WebDAV（HTTPS + ETag）、本地文件
- 凭据只存系统安全存储；同步页可测试连接、查看结果与本地待同步状态

## 目录结构

```
lib/
  app/                     导航壳、主题系统、Riverpod providers
  core/database/           Drift 表、schema v3 迁移、行映射
  core/text/               词典文本规范化
  core/repositories/       词条 / 词书 / 学习 / 冲刺 / 内容版本 / 设置
  features/                dashboard / study / dictionary / settings / statistics /
                           word_management / wordbooks / sync / backup
  services/                调度、学习会话、练习会话、词典、统一新增、导入、导出、
                           备份管理器、TTS、常亮、诊断、同步
  shared/widgets/          经典 Material 2 列表与通用控件
assets/dictionary/          ECDICT SQLite + 内容哈希元数据 + MIT 许可证
test/                      472 项测试（Phase 1–5 回归 + 5.1 收口 + 性能基准 + golden）
```

## 文档

- [架构](docs/architecture.md) · [同步协议](docs/sync-protocol.md) · [学习算法](docs/study-scheduler.md)
- [构建指南](docs/build-guide.md) · [路线图](docs/roadmap.md)
- Phase 5.1：[验证记录](docs/phase5-1-verification.md)（数据功能收口）
- Phase 5：[审计](docs/phase5-audit.md) · [验证](docs/phase5-verification.md) · [验收矩阵](docs/phase5-acceptance-matrix.md) · [交付](docs/phase5-delivery.md) · [词书交换格式](docs/wordbook-exchange-format.md) · [备份与恢复](docs/backup-and-recovery.md)
- Phase 4：[审计](docs/phase4-audit.md) · [验证](docs/phase4-verification.md) · [验收矩阵](docs/phase4-acceptance-matrix.md) · [交付](docs/phase4-delivery.md)

## 已知限制

- 本机没有完整 Xcode / CocoaPods，macOS 与 iOS 构建验证由 GitHub Actions 完成；
  Android Gradle 依赖下载在本机遇到 Maven 503，同样交由 CI 产出。
- iOS 仅 `--no-codesign` 编译验证，**不可安装**。
- Android release 仍使用 debug keystore，签名身份与上一阶段一致，旧用户可覆盖安装。
- WebDAV 服务器若不返回 ETag，会被明确标注为"无法安全检测并发修改"，自动同步受限。
- GitHub / WebDAV 的协议测试使用 Mock HTTP 与 loopback HTTPS；**未连接真实服务**，
  真实账号联调仍需用户提供测试配置。
- 真机动画、TTS 语音、屏幕常亮与窗口缩放的人工验收尚未完成；Widget 测试与编译成功
  不等同于真机验收。
- 屏幕常亮依赖 `wakelock_plus`（会带入 `package_info_plus`），三平台行为只在 CI 编译
  层面验证，未做真机确认。
- 大数据性能数字为 Debug + 内存/文件 SQLite，不是 Release 真机基准。
- 空间与时间限制：单次导入上限 20 000 条、单文件 8 MB；超限直接拒绝，需要用户拆分文件。
- 指定版本恢复期间持有单个写事务；20 万级事件时会阻塞其他写入数秒。
- CSV 为"安全但不逐字无损"（危险前缀加前导单引号）；逐字往返请使用 JSON。
