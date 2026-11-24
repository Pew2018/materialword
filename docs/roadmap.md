# Roadmap

## Phase 1（已完成）

目标：可以真的坐下来背六级单词。

- [x] 三平台工程（Android / iOS / macOS），同一套 Dart 代码
- [x] 经典 Material Design 2 主题（`useMaterial3: false`）、浅色 / 深色 / 跟随系统
- [x] SQLite（Drift）用户库：词条、词书、关联、学习状态、作答流水、设置
- [x] 词库管理：新建 / 重命名 / 删除词书、词条增删改查、批量添加、搜索
- [x] 快速添加：输入单词 → 离线词典自动补全 → 选词书 → 保存 / 保存并继续
- [x] 导入 TXT / CSV / JSON（本机文件 + HTTPS 链接），带预览与事务写入
- [x] 内置离线词典（ECDICT 子集 26,282 词，MIT）
- [x] 学习闭环：显示释义 → 认识 / 模糊 / 不认识 → 写事件 + 更新状态 → 下一词
- [x] 阶梯式间隔重复（1/3/7/14/30 天）、每日新词目标、复习上限、积压统计
- [x] 首页真实进度、统计页、困难词列表、单词作答历史
- [x] 备份导出 / 导入合并（版本化协议、事件去重、状态重算、幂等）
- [x] 同步接口 `SyncProvider` + 完整可用的本地文件 Provider
- [x] 34 个自动化测试（T01–T20）、`flutter analyze` 零问题
- [x] GitHub Actions：validate / android / macos / ios 四个独立 job
- [x] macOS 快捷键：Space / 1 / 2 / 3 / Enter / ⌘F / ⌘N

## Phase 2（下一步，优先级从高到低）

1. **iPhone / Android 真机日常使用打磨**
   - 学习页手势（上滑显示释义、左右滑切词）
   - 屏幕常亮、后台返回保持当前卡
2. **真正的 GitHub 同步**
   - Fine-grained PAT + 系统安全存储（Android Keystore / Apple Keychain）
   - REST API + blob SHA 并发控制 + 冲突重试
3. **WebDAV 同步**
   - HTTPS + ETag / If-Match 条件请求
4. **发音**
   - 系统 TTS（`flutter_tts`）朗读单词，不打包千兆音频
5. **词书导入增强**
   - 一键「CET-4 / CET-6 全量词书」（从 ECDICT 标签生成）
   - 导入时按词频排序选项
6. **学习体验**
   - 拼写模式（看中文写英文）
   - 例句挖空
   - 学习时的「撤销上一张」
7. **统计增强**
   - 近 30 天学习热力图、每日曲线（简单 Canvas，不引入图表库）

## 明确推迟

- FSRS 或其它复杂调度算法（等真实使用数据积累后再评估，`review_events` 已经保留了全部
  原始记录，届时可以直接离线回放对比）
- 独立服务端 / 账号系统
- AI 生成释义、例句
- 社交、排行榜、词书商城
- App Store / Google Play 发布与签名服务配置
- 音频语料、语音识别

## 技术债

- Android release 目前是 debug 签名，正式迭代前必须换成固定 release key
- `words.customized` 是单向开关：用户改过之后词典再也不能更新该词（符合预期，但没有"恢复词典释义"的入口）
- 词书详情页一次最多渲染 5000 个词条（`WordRepository.listLimit`），超大词书需要分页
