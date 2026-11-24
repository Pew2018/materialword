# 数据交换与同步协议（schemaVersion 2）

代码：
- `lib/services/backup_service.dart` — 构建、校验、合并数据快照
- `lib/services/sync/sync_coordinator.dart` — 统一同步流程与互斥
- `lib/services/sync/{local_file,github,webdav}_sync_provider.dart` — 三种传输
- `lib/services/sync/credential_store.dart` — 系统安全凭据存储

测试：`test/sync_test.dart`、`test/sync_transport_test.dart`、`test/migration_and_settings_test.dart`

## 1. 数据快照

```json
{
  "schemaVersion": 2,
  "kind": "materialword-backup",
  "datasetId": "<安装时生成一次，之后永不变化>",
  "deviceId": "<设备标识，仅用于归因作答事件>",
  "exportedAt": "...",
  "words": [
    {"id": "uuid", "word": "abandon", "normalized": "abandon",
     "revision": 2, "updatedAt": "...", "deletedAt": null,
     "translation": "真实换行\n第二行", "note": "用户原文"}
  ],
  "wordBooks": [{"id": "uuid", "name": "...", "revision": 1, "deletedAt": null}],
  "entries": [{"wordBookId": "...", "wordId": "...", "version": 2,
               "updatedAt": "...", "deletedAt": null}],
  "reviewEvents": [{"id": "uuid", "wordId": "...", "deviceId": "...",
                    "answeredAt": "...", "result": 0, "type": "review",
                    "mode": "normal|special-*|manual-mastered|reset"}],
  "settings": {"dailyNewTarget": 30, "dailyReviewLimit": 100, "studyMode": "mixed"}
}
```

- `datasetId` 稳定；`exportedAt` 只是审计信息。
- `contentHash = sha256(words, wordBooks, entries, reviewEvents, settings)`，
  **不包含** `exportedAt` / `deviceId` / `appVersion`：没有实质变化就没有"假同步"。
- 词典字段在导出、导入、合并三处统一经过 `normalizeDictionaryText`（字面 `\n`、`\r\n`、
  尾随空白）；`note` 永远原样保存。

## 2. 身份映射（P0 前置修复）

不同设备独立创建同一个 `abandon`，UUID 必然不同。合并时：

1. 以 `normalized`（小写、折叠空白）为唯一身份；
2. 建立 `remoteWordId → canonicalWordId` 映射；
3. 所有 `entries.wordId` / `reviewEvents.wordId` 先经过映射再写库；
4. 本地行永远保留自己的 UUID，任何关联都不会指向不存在的远程 ID。

两台设备各自学习同一个词后，最终只有**一个词条、两条独立的原始作答事件**，
学习状态由事件重算。绝不按词形变化合并不同词条。

## 3. 删除、修改与冲突规则

| 情况 | 规则 |
| --- | --- |
| 词条内容不同 | `(revision, updatedAt)` 大者胜；双方都 `customized` 时在合并报告提示冲突数 |
| 删除 vs 编辑 | 删除时间更晚 → 删除胜；编辑时间更晚 → 复活 |
| 词书同名但 UUID 不同 | 按名称（未删除）合并到同一本书 |
| 词书关联移除 | 写墓碑 `deletedAt + version+1`，旧备份不会让它复活 |
| 删除后重新加入 | 版本继续递增，形成确定状态 |
| 设备时钟偏差 | 先比 revision，再比时间戳；完全相同时按 `(deviceId, id)` 稳定排序 |
| 作答事件 | 按事件 ID 去重，全部保留，不按时间戳丢弃 |
| 用户内容冲突 | 保留可重放的事件，报告冲突数，不静默删除任一方派生数据 |

删除是**墓碑**而非物理删除：旧备份、旧设备都不会让已删除内容复活。

## 4. 学习状态一致性

`learning_states` 完全派生于 `review_events`：

- 合并事件与状态重建在**同一个 SQLite 事务**内完成；中途崩溃整笔回滚。
- `markPendingRebuild()` / `recoverPendingRebuild()` 提供额外崩溃恢复兜底。
- 重放顺序 `(answeredAt, deviceId, id)`，相同时间戳也有稳定顺序。
- `mode = reset` 事件重放时清空此前累计；`manual-mastered` 记录为一次真实 `known` 作答。
- 同步期间本地新产生的事件会包含在合并后的快照中。
- `algorithmVersion` 随事件存储；本阶段算法版本仍为 1。

## 5. 共享设置与设备专属设置

- **共享**：`dailyNewTarget`、`dailyReviewLimit`、`studyMode`。仅在接收方尚无学习数据时首次采用。
- **设备专属**：`themeMode`、`accentColor`、TTS 选项、当前词书、同步配置与凭据，不会被远程覆盖。

## 6. 同步协调器流程

单次同步互斥，严格顺序：

1. 校验配置与连接；
2. 下载远程快照和版本 token；
3. 校验 `kind` / `schemaVersion` / 结构；
4. 内容哈希相同 → 不合并、不上传；
5. 事务内合并 + 重建派生状态；
6. 重新构建统一快照并计算哈希；
7. 与远程哈希相同 → 不上传；
8. 带条件版本上传（blob SHA / ETag / 本地文件哈希）；
9. 读回校验；
10. 保存 `lastSyncAt` / 结果 / 哈希并刷新 UI。

冲突时重新下载、重新合并、重试，最多 3 次；**绝不强制覆盖**。超时、认证失败、
限流、断网、远程文件不存在均返回可操作错误；日志不打印凭据。

## 7. 各传输的能力边界

| 传输 | 版本条件 | 凭据 | 限制 |
| --- | --- | --- | --- |
| 本地文件 | 内容 SHA-256；临时文件 + 原子 rename；保留 `.bak` | 无 | Android SAF / iOS 外部目录无长期授权时采用手动导入导出 |
| GitHub REST Contents | blob SHA（PUT 携带 `sha`） | Fine-grained PAT，仅存 Keychain/Keystore | 建议独立私有仓库；公开仓库提醒隐私风险；单文件建议 < 4 MB；受 API 限流约束 |
| WebDAV | `ETag` + `If-Match` / `If-None-Match`，412 重新合并 | 用户名/密码存安全存储 | 只允许 HTTPS；不关闭 TLS 校验；跨域重定向拒绝携带认证；无 ETag 时明确限制自动同步 |

同一时间只启用一种 Provider。首次连接已有远程数据先确认合并行为；没有全量覆盖按钮。

## 8. v1 → v2 迁移

纯增量、无损：新增 `word_book_entries.{version,updated_at,deleted_at}`、
`word_books.revision`、`study_settings.{accent_color,tts_*}`、`review_events.mode`。
不删除列或行，数据完整保留；旧的字面转义词典字段在升级时一次性修复。

## 9. 测试覆盖

SYNC01 独立设备同词、SYNC02 ID 映射后事件完整、SYNC03 删除不被复活、SYNC04 删除后重加、
SYNC05 幂等、SYNC06 往返一致、SYNC07 中断恢复、SYNC08 同步期间本地写入、
SYNC09 损坏数据、SYNC10 GitHub SHA 冲突、SYNC11 WebDAV ETag 冲突、
SYNC12 认证/超时/断网、SYNC13 凭据不入备份、SYNC14 无变化不上传、SYNC15 写文件失败保留旧文件。
全部使用内存数据库、可控时钟与 Mock HTTP，未连接真实服务。
