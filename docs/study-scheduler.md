# 学习算法（algorithmVersion 1）

代码：`lib/services/study_scheduler.dart`（纯函数）、`lib/services/study_session.dart`
测试：`test/study_scheduler_test.dart`、`test/study_flow_test.dart`、`test/data_correctness_test.dart`

本阶段**保留** Phase 1 的五级阶梯，不迁移 FSRS，也不替换调度器。

## 状态与阶梯

`1 / 3 / 7 / 14 / 30` 天；答对上一级，模糊退一级并在 6 小时后重现，不认识回到底部
并在 30 分钟后重现。长间隔按本地午夜计算（"1 天"就是明天），短间隔用精确时长。
状态：`newWord(0) / learning(1) / review(2) / relearning(3)`。
每个会话同一单词最多额外重复 2 次。

## 每日口径（Phase 2 明确化）

- 每日目标是**设备全局**（`dailyNewTarget` / `dailyReviewLimit`），UI 明确标注。
- 词书只决定"从哪些词里取"，不改变每日额度。
- `TodayProgress`：
  - `newDone` — 今天学习过的**不同**新词；
  - `newRemainingAllowance` — `目标 - newDone`，下限 0；
  - `unlearnedTotal` — 范围内实际未学单词数；
  - `newAvailableToday` — `min(额度, 未学)`，这是 UI 显示的"今日可学新词"；
  - `dueTotal` — 到期总数；
  - `reviewAvailableToday` — `min(复习额度, 到期)`；
  - `backlog` — 超出复习额度的到期数，顺延到明天。
- `hasWork == false` 时不显示可点击的"开始学习"。
- 队列口径与首页一致：`buildQueue` 同样把新词数限制为 `min(剩余额度, 未学数)`。

## 专项复习

`SpecialReview.hard`（困难词：错/模糊 ≥ 1）、`recentMistakes`（14 天内答错）、
`inBook`（指定词书内已学词）是**显式入口**，不会挤占普通到期队列。

- 专项仍按剩余复习额度取词（额度为 0 时允许最多 20 词的短专项），
  所以额度仍是全局一致的；
- 作答类型仍是 `review`，照常计入今日复习数，并照常推进下一次复习时间；
- 专项**不在会话内重复**失败卡，避免"N 个词"计数失真；
- 每条事件保留 `mode = special-*`，可在词条历史中看到，也可同步。

## 手动操作

- "标记为已掌握"写入一条 `known` 作答事件（`mode = manual-mastered`），
  按算法推进阶梯。它不是直接改派生状态，因此同步合并后不会丢失。
- "重置学习进度"写入一条 `mode = reset` 事件。重放到该事件时清空此前累计，
  单词回到未学习；原始作答历史保留，可在词条详情查看。

## 重建与同步

`learning_states` 可由 `review_events` 确定性重建：

- 顺序 `(answeredAt, deviceId, id)`，时钟偏差也有稳定顺序；
- `algorithmVersion` 存在事件上，未来换算法时可解释历史；
- 合并与重建在同一事务内完成；`SyncCoordinator` 另有 pending 标记恢复路径。

## 刷新时机

应用启动、从后台恢复、跨过本地午夜、词库修改、学习完成、备份导入与同步完成后，
首页与统计的 providers 会被 invalidate。测试使用 `FixedClock.nextDay()` 验证跨日行为。
