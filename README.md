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
| 版本 | 1.1.0 (Phase 2) |
| Flutter | **3.50.1** stable（Dart 3.14.0） |
| 关键依赖 | drift 2.35.4 / flutter_riverpod 3.5.0 / flutter_tts 4.2.5 / flutter_secure_storage 11.2.0 / http 1.6.0 / crypto 3.0.8 |
| 应用 ID | `com.pew2018.materialword` |
| 数据库 schemaVersion | 3（用户库）、1（词典库） |
| 备份协议 | schemaVersion 3（兼容导入 1/2；数据库独立为 3） |
| 自动化检查 | 102 项测试通过；`flutter analyze` 通过 |

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

## Phase 3（实施中）

已加入稳定分页、明确范围的批量选择、取消无副作用、管理事件与真实答题分离、会话恢复与撤销、本轮真实总结和错词复练、共享设置版本、事务快照、字段级合并与重命名身份、收藏和多标签、因果事件顺序、学习中编辑和语音刷新、持久化自动同步与配置并发保护、WebDAV 强 ETag/条件读取及经典 Material 交互整改。当前完整本地回归为 222 项通过、2 项平台条件跳过；不是三平台最终交付。

逐项范围见 [任务审计](docs/phase3-audit.md)，实际证据见 [验证记录](docs/phase3-verification.md)。冲刺、练习模式、完整同步矩阵与平台交付仍待完成。

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
  core/database/           Drift 表、schema v2 迁移、行映射
  core/text/               词典文本规范化
  core/repositories/       词条 / 词书 / 学习 / 设置
  features/                dashboard / study / dictionary / settings / statistics /
                           word_management / wordbooks / sync / backup
  services/                调度、会话、词典、导入、备份、TTS、同步
  shared/widgets/          经典 Material 2 列表与通用控件
assets/dictionary/          ECDICT SQLite + 内容哈希元数据 + MIT 许可证
test/                      102 项测试（Phase 1 T01–T20 + UI/DATA/SYNC 回归）
```

## 文档

- [架构](docs/architecture.md) · [同步协议](docs/sync-protocol.md) · [学习算法](docs/study-scheduler.md)
- [构建指南](docs/build-guide.md) · [路线图](docs/roadmap.md)

## 已知限制

- 本机没有完整 Xcode / CocoaPods，macOS 与 iOS 构建验证由 GitHub Actions 完成；
  Android Gradle 依赖下载在本机遇到 Maven 503，同样交由 CI 产出。
- iOS 仅 `--no-codesign` 编译验证，**不可安装**。
- Android release 仍使用 debug keystore，签名身份与上一阶段一致，旧用户可覆盖安装。
- WebDAV 服务器若不返回 ETag，会被明确标注为"无法安全检测并发修改"，自动同步受限。
- GitHub / WebDAV 的协议测试使用 Mock HTTP；未连接真实服务，真实账号联调仍需用户提供测试配置。
- 真机动画、TTS 语音与窗口缩放的人工验收尚未完成；Widget 测试与编译成功不等同于真机验收。
