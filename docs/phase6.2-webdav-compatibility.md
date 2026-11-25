# Phase 6.2 — WebDAV 真实服务兼容性、同步可靠性与首次初始化

本文件只记录**实际做过的修改与验证**。计划中的功能不写在"已完成"里；没有真实账号
验证的部分单独标注为未验证。

## 0. 一句话结论

用户报告的"服务器不支持安全双向同步 / 无法创建临时测试文件（HTTP 404）/ 403 拒绝访问"
里，**能由源码证明的两个根因已经修复**：

1. 目录创建把服务器基础集合 `/dav/` 当成用户目录，发出了 `MKCOL /dav/`；
2. 能力探测用**隐藏 `.txt` 文件**做条件写入测试，失败后只得到一句笼统的"不支持"，
   并且 0 字节的远程文件被当成 JSON 损坏。

403/404 究竟由哪一个请求产生，**尚未在坚果云真机上取得证据**（见 §4）。因此本阶段
交付的是"不再发出明显错误的请求 + 能准确报告是哪个请求失败 + 首次同步可以安全初始化
空文件"，而不是"已确认坚果云全兼容"。

## 1. 用户实际测试失败现象

macOS、坚果云、账号密码已确认正确、手工创建了 0 字节的 `materialword-data.json`。

| 配置 | 界面提示 |
|---|---|
| 远程目录留空 / 根目录 | `数据文件尚未创建，首次同步会写入并读取服务器返回的 ETag`；`注意：无法创建临时测试文件（HTTP 404）`；点击同步后 `同步失败：服务器未通过条件写入验证` |
| `Nutstore`、`/Nutstore`、`/Nutstore/` | `WebDAV 拒绝访问：请检查目录权限`（HTTP 403） |

两个现象的共同点：界面**无法说明**是哪一个 HTTP 请求、哪个阶段、哪个路径失败，
所以用户与开发者都只能猜。

## 2. 已确认的源码缺陷（修复前可复现）

以下每一条都在修复前的基线上读过代码并在测试服务器上复现过。

| 编号 | 缺陷 | 证据 |
|---|---|---|
| 6.2-01 | `_ensureDirectory()` 把 `dir.pathSegments` **全部**当作待创建目录，包含服务器基础路径。`baseUrl=https://dav.jianguoyun.com/dav/` + `remoteDir=Nutstore` 会依次 `MKCOL /dav/`、`MKCOL /dav/Nutstore/` | 旧实现遍历所有 segment；`MKCOL /dav/` 在商业服务上是 `403 OperationNotAllowed` |
| 6.2-02 | 目录创建对 `201/200/405/301` 一律 `continue`，对 404/409 静默忽略，创建后**不验证**就报告"已建立同步目录" | 旧 `_ensureDirectory` 的 switch |
| 6.2-03 | 能力探测文件是 `.materialword-probe-<uuid>.txt`（隐藏 + `text/plain`）。部分商业网盘拒绝隐藏文件或某些扩展名，这与条件写入能力**无关**，却会被报告成"不支持安全双向同步" | 旧 `_verifyConditionalWrites` |
| 6.2-04 | 探测把"条件创建失败"直接当成结论，没有先验证普通 PUT/GET/DELETE 是否可用，因此无法区分"不能写"与"不能条件写" | 同上 |
| 6.2-05 | `SyncTestResult.supportsConditionalWrites` 用 `details` 里的字符串前缀判断，空 `details` 会被解释为"支持"；`ok == true` 被界面当成"可以同步" | 旧 `sync_provider.dart` |
| 6.2-06 | `download()` 对 0 字节文件直接 `decodeDatasetJson('')` → `FormatException` → "远程数据文件不是合法 JSON"。用户手工建的文件因此变成"损坏数据" | 旧 `download()` 第 510–555 行 |
| 6.2-07 | `null` 同时表示"远程不存在"和"远程无法判断"，0 字节文件既不属于前者也无法表达 | 旧 `SyncPayload?` 返回约定 |
| 6.2-08 | 每次同步都跑完整探测：`if (!skipConnectionTest || provider is WebDavSyncProvider)` 使自动同步也执行十余次请求 | 旧 `sync_coordinator.dart` 第 185 行 |
| 6.2-09 | `_raise()` 把所有 403 压成"请检查目录权限"，不记录 method / stage / path | 旧 `_raise()` |
| 6.2-10 | 同步页用同一个 `result.ok` 决定图标与颜色，于是出现"绿色对勾 + 服务器不支持安全双向同步"；文案还承诺"可以用「立即同步」手动合并"，而 coordinator 实际会拒绝 | 旧 `sync_settings_page.dart` |
| 6.2-11 | 自动同步开关只看 `provider.supportsConditionalWrites`（WebDAV 恒为 `true`），未验证的服务器也能打开自动同步 | 旧 `autoSync()` 守卫 |

## 3. 本阶段修改清单

### 3.1 路径与目录（任务 B）

新增 `lib/services/sync/webdav_paths.dart`。路径模型把三件事永久分开：

```
服务器基础集合   https://dav.jianguoyun.com/dav/      (只探测，永不创建)
用户目录        MaterialWord                          (缺失时逐级创建)
数据文件        materialword-data.json                (只写入，从不用于探测)
```

规则：

- 基础路径按 segment 重新编码，保留原样，不做字符串拼接；
- `''`、`/`、`MaterialWord`、`/MaterialWord`、`/MaterialWord/` 解析结果完全相同；
- 每个 segment 先解码一次再编码一次，`Material%20Word` 不会变成 `%2520`；
- `.`、`..`、空段、控制字符、超长段、`a/b.json` 形式的文件名一律拒绝（`isConfigured == false`）；
- 空目录明确表示"基础集合本身"，不是服务器根。

`_ensureDirectory()` 重写为：逐级 PROPFIND → 缺失才 MKCOL → 创建后再次 PROPFIND 验证。
`MKCOL` 的状态码 201/405/403/404/409/401 分别给出不同处置，绝不再"一律容错"。
`p.segments.isEmpty` 时直接返回，`/dav/` 永远不会成为 MKCOL 目标。

### 3.2 远程目录浏览（任务 C）

- `WebDavSyncProvider.listDirectories({String path})`：`PROPFIND Depth: 1`，解析
  `d:response/d:href/d:propstat/d:prop`，只接受 2xx 的 propstat；
- 相对 `href`、绝对路径 `href`、绝对 URL `href` 都能解析（`WebDavPaths.resolveHref`）；
- 中文与百分号编码按 segment 解码，`displayname` 优先，缺失时用路径末段；
- 跨 origin 或跳出基础集合的 `href` 直接丢弃，凭据不会被带到其他主机；
- 新增 `createDirectory(path)`，供"新建文件夹"使用；对基础集合调用会直接抛错。

界面新增 `lib/features/sync/webdav_directory_picker.dart`（Classic Material 2 的
`AlertDialog` + 普通 `ListTile`），提供：浏览、进入子目录、返回上一级、选择当前文件夹、
新建文件夹。手动输入能力保留，选择器只是可选入口。

### 3.3 能力探测（任务 D）

`_probeWrites()` 在**一个**本次创建的探测资源上分两步：

1. 条件创建 `PUT If-None-Match: *`，文件名 `materialword-probe-<uuid>.json`
   （普通名字、`application/json`、内容 `{"probe":"<uuid>","revision":1}`）；
2. 条件创建失败时，才在同一个临时资源上做普通 `PUT`，用于区分"不能写"和"不能条件写"。

随后按顺序验证并在每一步记录证据：

| 步骤 | 期望 | 记录字段 |
|---|---|---|
| 条件创建 | 201/204 | `canCreate` |
| GET 读回 | 200 且内容一致 | `canRead` |
| 过期 `If-Match` | 412 | `supportsIfMatch` |
| 读回（在 If-None-Match 之前） | 内容与 ETag 未变 | 若变了则判定 If-Match 未生效 |
| 已存在文件 `If-None-Match: *` | 412 | `supportsIfNoneMatch` |
| 正确 `If-Match` 更新 | 2xx，且 ETag 变化、内容读回一致 | `canUpdate` |
| DELETE（带 `If-Match`） | 2xx/404 | `canDelete`、`probeCleanedUp` |

关键的顺序修正：**先读回，再做 If-None-Match 实验**。否则一个忽略 If-None-Match 的
服务器会覆盖探测文件，让"If-Match 检查失败后内容被改"看起来也像 If-Match 失效——两个
能力的证据会互相污染。

ETag 判定沿用 `strongEtag`：只接受带引号的强校验器，`W/"..."` 与缺失都记为
`supportsStrongEtag = false`。弱 ETag 服务器得到"基础读写可用、并发保护不可用"，
不会被说成"支持同步"。

探测清理：只删除本次创建的随机资源；清理失败会把原因写入报告，并提示用户手动删除
`materialword-probe-` 开头的文件。真实数据文件从头到尾没有被写入（测试断言
`dataWrites == 0`、`dataset` 不变）。

### 3.4 结构化能力模型（任务 E）

`lib/services/sync/sync_provider.dart`：

```dart
enum SyncCapabilityStatus {
  unknown, connectionFailed, authenticationFailed,
  directoryUnavailable, readOnly, basicReadWrite, safeConditionalWrite,
}
```

`SyncCapability` 显式保存 `reachable / authenticated / directoryAccessible / canRead /
canCreate / canUpdate / canDelete / supportsStrongEtag / supportsIfMatch /
supportsIfNoneMatch / probeCleanedUp / failureStage / failureMethod / failureStatus`。

- `safeBidirectionalSync` 是唯一允许自动同步的属性，要求状态为 `safeConditionalWrite`
  且所有读写与条件能力全部为真；
- `SyncTestResult` 增加可选 `capability`；`supportsConditionalWrites` 在有 capability 时
  只信任它，没有时保留旧的字符串规则但**额外要求 `ok`**，失败结果不再可能被读成"支持"；
- `details` 保留人类可读文案（含旧的 `NO_CONDITIONAL_WRITE:` 标记，便于既有日志检索），
  但**逻辑不再依赖字符串**。

### 3.5 远程状态与空文件初始化（任务 F）

`RemoteDataset` 把远程分成 `missing / empty / valid`（`invalid` 仍以 `SyncDataException`
表达，因为调用方只关心"不能继续"）：

- `SyncProvider.fetchRemote()` 默认实现保持 GitHub / 本地文件的两态行为；
  WebDAV 覆写它，`download()` 在 0 字节时抛 `SyncEmptyRemoteException`；
- coordinator 在合并**之前**处理空文件：未授权 → `SyncEmptyRemoteException`
  （`previouslySynced` 区分"首次"与"曾经同步过"）；已授权 → 用空文件**自己的 ETag**
  作为 `If-Match` 上传本机数据；
- 没有 ETag 的空文件拒绝初始化（无法证明不会覆盖其他设备）；
- 曾经同步成功的目标突然变空 → 提示语改为"远程同步文件变成了空文件（0 字节）"，
  只有用户在对话框里确认后才继续；
- 损坏 JSON、`{}`、不支持的版本仍然抛 `SyncDataException`，绝不自动覆盖、绝不重建。

### 3.6 能力缓存与请求次数（任务 H）

新增 `lib/services/sync/sync_capability_cache.dart`，键为
`sync_capability:<targetKey>`，内容为
`{v, at, fingerprint, capability}`，其中

```
fingerprint = sha256(['webdav-cap-1', 规范化 base, segments, fileName,
                      identityEpoch, sha256(用户名).前16位])
```

- **只缓存成功**：失败结果立即清除，下一次必须重新探测；
- 失效条件：地址、目录、文件名、凭据 epoch（账号/密码变更）、用户名变化，TTL 7 天，
  连续并发冲突，任何一个**不可重试**的同步失败（认证失效、权限变化、强 ETag 消失），
  以及用户在页面上任何连接字段的编辑（界面立即把状态退回"尚未验证"）；
- 可重试的失败（网络、5xx、并发冲突）与"远程数据本身的问题"（空文件、损坏、缺失）
  不清除缓存：它们不说明服务器能力变化，清掉只会让一次超时把自动同步静默关掉；
- 密码、Authorization、Base64 凭据**不进入**缓存文件；
- `sync()` 走 `ensureCapability()`：有有效缓存就不再探测；`测试连接` 强制 `force: true`；
- 正式写入仍然每次带 `If-Match` / `If-None-Match`，缓存只省掉"探测"，不省并发保护。

### 3.7 同步页与文案（任务 I）

- 状态行由 capability 决定：灰色"尚未验证连接" / 绿色"连接成功，可以同步" /
  橙色"此服务器暂不支持安全的多设备同步" / 红色"无法连接服务器" / 红色
  "已连接，但无法访问此文件夹" / 红色"认证失败：账号或密码不正确"；
- 技术细节收进"技术详情"折叠项（`ExpansionTile`），普通文案只有结论；
- 自动同步：能力未知或不安全时显示"自动同步尚未启用：…"，偏好仍可保存，但
  `autoSync()` / `autoRetryDelay()` 在 `safeBidirectionalSync` 为假时直接返回 `null`；
- 「立即同步」在已知不安全时不再执行覆盖，改为弹窗说明并提供"重新测试连接 / 导出备份"；
- 删除了"可以用「立即同步」手动合并"这句与实际行为矛盾的文案；
- 新增"选择远程文件夹"按钮与"同步诊断信息"入口（跳转诊断页导出 TXT）。

### 3.8 诊断日志（任务 J）

新增 `lib/services/sync/webdav_trace.dart`：

```
[WebDAV] request=r12 stage=directory_creation method=MKCOL host=dav.example.com
         path=/dav/ status=403 duration_ms=181 conditional=- etag=- result=http_error
```

- `stage` 使用固定枚举（`base_collection_probe`、`target_directory_probe`、
  `directory_creation`、`directory_listing`、`data_file_probe`、`basic_write_probe`、
  `conditional_create_probe`、`conditional_stale_update_probe`、
  `conditional_existing_create_probe`、`conditional_valid_update_probe`、`probe_cleanup`、
  `dataset_download`、`dataset_upload`、`dataset_verification`）；
- 只记录 method、host（不含 userinfo）、path（不含 query）、状态码、耗时、重定向次数、
  条件请求类型、ETag 类型、响应 Content-Type；探测文件的随机段统一替换为
  `materialword-probe-<nonce>`；
- 不记录密码、Authorization、Cookie、请求体或学习数据；错误消息中的 URL 凭据由既有
  `DiagnosticsService.redact` 再脱敏一次；
- 日志仍受既有诊断开关约束（默认关闭、400 条 / 24 小时上限、256 KB 轮转）。

## 4. 尚未确认的服务端行为（不得当作根因）

| 项 | 现状 |
|---|---|
| 用户那次 403 来自 PROPFIND、MKCOL 还是 PUT | **未确认**。代码能保证现在不会对 `/dav/` 发 MKCOL，能报告失败阶段，但没有用户当时的请求记录 |
| 用户那次 404 来自根目录写限制、隐藏文件限制、路径错误还是条件请求 | **未确认**。三个可能原因都已在模拟服务器上单独复现，并分别有测试覆盖 |
| 坚果云远程文件夹映射是否等于 Finder 中显示的名称 | **未确认**。这正是新增目录浏览器的原因：不再猜，改为列出真实集合 |
| 坚果云是否完整支持强 ETag / If-Match / If-None-Match | **未确认**。官方帮助页没有描述条件请求语义；只能由真机探测结果决定，代码不预设答案 |

## 5. 坚果云兼容性调查（官方资料）

来源：坚果云帮助中心《坚果云第三方应用授权 WebDAV 开启方法》
(<https://jianguoyun.com/s/help/?p=2064>)、官方内容页 (<https://content.jianguoyun.com/22237.html>)。

已确认（官方明示）：

- 服务器地址为 `https://dav.jianguoyun.com/dav`（客户端示例带尾斜杠）；
- 密码必须是"应用密码"，不是账号登录密码 —— 401 时应提示检查应用密码；
- 上传大小默认限制 500 MB；
- **访问频率限制：免费用户每 30 分钟不超过 600 次请求，付费用户 1500 次**；
- 单次 PROPFIND 最多返回 750 个条目，超出需分页，未分页的第三方客户端可能"同步不完整"；
- 第三方应用首次写入通常会在账号下生成自己的顶层文件夹。

对本项目的直接影响：

1. 频率限制直接印证了任务 H 的必要性：一次完整探测十余次请求，乘以"启动/返回/
   数据变化/学习结束"四个触发点，很容易吃掉免费额度。因此缓存成为必需，而不是优化项。
2. "单次 750 条、需要分页"意味着目录浏览器在大目录下可能只显示部分条目。当前实现
   只读取一页，界面对此没有分页；这是已记录的已知限制（§11）。
3. 顶层文件夹自动生成的说法与"不要在 `/dav/` 上 MKCOL"的修复方向一致，但**不能**据此
   断定用户那次 403 就是 MKCOL 造成的。

未从官方资料获得、因此不写入结论的：强/弱 ETag、If-Match、If-None-Match、LOCK/UNLOCK、
MKCOL 在子目录上的行为、重定向策略。这些只能由真机探测给出答案，`testConnection()`
现在会逐项报告。

## 6. 多设备并发保护（未降低）

- 创建：`If-None-Match: *`；更新：`If-Match: <强 ETag>`；412 → `SyncConflictException`
  → 重新下载并合并，最多 3 次；
- 空文件初始化使用该文件当前的 ETag，不是 `If-None-Match`；
- 上传后仍然读回并比对内容哈希（`_verifyUpload`）；
- 上传前的 GET / 哈希比较 / 修改时间比较 / 本机互斥锁都**没有**被当作并发保护；
- 服务器只支持普通读写时，`safeBidirectionalSync == false`，自动同步与「立即同步」
  都不会执行覆盖式写入。

## 7. 能力缓存

见 §3.6。测试覆盖：首次验证、缓存命中不探测、强制测试绕过、目录/地址/凭据变化失效、
TTL 过期、不安全结果清除、未验证时自动任务不启动、正式上传始终带条件头。

## 8. 日志脱敏规则

见 §3.8。诊断报告仍由 `DiagnosticsService.buildReport` 生成，包含版本、数据库统计、
同步状态与最近日志条目；不包含账号、密码、词条或笔记。

## 9. 新增自动测试

`test/phase6_2_webdav_test.dart`（真实 loopback HTTPS，39 例）覆盖：

- DAV01–DAV12：基础集合只读、绝不 MKCOL 基础路径、已存在目录不重建、只建缺失层级、
  根集合写受限、Depth:1 列出真实目录、中文/空格目录、百分号不重复编码、路径穿越拒绝、
  同源重定向、跨源重定向拒绝；
- CAP01–CAP14：普通 JSON 探测文件、隐藏文件被拒仍可探测、普通 PUT 可用但条件被忽略、
  强/弱/缺失 ETag、忽略 If-Match、忽略 If-None-Match、条件失败与探测失败都不改真实数据、
  清理、403/404 定位到具体阶段；
- INIT01–INIT10：首次创建、0 字节阻断、授权后用 `If-Match` 初始化、初始化期间被其他
  设备修改后重读合并、曾同步目标变空视为异常、损坏 JSON 不覆盖、`{}` 不算有效数据集、
  初始化失败保留本机数据；
- CACHE01–CACHE10：见 §7（含 CACHE08b：认证失效后缓存被清除）。

`test/phase6_2_sync_ui_test.dart`（widget，内存 WebDAV，10 例）覆盖 UI01–UI10 中可由
界面验证的部分：绿色/橙色/红色状态与图标颜色、目录权限提示、未验证目标不声称启用自动
同步、改配置后旧结果失效、技术详情折叠、诊断入口、目录浏览与选择、空文件确认对话框
（确认按钮存在，取消后不写入）。

既有测试全部保留并通过：`phase3_webdav_http_test.dart`、`sync_transport_test.dart`、
`phase3_sync_test.dart`、`phase3_sync_race_test.dart` 等；`test/helpers/webdav_server.dart`
扩展为跟踪集合、真实 Depth:1、基础集合禁写/禁 MKCOL 等行为，原有断言未放宽。

关于 widget 测试的边界：`encodeDatasetJson` / `decodeDatasetJson` 走 `Isolate.run`，
在 widget 测试的 fake-async 区域永远不会完成，所以"完整同步成功"只能在 `test()` 里
（真实 socket）验证，widget 测试只验证到"对话框出现且取消后没有写入"。

## 10. 真机验证状态

**尚未进行真实坚果云验证。** 本环境没有经过授权的坚果云测试账号，也没有把任何凭据写入
仓库、CI 日志或对话。因此：

- 已完成：源码修复、模拟商业服务行为（基础集合禁写、禁 MKCOL、隐藏文件限制、
  弱/无 ETag、忽略条件请求、跨源重定向）的自动化测试、构建产物中的分阶段诊断；
- 未完成：坚果云真机连接、真实 ETag/If-Match 行为确认、真实目录映射确认。

复测步骤（使用新构建，不要用真实学习库做破坏性实验）：

1. 在坚果云网页端 → 账户信息 → 安全选项 → 第三方应用管理，生成一个应用密码；
2. 应用内填 `https://dav.jianguoyun.com/dav/`、坚果云账号、**应用密码**；
3. 先点「选择远程文件夹」，确认能看到账号下的真实文件夹；在其中新建 `MaterialWord` 并选择它；
4. 点「测试连接」，记录状态行文字（绿/橙/红）与"技术详情"；
5. 若提示"远程文件为空"，确认后点「初始化并同步」；
6. 失败时进入 设置 → 数据同步 → 同步诊断信息 → 打开日志开关 → 复现一次 → 导出诊断信息；
   报告中 `[WebDAV]` 行会给出 stage / method / path / status，可直接定位失败请求。

## 11. 仍然存在的限制

1. 目录浏览器只读取 `Depth: 1` 的一页；坚果云单页上限 750 条，大目录可能只显示一部分。
2. 能力缓存固定 7 天，服务端策略在期内变化不会被发现（直到出现认证/条件请求异常）。
3. 只支持"强 ETag + 条件请求"这一种安全并发机制；LOCK/UNLOCK 未实现，也不打算用
   "GET 后比较再写"冒充并发保护。
4. 空文件初始化只保证"不覆盖别人的写入"，无法恢复已被其他工具清空的内容。
5. 不支持 `Depth: infinity` 的服务器不影响同步，但目录浏览在深层结构上需要逐层点击。
6. 坚果云的真实行为仍未验证（§4、§10）。
