# MaterialWord

离线优先的英语词汇学习应用，使用 Flutter、Riverpod、Drift 和经典 Material Design 2。
支持 Android、iOS、macOS；学习记录可通过本地备份、S3/WebDAV 单向云备份或双向同步迁移。
系统 TTS 提供发音，实际语音由设备安装情况决定。

## 词书与词典

**学习词书**决定学哪些词；**释义词典**提供音标、释义和词形，两者分开管理。
在词书页进入「词库与词典」：

- 默认内置 ECDICT：**57,835 条，12,742,656 字节**，无需首次联网即可查词。
- 可预览、添加 CET-4、CET-6、考研、IELTS、TOEFL、GRE、中考和高考社区标签词书。
  这些标签原先已存在，本次提供选择入口；不是最新官方完整词表。预览显示前十条。
- 可选 ECDICT Extended：**722,442 条**；下载 **39,539,385 字节（37.71 MiB）**，
  安装后 **96,681,984 字节（92.20 MiB）**。支持下载续传、失败重试、安装、启用、停用和卸载。
  下载及展开后的文件分别校验摘要；损坏包不会替换有效包。
- 扩展词典为单独的只读数据库，默认词典优先，扩展补充未收录内容；不覆盖用户笔记、自定义释义或学习进度。

两份 ECDICT 数据均固定至上游提交 `39cfb9672c0906b63569e0453c2e6abfb9ab182a`，MIT 许可。
构建保留 `exchange` 词形信息。规模、摘要、许可及其他来源评估见 [词库来源说明](docs/dictionary-sources.md)。
WordNet、Wiktionary/Kaikki 未作为本版资源；KyleBing、kajweb 的第三方数据未在授权链不明时打包。

## 导入与导出

词书页「导入」可选择本地 **TXT、CSV、JSON、学习 ZIP**，或提供 **HTTPS 链接**。
先解析并预览，再确认写入；取消预览不改变学习数据。普通词书文件上限 **8 MiB、20,000 条有效记录**，
超限拒绝。只读大型词典使用词库安装入口，不能当作普通词书导入。

默认导出均为**学习 ZIP 包**。选择 TXT、CSV 或 JSON 指的是包内内容文件的格式：

| 文件 | 内容 |
|---|---|
| `manifest.json` | 包版本、文件清单、范围、数量、大小与摘要 |
| `words.txt` / `words.csv` / `words.json` | 选择的词条内容格式 |
| `progress.json` | 所选词书实际内容、归属、稳定身份、事件、完整学习状态及相关收藏/标签 |
| `sources.json` | 来源、版本及署名信息 |

三种包均含进度；共享单词只保存一套事件和状态。未选中的词书和设备偏好不会夹带。
导入学习包时显示词书、单词和事件数量，默认**仅导入词书**，可开启**同时合并学习进度**。
开启后按包内词书归属合并，不替换全库、不清空其他词书。

首版仅接受应用生成的 **stored（不压缩）ZIP**；不要用压缩软件重新压缩。
最多四个普通文件，展开总计不超过 8 MiB（另允许 4096 字节 ZIP 开销）。读取前检查路径、
重复文件、数量、压缩方式、大小，再检查 CRC、摘要、版本、引用及状态一致性。

### 可直接使用的完整示例

以下文件全部通过实际解析和导入测试；学习包通过真实进度往返测试：

| 格式 | 示例 |
|---|---|
| 裸 TXT | [words.txt](examples/words.txt) |
| 单词书 CSV | [words.csv](examples/words.csv)，包含逗号、双引号与多行例句 |
| 单词书 JSON v2 | [wordbook.json](examples/wordbook.json) |
| 多词书 CSV | [wordbooks.csv](examples/wordbooks.csv) |
| 多词书 JSON v2 | [wordbooks.json](examples/wordbooks.json) |
| TXT 学习包 | [learning-txt.zip](examples/learning-txt.zip) |
| CSV 学习包 | [learning-csv.zip](examples/learning-csv.zip) |
| JSON 学习包 | [learning-json.zip](examples/learning-json.zip) |

TXT 每行一个英文词，也接受制表符后的释义；`#` 开头的行作为注释：

```text
alpha
beta
```

CSV 必须有 `word` 表头。字段含逗号、双引号或换行时用双引号包裹，内部双引号写两次：

```csv
word,translation,example,examTags
alpha,开端,"He said ""alpha"", then left.
cet4 practice.",cet4 ielts
beta,测试版,Try the beta version.,toefl
```

单词书 JSON：

```json
{
  "kind": "materialword-wordbook",
  "schemaVersion": 2,
  "name": "Everyday",
  "description": "日常词汇",
  "words": [
    {"word": "alpha", "translation": "开端", "examTags": "cet4 ielts"},
    {"word": "beta", "translation": "测试版", "note": "我的笔记"}
  ]
}
```

多词书 CSV 用 `book` 列表示归属，同一个单词可出现在不同词书中：

```csv
book,word,translation
Everyday,alpha,开端
Travel,alpha,开端
Travel,journey,旅程
```

多词书 JSON：

```json
{
  "kind": "materialword-wordbook",
  "schemaVersion": 2,
  "books": [
    {"name": "Everyday", "words": [{"word": "alpha", "translation": "开端"}]},
    {"name": "Travel", "words": [{"word": "alpha"}, {"word": "journey", "translation": "旅程"}]}
  ]
}
```

文件使用 **UTF-8**，UTF-16 和损坏编码会拒绝。CSV 的字段别名：`pos`/`part_of_speech`
对应 `partOfSpeech`，`meaning` 对应 `translation`，`sentence` 对应 `example`，
`exam_tags`/`tags` 对应 `examTags`，`wordbook`/`bookname` 对应 `book`。
JSON 也接受历史字段别名、裸词条数组和 v1 词书；JSON `examTags` 可为字符串或字符串数组。

考试标签使用 `zk gk cet4 cet6 ky ielts toefl gre` 等空格分隔值。
同书重复词条去重；不同词书共享单词身份并保留各自归属。普通导入只补齐已有词条的空字段，
不覆盖非空释义、笔记和进度。普通明确导入可以恢复已删除词条，在线刷新不会擅自恢复。
CSV 导出对 `= + - @` 等公式前缀加单引号以防表格执行；逐字无损内容交换请用 JSON。
详细字段规则见 [交换格式](docs/wordbook-exchange-format.md)。

## 备份、同步与恢复

**裸内容文件**用于交换词汇，不保证携带学习进度；**学习包**用于迁移所选词书及进度；
**全量备份**保存整个学习库。备份文件可能包含笔记、收藏与个人学习历史，请妥善保管。

| 功能 | 保存/执行的内容 | 使用边界 |
|---|---|---|
| 本地备份 | 全库内容、事件、状态、收藏、标签、删除记录、身份、共享学习设置、词库选择 | 副本位于应用目录，重要副本应导出到应用外 |
| S3/WebDAV 单向云备份 | 上传独立命名、回读校验的全库备份，支持历史浏览及删除 | 不覆盖双向同步对象；上传不等于双向合并 |
| 双向同步 | 按身份合并内容、去重事件、重建进度及同步词库选择 | 保留现有条件写入与冲突保护；设备文件单独安装 |
| 合并恢复 | 找回旧词条及历史，与近期学习合并 | 不回退整个数据库，不按整行状态时间覆盖 |
| 快照恢复 | 回到指定快照的内容、事件、状态和共享学习设置 | 先做保护性备份，事务恢复；完成后暂停同步 |
| 完整离线迁移 | 全量快照、默认词典、启用的扩展词典本体及来源许可 | 词库页独立入口，stored ZIP，200 MiB 上限；需对应默认词典版本 |

同步/备份协议为 **v6**，数据库 Schema 仍为 **3**。新客户端兼容 v1–v5 历史文件；
旧文件没有状态时从事件重建。v5 起包含完整 `learningStates`、事件摘要和算法版本；
v6 新增共享词典选择清单。未知/过新协议、未知算法、损坏或不一致的状态整包拒绝。
旧客户端会拒绝新协议，避免忽略关键字段后覆盖远端。

合并以去重后的事件为准，按既有因果顺序重放，保留两台设备独立的学习；重置也是可传播事件。
快照恢复同时恢复经过验证的事件和状态，保留实际复习时间，不用旧状态覆盖近期独立学习。
详见 [协议](docs/sync-protocol.md) 与 [恢复规则](docs/backup-and-recovery.md)。

所有新数据出口排除主题、强调色、TTS 语音/语言/速度/自动发音、屏幕常亮偏好。
所有恢复入口忽略历史文件中的这些设备偏好。每日目标、复习上限、学习模式、冲刺计划继续共享。
连接配置、密码、Token、Access Key 和 Secret Key 不进入备份。
普通备份只保存大型词典的清单和摘要；恢复后若缺包会提示重新获取，不伪报完整离线恢复。

### 常见情景

- **手机和电脑离线各自学习**：联网后双向同步会合并双方事件；重复同步不重复增加计数。
- **换设备**：恢复备份得到学习进度和词书选择，新设备的外观、发音和常亮设置保留；缺失扩展词典可重新下载。
- **找回旧词条，同时保留近期学习**：使用合并恢复。
- **回到历史状态**：使用快照恢复，先生成保护性副本，完成后决定如何处理远端同步。
- **无网络搬迁**：在原设备导出完整离线迁移包，在新设备词库页恢复，包内携带所需词典数据库。

### 云端历史清理

历史页支持单条删除，以及「清理旧备份（保留最近两份）」。不会默认自动清理。
例如已有 A、B、C，新备份 D 上传并回读校验成功后，确认清理会保留 **D、C**，删除 **B、A**。
D 上传失败、内容损坏或结果不确定时，不能挤掉原有保留项；无法确认就停止清理。

清理读取 S3 全部分页；WebDAV 声明分页/截断/限制时停止，不猜测服务商私有分页方式。
确认前显示保留项、删除数量与可获取的总大小；确认后列表或目标变化会拒绝旧计划。
单条删除可以明确删除任意一份，包括最近两份。

删除后刷新确认：已删除、失败、部分成功、结果待确认分别报告。需要列举、读取和删除权限；
权限不足时不会声称全部成功。S3 开启版本控制时，普通 DELETE 通常只增加删除标记，
历史对象版本仍存在并可能计费；本版不清除全部历史版本。见 [删除边界](docs/cloud-backup-deletion.md)。

## 开发与验证

沿用仓库的 Flutter **3.50.1**、Dart **3.14**；不要为这些功能修改签名、Bundle ID 或版本号。

```sh
flutter pub get
dart run build_runner build
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter expanded
tool/verify_timezone_replay.sh
```

[Build 工作流](.github/workflows/ci.yml) 负责分析、测试和 Android/iOS/macOS 构建。
iOS CI 产物为**未签名 IPA/.app**，不能视为可直接安装的已签名 IPA。
真实设备、真实用户 S3/WebDAV 权限矩阵及大型离线包的移动设备内存峰值仍需真机验收，
Widget 渲染与本机 HTTPS 测试不替代这些验证。
