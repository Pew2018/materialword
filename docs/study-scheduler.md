# 学习算法（Phase 1）

代码：`lib/services/study_scheduler.dart`（纯函数）
测试：`test/study_scheduler_test.dart`、`test/study_flow_test.dart`
算法版本：`StudyScheduler.algorithmVersion = 1`，写进每条 `review_events`，方便以后换算法时解释历史。

刻意不做 FSRS。这里是一个**可解释、可测试的阶梯式间隔重复**：五级阶梯
`1 / 3 / 7 / 14 / 30` 天，答对上一级，模糊下一级，不认识回到底部。

## 状态

`learning_states` 每个词一行：

| 字段 | 含义 |
| --- | --- |
| `stage` | 0 未学习 / 1 学习中 / 2 复习中 / 3 重学中 |
| `correct_count` / `hazy_count` / `wrong_count` | 累计作答次数 |
| `streak` | 连续答对次数 |
| `interval_days` | 当前间隔（阶梯值：1/3/7/14/30） |
| `last_studied_at` / `next_review_at` | 最近作答 / 下次到期时间 |

## 规则

设当前阶梯位置 `step = indexOf(interval_days)`，新词为 `-1`：

| 作答 | 新间隔 | 新阶段 | 下次复习 | 本组是否重练 |
| --- | --- | --- | --- | --- |
| 认识 | `ladder[step+1]`（封顶 30 天） | `step+1 >= 1` → 复习中，否则学习中 | 本地日 0 点 + 新间隔天 | 否 |
| 模糊 | `ladder[step-1]`（最低 1 天），`streak` 归零 | 复习中保持复习中，其余为学习中 | 现在 + 6 小时 | 是 |
| 不认识 | 回到 `ladder[0] = 1` 天，`streak` 归零 | 重学中 | 现在 + 30 分钟 | 是 |

由此得到的实际行为（与测试一致）：

- 新词答"认识" → 阶段=学习中，间隔 1 天，明天到期；
- 第二天再答"认识" → 阶段=复习中，间隔 3 天；之后 7 / 14 / 30，封顶 30；
- 任何一次"不认识" → 回到 1 天并进入重学队列，重新爬升；
- "模糊" 只降一级，而不是清零。

### 时间的两个粒度

- **天级**：`next_review_at = 本地日 0 点 + 间隔天`。这样"1 天"永远等于"明天"，
  不会出现"23:50 学的词 24 小时后才到期"的怪现象。
- **分钟级**：只有重学 / 模糊的短期回访用精确时长（30 分钟 / 6 小时）。

### 本组重练

`repeatInSession = true` 的词会被追加到当前会话队列尾部，
`StudyScheduler.maxSessionRepeats = 2` 限制最多重复 2 次，避免一个词在本次会话里无限循环。

## 队列

### 新词队列

```sql
FROM words w LEFT JOIN learning_states ls ON ls.word_id = w.id
WHERE w.deleted_at IS NULL AND (ls.stage IS NULL OR ls.stage = 0)
ORDER BY <frq_rank 升序，0 视为 999999>, <bnc_rank>, normalized
LIMIT 今日剩余新词目标
```

- 未学习的词**只会**出现在新词队列，不会混进复习队列；
- 排序用当代语料库词频优先 → 先背高频词，再背低频词；
- 同一批导入里词频未知的词按字母序，保证顺序稳定可复现。

### 复习队列

```sql
FROM words w JOIN learning_states ls ON ls.word_id = w.id
WHERE w.deleted_at IS NULL AND ls.stage != 0
  AND ls.next_review_at IS NOT NULL AND ls.next_review_at <= now
ORDER BY ls.next_review_at ASC, (ls.wrong_count*2 + ls.hazy_count) DESC, normalized
LIMIT 今日剩余复习上限
```

- 越逾期越靠前；同一天到期的词里，错得多的先复习；
- **去重**：`learning_states` 每个词只有一行，天然不会重复；
- **不会永久霸占队列**：答完一次，`next_review_at` 就被推后，当天不会再出现；
- **区分三个数字**：
  - `dueNow`：现在真正到期的总数；
  - `reviewLimit`：用户设置每天最多复习多少（默认 100）；
  - `backlog`：`dueNow - 今日剩余上限`，即今天做不完、顺延到明天的积压。
    因为到期时间是持久化的，"顺延"不需要任何额外处理，明天照常到期。
- **跨日不丢**：所有到期判断都基于持久化的 `next_review_at`，与"今天打开过没有"无关。

## 每日进度

今日新词完成数 / 复习完成数来自作答流水：

```sql
SELECT COUNT(DISTINCT word_id) FROM review_events
WHERE local_day = :today AND type = :study|review
```

- 用 `COUNT(DISTINCT word_id)`：同一个词在一次会话里被重复练习多次，只算 1 个新词（T10）；
- 用本地日期而不是 UTC 日期：用户所在时区的"今天"才是"今天"；
- 进度不落库、不缓存，每次从流水聚合，因此退出重进、换设备合并后都一致。

## 并发与幂等

- **一次作答一个事务**：`review_events` + `learning_states` 同事务写入。
- **事件 ID 幂等**：`recordAnswer(eventId:)` 若该 ID 已存在，直接返回 `duplicate: true`，不重复写。
- **重复点击防护**（`StudySession`）：
  1. 只有先"显示释义"才接受作答，答完立刻回到未显示状态 → 按钮变灰，连点第二下打不到下一张卡；
  2. `_busy` 标志保证同一次作答不会并发写两次；
  3. 每张卡记录 `answeredCardIds`，同一张卡不会二次提交。
- 会话中断：每答一张就落库，重新进入时队列由数据库重新计算，剩下的词照常出现，
  已经答过的词当天不会再作为新词出现（stage 已非 0）。
