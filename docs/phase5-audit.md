# Phase 5 审计（5A）

本文件记录 Phase 5 开始时的**实测**状态，以及据此确认的缺陷清单。所有数字来自
本机实际执行，不采信历史文档自述。

## 5A-01 实际代码状态

| 项 | 实测值 |
|---|---|
| 远程 main HEAD（`git ls-remote origin main`） | `7429182c6f396cb0cd0fb7806590f6c961cd2887` |
| 本地分支 | `main`，跟踪 `origin/main`，与远程一致 |
| 工作树 | 干净（`git status --porcelain` 无输出），无其他 Agent 的未提交修改 |
| 最近提交 | `7429182 docs: phase 4 delivery report for a736482` |
| 最近成功构建源码 | `a7364823f288317dcd168e91074ed5300bc0d75c`（CI run 45556847283，四 job 全绿） |
| 版本 | `1.2.0+3`（`pubspec.yaml`） |
| 数据库 Schema | 3（`AppDatabase.currentSchemaVersion`） |
| 备份协议 | 3（`backupSchemaVersion`，Phase 5 之后见 5E） |
| Flutter / Dart | 3.50.1 stable / 3.14.0 |
| lib / test Dart 文件 | 59 / 55（Phase 5 开始时） |

任务书给出的 HEAD（`7429182c…`）与实测一致，说明期间没有其他 Agent 的后续提交。
`a736482` 是最近一次三平台构建成功的源码提交，而 `7429182` 只增加交付文档。

## 5A-02 回归基线

执行顺序：`flutter pub get` → `dart run build_runner build` → 格式 → 分析 → 测试。

| 命令 | 结果 |
|---|---|
| `flutter pub get` | 成功 |
| `dart run build_runner build` | 成功（224 outputs；本机冷启动约 28 分钟，属 drift 生成器编译开销） |
| `dart format --output=none --set-exit-if-changed lib test` | 109 文件，0 需要修改 |
| `flutter analyze` | No issues found |
| `flutter test` | **341 通过、2 跳过、0 失败** |
| `tool/verify_timezone_replay.sh` | 香港进程 + 纽约进程各 1 项通过 |

2 项跳过的原因（`test/macos_packaging_test.dart`）：

- `未构建 macOS 产物（CI 的 macos job 会先构建再执行本测试）`
- `未构建 macOS 产物，跳过 ZIP 复验`

这是平台条件跳过，在 CI 的 `macos` job 中实际执行。

## 5A-03 确认仍然存在的缺陷

审计方法：逐条阅读任务书列出的代码位置，与实际源码比对；不依赖文档中的复选框。

| 编号 | 任务书描述 | 源码证据 | 结论 |
|---|---|---|---|
| D5-01 | 删除后无法重新新增 | `quick_add_page.dart` 用 `byNormalized(includeDeleted: true)` 找词，命中已删除词条后调用 `updateContent()`；后者在 `word_repository.dart` 中 `if (existing.deletedAt != null) throw StateError('词条已删除，请通过重新添加恢复')` | **确认存在**：UI 直接报错，用户无法恢复 |
| D5-02 | 导入只恢复关联不恢复词条 | `import_service.dart commit()`：找到（含已删除）词条后只调 `applyDictionaryInfo`（该方法对 `deletedAt != null` 直接返回原行）再 `addWords` | **确认存在**：墓碑词条仍不可见 |
| D5-03 | 新增逻辑分散在多个页面 | 快速添加、批量粘贴、文件导入、词典页各自实现查重/恢复/关联 | **确认存在**：四套近似逻辑，语义不一致（词典页对已删除词条只加关联） |
| D5-04 | 导入建书与写词不在同一事务 | `import_page.dart _commit()` 先 `ensureBook()`，再 `ImportService.commit()`（内部另开事务） | **确认存在**：失败会残留空词书 |
| D5-05 | 超限静默截断 | `_parseTxt/_parseCsv/_parseJson` 中 `if (entries.length >= maxEntries) break;` | **确认存在**：20001 行文件被当作全部导入 |
| D5-06 | 编码错误被静默替换 | `parseFile`/`fetchUrl` 使用 `Utf8Decoder(allowMalformed: true)` | **确认存在**：损坏字符被替换为 U+FFFD 后入库 |
| D5-07 | 在线下载不限制内存 | `fetchUrl` 用 `http.get()` 下载完整响应，再比较 `content.length`（UTF-16 码元，不是字节） | **确认存在**：8 MB 限制既不准确也不防内存峰值 |
| D5-08 | CSV 导入不认识 `partOfSpeech` | 导入只看 `pos` / `part_of_speech`；导出写 `partOfSpeech` | **确认存在**：自家 CSV 往返丢词性 |
| D5-09 | `ParsedEntry` 缺 `phrase` / `examTags` | 结构体只有 7 个字段；CSV 列也没有这两列 | **确认存在**：导出/导入丢字段 |
| D5-10 | 备份写入非原子 | `writeBackupFile` 直接 `file.writeAsString(json, flush: true)` | **确认存在**：中断可截断最后一份备份；同秒备份同名覆盖 |
| D5-11 | 恢复副本只能导出/删除 | `backup_page.dart` 的副本菜单只有 `export` / `delete` | **确认存在**：灾难恢复必须绕道文件选择器 |
| D5-12 | 无自动备份 | 只有手动保存，保留策略硬编码在页面内（`files.skip(5)`） | **确认存在** |
| D5-13 | 无保护性备份 | 批量删除/重置前没有快照 | **确认存在** |
| D5-14 | 缺少同步状态区分 | `SyncStage` 只有 9 个阶段；上传失败被包装为普通失败，"本机已合并"的信息丢失 | **确认存在** |
| D5-15 | 前台无法发现远端变化 | `AutoSyncService` 只监听本机表变更与生命周期；`change` 触发器在无本机修改时直接返回 | **确认存在**：另一台设备的修改要等重启或手动同步 |
| D5-16 | 冲突无可追溯记录 | `ContentSyncRepository.merge` 只返回 `conflict` 布尔 | **确认存在**：被淘汰的内容无法找回 |
| D5-17 | 远端文件被删除会被静默重建 | `download()` 返回 null 时直接进入上传分支 | **确认存在**：等同于把"文件被删"当作"尚未创建" |
| D5-18 | 词条合并 N+1 | `mergeDataset` 每词执行 `resolve`（2 次查询）、`byNormalized`、`remember`（逐条查询）、`versions` | **确认存在**：Phase 4 分段计时中 `words` 段约 2 967 ms |

## 证据等级约定

`docs/phase5-verification.md` 与 `docs/phase5-acceptance-matrix.md` 严格区分：

- **源码**：代码已实现并可指认位置；
- **自动**：`flutter test` / 脚本实际执行通过；
- **构建**：CI 或本地实际产出三平台产物；
- **真机**：真实设备上人工确认；
- **真实服务**：真实 GitHub 私有仓库 / 真实 WebDAV 联调。

只有**自动**、**构建**、**真机**、**真实服务**可以标记为通过；源码实现本身不构成验证。
