# Phase 6 — 经典 Material 收尾（UI 精修）

本阶段只改外观、交互与文案，数据与同步逻辑零改动。功能基线保持
Phase 5 / 5.1 冻结状态（新增、删除后恢复、导入导出、备份、指定版本恢复、
自动备份、GitHub / WebDAV 同步、多设备冲突、conflict restore、remote missing、
metadata-only import、大数据 merge、三平台 CI）。

## 1. 响应式外壳

`layoutFor()` 只看窗口宽度，且只有两种状态：

| 宽度 | 布局 |
| --- | --- |
| ≥ 720 | 完整侧栏 |
| < 720 | 底部导航 |

此前桌面平台在任意窄窗口都保留 76dp 图标侧栏，550dp 的 macOS 窗口因此只剩
474dp 内容区，数字与按钮被挤到换行。现在窄窗口直接用手机布局，720dp 及以上直接
给完整侧栏 —— 中间那档“只有图标”的侧栏在 Phase 6.1 中已彻底删除。

内容列最大宽度 880dp（`ContentColumn`），Dashboard / Statistics / Settings /
WordBooks / Dictionary / Backup / Sync 在宽窗口下不再把一行文字拉满 1600dp。

## 2. 底部导航

- 五项等宽、56dp 高、24dp 图标、12sp 标签。
- 每项是矩形命中区：无圆角裁切、无 pill、无 M3 indicator。
- 选中不改变背景：只有 active 图标 + 强调色 + 字重 500。
- 大面积经典 InkRipple 被矩形边界裁切，结束后完全消失。
- 移除了悬停 tooltip（窄桌面窗口下它会盖住相邻目的地）。

## 3. 形状标尺

| 元素 | 之前 | 现在 |
| --- | --- | --- |
| ElevatedButton | 12dp | 2dp |
| Outlined / TextButton | 10dp | 2dp |
| 底栏选中项 | 16dp 圆角 + 裁切 | 0dp，无背景 |
| Dialog / 菜单 / 输入框 | 6dp | 4dp |
| Card / Chip / 侧栏选中块 | 6dp | 2dp |

## 4. 菜单 / Select

`DropdownButton(isExpanded: true)` 会把菜单拉到按钮宽度，狭窄窗口里直接顶到
屏幕边缘。新增 `ClassicSelect`、`ClassicSelectChip`、`showClassicMenu`：

- 宽度 160–320dp；
- 距窗口边缘 ≥16dp；
- 锚点下方展开，空间不足才上翻；
- 菜单项 48dp、整行 Ripple、选中项带勾。

替换范围：Dashboard 当前词书、Statistics 词书筛选、Settings（词书 / 学习模式 /
TTS 语音）、Import 目标词书、QuickAdd 目标词书、Sprint 目标词书、Word Management
（标签 / 词书 / 状态 / 排序）。`_DropdownChip` 已删除。

## 5. 页面转场

- Android：`PredictiveBackPageTransitionsBuilder`，并在 Manifest 打开
  `enableOnBackInvokedCallback`；手势进行时能看到父页面，松手自然完成。
- 桌面：`FadeForwardsPageTransitionsBuilder`（短距离水平 + 淡入）。
- Apple：保持 Cupertino 水平转场。
- 一级导航仍是即时切换。

## 6. 控件减法

- **Settings 每日目标**：原本数字框 + 减 + 加 + 滑杆四套输入，现在只有
  `− 值 +`（步长 5 / 10），点数值弹出精确输入框。
- **Dashboard**：一个 Primary（开始学习）+ 一个 Secondary（只做复习）；
  困难词 / 近期错误变成列表行；删除与底栏重复的「词书」按钮；删除「快捷操作」
  三行（快速添加、导入、同步在底栏、词书页与设置里已有入口）。
- **Settings 信息架构**：学习 / 外观 / 发音 / 数据 / 关于；诊断信息拆成独立页面。
- **Statistics**：删除与总览重复的「字词表现」，保留最近学习日与已撤销作答。

## 7. 学习页操作区

- 360dp 的 AppBar 不再溢出：标题过长时，跳过/撤销折叠进「更多操作」。
- 去掉 `Material(elevation: 8)` 的浮层，改为单一 surface + 1dp 分隔线。
- 「显示释义」40dp 高、2dp 圆角、48dp 触控区，桌面限宽 420dp 居中。
- `（Space）` 从按钮标题移出，桌面端在按钮右侧显示 keycap；手机端隐藏。
- 三个作答按钮等宽、2dp 圆角、48dp 高，语义色不变。

## 8. 文案

普通用户可见处删除：同步墓碑、字段版本、确定性裁决、ETag、Fine-grained PAT、
Token、schema 版本等。示例：

| 之前 | 现在 |
| --- | --- |
| 作答历史作为同步墓碑保留 | 删除单词不会清除已有学习记录 |
| 冲突由字段版本、更新时间和设备 ID 确定性地裁决 | 另一台设备也修改了同一项内容，MaterialWord 保留了较新的版本… |
| Fine-grained Personal Access Token | 访问令牌（Access Token） |
| 如果服务器不返回 ETag… | 如果这个服务器不能可靠地处理多设备同时修改… |
| 数据版本：v9 | 数据格式：v9 |

合并规则的详细表述移入「合并规则（高级）」可展开区域，诊断相关（设备标识、
导出报告、运行日志）移入独立页面。

## 9. 性能

- 后台写入（同步、自动备份、定时器）以前会 invalidate
  `statisticsProvider` 与 `bookSummariesProvider`，隐藏页面也会重建，统计页的
  聚合与图表在用户滚动设置时被反复重算。现在只失效当前可见页面依赖的 provider，
  隐藏页面在被选中时刷新一次。
- 统计页仍保留一次聚合计算，但不再被后台写入放大。
- 已有性能测试（phase3/4/5 performance）全部通过。

未做：真机 Profile 的逐帧截图对比（本机无可用的 macOS profile 采样流程），
因此没有给出 frame time 数字；相关结论来自 provider 失效范围与重建路径的代码证据。

## 10. 测试

- 更新：`phase3_ui_test`（预测性返回、宽度断点、矩形底栏、无着色选中）、
  `ui_phase2_test`（每日目标单输入模型）、`widget_test`（9 档宽度矩阵）。
- 新增：`phase6_classic_ui_test`（形状标尺、底栏、学习页操作区、菜单约束、
  深色菜单、Dashboard 控件减法）。
- Golden：`classic_light/dark` 的 macOS 与 Linux 参考图均已按新形状重建
  （Linux 参考图由 Ubuntu runner 生成，逐像素比较不变）。
- 本地：`flutter analyze` 0 issue，`flutter test` 485 通过，时区回放脚本通过，
  `git diff --check` 干净。

---

# Phase 6.1 — 交互收尾

本轮只动外观、交互与文案：数据、同步、备份、调度一行未改，可用
`git diff --stat` 核对（只涉及 `lib/app`、`lib/features/*/…_page.dart` 的 UI 部分、
`lib/shared/widgets/common.dart` 与测试）。

## 1. 导航只有两态

`enum ShellLayout { bottomBar, rail }`。`layoutFor()` 在
`AppDimens.sideNavigationBreakpoint`（720dp）处分流；`railCollapseBreakpoint`、
`desktopBreakpoint`、`navRailCompactWidth` 以及 `_SideNavigation` / `_RailItem` 里
所有 `compact` 分支全部删除。720 / 840 / 900 / 1024 都是完整侧栏，`< 720` 是底栏。

## 2. 设置页

- 「随机学习顺序」补上 `Icons.shuffle`，与「学习时保持屏幕常亮」一致。
- 新增 `SettingsSwitchTile`，三处开关统一为：16dp 左右内边距、24dp leading、
  `bodyLarge` 标题、`bodySmall` 说明、非 dense。
- 发音速度 `Slider` 去掉 `divisions: 18`：连续跟手，拖动只更新本地 draft，
  松手（`onChangeEnd`）才写一次库。

## 3. macOS 滚动

`ClassicScrollBehavior.getScrollPhysics` 在 macOS 上返回
`ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics())`，去掉桌面端的
bouncing 惯性；iOS / Android / 桌面其余平台的物理不变。
没有把 `PointerDeviceKind.mouse` 加进全局 drag devices。

## 4. 统计「作答构成」

`_LineRow` 的左右两侧现在共用同一个 `TextStyle`（`subtle` 时都是 `bodySmall`，
否则都是 `bodyMedium`），数字只额外带 `tabularFigures`。子项不再用全角空格排版，
改为 `indent: 16` 的真实布局缩进，前缀用 `•`。

## 5. 词典

删除顶栏里与页面内搜索框重复的 `IconButton`；`⌘F` / `Ctrl+F` 保留，且切换一级
页面后会把键盘焦点交回外壳（`_shellFocus`），快捷键不会再“按一次就失效”。

## 6. 同步页

- 四个自动同步开关统一走 `SettingsSwitchTile`（同高、同内边距、同图标位）。
- 连接配置抽出 `_SyncTextField`：统一外边距、label/helper 字号与边框。
- 按钮层级：`测试连接`（Outlined）/ `立即同步`（Elevated，唯一 Primary）/
  `导出备份`（Outlined）。
- 合并规则、ID 去重、删除标记、钥匙串等实现细节移入默认收起的
  「同步与合并说明」；主页面只剩功能说明。

## 7. 顶栏 Ripple

新增 `ClassicAppBar`：在顶栏子树内把 splash/highlight/hover/focus 覆写为**前景色**
（20% / 12% / 8% / 16%），仍然使用 `InkRipple`。这样自动生成的 `BackButton` 与
所有 `IconButton` 同时可见，静止态没有底板/pill。全部 14 处 `AppBar(` 已替换。

## 8. 文案

设置项副标题、统计脚注、词典空状态与词形提示、同步页说明/开关/输入/按钮/状态
全部改为面向普通用户：不出现 ECDICT、去重、退避、条件写入、钥匙串等术语。
`解除同步配置` → `关闭同步`，`本地待同步修改` → `待同步的更改`。

## 9. 测试

- 更新：`phase3_ui_test`（两态断点 + `ShellLayout.values` 长度为 2）、
  `widget_test`（720/840 起为完整侧栏，逐项断言图标+文字、220dp 宽度）。
- 新增：`phase6_1_polish_test`（NAV01–05 / SET01–05 / SCROLL01 / STAT01–03 /
  DICT01–03 / SYNCUI01–04 / TOP01–08）。
- Golden 基准图未变：本轮没有改动它们渲染的控件与几何。
