# Classic Material 交互规范

MaterialWord 的最终视觉目标是“统一、克制、清晰、稳定的经典 Material 应用”，
而不是 Flutter 默认控件加大圆角的组合。本文件是 UI 精修阶段的唯一形状与交互口径；
新增控件前先在这里找到对应条目，找不到就先补规范。

## 基础

- Material Design 1 / 2，`useMaterial3: false`，`Typography.material2014`。
- 强调色驱动：顶栏、底栏、按钮、开关、滑块、焦点框、选中态都用 `colorScheme.primary`；
  「认识 / 模糊 / 不认识」的语义色与强调色无关。
- 浅色与深色同时成立：任何颜色都必须从 `ThemeData` 取，不写死白/黑。

## 形状（唯一标尺）

| 元素 | 圆角 |
| --- | --- |
| 按钮（Elevated / Filled / Outlined / Text / 作答按钮） | 2dp |
| 输入框、Select、菜单、Dialog、Snackbar | 4dp |
| Card、Chip、标签、侧栏选中块 | 2dp |
| 底栏项 | 0dp（纯矩形） |
| 头像 / FAB / 色板圆点 | 圆形（唯一允许的圆形） |

不允许出现 8 / 10 / 12 / 16dp 的普通按钮或“胶囊”控件。`FilledButton` 与
`ElevatedButton` 共用 `AppTheme.solidButtonStyle()`：同一背景、同一白色前景、
同一禁用色、同一 2dp 圆角与 88×40 最小尺寸，只有 elevation 不同。

## 响应式

导航只由**窗口宽度**决定，与平台无关，且只有两种状态：

| 宽度 | 布局 |
| --- | --- |
| ≥ 720 | 完整侧栏（品牌区 + 图标 + 文字） |
| < 720 | 底部导航（手机布局） |

不存在“只留图标”的中间态：76dp 图标侧栏既不像手机也不像桌面，还会吃掉内容宽度，
已彻底删除（`ShellLayout` 只有 `bottomBar` / `rail` 两个值）。

`< 720` 的 macOS 窗口是手机布局，不是“压扁的桌面”：页面必须回到单列、可换行、
可滚动，而不是隐藏功能。内容列最大宽度 880dp，页面 gutter 16dp。

## 底部导航

- 五项等宽，内容高 56dp + SafeArea；图标 24dp、标签 12sp、位置固定。
- 每项是矩形命中区：**没有**圆角裁切、没有 pill、没有 M3 indicator。
- 选中**不改变背景**：只用 active 图标、强调色、字重 500 表达当前位置。
- 点击产生大面积经典 InkRipple，被该项矩形裁切；松手后完全消失。
- 不允许图标/标签缩放，不允许宽度跳动。

## 侧栏

- 固定 220dp；品牌区（`MaterialWord`）+ 五项一级导航 + 「词汇」入口 + 底部说明。
- 选中态：极浅矩形着色（primary 6%，2dp 圆角）+ 强调色图标/文字。
- 不允许 16dp 圆角选中块，不允许整行卡片，不允许退回只留图标的窄侧栏。

## 顶栏与 Ripple

- 每个页面的顶栏都用 `ClassicAppBar`（`lib/shared/widgets/common.dart`），
  不得直接使用裸 `AppBar`：全局 ripple 是强调色，而浅色顶栏背景也是强调色，
  两者重合就等于“没有反馈”。
- `ClassicAppBar` 在顶栏子树内覆写交互色为**前景色**：
  splash 20% / highlight 12% / hover 8% / focus 16%，统一 `InkRipple`。
- 这样自动生成的 `BackButton` 与每个 `IconButton` 同时获得可见反馈；静止态无底板、
  无 pill、无 M3 filled 图标按钮；图标 24dp，命中区 ≥48dp。
- 页面内部搜索框是唯一搜索入口：顶栏不再放第二个搜索按钮，⌘F / Ctrl+F 仍然
  跳转并聚焦该输入框。

## 开关行

- 所有 `SwitchListTile` 走 `SettingsSwitchTile`：16dp 左右内边距、24dp leading 图标、
  `bodyLarge` 标题、`bodySmall` 说明、Switch 右对齐、行高随文字自然展开。
- 禁止同一组里混用 `dense: true` 与默认高度。

## 菜单 / Select

- 统一使用 `ClassicSelect` / `ClassicSelectChip` / `showClassicMenu`。
  语言、学习模式、词书、S3 寻址方式、备份目标都是同一套控件。
- 菜单宽度 160–320dp，距窗口边缘 ≥16dp，锚点下方展开（间隙 4dp），空间不足才上翻，
  上下都放不下时限制高度并允许滚动。
- 菜单项高 48dp、左侧 16dp、整行 Ripple，选中项带勾；长文本省略并带 Tooltip，
  勾号永远留在菜单内。
- 几何量一律以**承载菜单的 Overlay** 为准（`anchor.getTransformTo(overlay)`），
  不用 `MediaQuery.sizeOf`：弹窗、嵌套 Navigator、缩放后的 macOS 窗口里三者不同。
- 极窄窗口优先保证不越界，再缩小宽度；任何 `clamp` 都必须有 `low <= high`。
- 菜单关闭后再回调，且回调前检查 `context.mounted`。
- 禁止 `isExpanded` 下拉把菜单拉到整页宽度；三点菜单、长按菜单、确认弹窗不属于
  Select，不要被这条规则改造。

## 按钮层级

一个区域一个 Primary（`ElevatedButton`）；Secondary 用 `OutlinedButton`；
Tertiary 用 `TextButton`；破坏性操作使用红色 `TextButton`。
不再出现“7 个不同权重的按钮抢注意力”，也不要让 `AlertDialog.actions` 把四个按钮
自动折成右对齐的一列：弹窗里主要操作自己成行（宽 ≥400dp 两列，否则纵向铺满），
辅助操作放单独一行。

## 实心控件的前景

- 强调色实心控件（实心按钮、FAB、顶栏标题与图标）**永远白色前景**，
  不再用 `AppTheme.onColor()` 按亮度二选一。
- 强调色太亮时用 `AppTheme.whiteForegroundSurface()` 降低**填充**亮度，
  保证白色文字 ≥4.5:1；用户保存的强调色、色板圆点、语义色都不改。
- 描边按钮、文字按钮、正文、菜单项仍用强调色或主题正文色；不得全局强制白字。

## 用户可见时间

- 所有用户可见日期时间必须经过展示层格式化（`formatDateTime` /
  `lib/l10n/backup_labels.dart` 的 `cloudBackupTime`）。
- 不显示 ISO 的 `T` / `Z` / 微秒，不显示 1970：解析失败显示本地化回退文案。
- 持久化的 UTC 时间、文件名里的时间、`exportedAt` 与校验逻辑都不因格式化而改变。

## 页面转场

- 一级导航之间：即时切换（IndexedStack），不做 push 动画。
- 二级页面：Android 使用 `PredictiveBackPageTransitionsBuilder`（系统预测性返回，
  回退为水平滑动 + 淡入），Apple 平台 Cupertino，桌面 FadeForwards。
- Dialog：Material 的 fade + 轻微缩放，不使用页面滑动。
- 动画时长 token：fast 140ms / standard 200ms / page 240ms，统一 `Curves.easeInOut`。

## 学习页底部操作区

- 单一 surface + 顶部 1dp 分隔线，**不是**浮起卡片里再放一个按钮。
- 「显示释义」40dp 高、2dp 圆角，触控区 ≥48dp；桌面端限宽居中。
- 快捷键是按钮旁边的 keycap 提示，不写进按钮标题。
- 三个作答按钮等宽、2dp 圆角、高度稳定。

## 文本

- 面向普通用户；不出现墓碑、字段版本、ETag、schema、确定性裁决、设备 ID 等术语。
- 技术细节放在「高级」「诊断」二级页面或可展开区域。

## 性能

- 后台写入只失效当前可见页面依赖的 provider；隐藏页面在被选中时刷新一次。
- 长列表使用 builder/sliver；不在 build 中排序或过滤大集合。
- 只加有证据支持的 `RepaintBoundary` / `const` / 缓存。

## 滚动

- 全局使用 `ClassicScrollBehavior`（`lib/app/app.dart`）：macOS 上强制
  `ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics())`，去掉桌面端的
  bouncing 惯性，让页面位置直接跟随手势/滚轮；iOS / Android 保持各自原生物理。
- `Slider` 不使用 `divisions`：连续跟手，数值显示取整，只在松手时写库。
- 不把 `PointerDeviceKind.mouse` 加进全局 drag devices（会破坏文本选择）。

## 新增页面检查表

1. 普通按钮用 2dp 圆角；实心按钮白字白图标。
2. 强调色实心面用 `whiteForegroundSurface()` 保可读性。
3. 普通数据选择器用 `ClassicSelect`，紧凑筛选器用 `ClassicSelectChip`。
4. 菜单只走 `showClassicMenu`，不自己算位置。
5. 页面顶栏用 `ClassicAppBar`。
6. 设置页复用 `SectionHeader` / `SettingsGroup` / `SettingsTile`。
7. 用户可见时间必须格式化。
8. 新增文案进 ARB（中英齐备），不写死中文字面量。
9. 320 / 360 / 411 / 720 / 1024 与 1.6 倍字号下无溢出。
10. 不引入未经规范约束的药丸形按钮。

## 测试

- `test/phase6_classic_ui_test.dart`：形状标尺、底栏矩形与无着色、学习页操作区、
  菜单宽度约束、Dashboard 控件减法、实心按钮白色前景与 23 种强调色对比度、
  语言选择器、菜单定位（下方 / 上翻 / 极窄窗口 / 弹窗内 / 缩放后 / 长文本）。
- `test/cloud_backup_ui_test.dart`：手动备份弹窗在 360dp 与大字号下不溢出、
  下载描边 + 上传实心、未配置状态、S3 寻址选择器、凭证状态、时间与文件大小格式。
- `test/phase6_1_polish_test.dart`：两态导航、设置页图标/开关/滑杆、macOS 滚动物理、
  作答构成行样式、词典搜索入口、同步页统一、顶栏 ripple。
- `test/phase3_golden_test.dart`：按钮/输入框/开关的浅色与深色基准图（逐像素）。
- `test/widget_test.dart`：360 / 412 / 520 / 600 / 720 / 840 / 1024 / 1280 / 1600
  宽度下无溢出，且导航形态符合上表。

视觉真机验收仍然需要人工过一遍；Widget 结构测试只覆盖可判定的部分。
