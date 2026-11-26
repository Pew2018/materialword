# Phase 6.3 — S3 双向同步

本文件只记录**实际做过的修改与验证**。计划中的功能不写进"已完成"；没有真实账号验证的部分
单独标注为未验证。

## 0. 一句话结论

S3 已作为与 WebDAV 并列的双向同步通道接入：`S3SyncProvider` 用 AWS Signature V4 发送
`If-None-Match: *`／`If-Match` 条件写入，能力探测在隔离临时对象上证明服务端**真的**拒绝
并发写入后才允许写正式对象；协调器、能力缓存、目标键、退避与设置页全部复用现有机制。

**真实 S3／R2 端点与两台真实设备的验收尚未完成**（本机没有可用凭据，见 §5），因此 S3
目前标记为"代码与自动化测试完成、待真实服务验收"，不宣称可以替代 WebDAV。

## 1. 交付内容

| 文件 | 作用 |
|---|---|
| `lib/services/sync/aws_signature_v4.dart` | SigV4 签名（`service=s3`），键编码、规范化请求、签名头 |
| `lib/services/sync/s3_sync_provider.dart` | `SyncProvider` + 能力探测 + 条件写入 + 错误分类 + 上传响应丢失恢复 |
| `lib/services/sync/sync_provider.dart` | 新增 `permissionDenied` 能力状态；新增 `VerifiableSyncProvider`、`SessionScopedSyncProvider` 接口 |
| `lib/services/sync/sync_coordinator.dart` | 能力门槛、凭据捕获/清理、目标键、ETag 缺失拒绝、上传后以读回版本为准，统一按接口判断而非 `is WebDavSyncProvider` |
| `lib/services/sync/credential_store.dart` | `sync.s3.accessKeyId` / `sync.s3.secretAccessKey` |
| `lib/features/sync/sync_settings_page.dart` | S3 选项与字段、草稿测试、自动同步门槛提示、断开时清理凭据 |
| `lib/l10n/app_en.arb` / `app_zh.arb` | 13 条 S3 文案 + `syncCapabilityPermissionDenied` |
| `test/helpers/s3_server.dart` | 回环 HTTPS 假 S3：独立重算 SigV4 签名、强制条件语义、可模拟忽略条件/缺 ETag/丢响应/409/301 |
| `test/phase6_3_s3_sync_test.dart` | 33 个用例：签名向量、能力矩阵、数据路径、双设备收敛、自动同步门槛 |
| `test/phase6_3_s3_ui_test.dart` | 设置页 S3 选项、已验证状态、自动同步暂停提示 |

## 2. 关键设计决定

1. **寻址方式自动决定**。AWS 新桶要求 virtual-hosted，R2／MinIO 走 path-style。端点以
   `*.amazonaws.com(.cn)` 结尾时用 `<bucket>.<host>/<key>`，否则 `<host>/<bucket>/<key>`；
   Bucket 名含点时强制 path-style（通配证书不匹配），不做用户可见开关，减少配置出错面。
2. **签名路径 = 发送路径**。签名器接收最终 `Uri`，规范化路径直接读 `uri.path`；对象键由
   `AwsV4Signer.encodeKey` 逐段按 RFC 3986 编码后再拼 URL。测试用独立实现的服务端重算签名，
   签错路径会直接得到 `403 SignatureDoesNotMatch`。
3. **ETag 只是版本**。不用 ETag 推断内容相同；内容比较仍用 `BackupService.contentHashOf`。
   远程对象存在却无 ETag 时拒绝上传（`未提供 ETag → 停止`），而不是退回无条件 PUT。
4. **上传后以读回的版本为准**。`_verifyUpload` 返回远端文档实际所在的 revision，协调器优先
   持久化它；PUT 响应头的 ETag 只作为兜底。这让"写成功但响应丢了／响应头不全"不再污染
   下一次 `If-Match`。
5. **响应丢失不等于失败**。PUT 抛可重试错误后立即读回对象并比对 SHA-256：一致即认定提交
   生效并返回新 ETag，不一致才上报可重试失败。
6. **能力门槛在协调器**。`ensureCapability` 对任何 `VerifiableSyncProvider` 生效，因此手动
   同步、立即同步、首次初始化、恢复后同步与四类自动触发走的是同一个门槛；能力失败不入缓存，
   非可重试失败（鉴权、权限、Bucket 缺失）会清除已缓存的能力。
7. **凭据只在钥匙串**。Access Key ID 与 Secret Access Key 都不进入 `sync_config`，因此导出
   配置、备份与诊断报告中不存在凭据字段。

## 3. 自动化验证

`flutter test test/phase6_3_s3_sync_test.dart`（33 passed）：

- **签名向量**：与 botocore `S3SigV4Auth` 对同一输入的输出逐字节一致，覆盖 GET/HEAD/PUT/
  DELETE、`If-Match`、`If-None-Match`、`content-type`、非默认端口、virtual-hosted 与
  path-style、以及含中文／空格／`+`／`%`／多级前缀的对象键。
- **能力矩阵**：合规服务端 → `safeConditionalWrite` 且探测对象清理干净；忽略 `If-None-Match`
  或 `If-Match` → `basicReadWrite` 并点名哪个条件头被忽略；无 ETag → `basicReadWrite`；
  Bucket 不存在 → `directoryUnavailable`；全拒绝 → `permissionDenied`；密钥错误 →
  `authenticationFailed`；Region 不符 → `connectionFailed` 且带服务端期望的 Region。
- **数据路径**：首次创建带 `If-None-Match: *`、重复创建被拒且原内容不变、过期版本被拒、
  当前版本成功并更换 ETag、每次正式写入都带条件且条件头在签名内、409 转冲突、响应丢失后
  校验成功、`missing/empty/corrupt/wrong-root/valid` 五种远端状态互不混淆、`403` 不当 missing、
  不可用版本令牌直接停止。
- **双设备**：同一远端并发首次同步后两端收敛；两端离线各自编辑后合并（词条与学习记录都
  一致）；远端被删后停止并保留本机数据，用户确认后可重建；自动同步在能力未验证时一次请求
  都不发，验证并首次同步后才运行，能力失效后再次关闭；换对象键得到独立状态且不继承能力。
- **不回归**：`phase3_sync`、`phase5_sync`、`phase3_sync_race`、`phase3_auto_sync`、
  `phase6_2_webdav`、`phase6_2_1_webdav_etag/real_compat`、`phase3_webdav_http`、
  `phase6_2_sync_ui`、`phase5_1_conflict_restore`、`phase5_1_foreground_probe`、
  `phase5_regression`、`backup` 全绿；新增 `phase6_3_s3_ui_test` 覆盖设置页。

## 4. 与 WebDAV 的关系

本阶段**保留** WebDAV 的全部数据、配置与双向同步入口，不迁移、不删除、不覆盖远端文件。
WebDAV 的 `safeSnapshotWrite` 快照通道逻辑未改动。真实验收通过后，再单独安排"读取旧单文件
与已发布快照 → 合并进本机 → 校验 → 绑定 S3 → 下线旧双向入口"的迁移任务。

## 5. 未完成 / 未验证

| 项目 | 状态 | 原因 |
|---|---|---|
| 真实 AWS S3 或 Cloudflare R2 端点验收 | **未完成** | 本机没有该服务凭据，且任务要求用户凭据由应用安全配置输入；未擅自注册第三方服务 |
| 两台真实设备（Android/macOS/iOS）数据收敛 | **未完成** | 依赖上一项 |
| 条件写入探测在真实服务上的结果 | **未完成** | 同上；本地以回环 HTTPS 假服务端 + 独立签名校验代替 |
| WebDAV → S3 迁移与旧入口下线 | 未开始 | 按计划排在真实验收之后 |

因此本次交付**不**把 S3 标记为"可替代 WebDAV 的正式同步选项"，只标记为"代码完成、
自动化测试通过、等待真实端点与双设备验收"。验收步骤见 §6。

## 6. 真实端点验收步骤（待执行）

1. 准备专用 Bucket 或专用前缀（例如 `mw-acceptance/`），使用仅授权该前缀读写的 Access Key。
2. 应用内填写 Endpoint／Region／Bucket／对象键与密钥，点「测试连接」；期望状态为
   `连接成功，可以同步`，技术详情包含"基础读写验证通过"与"If-None-Match/If-Match 已验证"。
3. 两台设备分别填入同一目标，各自新增不同词条后同时「立即同步」，再各自同步一次；
   以两端重新拉取后的词条、词书关联、复习记录与内容哈希一致为准。
4. 两端各自离线编辑后上线，确认合并而不是覆盖，冲突列表符合预期。
5. 在控制台删除对象，确认设备停止自动同步并提示，而不是静默重建。
6. 记录服务商、Region、探测结果与两端收敛结果，回填本节。
