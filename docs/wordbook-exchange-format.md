# 词书交换格式（Word-book exchange format）

本文件是导出的**契约**。实现见 `lib/services/wordbook_export.dart`（写）与
`lib/services/import_service.dart`（读）。任何字段变更都必须同时更新本文件与
往返测试 `test/phase5_export_test.dart`。

## 三种格式的承诺不同

| 格式 | 用途 | 承诺 | 明确不包含 |
|---|---|---|---|
| TXT | 纯单词表 | 每行一个拼写 | 释义、音标、笔记、学习历史 |
| CSV | 电子表格 / 通用交换 | 词条**内容**（9 列），公式注入已中和 | 学习历史、收藏、标签，且带前导单引号时不是逐字无损 |
| JSON | MaterialWord 原生词书交换 | 全部词条内容 + 词书名称/描述，逐字无损 | 学习记录、状态、收藏、标签、同步凭据 |

完整学习数据只能通过**备份 JSON**（`kind = materialword-backup`）迁移，见
`docs/backup-and-recovery.md`。词书 JSON 与备份 JSON 是两种文档，导入器会明确拒绝
把备份当作词书导入。

## 字段协议

| 字段 | TXT | CSV 列 | JSON 键 | 说明 |
|---|---|---|---|---|
| 拼写 | ✔ | `word` | `word` | 必需；去首尾空格；大小写保留 |
| 音标 | — | `phonetic` | `phonetic` | 词典文本规范化 |
| 词性 | — | `partOfSpeech` | `partOfSpeech` | 别名 `part_of_speech` / `pos` |
| 中文释义 | 制表符/逗号后 | `translation` | `translation` | 别名 `meaning` |
| 英文释义 | — | `definition` | `definition` | |
| 例句 | — | `example` | `example` | 多行；别名 `sentence` |
| 短语 | — | `phrase` | `phrase` | 5D 新增 |
| 笔记 | — | `note` | `note` | 用户文本，永不规范化 |
| 考试标签 | — | `examTags` | `examTags` | 5D 新增；JSON 亦可为数组 |
| BNC 词频排名 | — | — | `bncRank` | 仅 JSON，整数 |
| COCA/FRQ 排名 | — | — | `frqRank` | 仅 JSON，整数 |

不导出的字段：`id`、`customized`、`revision`、`source`、`createdAt`、`updatedAt`、
`deletedAt`、`aliases`、`fieldVersions`。它们是本地身份与同步记账，不是词条内容；
`source` 是本地来源标记，导入时统一写为 `import`。

## JSON 文档结构（v2）

单词书：

```json
{
  "kind": "materialword-wordbook",
  "schemaVersion": 2,
  "exportedAt": "2026-11-25T06:00:00.000Z",
  "name": "CET-6 核心词",
  "description": "可选",
  "wordCount": 2,
  "words": [
    {
      "word": "abandon",
      "phonetic": "əˈbændən",
      "partOfSpeech": "v.",
      "translation": "放弃；抛弃",
      "definition": "to leave somebody behind",
      "example": "They abandoned the plan.\nHe abandoned hope.",
      "phrase": "abandon oneself to",
      "note": "第一章笔记",
      "examTags": "cet6 cet4",
      "bncRank": 3211,
      "frqRank": 940
    }
  ]
}
```

多词书（`encodeBooks`）：

```json
{
  "kind": "materialword-wordbook",
  "schemaVersion": 2,
  "books": [
    {"name": "书一", "description": "", "wordCount": 1, "words": [ ... ]},
    {"name": "书二", "description": "", "wordCount": 2, "words": [ ... ]}
  ]
}
```

多词书 CSV 在首列增加 `book`，其余列不变；没有 `book` 值的行归入文件名对应的词书。
TXT 多词书导出会去重成一个拼写列表（TXT 无法表达归属）。

### 历史兼容

- `schemaVersion` 1（只有 `name` + `words`）仍可导入。
- 更早的**裸数组** `[{...}]` 仍可导入（`WordBookExporter.encode` 的 JSON 输出）。
- `schemaVersion > 2` 明确拒绝，不猜测含义。
- 旧字段别名（`pos`、`part_of_speech`、`meaning`、`sentence`、`exam_tags`）继续接受。

## 导入语义（与 5B 的统一入口一致）

1. 文件中提供的非空字段视为**内容**：新建词条时全部写入并标记 `customized`。
2. 已存在的词条：内容只填充**空字段**，不覆盖本机已有的释义、笔记与进度。
3. 已删除（墓碑）词条：普通导入视为用户明确的重新添加，恢复原 UUID 与学习记录；
   在线词书刷新不恢复它们。
4. 目标词书与词条写入在**同一个事务**中完成；失败时全部回滚。
5. 超过 20 000 条直接拒绝（不静默截断），文件内重复只计一次。

## CSV 安全

导出时以 `=`、`+`、`-`、`@`、Tab、CR 开头的单元格会加前导单引号，防止 Excel /
Numbers / LibreOffice 执行公式。这是导出侧的安全措施：

- 导入时**不会**盲目删除前导单引号（那会篡改用户原文），所以含危险前缀的内容经过
  CSV 往返会多一个引号；
- 需要逐字无损时使用 JSON；
- 数据库中的值永远不被这条规则修改。
