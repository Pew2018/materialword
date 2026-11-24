# 数据交换与同步协议

代码：`lib/services/backup_service.dart`、`lib/services/sync/sync_provider.dart`
测试：`test/backup_test.dart`（T13–T16）

Phase 1 的"同步"= **导出 JSON → 自己传文件 → 在另一台设备导入合并**。
协议从第一天就按"以后要接 GitHub / WebDAV"设计，所以现在就把版本号、设备 ID、
删除墓碑、幂等规则定好。

## 文件形态

```json
{
  "schemaVersion": 1,
  "kind": "materialword-backup",
  "exportedAt": "2026-11-24T13:30:00.000Z",
  "datasetId": "8d0f…",
  "deviceId": "c1f2…",
  "appVersion": "1.0.0",
  "words": [
    {
      "id": "b2…",
      "word": "abandon",
      "normalized": "abandon",
      "phonetic": "əˈbændən",
      "partOfSpeech": "v:98/n:2",
      "translation": "v. 放弃",
      "definition": "to leave behind",
      "example": "",
      "phrase": "",
      "note": "常与 plan 搭配",
      "source": "manual",
      "examTags": "cet4 cet6 ky",
      "bncRank": 2149,
      "frqRank": 1877,
      "customized": true,
      "revision": 3,
      "createdAt": "2026-11-20T02:11:00.000Z",
      "updatedAt": "2026-11-24T11:02:00.000Z",
      "deletedAt": null
    }
  ],
  "wordBooks": [
    {
      "id": "f1…",
      "name": "CET-6 核心词",
      "description": "",
      "sourceType": "file",
      "sourceUrl": "",
      "createdAt": "…",
      "updatedAt": "…",
      "deletedAt": null
    }
  ],
  "entries": [
    { "wordBookId": "f1…", "wordId": "b2…", "addedAt": "…" }
  ],
  "reviewEvents": [
    {
      "id": "5c…",
      "wordId": "b2…",
      "deviceId": "c1f2…",
      "answeredAt": "2026-11-24T12:59:00.000Z",
      "localDay": "2026-11-24",
      "result": 2,
      "type": "study",
      "stageBefore": 0,
      "intervalDaysAfter": 1,
      "algoVersion": 1
    }
  ],
  "settings": {
    "dailyNewTarget": 30,
    "dailyReviewLimit": 100,
    "currentWordBookId": "f1…",
    "studyMode": "mixed",
    "themeMode": "system"
  }
}
```

字段约定：

- 时间一律 **UTC ISO-8601 字符串**；`result` 用整数 `0 不认识 / 1 模糊 / 2 认识`；
- `type` 只能是 `study` / `review`；
- `normalized` 是小写、去空白后的查询键，用来判定"同一个词"；
- `revision` + `updatedAt` 共同决定词条冲突；
- `deletedAt` 非空即墓碑，**不会被丢弃**，这是删除能跨设备生效的唯一办法。

**不包含**：GitHub Token、WebDAV 密码、任何凭据。词典原始数据也不在备份里（体积大且可重建）。

## 导入校验

`BackupService.decodeDataset` 在**读文件阶段**就拒绝：

| 情况 | 结果 |
| --- | --- |
| 不是 JSON / 根节点不是对象 | `BackupException` |
| 缺 `schemaVersion` | `BackupException` |
| `schemaVersion > 1` | `BackupException`（版本过新，提示升级） |
| `kind` 存在但不等于 `materialword-backup` | `BackupException` |
| `words` / `wordBooks` / `entries` / `reviewEvents` 不是数组 | `BackupException` |

整个合并跑在**一个事务**里；任何异常都会回滚，本地数据保持原样（T16）。

## 合并规则

| 数据 | 规则 |
| --- | --- |
| `reviewEvents` | 按 `id` 插入，已存在就跳过。历史只增不改 → 重复导入天然幂等（T15） |
| `words` | 按 `normalized` 找本地词条：不存在则插入；存在则比较 `(revision, updatedAt)`，仅当**远端更新**时覆盖内容与 `deletedAt`，否则保留本地 |
| `wordBooks` | 按 `id` 匹配，`updatedAt` 较新者胜 |
| `entries` | 主键去重后插入；引用的词条/词书不存在则跳过并计入 `skippedEntries` |
| `settings` | **保留本地**（设备偏好不该被别的设备覆盖），界面会说明 |
| `learning_states` | 不直接合并，而是对"收到新事件的词"调用 `rebuildStateFromEvents()` 用合并后的完整历史重算 |

设计意图：**学习状态是派生数据，历史才是事实**。这样即使两台设备的算法版本不同、
或者本地状态被写坏，合并后依然能得到唯一正确的结果。

冲突无法自动处理时（例如两边都改过同一个词条且 `revision` 相同但内容不同）：
按 `updatedAt` 取较新的一方，并保留 `revision` 较大值，不静默丢词条——
被覆盖的旧内容仍在对方的备份文件里，用户可以再次合并回来。

## 幂等性

同一份备份导入 N 次，结果与导入 1 次相同：

- 事件按 ID 去重；
- 词条按 `normalized` 去重；
- 关联按复合主键去重；
- 统计从事件聚合，不累加计数器。

T15 用"连续导入两次后词条数、事件数、正确次数都不变"来验证这一点。

## 同步接口

```dart
abstract class SyncProvider {
  String get id;
  String get label;
  bool get isImplemented;                 // 未实现的 Provider 必须为 false
  Future<SyncTestResult> testConnection();
  Future<SyncPayload?> download();        // 远端没有数据时返回 null
  Future<SyncUploadResult> upload(Map<String, Object?> dataset, {String? ifRevision});
}
```

| Provider | 状态 |
| --- | --- |
| `LocalFileSyncProvider` | **已实现**：读写同一个 JSON 文件，`revision` 用文件 mtime，可选乐观并发检查 |
| `GitHubSyncProvider` | 未实现（`isImplemented == false`），调用会抛 `SyncException` |
| `WebDavSyncProvider` | 未实现（同上） |

界面上未实现的 provider 显示「未实现」并且没有可点的操作，不会假装能用。

## GitHub 同步（下一阶段）

- GitHub REST API，目标为**独立的私有数据仓库**（不要写进源码仓库），用户指定分支与文件路径；
- 认证用最小权限 Fine-grained PAT（仅 `contents: read/write`），Token 只存系统安全存储
  （Android Keystore / Apple Keychain），绝不进备份文件、绝不打日志；
- 并发控制：读取文件时拿到 `sha`，上传时带上 `sha`；409/422 视为冲突 → 重新下载、
  重新合并、有限次重试（最多 3 次），绝不强推覆盖；
- 提交信息带设备 ID 与数据集摘要，方便回溯。

## WebDAV 同步（下一阶段）

- 仅 HTTPS；服务器地址、用户名、密码、目标目录；
- 用 `If-Match` / `ETag` 做条件请求，`412 Precondition Failed` 视为冲突并重试合并；
- 关闭证书校验的行为**一律不提供**；
- 网络失败时本地修改保留在本地库，等待下次手动同步。

## 共同约束

- 离线永远可用：网络代码不得在启动路径或学习路径上；
- 第一版只做**用户主动触发**的同步，不做后台自动同步；
- 同一时间只启用一个远程 provider，避免 GitHub 与 WebDAV 互相覆盖；
- 界面展示：最近同步时间、状态、错误信息。
