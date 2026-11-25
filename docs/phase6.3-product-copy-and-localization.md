# Phase 6.3 — 产品文案、中文/英文国际化与强调色更新

本文件记录 MaterialWord Phase 6.3 的实际实施状态。**只描述已经进入 `main` 的代码**；未完成项集中列在最后一节，不得当作已完成。

## 1. 目标与边界

* 把面向开发者的界面语言改成面向普通用户的产品语言（参考 Apple 自有应用的克制表达，不模仿 iOS 视觉）。
* 建立 Flutter 官方国际化体系（`flutter_localizations` + `intl` + `gen_l10n` + ARB），支持简体中文、English 与跟随系统。
* 语言设置属于**设备独立设置**：不进入 GitHub/WebDAV 同步数据，不进入共享设置快照。
* 强调色预设整体替换为 23 个指定颜色（11 经典 + 12 Material Design），保留既有选择器 UI、自定义 HEX、恢复默认、旧用户已选颜色。
* 不改变的：Material Design 2 Classic 视觉、学习算法、数据库结构、同步协议、备份格式、导入导出格式、已有测试。

## 2. 文案设计原则

1. **简洁**：删除标题已表达的信息（「当前学习词书」→「学习词书」）。
2. **明确**：一个动作只有一种说法；「删除单词」「移出词书」「重置学习进度」严格区分数据语义。
3. **用户导向**：说结果，不说实现（「导入失败，现有数据未更改」而不是「事务已回滚」）。
4. **无开发者术语**：普通界面不出现 ETag、If-Match、事务、Tombstone、schema 等；这些只保留在「同步诊断」与「技术详情」中。
5. **适度亲切**：「今日任务已完成。」允许；感叹号、营销语、幼稚激励不允许。
6. **风险不削弱**：删除、恢复、同步冲突必须说明影响范围、是否可恢复、是否暂停同步、下一步怎么做。

详细规则见 `docs/ui/copywriting-guidelines.md`。

## 3. 国际化资源结构

```
lib/l10n/
├── app_en.arb                 # 模板（唯一真源）
├── app_zh.arb                 # 简体中文
├── generated/                 # flutter gen-l10n 输出（已提交，CI 会重新生成）
├── l10n.dart                  # BuildContext.l10n + AppLanguage 枚举
├── language_store.dart        # 设备本地语言持久化
├── enum_labels.dart           # 领域枚举 → 本地化名称
├── error_labels.dart          # AppErrorCode → 本地化句子
├── intake_labels.dart         # 单词录入结果 → 本地化句子
├── source_labels.dart         # word.source 内部 ID → 本地化名称
└── relative_time.dart         # 相对时间（刚刚 / 3 分钟前）
l10n.yaml                      # gen_l10n 配置
```

* 组件读取文案的唯一方式：`final l10n = context.l10n;`，随后 `Text(l10n.startStudying)`。
* 不允许 `isChinese ? '开始学习' : 'Start Studying'`，也不允许两套页面。
* 动态文案一律使用 ARB 参数与 ICU plural：`l10n.wordCount(count)`、`l10n.answeredCount(n)`。

## 4. 新增本地化字符串的方法

1. 在 `lib/l10n/app_en.arb` 增加 key（英文文案 + 可选 `description`/`placeholders`）。
2. 在 `lib/l10n/app_zh.arb` 增加同名 key（中文文案）。
3. 运行 `flutter gen-l10n`（`flutter pub get` 也会触发，因为 `flutter: generate: true`）。
4. 在组件中使用 `context.l10n.<key>`；需要参数时使用生成的带参方法。
5. 提交生成文件，保证 CI/新克隆无需先跑 codegen。

## 5. 动态参数与复数规则

* 数量、时间、百分比、文件大小都必须走 ARB，不允许手工拼接单位。
* 英文必须区分单复数，例如 `1 word / 2 words`、`1 minute / 5 minutes`。
* 中文不区分单复数时保留同一句式，例如 `{count} 个单词`。

## 6. 结构化错误与状态

* `lib/core/errors/app_error.dart` 定义 `AppErrorCode`（语言无关）。
* 业务层（会话、服务）只抛/存**代码**或结构化数据，UI 通过 `describeAppError(l10n, code)` 得到句子。
* 已经移除的字符串判断（示例）：
  * `(_error ?? '').contains('远程数据文件已被删除')` → `_remoteMissing` 布尔标记 + `SyncRemoteMissingException` 类型判断。
  * `e.message.contains('词书已被删除')` → `e.code == AppErrorCode.wordListDeleted`。
* 服务层不再返回展示用句子：`WordIntakeResult.describe()` 已删除，改为 `describeIntake(l10n, result)`；`protectiveBackupFailure` 返回 `AppErrorCode?`。

## 7. 语言设置与既有用户兼容

* 持久化：`<application support>/app_language`，内容为 `system` / `zh` / `en`。
* 启动顺序：`main()` 在 `runApp` 前读取该文件（有超时保护），因此已有用户不会看到界面语言闪变。
* 默认值规则：
  * 有记录 → 使用记录；
  * 无记录但学习数据库 `materialword.sqlite` 已存在 → 视为**从旧版本升级**，保持简体中文；
  * 无记录且无数据库 → **新安装**，跟随系统。
* 语言解析：`zh-*`（含繁体系统）→ 简体中文；未翻译语言 → 英文；不新增未翻译的繁体资源。
* 切换只改 `MaterialApp.locale`，不重建数据层：当前路由、学习进度、正在进行的同步、词书选择、主题与强调色全部保留。

## 8. 共享数据与设备设置的边界

* 同步载荷、备份的「共享设置」不包含语言；语言只影响本机界面。
* 两台设备可使用不同语言，互不影响。
* 界面语言不作用于学习内容：单词、释义、例句、笔记、标签、词书名、导入文本一律保持原样。

## 9. 强调色

* 23 个预设，顺序与 HEX 与需求一致（11 经典 + 12 Material）。
* 稳定 ID：`classic.clearSkyBlue`、`material.blue` 等；颜色本身以 `#RRGGBB` 持久化，因此预设增删不影响用户已选颜色。
* 旧版本 ID（`blue`、`teal`…）仍被 `parseAccent` 识别，映射到旧值，不会把升级用户切到新配色。
* 默认色仍是经典蓝 `#1565C0`；「恢复默认颜色」行为不变。
* 前景色对比度沿用 `AppTheme.onColor`（按背景亮度选择白/黑），AppBar 标题、返回图标、按钮、FAB 与 InkRipple 均使用同一逻辑。
* 认识/模糊/不认识、正确/错误、警告、危险操作颜色与强调色完全分离。

## 10. 跨平台与回归

* 本地检查：`flutter analyze`、`flutter test`、`dart format`、`git diff --check`。
* CI（`.github/workflows/ci.yml`）在 analyze 前执行 `flutter gen-l10n`，确保 ARB 是唯一真源。
* 已知的尺寸风险点（英文更长）：设置项副标题、同步页字段标签、统计页 StatBlock、学习结果页按钮行——均已使用 Flexible/Expanded/Wrap 或可换行文本。

## 11. 测试与构建状态

* 新增 `test/phase6_3_localization_test.dart`：ARB 键集合/占位符一致性、复数、枚举持久化值、
  文案不参与业务判断、语言入口位置、语言切换、`跟随系统` 解析、强调色 23 项与 HEX/顺序、
  对比度 ≥ 4.5、语义色隔离、危险操作文案准确性、界面文案不含原始异常。
* 既有测试按本次合法的文案与颜色变化更新：旧文案断言、`AppDestination` 稳定 ID、
  错误代码断言、23 个色板后的滚动、深色主题 golden。
* 未通过项与原因以 CI 结果为准，见最终交付说明。

## 12. 尚未完成 / 已知限制

1. **强调色数量与需求表格不一致（需产品确认）**：需求颜色表为 11 经典 + 12 Material = 23，
   而同一份需求的验收/测试条目写作 25 / 13。实现按**明确给出的 HEX 与顺序**交付 23 个，
   未猜测补齐；补充另外两个颜色只需在 `lib/app/theme.dart` 的两个常量列表中各加一项并补两个 ARB 名称。
2. **服务层仍保留中文技术文案**（`sync/webdav_sync_provider.dart`、`github_sync_provider.dart`、
   `import_service.dart`、`backup_service.dart` 等，约 370 条）。这些字符串不再展示给用户：
   普通界面的用户提示已改为 `AppErrorCode` / 结构化结果 + ARB，服务层文案只进入诊断日志。
   若要英文诊断日志，需逐条改为英文技术描述（不影响界面正确性）。
3. **旧版本已持久化的「最近同步结果」是中文句子**：新写入为 `{"outcome": ...}` 结构化 JSON，
   读取时旧值原样显示（兼容优先）。首次同步后即被新格式覆盖。
4. **英文文案未做母语者终审**（944 条）。术语、句式与大小写已统一，仍建议人工通读一次。
5. **人工视觉回归未完成**：320–1600 逻辑宽度 × 中/英 × 浅/深 的逐页截图核对尚未执行；
   目前依赖代码层面的 Flexible/Expanded/Wrap 与自动化布局断言。真机抽查需在三平台产物生成后进行。
6. **坚果云真实 WebDAV 服务测试**仍待用户验证（Phase 6.2 遗留，本阶段未触碰同步协议）。
7. 词典的考试标签（中考/高考/考研…）与词条释义属于**词典内容**，按 D6 不做翻译。

## 13. 相关文档

* `docs/ui/copywriting-guidelines.md` — 文案写作规范
* `docs/ui/localization-glossary.md` — 中英文术语表（含 23 个强调色名称与 HEX）
* `docs/ui/copy-inventory.md` — 逐条文案迁移清册（944 条，由 `tool/gen_copy_inventory.py` 生成）
