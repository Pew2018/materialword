# Phase 4 验收矩阵

每一项都关联实际源码与测试文件。**只有实际执行过的验证才标记为通过**；
`源码` 只表示实现存在，`—` 表示本轮未执行。

图例：`✅ 自动` 已由 `flutter test` 实际通过；`⏭ 条件跳过` 平台条件不满足；
`📱 真机` 真实设备人工确认；`🌐 真实服务` 真实远端联调；`—` 未执行。

| 编号 | 验收范围 | 源码位置 | 验证 | 状态 |
|---|---|---|---|---|
| REG-01 | 普通学习与间隔重复算法 | `lib/services/study_scheduler.dart` | `study_scheduler_test.dart`、`data_correctness_test.dart` | ✅ 自动 |
| REG-02 | 学习阶段及每日额度 | `lib/services/study_session.dart`、`study_repository.dart` | `study_flow_test.dart`、`phase3_session_test.dart` | ✅ 自动 |
| REG-03 | 会话恢复与撤销 | `study_session.dart`、`study_repository.dart` | `phase3_session_test.dart`、`phase3_study_actions_test.dart` | ✅ 自动 |
| REG-04 | 普通/专项/冲刺模式 | `study_session.dart`、`sprint_repository.dart`、`sprint_page.dart` | `phase3_sprint_test.dart`、`phase3_sprint_ui_test.dart` | ✅ 自动 |
| REG-05 | 四种练习模式 | `practice_session.dart`、`practice_page.dart` | `phase3_practice_test.dart`、`phase3_practice_ui_test.dart`、`phase4_practice_test.dart` | ✅ 自动 |
| REG-06 | 练习公平覆盖与题目质量 | `study_repository.practiceBatch` / `_practiceCandidates`、`practice_session._optionsFor` | `phase4_practice_test.dart`（覆盖 20/800/5000/20000、稀疏例句、同义干扰项） | ✅ 自动 |
| REG-07 | 反馈状态与语音时序 | `practice_session.dart`（`PracticePhase`）、`practice_page.dart` | `phase3_practice_test.dart`、`phase4_practice_test.dart`、`phase3_practice_ui_test.dart` | ✅ 自动（界面层）；📱 真机发音时序 — |
| REG-08 | 收藏、多标签、词书及搜索 | `word_metadata_repository.dart`、`wordbook_repository.dart`、`word_repository.dart` | `phase3_metadata_test.dart`、`phase3_metadata_ui_test.dart`、`wordbook_test.dart`、`phase3_data_test.dart` | ✅ 自动 |
| REG-09 | 批量操作与事务回滚 | `word_management` 系列、`study_repository` 事务 | `phase3_data_test.dart`、`phase3_study_actions_test.dart` | ✅ 自动 |
| REG-10 | 数据库迁移与旧备份兼容 | `app_database.dart`（Schema 1→2→3） | `phase3_migration_test.dart`、`migration_and_settings_test.dart`、`phase3_backup_validation_test.dart` | ✅ 自动 |
| REG-11 | 三设备同步收敛 | `backup_service.dart`、`sync_coordinator.dart` | `phase3_sync_test.dart`、`sync_test.dart` | ✅ 自动（逻辑层） |
| REG-12 | 同步冲突、删除及恢复 | `backup_service.mergeDataset`、`content_sync_repository.dart` | `phase3_content_merge_test.dart`、`phase3_sync_test.dart` | ✅ 自动 |
| REG-13 | 自动同步、配置与凭据隔离 | `auto_sync_service.dart`、`credential_store.dart`、`sync_settings_page.dart` | `phase3_auto_sync_test.dart`、`phase3_auto_sync_ui_test.dart`、`phase3_github_guard_test.dart` | ✅ 自动 |
| REG-14 | 大数据量合并与重放 | `backup_service.mergeDataset`、`study_repository.rebuildStatesForWords` | `phase3_performance_test.dart`、`phase4_performance_test.dart` | ✅ 自动（Debug 内存库） |
| REG-15 | 统计及到期刷新 | `study_repository.statistics/nextDueAfter`、`navigation.dart` 定时器 | `phase3_statistics_test.dart`、`phase3_due_refresh_test.dart` | ✅ 自动 |
| REG-16 | TTS 与屏幕常亮 | `tts_service.dart`、`screen_awake.dart` | `phase3_tts_test.dart`、`phase4_native_test.dart` | ✅ 自动（服务层）；📱 真机发音与真实常亮 — |
| REG-17 | 文件导入、导出及恢复副本 | `import_service.dart`、`backup_files.dart`、`wordbook_export.dart` | `import_test.dart`、`backup_test.dart`、`phase3_export_and_forms_test.dart`、`phase4_security_test.dart` | ✅ 自动 |
| REG-18 | 诊断日志与凭据保护 | `diagnostics_service.dart`、`settings_page.dart` | `phase3_diagnostics_test.dart`、`phase4_security_test.dart` | ✅ 自动 |
| REG-19 | 前后台生命周期 | `navigation.dart`、`study_page.dart`、`practice_page.dart` | `phase3_due_refresh_test.dart`、`phase4_native_test.dart`、`phase4_security_test.dart`（后台落盘） | ✅ 自动（状态层）；📱 真实前后台 — |
| REG-20 | Android / macOS / iOS 构建 | `.github/workflows/ci.yml` | GitHub Actions | 见 `docs/phase4-delivery.md` |
| REG-21 | 经典 Material Design 2 交互回归 | `app/theme.dart`、`shared/widgets/common.dart` | `phase3_ui_test.dart`、`ui_phase2_test.dart`、`widget_test.dart`、golden 测试 | ✅ 自动（含 golden 基准） |

## 平台条件跳过项

| 测试 | 原因 | 在哪里执行 |
|---|---|---|
| `macos_packaging_test.dart` MAC02 | 需要真实 `.app` 产物 | CI `macos` job |
| `macos_packaging_test.dart` MAC03 | 需要真实 ZIP 产物 | CI `macos` job |

本地 286→（本轮新增后）全量运行中这 2 项始终为 `⏭ 条件跳过`，从未标记为通过。

## 明确未验证清单

以下项目**不得**在任何交付材料中表述为已通过：

1. 三平台真机交互、发音、常亮、前后台切换。
2. 真实 GitHub 私有仓库 + 真实 PAT 的完整同步矩阵。
3. 真实 WebDAV 服务（仅 loopback HTTPS 协议测试）。
4. Release 模式与文件型 SQLite 的性能数据。
5. iOS / macOS 的签名、公证与分发（本阶段明确排除）。
