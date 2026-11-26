# 词库来源与资源边界

核查日期：2026-11-26。学习词书决定学哪些词，释义词典提供查词内容；二者分开管理。

| 资源 | 固定版本 | 条目 | 字节 | 许可 |
|---|---|---:|---:|---|
| 默认 ECDICT core | 39cfb9672c0906b63569e0453c2e6abfb9ab182a | 57,835 | 12,742,656 | MIT |
| 可选 ECDICT extended | 同上 | 722,442 | 96,681,984 | MIT |

扩展下载 gzip 为 39,539,385 字节；两个层级均固定 SHA-256，见资源旁 meta.json。
扩展数据发布在本仓库资源提交 51d27bb，运行时使用该固定提交，不追踪可变 main。
资源不含用户笔记；用户库更新只走既有 intake 流程，已学习词条不因卸载词典被删除。
默认资源由 26,282 条/6,307,840 字节扩至以上规模，旧有 IELTS/TOEFL 等标签并非本次新引入。
构建保留 exchange 词形字段；core 用考试标签及频率阈值，extended 用有释义、受支持拼写和长度的词条。

来源：[ECDICT](https://github.com/skywind3000/ECDICT/tree/39cfb9672c0906b63569e0453c2e6abfb9ab182a)，
[数据许可](https://github.com/skywind3000/ECDICT/blob/39cfb9672c0906b63569e0453c2e6abfb9ab182a/LICENSE)。
许可原文保留在 assets/dictionary/ECDICT_LICENSE.txt 和 resources/dictionaries/ECDICT_LICENSE.txt。
考试词书来自社区标签，不声称是最新官方完整词表。预览显示前十条，添加实际全部标签词条。

## 其他来源评估

- [Open English WordNet](https://github.com/globalwordnet/english-wordnet#license)：上游声明 CC BY 4.0，
  有词义关系与独立的 Namenet/Plus 层级，需要按义项保留来源。本次不将其关系图压成单一中文释义，不打包。
- [Kaikki 原始数据](https://kaikki.org/dictionary/rawdata.html)：当前页面给出 2026-10-01 Wiktionary dump，
  原始 English edition 24.8 GB（含多语言）；[English 页面](https://kaikki.org/dictionary/English/)显示独立处理后的词义内容。
  需要逐项核对 Wiktionary 文本、附加来源与媒体的署名/许可边界，不能用提取器的代码许可替代数据许可。本次不分发。
- [KyleBing/english-vocabulary](https://github.com/KyleBing/english-vocabulary) 和
  [kajweb/dict](https://github.com/kajweb/dict)：仓库存在不等于第三方数据具备统一再分发授权；
  本次没有为每个来源文件取得完整出处和授权证据，因此不作为默认或可下载资源。

## 备份与迁移

协议 v6 保存扩展词典来源、版本、摘要、启用状态及独立版本计数；本机已下载文件状态不共享。
学习词书自身含实际词条、归属和进度，不仅是链接。普通备份不塞入大型只读数据库；恢复缺失资源时
提示前往词库页安装。词典启停不会覆盖用户内容，也不把不同来源释义混成一段文本。

完整离线迁移另行导出 backup.json、默认词典、启用的扩展数据库、MIT 原文和带摘要 manifest。
上限 200 MiB，只接受应用生成的不压缩 ZIP；恢复前核对全部文件、固定版本和摘要，随后走保护性备份、
事务快照恢复和暂停同步流程。不同默认词典版本明确拒绝，不能伪报完整。移动设备上的大包内存峰值仍待真机验收。
