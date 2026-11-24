# 数据交换协议 v3（数据库 Schema 独立保持 2）

## 格式与兼容

JSON 包含 `kind=materialword-backup`、`schemaVersion=3`、datasetId、作者 deviceId、exportedAt、words、wordBooks、entries、reviewEvents、settings。仍可导入备份 v1/v2；旧客户端会明确拒绝 v3，不能把撤销或管理事件误当普通作答。未来协议、未来算法与未知事件模式拒绝导入。

凭据不进入 JSON。导出的设备标识用于事件归因，导入不覆盖本机 deviceId、语音、主题、窗口或文件授权。

## 一致性与合并

- 所有表和共享设置版本在同一 Drift 事务读取，避免导出跨写入边界的引用。
- 合并及派生状态重放在同一事务，失败回滚。
- 用户词按 normalized 映射设备各自 UUID；关联与事件改指本机规范 ID。原始作答按事件 ID 幂等。
- 词条按 revision、updatedAt 比较，同时间冲突以内容的稳定字符串顺序决胜；删除相同版本优先。关联保留版本化删除标记。
- 逻辑内容哈希将词条/词书引用转为 normalized/名称，排除本地 ID、创建时间、导出时间及设备归因头，递归稳定排序。独立三设备同词同书往返的收敛测试已通过。
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
- **待完成**：对服务器实际遵守条件写入的临时文件探测、真实 HTTP 服务测试、真实服务验收。仅返回 ETag 不能证明服务器遵守条件写入，目前不得宣称已完成安全自动双向同步验收。

## GitHub

使用 Fine-grained PAT 和 Contents API 的 SHA 条件 PUT；不会创建数据仓库。拒绝将数据写入 Pew2018/materialword 源码仓库。90 MB 是应用保护上限，不要求删除历史。1–90 MB 的 encoding:none 响应通过同一仓库的 immutable blob SHA + raw 媒体类型读取，避免两次 branch 查询间的竞态。

[官方 Contents API](https://docs.github.com/en/rest/repos/contents#get-repository-content) 说明 1 MB 以上读取须 raw/object，100 MB 以上不支持。私有仓库/分支验证和真实 PAT 权限矩阵仍需继续完善；Mock 测试不是服务验收。

## 未完成的安全矩阵

字段级独立编辑合并、不同名字/删除书身份边界、跨时区旧事件到期重放、同步期间写入与 dirty 状态、自动变更防抖与退避持久化、标签关系、真实 HTTP 条件写入和平台文件授权验证仍属待办。最终交付前需逐项通过。
