# Roadmap

## Phase 1（已完成）

- [x] Android / iOS / macOS 三平台，同一套 Dart 代码
- [x] 经典 Material Design 2 主题（`useMaterial3: false` + `InkSplash`）
- [x] Drift / SQLite 用户库，离线 ECDICT 词典（26,282 词，MIT）
- [x] 词书、快速添加、TXT / CSV / JSON / HTTPS 导入
- [x] 学习闭环、五级间隔重复、每日目标、统计、备份合并
- [x] 34 个自动化测试与四个 GitHub Actions job

## Phase 2（本次已完成）

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

## Phase 3（尚未开始）

- [ ] 真机交互验收：macOS / Android / iOS 上人工确认动画与 TTS 语音
- [ ] 学习页手势（上滑显示释义、左右滑切词）与屏幕常亮
- [ ] 拼写模式、例句挖空
- [ ] 真实 GitHub / WebDAV 服务端联调（需用户提供测试凭据）
- [ ] 操作系统后台定时同步（本阶段未要求）
