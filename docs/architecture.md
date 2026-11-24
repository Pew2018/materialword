# 架构

## 目标与取舍

不使用 Clean Architecture 的三层接口铺开。UI、数据库、算法、同步边界清晰，
层与层之间直接调用；刻意的抽象只有 `StudyScheduler`（纯函数算法）和
`SyncProvider`（统一传输契约）。Phase 2 保持这一原则，没有重写项目。

## 分层

```
lib/
  app/                 AppShell 导航、Riverpod providers、AppTheme 设计令牌
  core/
    database/          Drift 表定义、schema v2 迁移、行映射
    models/            enums / study_models（含口径明确的 TodayProgress）
    repositories/      words / wordBooks / study / settings（字段级写入）
    text/              词典文本规范化（唯一入口）
  features/            dashboard / study / dictionary / settings / statistics /
                       word_management / wordbooks / sync / backup
  services/            dictionary / import / backup / TTS / scheduler / session / sync
  shared/widgets/      经典 MD2 列表与通用控件
```

## 关键设计决策（Phase 2）

### 导航
`AppShell` 用 `layoutFor(width, platform)` 选择底栏 / 紧凑侧栏 / 完整侧栏。
一级页面放在**懒加载 IndexedStack**：只有访问过的页面才挂载，其余是 `SizedBox.shrink()`。
这样保留搜索文本与滚动状态，同时不会在首屏触发五个页面的数据库查询。

`ClassicBottomNavigationBar` 由 `Material + Row + Expanded + InkWell + Semantics` 组成：
每一项独占一个裁剪过的 `Material`，因此 InkSplash 只能在该项矩形内绘制，且涟漪出现在
真实点击坐标。hover / focus / highlight / selected 四种反馈分别配色，没有永久药丸背景。

### 设置写入
`SettingsRepository.save()` 只把调用者给出的字段放进 `StudySettingsCompanion`，
生成单条字段级 `UPDATE`；不再"读整行 → replace 整行"。滑块在拖动期间只改本地
`_draft`，`onChangeEnd` / 步进器 / 文本输入才调用 save。

### 词典文本
`core/text/dictionary_text.dart` 是唯一规范化入口，处理字面 `\n`/`\r\n`/`\t`、
真实 CRLF、行尾空白与多余空行。`note` 是用户文本，永远不参与规范化。
内置词典用 `.meta.json` 的 `schemaVersion + sha256` 校验应用私有目录中的缓存；
不再以文件大小判断版本。

### 学习数据口径
每日目标是**设备全局**，词书只限制学习范围（UI 明确标注）。
`TodayProgress` 同时给出目标、今日完成、剩余额度、真实未学数、今日可学新词、
到期总数、今日可复习、积压；`hasWork` 为假时不显示可点击的"开始学习"。
`learning_states` 是从 `review_events` 派生的，可确定性重建。

### 同步
`BackupService` 负责版本化快照与事务内合并；`SyncCoordinator` 负责流程、互斥、
冲突重试与状态持久化；`SyncProvider` 只负责传输。凭据走平台安全存储，
永远不进 SQLite / JSON / 日志。详见 `docs/sync-protocol.md`。

### 主题
`AppTheme.of(brightness, accent)` 由一个强调色生成完整 Material 2 主题
（AppBar、底栏、按钮、FAB、Switch、Checkbox、Radio、Slider、进度条、输入框焦点、
TabBar、Ripple）。答题三级颜色独立，不随强调色变化。

## 平台权限

- Android：`INTERNET`（GitHub / WebDAV / HTTPS 导入）。签名身份未改变，仍为 debug key。
- macOS：沙箱 + `network.client` + 用户选择文件读写 + Keychain access group。
- iOS：HTTPS 默认允许；动态 TTS 语音取决于系统；凭据在 Keychain。


## Phase 3 当前变化

- 用户库升级至 Schema 3；事件增加作者日界及来源，收藏/标签/身份及字段版本基础表增量建立；新管理/撤销事件仍通过 mode 表示，备份协议独立为 3，旧客户端拒绝未来版本。
- `StudySession` 将队列引用、位置、复练、计数和最近撤销信息存入本机 AppMeta，不复制词典；作答与会话快照同事务写入。此会话不随设备同步。
- 同日同范围同计划可恢复；跨日/目标变化按当前额度重建，旧未作答词仍由普通队列安排。恢复时过滤删除、移出词书及其他设备新完成的条目。
- 备份所有表由一个 Drift 事务形成快照；大 JSON 的文件导入/导出编解码使用后台 isolate。
- 本地文件仅承诺手动备份合并，不声称原子 rename 等于跨进程条件写入；移动平台手动使用系统文件接口，不声称持久 URI 授权。
- 一级页面采用固定 Row/Expanded 页面宿主，切换侧栏断点时保持同一元素位置。双栏使用父 LayoutBuilder 约束。
- 最近到期时间调度一次性 Timer；数据变更防抖重算，最多一小时重查系统时间变化，不逐秒轮询。

完整 Phase 3 仍在实施；作者日界及旧状态/UTC 回退的来源优先级已通过双时区进程测试；临时资源条件写入探测通过真实 HTTPS 服务测试。字段级内容并发合并、标签功能、真实用户服务及完整平台验证仍待完成。
