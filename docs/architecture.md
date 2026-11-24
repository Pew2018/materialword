# 架构

## 目标与取舍

Phase 1 只有一个目标：尽快得到一个**真的能用来背单词**的软件。因此：

- 不做 Clean Architecture 那套 interface / use case / adapter 三层铺开；
- UI、数据库、算法、同步四层边界清晰，但层与层之间是**直接调用**，不额外造抽象；
- 只有两处刻意抽象：`StudyScheduler`（纯函数算法）和 `SyncProvider`（未来网络同步接口）。

## 分层

```
UI (features/*)                Flutter Widget，只读状态 + 触发动作
   ↓ ref.watch / ref.read
Providers (app/providers.dart) Riverpod：依赖注入 + 缓存 + 失效
   ↓
Services (services/*)          调度算法、学习会话、词典、导入、备份、同步
   ↓
Repositories (core/repositories)  唯一写数据库的地方（事务边界在这里）
   ↓
Database (core/database)       Drift 表定义 + 生成代码 + 行映射
```

规则：

1. **Widget 不写 SQL**，也不自己算学习进度；进度一律来自仓储查询。
2. **调度纯函数**：`StudyScheduler.schedule()` 输入快照 + 答案 + 时间，输出新状态，无 IO，
   因此可以被穷举测试。
3. **一次作答 = 一个事务**：`StudyRepository.recordAnswer()` 在同一事务里写
   `review_events` 与 `learning_states`，要么都成功、要么都不写。

## 数据模型

用户库（`materialword.sqlite`，Drift）：

| 表 | 作用 | 关键约束 |
| --- | --- | --- |
| `words` | 词条 | `normalized` 唯一索引（大小写/空格归一化后去重） |
| `word_books` | 词书 | 软删除 `deleted_at` |
| `word_book_entries` | 词书 ↔ 词条多对多 | 复合主键，外键级联删除 |
| `learning_states` | 每个词条的学习状态 | 主键 = `word_id`；`next_review_at` 索引 |
| `review_events` | 原始作答流水（不可变） | 全局唯一 `id`；按 `word_id`、`local_day` 索引 |
| `study_settings` | 单行设置 | 主键固定为 1 |
| `app_meta` | 设备 ID、上次备份时间等 | 键值表 |

要点：

- **词条与学习状态分离**：同一个词加入多个词书，学习记录只有一份。
- **作答流水是事实来源**：`learning_states` 可以从 `review_events` 完整重算
  （`StudyRepository.rebuildStateFromEvents`），备份合并后就靠它纠正状态。
- **软删除**：词条/词书删除只写 `deleted_at`，保证历史与同步墓碑不丢。
- **时间**：全部以 UTC 毫秒存储；"今天"按设备**本地时区**计算 `local_day = YYYY-MM-DD`，
  直接写进 `review_events.local_day`，避免跨时区时每日进度算错。
- **用户改动标记**：`words.customized` 一旦为真，词典补全不再覆盖释义/笔记。

词典库（`ecdict_core.db`，只读）单独一个文件，启动时按资源长度判断是否需要从 bundle 复制到
应用支持目录，然后以 `readOnly` 打开。用户数据与词典数据物理隔离，换词典不会动用户数据。

## 主题

集中在 `lib/app/theme.dart`：颜色、尺寸、圆角、文本主题全部是常量，页面里没有裸色值。

- `useMaterial3: false`
- `Typography.material2014`（Roboto 14/16/20/24 经典字阶）
- `splashFactory: InkSplash.splashFactory`（不是 M3 的 InkSparkle）
- AppBar 56dp / 标题 20sp；列表项 56dp、双行 72dp；图标 24dp；圆角 4dp
- 浅色背景 `#FAFAFA`，主文字 `#212121`；深色主题背景 `#121212`
- 强调色与语义色（认识绿 / 模糊橙 / 不认识红）统一在 `AppColors`

> 说明：Flutter 3.47 起 `package:flutter/material.dart` 被标记为 deprecated，官方建议迁移到
> Material 3 的 `package:material_ui`。MaterialWord 明确要求 M2 外观，而 M2 实现仍在
> `flutter/material` 中完整可用，因此保留原导入，并在 `analysis_options.yaml` 里关闭
> `deprecated_member_use`，原因写在配置文件注释里。

## 平台差异

| | 手机（Android / iOS） | macOS |
| --- | --- | --- |
| 导航 | `BottomNavigationBar` 五个 tab | 左侧 220dp 固定导航 + 右侧内容 |
| 断点 | `< 900dp` | `>= 900dp` |
| 快捷键 | 无 | Space 显示释义、1/2/3 作答、Enter 继续、⌘F 搜索、⌘N 快速添加 |
| 快速添加 | FAB | FAB + ⌘N |

快捷键在 `CallbackShortcuts` 里注册，并且检查 `FocusManager.instance.primaryFocus` 是否落在
`EditableText` 上——正在输入时不会误触发作答。

## 为什么不做的事

- 不引入状态管理 codegen（riverpod_generator）、不做路由表、不做本地化框架（只有中英两种
  Material 本地化字符串，直接交给 `flutter_localizations`）。
- 不做自定义 Material 控件库：全部用官方组件，只调主题参数。
