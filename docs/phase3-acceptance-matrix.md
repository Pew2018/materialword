# Phase 3 验收矩阵（源码 → 自动化 → 平台 → 真机）

本文件把 Phase 3 的验收项映射到**实际存在的测试用例**，并明确区分四种证据等级：

- **S**：源码已实现，可静态审计。
- **T**：本地自动化测试通过（`flutter test`，含 Dart / Drift / Widget / Golden / Mock HTTP / 真实 loopback HTTPS）。
- **P**：三平台编译与产物校验通过（GitHub Actions，见最终报告）。
- **D**：真机/真实服务验收。**没有 D 的项目一律不得声称真机通过。**

Phase 3I 原始编号（UI01–UI20、WORD01–WORD12、STUDY01–STUDY17、SYNC01–SYNC27、DB01–DB10）
的逐条原文不在仓库中，因此下表按**功能域**映射到 `docs/phase3-audit.md` 中可追溯的 3A–3H 条目
和真实测试文件；不臆造编号含义。

## 1. 任务域映射

| 域 | 对应审计条目 | 主要测试文件 | S | T | P | D |
|---|---|---|---|---|---|---|
| 页面转场、底栏、Ripple、形状 | 3A-01…3A-05 | `phase3_ui_test.dart`、`ui_phase2_test.dart`、`phase3_golden_test.dart` | 是 | 是 | 是（macOS/iOS 编译） | 返回手势/IME 真机待验 |
| 配色语义、阴影、滚动反馈、文案 | 3B-01…3B-05 | `phase3_golden_test.dart`、`phase3_ui_test.dart` | 是 | 是 | 是 | 视觉真机待验 |
| macOS 布局、桌面学习页、移动适配、快捷键 | 3C-01…3C-04 | `ui_phase2_test.dart`（UI07/UI08/UI09）、`phase3_study_actions_test.dart` | 是 | 是 | 是 | 多窗口 DPI 真机待验 |
| 分页、全选、取消、搜索代际、批量事务 | 3D-01…3D-05 | `data_correctness_test.dart`、`phase3_data_test.dart`、`phase3_metadata_ui_test.dart` | 是 | 是 | — | — |
| 快速录入、词书扩展、词典质量、词形、搜索、TTS | 3D-06、3D-08、3F-01…3F-04 | `quick_add_test.dart`、`wordbook_test.dart`、`import_test.dart`、`phase3_export_and_forms_test.dart`、`phase3_tts_test.dart`、`phase3_ui_test.dart` | 是 | 是 | 是 | 真实语音待验 |
| 间隔重复、掌握语义、会话恢复、撤销、总结、冲刺、练习 | 3E-01…3E-08 | `study_scheduler_test.dart`、`study_flow_test.dart`、`phase3_session_test.dart`、`phase3_study_actions_test.dart`、`phase3_round_summary_test.dart`、`phase3_sprint_test.dart`、`phase3_practice_test.dart`、`phase3_practice_ui_test.dart`、`phase3_study_interaction_test.dart` | 是 | 是 | 是 | 手势/语音真机待验 |
| 文件选择、备份、WebDAV/GitHub、共享设置、合并、快照、自动同步、同步 UI、凭据 | 3G-01…3G-10 | `sync_test.dart`、`sync_transport_test.dart`、`phase3_sync_test.dart`、`phase3_sync_race_test.dart`、`phase3_webdav_http_test.dart`、`phase3_github_guard_test.dart`、`phase3_auto_sync_test.dart`、`phase3_content_merge_test.dart`、`phase3_backup_validation_test.dart`、`phase3_auto_sync_ui_test.dart` | 是 | 是 | 是 | 真实 PAT/WebDAV 待验 |
| 统计、到期刷新、性能、诊断、应用基础 | 3H-01…3H-05 | `phase3_statistics_test.dart`、`phase3_data_test.dart`、`phase3_performance_test.dart`、`phase3_diagnostics_test.dart` | 是 | 是 | 是 | 真机性能待验 |
| Schema 迁移、事件语义、跨时区 | 3D/3E/3G 交叉 | `phase3_migration_test.dart`、`phase3_event_order_test.dart`、`phase3_sync_test.dart`、`tool/verify_timezone_replay.sh` | 是 | 是 | — | — |

## 2. 数据库（DB01–DB10 域）

| 项 | 证据 |
|---|---|
| Schema 1 / 2 真实 fixture 升级 | `phase3_migration_test.dart`（真实发布 SQL fixture，断言笔记/状态/主题/身份/墓碑保留） |
| 迁移中断回滚 | `phase3_migration_test.dart`（DDL 故障注入后列/版本完整回滚，再开成功） |
| Schema 3 增量建表 | `app_database.dart` + 上述迁移测试 |
| 事件可确定性重放 | `phase3_event_order_test.dart`、`phase3_session_test.dart`、`phase3_practice_test.dart` |
| 删除墓碑与复活 | `data_correctness_test.dart`、`phase3_content_merge_test.dart` |
| 文件数据库关闭重开 | `phase3_session_test.dart`、`phase3_backup_validation_test.dart` |
| 批量操作事务回滚 | `data_correctness_test.dart`、`phase3_metadata_test.dart` |
| 字段级版本与身份别名 | `phase3_content_merge_test.dart` |
| 备份整包校验 | `phase3_backup_validation_test.dart` |
| 迁移后凭据不落库 | `phase3_sync_test.dart`、`docs/sync-protocol.md` 审计 |

## 3. 明确未验证（不得声称通过）

1. Android/iOS/macOS **真机**触控、IME、返回手势、语音实际发声。
2. macOS 首启 Gatekeeper 交互与**签名/公证**：当前为 ad-hoc 签名，无 Developer ID。
3. 用户真实 WebDAV 服务与真实 GitHub PAT（仅 Mock + 本机真实 HTTPS 服务 + 公开仓库权限矩阵）。
4. Android APK 覆盖安装：签名使用 runner 临时 debug keystore，不具备生产升级身份。
5. iOS 签名安装包：仅 `--no-codesign` 编译验证，无 IPA。
6. 屏幕常亮：未引入原生插件（见 `docs/phase3-audit.md` 待办）。
