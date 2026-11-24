# 数据交换协议 v3（数据库 Schema 独立为 3）

## 格式与兼容

JSON 包含 `kind=materialword-backup`、`schemaVersion=3`、datasetId、作者 deviceId、exportedAt、words、wordBooks、entries、reviewEvents、settings。仍可导入备份 v1/v2；旧客户端会明确拒绝 v3，不能把撤销或管理事件误当普通作答。未来协议、未来算法与未知事件模式拒绝导入。所有已知记录字段、ID 唯一性、引用、撤销目标和时间锚点先完整校验；损坏整包拒绝，不再部分跳过。

凭据不进入 JSON。导出的设备标识用于事件归因，导入不覆盖本机 deviceId、语音、主题、窗口或文件授权。

## 一致性与合并

- 所有表和共享设置版本在同一 Drift 事务读取，避免导出跨写入边界的引用；大文档解析、结构/引用校验及内容哈希在后台 isolate 执行。
- 合并及派生状态重放在同一事务，失败回滚。
- 词条/词书先按 ID 和持久化 aliases 映射，再按 normalized/同生命周期名称合并独立创建的数据。关联与事件改指本机规范 ID。重命名更新 normalized，保留旧 UUID 别名；歧义身份或重命名占用已有词面时整包拒绝回滚。原始作答按事件 ID 幂等。
- `fieldVersions` 为每个字段记录 counter、updatedAt、deviceId，首次编辑前为未改字段保存原始基线。不同字段并发修改分别保留，同字段按计数、时间、来源、值稳定决胜并报告冲突。旧格式缺失字段不覆盖，显式空字符串才清空。删除有独立版本，同计数删除优先，未观察删除的普通编辑不能复活，明确重新添加才递增删除版本。
- 逻辑内容哈希将词条/词书引用转为 normalized/名称及删除生命周期，排除本地 ID、aliases、创建时间、导出时间及设备归因头，保留字段版本并递归稳定排序。独立三设备同词同书往返及后续重命名收敛测试已通过。
- 共享目标/复习上限/模式采用 Lamport counter + 修改来源 deviceId 决胜；设备设置不被远端覆盖。旧版无版本设置仅在原本空库且无本地计划修改时采用。
- 每个目标以 endpoint/repo/branch/path 的 SHA256 键记录首次成功及内容哈希，不拿全局 lastSyncAt 推断不同目标的首次连接。新目标须人工确认后才允许自动同步。

## 文件备份

所有外部导出使用系统 FilePicker 保存字节；不把 Android content URI 当 File，也不调用 toFilePath。导入先读取/校验/预览，再确认合并；取消不写学习数据。内部恢复副本最多 5 份。

裸本地路径提供手动文件合并；空值、相对路径和 URI 在任何文件系统操作前拒绝。临时文件 rename 只防止部分写入，不保证多进程条件更新，因此本地文件禁用自动同步。没有声称拥有永久 SAF grant 或 macOS bookmark。

## WebDAV

- 仅 HTTPS；跨 origin（主机、端口或协议）重定向拒绝继续，不能泄露认证。
- 保留带引号的强 ETag。弱或无 ETag 不允许 coordinator 上传现有文档，提示手动备份。
- XML 使用 namespace-aware parser，仅接受成功 propstat 的 DAV:getetag，正确解码实体。
- GET 缺强 ETag 时，PROPFIND 之后再用该 ETag 发 If-Match GET，保证文档与令牌对应。
- 更新用 If-Match，首次创建用 If-None-Match:*；412 重新读取合并，最多三次。
- 每次 WebDAV 同步（包括自动同步）在 UUID 临时资源上实测过期 If-Match/重复 If-None-Match 必须返回 412，失败请求不能改内容，有效更新必须读回新内容与强 ETag；最后条件删除临时文件。探测失败不写正式数据。
- 7 项本机真实 HTTPS 测试覆盖忽略条件、弱/无 ETag、412 重试、上传期间作答及 TLS 不受信任证书拒绝。测试信任运行时生成的根，不关闭证书校验。用户真实 WebDAV 服务及真机联网仍未验收。

## GitHub

使用 Fine-grained PAT 和 Contents API 的 SHA 条件 PUT；不会创建数据仓库。拒绝将数据写入 Pew2018/materialword 源码仓库。90 MB 是应用保护上限，不要求删除历史。1–90 MB 的 encoding:none 响应通过同一仓库的 immutable blob SHA + raw 媒体类型读取，避免两次 branch 查询间的竞态。

[官方 Contents API](https://docs.github.com/en/rest/repos/contents#get-repository-content) 说明 1 MB 以上读取须 raw/object，100 MB 以上不支持。私有仓库/分支验证和真实 PAT 权限矩阵仍需继续完善；Mock 测试不是服务验收。

## 未完成的安全矩阵

共享设置上传并发、自动变更防抖与退避持久化、标签关系和平台文件授权仍属待办。同字段冲突当前确定性选择并计数提示，尚无双版本恢复界面。已验证上传期间新答题保持 pending，并在下次实际上传；作者日界/来源通过香港与纽约两进程验证。最终交付前需逐项通过。


## 时间来源与旧格式

新作答保存 `dayStartUtc` 与 `dayStartSource=authored`。重放用事件作者锚点加复习间隔，不使用导入设备的午夜。Schema 1/2 迁移优先从最新原学习状态的准确 due 推导 `legacy-state`，其余缺失信息为 `legacy-utc`（作答 UTC 日期午夜）。纯旧备份没有原时区和原 due，不能还原未知信息；不虚构精确作者午夜。

同一事件可从 UTC 回退升级到旧状态来源，再升级到真实作者来源，答题本体不可改变。相同作者来源却出现不同锚点时整包拒绝；同级旧来源冲突确定性取较早锚点。该升级参与重放和哈希，避免双端持续不同。原数据库迁移不改已有学习状态；后续合并/撤销按来源规则重放。
