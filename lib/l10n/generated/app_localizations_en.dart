// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navToday => 'Today';

  @override
  String get navWordLists => 'Word Lists';

  @override
  String get navDictionary => 'Dictionary';

  @override
  String get navStatistics => 'Statistics';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAllWords => 'All Words';

  @override
  String get navOfflineNote => 'Offline · stored on this device';

  @override
  String get actionAddWord => 'Add Word';

  @override
  String actionAddWordsShortcut(String shortcut) {
    return 'Add Word ($shortcut)';
  }

  @override
  String get actionAddWordShortcutMac => 'Add Word (⌘N)';

  @override
  String get manageAllWords => 'All Words';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Try Again';

  @override
  String get commonDone => 'Done';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonRestore => 'Restore';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonImport => 'Import';

  @override
  String get commonExport => 'Export';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonTest => 'Test';

  @override
  String get commonAll => 'All';

  @override
  String get commonCopy => 'Copy';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accentColor => 'Accent Color';

  @override
  String get accentColorHint => 'Change the app\'s theme color.';

  @override
  String get accentAnswerNote => 'Answer colors are not affected.';

  @override
  String get accentCustom => 'Custom Color';

  @override
  String get accentHex => 'HEX';

  @override
  String get accentRestoreDefault => 'Restore Default Color';

  @override
  String get accentClassicGroup => 'Classic';

  @override
  String get accentMaterialGroup => 'Material Design';

  @override
  String get appLanguage => 'App Language';

  @override
  String get appLanguageSystem => 'System Default';

  @override
  String get appLanguageChinese => '简体中文';

  @override
  String get appLanguageEnglish => 'English';

  @override
  String get accentClearSkyBlue => 'Clear Sky Blue';

  @override
  String get accentDeepSeaBlue => 'Deep Sea Blue';

  @override
  String get accentGoldenOrange => 'Golden Orange';

  @override
  String get accentLemonYellow => 'Lemon Yellow';

  @override
  String get accentGrassGreen => 'Grass Green';

  @override
  String get accentJadeGreen => 'Jade Green';

  @override
  String get accentViolet => 'Violet';

  @override
  String get accentDeepIndigo => 'Deep Indigo';

  @override
  String get accentSkyBlue => 'Sky Blue';

  @override
  String get accentVibrantPink => 'Vibrant Pink';

  @override
  String get accentOrchidPink => 'Orchid Pink';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentRed => 'Red';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentPurple => 'Purple';

  @override
  String get accentCyan => 'Cyan';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentBlueGray => 'Blue Gray';

  @override
  String get accentDeepOrange => 'Deep Orange';

  @override
  String get accentLightGreen => 'Light Green';

  @override
  String get stageNotStudied => 'Not Studied';

  @override
  String get stageLearning => 'Learning';

  @override
  String get stageReviewing => 'Reviewing';

  @override
  String get stageRelearning => 'Relearning';

  @override
  String get mastered => 'Mastered';

  @override
  String get answerKnow => 'Know';

  @override
  String get answerNotSure => 'Not Sure';

  @override
  String get answerDontKnow => 'Don\'t Know';

  @override
  String get modeMixed => 'New Words & Review';

  @override
  String get modeNewOnly => 'New Words Only';

  @override
  String get modeReviewOnly => 'Review Only';

  @override
  String get modeSpecial => 'Targeted Review';

  @override
  String get specialNone => 'Regular Study';

  @override
  String get specialHard => 'Review Difficult Words';

  @override
  String get specialMistakes => 'Review Recent Mistakes';

  @override
  String get specialBook => 'Review This Word List';

  @override
  String get specialFavorites => 'Review Favorites';

  @override
  String get specialSessionMistakes => 'Review This Round\'s Mistakes';

  @override
  String get specialSprint => 'Exam Prep';

  @override
  String get practiceSpelling => 'Spelling';

  @override
  String get practiceDictation => 'Dictation';

  @override
  String get practiceChoice => 'Multiple Choice';

  @override
  String get practiceCloze => 'Fill in the Blank';

  @override
  String get practiceSpellingDesc =>
      'Type the English word for the Chinese meaning.';

  @override
  String get practiceDictationDesc => 'Listen and type the English word.';

  @override
  String get practiceChoiceDesc => 'Pick the correct word.';

  @override
  String get practiceClozeDesc => 'Complete the word in the example sentence.';

  @override
  String get sortAddedDesc => 'Recently Added';

  @override
  String get sortAlpha => 'Alphabetical';

  @override
  String get sortWrongDesc => 'Most Mistakes';

  @override
  String get sortLastStudied => 'Recently Studied';

  @override
  String get filterAll => 'All';

  @override
  String get filterUnlearned => 'Not Studied';

  @override
  String get filterLearning => 'Learning';

  @override
  String get filterReviewing => 'Reviewing';

  @override
  String get filterRelearning => 'Relearning';

  @override
  String get filterHard => 'Difficult Words';

  @override
  String get filterMastered => 'Mastered';

  @override
  String get errorGeneric => 'Something went wrong. Try again.';

  @override
  String get errorLoadFailed => 'Couldn\'t load this. Try again.';

  @override
  String get errorSaveFailed => 'Couldn\'t save. Try again.';

  @override
  String get errorNetwork => 'No network connection.';

  @override
  String get errorTimeout => 'The connection timed out. Try again.';

  @override
  String get errorPermission => 'No permission to do that.';

  @override
  String get sectionDailyGoals => 'Daily Goals';

  @override
  String get sectionStudy => 'Study';

  @override
  String get sectionPronunciation => 'Pronunciation';

  @override
  String get sectionData => 'Data';

  @override
  String get sectionAbout => 'About';

  @override
  String get dailyNewWords => 'Daily New Words';

  @override
  String get dailyReviewLimit => 'Daily Review Limit';

  @override
  String get dailyGoalsNote =>
      'Goals apply to this device. Words beyond the review limit move to tomorrow.';

  @override
  String get studyWordList => 'Word List';

  @override
  String get allWordLists => 'All Word Lists';

  @override
  String get studyMode => 'Study Mode';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get enterExactValue => 'Enter a number';

  @override
  String valueRange(int min, int max) {
    return 'Value ($min–$max)';
  }

  @override
  String get ok => 'OK';

  @override
  String enterNumberInRange(int min, int max) {
    return 'Enter a number between $min and $max.';
  }

  @override
  String get customAccentTitle => 'Custom Color';

  @override
  String get apply => 'Apply';

  @override
  String get invalidHexColor => 'Enter a 6-digit HEX color, such as #1565C0.';

  @override
  String accentSwatchSemantics(String name) {
    return 'Accent color $name';
  }

  @override
  String get englishVoice => 'English Voice';

  @override
  String get loadingVoices => 'Loading system voices…';

  @override
  String get systemDefault => 'System Default';

  @override
  String get noEnglishVoice =>
      'No English voice is installed. Install one in System Settings to hear pronunciation.';

  @override
  String get autoPronounce => 'Auto-Pronunciation';

  @override
  String get autoPronounceHint =>
      'Offline playback depends on the installed voice.';

  @override
  String get refreshVoices => 'Refresh Voices';

  @override
  String get previewVoice => 'Preview Voice';

  @override
  String get speakingRate => 'Speaking Rate';

  @override
  String get keepScreenAwake => 'Keep Screen Awake';

  @override
  String get keepScreenAwakeHint =>
      'Applies only while studying or practicing.';

  @override
  String get keepScreenAwakeUnsupported =>
      'Not available on this platform. Studying is unaffected.';

  @override
  String get randomOrder => 'Random Order';

  @override
  String get randomOrderHint =>
      'Shuffles the order. Targeted review and exam prep are unaffected.';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncSubtitle => 'Keep your data in step across devices.';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get backupRestoreSubtitle => 'Back up and restore your study data.';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsSubtitle => 'Version, logs and troubleshooting.';

  @override
  String get aboutBlurb =>
      'An offline-first vocabulary app. Your data stays on this device unless you turn on sync.';

  @override
  String aboutDictionary(int count, String license) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Built-in dictionary: $countString entries (ECDICT, $license license).';
  }

  @override
  String get openSourceLicenses => 'Open Source Licenses';

  @override
  String get licensesSubtitle =>
      'Flutter, Drift, ECDICT and other dependencies';

  @override
  String get legalNotice =>
      'ECDICT dictionary data is distributed under the MIT license.';

  @override
  String get voiceUnavailable => 'Voice unavailable.';

  @override
  String get languageSheetTitle => 'App Language';

  @override
  String sprintTileSubtitleOn(String date, int count) {
    return 'Exam on $date · $count words per round';
  }

  @override
  String get sprintTileSubtitleOff => 'Set up an exam plan';

  @override
  String get continueStudying => 'Continue Studying';

  @override
  String resumeProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get todayTasks => 'Today';

  @override
  String get scopeCurrentList => 'This word list';

  @override
  String get scopeAllLists => 'All word lists';

  @override
  String backlogNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count due words are beyond today\'s review limit. They move to tomorrow.',
      one: '1 due word is beyond today\'s review limit. It moves to tomorrow.',
    );
    return '$_temp0';
  }

  @override
  String get startStudying => 'Start Studying';

  @override
  String get reviewOnly => 'Review Only';

  @override
  String get newWordsAvailable => 'New Words Available';

  @override
  String get reviewsAvailable => 'Due Reviews';

  @override
  String get overdueReviews => 'Overdue Reviews';

  @override
  String get difficultWords => 'Difficult Words';

  @override
  String get newWords => 'New Words';

  @override
  String get review => 'Review';

  @override
  String newWordsHintRemaining(int remaining, int unlearned) {
    return '$remaining left · $unlearned not studied';
  }

  @override
  String get noNewWordsInScope => 'No new words left in this scope.';

  @override
  String reviewHintRemaining(int due, int remaining) {
    return '$due due · $remaining left';
  }

  @override
  String get noDueWords => 'No words due for review.';

  @override
  String learnedOfTotal(int learned, int total) {
    return '$learned of $total studied';
  }

  @override
  String get todayDone => 'Today\'s tasks are done.';

  @override
  String get todayDoneHint =>
      'You can keep practicing, or come back later to review.';

  @override
  String hardWordsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words you missed or weren\'t sure of',
      one: '1 word you missed or weren\'t sure of',
    );
    return '$_temp0';
  }

  @override
  String get noHardWordsYet => 'No difficult words yet.';

  @override
  String get mistakesSubtitle => 'Review words you recently got wrong.';

  @override
  String get sectionPractice => 'Practice';

  @override
  String get practiceNote =>
      'Practice does not use your daily allowance and does not affect your review schedule.';

  @override
  String get clozeUsesOwnSentence => 'Uses the example stored with the word.';

  @override
  String get noWordsYet => 'No words yet';

  @override
  String get firstRunBody =>
      'Import your own word list, or add the sample list to try the learning flow. You can also tap + to add words by hand.';

  @override
  String get importWordList => 'Import Word List';

  @override
  String get addSampleList => 'Add Sample Word List';

  @override
  String get sampleAddFailed => 'Couldn\'t add the sample word list.';

  @override
  String sampleLoaded(String name, int count) {
    return 'Added “$name”: $count words.';
  }

  @override
  String wordListOptionLabel(String name, int count) {
    return '$name ($count words)';
  }

  @override
  String get sectionStartStudy => 'Start Studying';

  @override
  String get sectionSpecialReview => 'Targeted Review';

  @override
  String get studyLoadFailed => 'Couldn\'t load this session. Try again.';

  @override
  String get studySaveFailed => 'Couldn\'t save. Try again.';

  @override
  String get undoFailed => 'Couldn\'t undo. Try again.';

  @override
  String get skipFailed => 'Couldn\'t skip. Try again.';

  @override
  String get wordRemovedSkipped => 'This word was removed, so it was skipped.';

  @override
  String get stateChangedSkipped =>
      'This word\'s progress changed. The old card was skipped.';

  @override
  String get contentUpdatedReview =>
      'This word was updated. Check it again before answering.';

  @override
  String get sprintChanged =>
      'The exam plan changed. Go back and set it up again.';

  @override
  String get reviewLimitReached =>
      'Today\'s review limit is reached. You can allow extra reviews in the exam plan.';

  @override
  String get practiceLoadFailed => 'Couldn\'t load this practice. Try again.';

  @override
  String get practiceSaveFailed => 'Couldn\'t save this practice. Try again.';

  @override
  String get practiceWordDeleted =>
      'This word was deleted. The round restarts.';

  @override
  String get practiceContentUpdated =>
      'This word was updated. The round restarts.';

  @override
  String get practiceWordUnlinked =>
      'This word is no longer in the word list. The round restarts.';

  @override
  String get editWord => 'Edit Word';

  @override
  String get undoLastAnswer => 'Undo Last Answer';

  @override
  String get skip => 'Skip';

  @override
  String get moreActions => 'More';

  @override
  String get repeatPractice => 'Repeat Practice';

  @override
  String get newWordTag => 'New';

  @override
  String reviewWithStage(String stage) {
    return 'Review · $stage';
  }

  @override
  String wrongCountChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count misses',
      one: '1 miss',
    );
    return '$_temp0';
  }

  @override
  String get recallMeaning => 'Recall the meaning';

  @override
  String get noChineseMeaning => 'No Chinese meaning yet';

  @override
  String get englishDefinition => 'English Definition';

  @override
  String get exampleSentence => 'Example';

  @override
  String get phrases => 'Phrases';

  @override
  String get notes => 'Notes';

  @override
  String get speak => 'Pronounce';

  @override
  String studyHistoryShort(int correct, int hazy, int wrong, int days) {
    return '$correct correct · $hazy unsure · $wrong wrong · $days-day interval';
  }

  @override
  String get showMeaning => 'Show Meaning';

  @override
  String keyHintShowMeaning(String key) {
    return 'Press $key to show the meaning';
  }

  @override
  String get back => 'Back';

  @override
  String get nothingDueSpecial => 'Nothing due for review';

  @override
  String get nothingToStudyToday => 'Nothing to study today';

  @override
  String get specialEmptyMessage =>
      'Only words matching this review are included. Your normal queue is unchanged.';

  @override
  String get nothingLeftTodayMessage =>
      'Today\'s new words and reviews are done. Adjust your goals, import more words, or come back later.';

  @override
  String get roundSummaryFailed => 'Couldn\'t load this round.';

  @override
  String get roundComplete => 'Round Complete';

  @override
  String wordsAndAnswers(int words, int answers) {
    return '$words words · $answers answers';
  }

  @override
  String accuracyValue(String value) {
    return 'Accuracy $value';
  }

  @override
  String timeSpent(int minutes, int seconds) {
    return '$minutes min $seconds s (pauses included)';
  }

  @override
  String get roundDifficultWords => 'Difficult Words';

  @override
  String get deletedWordSuffix => ' (deleted)';

  @override
  String get roundDifficultNote =>
      'Words you weren\'t sure of or didn\'t know. Deleted words are not repeated.';

  @override
  String backlogCarried(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count due words move to tomorrow.',
      one: '1 due word moves to tomorrow.',
    );
    return '$_temp0';
  }

  @override
  String get errorAuthFailed => 'Unable to sign in. Check your credentials.';

  @override
  String get errorRemoteFileMissing =>
      'The sync file is missing from the remote location.';

  @override
  String get errorInvalidBackup => 'This file is not a valid backup.';

  @override
  String get studyTitle => 'Study';

  @override
  String get practiceVoiceHintUsed =>
      'Voice unavailable. The Chinese meaning is shown instead.';

  @override
  String get nothingToPractice => 'Nothing to practice';

  @override
  String get practiceCannotStart => 'Can\'t start this practice';

  @override
  String get clozeEmptyMessage =>
      'Fill in the Blank uses only the example stored with each word. Add an example, or try another practice.';

  @override
  String get practiceEmptyMessage =>
      'Practice needs words with a Chinese meaning. Add or import words first.';

  @override
  String get undoLastQuestion => 'Undo Last Answer';

  @override
  String get playAgain => 'Play Again';

  @override
  String get listenAndType => 'Listen and type the word.';

  @override
  String hintWithText(String text) {
    return 'Hint: $text';
  }

  @override
  String get correct => 'Correct';

  @override
  String get incorrect => 'Wrong';

  @override
  String correctSpelling(String answer) {
    return 'Correct spelling: $answer';
  }

  @override
  String yourAnswer(String answer) {
    return 'Your answer: $answer';
  }

  @override
  String get practiceAnswerNote =>
      'This answer is recorded but does not change the word\'s review interval.';

  @override
  String get viewResults => 'View Results';

  @override
  String get nextQuestion => 'Next';

  @override
  String get typeTheWord => 'Type the word';

  @override
  String get submit => 'Submit';

  @override
  String get chooseCorrectWord => 'Choose the correct word above.';

  @override
  String get hideHint => 'Hide Hint';

  @override
  String get showHint => 'Show Hint';

  @override
  String get practiceComplete => 'Practice Complete';

  @override
  String get answersCount => 'Answers';

  @override
  String get skipped => 'Skipped';

  @override
  String practiceAccuracy(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return 'Accuracy $value · $_temp0';
  }

  @override
  String get worthAnotherLook => 'Worth Another Look';

  @override
  String get practiceStatsNote =>
      'Practice answers count towards statistics but do not change the review interval.';

  @override
  String get continuePracticing => 'Continue Practicing';

  @override
  String get sprintPlanFailed => 'Couldn\'t load the exam plan.';

  @override
  String get createListFirst => 'Add or import a word list first.';

  @override
  String get sprintSaveFailed => 'Couldn\'t save the exam plan.';

  @override
  String get sprintNothingToRun =>
      'Nothing to review right now. Check the plan and today\'s limits.';

  @override
  String get sprintPrepareFailed => 'Couldn\'t start exam prep.';

  @override
  String get setSprintPlan => 'Exam Plan';

  @override
  String get sprintTileOff => 'Set up an exam plan';

  @override
  String examPassedDays(int days) {
    return 'Exam was $days days ago';
  }

  @override
  String get examToday => 'Exam today';

  @override
  String examInDays(int days) {
    return 'Exam in $days days';
  }

  @override
  String targetListName(String name) {
    return 'Word list: $name';
  }

  @override
  String get notSet => 'Not set';

  @override
  String get sprintDisabledNote => 'Exam prep is off.';

  @override
  String get sprintBookUnavailable =>
      'The word list is unavailable. Choose another one.';

  @override
  String get unlearnedWords => 'Not Studied';

  @override
  String get recentMistakes7d => 'Recent Mistakes';

  @override
  String sprintThisRound(int count) {
    return '$count words this round';
  }

  @override
  String sprintEligibleLine(int eligible, int allowance) {
    return '$eligible eligible · $allowance reviews left today';
  }

  @override
  String get sprintOnlyUnlearned =>
      'Only unstudied words are left. You can include them in the plan.';

  @override
  String get sprintLimitReached =>
      'Today\'s review limit is reached. You can allow extra reviews in the plan.';

  @override
  String get sprintAlgorithmNote =>
      'Prioritises difficult words and recent mistakes, while still covering other words.';

  @override
  String get aboutSprintPlan => 'About Exam Prep';

  @override
  String get sprintAboutBody =>
      'Exam prep builds its own queue from the selected word list. Answers are recorded as ordinary reviews, so they count towards today\'s limit and move the word\'s next review date; a correct answer today does not shorten an interval already earned. Changing the plan re-plans the queue and keeps every recorded answer.';

  @override
  String get continueSprint => 'Continue Exam Prep';

  @override
  String get startSprint => 'Start Exam Prep';

  @override
  String get endSprint => 'End Exam Prep';

  @override
  String get sprintEnable => 'Turn On Exam Prep';

  @override
  String examDateLabel(String date) {
    return 'Exam date: $date';
  }

  @override
  String get chooseDate => 'Choose';

  @override
  String get roundSizeShort => 'Words per Round';

  @override
  String get roundSizeRange => 'Words per Round (1–500)';

  @override
  String get prioritizeHard => 'Prioritise Difficult Words';

  @override
  String get prioritizeRecent => 'Prioritise Recent Mistakes';

  @override
  String get prioritizeUnmastered => 'Prioritise Unmastered Words';

  @override
  String get includeUnlearned => 'Include Unstudied Words';

  @override
  String get allowOverReviewLimit => 'Allow Extra Reviews';

  @override
  String get sprintDialogNote =>
      'Exam prep is a separate practice. With extra reviews off it respects today\'s limit. Changing the plan re-plans the queue and keeps your answers.';

  @override
  String get sprintVersionUnsupported =>
      'This plan was made by a newer version. Update the app.';

  @override
  String get sprintInvalidSwitch => 'This plan isn\'t valid. Set it up again.';

  @override
  String get sprintInvalidDate => 'That exam date isn\'t valid.';

  @override
  String get sprintInvalidBook => 'That word list isn\'t valid.';

  @override
  String get sprintInvalidRoundSize =>
      'Words per round must be between 1 and 500.';

  @override
  String get sprintIncomplete => 'Choose an exam date and a word list.';

  @override
  String get newWordList => 'New Word List';

  @override
  String get wordListName => 'Word List Name';

  @override
  String get refreshOnlineList => 'Refresh Online List';

  @override
  String sourceUrlLabel(String url) {
    return 'Source: $url';
  }

  @override
  String onlineListTotal(int count) {
    return 'The online list has $count words.';
  }

  @override
  String refreshExisting(int count) {
    return 'Already on this device: $count';
  }

  @override
  String refreshToAdd(int count) {
    return 'To add: $count';
  }

  @override
  String refreshDuplicate(int count) {
    return 'Duplicates in the file: $count';
  }

  @override
  String refreshInvalid(int count) {
    return 'Invalid entries: $count';
  }

  @override
  String refreshDropped(int count) {
    return 'Lines skipped: $count';
  }

  @override
  String refreshDeletedByUser(int count) {
    return 'Deleted by you, not restored: $count';
  }

  @override
  String refreshLocalOnly(int count) {
    return 'Removed from the source, kept here: $count';
  }

  @override
  String get refreshNote =>
      'Only missing words are added. Nothing on this device is deleted, restored, overwritten or reset. Canceling changes nothing.';

  @override
  String get confirmRefresh => 'Refresh';

  @override
  String refreshDone(int added, int updated, int existing) {
    return 'Refresh complete. Added $added, updated $updated, already present $existing.';
  }

  @override
  String get refreshCancelled => 'Refresh canceled. Nothing changed.';

  @override
  String get refreshFailed => 'Couldn\'t refresh this word list. Try again.';

  @override
  String get nothingToExport => 'No word lists to export.';

  @override
  String get exportListTitle => 'Export Word List';

  @override
  String wordCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
      zero: 'No words',
    );
    return '$_temp0';
  }

  @override
  String get exportContentNote =>
      'Exports a learning ZIP with selected lists, study events and progress. Device preferences and credentials are excluded.';

  @override
  String exportSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Word Lists',
      one: '1 Word List',
    );
    return 'Export $_temp0';
  }

  @override
  String get chooseFormat => 'Choose Format';

  @override
  String get exportCancelled => 'Export canceled.';

  @override
  String exportDone(int books, int words) {
    return 'Exported $books word lists · $words words (no study history).';
  }

  @override
  String get exportFailed => 'Couldn\'t export. Try again.';

  @override
  String get myWordLists => 'My Word Lists';

  @override
  String get wordListsLoadFailed => 'Couldn\'t load word lists. Try again.';

  @override
  String get noWordLists => 'No word lists yet';

  @override
  String get noWordListsMessage =>
      'Create a word list, then import your words — one per line.';

  @override
  String get renameWordList => 'Rename Word List';

  @override
  String get deleteWordListTitle => 'Delete Word List?';

  @override
  String deleteWordListBody(String name) {
    return '“$name” will be deleted. Words and study history are kept.';
  }

  @override
  String get allWordsNote =>
      'All Words filters by list, progress and difficulty, and can add, remove or delete in bulk.';

  @override
  String get currentTag => 'Current';

  @override
  String get setForStudy => 'Use for Study';

  @override
  String get commonRename => 'Rename';

  @override
  String get importIntoList => 'Import into This List';

  @override
  String wordListRowStats(int count, int learned, int due) {
    return '$count words · $learned studied · $due due';
  }

  @override
  String get protectiveBackupFailed =>
      'Couldn\'t create the safety backup, so nothing was changed.';

  @override
  String exportDoneSingle(int count) {
    return 'Exported $count words (no study history).';
  }

  @override
  String get searchWordsHint => 'Search words, meanings or notes';

  @override
  String get wordListLoadFailed => 'Couldn\'t load this word list. Try again.';

  @override
  String get wordListEmpty => 'This word list is empty';

  @override
  String get noMatchingWords => 'No matching words';

  @override
  String get wordListEmptyMessage => 'Add or import words to start studying.';

  @override
  String get operationFailedNothingChanged =>
      'The action failed. Nothing was changed. Try again.';

  @override
  String get selectionFailed => 'Couldn\'t select these words. Try again.';

  @override
  String updatedWordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count words',
      one: 'Updated 1 word',
    );
    return '$_temp0';
  }

  @override
  String get markMasteredTitle => 'Mark as Mastered?';

  @override
  String get unmarkMasteredTitle => 'Unmark as Mastered?';

  @override
  String get unmarkMasteredBody =>
      'Clears the manual mark. Progress returns to what the recorded answers say, without adding answers.';

  @override
  String markMasteredBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return 'Marks $_temp0 as mastered and schedules a review in 30 days. Study history is kept; it doesn\'t count as an answer.';
  }

  @override
  String get markMasteredBodyOne =>
      'Marks this word as mastered and schedules a review in 30 days. Study history is kept; it doesn\'t count as an answer or affect accuracy.';

  @override
  String unmarkMasteredDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Unmarked $count words',
      one: 'Unmarked 1 word',
    );
    return '$_temp0';
  }

  @override
  String markMasteredDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Marked $count words as mastered',
      one: 'Marked 1 word as mastered',
    );
    return '$_temp0';
  }

  @override
  String get resetProgressTitle => 'Reset Progress?';

  @override
  String resetProgressBodyBulk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return 'Clears the learning state of $_temp0: answers, interval and next review date. The words and their answer history are kept.';
  }

  @override
  String get resetProgressBodyOne =>
      'Clears this word\'s learning state: answers, interval and next review date. The word and its answer history are kept.';

  @override
  String get reset => 'Reset';

  @override
  String resetDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reset $count words',
      one: 'Reset 1 word',
    );
    return '$_temp0';
  }

  @override
  String get addListFirst => 'Add a word list first.';

  @override
  String get addToWordList => 'Add to Word List';

  @override
  String addedToWordList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count words',
      one: 'Added 1 word',
    );
    return '$_temp0';
  }

  @override
  String get chooseListFirst => 'Choose a word list above first.';

  @override
  String get removeFromWordList => 'Remove from Word List';

  @override
  String removeFromListBody(int count, String book) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return 'Remove $_temp0 from “$book”? Links to other word lists and study progress are unaffected.';
  }

  @override
  String removedFromWordList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count words from the list',
      one: 'Removed 1 word from the list',
    );
    return '$_temp0';
  }

  @override
  String get deleteWordsTitle => 'Delete Words?';

  @override
  String deleteWordsBodyBulk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return 'Delete $_temp0 from every word list? Study history is kept. To take a word out of one list only, use Remove from Word List.';
  }

  @override
  String get deleteWordsBodyOne =>
      'Delete this word from every word list? Study history is kept. To take it out of one list only, use Remove from Word List.';

  @override
  String deletedWordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count words',
      one: 'Deleted 1 word',
    );
    return '$_temp0';
  }

  @override
  String get tagsManagement => 'Tags';

  @override
  String get noMatchingWordsGroup => 'No matching words';

  @override
  String get emptyFilterHint => 'Try another filter, or add words first.';

  @override
  String noMatchForQuery(String query) {
    return 'No words match “$query”.';
  }

  @override
  String get favoritesOnly => 'Favorites only';

  @override
  String get tags => 'Tags';

  @override
  String get allTags => 'All Tags';

  @override
  String get statusLabel => 'Progress';

  @override
  String get sortLabel => 'Sort';

  @override
  String selectAllResults(int count) {
    return 'Select all $count';
  }

  @override
  String get clearSelection => 'Clear';

  @override
  String selectLoaded(int count) {
    return 'Select $count';
  }

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get batchFavoritesAndTags => 'Favorites & Tags';

  @override
  String get favoriteSelected => 'Add to Favorites';

  @override
  String get unfavoriteSelected => 'Remove from Favorites';

  @override
  String get addTag => 'Add Tag';

  @override
  String get removeTag => 'Remove Tag';

  @override
  String get removeFromCurrentList => 'Remove from Word List';

  @override
  String get markMastered => 'Mark as Mastered';

  @override
  String get unmarkMastered => 'Unmark as Mastered';

  @override
  String get resetProgress => 'Reset Progress';

  @override
  String get loadMore => 'Load More';

  @override
  String errorRateChip(int percent) {
    return '$percent% wrong';
  }

  @override
  String get noChineseMeaningShort => 'No Chinese meaning';

  @override
  String get selectAWord => 'Select a word';

  @override
  String get selectAWordHint => 'Choose a word to see its history and actions.';

  @override
  String get wordDetailTitle => 'Word Details';

  @override
  String get wordNotFound => 'Word Not Found';

  @override
  String errorRateLabel(String value) {
    return 'Error rate $value';
  }

  @override
  String answersTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count answers',
      one: '1 answer',
    );
    return '$_temp0';
  }

  @override
  String inWordLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count word lists',
      one: '1 word list',
    );
    return 'In $_temp0';
  }

  @override
  String get nextReviewNone => 'Next review: none';

  @override
  String nextReviewAt(String date, String relative) {
    return 'Next review: $date ($relative)';
  }

  @override
  String answerHistory(int count) {
    return 'Answer History (last $count)';
  }

  @override
  String get noAnswerHistory => 'No answers recorded yet.';

  @override
  String get eventNewStudy => 'New';

  @override
  String get eventReview => 'Review';

  @override
  String get eventReset => 'Reset';

  @override
  String get eventManual => 'Manual';

  @override
  String get eventSpecial => 'Targeted';

  @override
  String get unmarkMasteredBodyOne =>
      'Returns the word to learning and schedules a near review. History is kept; no answer is added.';

  @override
  String navAllWordsWithCount(int count) {
    return 'All Words ($count)';
  }

  @override
  String get noRecord => 'none';

  @override
  String get wordManagementDeleteWord => 'Delete Word';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeAgo(String value) {
    return '$value ago';
  }

  @override
  String timeIn(String value) {
    return 'in $value';
  }

  @override
  String timeValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String timeHoursValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String timeDaysValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String timeMonthsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String timeYearsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String get saved => 'Saved';

  @override
  String get wordNotInDictionary => 'The dictionary doesn\'t have this word.';

  @override
  String get filledFromDictionary =>
      'Blank fields were filled from the dictionary. Save to keep them.';

  @override
  String get wordEntry => 'Word';

  @override
  String removeFromListBodyWord(String word) {
    return 'Remove “$word” from this word list? The word, its other word lists and study progress are kept.';
  }

  @override
  String deleteWordBodyName(String word) {
    return 'Delete “$word” from every word list? Study history is kept. To remove it from one list only, use Remove from Word List.';
  }

  @override
  String get fillFromDictionary => 'Fill from Dictionary';

  @override
  String get wordInfo => 'Word Info';

  @override
  String get wordField => 'Word';

  @override
  String get phonetics => 'Phonetics';

  @override
  String get partOfSpeech => 'Part of Speech';

  @override
  String get chineseMeaning => 'Chinese Meaning';

  @override
  String get savedAsCustom =>
      'Once saved, this word is marked as edited, and dictionary updates won\'t overwrite what you typed.';

  @override
  String get saving => 'Saving…';

  @override
  String get learningProgress => 'Learning Progress';

  @override
  String get editedTag => 'Edited';

  @override
  String sourceLabel(String source) {
    return 'Source: $source';
  }

  @override
  String get sourceManual => 'Added by hand';

  @override
  String get sourceImport => 'Imported';

  @override
  String get sourceUrl => 'Online list';

  @override
  String get sourceSample => 'Sample list';

  @override
  String get sourceDictionary => 'Dictionary';

  @override
  String get sourceFile => 'Imported';

  @override
  String get sourceOther => 'Other';

  @override
  String intervalDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get intervalLabel => 'Interval';

  @override
  String get statsOverview => 'Overview';

  @override
  String get totalWordsLabel => 'Total Words';

  @override
  String get learnedLabel => 'Studied';

  @override
  String get unlearnedLabel => 'Not Studied';

  @override
  String get accuracyLabel => 'Accuracy';

  @override
  String get overallAccuracy => 'Overall Accuracy';

  @override
  String get todayStudy => 'Today';

  @override
  String get todayNewWords => 'New Words';

  @override
  String get todayReviews => 'Reviews';

  @override
  String get cumulativeCorrect => 'Correct';

  @override
  String get cumulativeWrong => 'Wrong';

  @override
  String get cumulativeHazy => 'Not Sure';

  @override
  String get distinctAnsweredWords => 'Words Answered';

  @override
  String get answerBreakdown => 'Answer Breakdown';

  @override
  String get breakdownStudyReview => 'Study & Review';

  @override
  String get breakdownSpecial => 'Targeted Review';

  @override
  String get breakdownPractice => 'Practice';

  @override
  String get breakdownRepeat => 'Repeat Practice';

  @override
  String get distinctWordsAnswered => 'Distinct Words';

  @override
  String get undoneAnswers => 'Undone';

  @override
  String get breakdownNote =>
      'Practice counts as answers but doesn\'t affect your review plan. Marking as mastered or resetting progress doesn\'t count.';

  @override
  String get answersLast7Days => 'Answers in the Last 7 Days';

  @override
  String get reviewsNext7Days => 'Reviews in the Next 7 Days';

  @override
  String get noScheduledReviews => 'No reviews scheduled.';

  @override
  String get wordListProgress => 'Word List Progress';

  @override
  String get wordPerformance => 'Performance';

  @override
  String get lastStudiedDay => 'Last Studied';

  @override
  String get accuracyFormula =>
      'Accuracy = Know answers ÷ all answers, counted across every session and device.';

  @override
  String get noAnswersYet =>
      'No answers yet. Finish one study session to see real numbers.';

  @override
  String wordErrorHazyStat(int wrong, int hazy) {
    return '$wrong wrong · $hazy unsure';
  }

  @override
  String get noAnswersLast7Days => 'No answers in the last 7 days.';

  @override
  String get aboutStatistics => 'About Statistics';

  @override
  String get aboutStatisticsBody =>
      'Overview counts every word in the current scope. Today covers this device\'s answers since midnight; the overview is cumulative. Answers are compared across all sessions and devices, and undone answers are listed separately rather than removed from history.';

  @override
  String valueTimes(int count) {
    return '$count';
  }

  @override
  String get statsLoadFailed => 'Couldn\'t load statistics.';

  @override
  String get searchWordHint => 'Search words (⌘F)';

  @override
  String get searchWordHintPlain => 'Search words';

  @override
  String get recentSearch => 'Recent';

  @override
  String get offlineDictionary => 'Offline Dictionary';

  @override
  String dictionaryEmptyBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Search $countString English words and add them straight to a word list.';
  }

  @override
  String get relatedWords => 'Related Words';

  @override
  String wordFormHint(String word) {
    return 'Past tense or past participle of $word';
  }

  @override
  String get relationPastParticiple => 'past tense or past participle';

  @override
  String get relationPlural => 'plural or third-person form';

  @override
  String get relationPresentParticiple => 'present participle or gerund';

  @override
  String get relationComparative => 'comparative';

  @override
  String get relationSuperlative => 'superlative';

  @override
  String myWordsCount(int count) {
    return 'My Words ($count)';
  }

  @override
  String dictionaryResultsCount(int count) {
    return 'Results ($count)';
  }

  @override
  String get noDictionaryMatch =>
      'The dictionary doesn\'t have this word. You can add it by hand and fill in the meaning later.';

  @override
  String addTermAsWord(String term) {
    return 'Add “$term”';
  }

  @override
  String get dictionaryHint =>
      'Use + to add a word to the current list. Existing words keep their progress and notes.';

  @override
  String get dictionarySearchFailed => 'Couldn\'t search the dictionary.';

  @override
  String get addFailed => 'Couldn\'t add. Try again.';

  @override
  String get tagCreateFirst => 'Create a tag in Tags first.';

  @override
  String get chooseTag => 'Choose Tag';

  @override
  String get unfavoriteWord => 'Remove from Favorites';

  @override
  String get favoriteWord => 'Add to Favorites';

  @override
  String get favoriteFailed => 'Couldn\'t update favorites. Try again.';

  @override
  String get tagOperationFailed => 'Couldn\'t update tags. Try again.';

  @override
  String removeTagNamed(String name) {
    return 'Remove tag $name';
  }

  @override
  String get manageTags => 'Manage Tags';

  @override
  String get createTag => 'Create Tag';

  @override
  String get renameTag => 'Rename Tag';

  @override
  String get tagName => 'Tag Name';

  @override
  String get deleteTag => 'Delete Tag';

  @override
  String deleteTagBody(String name) {
    return 'Delete “$name” and its word links? Words, favorites and study history are kept.';
  }

  @override
  String get tagsLoadFailed => 'Couldn\'t load tags. Open this page again.';

  @override
  String get noTagsYet => 'No tags yet';

  @override
  String tagDeleteAction(String name) {
    return 'Delete tag $name';
  }

  @override
  String intakeAdded(String word) {
    return 'Added “$word”.';
  }

  @override
  String intakeRevivedLinked(String word) {
    return 'Restored “$word” and added it to the list. Study history was kept.';
  }

  @override
  String intakeRevived(String word) {
    return 'Restored “$word”. Study history was kept.';
  }

  @override
  String intakeUnchanged(String word) {
    return '“$word” is unchanged.';
  }

  @override
  String intakeUpdated(int count, String word) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields',
      one: '1 field',
    );
    return 'Updated $_temp0 of “$word”.';
  }

  @override
  String intakeAlreadyInList(String word) {
    return '“$word” is already in this list.';
  }

  @override
  String intakeExists(String word) {
    return '“$word” already exists and is unchanged.';
  }

  @override
  String intakeDeletedSkipped(String word) {
    return '“$word” was deleted and wasn\'t restored.';
  }

  @override
  String get dictNotFoundManual => 'No meaning found. You can add one by hand.';

  @override
  String get dictFilled => 'Filled from the dictionary.';

  @override
  String get dictLookupFailed =>
      'Couldn\'t query the dictionary. You can type the meaning yourself.';

  @override
  String get enterEnglishWord => 'Enter an English word.';

  @override
  String get listDeleted => 'That word list was deleted.';

  @override
  String get pasteWordsPerLine => 'Paste words, one per line.';

  @override
  String get addMultiple => 'Add Multiple Words';

  @override
  String get parseFailed => 'Couldn\'t read this. Check the format.';

  @override
  String get batchAddFailed => 'Couldn\'t add these words. Try again.';

  @override
  String get addOneWord => 'Add One Word';

  @override
  String get englishWord => 'English Word';

  @override
  String get typeToLookUp => 'Type a word to look it up';

  @override
  String get optional => 'Optional';

  @override
  String get dictMissingNote =>
      'You can save even if the dictionary doesn\'t have it, and fill in the meaning later.';

  @override
  String get preview => 'Preview';

  @override
  String get importing => 'Adding…';

  @override
  String get saveAndContinueShortcut => 'Save and Continue (⌘Enter)';

  @override
  String get saveAndContinue => 'Save and Continue';

  @override
  String get quickAddNote =>
      'Uses the last chosen word list. Existing words keep their meaning, notes and progress; only what you change is overwritten.';

  @override
  String get batchWordsPerLine => 'One word per line';

  @override
  String foundWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count words',
      one: 'Found 1 word',
    );
    return '$_temp0';
  }

  @override
  String batchDuplicates(int count) {
    return '$count duplicates merged';
  }

  @override
  String batchInvalidLines(int count) {
    return '$count lines ignored';
  }

  @override
  String batchDefinitionStats(int withMeaning, int withoutMeaning) {
    return '$withMeaning have a meaning or can be filled from the dictionary; $withoutMeaning need one.';
  }

  @override
  String get batchKeepsProgress => 'Existing progress is kept.';

  @override
  String moreTotal(int count) {
    return '…$count in total';
  }

  @override
  String get targetList => 'Word List';

  @override
  String get wordEmpty => 'Enter a word.';

  @override
  String get wordTooLong => 'That word is too long (64 characters at most).';

  @override
  String get chooseWordListFile => 'Choose a Word List File';

  @override
  String get cannotReadFile =>
      'Couldn\'t read this file. Only local files are supported.';

  @override
  String get downloadParseFailed =>
      'Couldn\'t download or read this link. Check the file.';

  @override
  String get downloadCancelled => 'Download canceled. Nothing was written.';

  @override
  String get chooseTargetList => 'Choose a word list first.';

  @override
  String get importFailedUnchanged => 'Import failed. Nothing was changed.';

  @override
  String get importWordListTitle => 'Import Word List';

  @override
  String get stepChooseSource => '1. Source';

  @override
  String get chooseFile => 'Choose File';

  @override
  String get formatHelp => 'Format';

  @override
  String get downloadLink => 'Word list link (TXT / CSV / JSON / ZIP)';

  @override
  String get download => 'Download';

  @override
  String get cancelDownload => 'Cancel Download';

  @override
  String get stepPreview => '2. Preview';

  @override
  String get statImportable => 'Importable';

  @override
  String get statNewWords => 'New';

  @override
  String get statExistingWords => 'Existing';

  @override
  String get statRestorable => 'Restorable';

  @override
  String get statWillLink => 'Will be added';

  @override
  String get statDuplicates => 'Duplicates';

  @override
  String get statInvalid => 'Invalid';

  @override
  String get statFormat => 'Format';

  @override
  String get statLists => 'Word Lists';

  @override
  String fileRowsSummary(int total, int skipped) {
    return '$total lines. $skipped won\'t be imported (see below).';
  }

  @override
  String restorableNote(int count) {
    return '$count of them were deleted by you. An explicit import restores them and keeps their history; refreshing an online list does not.';
  }

  @override
  String issuesHeader(int count) {
    return 'First $count issues:';
  }

  @override
  String get stepTargetList => '3. Word List';

  @override
  String get addToExistingList => 'Add to an Existing Word List';

  @override
  String get chooseWordList => 'Choose a word list';

  @override
  String get importMergeNote =>
      'Existing words are not created twice and their progress is kept. Only missing details are filled in, and the word is linked to the chosen list.';

  @override
  String startImportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Words',
      one: '1 Word',
    );
    return 'Import $_temp0';
  }

  @override
  String get importComplete => 'Import Complete';

  @override
  String get noFileChosen => 'No file chosen';

  @override
  String get formatSummary =>
      'TXT: one word per line. CSV: a word column. JSON: one or more word lists. Learning ZIP packages can include progress.';

  @override
  String get supportedFormats => 'Supported Formats';

  @override
  String get importResultAdded => 'Added';

  @override
  String get importResultExisting => 'Already present';

  @override
  String get importResultUpdated => 'Updated';

  @override
  String get importResultRestored => 'Restored';

  @override
  String get importResultDuplicate => 'Duplicates';

  @override
  String get importResultSkipped => 'Not imported';

  @override
  String get formatHelpTxt =>
      'TXT\nOne word per line. An optional meaning can follow a tab or a comma:\n  abandon\n  abandon\tv. to give up';

  @override
  String get formatHelpCsv =>
      'CSV\nOne header row, and a word column is required. phonetic / pos / translation / definition / example / note are optional.';

  @override
  String get formatHelpJson =>
      'JSON\nSupports one list with words, multiple lists with books, and legacy bare arrays. Entries require word; meaning, phonetics, part of speech, examples, phrases, tags and notes are optional.';

  @override
  String formatHelpFooter(int entries, int megabytes) {
    final intl.NumberFormat entriesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String entriesString = entriesNumberFormat.format(entries);

    return 'Files must be UTF-8. One import is limited to $entriesString words and $megabytes MB; download links must be HTTPS. Missing phonetics and meanings are filled in from the offline dictionary, and existing progress and notes are never overwritten.';
  }

  @override
  String get saveDiagnostics => 'Save Diagnostics';

  @override
  String get diagnosticsExported =>
      'Diagnostics exported (no account or study content).';

  @override
  String get diagnosticsExportFailed => 'Couldn\'t export diagnostics.';

  @override
  String get logsSection => 'Logs';

  @override
  String get detailedLogging => 'Detailed Logs';

  @override
  String get detailedLoggingHint =>
      'Off by default. When on, keeps the last 400 entries for 24 hours, with sensitive values removed.';

  @override
  String get exportDiagnosticsReport => 'Export Diagnostics';

  @override
  String get exportDiagnosticsHint =>
      'Version, database and dictionary statistics, sync status. No account or study content.';

  @override
  String get clearLogs => 'Clear Logs';

  @override
  String get noLogs => 'Nothing recorded yet';

  @override
  String logCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get logsCleared => 'Logs cleared.';

  @override
  String get deviceSection => 'Device';

  @override
  String get deviceIdLabel => 'Device ID';

  @override
  String get reading => 'Reading…';

  @override
  String get deviceIdCopied =>
      'Device ID copied (used only to investigate sync problems).';

  @override
  String get diagnosticsPrivacy =>
      'Diagnostics never include passwords, credentials, word content or personal notes. The sync configuration records only the sync method, not the address, account or path.';

  @override
  String get chooseRemoteFolder => 'Choose Remote Folder';

  @override
  String get cannotReadFolder => 'Couldn\'t read this folder.';

  @override
  String get newFolder => 'New Folder';

  @override
  String get folderName => 'Folder Name';

  @override
  String get create => 'Create';

  @override
  String serverLabel(String url) {
    return 'Server: $url';
  }

  @override
  String get chooseThisFolder => 'Choose This Folder';

  @override
  String get parentFolder => 'Up One Level';

  @override
  String get noSubfolders =>
      'No subfolders here. You can choose this folder or create one.';

  @override
  String get syncOff => 'Off';

  @override
  String get syncOffHint => 'Study data stays on this device.';

  @override
  String get localFile => 'Local File';

  @override
  String get localFileHint => 'Transfers data through a JSON file.';

  @override
  String get githubPrivateRepo => 'GitHub';

  @override
  String get githubHint => 'Keeps study data in a private repository.';

  @override
  String get webdavHint => 'Syncs through a compatible WebDAV service.';

  @override
  String get s3Hint =>
      'Syncs to an S3-compatible bucket (AWS S3, Cloudflare R2).';

  @override
  String credentialsUnreadable(String reason) {
    return '$reason. The saved credentials can\'t be read; enter them again. Offline study is unaffected.';
  }

  @override
  String get tokenMissing =>
      'No saved access token was found. Enter it again before syncing.';

  @override
  String get passwordMissing =>
      'No saved WebDAV password was found. Enter it again before syncing.';

  @override
  String get draftNotSaved =>
      'The connection settings aren\'t saved yet. Auto options are saved and verified when you tap Sync Now.';

  @override
  String get configChanged =>
      'The connection settings changed. Open this page again.';

  @override
  String get preferencesSaved =>
      'Preferences saved. Automatic sync starts only after Test Connection verifies safe writes.';

  @override
  String get preferencesSaveFailed =>
      'Couldn\'t save the auto-sync options. Try again.';

  @override
  String credentialsNotSaved(String reason) {
    return '$reason. The credentials were not saved; enter them again. Offline study is unaffected.';
  }

  @override
  String get connectionTestFailed => 'Couldn\'t test this connection.';

  @override
  String remoteFolderChosen(String path) {
    return 'Remote folder selected: $path';
  }

  @override
  String get cannotBrowseRemote => 'Couldn\'t browse the remote folder.';

  @override
  String get syncInProgress => 'A sync is already running.';

  @override
  String get firstSyncTitle => 'First Sync';

  @override
  String get firstSyncBody =>
      'The first sync merges the remote data with this device. It won\'t overwrite local progress and won\'t delete local words.\n\nContinue?';

  @override
  String get startMerging => 'Merge';

  @override
  String get unsafeServerBody =>
      'MaterialWord paused syncing because this check could not confirm that two devices can update the same file without overwriting each other. You can test the connection again or export a backup.';

  @override
  String get retestConnection => 'Test Again';

  @override
  String get exportBackup => 'Export Backup';

  @override
  String get syncFailed => 'Sync failed.';

  @override
  String get remoteBecameEmpty => 'Remote file became empty';

  @override
  String get remoteIsEmpty => 'Remote file is empty';

  @override
  String get remoteEmptiedBody =>
      'This target synced successfully before, but the remote file is now 0 bytes.\n\nContinuing re-initialises it with this device\'s data, replacing what was there.';

  @override
  String get remoteEmptiedConfirm =>
      'Continue only if the remote data is no longer needed.';

  @override
  String get emptyInitBody =>
      'The remote sync file is empty.\n\nInitialise it with this device\'s data? The current version is recorded, so if another device writes meanwhile this initialisation is rejected instead of overwriting it.';

  @override
  String get initialiseAndSync => 'Initialise and Sync';

  @override
  String get mergeRemoteTitle => 'Merge Remote Data?';

  @override
  String get mergeRemoteBody =>
      'This resumes sync and merges the other device\'s data into this one, adding only what is missing. The merged result is then uploaded, so the remote copy will contain the restored data from this device.';

  @override
  String get noTargetConfigured => 'No sync target configured';

  @override
  String get syncStaysPausedRemoteUntouched =>
      'Sync stays paused. The remote data was not changed.';

  @override
  String get recreateRemoteTitle => 'Re-upload Remote Data?';

  @override
  String get recreateRemoteBody =>
      'The remote data file no longer exists, perhaps because the repository file was deleted or the path changed.\n\nContinuing uploads this device\'s current data there. If you did not intend to remove the remote data, cancel and check the repository and settings.';

  @override
  String get reupload => 'Re-upload';

  @override
  String get restoreConflictTitle => 'Restore the Overwritten Value?';

  @override
  String restoreConflictBody(String label, String field) {
    return '$label · $field will be changed back to the other value. This is synced to other devices as a new edit.';
  }

  @override
  String restoredField(String field) {
    return 'Restored $field';
  }

  @override
  String get restoredAsNewEdit => '(synced as a new edit)';

  @override
  String get restoreFailedKept =>
      'Couldn\'t restore. The conflict record was kept.';

  @override
  String get fieldWord => 'Word';

  @override
  String get fieldPhonetic => 'Phonetics';

  @override
  String get fieldPos => 'Part of Speech';

  @override
  String get fieldTranslation => 'Meaning';

  @override
  String get fieldDefinition => 'English Definition';

  @override
  String get fieldExample => 'Example';

  @override
  String get fieldPhrase => 'Phrases';

  @override
  String get fieldNote => 'Notes';

  @override
  String get fieldSource => 'Source';

  @override
  String get fieldExamTags => 'Exam Tags';

  @override
  String get fieldBnc => 'BNC Rank';

  @override
  String get fieldCoca => 'COCA Rank';

  @override
  String get fieldDeleted => 'Deleted';

  @override
  String get fieldBookName => 'Word List Name';

  @override
  String get fieldBookDescription => 'Word List Description';

  @override
  String get fieldBookSourceType => 'Word List Source Type';

  @override
  String get fieldBookSourceUrl => 'Word List Source Link';

  @override
  String get notDeleted => 'Not deleted';

  @override
  String get deleted => 'Deleted';

  @override
  String get emptyValue => '(empty)';

  @override
  String get backupExported => 'Backup exported.';

  @override
  String get exportPickFailed => 'Couldn\'t export. Choose another location.';

  @override
  String get turnOffSync => 'Turn Off Sync';

  @override
  String get turnOffSyncBody =>
      'The sync settings and credentials (token / password) stored on this device are deleted. Remote data is not deleted, and study records stay on this device.';

  @override
  String get syncTurnedOff => 'Sync turned off.';

  @override
  String get retestAfterSwitch =>
      'Test the connection again after switching sync method.';

  @override
  String get remoteFileMissingNotice =>
      'The remote data file no longer exists.';

  @override
  String get syncPausedTitle => 'Sync Paused';

  @override
  String get syncPausedRestoreBody =>
      'This data came from a restore. Automatic sync stays off until you decide what to do with the remote data.';

  @override
  String get mergeRemote => 'Merge Remote Data';

  @override
  String get keepLocal => 'Keep This Device';

  @override
  String get mergeOnlyAdds =>
      'Neither side overwrites the other: a merge only adds what is missing.';

  @override
  String get syncMethod => 'Sync Method';

  @override
  String get connectionSettings => 'Connection Settings';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncing => 'Syncing…';

  @override
  String get syncOnStart => 'Sync on Launch';

  @override
  String get syncOnStartHint => 'The app always shows local data first.';

  @override
  String get syncOnResume => 'Sync on Return';

  @override
  String get syncOnResumeHint =>
      'Checks for changes when you come back; retries later on failure.';

  @override
  String get syncOnChange => 'Sync After Changes';

  @override
  String get syncOnChangeHint =>
      'Runs about 20 seconds after you stop, not after every answer.';

  @override
  String get syncOnSessionEnd => 'Sync When a Session Ends';

  @override
  String get syncOnSessionEndHint =>
      'Runs after a session ends, without changing the flow.';

  @override
  String get localFileManualOnly =>
      'A local file is for manual merging only. For automatic sync, choose GitHub or WebDAV.';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get autoSyncNotEnabled =>
      'Automatic sync is paused until Test Connection verifies safe writes.';

  @override
  String autoSyncNotEnabledReason(String reason) {
    return 'Automatic sync is paused. $reason.';
  }

  @override
  String get syncConflicts => 'Sync Conflicts';

  @override
  String keptValue(String value) {
    return 'Kept: $value';
  }

  @override
  String discardedValue(String value) {
    return 'Overwritten: $value';
  }

  @override
  String get restoreOverwritten => 'Restore';

  @override
  String get diagnosticOnly => 'Diagnostic only, can\'t be restored';

  @override
  String get ignoreRecord => 'Ignore';

  @override
  String get conflictExplain =>
      'Another device changed the same item. MaterialWord kept the newer value and stored the other one here. Restoring changes it back and syncs that as a new edit; entries without a restore action are for diagnostics only.';

  @override
  String get syncStatus => 'Sync Status';

  @override
  String get lastSynced => 'Last Synced';

  @override
  String get neverSynced => 'Never Synced';

  @override
  String get syncResult => 'Sync Result';

  @override
  String get pendingChanges => 'Pending Changes';

  @override
  String get hasLocalChanges => 'Local changes are not uploaded yet.';

  @override
  String get inSyncWithLast => 'This device matches the last sync.';

  @override
  String get recreateRemoteAction => 'Re-upload Remote Data…';

  @override
  String get syncDiagnostics => 'Sync Diagnostics';

  @override
  String get syncDiagnosticsHint =>
      'View and export recent sync requests (no passwords or study content).';

  @override
  String get aboutSync => 'About Syncing';

  @override
  String get aboutSyncBody =>
      'Remote and local data are merged, never overwritten:\n· one record per word;\n· every answer is kept and progress is recomputed after merging;\n· deleted words and word lists stay deleted;\n· when two devices change the same item, the newer value is kept and the other copy stays under Sync Conflicts.\nTokens and passwords are kept only in the system secure storage (Keychain / Keystore), never in the database, a backup or a log.';

  @override
  String get connectionNotVerified => 'Connection Not Verified';

  @override
  String get connectionNotVerifiedHint =>
      'Enter the address and account, then run Test Connection. Safe writes must be verified before syncing.';

  @override
  String get technicalDetails => 'Technical Details';

  @override
  String get noteLabel => 'Note:';

  @override
  String get syncFilePath => 'Sync File Path';

  @override
  String get mobileFolderLimit =>
      'Phones can\'t keep access to an arbitrary folder. Use the app\'s own file, or export / import from Backup & Restore.';

  @override
  String get githubOwner => 'GitHub User or Organization';

  @override
  String get repoName => 'Repository Name';

  @override
  String get branch => 'Branch';

  @override
  String get dataFilePath => 'File Path';

  @override
  String get accessToken => 'Access Token';

  @override
  String get accessTokenHint =>
      'Used to access your private repository; kept only in this device\'s secure storage.';

  @override
  String get privateRepoNote =>
      'Use a dedicated private repository for study data. Never use a public one.';

  @override
  String get serverAddress => 'Server Address (HTTPS)';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get appPassword => 'Password or App Password';

  @override
  String get leaveBlankToKeep => 'Leave blank to keep the saved value';

  @override
  String get remoteFolder => 'Folder';

  @override
  String get remoteFolderHint =>
      'Leave blank to use the server address itself. Browse with the button above rather than copying a name from a sync client.';

  @override
  String get fileName => 'File Name';

  @override
  String get httpsOnly => 'HTTPS only; certificate checks are never disabled.';

  @override
  String get etagNote =>
      'Sync protects edits from multiple devices with conditional writes or separate snapshots. Automatic sync requires a verified connection.';

  @override
  String get serverNoConditionalWrite =>
      'This server did not pass the safe-write check.';

  @override
  String get credentialsUnavailable =>
      'The saved sync credentials can\'t be read. Enter them again. Offline study is unaffected.';

  @override
  String get credentialsNotStored =>
      'The credentials were not saved. Enter them again. Offline study is unaffected.';

  @override
  String get serverRootFolder => 'server root';

  @override
  String get mergeOnlyAddsShort => 'Merge';

  @override
  String get backupAndRestore => 'Backup & Restore';

  @override
  String get exportBackupDone => 'Backup exported.';

  @override
  String get exportCanceled => 'Export canceled.';

  @override
  String get mergeBackup => 'Merge Backup';

  @override
  String get mergeToDevice =>
      'Merges into this device and keeps the existing history; nothing on this device is deleted.';

  @override
  String get merge => 'Merge';

  @override
  String get checkBackup => 'Check Backup';

  @override
  String get backupInfo => 'Backup Info';

  @override
  String schemaVersionLine(int version) {
    return 'Format: v$version';
  }

  @override
  String createdAtLine(String time) {
    return 'Created: $time';
  }

  @override
  String appVersionLine(String version) {
    return 'App version: $version';
  }

  @override
  String hasDeviceSettingsLine(String value) {
    return 'Legacy device preferences: $value (ignored on restore)';
  }

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get integrityPassed =>
      'Integrity check passed: the file can be read safely.';

  @override
  String get integrityUnchecked =>
      'Integrity: unchecked (run Check to read and verify)';

  @override
  String get cannotReadBackup => 'Can\'t Read';

  @override
  String get close => 'Close';

  @override
  String backupUnreadable(String problem) {
    return 'This backup can\'t be read: $problem';
  }

  @override
  String get mergeRestore => 'Merge Backup';

  @override
  String get mergeRestoreBody =>
      'Adds only words and answers this device is missing. Existing data and progress are kept. This is the safe default.';

  @override
  String get mergeComplete => 'Merge complete.';

  @override
  String get restoreVersionTitle => 'Restore This Version?';

  @override
  String get restoreVersionBody =>
      'Study data on this device returns to the selected version. Changes made after that backup are removed from the current data.\n\nThe current data is backed up automatically first, and sync is paused.';

  @override
  String get restore => 'Restore';

  @override
  String restoredProtected(String file) {
    return 'Restored. The previous state was saved as $file.';
  }

  @override
  String get restoreNextStepTitle => 'Restored: What About the Remote Data?';

  @override
  String get restoreNextStepBody =>
      'This device now holds the selected version and sync is paused. Choose the next step:\n\n· Keep this device: don\'t sync yet; handle it later on the Sync page.\n· Merge remote data: bring the other device\'s data in (adds only).\n· Use a new target: point sync at a different remote location.';

  @override
  String get keepLocalState => 'Keep This Device';

  @override
  String get useNewTarget => 'Use a New Target';

  @override
  String get mergeRemoteData => 'Merge Remote Data';

  @override
  String get syncPausedRemoteUnchanged =>
      'Sync stays paused. The remote data was not changed.';

  @override
  String get noSyncTargetHint =>
      'No sync target configured. Set one on the Sync page.';

  @override
  String get remoteMerged => 'Remote data merged.';

  @override
  String get syncStillPausedUntilTarget =>
      'Sync stays paused until one sync completes with the new target.';

  @override
  String get deleteBackupTitle => 'Delete Backup?';

  @override
  String deleteBackupBody(String name) {
    return '$name\n\nOnly this local file is deleted. Study data in the database is not affected.';
  }

  @override
  String get backupDeleted => 'Backup deleted.';

  @override
  String get backupExportedShort => 'Backup exported.';

  @override
  String get syncPausedBanner => 'Sync Paused';

  @override
  String get syncPausedBannerBody =>
      'This data came from a restore and hasn\'t been checked against the remote copy. Automatic sync stays off until you confirm how to handle the remote data on the Sync page.';

  @override
  String get handleSync => 'Open Sync';

  @override
  String get autoBackupLocal => 'Automatic Backup (Local)';

  @override
  String get autoBackupDaily => 'Daily Automatic Backup';

  @override
  String autoBackupHint(int count) {
    return 'Checked at launch, on resume and while the app stays open. A new copy is written only when data changed, keeping the last $count.';
  }

  @override
  String get lastAutoBackup => 'Last Automatic Backup';

  @override
  String get noAutoBackupYet => 'No automatic backup yet';

  @override
  String get manualBackupJson => 'Manual Backup (JSON)';

  @override
  String get exportTo => 'Export Backup…';

  @override
  String get exportToHint =>
      'Saves shared learning data through the system file picker; device preferences stay on this device.';

  @override
  String get saveBackupNow => 'Save Backup Now';

  @override
  String get saveBackupNowHint =>
      'Saved on this device and restorable from the list below.';

  @override
  String get importAndMerge => 'Import and Merge';

  @override
  String get importAndMergeHint =>
      'Never overwrites local data: merges after de-duplicating words and answers.';

  @override
  String get backupContentsNote =>
      'A backup contains words, word lists, links (including delete marks), answer history, learning progress, favorites, tags and study goals. Device appearance, voice and screen preferences are excluded. It never contains accounts, passwords or sync credentials.';

  @override
  String get localBackups => 'Local Backups';

  @override
  String get noLocalBackups =>
      'No backups yet. An automatic backup or Save Backup Now will appear here.';

  @override
  String get backupActions => 'Backup Actions';

  @override
  String get viewInfo => 'View Info';

  @override
  String get checkIntegrity => 'Check Backup';

  @override
  String get mergeRestoreSafe => 'Merge Backup';

  @override
  String get restoreThisVersion => 'Restore This Version…';

  @override
  String get deleteBackup => 'Delete';

  @override
  String get restoreModesNote =>
      'Merging only adds what is missing, so it is idempotent and safe to repeat. Restoring a version replaces this device\'s data atomically, saves a safety backup first, and pauses sync until you decide how to handle the remote copy.';

  @override
  String get crossDeviceSync => 'Cross-device Sync';

  @override
  String get openSync => 'Open Sync';

  @override
  String get syncTargetsHint => 'GitHub / WebDAV / local file';

  @override
  String get mergeNeverOverwrites =>
      'A merge only adds missing content and never overwrites existing words or answers. Importing the same file twice does not double-count.';

  @override
  String get mergeRulesAdvanced => 'Merge Rules (Advanced)';

  @override
  String get mergeRulesBody =>
      'Answers are de-duplicated by global id and learning state is recalculated from the merged history. Word-list links carry versions and delete marks, so an old backup cannot revive a removed word.';

  @override
  String get syncUploadPending => 'Local data is saved. Upload is pending.';

  @override
  String get syncConflictRetry =>
      'Another device changed the data. Try syncing again.';

  @override
  String get syncFileUnreadable => 'Unable to read the sync file.';

  @override
  String backupInfoSummary(int words, int books, int entries, int events) {
    return '$words words · $books word lists · $entries links · $events answers';
  }

  @override
  String backupInfoTags(int count) {
    return '$count tags';
  }

  @override
  String backupInfoFavorites(int count) {
    return '$count favorites';
  }

  @override
  String backupInfoUnreadable(String reason) {
    return 'Unreadable: $reason';
  }

  @override
  String get unknownReason => 'unknown reason';

  @override
  String mergeSummaryEvents(int count) {
    return '$count new answers';
  }

  @override
  String mergeSummaryDuplicates(int count) {
    return '$count duplicates ignored';
  }

  @override
  String mergeSummaryNewWords(int count) {
    return '$count new words';
  }

  @override
  String mergeSummaryUpdatedWords(int count) {
    return '$count words updated';
  }

  @override
  String mergeSummaryDeletedWords(int count) {
    return '$count deletions applied';
  }

  @override
  String mergeSummaryNewBooks(int count) {
    return '$count new word lists';
  }

  @override
  String mergeSummaryNewEntries(int count) {
    return '$count links added';
  }

  @override
  String mergeSummaryRemovedEntries(int count) {
    return '$count links removed';
  }

  @override
  String mergeSummaryRebuiltStates(int count) {
    return '$count progress rows recalculated';
  }

  @override
  String mergeSummaryMetadata(int count) {
    return '$count favorite or tag changes';
  }

  @override
  String mergeSummaryConflicts(int count) {
    return '$count content conflicts (the newer value was kept)';
  }

  @override
  String restoreSummary(int words, int events) {
    return 'Restored $words words and $events answers. The previous state was saved as a safety backup.';
  }

  @override
  String importOutcomeCreated(int count) {
    return '$count added';
  }

  @override
  String importOutcomeRevived(int count) {
    return '$count restored';
  }

  @override
  String importOutcomeExisting(int count) {
    return '$count already present';
  }

  @override
  String importOutcomeUpdated(int count) {
    return '$count updated';
  }

  @override
  String importOutcomeLinked(int count) {
    return '$count linked to the word list';
  }

  @override
  String importOutcomeBooks(int count) {
    return 'across $count word lists';
  }

  @override
  String importOutcomeSkippedDeleted(int count) {
    return '$count deleted words skipped';
  }

  @override
  String importOutcomeDuplicates(int count) {
    return '$count duplicates in the file';
  }

  @override
  String importOutcomeInvalid(int count) {
    return '$count invalid lines ignored';
  }

  @override
  String get importOutcomeSeparator => ', ';

  @override
  String backupSavedAs(String name) {
    return 'Backup saved: $name';
  }

  @override
  String mergeConfirmBody(int words, int books, int events, String time) {
    return '$words words, $books word lists, $events answers.\nBackup time: $time\nMerges into this device, keeps the existing history and deletes nothing.';
  }

  @override
  String get timeNotRecorded => 'not recorded';

  @override
  String mergeRestoreConfirm(String summary) {
    return '$summary\n\nMerging only adds what this device is missing and keeps existing data and progress. This is the safe default.';
  }

  @override
  String mergeCompleteWith(String summary) {
    return 'Merge complete: $summary';
  }

  @override
  String restoreSnapshotConfirm(String summary, String created) {
    return '$summary\nCreated: $created\n\nThis replaces the current data on this device: answers, edits and deletions made after that backup are removed from it. A safety backup is written first, and a failure rolls everything back. Sync stays paused afterwards until you decide what to do with the remote data.';
  }

  @override
  String restoreDoneWith(String summary, String file) {
    return '$summary The previous state was saved as $file.';
  }

  @override
  String get createdUnknown => 'unknown';

  @override
  String autoBackupHintCount(int count) {
    return 'Checked at launch, on resume and while the app stays open. A new copy is written only when data changed, keeping the last $count.';
  }

  @override
  String get syncStageIdle => 'Preparing';

  @override
  String get syncStageValidating => 'Checking settings';

  @override
  String get syncStageDownloading => 'Reading remote data';

  @override
  String get syncStageMerging => 'Merging';

  @override
  String get syncStageRebuilding => 'Updating progress';

  @override
  String get syncStageUploading => 'Uploading';

  @override
  String get syncStageVerifying => 'Verifying upload';

  @override
  String get syncStageDone => 'Done';

  @override
  String get syncStageMergedNotUploaded => 'Saved locally, upload pending';

  @override
  String get syncStageWaitingBackoff => 'Waiting to retry';

  @override
  String get syncStageAuthFailed => 'Sign-in failed';

  @override
  String get syncStageRemoteMissing => 'Remote data missing';

  @override
  String get syncStageRemoteCorrupt => 'Remote data unreadable';

  @override
  String get syncStageConfigChanged => 'Settings changed';

  @override
  String get syncStagePausedAfterRestore => 'Paused after restore';

  @override
  String get syncStageFailed => 'Failed';

  @override
  String get webDavServerResponded => 'The server responded.';

  @override
  String get webDavFolderBrowsable =>
      'The folder is accessible and can be browsed.';

  @override
  String get webDavFolderAccessible => 'The folder is accessible.';

  @override
  String get webDavProbeReadWrite => 'The test file was written and read back.';

  @override
  String get syncCapabilityUnknown => 'Connection not verified';

  @override
  String get syncCapabilityConnectionFailed => 'Can\'t reach the server';

  @override
  String get syncCapabilityAuthFailed =>
      'Sign-in failed. Check the account and password.';

  @override
  String get syncCapabilityRequestRejected =>
      'The server could not process the WebDAV request';

  @override
  String get syncCapabilityNoFolder =>
      'Connected, but this folder isn\'t accessible';

  @override
  String get syncCapabilityReadOnly => 'Connected, but read-only';

  @override
  String get syncCapabilityUnsafe =>
      'Basic file access works, but safe syncing could not be verified';

  @override
  String get syncCapabilitySnapshot =>
      'Connected. Sync uses versioned snapshots.';

  @override
  String get syncCapabilitySafe => 'Connected. Ready to sync.';

  @override
  String get syncResultSynced => 'Synced';

  @override
  String get syncResultUnchanged => 'Already up to date';

  @override
  String get syncResultRemoteHasData => 'Remote already has this data';

  @override
  String get syncResultInitialised =>
      'Remote file initialised from this device';

  @override
  String get syncResultPartial => 'Saved locally, upload pending';

  @override
  String get syncResultFailed => 'Sync failed';

  @override
  String syncResultSyncedWith(String summary) {
    return 'Synced: $summary';
  }

  @override
  String get syncResultUnknown => 'Sync finished';

  @override
  String get syncTestOk => 'Connection verified';

  @override
  String get syncTestFailed => 'Connection check failed';

  @override
  String get voiceVariantUS => 'US';

  @override
  String get voiceVariantUK => 'UK';

  @override
  String get voiceVariantAU => 'Australia';

  @override
  String get voiceVariantCA => 'Canada';

  @override
  String get voiceVariantIE => 'Ireland';

  @override
  String get voiceVariantIN => 'India';

  @override
  String get importIssueNotEnglish => 'Not a valid English word';

  @override
  String importIssueRowInvalid(int row) {
    return 'Row $row: the word field is invalid';
  }

  @override
  String get importIssueNotEntry =>
      'Not a valid entry (expected text or an object)';

  @override
  String get importIssueInvalidEntry => 'Invalid entry';

  @override
  String get importIssueEmpty => '(empty)';

  @override
  String get exportFormatTxt => 'Plain text (one word per line)';

  @override
  String get exportFormatCsv => 'CSV (with meanings and examples)';

  @override
  String get exportFormatJson => 'JSON (structured, lossless round trip)';

  @override
  String get createFolderFailed =>
      'Couldn\'t create the folder. Check the permissions and try again.';

  @override
  String get s3Endpoint => 'Endpoint';

  @override
  String get s3EndpointHint => 'https://s3.us-east-1.amazonaws.com';

  @override
  String get s3Region => 'Region';

  @override
  String get s3RegionHint => 'us-east-1, or auto for Cloudflare R2';

  @override
  String get s3Bucket => 'Bucket';

  @override
  String get s3BucketHint => 'materialword-sync';

  @override
  String get s3ObjectKey => 'Object key';

  @override
  String get s3ObjectKeyHint => 'materialword/materialword-data.json';

  @override
  String get s3AccessKeyId => 'Access Key ID';

  @override
  String get s3SecretKey => 'Secret Access Key';

  @override
  String get s3ConfigNote =>
      'HTTPS only. AWS endpoints are addressed virtual-hosted, other services path-style. The object key is percent-encoded, so Chinese characters, spaces, + and % are safe.';

  @override
  String get s3CredentialsHint =>
      'Kept in the system keychain, never in backups or diagnostics.';

  @override
  String get syncCapabilityPermissionDenied =>
      'Permission denied. Check the access key permissions and the bucket policy.';

  @override
  String get cloudBackupManual => 'Manual backup';

  @override
  String get cloudBackupTitle => 'S3 and WebDAV backups';

  @override
  String get cloudBackupIndependentHint =>
      'Independent backups do not replace your bidirectional sync service.';

  @override
  String get cloudBackupConfigure => 'Configure backup';

  @override
  String get cloudBackupNotConfigured => 'Cloud backup is not configured.';

  @override
  String get cloudBackupTarget => 'Backup target';

  @override
  String get cloudBackupLastSuccess => 'Last successful backup';

  @override
  String get cloudBackupNever => 'Never';

  @override
  String get cloudBackupUpload => 'Upload backup';

  @override
  String get cloudBackupDownload => 'Download backup';

  @override
  String get cloudBackupBrowse => 'Browse cloud backups';

  @override
  String get cloudBackupSucceeded => 'Backup succeeded';

  @override
  String get cloudBackupUploadProgress => 'Uploading backup';

  @override
  String get cloudBackupVerifyProgress => 'Verifying backup';

  @override
  String get cloudBackupDownloadProgress => 'Downloading backup';

  @override
  String get cloudBackupSaveFile => 'Save file';

  @override
  String get cloudBackupEndpoint => 'Server address';

  @override
  String get cloudBackupRegion => 'Region';

  @override
  String get cloudBackupBucket => 'Bucket';

  @override
  String get cloudBackupDirectory => 'Backup directory';

  @override
  String get cloudBackupAddressing => 'Addressing style';

  @override
  String get cloudBackupUsername => 'Username';

  @override
  String get cloudBackupPassword => 'Password or app password';

  @override
  String get cloudBackupCopySync => 'Copy from sync settings';

  @override
  String get cloudBackupTest => 'Test connection';

  @override
  String get cloudBackupConfigured => 'Configured';

  @override
  String get cloudBackupNotConfiguredShort => 'Not configured';

  @override
  String get cloudBackupReady => 'Upload and readback verified';

  @override
  String get cloudBackupNoFiles => 'No cloud backups found';

  @override
  String get cloudBackupSelectFile => 'Select a backup to download';

  @override
  String get cloudBackupMergeRestore => 'Merge restore';

  @override
  String get cloudBackupSnapshotRestore => 'Snapshot restore';

  @override
  String get cloudBackupConfirmDelete =>
      'Remove this backup configuration? Cloud files will remain.';

  @override
  String get cloudBackupDownloaded => 'Backup downloaded and validated';

  @override
  String get cloudBackupNoSyncConfig => 'No matching sync configuration';

  @override
  String get cloudBackupWords => 'Words';

  @override
  String get cloudBackupBooks => 'Word books';

  @override
  String get cloudBackupSyncRunning =>
      'Sync is running. Try again after it finishes.';

  @override
  String get cloudBackupPreparing => 'Preparing backup';

  @override
  String get cloudBackupListing => 'Loading backup history';

  @override
  String get cloudBackupValidating => 'Validating backup';

  @override
  String get cloudBackupCopied => 'Backup configuration copied';

  @override
  String get cloudBackupS3 => 'S3 backup';

  @override
  String get cloudBackupWebDav => 'WebDAV backup';

  @override
  String get cloudBackupReadOnly =>
      'History available; uploading is unavailable';

  @override
  String get cloudBackupUploadOnly => 'Uploading works; history is unavailable';

  @override
  String get cloudBackupAddressingAuto => 'Auto';

  @override
  String get cloudBackupAddressingPath => 'Path-style';

  @override
  String get cloudBackupAddressingVirtual => 'Virtual-hosted';

  @override
  String get cloudBackupAccessKeyId => 'Access key ID';

  @override
  String get cloudBackupSecretAccessKey => 'Secret access key';

  @override
  String get cloudBackupCredentialsSaved =>
      'Credentials saved. Leave blank to keep them.';

  @override
  String get cloudBackupSectionServer => 'Server';

  @override
  String get cloudBackupSectionAuth => 'Credentials';

  @override
  String get cloudBackupSectionActions => 'Configuration';

  @override
  String get cloudBackupSectionDanger => 'Danger zone';

  @override
  String get cloudBackupDeleteHint =>
      'Removes the configuration and credentials on this device only. Backups already in the cloud are kept.';

  @override
  String get cloudBackupBusy =>
      'A backup is already running. Try again in a moment.';

  @override
  String get cloudBackupTooLarge => 'The backup is larger than 100 MB.';

  @override
  String get cloudBackupUnknownTime => 'Unrecognised time';

  @override
  String get cloudBackupSizeUnknown => 'Size unknown';

  @override
  String get cloudBackupDownloading => 'Downloading';

  @override
  String get cloudBackupRestoreSection => 'Restore';

  @override
  String get cloudBackupRestoreHint =>
      'Merge restore only adds missing data; snapshot restore replaces all local data and creates a protective backup first.';

  @override
  String get cloudBackupRunningHint =>
      'Closing this window does not stop the backup. Reopen it to follow the progress.';

  @override
  String get bareContentNote =>
      'Bare content files do not guarantee study progress.';

  @override
  String get mergePackageProgress => 'Merge study progress too';

  @override
  String get packageScopeNote =>
      'Only this package is merged. Other lists and study data are kept.';

  @override
  String packageProgressSummary(int count) {
    return 'Includes study progress: $count events';
  }

  @override
  String get libraryTitle => 'Libraries & dictionaries';

  @override
  String get librarySubtitle => 'Offline dictionary, exam lists and extensions';

  @override
  String get defaultDictionary => 'Default dictionary';

  @override
  String get offlineDictionaryNote => 'Bundled offline; includes word forms';

  @override
  String get optionalStudyBooks => 'Optional study lists';

  @override
  String get communityExamNote =>
      'Community exam tags, not a current official complete syllabus. Preview shows the first 10 entries.';

  @override
  String get addCatalogBook => 'Add list';

  @override
  String get extensionDictionary => 'Extension dictionary';

  @override
  String get enableDictionary => 'Enable extension';

  @override
  String get dictionarySelectionNote =>
      'Selection is backed up and synced; files are installed separately on each device.';

  @override
  String get installDictionary => 'Install / resume download';

  @override
  String get reinstallDictionary => 'Reinstall / retry';

  @override
  String get uninstallDictionary => 'Uninstall extension';

  @override
  String get uninstallDictionaryNote =>
      'Remove the local read-only package and disable it. Added words, notes and progress are retained.';

  @override
  String get dictionaryMissing =>
      'Dictionary resource missing; reinstall from Libraries';

  @override
  String get dictionaryOperationFailed =>
      'Dictionary operation failed. Retry; existing valid resources are retained.';

  @override
  String get offlineMigrationTitle => 'Full offline migration';

  @override
  String get exportOfflineMigration => 'Export offline migration';

  @override
  String get restoreOfflineMigration => 'Restore offline migration';

  @override
  String get offlineMigrationWarning =>
      'Restores the entire study snapshot and dictionary resources. A protective backup is created first and sync is paused afterward. Local appearance and voice preferences are retained.';

  @override
  String get cloudBackupDeleting => 'Deleting and checking the remote list…';

  @override
  String get cloudBackupCleanup => 'Clean old backups (keep latest two)';

  @override
  String get cloudBackupNothingToClean =>
      'There are at most two backups; nothing to clean.';

  @override
  String get cloudBackupRetain => 'Keep these two verified backups:';

  @override
  String cloudBackupCleanupCount(int count, String size) {
    return 'Delete $count older backups. Total size: $size.';
  }

  @override
  String get cloudBackupDeleteWarning =>
      'Delete this cloud backup? Local study data is retained.';

  @override
  String get s3DeleteMarkerNote =>
      'With S3 versioning, deletion usually adds a delete marker; historical object versions are retained.';

  @override
  String cloudBackupDeletionResult(int removed, int failed, int unknown) {
    return 'Confirmed deleted: $removed. Failed: $failed. Unconfirmed: $unknown.';
  }

  @override
  String get cloudBackupTargetChanged =>
      'The target changed. The operation stopped; refresh the list and retry.';

  @override
  String get cloudBackupListUncertain =>
      'The complete list, backup times or retained files could not be confirmed. Cleanup stopped; refresh and retry.';

  @override
  String get cloudBackupDeleteUnknown =>
      'The network outcome or post-delete list is unconfirmed. Refresh and verify before retrying.';

  @override
  String get examPostgraduate => 'Postgraduate entrance';

  @override
  String get examJunior => 'Junior school exam';

  @override
  String get examSenior => 'College entrance';

  @override
  String get packageProgressChoiceNote =>
      'Off: lists only. On: lists and progress.';

  @override
  String get learningPackageTooLarge =>
      'The learning package exceeds 8 MiB. Select fewer lists or split them before exporting.';

  @override
  String get dictionaryInstalled => 'Installed';

  @override
  String get dictionaryNotInstalled => 'Not installed';

  @override
  String get formatHelpZip =>
      'Learning ZIP\nUse a package exported by the app, containing content, a manifest, sources and progress. Choose lists only or also merge progress after preview. The full library is retained.';

  @override
  String get dictionaryPackageSize =>
      'Download: 37.71 MiB. Installed: 92.20 MiB.';
}
