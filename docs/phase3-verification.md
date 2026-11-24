# Phase 3 验证记录（持续更新）

当前为实施中，尚未最终交付。

## 已执行

- Flutter 3.50.1 / Dart 3.14.0；flutter pub get --offline 成功，未升级 SDK。
- 当前 flutter analyze：无问题；dart format 已执行；git diff --check 无问题。
- 当前全量回归：145 项通过、2 项平台条件跳过。平台跳过需要构建 Bundle/ZIP 的真实 macOS 包；没有宣称已执行。
- phase3_data：800/5000/20000 词×四排序无遗漏，人工掌握/取消、撤销、失败回滚、到期查询。
- phase3_sync + sync_transport：三设备逻辑哈希收敛、共享设置版本、ETag/XML/条件 GET/origin、2 MB encoding:none immutable SHA 大文件读取。
- phase3_session：队列、位置、复练、计数恢复；撤销；跨日/目标变化；删除过滤；复练不拉长间隔。
- phase3_ui：5 项通过。底栏中间颜色/最终颜色、同一 InkWell 元素、圆角 customBorder、父约束双栏、短窄 macOS 窗口搜索状态、Dialog controller 退出生命周期。
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
- Schema 1/2 到最终 Schema 的完整迁移矩阵（当前尚未新增数据库列）。
- 补全 800/5000 规模各操作、文件数据库、批量导入/词书统计及 Release 启动性能。
- 当前改动的 Android、macOS、iOS CI 编译和产物核验。
- 当前改动的 macOS 实际启动、三平台真机交互验收。

## 协议依据

- [RFC 9110 If-Match](https://www.rfc-editor.org/rfc/rfc9110.html#section-13.1.1)：强比较、实体标签引号、412。
- [GitHub Contents API](https://docs.github.com/en/rest/repos/contents#get-repository-content)：1–100 MB 读取需要 raw/object 媒体类型；100 MB 以上不支持。本项目使用 90 MB 应用保护上限及 immutable SHA raw blob 大文件读取。

测试日志临时保存在工作区 work/ 下，最终报告应只引用最终源码 commit 对应的真实结果。
