# 文案迁移清册（Copy Inventory）

由 `lib/l10n/app_en.arb` / `app_zh.arb` 生成，列出每条用户可见文案的 key、中英文与使用位置。
重新生成：`python3 tool/gen_copy_inventory.py`。

共 **943** 条。

| # | key | 中文 | English | 使用文件 |
| --- | --- | --- | --- | --- |
| 1 | `aboutBlurb` | 离线优先的英语单词学习工具。学习记录保存在本机，开启同步后会在设备间保持一致。 | An offline-first vocabulary app. Your data stays on this device unless you turn on sync. | settings_page.dart |
| 2 | `aboutDictionary` | 内置离线词典：{count} 条词条（ECDICT，{license} 许可）。 | Built-in dictionary: {count} entries (ECDICT, {license} license). | settings_page.dart |
| 3 | `aboutSprintPlan` | 关于冲刺计划 | About Exam Prep | sprint_page.dart |
| 4 | `aboutStatistics` | 关于统计 | About Statistics | （仅文档/间接） |
| 5 | `aboutStatisticsBody` | 总览统计当前范围内的全部单词；今日只统计本机今天零时以来的作答，累计值与设备无关。作答按全部会话累计，已撤销的作答单独列出，历史记录仍会保留。 | Overview counts every word in the current scope. Today covers this device's answers since midnight; the overview is cumulative. Answers are compared across all sessions and devices, and undone answers are listed separately rather than removed from history. | （仅文档/间接） |
| 6 | `aboutSync` | 关于同步 | About Syncing | sync_settings_page.dart |
| 7 | `aboutSyncBody` | 远程数据和本机数据会合并，不会互相覆盖。⏎· 同一个单词只保留一条记录；⏎· 每次作答都单独保留，合并后重新计算学习状态；⏎· 已删除的单词和词书不会被旧备份恢复；⏎· 两台设备改了同一项时，保留较新的一次，另一份留在「同步冲突」里，可以随时改回来。⏎令牌与密码只保存在系统安全存储（钥匙串 / Keystore）中，不会写进数据库、备份文件或日志。 | Remote and local data are merged, never overwritten:⏎· one record per word;⏎· every answer is kept and progress is recomputed after merging;⏎· deleted words and word lists stay deleted;⏎· when two devices change the same item, the newer value is kept and the other copy stays under Sync Conflicts.⏎Tokens and passwords are kept only in the system secure storage (Keychain / Keystore), never in the database, a backup or a log. | sync_settings_page.dart |
| 8 | `accentAnswerNote` | 学习结果的颜色不受影响。 | Answer colors are not affected. | settings_page.dart |
| 9 | `accentBlue` | 蓝 | Blue | enum_labels.dart |
| 10 | `accentBlueGray` | 蓝灰 | Blue Gray | enum_labels.dart |
| 11 | `accentClassicGroup` | 经典配色 | Classic | （仅文档/间接） |
| 12 | `accentClearSkyBlue` | 晴空蓝 | Clear Sky Blue | enum_labels.dart |
| 13 | `accentColor` | 强调色 | Accent Color | settings_page.dart |
| 14 | `accentColorHint` | 更改应用的主题颜色。 | Change the app's theme color. | settings_page.dart |
| 15 | `accentCustom` | 自定义颜色 | Custom Color | enum_labels.dart, settings_page.dart |
| 16 | `accentCyan` | 青 | Cyan | enum_labels.dart |
| 17 | `accentDeepIndigo` | 靛青蓝 | Deep Indigo | enum_labels.dart |
| 18 | `accentDeepOrange` | 深橙 | Deep Orange | enum_labels.dart |
| 19 | `accentDeepSeaBlue` | 深海蓝 | Deep Sea Blue | enum_labels.dart |
| 20 | `accentGoldenOrange` | 流金橙 | Golden Orange | enum_labels.dart |
| 21 | `accentGrassGreen` | 青草绿 | Grass Green | enum_labels.dart |
| 22 | `accentGreen` | 绿 | Green | enum_labels.dart |
| 23 | `accentHex` | HEX 颜色 | HEX | settings_page.dart |
| 24 | `accentIndigo` | 靛蓝 | Indigo | enum_labels.dart |
| 25 | `accentJadeGreen` | 碧玉绿 | Jade Green | enum_labels.dart |
| 26 | `accentLemonYellow` | 柠檬黄 | Lemon Yellow | enum_labels.dart |
| 27 | `accentLightGreen` | 浅绿 | Light Green | enum_labels.dart |
| 28 | `accentMaterialGroup` | Material Design 配色 | Material Design | （仅文档/间接） |
| 29 | `accentOrange` | 橙 | Orange | enum_labels.dart |
| 30 | `accentOrchidPink` | 时尚粉 | Orchid Pink | enum_labels.dart |
| 31 | `accentPink` | 粉 | Pink | enum_labels.dart |
| 32 | `accentPurple` | 紫 | Purple | enum_labels.dart |
| 33 | `accentRed` | 红 | Red | enum_labels.dart |
| 34 | `accentRestoreDefault` | 恢复默认颜色 | Restore Default Color | settings_page.dart |
| 35 | `accentSkyBlue` | 天空蓝 | Sky Blue | enum_labels.dart |
| 36 | `accentSwatchSemantics` | 强调色 {name} | Accent color {name} | settings_page.dart |
| 37 | `accentTeal` | 青绿 | Teal | enum_labels.dart |
| 38 | `accentVibrantPink` | 活力红 | Vibrant Pink | enum_labels.dart |
| 39 | `accentViolet` | 魅力紫 | Violet | enum_labels.dart |
| 40 | `accessToken` | 访问令牌 | Access Token | sync_settings_page.dart |
| 41 | `accessTokenHint` | 用于访问你的私有仓库，仅保存在本机系统安全存储中。 | Used to access your private repository; kept only in this device's secure storage. | sync_settings_page.dart |
| 42 | `accuracyFormula` | 正确率 = 认识次数 ÷ 全部作答次数，累计计算。 | Accuracy = Know answers ÷ all answers, counted across every session and device. | （仅文档/间接） |
| 43 | `accuracyLabel` | 正确率 | Accuracy | statistics_page.dart |
| 44 | `accuracyValue` | 正确率 {value} | Accuracy {value} | study_page.dart |
| 45 | `actionAddWord` | 添加单词 | Add Word | navigation.dart, quick_add_page.dart, word_book_detail_page.dart, word_management_page.dart |
| 46 | `actionAddWordShortcutMac` | 添加单词（⌘N） | Add Word (⌘N) | navigation.dart |
| 47 | `actionAddWordsShortcut` | 添加单词（{shortcut}） | Add Word ({shortcut}) | （仅文档/间接） |
| 48 | `addFailed` | 添加失败，请重试。 | Couldn't add. Try again. | dictionary_page.dart |
| 49 | `addListFirst` | 还没有词书，请先创建。 | Add a word list first. | word_management_page.dart |
| 50 | `addMultiple` | 批量添加 | Add Multiple Words | quick_add_page.dart |
| 51 | `addOneWord` | 添加单个单词 | Add One Word | quick_add_page.dart |
| 52 | `addSampleList` | 添加示例词书 | Add Sample Word List | dashboard_page.dart |
| 53 | `addTag` | 添加标签 | Add Tag | word_management_page.dart, word_metadata_widgets.dart |
| 54 | `addTermAsWord` | 添加「{term}」 | Add “{term}” | dictionary_page.dart |
| 55 | `addToExistingList` | 加入已有词书 | Add to an Existing Word List | import_page.dart |
| 56 | `addToWordList` | 加入词书 | Add to Word List | dictionary_page.dart, word_management_page.dart |
| 57 | `addedToWordList` | 已加入 {count} 个单词 | {count, plural, =1{Added 1 word} other{Added {count} words}} | word_management_page.dart |
| 58 | `allTags` | 全部标签 | All Tags | word_management_page.dart |
| 59 | `allWordLists` | 全部词书 | All Word Lists | settings_page.dart, statistics_page.dart, word_management_page.dart |
| 60 | `allWordsNote` | 「全部单词」可以按词书、学习进度和困难程度筛选，并批量加入词书、移出或删除。 | All Words filters by list, progress and difficulty, and can add, remove or delete in bulk. | wordbooks_page.dart |
| 61 | `allowOverReviewLimit` | 允许额外复习 | Allow Extra Reviews | sprint_page.dart |
| 62 | `answerBreakdown` | 作答明细 | Answer Breakdown | statistics_page.dart |
| 63 | `answerDontKnow` | 不认识 | Don't Know | enum_labels.dart |
| 64 | `answerHistory` | 作答历史（最近 {count} 条） | Answer History (last {count}) | word_detail_page.dart, word_management_page.dart |
| 65 | `answerKnow` | 认识 | Know | enum_labels.dart |
| 66 | `answerNotSure` | 模糊 | Not Sure | enum_labels.dart |
| 67 | `answersCount` | 作答次数 | Answers | practice_page.dart, statistics_page.dart |
| 68 | `answersLast7Days` | 最近 7 天作答 | Answers in the Last 7 Days | statistics_page.dart |
| 69 | `answersTimes` | 作答 {count} 次 | {count, plural, =1{1 answer} other{{count} answers}} | word_management_page.dart |
| 70 | `appLanguage` | 应用语言 | App Language | settings_page.dart |
| 71 | `appLanguageChinese` | 简体中文 | 简体中文 | l10n.dart |
| 72 | `appLanguageEnglish` | English | English | l10n.dart |
| 73 | `appLanguageSystem` | 跟随系统 | System Default | l10n.dart |
| 74 | `appPassword` | 密码或应用专用密码 | Password or App Password | sync_settings_page.dart |
| 75 | `appVersionLine` | 应用版本：{version} | App version: {version} | backup_page.dart |
| 76 | `apply` | 应用 | Apply | settings_page.dart |
| 77 | `autoBackupDaily` | 每日自动备份 | Daily Automatic Backup | backup_page.dart |
| 78 | `autoBackupHint` | 启动、恢复前台与停留前台期间检查；只有数据变化才创建新副本，保留最近 {count} 份。 | Checked at launch, on resume and while the app stays open. A new copy is written only when data changed, keeping the last {count}. | （仅文档/间接） |
| 79 | `autoBackupHintCount` | 启动、恢复前台与停留前台期间检查；只有数据变化才创建新副本，保留最近 {count} 份。 | Checked at launch, on resume and while the app stays open. A new copy is written only when data changed, keeping the last {count}. | backup_page.dart |
| 80 | `autoBackupLocal` | 自动备份（本机） | Automatic Backup (Local) | backup_page.dart |
| 81 | `autoPronounce` | 自动发音 | Auto-Pronunciation | settings_page.dart |
| 82 | `autoPronounceHint` | 语音是否可离线使用取决于系统安装的语音包 | Offline playback depends on the installed voice. | settings_page.dart |
| 83 | `autoSyncNotEnabled` | 自动同步尚未启用：请先「测试连接」完成安全写入验证。 | Automatic sync is off: run Test Connection to verify safe writes first. | sync_settings_page.dart |
| 84 | `autoSyncNotEnabledReason` | 自动同步尚未启用：{reason}。 | Automatic sync is off: {reason}. | sync_settings_page.dart |
| 85 | `back` | 返回 | Back | practice_page.dart, study_page.dart |
| 86 | `backlogCarried` | 还有 {count} 个到期单词顺延到明天。 | {count, plural, =1{1 due word moves to tomorrow.} other{{count} due words move to tomorrow.}} | study_page.dart |
| 87 | `backlogNote` | {count} 个到期单词超出今日复习上限，会顺延到明天，不会丢失。 | {count, plural, =1{1 due word is beyond today's review limit. It moves to tomorrow.} other{{count} due words are beyond today's review limit. They move to tomorrow.}} | dashboard_page.dart |
| 88 | `backupActions` | 备份操作 | Backup Actions | backup_page.dart |
| 89 | `backupAndRestore` | 备份与恢复 | Backup & Restore | backup_page.dart |
| 90 | `backupContentsNote` | 备份包含单词、词书、关联（含删除标记）、作答历史、收藏、标签、学习目标与设备设置。不包含账号、密码或任何同步凭据。 | A backup contains words, word lists, links (including delete marks), answer history, favorites, tags, study goals and device settings. It never contains accounts, passwords or sync credentials. | backup_page.dart |
| 91 | `backupDeleted` | 已删除恢复副本 | Backup deleted. | backup_page.dart |
| 92 | `backupExported` | 备份已导出 | Backup exported. | sync_settings_page.dart |
| 93 | `backupExportedShort` | 已导出恢复副本 | Backup exported. | backup_page.dart |
| 94 | `backupInfo` | 备份信息 | Backup Info | backup_page.dart |
| 95 | `backupInfoFavorites` | 收藏 {count} | {count} favorites | backup_labels.dart |
| 96 | `backupInfoSummary` | 词条 {words} · 词书 {books} · 关联 {entries} · 学习记录 {events} | {words} words · {books} word lists · {entries} links · {events} answers | backup_labels.dart |
| 97 | `backupInfoTags` | 标签 {count} | {count} tags | backup_labels.dart |
| 98 | `backupInfoUnreadable` | 无法读取：{reason} | Unreadable: {reason} | backup_labels.dart |
| 99 | `backupRestore` | 备份与恢复 | Backup & Restore | settings_page.dart |
| 100 | `backupRestoreSubtitle` | 备份和恢复学习数据 | Back up and restore your study data. | settings_page.dart |
| 101 | `backupSavedAs` | 备份已保存：{name} | Backup saved: {name} | backup_page.dart |
| 102 | `backupUnreadable` | 此备份无法读取：{problem} | This backup can't be read: {problem} | backup_page.dart |
| 103 | `batchAddFailed` | 批量添加失败，请重试。 | Couldn't add these words. Try again. | quick_add_page.dart |
| 104 | `batchDefinitionStats` | 已有释义或可由词典补全 {withMeaning} 个；需要人工补充 {withoutMeaning} 个。 | {withMeaning} have a meaning or can be filled from the dictionary; {withoutMeaning} need one. | quick_add_page.dart |
| 105 | `batchDuplicates` | 文件内重复 {count} 个已合并 | {count} duplicates merged | quick_add_page.dart |
| 106 | `batchFavoritesAndTags` | 收藏与标签 | Favorites & Tags | word_management_page.dart |
| 107 | `batchInvalidLines` | 忽略 {count} 行无效内容 | {count} lines ignored | quick_add_page.dart |
| 108 | `batchKeepsProgress` | 已有学习进度会被保留。 | Existing progress is kept. | quick_add_page.dart |
| 109 | `batchWordsPerLine` | 每行输入一个单词 | One word per line | quick_add_page.dart |
| 110 | `branch` | 分支 | Branch | sync_settings_page.dart |
| 111 | `breakdownNote` | 练习计入作答次数，但不影响复习计划；标记掌握或重置进度不计入作答统计。 | Practice counts as answers but doesn't affect your review plan. Marking as mastered or resetting progress doesn't count. | statistics_page.dart |
| 112 | `breakdownPractice` | 练习 | Practice | statistics_page.dart |
| 113 | `breakdownRepeat` | 本轮复练 | Repeat Practice | statistics_page.dart |
| 114 | `breakdownSpecial` | 专项复习 | Targeted Review | statistics_page.dart |
| 115 | `breakdownStudyReview` | 学习与复习 | Study & Review | statistics_page.dart |
| 116 | `cancelDownload` | 取消下载 | Cancel Download | import_page.dart |
| 117 | `cannotBrowseRemote` | 无法浏览远程文件夹。 | Couldn't browse the remote folder. | sync_settings_page.dart |
| 118 | `cannotReadBackup` | 无法读取 | Can't Read | backup_page.dart |
| 119 | `cannotReadFile` | 无法读取此文件（仅支持本机文件）。 | Couldn't read this file. Only local files are supported. | import_page.dart |
| 120 | `cannotReadFolder` | 无法读取文件夹。 | Couldn't read this folder. | webdav_directory_picker.dart |
| 121 | `checkBackup` | 检查备份 | Check Backup | backup_page.dart |
| 122 | `checkIntegrity` | 检查备份 | Check Backup | backup_page.dart |
| 123 | `chineseMeaning` | 中文释义 | Chinese Meaning | quick_add_page.dart, word_detail_page.dart |
| 124 | `chooseCorrectWord` | 选择正确的单词 | Choose the correct word above. | practice_page.dart |
| 125 | `chooseDate` | 请选择 | Choose | sprint_page.dart |
| 126 | `chooseFile` | 选择文件 | Choose File | import_page.dart |
| 127 | `chooseFormat` | 选择格式 | Choose Format | wordbooks_page.dart |
| 128 | `chooseListFirst` | 请先在上方选择一个词书，再移出单词。 | Choose a word list above first. | word_management_page.dart |
| 129 | `chooseRemoteFolder` | 选择远程文件夹 | Choose Remote Folder | sync_settings_page.dart, webdav_directory_picker.dart |
| 130 | `chooseTag` | 选择标签 | Choose Tag | word_metadata_widgets.dart |
| 131 | `chooseTargetList` | 请先选择目标词书。 | Choose a word list first. | import_page.dart |
| 132 | `chooseThisFolder` | 选择此文件夹 | Choose This Folder | webdav_directory_picker.dart |
| 133 | `chooseWordList` | 请选择词书 | Choose a word list | import_page.dart |
| 134 | `chooseWordListFile` | 选择词书文件 | Choose a Word List File | import_page.dart |
| 135 | `clearLogs` | 清除日志 | Clear Logs | diagnostics_page.dart |
| 136 | `clearSelection` | 取消选择 | Clear | word_management_page.dart |
| 137 | `close` | 关闭 | Close | backup_page.dart |
| 138 | `clozeEmptyMessage` | 例句填空只使用词条自带的例句。可以先补充例句，或改用其他练习方式。 | Fill in the Blank uses only the example stored with each word. Add an example, or try another practice. | practice_page.dart |
| 139 | `clozeUsesOwnSentence` | 仅使用词条自带的例句。 | Uses the example stored with the word. | dashboard_page.dart |
| 140 | `commonAdd` | 添加 | Add | （仅文档/间接） |
| 141 | `commonAll` | 全部 | All | （仅文档/间接） |
| 142 | `commonCancel` | 取消 | Cancel | import_page.dart, sprint_page.dart, sync_settings_page.dart, webdav_directory_picker.dart, wordbooks_page.dart |
| 143 | `commonClear` | 清除 | Clear | dictionary_page.dart |
| 144 | `commonClose` | 关闭 | Close | import_page.dart, sprint_page.dart, sync_settings_page.dart |
| 145 | `commonContinue` | 继续 | Continue | （仅文档/间接） |
| 146 | `commonCopy` | 复制 | Copy | （仅文档/间接） |
| 147 | `commonDelete` | 删除 | Delete | backup_page.dart, word_detail_page.dart, word_management_page.dart, word_metadata_widgets.dart, wordbooks_page.dart |
| 148 | `commonDone` | 完成 | Done | import_page.dart, practice_page.dart, study_page.dart |
| 149 | `commonEdit` | 编辑 | Edit | （仅文档/间接） |
| 150 | `commonExport` | 导出 | Export | （仅文档/间接） |
| 151 | `commonImport` | 导入 | Import | （仅文档/间接） |
| 152 | `commonRefresh` | 刷新 | Refresh | webdav_directory_picker.dart, word_management_page.dart |
| 153 | `commonRemove` | 移除 | Remove | word_detail_page.dart, word_management_page.dart |
| 154 | `commonRename` | 重命名 | Rename | wordbooks_page.dart |
| 155 | `commonRestore` | 恢复 | Restore | sync_settings_page.dart |
| 156 | `commonRetry` | 重试 | Try Again | （仅文档/间接） |
| 157 | `commonSave` | 保存 | Save | quick_add_page.dart, sprint_page.dart, word_detail_page.dart |
| 158 | `commonTest` | 测试 | Test | （仅文档/间接） |
| 159 | `configChanged` | 连接设置已改变，请重新打开同步页后设置。 | The connection settings changed. Open this page again. | sync_settings_page.dart |
| 160 | `confirmRefresh` | 确认刷新 | Refresh | wordbooks_page.dart |
| 161 | `conflictExplain` | 另一台设备也修改了同一项内容。MaterialWord 保留了较新的版本，把另一份内容留在这里备用。恢复会把它改回来，并作为一次新的修改同步；没有恢复按钮的记录只用于排查问题。 | Another device changed the same item. MaterialWord kept the newer value and stored the other one here. Restoring changes it back and syncs that as a new edit; entries without a restore action are for diagnostics only. | sync_settings_page.dart |
| 162 | `connectionNotVerified` | 尚未验证连接 | Connection Not Verified | sync_settings_page.dart |
| 163 | `connectionNotVerifiedHint` | 填写地址与账号后点「测试连接」。同步前必须先验证安全写入能力。 | Enter the address and account, then run Test Connection. Safe writes must be verified before syncing. | sync_settings_page.dart |
| 164 | `connectionSettings` | 连接设置 | Connection Settings | sync_settings_page.dart |
| 165 | `connectionTestFailed` | 无法测试连接。 | Couldn't test this connection. | sync_settings_page.dart |
| 166 | `contentUpdatedReview` | 单词信息已更新，请重新查看后作答。 | This word was updated. Check it again before answering. | error_labels.dart |
| 167 | `continuePracticing` | 继续练习 | Continue Practicing | practice_page.dart |
| 168 | `continueSprint` | 继续本轮冲刺 | Continue Exam Prep | sprint_page.dart |
| 169 | `continueStudying` | 继续学习 | Continue Studying | dashboard_page.dart, study_page.dart |
| 170 | `correct` | 正确 | Correct | practice_page.dart |
| 171 | `correctSpelling` | 正确拼写：{answer} | Correct spelling: {answer} | practice_page.dart |
| 172 | `create` | 创建 | Create | webdav_directory_picker.dart |
| 173 | `createListFirst` | 请先创建或导入词书。 | Add or import a word list first. | quick_add_page.dart, sprint_page.dart |
| 174 | `createTag` | 创建标签 | Create Tag | word_metadata_widgets.dart |
| 175 | `createdAtLine` | 创建时间：{time} | Created: {time} | backup_page.dart |
| 176 | `createdUnknown` | 未知 | unknown | backup_page.dart |
| 177 | `credentialsNotSaved` | {reason}。凭据没有保存，请重新输入；离线学习不受影响。 | {reason}. The credentials were not saved; enter them again. Offline study is unaffected. | （仅文档/间接） |
| 178 | `credentialsNotStored` | 凭据没有保存，请重新输入；离线学习不受影响。 | The credentials were not saved. Enter them again. Offline study is unaffected. | sync_settings_page.dart |
| 179 | `credentialsUnavailable` | 已保存的同步凭据无法读取，请重新输入；离线学习不受影响。 | The saved sync credentials can't be read. Enter them again. Offline study is unaffected. | sync_settings_page.dart |
| 180 | `credentialsUnreadable` | {reason}。已保存的同步凭据无法读取，请重新输入；离线学习不受影响。 | {reason}. The saved credentials can't be read; enter them again. Offline study is unaffected. | （仅文档/间接） |
| 181 | `crossDeviceSync` | 跨设备同步 | Cross-device Sync | backup_page.dart |
| 182 | `cumulativeCorrect` | 累计正确 | Correct | statistics_page.dart |
| 183 | `cumulativeHazy` | 累计模糊 | Not Sure | statistics_page.dart |
| 184 | `cumulativeWrong` | 累计错误 | Wrong | statistics_page.dart |
| 185 | `currentTag` | 当前 | Current | wordbooks_page.dart |
| 186 | `customAccentTitle` | 自定义颜色 | Custom Color | settings_page.dart |
| 187 | `dailyGoalsNote` | 目标按设备计算。超出复习上限的单词会顺延到明天，不会丢失。 | Goals apply to this device. Words beyond the review limit move to tomorrow. | settings_page.dart |
| 188 | `dailyNewWords` | 每日新词目标 | Daily New Words | settings_page.dart |
| 189 | `dailyReviewLimit` | 每日复习上限 | Daily Review Limit | settings_page.dart |
| 190 | `dataFilePath` | 文件路径 | File Path | sync_settings_page.dart |
| 191 | `decrease` | 减少 | Decrease | settings_page.dart |
| 192 | `deleteBackup` | 删除 | Delete | （仅文档/间接） |
| 193 | `deleteBackupBody` | {name}⏎⏎只会删除这个本机文件；数据库里的学习数据不受影响。 | {name}⏎⏎Only this local file is deleted. Study data in the database is not affected. | backup_page.dart |
| 194 | `deleteBackupTitle` | 删除备份？ | Delete Backup? | backup_page.dart |
| 195 | `deleteTag` | 删除标签 | Delete Tag | word_metadata_widgets.dart |
| 196 | `deleteTagBody` | 删除「{name}」及其单词关联？单词、收藏和学习记录都会保留。 | Delete “{name}” and its word links? Words, favorites and study history are kept. | word_metadata_widgets.dart |
| 197 | `deleteWordBodyName` | 从全部单词中删除「{word}」？所有词书都会移除它，学习记录仍会保留。只想移出一个词书请用「移出词书」。 | Delete “{word}” from every word list? Study history is kept. To remove it from one list only, use Remove from Word List. | word_detail_page.dart |
| 198 | `deleteWordListBody` | 「{name}」将被删除。单词和学习记录仍会保留。 | “{name}” will be deleted. Words and study history are kept. | wordbooks_page.dart |
| 199 | `deleteWordListTitle` | 删除词书？ | Delete Word List? | wordbooks_page.dart |
| 200 | `deleteWordsBodyBulk` | 从全部单词中删除选中的 {count} 个单词？它们会从所有词书中移除，学习记录仍会保留。如果只想从某个词书移出，请用「移出词书」。 | Delete {count, plural, =1{1 word} other{{count} words}} from every word list? Study history is kept. To take a word out of one list only, use Remove from Word List. | word_management_page.dart |
| 201 | `deleteWordsBodyOne` | 从全部单词中删除此单词？所有词书都会移除它，学习记录仍会保留。如果只想从一个词书移出，请使用「移出词书」。 | Delete this word from every word list? Study history is kept. To take it out of one list only, use Remove from Word List. | word_management_page.dart |
| 202 | `deleteWordsTitle` | 删除单词？ | Delete Words? | word_management_page.dart |
| 203 | `deleted` | 已删除 | Deleted | sync_settings_page.dart |
| 204 | `deletedWordSuffix` | （已删除） |  (deleted) | study_page.dart |
| 205 | `deletedWordsCount` | 已删除 {count} 个单词 | {count, plural, =1{Deleted 1 word} other{Deleted {count} words}} | word_management_page.dart |
| 206 | `detailedLogging` | 记录详细日志 | Detailed Logs | diagnostics_page.dart |
| 207 | `detailedLoggingHint` | 默认关闭。开启后只保留最近 400 条、24 小时，并自动脱敏。 | Off by default. When on, keeps the last 400 entries for 24 hours, with sensitive values removed. | diagnostics_page.dart |
| 208 | `deviceIdCopied` | 已复制设备标识（仅用于排查同步问题） | Device ID copied (used only to investigate sync problems). | diagnostics_page.dart |
| 209 | `deviceIdLabel` | 设备标识 | Device ID | diagnostics_page.dart |
| 210 | `deviceSection` | 设备 | Device | diagnostics_page.dart |
| 211 | `diagnosticOnly` | 仅用于诊断，无法恢复 | Diagnostic only, can't be restored | sync_settings_page.dart |
| 212 | `diagnostics` | 诊断信息 | Diagnostics | diagnostics_page.dart, settings_page.dart |
| 213 | `diagnosticsExportFailed` | 导出诊断信息失败。 | Couldn't export diagnostics. | diagnostics_page.dart |
| 214 | `diagnosticsExported` | 诊断信息已导出（不含账号与学习内容） | Diagnostics exported (no account or study content). | diagnostics_page.dart |
| 215 | `diagnosticsPrivacy` | 诊断信息不会包含密码、认证信息、词条内容或个人笔记；同步配置只记录同步方式，不记录地址、账号或路径。 | Diagnostics never include passwords, credentials, word content or personal notes. The sync configuration records only the sync method, not the address, account or path. | diagnostics_page.dart |
| 216 | `diagnosticsSubtitle` | 版本信息、运行日志与问题反馈 | Version, logs and troubleshooting. | settings_page.dart |
| 217 | `dictFilled` | 已从词典补全。 | Filled from the dictionary. | quick_add_page.dart |
| 218 | `dictLookupFailed` | 无法查询词典，可手动填写释义后保存。 | Couldn't query the dictionary. You can type the meaning yourself. | quick_add_page.dart |
| 219 | `dictMissingNote` | 词典未收录也可以直接保存，之后可在单词详情中补充释义。 | You can save even if the dictionary doesn't have it, and fill in the meaning later. | quick_add_page.dart |
| 220 | `dictNotFoundManual` | 未找到释义，可手动添加。 | No meaning found. You can add one by hand. | quick_add_page.dart |
| 221 | `dictionaryEmptyBody` | 在 {count} 个英语单词中查找，并可直接加入词书。 | Search {count} English words and add them straight to a word list. | dictionary_page.dart |
| 222 | `dictionaryHint` | 点一行查看单词。点右侧「+」把单词加入当前词书；已有单词会保留学习进度和笔记。 | Tap a row to view the word. Use + to add it to the current list. Existing words keep their progress and notes. | dictionary_page.dart |
| 223 | `dictionaryResultsCount` | 查询结果（{count}） | Results ({count}) | dictionary_page.dart |
| 224 | `dictionarySearchFailed` | 无法查询词典。 | Couldn't search the dictionary. | dictionary_page.dart |
| 225 | `difficultWords` | 困难词 | Difficult Words | dashboard_page.dart, sprint_page.dart, statistics_page.dart |
| 226 | `discardedValue` | 被覆盖：{value} | Overwritten: {value} | sync_settings_page.dart |
| 227 | `distinctAnsweredWords` | 作答单词数 | Words Answered | statistics_page.dart |
| 228 | `distinctWordsAnswered` | 不重复的作答单词 | Distinct Words | statistics_page.dart |
| 229 | `download` | 下载 | Download | import_page.dart |
| 230 | `downloadCancelled` | 已取消下载，未写入任何数据 | Download canceled. Nothing was written. | import_page.dart |
| 231 | `downloadLink` | 词书下载链接 | Word List Link (TXT / CSV / JSON) | import_page.dart |
| 232 | `downloadParseFailed` | 无法下载或解析此链接，请检查文件。 | Couldn't download or read this link. Check the file. | import_page.dart |
| 233 | `draftNotSaved` | 连接设置尚未保存，自动选项会在「立即同步」时一并保存和验证。 | The connection settings aren't saved yet. Auto options are saved and verified when you tap Sync Now. | sync_settings_page.dart |
| 234 | `editWord` | 编辑单词 | Edit Word | study_page.dart, word_management_page.dart |
| 235 | `editedTag` | 已编辑 | Edited | word_detail_page.dart |
| 236 | `emptyFilterHint` | 换个筛选条件，或先添加单词。 | Try another filter, or add words first. | word_management_page.dart |
| 237 | `emptyInitBody` | 远程同步文件为空。⏎⏎是否使用本机学习数据初始化这个文件？初始化会记录当前版本，若其他设备在此期间写入，本次初始化会被拒绝，不会覆盖对方的数据。 | The remote sync file is empty.⏎⏎Initialise it with this device's data? The current version is recorded, so if another device writes meanwhile this initialisation is rejected instead of overwriting it. | sync_settings_page.dart |
| 238 | `emptyValue` | （空） | (empty) | sync_settings_page.dart |
| 239 | `endSprint` | 结束冲刺 | End Exam Prep | sprint_page.dart |
| 240 | `englishDefinition` | 英文释义 | English Definition | quick_add_page.dart, study_page.dart, word_detail_page.dart |
| 241 | `englishVoice` | 英语语音 | English Voice | settings_page.dart |
| 242 | `englishWord` | 英文单词 | English Word | quick_add_page.dart |
| 243 | `enterEnglishWord` | 请输入英文单词。 | Enter an English word. | quick_add_page.dart |
| 244 | `enterExactValue` | 输入具体数值 | Enter a number | settings_page.dart |
| 245 | `enterNumberInRange` | 请输入 {min}–{max} 之间的数字 | Enter a number between {min} and {max}. | settings_page.dart |
| 246 | `errorAuthFailed` | 无法登录，请检查账号和密码。 | Unable to sign in. Check your credentials. | error_labels.dart |
| 247 | `errorGeneric` | 出现问题，请重试。 | Something went wrong. Try again. | error_labels.dart, word_metadata_widgets.dart |
| 248 | `errorInvalidBackup` | 此文件不是有效的备份。 | This file is not a valid backup. | error_labels.dart |
| 249 | `errorLoadFailed` | 加载失败，请重试。 | Couldn't load this. Try again. | dashboard_page.dart, word_management_page.dart |
| 250 | `errorNetwork` | 网络不可用。 | No network connection. | error_labels.dart |
| 251 | `errorPermission` | 没有权限执行此操作。 | No permission to do that. | error_labels.dart |
| 252 | `errorRateChip` | 错 {percent}% | {percent}% wrong | word_management_page.dart |
| 253 | `errorRateLabel` | 错误率 {value} | Error rate {value} | word_management_page.dart |
| 254 | `errorRemoteFileMissing` | 远程同步文件不存在。 | The sync file is missing from the remote location. | error_labels.dart |
| 255 | `errorSaveFailed` | 保存失败，请重试。 | Couldn't save. Try again. | quick_add_page.dart, word_detail_page.dart |
| 256 | `errorTimeout` | 连接超时，请重试。 | The connection timed out. Try again. | error_labels.dart |
| 257 | `etagNote` | 同步使用条件请求（ETag）保护多设备同时修改；服务器不支持时，本页不会启用自动同步。 | Sync uses conditional requests (ETag) to protect concurrent edits; automatic sync stays off when a server doesn't support them. | sync_settings_page.dart |
| 258 | `eventManual` | 手动标记 | Manual | word_management_page.dart |
| 259 | `eventNewStudy` | 新词学习 | New | word_detail_page.dart, word_management_page.dart |
| 260 | `eventReset` | 重置 | Reset | word_management_page.dart |
| 261 | `eventReview` | 复习 | Review | word_detail_page.dart, word_management_page.dart |
| 262 | `eventSpecial` | 专项 | Targeted | word_management_page.dart |
| 263 | `examDateLabel` | 考试日期：{date} | Exam date: {date} | sprint_page.dart |
| 264 | `examInDays` | 距离考试 {days} 天 | Exam in {days} days | sprint_page.dart |
| 265 | `examPassedDays` | 考试日期已过 {days} 天 | Exam was {days} days ago | sprint_page.dart |
| 266 | `examToday` | 今天考试 | Exam today | sprint_page.dart |
| 267 | `exampleSentence` | 例句 | Example | quick_add_page.dart, study_page.dart, word_detail_page.dart |
| 268 | `exportBackup` | 导出备份 | Export Backup | sync_settings_page.dart |
| 269 | `exportBackupDone` | 备份已导出 | Backup exported. | （仅文档/间接） |
| 270 | `exportCanceled` | 已取消导出 | Export canceled. | backup_page.dart |
| 271 | `exportCancelled` | 已取消导出 | Export canceled. | diagnostics_page.dart, word_book_detail_page.dart, wordbooks_page.dart |
| 272 | `exportContentNote` | 只导出词条内容：不含学习记录、笔记历史与同步凭据。完整备份请到「设置 → 备份与恢复」。 | Exports word content only: no study history, notes or credentials. Use Backup & Restore for a full backup. | wordbooks_page.dart |
| 273 | `exportDiagnosticsHint` | 版本、数据库与词典统计、同步状态；不含账号和学习内容。 | Version, database and dictionary statistics, sync status. No account or study content. | diagnostics_page.dart |
| 274 | `exportDiagnosticsReport` | 导出诊断报告 | Export Diagnostics | diagnostics_page.dart |
| 275 | `exportDone` | 已导出 {books} 个词书、{words} 条词条内容（不含学习记录） | Exported {books} word lists · {words} words (no study history). | wordbooks_page.dart |
| 276 | `exportDoneSingle` | 已导出 {count} 个单词（不含学习记录） | Exported {count} words (no study history). | word_book_detail_page.dart |
| 277 | `exportFailed` | 导出失败，请重试。 | Couldn't export. Try again. | word_book_detail_page.dart, wordbooks_page.dart |
| 278 | `exportFormatCsv` | CSV（含释义与例句） | CSV (with meanings and examples) | export_labels.dart |
| 279 | `exportFormatJson` | JSON（结构化字段，可无损往返） | JSON (structured, lossless round trip) | export_labels.dart |
| 280 | `exportFormatTxt` | 纯文本（每行一个单词） | Plain text (one word per line) | export_labels.dart |
| 281 | `exportListTitle` | 导出词书 | Export Word List | word_book_detail_page.dart, wordbooks_page.dart |
| 282 | `exportPickFailed` | 导出失败，请重新选择保存位置。 | Couldn't export. Choose another location. | sync_settings_page.dart |
| 283 | `exportSelected` | 导出 {count} 个词书 | Export {count, plural, =1{1 Word List} other{{count} Word Lists}} | wordbooks_page.dart |
| 284 | `exportTo` | 导出备份… | Export Backup… | backup_page.dart |
| 285 | `exportToHint` | 通过系统文件选择器保存到任意位置（含设备设置） | Saves anywhere through the system file picker (includes device settings). | backup_page.dart |
| 286 | `favoriteFailed` | 收藏操作失败，请重试。 | Couldn't update favorites. Try again. | word_metadata_widgets.dart |
| 287 | `favoriteSelected` | 收藏 | Add to Favorites | word_management_page.dart |
| 288 | `favoriteWord` | 收藏单词 | Add to Favorites | word_metadata_widgets.dart |
| 289 | `favoritesOnly` | 仅收藏 | Favorites only | word_management_page.dart |
| 290 | `fieldBnc` | BNC 词频 | BNC Rank | sync_settings_page.dart |
| 291 | `fieldBookDescription` | 词书描述 | Word List Description | sync_settings_page.dart |
| 292 | `fieldBookName` | 词书名称 | Word List Name | sync_settings_page.dart |
| 293 | `fieldBookSourceType` | 词书来源类型 | Word List Source Type | sync_settings_page.dart |
| 294 | `fieldBookSourceUrl` | 词书来源链接 | Word List Source Link | sync_settings_page.dart |
| 295 | `fieldCoca` | COCA 词频 | COCA Rank | sync_settings_page.dart |
| 296 | `fieldDefinition` | 英文释义 | English Definition | sync_settings_page.dart |
| 297 | `fieldDeleted` | 删除状态 | Deleted | sync_settings_page.dart |
| 298 | `fieldExamTags` | 考试标签 | Exam Tags | sync_settings_page.dart |
| 299 | `fieldExample` | 例句 | Example | sync_settings_page.dart |
| 300 | `fieldNote` | 笔记 | Notes | sync_settings_page.dart |
| 301 | `fieldPhonetic` | 音标 | Phonetics | sync_settings_page.dart |
| 302 | `fieldPhrase` | 短语 | Phrases | sync_settings_page.dart |
| 303 | `fieldPos` | 词性 | Part of Speech | sync_settings_page.dart |
| 304 | `fieldSource` | 来源 | Source | sync_settings_page.dart |
| 305 | `fieldTranslation` | 释义 | Meaning | sync_settings_page.dart |
| 306 | `fieldWord` | 单词 | Word | sync_settings_page.dart |
| 307 | `fileName` | 文件名称 | File Name | sync_settings_page.dart |
| 308 | `fileRowsSummary` | 文件共有 {total} 行，其中 {skipped} 行不会被导入（见下方原因）。 | {total} lines. {skipped} won't be imported (see below). | import_page.dart |
| 309 | `fillFromDictionary` | 从词典补全 | Fill from Dictionary | word_detail_page.dart |
| 310 | `filledFromDictionary` | 已从词典补全空白字段，记得保存。 | Blank fields were filled from the dictionary. Save to keep them. | word_detail_page.dart |
| 311 | `filterAll` | 全部 | All | enum_labels.dart |
| 312 | `filterHard` | 困难词 | Difficult Words | enum_labels.dart |
| 313 | `filterLearning` | 学习中 | Learning | enum_labels.dart |
| 314 | `filterMastered` | 已掌握 | Mastered | enum_labels.dart |
| 315 | `filterRelearning` | 重学中 | Relearning | enum_labels.dart |
| 316 | `filterReviewing` | 复习中 | Reviewing | enum_labels.dart |
| 317 | `filterUnlearned` | 未学 | Not Studied | enum_labels.dart |
| 318 | `firstRunBody` | 导入你自己的单词表，或先添加一份示例词书熟悉学习流程。也可以点右下角「+」手动添加。 | Import your own word list, or add the sample list to try the learning flow. You can also tap + to add words by hand. | dashboard_page.dart |
| 319 | `firstSyncBody` | 首次同步会把远程数据与本机数据合并，不会覆盖本机学习进度，也不会删除本机单词。⏎⏎继续吗？ | The first sync merges the remote data with this device. It won't overwrite local progress and won't delete local words.⏎⏎Continue? | sync_settings_page.dart |
| 320 | `firstSyncTitle` | 首次同步 | First Sync | sync_settings_page.dart |
| 321 | `folderName` | 文件夹名称 | Folder Name | webdav_directory_picker.dart |
| 322 | `formatHelp` | 格式说明 | Format | import_page.dart |
| 323 | `formatHelpCsv` | CSV⏎首行表头，必须包含 word 列，可选 phonetic / pos / translation / definition / example / note。 | CSV⏎One header row, and a word column is required. phonetic / pos / translation / definition / example / note are optional. | import_page.dart |
| 324 | `formatHelpFooter` | 文件需为 UTF-8 编码。单次最多导入 {entries} 个单词、{megabytes} MB；下载链接必须为 HTTPS。导入前会用离线词典补全音标与释义，已有学习进度与笔记不会被覆盖。 | Files must be UTF-8. One import is limited to {entries} words and {megabytes} MB; download links must be HTTPS. Missing phonetics and meanings are filled in from the offline dictionary, and existing progress and notes are never overwritten. | import_page.dart |
| 325 | `formatHelpJson` | JSON⏎包含 schemaVersion、可选的 name 和 words 数组。每个词条是一个对象，必须有 word，可选 translation、phonetic、pos、definition、example、note。 | JSON⏎A schemaVersion, an optional name, and a words array. Each entry is an object with word, plus optional translation, phonetic, pos, definition, example and note. | import_page.dart |
| 326 | `formatHelpTxt` | TXT⏎每行一个单词，可在制表符或逗号后附带释义：⏎  abandon⏎  abandon	v. 放弃 | TXT⏎One word per line. An optional meaning can follow a tab or a comma:⏎  abandon⏎  abandon	v. to give up | import_page.dart |
| 327 | `formatSummary` | TXT 每行一个单词；CSV 需包含 word 列；JSON 需包含 words 数组。 | TXT: one word per line. CSV: a word column is required. JSON: a words array is required. | import_page.dart |
| 328 | `foundWordCount` | 找到 {count} 个单词 | {count, plural, =1{Found 1 word} other{Found {count} words}} | quick_add_page.dart |
| 329 | `githubHint` | 使用私有仓库保存学习数据 | Keeps study data in a private repository. | sync_settings_page.dart |
| 330 | `githubOwner` | GitHub 用户名或组织 | GitHub User or Organization | sync_settings_page.dart |
| 331 | `githubPrivateRepo` | GitHub | GitHub | sync_settings_page.dart |
| 332 | `handleSync` | 处理同步 | Open Sync | backup_page.dart |
| 333 | `hardWordsSubtitle` | {count} 个答错或模糊过的单词 | {count, plural, =1{1 word you missed or weren't sure of} other{{count} words you missed or weren't sure of}} | dashboard_page.dart |
| 334 | `hasDeviceSettingsLine` | 包含设备设置：{value} | Device settings included: {value} | backup_page.dart |
| 335 | `hasLocalChanges` | 有更改尚未同步 | Local changes are not uploaded yet. | sync_settings_page.dart |
| 336 | `hideHint` | 隐藏提示 | Hide Hint | practice_page.dart |
| 337 | `hintWithText` | 提示：{text} | Hint: {text} | practice_page.dart |
| 338 | `httpsOnly` | 只使用 HTTPS，不会关闭证书校验。 | HTTPS only; certificate checks are never disabled. | sync_settings_page.dart |
| 339 | `ignoreRecord` | 忽略这条记录 | Ignore | sync_settings_page.dart |
| 340 | `importAndMerge` | 导入并合并 | Import and Merge | backup_page.dart |
| 341 | `importAndMergeHint` | 不会覆盖本地数据：按单词与作答记录去重后合并 | Never overwrites local data: merges after de-duplicating words and answers. | backup_page.dart |
| 342 | `importComplete` | 导入完成 | Import Complete | import_page.dart |
| 343 | `importFailedUnchanged` | 导入失败，现有数据未更改。 | Import failed. Nothing was changed. | import_page.dart |
| 344 | `importIntoList` | 导入到该词书 | Import into This List | quick_add_page.dart, word_book_detail_page.dart, wordbooks_page.dart |
| 345 | `importIssueEmpty` | (空) | (empty) | import_page.dart |
| 346 | `importIssueInvalidEntry` | 无效词条 | Invalid entry | backup_labels.dart |
| 347 | `importIssueNotEnglish` | 不是合法英文单词 | Not a valid English word | backup_labels.dart |
| 348 | `importIssueNotEntry` | 无效词条（应为字符串或对象） | Not a valid entry (expected text or an object) | backup_labels.dart |
| 349 | `importIssueRowInvalid` | 第 {row} 行 word 无效 | Row {row}: the word field is invalid | backup_labels.dart |
| 350 | `importMergeNote` | 已存在的单词不会重复创建，也不会清空学习进度；只补充缺失信息并关联到目标词书。 | Existing words are not created twice and their progress is kept. Only missing details are filled in, and the word is linked to the chosen list. | import_page.dart |
| 351 | `importOutcomeBooks` | 涉及 {count} 个词书 | across {count} word lists | backup_labels.dart |
| 352 | `importOutcomeCreated` | 新增 {count} 个词条 | {count} added | backup_labels.dart |
| 353 | `importOutcomeDuplicates` | 文件内重复 {count} 个 | {count} duplicates in the file | backup_labels.dart |
| 354 | `importOutcomeExisting` | 已存在 {count} 个 | {count} already present | backup_labels.dart |
| 355 | `importOutcomeInvalid` | 忽略无效 {count} 行 | {count} invalid lines ignored | backup_labels.dart |
| 356 | `importOutcomeLinked` | 关联 {count} 个到词书 | {count} linked to the word list | backup_labels.dart |
| 357 | `importOutcomeRevived` | 恢复 {count} 个已删除词条 | {count} restored | backup_labels.dart |
| 358 | `importOutcomeSeparator` | ， | ,  | backup_labels.dart, sync_labels.dart |
| 359 | `importOutcomeSkippedDeleted` | 跳过 {count} 个已删除词条 | {count} deleted words skipped | backup_labels.dart |
| 360 | `importOutcomeUpdated` | 更新 {count} 个 | {count} updated | backup_labels.dart |
| 361 | `importResultAdded` | 新增单词 | Added | （仅文档/间接） |
| 362 | `importResultDuplicate` | 重复单词 | Duplicates | （仅文档/间接） |
| 363 | `importResultExisting` | 已有单词 | Already present | （仅文档/间接） |
| 364 | `importResultRestored` | 已恢复单词 | Restored | （仅文档/间接） |
| 365 | `importResultSkipped` | 未能导入 | Not imported | （仅文档/间接） |
| 366 | `importResultUpdated` | 已更新单词 | Updated | （仅文档/间接） |
| 367 | `importWordList` | 导入词书 | Import Word List | dashboard_page.dart, wordbooks_page.dart |
| 368 | `importWordListTitle` | 导入词书 | Import Word List | import_page.dart |
| 369 | `importing` | 导入中… | Adding… | import_page.dart, quick_add_page.dart |
| 370 | `inSyncWithLast` | 本地与上次同步一致 | This device matches the last sync. | sync_settings_page.dart |
| 371 | `inWordLists` | 所属词书 {count} | In {count, plural, =1{1 word list} other{{count} word lists}} | word_management_page.dart |
| 372 | `includeUnlearned` | 包含未学单词 | Include Unstudied Words | sprint_page.dart |
| 373 | `incorrect` | 错误 | Wrong | practice_page.dart |
| 374 | `increase` | 增加 | Increase | settings_page.dart |
| 375 | `initialiseAndSync` | 初始化并同步 | Initialise and Sync | sync_settings_page.dart |
| 376 | `intakeAdded` | 已添加「{word}」 | Added “{word}”. | intake_labels.dart |
| 377 | `intakeAlreadyInList` | 「{word}」已在词书中 | “{word}” is already in this list. | intake_labels.dart |
| 378 | `intakeDeletedSkipped` | 「{word}」已被删除，未自动恢复 | “{word}” was deleted and wasn't restored. | intake_labels.dart |
| 379 | `intakeExists` | 「{word}」已存在，内容无变化 | “{word}” already exists and is unchanged. | intake_labels.dart |
| 380 | `intakeRevived` | 已恢复「{word}」，学习记录保留。 | Restored “{word}”. Study history was kept. | intake_labels.dart |
| 381 | `intakeRevivedLinked` | 已恢复「{word}」并加入词书，学习记录保留。 | Restored “{word}” and added it to the list. Study history was kept. | intake_labels.dart |
| 382 | `intakeUnchanged` | 「{word}」内容无变化 | “{word}” is unchanged. | intake_labels.dart |
| 383 | `intakeUpdated` | 已更新「{word}」的 {count} 个字段 | Updated {count, plural, =1{1 field} other{{count} fields}} of “{word}”. | intake_labels.dart |
| 384 | `integrityPassed` | 完整性校验通过：文件可以安全读取。 | Integrity check passed: the file can be read safely. | backup_page.dart |
| 385 | `integrityUnchecked` | 完整性：未校验（点「检查」可读取并验证） | Integrity: unchecked (run Check to read and verify) | backup_page.dart |
| 386 | `intervalDays` | {count} 天 | {count, plural, =1{1 day} other{{count} days}} | word_detail_page.dart |
| 387 | `intervalLabel` | 复习间隔 | Interval | word_detail_page.dart |
| 388 | `invalidHexColor` | 请输入 6 位 HEX 颜色，例如 #1565C0 | Enter a 6-digit HEX color, such as #1565C0. | settings_page.dart |
| 389 | `issuesHeader` | 前 {count} 个问题： | First {count} issues: | import_page.dart |
| 390 | `keepLocal` | 保持本机状态 | Keep This Device | sync_settings_page.dart |
| 391 | `keepLocalState` | 保持本机状态 | Keep This Device | backup_page.dart |
| 392 | `keepScreenAwake` | 学习时保持屏幕常亮 | Keep Screen Awake | settings_page.dart |
| 393 | `keepScreenAwakeHint` | 仅在学习和练习期间生效 | Applies only while studying or practicing. | settings_page.dart |
| 394 | `keepScreenAwakeUnsupported` | 当前平台不支持此功能，学习不受影响 | Not available on this platform. Studying is unaffected. | settings_page.dart |
| 395 | `keptValue` | 保留：{value} | Kept: {value} | sync_settings_page.dart |
| 396 | `keyHintShowMeaning` | 按 {key} 键显示释义 | Press {key} to show the meaning | study_page.dart |
| 397 | `languageSheetTitle` | 应用语言 | App Language | （仅文档/间接） |
| 398 | `lastAutoBackup` | 上次自动备份 | Last Automatic Backup | backup_page.dart |
| 399 | `lastStudiedDay` | 最近学习日 | Last Studied | statistics_page.dart |
| 400 | `lastSynced` | 上次同步 | Last Synced | sync_settings_page.dart |
| 401 | `learnedLabel` | 已学 | Studied | dictionary_page.dart, statistics_page.dart |
| 402 | `learnedOfTotal` | 已学 {learned} / {total} | {learned} of {total} studied | dashboard_page.dart |
| 403 | `learningProgress` | 学习进度 | Learning Progress | word_detail_page.dart |
| 404 | `leaveBlankToKeep` | 留空表示保持不变 | Leave blank to keep the saved value | sync_settings_page.dart |
| 405 | `legalNotice` | ECDICT 词典数据以 MIT 许可分发。 | ECDICT dictionary data is distributed under the MIT license. | settings_page.dart |
| 406 | `licensesSubtitle` | Flutter、Drift、ECDICT 及其他依赖 | Flutter, Drift, ECDICT and other dependencies | settings_page.dart |
| 407 | `listDeleted` | 词书已被删除。 | That word list was deleted. | error_labels.dart |
| 408 | `listenAndType` | 听发音，输入单词 | Listen and type the word. | practice_page.dart |
| 409 | `loadMore` | 加载更多 | Load More | word_management_page.dart |
| 410 | `loadingVoices` | 正在读取系统语音… | Loading system voices… | settings_page.dart |
| 411 | `localBackups` | 本机备份 | Local Backups | backup_page.dart |
| 412 | `localFile` | 本地文件 | Local File | sync_settings_page.dart |
| 413 | `localFileHint` | 使用文件在设备间传输数据 | Transfers data through a JSON file. | sync_settings_page.dart |
| 414 | `localFileManualOnly` | 本地文件只用于手动合并；需要自动同步时请选择 GitHub 或 WebDAV。 | A local file is for manual merging only. For automatic sync, choose GitHub or WebDAV. | sync_settings_page.dart |
| 415 | `logCount` | {count} 条记录 | {count, plural, =1{1 entry} other{{count} entries}} | diagnostics_page.dart |
| 416 | `logsCleared` | 已清除运行日志 | Logs cleared. | diagnostics_page.dart |
| 417 | `logsSection` | 日志 | Logs | diagnostics_page.dart |
| 418 | `manageAllWords` | 全部单词 | All Words | navigation.dart |
| 419 | `manageTags` | 管理标签 | Manage Tags | word_metadata_widgets.dart |
| 420 | `manualBackupJson` | 手动备份（JSON） | Manual Backup (JSON) | backup_page.dart |
| 421 | `markMastered` | 标记已掌握 | Mark as Mastered | word_detail_page.dart, word_management_page.dart |
| 422 | `markMasteredBody` | 将选中的 {count} 个单词标记为已掌握，30 天后复习。保留学习历史，不计入作答次数和正确率。 | Marks {count, plural, =1{1 word} other{{count} words}} as mastered and schedules a review in 30 days. Study history is kept; it doesn't count as an answer. | word_management_page.dart |
| 423 | `markMasteredBodyOne` | 标记为已掌握，30 天后再次复习。保留学习历史，不计入作答次数和正确率。 | Marks this word as mastered and schedules a review in 30 days. Study history is kept; it doesn't count as an answer or affect accuracy. | word_detail_page.dart, word_management_page.dart |
| 424 | `markMasteredDone` | 已标记 {count} 个单词为已掌握 | {count, plural, =1{Marked 1 word as mastered} other{Marked {count} words as mastered}} | word_management_page.dart |
| 425 | `markMasteredTitle` | 标记为已掌握？ | Mark as Mastered? | word_detail_page.dart, word_management_page.dart |
| 426 | `mastered` | 已掌握 | Mastered | word_management_page.dart |
| 427 | `merge` | 合并 | Merge | backup_page.dart |
| 428 | `mergeBackup` | 合并备份 | Merge Backup | backup_page.dart |
| 429 | `mergeComplete` | 合并完成。 | Merge complete. | （仅文档/间接） |
| 430 | `mergeCompleteWith` | 合并完成：{summary} | Merge complete: {summary} | backup_page.dart |
| 431 | `mergeConfirmBody` | {words} 个词条，{books} 个词书，{events} 条学习记录。⏎备份时间：{time}⏎将合并到本机，保留现有学习历史，不会删除本机任何数据。 | {words} words, {books} word lists, {events} answers.⏎Backup time: {time}⏎Merges into this device, keeps the existing history and deletes nothing. | backup_page.dart |
| 432 | `mergeNeverOverwrites` | 合并只补充缺失内容，不会覆盖已有单词和作答记录；同一份文件重复导入也不会重复计数。 | A merge only adds missing content and never overwrites existing words or answers. Importing the same file twice does not double-count. | backup_page.dart |
| 433 | `mergeOnlyAdds` | 不会自动用任一方的数据覆盖另一方：合并只补充缺失内容。 | Neither side overwrites the other: a merge only adds what is missing. | sync_settings_page.dart |
| 434 | `mergeOnlyAddsShort` | 合并 | Merge | sync_settings_page.dart |
| 435 | `mergeRemote` | 合并远端数据 | Merge Remote Data | sync_settings_page.dart |
| 436 | `mergeRemoteBody` | 会解除同步暂停，并把远端设备的数据合并到本机，只补充缺失内容，不删除本机内容。合并结果随后上传，因此远端会包含本机恢复后的数据。 | This resumes sync and merges the other device's data into this one, adding only what is missing. The merged result is then uploaded, so the remote copy will contain the restored data from this device. | sync_settings_page.dart |
| 437 | `mergeRemoteData` | 合并远端数据 | Merge Remote Data | backup_page.dart |
| 438 | `mergeRemoteTitle` | 合并远端数据？ | Merge Remote Data? | sync_settings_page.dart |
| 439 | `mergeRestore` | 合并备份 | Merge Backup | backup_page.dart |
| 440 | `mergeRestoreBody` | 只补充本机缺少的单词与作答记录，保留现有数据与学习进度。这是安全的方式。 | Adds only words and answers this device is missing. Existing data and progress are kept. This is the safe default. | （仅文档/间接） |
| 441 | `mergeRestoreConfirm` | {summary}⏎⏎合并只补充本机缺少的词条与学习记录，保留现有数据与学习进度。这是安全的方式。 | {summary}⏎⏎Merging only adds what this device is missing and keeps existing data and progress. This is the safe default. | backup_page.dart |
| 442 | `mergeRestoreSafe` | 合并备份 | Merge Backup | backup_page.dart |
| 443 | `mergeRulesAdvanced` | 合并规则（高级） | Merge Rules (Advanced) | backup_page.dart |
| 444 | `mergeRulesBody` | 作答记录按全局 ID 去重，学习状态由合并后的历史重新计算；词书关联带版本与删除标记，因此旧备份不会让已移除的单词复活。 | Answers are de-duplicated by global id and learning state is recalculated from the merged history. Word-list links carry versions and delete marks, so an old backup cannot revive a removed word. | backup_page.dart |
| 445 | `mergeSummaryConflicts` | 内容冲突 {count} 个（保留较新的值） | {count} content conflicts (the newer value was kept) | backup_labels.dart |
| 446 | `mergeSummaryDeletedWords` | 同步删除 {count} 个 | {count} deletions applied | backup_labels.dart, sync_labels.dart |
| 447 | `mergeSummaryDuplicates` | 重复记录 {count} 条已忽略 | {count} duplicates ignored | backup_labels.dart |
| 448 | `mergeSummaryEvents` | 新增学习记录 {count} 条 | {count} new answers | backup_labels.dart, sync_labels.dart |
| 449 | `mergeSummaryMetadata` | 收藏与标签变更 {count} 项 | {count} favorite or tag changes | backup_labels.dart |
| 450 | `mergeSummaryNewBooks` | 新增词书 {count} 个 | {count} new word lists | backup_labels.dart |
| 451 | `mergeSummaryNewEntries` | 新增词书关联 {count} 条 | {count} links added | backup_labels.dart |
| 452 | `mergeSummaryNewWords` | 新增词条 {count} 个 | {count} new words | backup_labels.dart, sync_labels.dart |
| 453 | `mergeSummaryRebuiltStates` | 重算学习状态 {count} 个 | {count} progress rows recalculated | backup_labels.dart |
| 454 | `mergeSummaryRemovedEntries` | 同步移出词书 {count} 条 | {count} links removed | backup_labels.dart, sync_labels.dart |
| 455 | `mergeSummaryUpdatedWords` | 更新词条 {count} 个 | {count} words updated | backup_labels.dart, sync_labels.dart |
| 456 | `mergeToDevice` | 将合并到本机，保留现有学习历史，不会删除本机任何数据。 | Merges into this device and keeps the existing history; nothing on this device is deleted. | （仅文档/间接） |
| 457 | `mistakesSubtitle` | 复习近期答错的单词 | Review words you recently got wrong. | dashboard_page.dart |
| 458 | `mobileFolderLimit` | 手机上无法长期访问任意文件夹，请使用应用内的文件，或改用「备份与恢复」中的导出 / 导入。 | Phones can't keep access to an arbitrary folder. Use the app's own file, or export / import from Backup & Restore. | sync_settings_page.dart |
| 459 | `modeMixed` | 新词与复习 | New Words & Review | enum_labels.dart |
| 460 | `modeNewOnly` | 仅新词 | New Words Only | enum_labels.dart |
| 461 | `modeReviewOnly` | 仅复习 | Review Only | enum_labels.dart |
| 462 | `modeSpecial` | 专项复习 | Targeted Review | enum_labels.dart |
| 463 | `moreActions` | 更多操作 | More | study_page.dart, wordbooks_page.dart |
| 464 | `moreTotal` | …共 {count} 个 | …{count} in total | quick_add_page.dart |
| 465 | `myWordLists` | 我的词书 | My Word Lists | wordbooks_page.dart |
| 466 | `myWordsCount` | 我的单词（{count}） | My Words ({count}) | dictionary_page.dart |
| 467 | `navAllWords` | 全部单词 | All Words | navigation.dart, word_management_page.dart, wordbooks_page.dart |
| 468 | `navAllWordsWithCount` | 全部单词（{count}） | All Words ({count}) | word_management_page.dart |
| 469 | `navDictionary` | 词典 | Dictionary | navigation.dart |
| 470 | `navOfflineNote` | 离线可用 · 本地优先 | Offline · stored on this device | navigation.dart |
| 471 | `navSettings` | 设置 | Settings | navigation.dart |
| 472 | `navStatistics` | 统计 | Statistics | navigation.dart |
| 473 | `navToday` | 今日 | Today | l10n.dart, navigation.dart |
| 474 | `navWordLists` | 词书 | Word Lists | navigation.dart, word_book_detail_page.dart, word_management_page.dart |
| 475 | `neverSynced` | 尚未同步 | Never Synced | sync_settings_page.dart |
| 476 | `newFolder` | 新建文件夹 | New Folder | webdav_directory_picker.dart |
| 477 | `newWordList` | 新建词书 | New Word List | dictionary_page.dart, import_page.dart, quick_add_page.dart, wordbooks_page.dart |
| 478 | `newWordTag` | 新词 | New | study_page.dart |
| 479 | `newWords` | 新词 | New Words | dashboard_page.dart, study_page.dart |
| 480 | `newWordsAvailable` | 可学新词 | New Words Available | dashboard_page.dart |
| 481 | `newWordsHintRemaining` | 剩余目标 {remaining} · 未学 {unlearned} 词 | {remaining} left · {unlearned} not studied | dashboard_page.dart |
| 482 | `nextQuestion` | 下一题 | Next | practice_page.dart |
| 483 | `nextReviewAt` | 下次复习：{date}（{relative}） | Next review: {date} ({relative}) | word_detail_page.dart, word_management_page.dart |
| 484 | `nextReviewNone` | 下次复习：无 | Next review: none | word_management_page.dart |
| 485 | `no` | 否 | No | backup_page.dart |
| 486 | `noAnswerHistory` | 还没有作答记录。 | No answers recorded yet. | word_detail_page.dart, word_management_page.dart |
| 487 | `noAnswersLast7Days` | 最近 7 天暂无作答记录。 | No answers in the last 7 days. | statistics_page.dart |
| 488 | `noAnswersYet` | 还没有作答记录。完成一次学习后会显示真实数据。 | No answers yet. Finish one study session to see real numbers. | statistics_page.dart |
| 489 | `noAutoBackupYet` | 还没有自动备份 | No automatic backup yet | backup_page.dart |
| 490 | `noChineseMeaning` | 暂无中文释义 | No Chinese meaning yet | study_page.dart |
| 491 | `noChineseMeaningShort` | 无中文释义 | No Chinese meaning | word_management_page.dart |
| 492 | `noDictionaryMatch` | 词典中没有此单词。你可以手动添加，稍后补充释义。 | The dictionary doesn't have this word. You can add it by hand and fill in the meaning later. | dictionary_page.dart |
| 493 | `noDueWords` | 暂无待复习单词 | No words due for review. | dashboard_page.dart |
| 494 | `noEnglishVoice` | 系统未安装英语语音。可在系统设置中安装后再听发音。 | No English voice is installed. Install one in System Settings to hear pronunciation. | settings_page.dart |
| 495 | `noFileChosen` | 尚未选择文件 | No file chosen | import_page.dart |
| 496 | `noHardWordsYet` | 暂无困难词 | No difficult words yet. | dashboard_page.dart |
| 497 | `noLocalBackups` | 还没有备份。自动备份或「立即备份」会在此列出。 | No backups yet. An automatic backup or Save Backup Now will appear here. | backup_page.dart |
| 498 | `noLogs` | 当前没有记录 | Nothing recorded yet | diagnostics_page.dart |
| 499 | `noMatchForQuery` | 没有匹配「{query}」的单词。 | No words match “{query}”. | word_management_page.dart |
| 500 | `noMatchingWords` | 没有匹配的单词 | No matching words | word_book_detail_page.dart |
| 501 | `noMatchingWordsGroup` | 没有符合条件的单词 | No matching words | word_management_page.dart |
| 502 | `noNewWordsInScope` | 没有未学的新词 | No new words left in this scope. | dashboard_page.dart |
| 503 | `noRecord` | 无记录 | none | word_management_page.dart |
| 504 | `noScheduledReviews` | 暂无复习安排。 | No reviews scheduled. | statistics_page.dart |
| 505 | `noSubfolders` | 这个位置没有子文件夹。可以直接选择当前文件夹，或新建一个。 | No subfolders here. You can choose this folder or create one. | webdav_directory_picker.dart |
| 506 | `noSyncTargetHint` | 尚未配置同步目标，可在「同步」页设置 | No sync target configured. Set one on the Sync page. | backup_page.dart |
| 507 | `noTagsYet` | 还没有标签 | No tags yet | word_metadata_widgets.dart |
| 508 | `noTargetConfigured` | 尚未配置同步目标 | No sync target configured | sync_settings_page.dart |
| 509 | `noWordLists` | 还没有词书 | No word lists yet | quick_add_page.dart, wordbooks_page.dart |
| 510 | `noWordListsMessage` | 创建一个词书，然后导入单词表，每行一个单词。 | Create a word list, then import your words — one per line. | wordbooks_page.dart |
| 511 | `noWordsYet` | 还没有单词 | No words yet | dashboard_page.dart, sprint_page.dart |
| 512 | `notDeleted` | 未删除 | Not deleted | sync_settings_page.dart |
| 513 | `notSet` | 未选择 | Not set | sprint_page.dart |
| 514 | `noteLabel` | 注意： | Note: | sync_settings_page.dart |
| 515 | `notes` | 笔记 | Notes | quick_add_page.dart, study_page.dart, word_detail_page.dart, word_management_page.dart |
| 516 | `nothingDueSpecial` | 暂无待复习单词 | Nothing due for review | study_page.dart |
| 517 | `nothingLeftTodayMessage` | 今天的新词和到期复习都已完成。你可以调整每日目标、导入新词，或稍后回来。 | Today's new words and reviews are done. Adjust your goals, import more words, or come back later. | study_page.dart |
| 518 | `nothingToExport` | 还没有可导出的词书 | No word lists to export. | wordbooks_page.dart |
| 519 | `nothingToPractice` | 没有可练习的单词 | Nothing to practice | practice_page.dart |
| 520 | `nothingToStudyToday` | 今天没有要学的单词 | Nothing to study today | study_page.dart |
| 521 | `offlineDictionary` | 离线词典 | Offline Dictionary | dictionary_page.dart |
| 522 | `ok` | 确定 | OK | settings_page.dart |
| 523 | `onlineListTotal` | 在线词书共 {count} 个词条。 | The online list has {count} words. | wordbooks_page.dart |
| 524 | `openSourceLicenses` | 开源许可 | Open Source Licenses | settings_page.dart |
| 525 | `openSync` | 打开同步 | Open Sync | backup_page.dart |
| 526 | `operationFailedNothingChanged` | 操作失败，数据未更改。请重试。 | The action failed. Nothing was changed. Try again. | word_management_page.dart |
| 527 | `optional` | 可选 | Optional | quick_add_page.dart |
| 528 | `overallAccuracy` | 累计正确率 | Overall Accuracy | statistics_page.dart |
| 529 | `overdueReviews` | 待补复习 | Overdue Reviews | dashboard_page.dart |
| 530 | `parentFolder` | 上一级 | Up One Level | webdav_directory_picker.dart |
| 531 | `parseFailed` | 无法解析内容，请检查格式。 | Couldn't read this. Check the format. | import_page.dart, quick_add_page.dart |
| 532 | `partOfSpeech` | 词性 | Part of Speech | quick_add_page.dart, word_detail_page.dart |
| 533 | `password` | 密码 | Password | （仅文档/间接） |
| 534 | `passwordMissing` | 未读取到已保存的 WebDAV 密码，请重新输入后再同步。 | No saved WebDAV password was found. Enter it again before syncing. | sync_settings_page.dart |
| 535 | `pasteWordsPerLine` | 请粘贴单词，每行一个。 | Paste words, one per line. | quick_add_page.dart |
| 536 | `pendingChanges` | 待同步更改 | Pending Changes | sync_settings_page.dart |
| 537 | `phonetics` | 音标 | Phonetics | quick_add_page.dart, word_detail_page.dart |
| 538 | `phrases` | 短语 | Phrases | study_page.dart, word_detail_page.dart |
| 539 | `playAgain` | 再听一次 | Play Again | practice_page.dart |
| 540 | `practiceAccuracy` | 正确率 {value} · {count} 个单词 | Accuracy {value} · {count, plural, =1{1 word} other{{count} words}} | practice_page.dart |
| 541 | `practiceAnswerNote` | 本次练习只记录作答，不会改变这个单词的复习间隔。 | This answer is recorded but does not change the word's review interval. | practice_page.dart |
| 542 | `practiceCannotStart` | 练习无法开始 | Can't start this practice | practice_page.dart |
| 543 | `practiceChoice` | 选择题 | Multiple Choice | enum_labels.dart |
| 544 | `practiceChoiceDesc` | 从选项中选出正确单词 | Pick the correct word. | enum_labels.dart |
| 545 | `practiceCloze` | 例句填空 | Fill in the Blank | enum_labels.dart |
| 546 | `practiceClozeDesc` | 根据例句语境补全单词 | Complete the word in the example sentence. | enum_labels.dart |
| 547 | `practiceComplete` | 练习完成 | Practice Complete | practice_page.dart |
| 548 | `practiceContentUpdated` | 此单词已更新，本轮练习将重新开始。 | This word was updated. The round restarts. | error_labels.dart |
| 549 | `practiceDictation` | 听写练习 | Dictation | enum_labels.dart |
| 550 | `practiceDictationDesc` | 听发音，输入英文单词 | Listen and type the English word. | enum_labels.dart |
| 551 | `practiceEmptyMessage` | 练习需要带中文释义的词条。先添加或导入单词后再回来。 | Practice needs words with a Chinese meaning. Add or import words first. | practice_page.dart |
| 552 | `practiceLoadFailed` | 无法加载练习，请重试。 | Couldn't load this practice. Try again. | error_labels.dart |
| 553 | `practiceNote` | 练习不占用每日学习额度，也不影响复习计划。 | Practice does not use your daily allowance and does not affect your review schedule. | dashboard_page.dart |
| 554 | `practiceSaveFailed` | 无法保存练习结果，请重试。 | Couldn't save this practice. Try again. | error_labels.dart |
| 555 | `practiceSpelling` | 拼写练习 | Spelling | enum_labels.dart |
| 556 | `practiceSpellingDesc` | 看中文释义，输入英文单词 | Type the English word for the Chinese meaning. | enum_labels.dart |
| 557 | `practiceStatsNote` | 练习作答计入统计，但不会改变长期复习间隔。 | Practice answers count towards statistics but do not change the review interval. | practice_page.dart |
| 558 | `practiceVoiceHintUsed` | 无法播放发音，已改为显示中文提示。 | Voice unavailable. The Chinese meaning is shown instead. | practice_page.dart |
| 559 | `practiceWordDeleted` | 此单词已被删除，本轮练习将重新开始。 | This word was deleted. The round restarts. | error_labels.dart |
| 560 | `practiceWordUnlinked` | 此单词已移出词书，本轮练习将重新开始。 | This word is no longer in the word list. The round restarts. | error_labels.dart |
| 561 | `preferencesSaveFailed` | 自动同步选项保存失败，请重试。 | Couldn't save the auto-sync options. Try again. | sync_settings_page.dart |
| 562 | `preferencesSaved` | 已保存偏好。自动同步需要先通过「测试连接」验证安全写入。 | Preferences saved. Automatic sync starts only after Test Connection verifies safe writes. | sync_settings_page.dart |
| 563 | `preview` | 预览 | Preview | quick_add_page.dart |
| 564 | `previewVoice` | 试听 | Preview Voice | settings_page.dart |
| 565 | `prioritizeHard` | 优先困难词 | Prioritise Difficult Words | sprint_page.dart |
| 566 | `prioritizeRecent` | 优先近期错词 | Prioritise Recent Mistakes | sprint_page.dart |
| 567 | `prioritizeUnmastered` | 优先未掌握词 | Prioritise Unmastered Words | sprint_page.dart |
| 568 | `privateRepoNote` | 建议新建一个专用私有仓库保存学习数据，请勿使用公开仓库。 | Use a dedicated private repository for study data. Never use a public one. | sync_settings_page.dart |
| 569 | `protectiveBackupFailed` | 无法创建操作前备份，操作已取消。 | Couldn't create the safety backup, so nothing was changed. | error_labels.dart, word_management_page.dart, wordbooks_page.dart |
| 570 | `quickAddNote` | 默认沿用上次选择的词书。已有单词会保留释义、笔记和学习进度，只有你实际修改的内容才会覆盖。 | Uses the last chosen word list. Existing words keep their meaning, notes and progress; only what you change is overwritten. | quick_add_page.dart |
| 571 | `randomOrder` | 随机顺序 | Random Order | settings_page.dart |
| 572 | `randomOrderHint` | 随机排列单词，不影响专项复习和冲刺 | Shuffles the order. Targeted review and exam prep are unaffected. | settings_page.dart |
| 573 | `reading` | 读取中… | Reading… | diagnostics_page.dart |
| 574 | `recallMeaning` | 回想单词的含义 | Recall the meaning | study_page.dart |
| 575 | `recentMistakes7d` | 近期错词 | Recent Mistakes | sprint_page.dart |
| 576 | `recentSearch` | 最近搜索 | Recent | dictionary_page.dart |
| 577 | `recreateRemoteAction` | 重新上传远端数据… | Re-upload Remote Data… | sync_settings_page.dart |
| 578 | `recreateRemoteBody` | 远端数据文件已不存在，可能是仓库文件被删除，或权限/路径变化。⏎⏎继续会把本机当前数据重新上传到该位置。如果你并不想删除远端数据，请先取消并检查仓库与配置。 | The remote data file no longer exists, perhaps because the repository file was deleted or the path changed.⏎⏎Continuing uploads this device's current data there. If you did not intend to remove the remote data, cancel and check the repository and settings. | sync_settings_page.dart |
| 579 | `recreateRemoteTitle` | 重新上传远端数据？ | Re-upload Remote Data? | sync_settings_page.dart |
| 580 | `refreshCancelled` | 已取消刷新，未修改任何数据 | Refresh canceled. Nothing changed. | wordbooks_page.dart |
| 581 | `refreshDeletedByUser` | 你曾删除、不会自动恢复：{count} 个 | Deleted by you, not restored: {count} | wordbooks_page.dart |
| 582 | `refreshDone` | 刷新完成：新增 {added}，更新 {updated}，已有 {existing}。 | Refresh complete. Added {added}, updated {updated}, already present {existing}. | import_page.dart, wordbooks_page.dart |
| 583 | `refreshDropped` | 不会导入的行：{count} 行 | Lines skipped: {count} | wordbooks_page.dart |
| 584 | `refreshDuplicate` | 文件内重复：{count} 个 | Duplicates in the file: {count} | wordbooks_page.dart |
| 585 | `refreshExisting` | 本机已有：{count} 个 | Already on this device: {count} | wordbooks_page.dart |
| 586 | `refreshFailed` | 无法刷新此词书，请重试。 | Couldn't refresh this word list. Try again. | wordbooks_page.dart |
| 587 | `refreshInvalid` | 无效词条：{count} 个 | Invalid entries: {count} | wordbooks_page.dart |
| 588 | `refreshLocalOnly` | 来源已移除、仍保留在本机：{count} 个 | Removed from the source, kept here: {count} | wordbooks_page.dart |
| 589 | `refreshNote` | 只添加缺失的单词。不会删除本机词条、不恢复你删除的词条、不覆盖笔记与自定义释义、不重置学习进度。取消不会修改任何数据。 | Only missing words are added. Nothing on this device is deleted, restored, overwritten or reset. Canceling changes nothing. | wordbooks_page.dart |
| 590 | `refreshOnlineList` | 刷新在线词书 | Refresh Online List | wordbooks_page.dart |
| 591 | `refreshToAdd` | 将新增：{count} 个 | To add: {count} | wordbooks_page.dart |
| 592 | `refreshVoices` | 刷新语音 | Refresh Voices | settings_page.dart |
| 593 | `relatedWords` | 相关单词 | Related Words | dictionary_page.dart |
| 594 | `relationComparative` | 比较级 | comparative | enum_labels.dart |
| 595 | `relationPastParticiple` | 过去式或过去分词 | past tense or past participle | enum_labels.dart |
| 596 | `relationPlural` | 复数或第三人称单数 | plural or third-person form | enum_labels.dart |
| 597 | `relationPresentParticiple` | 现在分词或动名词 | present participle or gerund | enum_labels.dart |
| 598 | `relationSuperlative` | 最高级 | superlative | enum_labels.dart |
| 599 | `remoteBecameEmpty` | 远程文件变成空文件 | Remote file became empty | sync_settings_page.dart |
| 600 | `remoteEmptiedBody` | 这个同步目标之前成功同步过，但远程文件现在是 0 字节。⏎⏎继续会用本机数据重新初始化它，远端原本的内容将被替换。 | This target synced successfully before, but the remote file is now 0 bytes.⏎⏎Continuing re-initialises it with this device's data, replacing what was there. | sync_settings_page.dart |
| 601 | `remoteEmptiedConfirm` | 只有确认远端数据不再需要时才继续。 | Continue only if the remote data is no longer needed. | sync_settings_page.dart |
| 602 | `remoteFileMissingNotice` | 远程数据文件已不存在。 | The remote data file no longer exists. | sync_settings_page.dart |
| 603 | `remoteFolder` | 文件夹 | Folder | sync_settings_page.dart |
| 604 | `remoteFolderChosen` | 已选择远程文件夹：{path} | Remote folder selected: {path} | sync_settings_page.dart |
| 605 | `remoteFolderHint` | 留空表示使用服务器地址本身。不确定真实路径时，用上面的按钮浏览服务器文件夹，不要照抄网盘客户端里显示的名称。 | Leave blank to use the server address itself. Browse with the button above rather than copying a name from a sync client. | sync_settings_page.dart |
| 606 | `remoteIsEmpty` | 远程文件为空 | Remote file is empty | sync_settings_page.dart |
| 607 | `remoteMerged` | 远端数据已合并。 | Remote data merged. | （仅文档/间接） |
| 608 | `removeFromCurrentList` | 移出词书 | Remove from Word List | word_detail_page.dart, word_management_page.dart |
| 609 | `removeFromListBody` | 把选中的 {count} 个单词从「{book}」移出？其他词书中的关联和学习进度不受影响。 | Remove {count, plural, =1{1 word} other{{count} words}} from “{book}”? Links to other word lists and study progress are unaffected. | word_management_page.dart |
| 610 | `removeFromListBodyWord` | 把「{word}」从当前词书移出？单词本身、其他词书中的关联和学习进度都会保留。 | Remove “{word}” from this word list? The word, its other word lists and study progress are kept. | word_detail_page.dart |
| 611 | `removeFromWordList` | 移出词书 | Remove from Word List | word_detail_page.dart, word_management_page.dart |
| 612 | `removeTag` | 移除标签 | Remove Tag | word_management_page.dart |
| 613 | `removeTagNamed` | 移除标签 {name} | Remove tag {name} | word_metadata_widgets.dart |
| 614 | `removedFromWordList` | 已从词书移出 {count} 个单词 | {count, plural, =1{Removed 1 word from the list} other{Removed {count} words from the list}} | word_management_page.dart |
| 615 | `renameTag` | 重命名标签 | Rename Tag | word_metadata_widgets.dart |
| 616 | `renameWordList` | 重命名词书 | Rename Word List | wordbooks_page.dart |
| 617 | `repeatPractice` | 本轮复练 | Repeat Practice | study_page.dart |
| 618 | `repoName` | 仓库名称 | Repository Name | sync_settings_page.dart |
| 619 | `reset` | 重置 | Reset | word_detail_page.dart, word_management_page.dart |
| 620 | `resetDone` | 已重置 {count} 个单词 | {count, plural, =1{Reset 1 word} other{Reset {count} words}} | word_management_page.dart |
| 621 | `resetProgress` | 重置进度 | Reset Progress | word_detail_page.dart, word_management_page.dart |
| 622 | `resetProgressBodyBulk` | 将清除选中的 {count} 个单词的学习状态：作答次数、复习间隔和下次复习时间。单词本身和作答历史仍会保留。 | Clears the learning state of {count, plural, =1{1 word} other{{count} words}}: answers, interval and next review date. The words and their answer history are kept. | word_management_page.dart |
| 623 | `resetProgressBodyOne` | 清除此单词的学习状态：作答次数、复习间隔和下次复习时间。单词本身和作答历史仍会保留。 | Clears this word's learning state: answers, interval and next review date. The word and its answer history are kept. | word_detail_page.dart, word_management_page.dart |
| 624 | `resetProgressTitle` | 重置学习进度？ | Reset Progress? | word_detail_page.dart, word_management_page.dart |
| 625 | `restorableNote` | 其中 {count} 个曾被你删除：导入会恢复它们并保留学习记录，在线刷新不会。 | {count} of them were deleted by you. An explicit import restores them and keeps their history; refreshing an online list does not. | import_page.dart |
| 626 | `restore` | 恢复 | Restore | backup_page.dart |
| 627 | `restoreConflictBody` | 「{label}」的 {field} 将改回另一个值。这会作为一次新的修改同步到其他设备。 | {label} · {field} will be changed back to the other value. This is synced to other devices as a new edit. | sync_settings_page.dart |
| 628 | `restoreConflictTitle` | 恢复被覆盖的内容？ | Restore the Overwritten Value? | sync_settings_page.dart |
| 629 | `restoreDoneWith` | {summary}；恢复前状态已保存为 {file}。 | {summary} The previous state was saved as {file}. | backup_page.dart |
| 630 | `restoreFailedKept` | 恢复失败，冲突记录已保留。 | Couldn't restore. The conflict record was kept. | sync_settings_page.dart |
| 631 | `restoreModesNote` | 合并只补充缺失内容，可重复执行。恢复指定版本会整体替换本机数据，先自动保存操作前备份，并暂停同步。 | Merging only adds what is missing, so it is idempotent and safe to repeat. Restoring a version replaces this device's data atomically, saves a safety backup first, and pauses sync until you decide how to handle the remote copy. | backup_page.dart |
| 632 | `restoreNextStepBody` | 本机已恢复为所选历史版本，同步保持暂停。请选择下一步：⏎⏎· 保持本机状态：暂不同步，稍后可在「同步」页处理。⏎· 合并远端数据：把远端设备的数据并回本机（只增不减）。⏎· 使用新的同步目标：为恢复后的数据换一个远端位置。 | This device now holds the selected version and sync is paused. Choose the next step:⏎⏎· Keep this device: don't sync yet; handle it later on the Sync page.⏎· Merge remote data: bring the other device's data in (adds only).⏎· Use a new target: point sync at a different remote location. | backup_page.dart |
| 633 | `restoreNextStepTitle` | 恢复完成：如何使用远端数据？ | Restored: What About the Remote Data? | backup_page.dart |
| 634 | `restoreOverwritten` | 恢复 | Restore | sync_settings_page.dart |
| 635 | `restoreSnapshotConfirm` | {summary}⏎创建时间：{created}⏎⏎这会用该备份替换本机当前数据：此后的学习记录、编辑和删除都会丢失。操作前会自动保存一份操作前备份，失败时整体回滚。恢复后同步会暂停，直到你决定如何处理远端数据。 | {summary}⏎Created: {created}⏎⏎This replaces the current data on this device: answers, edits and deletions made after that backup are removed from it. A safety backup is written first, and a failure rolls everything back. Sync stays paused afterwards until you decide what to do with the remote data. | backup_page.dart |
| 636 | `restoreSummary` | 已恢复 {words} 个词条、{events} 条学习记录（恢复前已保存操作前备份） | Restored {words} words and {events} answers. The previous state was saved as a safety backup. | backup_labels.dart |
| 637 | `restoreThisVersion` | 恢复此版本… | Restore This Version… | backup_page.dart |
| 638 | `restoreVersionBody` | 此设备上的学习数据将恢复到所选版本。备份创建后的更改会从当前数据中移除。⏎⏎恢复前会自动保存当前数据，并暂停同步。 | Study data on this device returns to the selected version. Changes made after that backup are removed from the current data.⏎⏎The current data is backed up automatically first, and sync is paused. | （仅文档/间接） |
| 639 | `restoreVersionTitle` | 恢复此备份？ | Restore This Version? | backup_page.dart |
| 640 | `restoredAsNewEdit` | （将作为一次新的编辑同步） | (synced as a new edit) | sync_settings_page.dart |
| 641 | `restoredField` | 已恢复「{field}」 | Restored {field} | sync_settings_page.dart |
| 642 | `restoredProtected` | 已恢复；恢复前状态已保存为 {file}。 | Restored. The previous state was saved as {file}. | （仅文档/间接） |
| 643 | `resumeProgress` | 已完成 {done} / {total} | {done} of {total} done | dashboard_page.dart |
| 644 | `retestAfterSwitch` | 切换同步方式后请重新测试连接。 | Test the connection again after switching sync method. | sync_settings_page.dart |
| 645 | `retestConnection` | 重新测试连接 | Test Again | sync_settings_page.dart |
| 646 | `reupload` | 重新上传 | Re-upload | sync_settings_page.dart |
| 647 | `review` | 复习 | Review | dashboard_page.dart, study_page.dart |
| 648 | `reviewHintRemaining` | 待复习 {due} 词 · 剩余限额 {remaining} | {due} due · {remaining} left | dashboard_page.dart |
| 649 | `reviewLimitReached` | 今日复习额度已用完。可在冲刺计划中允许额外复习。 | Today's review limit is reached. You can allow extra reviews in the exam plan. | error_labels.dart |
| 650 | `reviewOnly` | 仅复习 | Review Only | dashboard_page.dart |
| 651 | `reviewWithStage` | 复习 · {stage} | Review · {stage} | study_page.dart |
| 652 | `reviewsAvailable` | 可复习 | Due Reviews | dashboard_page.dart |
| 653 | `reviewsNext7Days` | 未来 7 天复习计划 | Reviews in the Next 7 Days | statistics_page.dart |
| 654 | `roundComplete` | 本轮学习完成 | Round Complete | study_page.dart |
| 655 | `roundDifficultNote` | 包含本轮曾模糊或不认识的单词；已删除词不进入复练。 | Words you weren't sure of or didn't know. Deleted words are not repeated. | study_page.dart |
| 656 | `roundDifficultWords` | 本轮困难词 | Difficult Words | study_page.dart |
| 657 | `roundSizeRange` | 每轮单词数（1–500） | Words per Round (1–500) | sprint_page.dart |
| 658 | `roundSizeShort` | 每轮单词数 | Words per Round | （仅文档/间接） |
| 659 | `roundSummaryFailed` | 无法读取本轮统计 | Couldn't load this round. | study_page.dart |
| 660 | `sampleAddFailed` | 无法添加示例词书。 | Couldn't add the sample word list. | dashboard_page.dart |
| 661 | `sampleLoaded` | 已添加「{name}」：{count} 个单词 | Added “{name}”: {count} words. | dashboard_page.dart |
| 662 | `saveAndContinue` | 保存并继续 | Save and Continue | quick_add_page.dart |
| 663 | `saveAndContinueShortcut` | 保存并继续（⌘Enter） | Save and Continue (⌘Enter) | quick_add_page.dart |
| 664 | `saveBackupNow` | 立即备份 | Save Backup Now | backup_page.dart |
| 665 | `saveBackupNowHint` | 保存在本机，可直接从下方列表恢复 | Saved on this device and restorable from the list below. | backup_page.dart |
| 666 | `saveDiagnostics` | 保存诊断信息 | Save Diagnostics | diagnostics_page.dart |
| 667 | `saved` | 已保存 | Saved | word_detail_page.dart |
| 668 | `savedAsCustom` | 保存后此单词会标记为已编辑，词典更新不会覆盖你填写的内容。 | Once saved, this word is marked as edited, and dictionary updates won't overwrite what you typed. | word_detail_page.dart |
| 669 | `saving` | 保存中… | Saving… | quick_add_page.dart, word_detail_page.dart |
| 670 | `schemaVersionLine` | 数据格式：v{version} | Format: v{version} | backup_page.dart |
| 671 | `scopeAllLists` | 全部词书 | All word lists | dashboard_page.dart |
| 672 | `scopeCurrentList` | 当前词书 | This word list | dashboard_page.dart |
| 673 | `searchWordHint` | 查找单词（⌘F） | Search words (⌘F) | dictionary_page.dart |
| 674 | `searchWordHintPlain` | 查找单词 | Search words | dictionary_page.dart |
| 675 | `searchWordsHint` | 搜索单词、释义或笔记 | Search words, meanings or notes | word_book_detail_page.dart, word_management_page.dart |
| 676 | `sectionAbout` | 关于 | About | settings_page.dart |
| 677 | `sectionDailyGoals` | 每日目标 | Daily Goals | settings_page.dart |
| 678 | `sectionData` | 数据 | Data | settings_page.dart |
| 679 | `sectionPractice` | 练习 | Practice | dashboard_page.dart |
| 680 | `sectionPronunciation` | 发音 | Pronunciation | settings_page.dart |
| 681 | `sectionSpecialReview` | 专项复习 | Targeted Review | dashboard_page.dart |
| 682 | `sectionStartStudy` | 开始学习 | Start Studying | dashboard_page.dart |
| 683 | `sectionStudy` | 学习 | Study | settings_page.dart |
| 684 | `selectAWord` | 选择一个单词 | Select a word | word_management_page.dart |
| 685 | `selectAWordHint` | 从左侧列表选择单词，查看学习记录与操作。 | Choose a word to see its history and actions. | word_management_page.dart |
| 686 | `selectAllResults` | 选择全部 {count} 个单词 | Select all {count} | word_management_page.dart |
| 687 | `selectLoaded` | 选择当前 {count} 个单词 | Select {count} | word_management_page.dart |
| 688 | `selectedCount` | 已选 {count} | {count} selected | word_management_page.dart |
| 689 | `selectionFailed` | 选择失败，请重试。 | Couldn't select these words. Try again. | word_management_page.dart |
| 690 | `serverAddress` | 服务器地址（HTTPS） | Server Address (HTTPS) | sync_settings_page.dart |
| 691 | `serverLabel` | 服务器：{url} | Server: {url} | webdav_directory_picker.dart |
| 692 | `serverNoConditionalWrite` | 此服务器没有通过安全写入验证。 | This server did not pass the safe-write check. | sync_settings_page.dart |
| 693 | `serverRootFolder` | 服务器基础目录 | server root | sync_settings_page.dart |
| 694 | `setForStudy` | 设为学习词书 | Use for Study | wordbooks_page.dart |
| 695 | `setSprintPlan` | 冲刺计划 | Exam Plan | sprint_page.dart |
| 696 | `settingsAppearance` | 外观 | Appearance | settings_page.dart |
| 697 | `showHint` | 显示提示 | Show Hint | practice_page.dart |
| 698 | `showMeaning` | 显示释义 | Show Meaning | study_page.dart |
| 699 | `skip` | 跳过 | Skip | practice_page.dart, study_page.dart |
| 700 | `skipFailed` | 跳过失败，请重试。 | Couldn't skip. Try again. | error_labels.dart |
| 701 | `skipped` | 跳过 | Skipped | practice_page.dart |
| 702 | `sortAddedDesc` | 添加时间（新→旧） | Recently Added | enum_labels.dart |
| 703 | `sortAlpha` | 字母顺序 | Alphabetical | enum_labels.dart |
| 704 | `sortLabel` | 排序 | Sort | word_management_page.dart |
| 705 | `sortLastStudied` | 最近学习时间 | Recently Studied | enum_labels.dart |
| 706 | `sortWrongDesc` | 错误次数（多→少） | Most Mistakes | enum_labels.dart |
| 707 | `sourceDictionary` | 词典 | Dictionary | source_labels.dart |
| 708 | `sourceFile` | 导入 | Imported | source_labels.dart |
| 709 | `sourceImport` | 导入 | Imported | source_labels.dart |
| 710 | `sourceLabel` | 来源：{source} | Source: {source} | word_detail_page.dart |
| 711 | `sourceManual` | 手动添加 | Added by hand | source_labels.dart |
| 712 | `sourceOther` | 其他 | Other | source_labels.dart |
| 713 | `sourceSample` | 示例词书 | Sample list | source_labels.dart |
| 714 | `sourceUrl` | 在线词书 | Online list | source_labels.dart |
| 715 | `sourceUrlLabel` | 来源：{url} | Source: {url} | wordbooks_page.dart |
| 716 | `speak` | 朗读 | Pronounce | study_page.dart |
| 717 | `speakingRate` | 发音速度 | Speaking Rate | settings_page.dart |
| 718 | `specialBook` | 复习此词书 | Review This Word List | enum_labels.dart, word_book_detail_page.dart |
| 719 | `specialEmptyMessage` | 专项复习只包含符合条件的单词，普通复习队列不受影响。 | Only words matching this review are included. Your normal queue is unchanged. | study_page.dart |
| 720 | `specialFavorites` | 收藏词复习 | Review Favorites | enum_labels.dart, word_management_page.dart |
| 721 | `specialHard` | 困难词复习 | Review Difficult Words | dashboard_page.dart, enum_labels.dart |
| 722 | `specialMistakes` | 错词复习 | Review Recent Mistakes | dashboard_page.dart, enum_labels.dart |
| 723 | `specialNone` | 普通学习 | Regular Study | enum_labels.dart |
| 724 | `specialSessionMistakes` | 复习本轮错词 | Review This Round's Mistakes | enum_labels.dart, study_page.dart |
| 725 | `specialSprint` | 考前冲刺 | Exam Prep | dashboard_page.dart, enum_labels.dart, sprint_page.dart |
| 726 | `sprintAboutBody` | 冲刺计划从所选词书单独排队。作答会照常记录为复习，因此计入今日限额，并更新下次复习日期；今天答对不会缩短已经形成的复习间隔。修改计划会重新排队，已记录的作答全部保留。 | Exam prep builds its own queue from the selected word list. Answers are recorded as ordinary reviews, so they count towards today's limit and move the word's next review date; a correct answer today does not shorten an interval already earned. Changing the plan re-plans the queue and keeps every recorded answer. | sprint_page.dart |
| 727 | `sprintAlgorithmNote` | 优先复习困难词和近期错词，同时兼顾其他单词。 | Prioritises difficult words and recent mistakes, while still covering other words. | sprint_page.dart |
| 728 | `sprintBookUnavailable` | 目标词书不可用，请重新选择。 | The word list is unavailable. Choose another one. | sprint_page.dart |
| 729 | `sprintChanged` | 冲刺计划已改变，请返回重新安排。 | The exam plan changed. Go back and set it up again. | error_labels.dart |
| 730 | `sprintDialogNote` | 冲刺是独立练习。关闭额外复习时，按今日剩余限额安排。修改计划会重新排队，已作答记录会保留。 | Exam prep is a separate practice. With extra reviews off it respects today's limit. Changing the plan re-plans the queue and keeps your answers. | sprint_page.dart |
| 731 | `sprintDisabledNote` | 尚未开启冲刺。 | Exam prep is off. | sprint_page.dart |
| 732 | `sprintEligibleLine` | 范围内 {eligible} 词 · 今日剩余复习限额 {allowance} | {eligible} eligible · {allowance} reviews left today | sprint_page.dart |
| 733 | `sprintEnable` | 开启冲刺 | Turn On Exam Prep | sprint_page.dart |
| 734 | `sprintIncomplete` | 请选择考试日期和目标词书。 | Choose an exam date and a word list. | error_labels.dart |
| 735 | `sprintInvalidBook` | 目标词书无效。 | That word list isn't valid. | error_labels.dart |
| 736 | `sprintInvalidDate` | 考试日期无效。 | That exam date isn't valid. | error_labels.dart |
| 737 | `sprintInvalidRoundSize` | 每轮单词数需在 1–500 之间。 | Words per round must be between 1 and 500. | error_labels.dart |
| 738 | `sprintInvalidSwitch` | 冲刺计划无效，请重新设置。 | This plan isn't valid. Set it up again. | error_labels.dart |
| 739 | `sprintLimitReached` | 今日复习额度已用完。可在计划中允许额外复习。 | Today's review limit is reached. You can allow extra reviews in the plan. | sprint_page.dart |
| 740 | `sprintNothingToRun` | 当前没有可安排的冲刺任务，请检查计划与今日限额。 | Nothing to review right now. Check the plan and today's limits. | sprint_page.dart |
| 741 | `sprintOnlyUnlearned` | 只剩未学单词。可在计划中允许包含未学单词。 | Only unstudied words are left. You can include them in the plan. | sprint_page.dart |
| 742 | `sprintPlanFailed` | 无法读取冲刺计划，请重试。 | Couldn't load the exam plan. | （仅文档/间接） |
| 743 | `sprintPrepareFailed` | 无法准备冲刺任务，请重试。 | Couldn't start exam prep. | sprint_page.dart |
| 744 | `sprintSaveFailed` | 无法保存冲刺计划，请重试。 | Couldn't save the exam plan. | sprint_page.dart |
| 745 | `sprintThisRound` | 本轮 {count} 词 | {count} words this round | sprint_page.dart |
| 746 | `sprintTileOff` | 制定冲刺计划 | Set up an exam plan | sprint_page.dart |
| 747 | `sprintTileSubtitleOff` | 为考试制定复习计划 | Set up an exam plan | dashboard_page.dart |
| 748 | `sprintTileSubtitleOn` | 考试日期 {date} · 每轮 {count} 个 | Exam on {date} · {count} words per round | dashboard_page.dart |
| 749 | `sprintVersionUnsupported` | 此计划来自更新的版本，请升级应用。 | This plan was made by a newer version. Update the app. | error_labels.dart |
| 750 | `stageLearning` | 学习中 | Learning | enum_labels.dart |
| 751 | `stageNotStudied` | 未学 | Not Studied | enum_labels.dart |
| 752 | `stageRelearning` | 重学中 | Relearning | enum_labels.dart |
| 753 | `stageReviewing` | 复习中 | Reviewing | enum_labels.dart |
| 754 | `startImportCount` | 导入 {count} 个单词 | Import {count, plural, =1{1 Word} other{{count} Words}} | import_page.dart |
| 755 | `startMerging` | 开始合并 | Merge | sync_settings_page.dart |
| 756 | `startSprint` | 开始冲刺 | Start Exam Prep | sprint_page.dart |
| 757 | `startStudying` | 开始学习 | Start Studying | dashboard_page.dart |
| 758 | `statDuplicates` | 重复单词 | Duplicates | import_page.dart |
| 759 | `statExistingWords` | 已有单词 | Existing | import_page.dart |
| 760 | `statFormat` | 格式 | Format | import_page.dart |
| 761 | `statImportable` | 可导入 | Importable | import_page.dart |
| 762 | `statInvalid` | 无效内容 | Invalid | import_page.dart |
| 763 | `statLists` | 词书数 | Word Lists | import_page.dart |
| 764 | `statNewWords` | 新单词 | New | import_page.dart |
| 765 | `statRestorable` | 可恢复 | Restorable | import_page.dart |
| 766 | `statWillLink` | 将加入词书 | Will be added | import_page.dart |
| 767 | `stateChangedSkipped` | 学习记录已改变，已跳过旧题。 | This word's progress changed. The old card was skipped. | error_labels.dart |
| 768 | `statsLoadFailed` | 无法读取统计，请重试。 | Couldn't load statistics. | statistics_page.dart |
| 769 | `statsOverview` | 总览 | Overview | statistics_page.dart |
| 770 | `statusLabel` | 状态 | Progress | word_management_page.dart |
| 771 | `stepChooseSource` | 1. 选择来源 | 1. Source | import_page.dart |
| 772 | `stepPreview` | 2. 预览 | 2. Preview | import_page.dart |
| 773 | `stepTargetList` | 3. 目标词书 | 3. Word List | import_page.dart |
| 774 | `studyHistoryShort` | 正确 {correct} · 模糊 {hazy} · 错误 {wrong} · 间隔 {days} 天 | {correct} correct · {hazy} unsure · {wrong} wrong · {days}-day interval | study_page.dart |
| 775 | `studyLoadFailed` | 无法加载学习任务，请重试。 | Couldn't load this session. Try again. | error_labels.dart |
| 776 | `studyMode` | 学习模式 | Study Mode | settings_page.dart |
| 777 | `studySaveFailed` | 保存失败，请重试。 | Couldn't save. Try again. | error_labels.dart |
| 778 | `studyTitle` | 学习 | Study | study_page.dart |
| 779 | `studyWordList` | 学习词书 | Word List | dashboard_page.dart, settings_page.dart, sprint_page.dart |
| 780 | `submit` | 提交 | Submit | practice_page.dart |
| 781 | `supportedFormats` | 支持的格式 | Supported Formats | import_page.dart |
| 782 | `syncCapabilityAuthFailed` | 认证失败：账号或密码不正确 | Sign-in failed. Check the account and password. | sync_labels.dart |
| 783 | `syncCapabilityConnectionFailed` | 无法连接服务器 | Can't reach the server | sync_labels.dart |
| 784 | `syncCapabilityNoFolder` | 已连接，但无法访问此文件夹 | Connected, but this folder isn't accessible | sync_labels.dart |
| 785 | `syncCapabilityReadOnly` | 已连接，但只能读取，无法写入 | Connected, but read-only | sync_labels.dart |
| 786 | `syncCapabilitySafe` | 连接成功，可以同步 | Connected. Ready to sync. | sync_labels.dart |
| 787 | `syncCapabilityUnknown` | 尚未验证连接 | Connection not verified | sync_labels.dart |
| 788 | `syncCapabilityUnsafe` | 此服务器暂不支持安全同步 | This server doesn't support safe syncing | sync_labels.dart |
| 789 | `syncConflictRetry` | 其他设备修改了数据，请重新同步。 | Another device changed the data. Try syncing again. | sync_settings_page.dart |
| 790 | `syncConflicts` | 同步冲突 | Sync Conflicts | sync_settings_page.dart |
| 791 | `syncDiagnostics` | 同步诊断信息 | Sync Diagnostics | sync_settings_page.dart |
| 792 | `syncDiagnosticsHint` | 查看并导出最近的同步请求记录（不含密码与学习内容） | View and export recent sync requests (no passwords or study content). | sync_settings_page.dart |
| 793 | `syncFailed` | 同步失败。 | Sync failed. | sync_settings_page.dart |
| 794 | `syncFilePath` | 同步文件路径 | Sync File Path | sync_settings_page.dart |
| 795 | `syncFileUnreadable` | 无法读取同步文件。 | Unable to read the sync file. | sync_settings_page.dart |
| 796 | `syncInProgress` | 同步正在进行中 | A sync is already running. | sync_settings_page.dart |
| 797 | `syncMethod` | 同步方式 | Sync Method | sync_settings_page.dart |
| 798 | `syncNow` | 立即同步 | Sync Now | sync_settings_page.dart |
| 799 | `syncOff` | 不同步 | Off | sync_settings_page.dart |
| 800 | `syncOffHint` | 学习数据仅保存在此设备上 | Study data stays on this device. | sync_settings_page.dart |
| 801 | `syncOnChange` | 更改后同步 | Sync After Changes | sync_settings_page.dart |
| 802 | `syncOnChangeHint` | 停止操作约 20 秒后同步，不会在每次作答后立即联网。 | Runs about 20 seconds after you stop, not after every answer. | sync_settings_page.dart |
| 803 | `syncOnResume` | 返回应用时同步 | Sync on Return | sync_settings_page.dart |
| 804 | `syncOnResumeHint` | 切回应用后自动检查更新，失败时会稍后重试。 | Checks for changes when you come back; retries later on failure. | sync_settings_page.dart |
| 805 | `syncOnSessionEnd` | 学习结束时同步 | Sync When a Session Ends | sync_settings_page.dart |
| 806 | `syncOnSessionEndHint` | 学习结束后自动同步，不影响结束流程。 | Runs after a session ends, without changing the flow. | sync_settings_page.dart |
| 807 | `syncOnStart` | 启动时同步 | Sync on Launch | sync_settings_page.dart |
| 808 | `syncOnStartHint` | 打开应用时自动同步，不阻塞启动 | The app always shows local data first. | sync_settings_page.dart |
| 809 | `syncPausedBanner` | 同步已暂停 | Sync Paused | backup_page.dart |
| 810 | `syncPausedBannerBody` | 本机数据来自历史恢复，尚未与远端核对。在「同步」页确认如何处理远端数据前，自动同步不会运行。 | This data came from a restore and hasn't been checked against the remote copy. Automatic sync stays off until you confirm how to handle the remote data on the Sync page. | backup_page.dart |
| 811 | `syncPausedRemoteUnchanged` | 同步保持暂停，远端数据未被修改 | Sync stays paused. The remote data was not changed. | backup_page.dart |
| 812 | `syncPausedRestoreBody` | 本机数据来自历史恢复。确认远端如何处理之前，自动同步不会运行。 | This data came from a restore. Automatic sync stays off until you decide what to do with the remote data. | sync_settings_page.dart |
| 813 | `syncPausedTitle` | 同步已暂停 | Sync Paused | sync_settings_page.dart |
| 814 | `syncResult` | 同步结果 | Sync Result | sync_settings_page.dart |
| 815 | `syncResultFailed` | 同步失败 | Sync failed | sync_labels.dart |
| 816 | `syncResultInitialised` | 已用本机数据初始化远程文件 | Remote file initialised from this device | sync_labels.dart |
| 817 | `syncResultPartial` | 本机已保存，上传未完成 | Saved locally, upload pending | sync_labels.dart |
| 818 | `syncResultRemoteHasData` | 远程已包含本机数据，未上传 | Remote already has this data | sync_labels.dart |
| 819 | `syncResultSynced` | 已同步 | Synced | sync_labels.dart |
| 820 | `syncResultSyncedWith` | 已同步：{summary} | Synced: {summary} | sync_labels.dart |
| 821 | `syncResultUnchanged` | 数据一致，无需上传 | Already up to date | sync_labels.dart |
| 822 | `syncResultUnknown` | 同步完成 | Sync finished | sync_labels.dart |
| 823 | `syncStageAuthFailed` | 认证失败 | Sign-in failed | sync_labels.dart |
| 824 | `syncStageConfigChanged` | 配置已变化 | Settings changed | sync_labels.dart |
| 825 | `syncStageDone` | 完成 | Done | sync_labels.dart |
| 826 | `syncStageDownloading` | 读取远程数据 | Reading remote data | sync_labels.dart |
| 827 | `syncStageFailed` | 失败 | Failed | sync_labels.dart |
| 828 | `syncStageIdle` | 准备 | Preparing | sync_labels.dart |
| 829 | `syncStageMergedNotUploaded` | 本机已保存，上传未完成 | Saved locally, upload pending | sync_labels.dart |
| 830 | `syncStageMerging` | 合并数据 | Merging | sync_labels.dart |
| 831 | `syncStagePausedAfterRestore` | 恢复后已暂停同步 | Paused after restore | sync_labels.dart |
| 832 | `syncStageRebuilding` | 更新学习进度 | Updating progress | sync_labels.dart |
| 833 | `syncStageRemoteCorrupt` | 远程数据不可用 | Remote data unreadable | sync_labels.dart |
| 834 | `syncStageRemoteMissing` | 远程数据缺失 | Remote data missing | sync_labels.dart |
| 835 | `syncStageUploading` | 上传数据 | Uploading | sync_labels.dart |
| 836 | `syncStageValidating` | 校验配置 | Checking settings | sync_labels.dart |
| 837 | `syncStageVerifying` | 校验上传结果 | Verifying upload | sync_labels.dart |
| 838 | `syncStageWaitingBackoff` | 等待重试 | Waiting to retry | sync_labels.dart |
| 839 | `syncStatus` | 同步状态 | Sync Status | sync_settings_page.dart |
| 840 | `syncStaysPausedRemoteUntouched` | 同步保持暂停，远端数据未被修改 | Sync stays paused. The remote data was not changed. | sync_settings_page.dart |
| 841 | `syncStillPausedUntilTarget` | 同步仍暂停：在新目标完成一次同步后会解除。 | Sync stays paused until one sync completes with the new target. | backup_page.dart |
| 842 | `syncSubtitle` | 在设备间同步学习数据 | Keep your data in step across devices. | settings_page.dart |
| 843 | `syncTargetsHint` | GitHub / WebDAV / 本地文件 | GitHub / WebDAV / local file | backup_page.dart |
| 844 | `syncTestFailed` | 连接验证未通过 | Connection check failed | sync_labels.dart |
| 845 | `syncTestOk` | 连接验证通过 | Connection verified | sync_labels.dart |
| 846 | `syncTitle` | 同步 | Sync | settings_page.dart, sync_settings_page.dart |
| 847 | `syncTurnedOff` | 已关闭同步 | Sync turned off. | sync_settings_page.dart |
| 848 | `syncUploadPending` | 本机数据已保存，上传尚未完成。 | Local data is saved. Upload is pending. | sync_settings_page.dart |
| 849 | `syncing` | 同步中… | Syncing… | sync_settings_page.dart |
| 850 | `systemDefault` | 系统默认 | System Default | settings_page.dart |
| 851 | `tagCreateFirst` | 请先在标签管理中创建标签。 | Create a tag in Tags first. | word_metadata_widgets.dart |
| 852 | `tagDeleteAction` | 删除标签 {name} | Delete tag {name} | word_metadata_widgets.dart |
| 853 | `tagName` | 标签名称 | Tag Name | word_metadata_widgets.dart |
| 854 | `tagOperationFailed` | 标签操作失败，请重试。 | Couldn't update tags. Try again. | word_metadata_widgets.dart |
| 855 | `tags` | 标签 | Tags | word_management_page.dart |
| 856 | `tagsLoadFailed` | 无法读取标签，请重新打开。 | Couldn't load tags. Open this page again. | word_metadata_widgets.dart |
| 857 | `tagsManagement` | 标签管理 | Tags | word_management_page.dart, word_metadata_widgets.dart |
| 858 | `targetList` | 词书 | Word List | import_page.dart, quick_add_page.dart |
| 859 | `targetListName` | 目标词书：{name} | Word list: {name} | sprint_page.dart |
| 860 | `technicalDetails` | 技术详情 | Technical Details | sync_settings_page.dart |
| 861 | `testConnection` | 测试连接 | Test Connection | sync_settings_page.dart |
| 862 | `themeDark` | 深色 | Dark | enum_labels.dart |
| 863 | `themeLight` | 浅色 | Light | enum_labels.dart |
| 864 | `themeSystem` | 跟随系统 | System Default | enum_labels.dart |
| 865 | `timeAgo` | {value}前 | {value} ago | relative_time.dart |
| 866 | `timeDaysValue` | {count} 天 | {count, plural, =1{1 day} other{{count} days}} | relative_time.dart |
| 867 | `timeHoursValue` | {count} 小时 | {count, plural, =1{1 hour} other{{count} hours}} | relative_time.dart |
| 868 | `timeIn` | {value}后 | in {value} | relative_time.dart |
| 869 | `timeJustNow` | 刚刚 | just now | relative_time.dart |
| 870 | `timeMonthsValue` | {count} 个月 | {count, plural, =1{1 month} other{{count} months}} | relative_time.dart |
| 871 | `timeNotRecorded` | 未记录 | not recorded | backup_page.dart |
| 872 | `timeSpent` | 用时 {minutes} 分 {seconds} 秒（含暂停） | {minutes} min {seconds} s (pauses included) | study_page.dart |
| 873 | `timeValue` | {count} 分钟 | {count, plural, =1{1 minute} other{{count} minutes}} | relative_time.dart |
| 874 | `timeYearsValue` | {count} 年 | {count, plural, =1{1 year} other{{count} years}} | relative_time.dart |
| 875 | `todayDone` | 今日任务已完成。 | Today's tasks are done. | dashboard_page.dart |
| 876 | `todayDoneHint` | 你可以继续练习，或稍后回来复习。 | You can keep practicing, or come back later to review. | dashboard_page.dart |
| 877 | `todayNewWords` | 新词 | New Words | statistics_page.dart |
| 878 | `todayReviews` | 复习 | Reviews | statistics_page.dart |
| 879 | `todayStudy` | 今日学习 | Today | statistics_page.dart |
| 880 | `todayTasks` | 今日任务 | Today | dashboard_page.dart |
| 881 | `tokenMissing` | 未读取到已保存的访问令牌，请重新输入后再同步。 | No saved access token was found. Enter it again before syncing. | sync_settings_page.dart |
| 882 | `totalWordsLabel` | 单词总数 | Total Words | statistics_page.dart |
| 883 | `turnOffSync` | 关闭同步 | Turn Off Sync | sync_settings_page.dart |
| 884 | `turnOffSyncBody` | 本机保存的同步设置和凭据（访问令牌 / 密码）会被删除。远程数据不会被删除，学习记录仍保存在本机。 | The sync settings and credentials (token / password) stored on this device are deleted. Remote data is not deleted, and study records stay on this device. | sync_settings_page.dart |
| 885 | `typeTheWord` | 输入英文单词 | Type the word | practice_page.dart |
| 886 | `typeToLookUp` | 输入单词 | Type a word to look it up | quick_add_page.dart |
| 887 | `undoFailed` | 撤销失败，请重试。 | Couldn't undo. Try again. | error_labels.dart |
| 888 | `undoLastAnswer` | 撤销上次作答 | Undo Last Answer | study_page.dart |
| 889 | `undoLastQuestion` | 撤销上次作答 | Undo Last Answer | practice_page.dart |
| 890 | `undoneAnswers` | 已撤销作答 | Undone | statistics_page.dart |
| 891 | `unfavoriteSelected` | 取消收藏 | Remove from Favorites | word_management_page.dart |
| 892 | `unfavoriteWord` | 取消收藏 | Remove from Favorites | word_metadata_widgets.dart |
| 893 | `unknownReason` | 未知原因 | unknown reason | backup_labels.dart, backup_page.dart |
| 894 | `unlearnedLabel` | 未学 | Not Studied | dictionary_page.dart, statistics_page.dart |
| 895 | `unlearnedWords` | 未学单词 | Not Studied | sprint_page.dart |
| 896 | `unmarkMastered` | 取消掌握 | Unmark as Mastered | word_detail_page.dart, word_management_page.dart |
| 897 | `unmarkMasteredBody` | 取消人工掌握标记。学习进度按已有作答记录恢复，不增加作答次数。 | Clears the manual mark. Progress returns to what the recorded answers say, without adding answers. | word_detail_page.dart, word_management_page.dart |
| 898 | `unmarkMasteredBodyOne` | 取消掌握后恢复到学习阶段，并安排近期复习。保留历史，不增加作答次数。 | Returns the word to learning and schedules a near review. History is kept; no answer is added. | word_management_page.dart |
| 899 | `unmarkMasteredDone` | 已取消 {count} 个单词的掌握标记 | {count, plural, =1{Unmarked 1 word} other{Unmarked {count} words}} | word_management_page.dart |
| 900 | `unmarkMasteredTitle` | 取消掌握标记？ | Unmark as Mastered? | word_detail_page.dart, word_management_page.dart |
| 901 | `unsafeServerBody` | 正常情况下这里会用条件请求写入，确保两台设备同时修改时不会互相覆盖。这台服务器做不到，所以自动合并和「立即同步」都不会执行。⏎⏎可以改用「导出备份」，或用其他支持条件请求的 WebDAV 服务。 | This is normally written with a conditional request, so two devices editing at once can't overwrite each other. This server can't do that, so automatic merge and Sync Now won't run.⏎⏎Use Export Backup, or a WebDAV service that supports conditional requests. | sync_settings_page.dart |
| 902 | `updatedWordsCount` | 已更新 {count} 个单词 | {count, plural, =1{Updated 1 word} other{Updated {count} words}} | word_management_page.dart |
| 903 | `useNewTarget` | 使用新的同步目标 | Use a New Target | backup_page.dart |
| 904 | `username` | 用户名 | Username | sync_settings_page.dart |
| 905 | `valueRange` | 数值（{min}–{max}） | Value ({min}–{max}) | settings_page.dart |
| 906 | `valueTimes` | {count} 次 | {count} | statistics_page.dart |
| 907 | `viewInfo` | 查看信息 | View Info | backup_page.dart |
| 908 | `viewResults` | 查看结果 | View Results | practice_page.dart |
| 909 | `voiceUnavailable` | 无法播放发音。 | Voice unavailable. | settings_page.dart, study_page.dart |
| 910 | `voiceVariantAU` | 澳洲 | Australia | voice_labels.dart |
| 911 | `voiceVariantCA` | 加拿大 | Canada | voice_labels.dart |
| 912 | `voiceVariantIE` | 爱尔兰 | Ireland | voice_labels.dart |
| 913 | `voiceVariantIN` | 印度 | India | voice_labels.dart |
| 914 | `voiceVariantUK` | 英式 | UK | voice_labels.dart |
| 915 | `voiceVariantUS` | 美式 | US | voice_labels.dart |
| 916 | `webdavHint` | 使用兼容的 WebDAV 服务同步 | Syncs through a compatible WebDAV service. | sync_settings_page.dart |
| 917 | `wordCountPlural` | {count} 个单词 | {count, plural, =0{No words} =1{1 word} other{{count} words}} | wordbooks_page.dart |
| 918 | `wordDetailTitle` | 单词详情 | Word Details | word_management_page.dart |
| 919 | `wordEmpty` | 请输入单词。 | Enter a word. | error_labels.dart |
| 920 | `wordEntry` | 单词 | Word | word_detail_page.dart |
| 921 | `wordErrorHazyStat` | 错 {wrong} · 模糊 {hazy} | {wrong} wrong · {hazy} unsure | statistics_page.dart |
| 922 | `wordField` | 单词 | Word | word_detail_page.dart |
| 923 | `wordFormHint` | 可能是「{word}」的过去式或过去分词 | Past tense or past participle of {word} | dictionary_page.dart |
| 924 | `wordInfo` | 单词信息 | Word Info | word_detail_page.dart |
| 925 | `wordListEmpty` | 词书为空 | This word list is empty | word_book_detail_page.dart |
| 926 | `wordListEmptyMessage` | 添加或导入单词以开始学习。 | Add or import words to start studying. | word_book_detail_page.dart |
| 927 | `wordListLoadFailed` | 无法加载词书，请重试。 | Couldn't load this word list. Try again. | word_book_detail_page.dart |
| 928 | `wordListName` | 词书名称 | Word List Name | dictionary_page.dart, import_page.dart, quick_add_page.dart, wordbooks_page.dart |
| 929 | `wordListOptionLabel` | {name}（{count} 词） | {name} ({count} words) | dashboard_page.dart |
| 930 | `wordListProgress` | 词书进度 | Word List Progress | statistics_page.dart |
| 931 | `wordListRowStats` | {count} 词 · 已学 {learned} · 到期 {due} | {count} words · {learned} studied · {due} due | statistics_page.dart, wordbooks_page.dart |
| 932 | `wordListsLoadFailed` | 无法加载词书，请重试。 | Couldn't load word lists. Try again. | word_management_page.dart, wordbooks_page.dart |
| 933 | `wordManagementDeleteWord` | 删除单词 | Delete Word | word_detail_page.dart, word_management_page.dart |
| 934 | `wordNotFound` | 找不到此单词 | Word Not Found | error_labels.dart, word_detail_page.dart, word_management_page.dart |
| 935 | `wordNotInDictionary` | 离线词典未收录此单词。 | The dictionary doesn't have this word. | word_detail_page.dart |
| 936 | `wordPerformance` | 学习表现 | Performance | statistics_page.dart |
| 937 | `wordRemovedSkipped` | 此单词已被删除，已跳过。 | This word was removed, so it was skipped. | error_labels.dart |
| 938 | `wordTooLong` | 单词过长（最多 64 个字符）。 | That word is too long (64 characters at most). | error_labels.dart |
| 939 | `wordsAndAnswers` | {words} 个单词 · {answers} 次作答 | {words} words · {answers} answers | study_page.dart |
| 940 | `worthAnotherLook` | 建议复习 | Worth Another Look | practice_page.dart |
| 941 | `wrongCountChip` | 错 {count} 次 | {count, plural, =1{1 miss} other{{count} misses}} | study_page.dart, word_book_detail_page.dart |
| 942 | `yes` | 是 | Yes | backup_page.dart |
| 943 | `yourAnswer` | 你的答案：{answer} | Your answer: {answer} | practice_page.dart |
