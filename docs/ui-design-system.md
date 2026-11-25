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
| 按钮（Elevated / Outlined / Text / 作答按钮） | 2dp |
| 输入框、Select、菜单、Dialog、Snackbar | 4dp |
| Card、Chip、标签、侧栏选中块 | 2dp |
| 底栏项 | 0dp（纯矩形） |
| 头像 / FAB / 色板圆点 | 圆形（唯一允许的圆形） |

不允许出现 8 / 10 / 12 / 16dp 的普通按钮或“胶囊”控件。

## 响应式

导航只由**窗口宽度**决定，与平台无关：

| 宽度 | 布局 |
| --- | --- |
| ≥ 900 | 完整侧栏（图标 + 文字） |
| 720–899 | 图标侧栏 |
| < 720 | 底部导航（手机布局） |

`< 720` 的 macOS 窗口是手机布局，不是“压扁的桌面”：页面必须回到单列、可换行、
可滚动，而不是隐藏功能。内容列最大宽度 880dp，页面 gutter 16dp。

## 底部导航

- 五项等宽，内容高 56dp + SafeArea；图标 24dp、标签 12sp、位置固定。
- 每项是矩形命中区：**没有**圆角裁切、没有 pill、没有 M3 indicator。
- 选中**不改变背景**：只用 active 图标、强调色、字重 500 表达当前位置。
- 点击产生大面积经典 InkRipple，被该项矩形裁切；松手后完全消失。
- 不允许图标/标签缩放，不允许宽度跳动。

## 侧栏

- 选中态：极浅矩形着色（primary 6%，2dp 圆角）+ 强调色图标/文字。
- 不允许 16dp 圆角选中块，不允许整行卡片。

## 菜单 / Select

- 统一使用 `ClassicSelect` / `ClassicSelectChip` / `showClassicMenu`。
- 菜单宽度 160–320dp，距窗口边缘 ≥16dp，锚点下方展开，空间不足才上翻。
- 菜单项高 48dp、左侧 16dp、整行 Ripple，选中项带勾。
- 禁止 `isExpanded` 下拉把菜单拉到整页宽度。

## 按钮层级

一个区域一个 Primary（`ElevatedButton`）；Secondary 用 `OutlinedButton`；
Tertiary 用 `TextButton`；破坏性操作使用红色 `TextButton`。
不再出现“7 个不同权重的按钮抢注意力”。

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

## 测试

- `test/phase6_classic_ui_test.dart`：形状标尺、底栏矩形与无着色、学习页操作区、
  菜单宽度约束、Dashboard 控件减法。
- `test/phase3_golden_test.dart`：按钮/输入框/开关的浅色与深色基准图（逐像素）。
- `test/widget_test.dart`：360 / 412 / 520 / 600 / 720 / 840 / 1024 / 1280 / 1600
  宽度下无溢出，且导航形态符合上表。

视觉真机验收仍然需要人工过一遍；Widget 结构测试只覆盖可判定的部分。
