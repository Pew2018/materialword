# Phase 3 验证记录（持续更新）

当前为实施中，尚未最终交付。

## 已执行

- Flutter 3.50.1 / Dart 3.14.0；flutter pub get --offline 成功，未升级 SDK。
- 当前 flutter analyze：无问题；dart format 已执行；git diff --check 无问题。
- 当前全量回归：162 项通过、2 项平台条件跳过。平台跳过需要构建 Bundle/ZIP 的真实 macOS 包；没有宣称已执行。
- phase3_data：800/5000/20000 词×四排序无遗漏，人工掌握/取消、撤销、失败回滚、到期查询。
- phase3_sync + sync_transport：三设备逻辑哈希收敛、共享设置版本、ETag/XML/条件 GET/origin、2 MB encoding:none immutable SHA 大文件读取。
- phase3_session：队列、位置、复练、计数恢复；撤销；跨日/目标变化；删除过滤；复练不拉长间隔。
- phase3_ui：6 项通过。底栏中间颜色/最终颜色、同一 InkWell 元素、圆角 customBorder、父约束双栏、短窄 macOS 窗口搜索状态、Dialog controller 退出生命周期，以及首页继续/跳过链路。
- phase3_golden：浅深色两项通过并人工查看布局图。图标显式加载已有 MaterialIcons；文本使用测试 Ahem 字体，属于确定性几何/颜色基准，不能替代中文字体或真机验收。

## 性能实测

`phase3_performance_test.dart`：合成 20000 词、100001 事件，内存 SQLite，Flutter test 调试环境；不是 Release 真机基准，不把测试数据库初始化等同应用启动。

| 操作 | 独立运行 ms | 全量并行运行 ms（示例） |
|---|---:|---:|
| 分页 100 项 | 3.476 | 3.705 |
| 精确子串搜索 | 6.048 | 6.287 |
| 筛选全部 ID | 19.504 | 19.353 |
| 单次答题 | 5.045 | 5.916 |
| 统计 | 329.136 | 349.448 |
| 建立队列 | 6.414 | 7.772 |
| 一致性快照 | 458.148 | 519.131 |
| 原始 JSON 编码 | 201.994 | 216.228 |
| 原始 JSON 解码 | 249.644 | 314.714 |
| 完整合并与重放 | 10249.441 | 11381.324 |
| 单词事件重放 | 0.223 | 0.358 |

备份大小 30,440,623 字节。由此整改了 GitHub 4 MB 上限，并将生产文件大 JSON 编解码移到后台 isolate。基准 raw 编解码值表示计算成本，不是 isolate 带来的“提速”。统计、全量映射和完整合并仍需后续性能审计。

## 未执行/待完成

- 新增后续功能后重新执行最终格式检查、analyze、全量测试与 Golden。
- 真实轻量 HTTP WebDAV 服务并发测试，用户真实 WebDAV/GitHub 数据服务。
- 新增收藏/标签等功能后继续扩展迁移数据矩阵；当前 Schema 1/2 的笔记/状态/主题/身份/同步元数据/删除标记保留与 DDL 故障回滚已通过。
- 补全 800/5000 规模各操作、文件数据库、批量导入/词书统计及 Release 启动性能。
- 当前改动的 Android、macOS、iOS CI 编译和产物核验。
- 当前改动的 macOS 实际启动、三平台真机交互验收。

## 协议依据

- [RFC 9110 If-Match](https://www.rfc-editor.org/rfc/rfc9110.html#section-13.1.1)：强比较、实体标签引号、412。
- [GitHub Contents API](https://docs.github.com/en/rest/repos/contents#get-repository-content)：1–100 MB 读取需要 raw/object 媒体类型；100 MB 以上不支持。本项目使用 90 MB 应用保护上限及 immutable SHA raw blob 大文件读取。

测试日志临时保存在工作区 work/ 下，最终报告应只引用最终源码 commit 对应的真实结果。


## Schema 3 与真实协议检查点

- `phase3_webdav_http_test.dart`：7 项真实 loopback HTTPS 通过；运行时 openssl 生成仅用于测试的短期根，客户端显式信任该根；未设置 badCertificateCallback，未改变生产 TLS 校验。
- `phase3_migration_test.dart`：4 项通过；真实发布 Schema 1/2 SQL fixture 升级；中断建表后 DDL/列/版本完整回滚，再开成功。测试曾捕获未加显式事务时的半迁移，现已修复。
- `phase3_session_test.dart`：7 项通过，包括快照写入失败时撤销完全回滚、删除中的卡不作答、文件数据库关闭重开恢复。
- `phase3_backup_validation_test.dart`：整包损坏拒绝与未知时区旧备份来源升级收敛通过。
- `tool/verify_timezone_replay.sh`：香港作者进程 + 纽约导入进程各 1 项通过，已纳入 CI validate；不将这两项重复计入全量 162。
- 最新独立全量日志：work/phase3-schema3-full-verified.log；162 通过、2 跳过。格式和 analyze 无问题。

Schema 3 全量同负载实测（debug，单次并行环境）：搜索 7.110 ms、分页 3.914 ms、统计 156.861 ms、快照 641.253 ms、整包合并/重放 12185.697 ms，37,540,692 字节。新增时间来源字段增加文档体积，完整 JSON 解码+严格校验原始计算成本 1148.151 ms；生产异步路径把该工作放到后台 isolate，不宣称计算成本消失。上表保留此前 Schema 2 检查点实测以便比较，不能当作严格 A/B 性能结论。

收藏/标签及身份别名/字段版本现已接入业务、界面和备份合并。收藏专项取消后的会话恢复/提交会过滤该词，不产生作答。

字段与身份批次：全量 170 通过、2 平台条件跳过；另有本批 10 项定向测试通过（含随后增加的同名书重建及非法元数据整包回滚）。覆盖三设备重命名、不同字段修改、相同字段决胜、删除与时钟偏差、明确恢复、旧字段省略/清空、重命名碰撞、过期词典对象与并发 ID 创建。同期 debug 单次合成负载：搜索 7.035 ms、分页 3.836 ms、快照 580.484 ms、合并/重放 12943.650 ms；不是严格 A/B 或真机性能结论。

收藏/标签批次完整回归：184 通过、2 平台条件跳过，analyze 无问题。实际文件关闭/重开、三设备标签身份与关系收敛、删除抵抗离线改名、移除墓碑、批量事务回滚、搜索与收藏专项均验证。3 项 Widget 测试实际点击创建/改名/取消删除/删除、收藏和标签增删/取消、121 个筛选结果跨分页批量取消收藏。测试等待缓存流的问题通过直接检查持久化行解决，业务断言未删减。单次 debug 合成负载搜索 10.504 ms、分页 4.578 ms、快照 671.126 ms、全量合并/重放 13462.839 ms，37,540,731 字节；不代表发布构建或真机表现。
