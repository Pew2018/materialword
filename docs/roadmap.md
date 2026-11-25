# Roadmap

## Phase 1（已完成）

- [x] Android / iOS / macOS 三平台，同一套 Dart 代码
- [x] 经典 Material Design 2 主题（`useMaterial3: false` + `InkSplash`）
- [x] Drift / SQLite 用户库，离线 ECDICT 词典（26,282 词，MIT）
- [x] 词书、快速添加、TXT / CSV / JSON / HTTPS 导入
- [x] 学习闭环、五级间隔重复、每日目标、统计、备份合并
- [x] 34 个自动化测试与四个 GitHub Actions job

## Phase 2（历史实现，已知缺陷见 Phase 3 审计）

### 2A 核心交互、数据正确性与 UI 整改
- [x] 自定义 `ClassicBottomNavigationBar`：等宽、固定尺寸、项目内 InkSplash、独立的
      hover / focus / pressed / selected 状态；无 M3 药丸背景、无全局禁用 Ripple
- [x] `IndexedStack` 保留页面搜索/滚动状态，未访问页面不挂载、不触发数据库查询
- [x] `SettingsRepository` 改为字段级 UPDATE；滑块用 draft 值，`onChangeEnd` 才写库
- [x] 统一词典文本规范化；词典缓存改用内容哈希；快速添加与词典页加入查询代际
- [x] `TodayProgress` 区分目标、额度、真实未学数、到期数与积压；空词库不再显示"剩余 30"
- [x] 启动、恢复前台、跨日刷新；历史正确率无记录时显示"—"

### 2B 词汇管理、词典与学习体验
- [x] 全局词汇管理页：词书/状态/困难筛选、排序、搜索、多选、批量加入/移出/删除
- [x] 学习历史、错误率、下次复习；手动标记掌握与重置进度写成可同步事件
- [x] 快速添加自动匹配、按字段区分自动填充与用户编辑、批量粘贴预览
- [x] 在线词书来源 URL 与主动刷新（只新增，不覆盖笔记和进度）
- [x] 学习页重构：单词主体、中文优先、英文释义折叠、固定作答区
- [x] 系统 TTS（`flutter_tts`）：语音选择、语速、自动发音、失败降级
- [x] 12+ 经典强调色 + 自定义 HEX + 即时切换；明暗主题均生效
- [x] macOS 宽/窄窗口侧栏、移动底栏、大屏双栏；移动端隐藏快捷键提示
- [x] 困难词 / 近期错误 / 词书内专项复习，作答仍记录事件并计入复习额度

### 2C 同步
- [x] schemaVersion 1 → 2 无损迁移（墓碑、版本、主题与 TTS 列）
- [x] 词条身份映射、删除同步、事务内状态重建、稳定冲突规则
- [x] 统一 `SyncCoordinator`（互斥、条件上传、冲突重试、内容哈希、脱敏）
- [x] 本地文件（哈希版本 + 原子替换 + `.bak`）、GitHub Contents API、WebDAV 正式实现
- [x] 独立数据同步页面；凭据只存系统安全存储
- [x] SYNC01–SYNC15 全部以内存库/Mock HTTP 覆盖

### 2D 测试与交付
- [x] 保留原 34 项测试；新增 UI01–UI09、DATA01–DATA08、SYNC01–SYNC15，共 102 项通过
- [x] `flutter analyze` 通过；`dart format` 已应用
- [x] Android ARM64、macOS、iOS 构建由 GitHub Actions 执行（本机无 Xcode / Gradle 依赖下载受限）

## Phase 5.1（核心数据功能收口 → 功能冻结）

证据见 [phase5-1-verification.md](phase5-1-verification.md)。只对实际测试项标记通过。

- [x] 冲突"一键恢复"修复：`deletedAt` 恢复方向、可恢复字段覆盖到全部
      `wordFields`/`bookFields`、词书冲突真正写入冲突日志、失败不 dismiss；
      CONFLICT-R01…R11。
- [x] 前台远端探测真正接通真实配置（删除幽灵键 `autoOnForeground`）；
      远端删除区分 `missing` 与"无法判断"，进入 `remoteMissing` 且不自动重传；
      AUTO-R01…R05。
- [x] 指定版本恢复强制恢复共享设置与版本；`currentWordBookId` 悬空清理；
      `sprintPlan.bookId` 按既有语义安全降级；恢复中途失败时设置与数据一起回滚；
      BAK-R01…R05。
- [x] `WordIntakeService` 按整行语义 diff 决定写库，metadata-only 导入不再丢失；
      INTAKE-R01…R06。
- [x] 本地 472 项测试通过、2 项平台跳过；`flutter analyze` / 格式 / 时区重放 /
      `git diff --check` 全部通过；Phase 5 性能基准无回退（批量合并 1.55x）。
- [x] GitHub Actions run 45577997099：Validate、Android ARM64 APK、macOS `.app`、
      iOS unsigned build 全部 success。
- [ ] 最终 UI 精修（下一阶段，功能层已冻结）。
- [ ] 真实 GitHub PAT / 真实 WebDAV / 三平台真机验收；发布签名与公证。

## Phase 5（已完成核心数据功能）

范围与证据见 [phase5-audit.md](phase5-audit.md)、[phase5-verification.md](phase5-verification.md)
与 [phase5-acceptance-matrix.md](phase5-acceptance-matrix.md)。只对实际测试项标记通过。

- [x] 统一新增/重新新增/批量新增入口（`WordIntakeService`），删除后可显式恢复，
      保留 UUID、aliases、笔记与学习记录；ADD01–ADD14。
- [x] 导入事务边界、超限拒绝（20 000）、严格编码校验、流式下载与字节上限、预览统计、
      在线刷新差异预览与不复活已删词条；IMP01–IMP19。
- [x] 词书字段协议统一（`phrase`/`examTags`/`bncRank`/`frqRank`）、版本化 JSON、
      多词书导出与真实往返；EXP01–EXP12。
- [x] 原子备份、自动备份、保护性备份、内部副本直接恢复、指定版本恢复与恢复后同步隔离；
      BAK01–BAK21。
- [x] 同步状态区分、前台远端探测、GitHub 远端缺失策略、冲突留痕与恢复、三设备收敛；
      SYNC01–SYNC24。
- [x] 词条合并批量身份解析（等价性测试）、导入导出开销、文件型 SQLite 基准；PERF01–PERF06。
- [ ] 最终 UI 精修（下一阶段）：视觉细节、动效、真机交互打磨。
- [ ] 真实 GitHub / WebDAV 账号联调与三平台真机人工验收（需外部凭据与设备）。

## Phase 3（历史，部分项在 Phase 4/5 完成）

全部 3A–3I 范围由 [phase3-audit.md](phase3-audit.md) 跟踪；只对实际测试项标记通过。

- [x] 数据正确性第一批整改：分页、取消、搜索代际、批量事务、人工掌握语义。
- [x] 同步第一批整改：ETag 格式/XML/origin/条件 GET、共享计划版本、事务快照、逻辑哈希。
- [x] 会话持久化与最近答题撤销核心及 UI。
- [x] MD2 转场、圆角 Ripple、颜色动画、父约束双栏、短侧栏滚动与断点状态回归。
- [x] 162 项本地测试通过，2 项平台条件跳过；浅深色 Golden 和 20k 词/100k 事件合成性能实测。
- [x] WebDAV 临时资源条件写入能力探测、本机真实 HTTPS 服务、作答上传并发；事件作者锚点和跨时区进程验证。
- [ ] 其余并发/字段级身份冲突矩阵、真实用户服务验收。
- [ ] 收藏/标签、词书导出与来源差异预览、词形/最近搜索。
- [ ] 冲刺、错词复练总结、拼写/听写/选择/合法例句练习。
- [ ] 设置分组二级页面、全面控件/文案审计、发音刷新与后台行为、常亮。
- [ ] 完整统计、脱敏诊断、原创应用图标、完整迁移/性能矩阵。
- [ ] 最终集中推送、三平台 CI 构建及产物/签名/启动验收。
