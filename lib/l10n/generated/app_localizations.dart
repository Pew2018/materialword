import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Bottom bar / side navigation destination.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navWordLists.
  ///
  /// In en, this message translates to:
  /// **'Word Lists'**
  String get navWordLists;

  /// No description provided for @navDictionary.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get navDictionary;

  /// No description provided for @navStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get navStatistics;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navAllWords.
  ///
  /// In en, this message translates to:
  /// **'All Words'**
  String get navAllWords;

  /// No description provided for @navOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'Offline · stored on this device'**
  String get navOfflineNote;

  /// No description provided for @actionAddWord.
  ///
  /// In en, this message translates to:
  /// **'Add Word'**
  String get actionAddWord;

  /// No description provided for @actionAddWordsShortcut.
  ///
  /// In en, this message translates to:
  /// **'Add Word ({shortcut})'**
  String actionAddWordsShortcut(String shortcut);

  /// No description provided for @actionAddWordShortcutMac.
  ///
  /// In en, this message translates to:
  /// **'Add Word (⌘N)'**
  String get actionAddWordShortcutMac;

  /// No description provided for @manageAllWords.
  ///
  /// In en, this message translates to:
  /// **'All Words'**
  String get manageAllWords;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonRetry;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get commonRestore;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get commonExport;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get commonTest;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accentColor;

  /// No description provided for @accentColorHint.
  ///
  /// In en, this message translates to:
  /// **'Change the app\'s theme color.'**
  String get accentColorHint;

  /// No description provided for @accentAnswerNote.
  ///
  /// In en, this message translates to:
  /// **'Answer colors are not affected.'**
  String get accentAnswerNote;

  /// No description provided for @accentCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get accentCustom;

  /// No description provided for @accentHex.
  ///
  /// In en, this message translates to:
  /// **'HEX'**
  String get accentHex;

  /// No description provided for @accentRestoreDefault.
  ///
  /// In en, this message translates to:
  /// **'Restore Default Color'**
  String get accentRestoreDefault;

  /// No description provided for @accentClassicGroup.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get accentClassicGroup;

  /// No description provided for @accentMaterialGroup.
  ///
  /// In en, this message translates to:
  /// **'Material Design'**
  String get accentMaterialGroup;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @appLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get appLanguageSystem;

  /// No description provided for @appLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get appLanguageChinese;

  /// No description provided for @appLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get appLanguageEnglish;

  /// No description provided for @accentClearSkyBlue.
  ///
  /// In en, this message translates to:
  /// **'Clear Sky Blue'**
  String get accentClearSkyBlue;

  /// No description provided for @accentDeepSeaBlue.
  ///
  /// In en, this message translates to:
  /// **'Deep Sea Blue'**
  String get accentDeepSeaBlue;

  /// No description provided for @accentGoldenOrange.
  ///
  /// In en, this message translates to:
  /// **'Golden Orange'**
  String get accentGoldenOrange;

  /// No description provided for @accentLemonYellow.
  ///
  /// In en, this message translates to:
  /// **'Lemon Yellow'**
  String get accentLemonYellow;

  /// No description provided for @accentGrassGreen.
  ///
  /// In en, this message translates to:
  /// **'Grass Green'**
  String get accentGrassGreen;

  /// No description provided for @accentJadeGreen.
  ///
  /// In en, this message translates to:
  /// **'Jade Green'**
  String get accentJadeGreen;

  /// No description provided for @accentViolet.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get accentViolet;

  /// No description provided for @accentDeepIndigo.
  ///
  /// In en, this message translates to:
  /// **'Deep Indigo'**
  String get accentDeepIndigo;

  /// No description provided for @accentSkyBlue.
  ///
  /// In en, this message translates to:
  /// **'Sky Blue'**
  String get accentSkyBlue;

  /// No description provided for @accentVibrantPink.
  ///
  /// In en, this message translates to:
  /// **'Vibrant Pink'**
  String get accentVibrantPink;

  /// No description provided for @accentOrchidPink.
  ///
  /// In en, this message translates to:
  /// **'Orchid Pink'**
  String get accentOrchidPink;

  /// No description provided for @accentBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get accentBlue;

  /// No description provided for @accentTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get accentTeal;

  /// No description provided for @accentGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// No description provided for @accentRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get accentRed;

  /// No description provided for @accentOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get accentPurple;

  /// No description provided for @accentCyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get accentCyan;

  /// No description provided for @accentIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get accentIndigo;

  /// No description provided for @accentPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get accentPink;

  /// No description provided for @accentBlueGray.
  ///
  /// In en, this message translates to:
  /// **'Blue Gray'**
  String get accentBlueGray;

  /// No description provided for @accentDeepOrange.
  ///
  /// In en, this message translates to:
  /// **'Deep Orange'**
  String get accentDeepOrange;

  /// No description provided for @accentLightGreen.
  ///
  /// In en, this message translates to:
  /// **'Light Green'**
  String get accentLightGreen;

  /// No description provided for @stageNotStudied.
  ///
  /// In en, this message translates to:
  /// **'Not Studied'**
  String get stageNotStudied;

  /// No description provided for @stageLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get stageLearning;

  /// No description provided for @stageReviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing'**
  String get stageReviewing;

  /// No description provided for @stageRelearning.
  ///
  /// In en, this message translates to:
  /// **'Relearning'**
  String get stageRelearning;

  /// No description provided for @mastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get mastered;

  /// No description provided for @answerKnow.
  ///
  /// In en, this message translates to:
  /// **'Know'**
  String get answerKnow;

  /// No description provided for @answerNotSure.
  ///
  /// In en, this message translates to:
  /// **'Not Sure'**
  String get answerNotSure;

  /// No description provided for @answerDontKnow.
  ///
  /// In en, this message translates to:
  /// **'Don\'t Know'**
  String get answerDontKnow;

  /// No description provided for @modeMixed.
  ///
  /// In en, this message translates to:
  /// **'New Words & Review'**
  String get modeMixed;

  /// No description provided for @modeNewOnly.
  ///
  /// In en, this message translates to:
  /// **'New Words Only'**
  String get modeNewOnly;

  /// No description provided for @modeReviewOnly.
  ///
  /// In en, this message translates to:
  /// **'Review Only'**
  String get modeReviewOnly;

  /// No description provided for @modeSpecial.
  ///
  /// In en, this message translates to:
  /// **'Targeted Review'**
  String get modeSpecial;

  /// No description provided for @specialNone.
  ///
  /// In en, this message translates to:
  /// **'Regular Study'**
  String get specialNone;

  /// No description provided for @specialHard.
  ///
  /// In en, this message translates to:
  /// **'Review Difficult Words'**
  String get specialHard;

  /// No description provided for @specialMistakes.
  ///
  /// In en, this message translates to:
  /// **'Review Recent Mistakes'**
  String get specialMistakes;

  /// No description provided for @specialBook.
  ///
  /// In en, this message translates to:
  /// **'Review This Word List'**
  String get specialBook;

  /// No description provided for @specialFavorites.
  ///
  /// In en, this message translates to:
  /// **'Review Favorites'**
  String get specialFavorites;

  /// No description provided for @specialSessionMistakes.
  ///
  /// In en, this message translates to:
  /// **'Review This Round\'s Mistakes'**
  String get specialSessionMistakes;

  /// No description provided for @specialSprint.
  ///
  /// In en, this message translates to:
  /// **'Exam Prep'**
  String get specialSprint;

  /// No description provided for @practiceSpelling.
  ///
  /// In en, this message translates to:
  /// **'Spelling'**
  String get practiceSpelling;

  /// No description provided for @practiceDictation.
  ///
  /// In en, this message translates to:
  /// **'Dictation'**
  String get practiceDictation;

  /// No description provided for @practiceChoice.
  ///
  /// In en, this message translates to:
  /// **'Multiple Choice'**
  String get practiceChoice;

  /// No description provided for @practiceCloze.
  ///
  /// In en, this message translates to:
  /// **'Fill in the Blank'**
  String get practiceCloze;

  /// No description provided for @practiceSpellingDesc.
  ///
  /// In en, this message translates to:
  /// **'Type the English word for the Chinese meaning.'**
  String get practiceSpellingDesc;

  /// No description provided for @practiceDictationDesc.
  ///
  /// In en, this message translates to:
  /// **'Listen and type the English word.'**
  String get practiceDictationDesc;

  /// No description provided for @practiceChoiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Pick the correct word.'**
  String get practiceChoiceDesc;

  /// No description provided for @practiceClozeDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete the word in the example sentence.'**
  String get practiceClozeDesc;

  /// No description provided for @sortAddedDesc.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get sortAddedDesc;

  /// No description provided for @sortAlpha.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get sortAlpha;

  /// No description provided for @sortWrongDesc.
  ///
  /// In en, this message translates to:
  /// **'Most Mistakes'**
  String get sortWrongDesc;

  /// No description provided for @sortLastStudied.
  ///
  /// In en, this message translates to:
  /// **'Recently Studied'**
  String get sortLastStudied;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterUnlearned.
  ///
  /// In en, this message translates to:
  /// **'Not Studied'**
  String get filterUnlearned;

  /// No description provided for @filterLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get filterLearning;

  /// No description provided for @filterReviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing'**
  String get filterReviewing;

  /// No description provided for @filterRelearning.
  ///
  /// In en, this message translates to:
  /// **'Relearning'**
  String get filterRelearning;

  /// No description provided for @filterHard.
  ///
  /// In en, this message translates to:
  /// **'Difficult Words'**
  String get filterHard;

  /// No description provided for @filterMastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get filterMastered;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorGeneric;

  /// No description provided for @errorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this. Try again.'**
  String get errorLoadFailed;

  /// No description provided for @errorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Try again.'**
  String get errorSaveFailed;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No network connection.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The connection timed out. Try again.'**
  String get errorTimeout;

  /// No description provided for @errorPermission.
  ///
  /// In en, this message translates to:
  /// **'No permission to do that.'**
  String get errorPermission;

  /// No description provided for @sectionDailyGoals.
  ///
  /// In en, this message translates to:
  /// **'Daily Goals'**
  String get sectionDailyGoals;

  /// No description provided for @sectionStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get sectionStudy;

  /// No description provided for @sectionPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation'**
  String get sectionPronunciation;

  /// No description provided for @sectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get sectionData;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @dailyNewWords.
  ///
  /// In en, this message translates to:
  /// **'Daily New Words'**
  String get dailyNewWords;

  /// No description provided for @dailyReviewLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily Review Limit'**
  String get dailyReviewLimit;

  /// No description provided for @dailyGoalsNote.
  ///
  /// In en, this message translates to:
  /// **'Goals apply to this device. Words beyond the review limit move to tomorrow.'**
  String get dailyGoalsNote;

  /// No description provided for @studyWordList.
  ///
  /// In en, this message translates to:
  /// **'Word List'**
  String get studyWordList;

  /// No description provided for @allWordLists.
  ///
  /// In en, this message translates to:
  /// **'All Word Lists'**
  String get allWordLists;

  /// No description provided for @studyMode.
  ///
  /// In en, this message translates to:
  /// **'Study Mode'**
  String get studyMode;

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// No description provided for @enterExactValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get enterExactValue;

  /// No description provided for @valueRange.
  ///
  /// In en, this message translates to:
  /// **'Value ({min}–{max})'**
  String valueRange(int min, int max);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @enterNumberInRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between {min} and {max}.'**
  String enterNumberInRange(int min, int max);

  /// No description provided for @customAccentTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customAccentTitle;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @invalidHexColor.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit HEX color, such as #1565C0.'**
  String get invalidHexColor;

  /// No description provided for @accentSwatchSemantics.
  ///
  /// In en, this message translates to:
  /// **'Accent color {name}'**
  String accentSwatchSemantics(String name);

  /// No description provided for @englishVoice.
  ///
  /// In en, this message translates to:
  /// **'English Voice'**
  String get englishVoice;

  /// No description provided for @loadingVoices.
  ///
  /// In en, this message translates to:
  /// **'Loading system voices…'**
  String get loadingVoices;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @noEnglishVoice.
  ///
  /// In en, this message translates to:
  /// **'No English voice is installed. Install one in System Settings to hear pronunciation.'**
  String get noEnglishVoice;

  /// No description provided for @autoPronounce.
  ///
  /// In en, this message translates to:
  /// **'Auto-Pronunciation'**
  String get autoPronounce;

  /// No description provided for @autoPronounceHint.
  ///
  /// In en, this message translates to:
  /// **'Offline playback depends on the installed voice.'**
  String get autoPronounceHint;

  /// No description provided for @refreshVoices.
  ///
  /// In en, this message translates to:
  /// **'Refresh Voices'**
  String get refreshVoices;

  /// No description provided for @previewVoice.
  ///
  /// In en, this message translates to:
  /// **'Preview Voice'**
  String get previewVoice;

  /// No description provided for @speakingRate.
  ///
  /// In en, this message translates to:
  /// **'Speaking Rate'**
  String get speakingRate;

  /// No description provided for @keepScreenAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep Screen Awake'**
  String get keepScreenAwake;

  /// No description provided for @keepScreenAwakeHint.
  ///
  /// In en, this message translates to:
  /// **'Applies only while studying or practicing.'**
  String get keepScreenAwakeHint;

  /// No description provided for @keepScreenAwakeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform. Studying is unaffected.'**
  String get keepScreenAwakeUnsupported;

  /// No description provided for @randomOrder.
  ///
  /// In en, this message translates to:
  /// **'Random Order'**
  String get randomOrder;

  /// No description provided for @randomOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Shuffles the order. Targeted review and exam prep are unaffected.'**
  String get randomOrderHint;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your data in step across devices.'**
  String get syncSubtitle;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// No description provided for @backupRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up and restore your study data.'**
  String get backupRestoreSubtitle;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @diagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version, logs and troubleshooting.'**
  String get diagnosticsSubtitle;

  /// No description provided for @aboutBlurb.
  ///
  /// In en, this message translates to:
  /// **'An offline-first vocabulary app. Your data stays on this device unless you turn on sync.'**
  String get aboutBlurb;

  /// No description provided for @aboutDictionary.
  ///
  /// In en, this message translates to:
  /// **'Built-in dictionary: {count} entries (ECDICT, {license} license).'**
  String aboutDictionary(int count, String license);

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get openSourceLicenses;

  /// No description provided for @licensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Flutter, Drift, ECDICT and other dependencies'**
  String get licensesSubtitle;

  /// No description provided for @legalNotice.
  ///
  /// In en, this message translates to:
  /// **'ECDICT dictionary data is distributed under the MIT license.'**
  String get legalNotice;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice unavailable.'**
  String get voiceUnavailable;

  /// No description provided for @languageSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get languageSheetTitle;

  /// No description provided for @sprintTileSubtitleOn.
  ///
  /// In en, this message translates to:
  /// **'Exam on {date} · {count} words per round'**
  String sprintTileSubtitleOn(String date, int count);

  /// No description provided for @sprintTileSubtitleOff.
  ///
  /// In en, this message translates to:
  /// **'Set up an exam plan'**
  String get sprintTileSubtitleOff;

  /// No description provided for @continueStudying.
  ///
  /// In en, this message translates to:
  /// **'Continue Studying'**
  String get continueStudying;

  /// No description provided for @resumeProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String resumeProgress(int done, int total);

  /// No description provided for @todayTasks.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTasks;

  /// No description provided for @scopeCurrentList.
  ///
  /// In en, this message translates to:
  /// **'This word list'**
  String get scopeCurrentList;

  /// No description provided for @scopeAllLists.
  ///
  /// In en, this message translates to:
  /// **'All word lists'**
  String get scopeAllLists;

  /// No description provided for @backlogNote.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 due word is beyond today\'s review limit. It moves to tomorrow.} other{{count} due words are beyond today\'s review limit. They move to tomorrow.}}'**
  String backlogNote(int count);

  /// No description provided for @startStudying.
  ///
  /// In en, this message translates to:
  /// **'Start Studying'**
  String get startStudying;

  /// No description provided for @reviewOnly.
  ///
  /// In en, this message translates to:
  /// **'Review Only'**
  String get reviewOnly;

  /// No description provided for @newWordsAvailable.
  ///
  /// In en, this message translates to:
  /// **'New Words Available'**
  String get newWordsAvailable;

  /// No description provided for @reviewsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Due Reviews'**
  String get reviewsAvailable;

  /// No description provided for @overdueReviews.
  ///
  /// In en, this message translates to:
  /// **'Overdue Reviews'**
  String get overdueReviews;

  /// No description provided for @difficultWords.
  ///
  /// In en, this message translates to:
  /// **'Difficult Words'**
  String get difficultWords;

  /// No description provided for @newWords.
  ///
  /// In en, this message translates to:
  /// **'New Words'**
  String get newWords;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @newWordsHintRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining} left · {unlearned} not studied'**
  String newWordsHintRemaining(int remaining, int unlearned);

  /// No description provided for @noNewWordsInScope.
  ///
  /// In en, this message translates to:
  /// **'No new words left in this scope.'**
  String get noNewWordsInScope;

  /// No description provided for @reviewHintRemaining.
  ///
  /// In en, this message translates to:
  /// **'{due} due · {remaining} left'**
  String reviewHintRemaining(int due, int remaining);

  /// No description provided for @noDueWords.
  ///
  /// In en, this message translates to:
  /// **'No words due for review.'**
  String get noDueWords;

  /// No description provided for @learnedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{learned} of {total} studied'**
  String learnedOfTotal(int learned, int total);

  /// No description provided for @todayDone.
  ///
  /// In en, this message translates to:
  /// **'Today\'s tasks are done.'**
  String get todayDone;

  /// No description provided for @todayDoneHint.
  ///
  /// In en, this message translates to:
  /// **'You can keep practicing, or come back later to review.'**
  String get todayDoneHint;

  /// No description provided for @hardWordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word you missed or weren\'t sure of} other{{count} words you missed or weren\'t sure of}}'**
  String hardWordsSubtitle(int count);

  /// No description provided for @noHardWordsYet.
  ///
  /// In en, this message translates to:
  /// **'No difficult words yet.'**
  String get noHardWordsYet;

  /// No description provided for @mistakesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review words you recently got wrong.'**
  String get mistakesSubtitle;

  /// No description provided for @sectionPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get sectionPractice;

  /// No description provided for @practiceNote.
  ///
  /// In en, this message translates to:
  /// **'Practice does not use your daily allowance and does not affect your review schedule.'**
  String get practiceNote;

  /// No description provided for @clozeUsesOwnSentence.
  ///
  /// In en, this message translates to:
  /// **'Uses the example stored with the word.'**
  String get clozeUsesOwnSentence;

  /// No description provided for @noWordsYet.
  ///
  /// In en, this message translates to:
  /// **'No words yet'**
  String get noWordsYet;

  /// No description provided for @firstRunBody.
  ///
  /// In en, this message translates to:
  /// **'Import your own word list, or add the sample list to try the learning flow. You can also tap + to add words by hand.'**
  String get firstRunBody;

  /// No description provided for @importWordList.
  ///
  /// In en, this message translates to:
  /// **'Import Word List'**
  String get importWordList;

  /// No description provided for @addSampleList.
  ///
  /// In en, this message translates to:
  /// **'Add Sample Word List'**
  String get addSampleList;

  /// No description provided for @sampleAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the sample word list.'**
  String get sampleAddFailed;

  /// No description provided for @sampleLoaded.
  ///
  /// In en, this message translates to:
  /// **'Added “{name}”: {count} words.'**
  String sampleLoaded(String name, int count);

  /// No description provided for @wordListOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} ({count} words)'**
  String wordListOptionLabel(String name, int count);

  /// No description provided for @sectionStartStudy.
  ///
  /// In en, this message translates to:
  /// **'Start Studying'**
  String get sectionStartStudy;

  /// No description provided for @sectionSpecialReview.
  ///
  /// In en, this message translates to:
  /// **'Targeted Review'**
  String get sectionSpecialReview;

  /// No description provided for @studyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this session. Try again.'**
  String get studyLoadFailed;

  /// No description provided for @studySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Try again.'**
  String get studySaveFailed;

  /// No description provided for @undoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t undo. Try again.'**
  String get undoFailed;

  /// No description provided for @skipFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t skip. Try again.'**
  String get skipFailed;

  /// No description provided for @wordRemovedSkipped.
  ///
  /// In en, this message translates to:
  /// **'This word was removed, so it was skipped.'**
  String get wordRemovedSkipped;

  /// No description provided for @stateChangedSkipped.
  ///
  /// In en, this message translates to:
  /// **'This word\'s progress changed. The old card was skipped.'**
  String get stateChangedSkipped;

  /// No description provided for @contentUpdatedReview.
  ///
  /// In en, this message translates to:
  /// **'This word was updated. Check it again before answering.'**
  String get contentUpdatedReview;

  /// No description provided for @sprintChanged.
  ///
  /// In en, this message translates to:
  /// **'The exam plan changed. Go back and set it up again.'**
  String get sprintChanged;

  /// No description provided for @reviewLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Today\'s review limit is reached. You can allow extra reviews in the exam plan.'**
  String get reviewLimitReached;

  /// No description provided for @practiceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this practice. Try again.'**
  String get practiceLoadFailed;

  /// No description provided for @practiceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save this practice. Try again.'**
  String get practiceSaveFailed;

  /// No description provided for @practiceWordDeleted.
  ///
  /// In en, this message translates to:
  /// **'This word was deleted. The round restarts.'**
  String get practiceWordDeleted;

  /// No description provided for @practiceContentUpdated.
  ///
  /// In en, this message translates to:
  /// **'This word was updated. The round restarts.'**
  String get practiceContentUpdated;

  /// No description provided for @practiceWordUnlinked.
  ///
  /// In en, this message translates to:
  /// **'This word is no longer in the word list. The round restarts.'**
  String get practiceWordUnlinked;

  /// No description provided for @editWord.
  ///
  /// In en, this message translates to:
  /// **'Edit Word'**
  String get editWord;

  /// No description provided for @undoLastAnswer.
  ///
  /// In en, this message translates to:
  /// **'Undo Last Answer'**
  String get undoLastAnswer;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreActions;

  /// No description provided for @repeatPractice.
  ///
  /// In en, this message translates to:
  /// **'Repeat Practice'**
  String get repeatPractice;

  /// No description provided for @newWordTag.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newWordTag;

  /// No description provided for @reviewWithStage.
  ///
  /// In en, this message translates to:
  /// **'Review · {stage}'**
  String reviewWithStage(String stage);

  /// No description provided for @wrongCountChip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 miss} other{{count} misses}}'**
  String wrongCountChip(int count);

  /// No description provided for @recallMeaning.
  ///
  /// In en, this message translates to:
  /// **'Recall the meaning'**
  String get recallMeaning;

  /// No description provided for @noChineseMeaning.
  ///
  /// In en, this message translates to:
  /// **'No Chinese meaning yet'**
  String get noChineseMeaning;

  /// No description provided for @englishDefinition.
  ///
  /// In en, this message translates to:
  /// **'English Definition'**
  String get englishDefinition;

  /// No description provided for @exampleSentence.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get exampleSentence;

  /// No description provided for @phrases.
  ///
  /// In en, this message translates to:
  /// **'Phrases'**
  String get phrases;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @speak.
  ///
  /// In en, this message translates to:
  /// **'Pronounce'**
  String get speak;

  /// No description provided for @studyHistoryShort.
  ///
  /// In en, this message translates to:
  /// **'{correct} correct · {hazy} unsure · {wrong} wrong · {days}-day interval'**
  String studyHistoryShort(int correct, int hazy, int wrong, int days);

  /// No description provided for @showMeaning.
  ///
  /// In en, this message translates to:
  /// **'Show Meaning'**
  String get showMeaning;

  /// No description provided for @keyHintShowMeaning.
  ///
  /// In en, this message translates to:
  /// **'Press {key} to show the meaning'**
  String keyHintShowMeaning(String key);

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @nothingDueSpecial.
  ///
  /// In en, this message translates to:
  /// **'Nothing due for review'**
  String get nothingDueSpecial;

  /// No description provided for @nothingToStudyToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing to study today'**
  String get nothingToStudyToday;

  /// No description provided for @specialEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Only words matching this review are included. Your normal queue is unchanged.'**
  String get specialEmptyMessage;

  /// No description provided for @nothingLeftTodayMessage.
  ///
  /// In en, this message translates to:
  /// **'Today\'s new words and reviews are done. Adjust your goals, import more words, or come back later.'**
  String get nothingLeftTodayMessage;

  /// No description provided for @roundSummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this round.'**
  String get roundSummaryFailed;

  /// No description provided for @roundComplete.
  ///
  /// In en, this message translates to:
  /// **'Round Complete'**
  String get roundComplete;

  /// No description provided for @wordsAndAnswers.
  ///
  /// In en, this message translates to:
  /// **'{words} words · {answers} answers'**
  String wordsAndAnswers(int words, int answers);

  /// No description provided for @accuracyValue.
  ///
  /// In en, this message translates to:
  /// **'Accuracy {value}'**
  String accuracyValue(String value);

  /// No description provided for @timeSpent.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} s (pauses included)'**
  String timeSpent(int minutes, int seconds);

  /// No description provided for @roundDifficultWords.
  ///
  /// In en, this message translates to:
  /// **'Difficult Words'**
  String get roundDifficultWords;

  /// No description provided for @deletedWordSuffix.
  ///
  /// In en, this message translates to:
  /// **' (deleted)'**
  String get deletedWordSuffix;

  /// No description provided for @roundDifficultNote.
  ///
  /// In en, this message translates to:
  /// **'Words you weren\'t sure of or didn\'t know. Deleted words are not repeated.'**
  String get roundDifficultNote;

  /// No description provided for @backlogCarried.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 due word moves to tomorrow.} other{{count} due words move to tomorrow.}}'**
  String backlogCarried(int count);

  /// No description provided for @errorAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in. Check your credentials.'**
  String get errorAuthFailed;

  /// No description provided for @errorRemoteFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The sync file is missing from the remote location.'**
  String get errorRemoteFileMissing;

  /// No description provided for @errorInvalidBackup.
  ///
  /// In en, this message translates to:
  /// **'This file is not a valid backup.'**
  String get errorInvalidBackup;

  /// No description provided for @studyTitle.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get studyTitle;

  /// No description provided for @practiceVoiceHintUsed.
  ///
  /// In en, this message translates to:
  /// **'Voice unavailable. The Chinese meaning is shown instead.'**
  String get practiceVoiceHintUsed;

  /// No description provided for @nothingToPractice.
  ///
  /// In en, this message translates to:
  /// **'Nothing to practice'**
  String get nothingToPractice;

  /// No description provided for @practiceCannotStart.
  ///
  /// In en, this message translates to:
  /// **'Can\'t start this practice'**
  String get practiceCannotStart;

  /// No description provided for @clozeEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Fill in the Blank uses only the example stored with each word. Add an example, or try another practice.'**
  String get clozeEmptyMessage;

  /// No description provided for @practiceEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Practice needs words with a Chinese meaning. Add or import words first.'**
  String get practiceEmptyMessage;

  /// No description provided for @undoLastQuestion.
  ///
  /// In en, this message translates to:
  /// **'Undo Last Answer'**
  String get undoLastQuestion;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get playAgain;

  /// No description provided for @listenAndType.
  ///
  /// In en, this message translates to:
  /// **'Listen and type the word.'**
  String get listenAndType;

  /// No description provided for @hintWithText.
  ///
  /// In en, this message translates to:
  /// **'Hint: {text}'**
  String hintWithText(String text);

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @incorrect.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get incorrect;

  /// No description provided for @correctSpelling.
  ///
  /// In en, this message translates to:
  /// **'Correct spelling: {answer}'**
  String correctSpelling(String answer);

  /// No description provided for @yourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer: {answer}'**
  String yourAnswer(String answer);

  /// No description provided for @practiceAnswerNote.
  ///
  /// In en, this message translates to:
  /// **'This answer is recorded but does not change the word\'s review interval.'**
  String get practiceAnswerNote;

  /// No description provided for @viewResults.
  ///
  /// In en, this message translates to:
  /// **'View Results'**
  String get viewResults;

  /// No description provided for @nextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextQuestion;

  /// No description provided for @typeTheWord.
  ///
  /// In en, this message translates to:
  /// **'Type the word'**
  String get typeTheWord;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @chooseCorrectWord.
  ///
  /// In en, this message translates to:
  /// **'Choose the correct word above.'**
  String get chooseCorrectWord;

  /// No description provided for @hideHint.
  ///
  /// In en, this message translates to:
  /// **'Hide Hint'**
  String get hideHint;

  /// No description provided for @showHint.
  ///
  /// In en, this message translates to:
  /// **'Show Hint'**
  String get showHint;

  /// No description provided for @practiceComplete.
  ///
  /// In en, this message translates to:
  /// **'Practice Complete'**
  String get practiceComplete;

  /// No description provided for @answersCount.
  ///
  /// In en, this message translates to:
  /// **'Answers'**
  String get answersCount;

  /// No description provided for @skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// No description provided for @practiceAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy {value} · {count, plural, =1{1 word} other{{count} words}}'**
  String practiceAccuracy(String value, int count);

  /// No description provided for @worthAnotherLook.
  ///
  /// In en, this message translates to:
  /// **'Worth Another Look'**
  String get worthAnotherLook;

  /// No description provided for @practiceStatsNote.
  ///
  /// In en, this message translates to:
  /// **'Practice answers count towards statistics but do not change the review interval.'**
  String get practiceStatsNote;

  /// No description provided for @continuePracticing.
  ///
  /// In en, this message translates to:
  /// **'Continue Practicing'**
  String get continuePracticing;

  /// No description provided for @sprintPlanFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the exam plan.'**
  String get sprintPlanFailed;

  /// No description provided for @createListFirst.
  ///
  /// In en, this message translates to:
  /// **'Add or import a word list first.'**
  String get createListFirst;

  /// No description provided for @sprintSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the exam plan.'**
  String get sprintSaveFailed;

  /// No description provided for @sprintNothingToRun.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review right now. Check the plan and today\'s limits.'**
  String get sprintNothingToRun;

  /// No description provided for @sprintPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start exam prep.'**
  String get sprintPrepareFailed;

  /// No description provided for @setSprintPlan.
  ///
  /// In en, this message translates to:
  /// **'Exam Plan'**
  String get setSprintPlan;

  /// No description provided for @sprintTileOff.
  ///
  /// In en, this message translates to:
  /// **'Set up an exam plan'**
  String get sprintTileOff;

  /// No description provided for @examPassedDays.
  ///
  /// In en, this message translates to:
  /// **'Exam was {days} days ago'**
  String examPassedDays(int days);

  /// No description provided for @examToday.
  ///
  /// In en, this message translates to:
  /// **'Exam today'**
  String get examToday;

  /// No description provided for @examInDays.
  ///
  /// In en, this message translates to:
  /// **'Exam in {days} days'**
  String examInDays(int days);

  /// No description provided for @targetListName.
  ///
  /// In en, this message translates to:
  /// **'Word list: {name}'**
  String targetListName(String name);

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @sprintDisabledNote.
  ///
  /// In en, this message translates to:
  /// **'Exam prep is off.'**
  String get sprintDisabledNote;

  /// No description provided for @sprintBookUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The word list is unavailable. Choose another one.'**
  String get sprintBookUnavailable;

  /// No description provided for @unlearnedWords.
  ///
  /// In en, this message translates to:
  /// **'Not Studied'**
  String get unlearnedWords;

  /// No description provided for @recentMistakes7d.
  ///
  /// In en, this message translates to:
  /// **'Recent Mistakes'**
  String get recentMistakes7d;

  /// No description provided for @sprintThisRound.
  ///
  /// In en, this message translates to:
  /// **'{count} words this round'**
  String sprintThisRound(int count);

  /// No description provided for @sprintEligibleLine.
  ///
  /// In en, this message translates to:
  /// **'{eligible} eligible · {allowance} reviews left today'**
  String sprintEligibleLine(int eligible, int allowance);

  /// No description provided for @sprintOnlyUnlearned.
  ///
  /// In en, this message translates to:
  /// **'Only unstudied words are left. You can include them in the plan.'**
  String get sprintOnlyUnlearned;

  /// No description provided for @sprintLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Today\'s review limit is reached. You can allow extra reviews in the plan.'**
  String get sprintLimitReached;

  /// No description provided for @sprintAlgorithmNote.
  ///
  /// In en, this message translates to:
  /// **'Prioritises difficult words and recent mistakes, while still covering other words.'**
  String get sprintAlgorithmNote;

  /// No description provided for @aboutSprintPlan.
  ///
  /// In en, this message translates to:
  /// **'About Exam Prep'**
  String get aboutSprintPlan;

  /// No description provided for @sprintAboutBody.
  ///
  /// In en, this message translates to:
  /// **'Exam prep builds its own queue from the selected word list. Answers are recorded as ordinary reviews, so they count towards today\'s limit and move the word\'s next review date; a correct answer today does not shorten an interval already earned. Changing the plan re-plans the queue and keeps every recorded answer.'**
  String get sprintAboutBody;

  /// No description provided for @continueSprint.
  ///
  /// In en, this message translates to:
  /// **'Continue Exam Prep'**
  String get continueSprint;

  /// No description provided for @startSprint.
  ///
  /// In en, this message translates to:
  /// **'Start Exam Prep'**
  String get startSprint;

  /// No description provided for @endSprint.
  ///
  /// In en, this message translates to:
  /// **'End Exam Prep'**
  String get endSprint;

  /// No description provided for @sprintEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn On Exam Prep'**
  String get sprintEnable;

  /// No description provided for @examDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Exam date: {date}'**
  String examDateLabel(String date);

  /// No description provided for @chooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get chooseDate;

  /// No description provided for @roundSizeShort.
  ///
  /// In en, this message translates to:
  /// **'Words per Round'**
  String get roundSizeShort;

  /// No description provided for @roundSizeRange.
  ///
  /// In en, this message translates to:
  /// **'Words per Round (1–500)'**
  String get roundSizeRange;

  /// No description provided for @prioritizeHard.
  ///
  /// In en, this message translates to:
  /// **'Prioritise Difficult Words'**
  String get prioritizeHard;

  /// No description provided for @prioritizeRecent.
  ///
  /// In en, this message translates to:
  /// **'Prioritise Recent Mistakes'**
  String get prioritizeRecent;

  /// No description provided for @prioritizeUnmastered.
  ///
  /// In en, this message translates to:
  /// **'Prioritise Unmastered Words'**
  String get prioritizeUnmastered;

  /// No description provided for @includeUnlearned.
  ///
  /// In en, this message translates to:
  /// **'Include Unstudied Words'**
  String get includeUnlearned;

  /// No description provided for @allowOverReviewLimit.
  ///
  /// In en, this message translates to:
  /// **'Allow Extra Reviews'**
  String get allowOverReviewLimit;

  /// No description provided for @sprintDialogNote.
  ///
  /// In en, this message translates to:
  /// **'Exam prep is a separate practice. With extra reviews off it respects today\'s limit. Changing the plan re-plans the queue and keeps your answers.'**
  String get sprintDialogNote;

  /// No description provided for @sprintVersionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This plan was made by a newer version. Update the app.'**
  String get sprintVersionUnsupported;

  /// No description provided for @sprintInvalidSwitch.
  ///
  /// In en, this message translates to:
  /// **'This plan isn\'t valid. Set it up again.'**
  String get sprintInvalidSwitch;

  /// No description provided for @sprintInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'That exam date isn\'t valid.'**
  String get sprintInvalidDate;

  /// No description provided for @sprintInvalidBook.
  ///
  /// In en, this message translates to:
  /// **'That word list isn\'t valid.'**
  String get sprintInvalidBook;

  /// No description provided for @sprintInvalidRoundSize.
  ///
  /// In en, this message translates to:
  /// **'Words per round must be between 1 and 500.'**
  String get sprintInvalidRoundSize;

  /// No description provided for @sprintIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Choose an exam date and a word list.'**
  String get sprintIncomplete;

  /// No description provided for @newWordList.
  ///
  /// In en, this message translates to:
  /// **'New Word List'**
  String get newWordList;

  /// No description provided for @wordListName.
  ///
  /// In en, this message translates to:
  /// **'Word List Name'**
  String get wordListName;

  /// No description provided for @refreshOnlineList.
  ///
  /// In en, this message translates to:
  /// **'Refresh Online List'**
  String get refreshOnlineList;

  /// No description provided for @sourceUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Source: {url}'**
  String sourceUrlLabel(String url);

  /// No description provided for @onlineListTotal.
  ///
  /// In en, this message translates to:
  /// **'The online list has {count} words.'**
  String onlineListTotal(int count);

  /// No description provided for @refreshExisting.
  ///
  /// In en, this message translates to:
  /// **'Already on this device: {count}'**
  String refreshExisting(int count);

  /// No description provided for @refreshToAdd.
  ///
  /// In en, this message translates to:
  /// **'To add: {count}'**
  String refreshToAdd(int count);

  /// No description provided for @refreshDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicates in the file: {count}'**
  String refreshDuplicate(int count);

  /// No description provided for @refreshInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid entries: {count}'**
  String refreshInvalid(int count);

  /// No description provided for @refreshDropped.
  ///
  /// In en, this message translates to:
  /// **'Lines skipped: {count}'**
  String refreshDropped(int count);

  /// No description provided for @refreshDeletedByUser.
  ///
  /// In en, this message translates to:
  /// **'Deleted by you, not restored: {count}'**
  String refreshDeletedByUser(int count);

  /// No description provided for @refreshLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Removed from the source, kept here: {count}'**
  String refreshLocalOnly(int count);

  /// No description provided for @refreshNote.
  ///
  /// In en, this message translates to:
  /// **'Only missing words are added. Nothing on this device is deleted, restored, overwritten or reset. Canceling changes nothing.'**
  String get refreshNote;

  /// No description provided for @confirmRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get confirmRefresh;

  /// No description provided for @refreshDone.
  ///
  /// In en, this message translates to:
  /// **'Refresh complete. Added {added}, updated {updated}, already present {existing}.'**
  String refreshDone(int added, int updated, int existing);

  /// No description provided for @refreshCancelled.
  ///
  /// In en, this message translates to:
  /// **'Refresh canceled. Nothing changed.'**
  String get refreshCancelled;

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh this word list. Try again.'**
  String get refreshFailed;

  /// No description provided for @nothingToExport.
  ///
  /// In en, this message translates to:
  /// **'No word lists to export.'**
  String get nothingToExport;

  /// No description provided for @exportListTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Word List'**
  String get exportListTitle;

  /// No description provided for @wordCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No words} =1{1 word} other{{count} words}}'**
  String wordCountPlural(int count);

  /// No description provided for @exportContentNote.
  ///
  /// In en, this message translates to:
  /// **'Exports word content only: no study history, notes or credentials. Use Backup & Restore for a full backup.'**
  String get exportContentNote;

  /// No description provided for @exportSelected.
  ///
  /// In en, this message translates to:
  /// **'Export {count, plural, =1{1 Word List} other{{count} Word Lists}}'**
  String exportSelected(int count);

  /// No description provided for @chooseFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose Format'**
  String get chooseFormat;

  /// No description provided for @exportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export canceled.'**
  String get exportCancelled;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Exported {books} word lists · {words} words (no study history).'**
  String exportDone(int books, int words);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export. Try again.'**
  String get exportFailed;

  /// No description provided for @myWordLists.
  ///
  /// In en, this message translates to:
  /// **'My Word Lists'**
  String get myWordLists;

  /// No description provided for @wordListsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load word lists. Try again.'**
  String get wordListsLoadFailed;

  /// No description provided for @noWordLists.
  ///
  /// In en, this message translates to:
  /// **'No word lists yet'**
  String get noWordLists;

  /// No description provided for @noWordListsMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a word list, then import your words — one per line.'**
  String get noWordListsMessage;

  /// No description provided for @renameWordList.
  ///
  /// In en, this message translates to:
  /// **'Rename Word List'**
  String get renameWordList;

  /// No description provided for @deleteWordListTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Word List?'**
  String get deleteWordListTitle;

  /// No description provided for @deleteWordListBody.
  ///
  /// In en, this message translates to:
  /// **'“{name}” will be deleted. Words and study history are kept.'**
  String deleteWordListBody(String name);

  /// No description provided for @allWordsNote.
  ///
  /// In en, this message translates to:
  /// **'All Words filters by list, progress and difficulty, and can add, remove or delete in bulk.'**
  String get allWordsNote;

  /// No description provided for @currentTag.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentTag;

  /// No description provided for @setForStudy.
  ///
  /// In en, this message translates to:
  /// **'Use for Study'**
  String get setForStudy;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @importIntoList.
  ///
  /// In en, this message translates to:
  /// **'Import into This List'**
  String get importIntoList;

  /// No description provided for @wordListRowStats.
  ///
  /// In en, this message translates to:
  /// **'{count} words · {learned} studied · {due} due'**
  String wordListRowStats(int count, int learned, int due);

  /// No description provided for @protectiveBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the safety backup, so nothing was changed.'**
  String get protectiveBackupFailed;

  /// No description provided for @exportDoneSingle.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} words (no study history).'**
  String exportDoneSingle(int count);

  /// No description provided for @searchWordsHint.
  ///
  /// In en, this message translates to:
  /// **'Search words, meanings or notes'**
  String get searchWordsHint;

  /// No description provided for @wordListLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this word list. Try again.'**
  String get wordListLoadFailed;

  /// No description provided for @wordListEmpty.
  ///
  /// In en, this message translates to:
  /// **'This word list is empty'**
  String get wordListEmpty;

  /// No description provided for @noMatchingWords.
  ///
  /// In en, this message translates to:
  /// **'No matching words'**
  String get noMatchingWords;

  /// No description provided for @wordListEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add or import words to start studying.'**
  String get wordListEmptyMessage;

  /// No description provided for @operationFailedNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'The action failed. Nothing was changed. Try again.'**
  String get operationFailedNothingChanged;

  /// No description provided for @selectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t select these words. Try again.'**
  String get selectionFailed;

  /// No description provided for @updatedWordsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated 1 word} other{Updated {count} words}}'**
  String updatedWordsCount(int count);

  /// No description provided for @markMasteredTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as Mastered?'**
  String get markMasteredTitle;

  /// No description provided for @unmarkMasteredTitle.
  ///
  /// In en, this message translates to:
  /// **'Unmark as Mastered?'**
  String get unmarkMasteredTitle;

  /// No description provided for @unmarkMasteredBody.
  ///
  /// In en, this message translates to:
  /// **'Clears the manual mark. Progress returns to what the recorded answers say, without adding answers.'**
  String get unmarkMasteredBody;

  /// No description provided for @markMasteredBody.
  ///
  /// In en, this message translates to:
  /// **'Marks {count, plural, =1{1 word} other{{count} words}} as mastered and schedules a review in 30 days. Study history is kept; it doesn\'t count as an answer.'**
  String markMasteredBody(int count);

  /// No description provided for @markMasteredBodyOne.
  ///
  /// In en, this message translates to:
  /// **'Marks this word as mastered and schedules a review in 30 days. Study history is kept; it doesn\'t count as an answer or affect accuracy.'**
  String get markMasteredBodyOne;

  /// No description provided for @unmarkMasteredDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Unmarked 1 word} other{Unmarked {count} words}}'**
  String unmarkMasteredDone(int count);

  /// No description provided for @markMasteredDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Marked 1 word as mastered} other{Marked {count} words as mastered}}'**
  String markMasteredDone(int count);

  /// No description provided for @resetProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Progress?'**
  String get resetProgressTitle;

  /// No description provided for @resetProgressBodyBulk.
  ///
  /// In en, this message translates to:
  /// **'Clears the learning state of {count, plural, =1{1 word} other{{count} words}}: answers, interval and next review date. The words and their answer history are kept.'**
  String resetProgressBodyBulk(int count);

  /// No description provided for @resetProgressBodyOne.
  ///
  /// In en, this message translates to:
  /// **'Clears this word\'s learning state: answers, interval and next review date. The word and its answer history are kept.'**
  String get resetProgressBodyOne;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Reset 1 word} other{Reset {count} words}}'**
  String resetDone(int count);

  /// No description provided for @addListFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a word list first.'**
  String get addListFirst;

  /// No description provided for @addToWordList.
  ///
  /// In en, this message translates to:
  /// **'Add to Word List'**
  String get addToWordList;

  /// No description provided for @addedToWordList.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 word} other{Added {count} words}}'**
  String addedToWordList(int count);

  /// No description provided for @chooseListFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a word list above first.'**
  String get chooseListFirst;

  /// No description provided for @removeFromWordList.
  ///
  /// In en, this message translates to:
  /// **'Remove from Word List'**
  String get removeFromWordList;

  /// No description provided for @removeFromListBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {count, plural, =1{1 word} other{{count} words}} from “{book}”? Links to other word lists and study progress are unaffected.'**
  String removeFromListBody(int count, String book);

  /// No description provided for @removedFromWordList.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Removed 1 word from the list} other{Removed {count} words from the list}}'**
  String removedFromWordList(int count);

  /// No description provided for @deleteWordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Words?'**
  String get deleteWordsTitle;

  /// No description provided for @deleteWordsBodyBulk.
  ///
  /// In en, this message translates to:
  /// **'Delete {count, plural, =1{1 word} other{{count} words}} from every word list? Study history is kept. To take a word out of one list only, use Remove from Word List.'**
  String deleteWordsBodyBulk(int count);

  /// No description provided for @deleteWordsBodyOne.
  ///
  /// In en, this message translates to:
  /// **'Delete this word from every word list? Study history is kept. To take it out of one list only, use Remove from Word List.'**
  String get deleteWordsBodyOne;

  /// No description provided for @deletedWordsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted 1 word} other{Deleted {count} words}}'**
  String deletedWordsCount(int count);

  /// No description provided for @tagsManagement.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsManagement;

  /// No description provided for @noMatchingWordsGroup.
  ///
  /// In en, this message translates to:
  /// **'No matching words'**
  String get noMatchingWordsGroup;

  /// No description provided for @emptyFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Try another filter, or add words first.'**
  String get emptyFilterHint;

  /// No description provided for @noMatchForQuery.
  ///
  /// In en, this message translates to:
  /// **'No words match “{query}”.'**
  String noMatchForQuery(String query);

  /// No description provided for @favoritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorites only'**
  String get favoritesOnly;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @allTags.
  ///
  /// In en, this message translates to:
  /// **'All Tags'**
  String get allTags;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get statusLabel;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// No description provided for @selectAllResults.
  ///
  /// In en, this message translates to:
  /// **'Select all {count}'**
  String selectAllResults(int count);

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearSelection;

  /// No description provided for @selectLoaded.
  ///
  /// In en, this message translates to:
  /// **'Select {count}'**
  String selectLoaded(int count);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @batchFavoritesAndTags.
  ///
  /// In en, this message translates to:
  /// **'Favorites & Tags'**
  String get batchFavoritesAndTags;

  /// No description provided for @favoriteSelected.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get favoriteSelected;

  /// No description provided for @unfavoriteSelected.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get unfavoriteSelected;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add Tag'**
  String get addTag;

  /// No description provided for @removeTag.
  ///
  /// In en, this message translates to:
  /// **'Remove Tag'**
  String get removeTag;

  /// No description provided for @removeFromCurrentList.
  ///
  /// In en, this message translates to:
  /// **'Remove from Word List'**
  String get removeFromCurrentList;

  /// No description provided for @markMastered.
  ///
  /// In en, this message translates to:
  /// **'Mark as Mastered'**
  String get markMastered;

  /// No description provided for @unmarkMastered.
  ///
  /// In en, this message translates to:
  /// **'Unmark as Mastered'**
  String get unmarkMastered;

  /// No description provided for @resetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset Progress'**
  String get resetProgress;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get loadMore;

  /// No description provided for @errorRateChip.
  ///
  /// In en, this message translates to:
  /// **'{percent}% wrong'**
  String errorRateChip(int percent);

  /// No description provided for @noChineseMeaningShort.
  ///
  /// In en, this message translates to:
  /// **'No Chinese meaning'**
  String get noChineseMeaningShort;

  /// No description provided for @selectAWord.
  ///
  /// In en, this message translates to:
  /// **'Select a word'**
  String get selectAWord;

  /// No description provided for @selectAWordHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a word to see its history and actions.'**
  String get selectAWordHint;

  /// No description provided for @wordDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Word Details'**
  String get wordDetailTitle;

  /// No description provided for @wordNotFound.
  ///
  /// In en, this message translates to:
  /// **'Word Not Found'**
  String get wordNotFound;

  /// No description provided for @errorRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Error rate {value}'**
  String errorRateLabel(String value);

  /// No description provided for @answersTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 answer} other{{count} answers}}'**
  String answersTimes(int count);

  /// No description provided for @inWordLists.
  ///
  /// In en, this message translates to:
  /// **'In {count, plural, =1{1 word list} other{{count} word lists}}'**
  String inWordLists(int count);

  /// No description provided for @nextReviewNone.
  ///
  /// In en, this message translates to:
  /// **'Next review: none'**
  String get nextReviewNone;

  /// No description provided for @nextReviewAt.
  ///
  /// In en, this message translates to:
  /// **'Next review: {date} ({relative})'**
  String nextReviewAt(String date, String relative);

  /// No description provided for @answerHistory.
  ///
  /// In en, this message translates to:
  /// **'Answer History (last {count})'**
  String answerHistory(int count);

  /// No description provided for @noAnswerHistory.
  ///
  /// In en, this message translates to:
  /// **'No answers recorded yet.'**
  String get noAnswerHistory;

  /// No description provided for @eventNewStudy.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get eventNewStudy;

  /// No description provided for @eventReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get eventReview;

  /// No description provided for @eventReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get eventReset;

  /// No description provided for @eventManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get eventManual;

  /// No description provided for @eventSpecial.
  ///
  /// In en, this message translates to:
  /// **'Targeted'**
  String get eventSpecial;

  /// No description provided for @unmarkMasteredBodyOne.
  ///
  /// In en, this message translates to:
  /// **'Returns the word to learning and schedules a near review. History is kept; no answer is added.'**
  String get unmarkMasteredBodyOne;

  /// No description provided for @navAllWordsWithCount.
  ///
  /// In en, this message translates to:
  /// **'All Words ({count})'**
  String navAllWordsWithCount(int count);

  /// No description provided for @noRecord.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get noRecord;

  /// No description provided for @wordManagementDeleteWord.
  ///
  /// In en, this message translates to:
  /// **'Delete Word'**
  String get wordManagementDeleteWord;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeAgo.
  ///
  /// In en, this message translates to:
  /// **'{value} ago'**
  String timeAgo(String value);

  /// No description provided for @timeIn.
  ///
  /// In en, this message translates to:
  /// **'in {value}'**
  String timeIn(String value);

  /// No description provided for @timeValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String timeValue(int count);

  /// No description provided for @timeHoursValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String timeHoursValue(int count);

  /// No description provided for @timeDaysValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String timeDaysValue(int count);

  /// No description provided for @timeMonthsValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String timeMonthsValue(int count);

  /// No description provided for @timeYearsValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year} other{{count} years}}'**
  String timeYearsValue(int count);

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @wordNotInDictionary.
  ///
  /// In en, this message translates to:
  /// **'The dictionary doesn\'t have this word.'**
  String get wordNotInDictionary;

  /// No description provided for @filledFromDictionary.
  ///
  /// In en, this message translates to:
  /// **'Blank fields were filled from the dictionary. Save to keep them.'**
  String get filledFromDictionary;

  /// No description provided for @wordEntry.
  ///
  /// In en, this message translates to:
  /// **'Word'**
  String get wordEntry;

  /// No description provided for @removeFromListBodyWord.
  ///
  /// In en, this message translates to:
  /// **'Remove “{word}” from this word list? The word, its other word lists and study progress are kept.'**
  String removeFromListBodyWord(String word);

  /// No description provided for @deleteWordBodyName.
  ///
  /// In en, this message translates to:
  /// **'Delete “{word}” from every word list? Study history is kept. To remove it from one list only, use Remove from Word List.'**
  String deleteWordBodyName(String word);

  /// No description provided for @fillFromDictionary.
  ///
  /// In en, this message translates to:
  /// **'Fill from Dictionary'**
  String get fillFromDictionary;

  /// No description provided for @wordInfo.
  ///
  /// In en, this message translates to:
  /// **'Word Info'**
  String get wordInfo;

  /// No description provided for @wordField.
  ///
  /// In en, this message translates to:
  /// **'Word'**
  String get wordField;

  /// No description provided for @phonetics.
  ///
  /// In en, this message translates to:
  /// **'Phonetics'**
  String get phonetics;

  /// No description provided for @partOfSpeech.
  ///
  /// In en, this message translates to:
  /// **'Part of Speech'**
  String get partOfSpeech;

  /// No description provided for @chineseMeaning.
  ///
  /// In en, this message translates to:
  /// **'Chinese Meaning'**
  String get chineseMeaning;

  /// No description provided for @savedAsCustom.
  ///
  /// In en, this message translates to:
  /// **'Once saved, this word is marked as edited, and dictionary updates won\'t overwrite what you typed.'**
  String get savedAsCustom;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @learningProgress.
  ///
  /// In en, this message translates to:
  /// **'Learning Progress'**
  String get learningProgress;

  /// No description provided for @editedTag.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get editedTag;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String sourceLabel(String source);

  /// No description provided for @sourceManual.
  ///
  /// In en, this message translates to:
  /// **'Added by hand'**
  String get sourceManual;

  /// No description provided for @sourceImport.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get sourceImport;

  /// No description provided for @sourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Online list'**
  String get sourceUrl;

  /// No description provided for @sourceSample.
  ///
  /// In en, this message translates to:
  /// **'Sample list'**
  String get sourceSample;

  /// No description provided for @sourceDictionary.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get sourceDictionary;

  /// No description provided for @sourceFile.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get sourceFile;

  /// No description provided for @sourceOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sourceOther;

  /// No description provided for @intervalDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String intervalDays(int count);

  /// No description provided for @intervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get intervalLabel;

  /// No description provided for @statsOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statsOverview;

  /// No description provided for @totalWordsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Words'**
  String get totalWordsLabel;

  /// No description provided for @learnedLabel.
  ///
  /// In en, this message translates to:
  /// **'Studied'**
  String get learnedLabel;

  /// No description provided for @unlearnedLabel.
  ///
  /// In en, this message translates to:
  /// **'Not Studied'**
  String get unlearnedLabel;

  /// No description provided for @accuracyLabel.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get accuracyLabel;

  /// No description provided for @overallAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Overall Accuracy'**
  String get overallAccuracy;

  /// No description provided for @todayStudy.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayStudy;

  /// No description provided for @todayNewWords.
  ///
  /// In en, this message translates to:
  /// **'New Words'**
  String get todayNewWords;

  /// No description provided for @todayReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get todayReviews;

  /// No description provided for @cumulativeCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get cumulativeCorrect;

  /// No description provided for @cumulativeWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get cumulativeWrong;

  /// No description provided for @cumulativeHazy.
  ///
  /// In en, this message translates to:
  /// **'Not Sure'**
  String get cumulativeHazy;

  /// No description provided for @distinctAnsweredWords.
  ///
  /// In en, this message translates to:
  /// **'Words Answered'**
  String get distinctAnsweredWords;

  /// No description provided for @answerBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Answer Breakdown'**
  String get answerBreakdown;

  /// No description provided for @breakdownStudyReview.
  ///
  /// In en, this message translates to:
  /// **'Study & Review'**
  String get breakdownStudyReview;

  /// No description provided for @breakdownSpecial.
  ///
  /// In en, this message translates to:
  /// **'Targeted Review'**
  String get breakdownSpecial;

  /// No description provided for @breakdownPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get breakdownPractice;

  /// No description provided for @breakdownRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat Practice'**
  String get breakdownRepeat;

  /// No description provided for @distinctWordsAnswered.
  ///
  /// In en, this message translates to:
  /// **'Distinct Words'**
  String get distinctWordsAnswered;

  /// No description provided for @undoneAnswers.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get undoneAnswers;

  /// No description provided for @breakdownNote.
  ///
  /// In en, this message translates to:
  /// **'Practice counts as answers but doesn\'t affect your review plan. Marking as mastered or resetting progress doesn\'t count.'**
  String get breakdownNote;

  /// No description provided for @answersLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Answers in the Last 7 Days'**
  String get answersLast7Days;

  /// No description provided for @reviewsNext7Days.
  ///
  /// In en, this message translates to:
  /// **'Reviews in the Next 7 Days'**
  String get reviewsNext7Days;

  /// No description provided for @noScheduledReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews scheduled.'**
  String get noScheduledReviews;

  /// No description provided for @wordListProgress.
  ///
  /// In en, this message translates to:
  /// **'Word List Progress'**
  String get wordListProgress;

  /// No description provided for @wordPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get wordPerformance;

  /// No description provided for @lastStudiedDay.
  ///
  /// In en, this message translates to:
  /// **'Last Studied'**
  String get lastStudiedDay;

  /// No description provided for @accuracyFormula.
  ///
  /// In en, this message translates to:
  /// **'Accuracy = Know answers ÷ all answers, counted across every session and device.'**
  String get accuracyFormula;

  /// No description provided for @noAnswersYet.
  ///
  /// In en, this message translates to:
  /// **'No answers yet. Finish one study session to see real numbers.'**
  String get noAnswersYet;

  /// No description provided for @wordErrorHazyStat.
  ///
  /// In en, this message translates to:
  /// **'{wrong} wrong · {hazy} unsure'**
  String wordErrorHazyStat(int wrong, int hazy);

  /// No description provided for @noAnswersLast7Days.
  ///
  /// In en, this message translates to:
  /// **'No answers in the last 7 days.'**
  String get noAnswersLast7Days;

  /// No description provided for @aboutStatistics.
  ///
  /// In en, this message translates to:
  /// **'About Statistics'**
  String get aboutStatistics;

  /// No description provided for @aboutStatisticsBody.
  ///
  /// In en, this message translates to:
  /// **'Overview counts every word in the current scope. Today covers this device\'s answers since midnight; the overview is cumulative. Answers are compared across all sessions and devices, and undone answers are listed separately rather than removed from history.'**
  String get aboutStatisticsBody;

  /// No description provided for @valueTimes.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String valueTimes(int count);

  /// No description provided for @statsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load statistics.'**
  String get statsLoadFailed;

  /// No description provided for @searchWordHint.
  ///
  /// In en, this message translates to:
  /// **'Search words (⌘F)'**
  String get searchWordHint;

  /// No description provided for @searchWordHintPlain.
  ///
  /// In en, this message translates to:
  /// **'Search words'**
  String get searchWordHintPlain;

  /// No description provided for @recentSearch.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentSearch;

  /// No description provided for @offlineDictionary.
  ///
  /// In en, this message translates to:
  /// **'Offline Dictionary'**
  String get offlineDictionary;

  /// No description provided for @dictionaryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Search {count} English words and add them straight to a word list.'**
  String dictionaryEmptyBody(int count);

  /// No description provided for @relatedWords.
  ///
  /// In en, this message translates to:
  /// **'Related Words'**
  String get relatedWords;

  /// No description provided for @wordFormHint.
  ///
  /// In en, this message translates to:
  /// **'Past tense or past participle of {word}'**
  String wordFormHint(String word);

  /// No description provided for @relationPastParticiple.
  ///
  /// In en, this message translates to:
  /// **'past tense or past participle'**
  String get relationPastParticiple;

  /// No description provided for @relationPlural.
  ///
  /// In en, this message translates to:
  /// **'plural or third-person form'**
  String get relationPlural;

  /// No description provided for @relationPresentParticiple.
  ///
  /// In en, this message translates to:
  /// **'present participle or gerund'**
  String get relationPresentParticiple;

  /// No description provided for @relationComparative.
  ///
  /// In en, this message translates to:
  /// **'comparative'**
  String get relationComparative;

  /// No description provided for @relationSuperlative.
  ///
  /// In en, this message translates to:
  /// **'superlative'**
  String get relationSuperlative;

  /// No description provided for @myWordsCount.
  ///
  /// In en, this message translates to:
  /// **'My Words ({count})'**
  String myWordsCount(int count);

  /// No description provided for @dictionaryResultsCount.
  ///
  /// In en, this message translates to:
  /// **'Results ({count})'**
  String dictionaryResultsCount(int count);

  /// No description provided for @noDictionaryMatch.
  ///
  /// In en, this message translates to:
  /// **'The dictionary doesn\'t have this word. You can add it by hand and fill in the meaning later.'**
  String get noDictionaryMatch;

  /// No description provided for @addTermAsWord.
  ///
  /// In en, this message translates to:
  /// **'Add “{term}”'**
  String addTermAsWord(String term);

  /// No description provided for @dictionaryHint.
  ///
  /// In en, this message translates to:
  /// **'Use + to add a word to the current list. Existing words keep their progress and notes.'**
  String get dictionaryHint;

  /// No description provided for @dictionarySearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search the dictionary.'**
  String get dictionarySearchFailed;

  /// No description provided for @addFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add. Try again.'**
  String get addFailed;

  /// No description provided for @tagCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a tag in Tags first.'**
  String get tagCreateFirst;

  /// No description provided for @chooseTag.
  ///
  /// In en, this message translates to:
  /// **'Choose Tag'**
  String get chooseTag;

  /// No description provided for @unfavoriteWord.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get unfavoriteWord;

  /// No description provided for @favoriteWord.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get favoriteWord;

  /// No description provided for @favoriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update favorites. Try again.'**
  String get favoriteFailed;

  /// No description provided for @tagOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update tags. Try again.'**
  String get tagOperationFailed;

  /// No description provided for @removeTagNamed.
  ///
  /// In en, this message translates to:
  /// **'Remove tag {name}'**
  String removeTagNamed(String name);

  /// No description provided for @manageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get manageTags;

  /// No description provided for @createTag.
  ///
  /// In en, this message translates to:
  /// **'Create Tag'**
  String get createTag;

  /// No description provided for @renameTag.
  ///
  /// In en, this message translates to:
  /// **'Rename Tag'**
  String get renameTag;

  /// No description provided for @tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get tagName;

  /// No description provided for @deleteTag.
  ///
  /// In en, this message translates to:
  /// **'Delete Tag'**
  String get deleteTag;

  /// No description provided for @deleteTagBody.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}” and its word links? Words, favorites and study history are kept.'**
  String deleteTagBody(String name);

  /// No description provided for @tagsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load tags. Open this page again.'**
  String get tagsLoadFailed;

  /// No description provided for @noTagsYet.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get noTagsYet;

  /// No description provided for @tagDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete tag {name}'**
  String tagDeleteAction(String name);

  /// No description provided for @intakeAdded.
  ///
  /// In en, this message translates to:
  /// **'Added “{word}”.'**
  String intakeAdded(String word);

  /// No description provided for @intakeRevivedLinked.
  ///
  /// In en, this message translates to:
  /// **'Restored “{word}” and added it to the list. Study history was kept.'**
  String intakeRevivedLinked(String word);

  /// No description provided for @intakeRevived.
  ///
  /// In en, this message translates to:
  /// **'Restored “{word}”. Study history was kept.'**
  String intakeRevived(String word);

  /// No description provided for @intakeUnchanged.
  ///
  /// In en, this message translates to:
  /// **'“{word}” is unchanged.'**
  String intakeUnchanged(String word);

  /// No description provided for @intakeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {count, plural, =1{1 field} other{{count} fields}} of “{word}”.'**
  String intakeUpdated(int count, String word);

  /// No description provided for @intakeAlreadyInList.
  ///
  /// In en, this message translates to:
  /// **'“{word}” is already in this list.'**
  String intakeAlreadyInList(String word);

  /// No description provided for @intakeExists.
  ///
  /// In en, this message translates to:
  /// **'“{word}” already exists and is unchanged.'**
  String intakeExists(String word);

  /// No description provided for @intakeDeletedSkipped.
  ///
  /// In en, this message translates to:
  /// **'“{word}” was deleted and wasn\'t restored.'**
  String intakeDeletedSkipped(String word);

  /// No description provided for @dictNotFoundManual.
  ///
  /// In en, this message translates to:
  /// **'No meaning found. You can add one by hand.'**
  String get dictNotFoundManual;

  /// No description provided for @dictFilled.
  ///
  /// In en, this message translates to:
  /// **'Filled from the dictionary.'**
  String get dictFilled;

  /// No description provided for @dictLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t query the dictionary. You can type the meaning yourself.'**
  String get dictLookupFailed;

  /// No description provided for @enterEnglishWord.
  ///
  /// In en, this message translates to:
  /// **'Enter an English word.'**
  String get enterEnglishWord;

  /// No description provided for @listDeleted.
  ///
  /// In en, this message translates to:
  /// **'That word list was deleted.'**
  String get listDeleted;

  /// No description provided for @pasteWordsPerLine.
  ///
  /// In en, this message translates to:
  /// **'Paste words, one per line.'**
  String get pasteWordsPerLine;

  /// No description provided for @addMultiple.
  ///
  /// In en, this message translates to:
  /// **'Add Multiple Words'**
  String get addMultiple;

  /// No description provided for @parseFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this. Check the format.'**
  String get parseFailed;

  /// No description provided for @batchAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add these words. Try again.'**
  String get batchAddFailed;

  /// No description provided for @addOneWord.
  ///
  /// In en, this message translates to:
  /// **'Add One Word'**
  String get addOneWord;

  /// No description provided for @englishWord.
  ///
  /// In en, this message translates to:
  /// **'English Word'**
  String get englishWord;

  /// No description provided for @typeToLookUp.
  ///
  /// In en, this message translates to:
  /// **'Type a word to look it up'**
  String get typeToLookUp;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @dictMissingNote.
  ///
  /// In en, this message translates to:
  /// **'You can save even if the dictionary doesn\'t have it, and fill in the meaning later.'**
  String get dictMissingNote;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get importing;

  /// No description provided for @saveAndContinueShortcut.
  ///
  /// In en, this message translates to:
  /// **'Save and Continue (⌘Enter)'**
  String get saveAndContinueShortcut;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and Continue'**
  String get saveAndContinue;

  /// No description provided for @quickAddNote.
  ///
  /// In en, this message translates to:
  /// **'Uses the last chosen word list. Existing words keep their meaning, notes and progress; only what you change is overwritten.'**
  String get quickAddNote;

  /// No description provided for @batchWordsPerLine.
  ///
  /// In en, this message translates to:
  /// **'One word per line'**
  String get batchWordsPerLine;

  /// No description provided for @foundWordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Found 1 word} other{Found {count} words}}'**
  String foundWordCount(int count);

  /// No description provided for @batchDuplicates.
  ///
  /// In en, this message translates to:
  /// **'{count} duplicates merged'**
  String batchDuplicates(int count);

  /// No description provided for @batchInvalidLines.
  ///
  /// In en, this message translates to:
  /// **'{count} lines ignored'**
  String batchInvalidLines(int count);

  /// No description provided for @batchDefinitionStats.
  ///
  /// In en, this message translates to:
  /// **'{withMeaning} have a meaning or can be filled from the dictionary; {withoutMeaning} need one.'**
  String batchDefinitionStats(int withMeaning, int withoutMeaning);

  /// No description provided for @batchKeepsProgress.
  ///
  /// In en, this message translates to:
  /// **'Existing progress is kept.'**
  String get batchKeepsProgress;

  /// No description provided for @moreTotal.
  ///
  /// In en, this message translates to:
  /// **'…{count} in total'**
  String moreTotal(int count);

  /// No description provided for @targetList.
  ///
  /// In en, this message translates to:
  /// **'Word List'**
  String get targetList;

  /// No description provided for @wordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a word.'**
  String get wordEmpty;

  /// No description provided for @wordTooLong.
  ///
  /// In en, this message translates to:
  /// **'That word is too long (64 characters at most).'**
  String get wordTooLong;

  /// No description provided for @chooseWordListFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a Word List File'**
  String get chooseWordListFile;

  /// No description provided for @cannotReadFile.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this file. Only local files are supported.'**
  String get cannotReadFile;

  /// No description provided for @downloadParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download or read this link. Check the file.'**
  String get downloadParseFailed;

  /// No description provided for @downloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download canceled. Nothing was written.'**
  String get downloadCancelled;

  /// No description provided for @chooseTargetList.
  ///
  /// In en, this message translates to:
  /// **'Choose a word list first.'**
  String get chooseTargetList;

  /// No description provided for @importFailedUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Import failed. Nothing was changed.'**
  String get importFailedUnchanged;

  /// No description provided for @importWordListTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Word List'**
  String get importWordListTitle;

  /// No description provided for @stepChooseSource.
  ///
  /// In en, this message translates to:
  /// **'1. Source'**
  String get stepChooseSource;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get chooseFile;

  /// No description provided for @formatHelp.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get formatHelp;

  /// No description provided for @downloadLink.
  ///
  /// In en, this message translates to:
  /// **'Word List Link (TXT / CSV / JSON)'**
  String get downloadLink;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel Download'**
  String get cancelDownload;

  /// No description provided for @stepPreview.
  ///
  /// In en, this message translates to:
  /// **'2. Preview'**
  String get stepPreview;

  /// No description provided for @statImportable.
  ///
  /// In en, this message translates to:
  /// **'Importable'**
  String get statImportable;

  /// No description provided for @statNewWords.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get statNewWords;

  /// No description provided for @statExistingWords.
  ///
  /// In en, this message translates to:
  /// **'Existing'**
  String get statExistingWords;

  /// No description provided for @statRestorable.
  ///
  /// In en, this message translates to:
  /// **'Restorable'**
  String get statRestorable;

  /// No description provided for @statWillLink.
  ///
  /// In en, this message translates to:
  /// **'Will be added'**
  String get statWillLink;

  /// No description provided for @statDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get statDuplicates;

  /// No description provided for @statInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get statInvalid;

  /// No description provided for @statFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get statFormat;

  /// No description provided for @statLists.
  ///
  /// In en, this message translates to:
  /// **'Word Lists'**
  String get statLists;

  /// No description provided for @fileRowsSummary.
  ///
  /// In en, this message translates to:
  /// **'{total} lines. {skipped} won\'t be imported (see below).'**
  String fileRowsSummary(int total, int skipped);

  /// No description provided for @restorableNote.
  ///
  /// In en, this message translates to:
  /// **'{count} of them were deleted by you. An explicit import restores them and keeps their history; refreshing an online list does not.'**
  String restorableNote(int count);

  /// No description provided for @issuesHeader.
  ///
  /// In en, this message translates to:
  /// **'First {count} issues:'**
  String issuesHeader(int count);

  /// No description provided for @stepTargetList.
  ///
  /// In en, this message translates to:
  /// **'3. Word List'**
  String get stepTargetList;

  /// No description provided for @addToExistingList.
  ///
  /// In en, this message translates to:
  /// **'Add to an Existing Word List'**
  String get addToExistingList;

  /// No description provided for @chooseWordList.
  ///
  /// In en, this message translates to:
  /// **'Choose a word list'**
  String get chooseWordList;

  /// No description provided for @importMergeNote.
  ///
  /// In en, this message translates to:
  /// **'Existing words are not created twice and their progress is kept. Only missing details are filled in, and the word is linked to the chosen list.'**
  String get importMergeNote;

  /// No description provided for @startImportCount.
  ///
  /// In en, this message translates to:
  /// **'Import {count, plural, =1{1 Word} other{{count} Words}}'**
  String startImportCount(int count);

  /// No description provided for @importComplete.
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get importComplete;

  /// No description provided for @noFileChosen.
  ///
  /// In en, this message translates to:
  /// **'No file chosen'**
  String get noFileChosen;

  /// No description provided for @formatSummary.
  ///
  /// In en, this message translates to:
  /// **'TXT: one word per line. CSV: a word column is required. JSON: a words array is required.'**
  String get formatSummary;

  /// No description provided for @supportedFormats.
  ///
  /// In en, this message translates to:
  /// **'Supported Formats'**
  String get supportedFormats;

  /// No description provided for @importResultAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get importResultAdded;

  /// No description provided for @importResultExisting.
  ///
  /// In en, this message translates to:
  /// **'Already present'**
  String get importResultExisting;

  /// No description provided for @importResultUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get importResultUpdated;

  /// No description provided for @importResultRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get importResultRestored;

  /// No description provided for @importResultDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get importResultDuplicate;

  /// No description provided for @importResultSkipped.
  ///
  /// In en, this message translates to:
  /// **'Not imported'**
  String get importResultSkipped;

  /// No description provided for @formatHelpTxt.
  ///
  /// In en, this message translates to:
  /// **'TXT\nOne word per line. An optional meaning can follow a tab or a comma:\n  abandon\n  abandon\tv. to give up'**
  String get formatHelpTxt;

  /// No description provided for @formatHelpCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV\nOne header row, and a word column is required. phonetic / pos / translation / definition / example / note are optional.'**
  String get formatHelpCsv;

  /// No description provided for @formatHelpJson.
  ///
  /// In en, this message translates to:
  /// **'JSON\nA schemaVersion, an optional name, and a words array. Each entry is an object with word, plus optional translation, phonetic, pos, definition, example and note.'**
  String get formatHelpJson;

  /// No description provided for @formatHelpFooter.
  ///
  /// In en, this message translates to:
  /// **'Files must be UTF-8. One import is limited to {entries} words and {megabytes} MB; download links must be HTTPS. Missing phonetics and meanings are filled in from the offline dictionary, and existing progress and notes are never overwritten.'**
  String formatHelpFooter(int entries, int megabytes);

  /// No description provided for @saveDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Save Diagnostics'**
  String get saveDiagnostics;

  /// No description provided for @diagnosticsExported.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics exported (no account or study content).'**
  String get diagnosticsExported;

  /// No description provided for @diagnosticsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export diagnostics.'**
  String get diagnosticsExportFailed;

  /// No description provided for @logsSection.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsSection;

  /// No description provided for @detailedLogging.
  ///
  /// In en, this message translates to:
  /// **'Detailed Logs'**
  String get detailedLogging;

  /// No description provided for @detailedLoggingHint.
  ///
  /// In en, this message translates to:
  /// **'Off by default. When on, keeps the last 400 entries for 24 hours, with sensitive values removed.'**
  String get detailedLoggingHint;

  /// No description provided for @exportDiagnosticsReport.
  ///
  /// In en, this message translates to:
  /// **'Export Diagnostics'**
  String get exportDiagnosticsReport;

  /// No description provided for @exportDiagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'Version, database and dictionary statistics, sync status. No account or study content.'**
  String get exportDiagnosticsHint;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get clearLogs;

  /// No description provided for @noLogs.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet'**
  String get noLogs;

  /// No description provided for @logCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String logCount(int count);

  /// No description provided for @logsCleared.
  ///
  /// In en, this message translates to:
  /// **'Logs cleared.'**
  String get logsCleared;

  /// No description provided for @deviceSection.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceSection;

  /// No description provided for @deviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceIdLabel;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get reading;

  /// No description provided for @deviceIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Device ID copied (used only to investigate sync problems).'**
  String get deviceIdCopied;

  /// No description provided for @diagnosticsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics never include passwords, credentials, word content or personal notes. The sync configuration records only the sync method, not the address, account or path.'**
  String get diagnosticsPrivacy;

  /// No description provided for @chooseRemoteFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose Remote Folder'**
  String get chooseRemoteFolder;

  /// No description provided for @cannotReadFolder.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this folder.'**
  String get cannotReadFolder;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get newFolder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder Name'**
  String get folderName;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @serverLabel.
  ///
  /// In en, this message translates to:
  /// **'Server: {url}'**
  String serverLabel(String url);

  /// No description provided for @chooseThisFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose This Folder'**
  String get chooseThisFolder;

  /// No description provided for @parentFolder.
  ///
  /// In en, this message translates to:
  /// **'Up One Level'**
  String get parentFolder;

  /// No description provided for @noSubfolders.
  ///
  /// In en, this message translates to:
  /// **'No subfolders here. You can choose this folder or create one.'**
  String get noSubfolders;

  /// No description provided for @syncOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get syncOff;

  /// No description provided for @syncOffHint.
  ///
  /// In en, this message translates to:
  /// **'Study data stays on this device.'**
  String get syncOffHint;

  /// No description provided for @localFile.
  ///
  /// In en, this message translates to:
  /// **'Local File'**
  String get localFile;

  /// No description provided for @localFileHint.
  ///
  /// In en, this message translates to:
  /// **'Transfers data through a JSON file.'**
  String get localFileHint;

  /// No description provided for @githubPrivateRepo.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get githubPrivateRepo;

  /// No description provided for @githubHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps study data in a private repository.'**
  String get githubHint;

  /// No description provided for @webdavHint.
  ///
  /// In en, this message translates to:
  /// **'Syncs through a compatible WebDAV service.'**
  String get webdavHint;

  /// No description provided for @credentialsUnreadable.
  ///
  /// In en, this message translates to:
  /// **'{reason}. The saved credentials can\'t be read; enter them again. Offline study is unaffected.'**
  String credentialsUnreadable(String reason);

  /// No description provided for @tokenMissing.
  ///
  /// In en, this message translates to:
  /// **'No saved access token was found. Enter it again before syncing.'**
  String get tokenMissing;

  /// No description provided for @passwordMissing.
  ///
  /// In en, this message translates to:
  /// **'No saved WebDAV password was found. Enter it again before syncing.'**
  String get passwordMissing;

  /// No description provided for @draftNotSaved.
  ///
  /// In en, this message translates to:
  /// **'The connection settings aren\'t saved yet. Auto options are saved and verified when you tap Sync Now.'**
  String get draftNotSaved;

  /// No description provided for @configChanged.
  ///
  /// In en, this message translates to:
  /// **'The connection settings changed. Open this page again.'**
  String get configChanged;

  /// No description provided for @preferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved. Automatic sync starts only after Test Connection verifies safe writes.'**
  String get preferencesSaved;

  /// No description provided for @preferencesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the auto-sync options. Try again.'**
  String get preferencesSaveFailed;

  /// No description provided for @credentialsNotSaved.
  ///
  /// In en, this message translates to:
  /// **'{reason}. The credentials were not saved; enter them again. Offline study is unaffected.'**
  String credentialsNotSaved(String reason);

  /// No description provided for @connectionTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t test this connection.'**
  String get connectionTestFailed;

  /// No description provided for @remoteFolderChosen.
  ///
  /// In en, this message translates to:
  /// **'Remote folder selected: {path}'**
  String remoteFolderChosen(String path);

  /// No description provided for @cannotBrowseRemote.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t browse the remote folder.'**
  String get cannotBrowseRemote;

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'A sync is already running.'**
  String get syncInProgress;

  /// No description provided for @firstSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'First Sync'**
  String get firstSyncTitle;

  /// No description provided for @firstSyncBody.
  ///
  /// In en, this message translates to:
  /// **'The first sync merges the remote data with this device. It won\'t overwrite local progress and won\'t delete local words.\n\nContinue?'**
  String get firstSyncBody;

  /// No description provided for @startMerging.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get startMerging;

  /// No description provided for @unsafeServerBody.
  ///
  /// In en, this message translates to:
  /// **'MaterialWord paused syncing because this check could not confirm that two devices can update the same file without overwriting each other. You can test the connection again or export a backup.'**
  String get unsafeServerBody;

  /// No description provided for @retestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Again'**
  String get retestConnection;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export Backup'**
  String get exportBackup;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed.'**
  String get syncFailed;

  /// No description provided for @remoteBecameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Remote file became empty'**
  String get remoteBecameEmpty;

  /// No description provided for @remoteIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Remote file is empty'**
  String get remoteIsEmpty;

  /// No description provided for @remoteEmptiedBody.
  ///
  /// In en, this message translates to:
  /// **'This target synced successfully before, but the remote file is now 0 bytes.\n\nContinuing re-initialises it with this device\'s data, replacing what was there.'**
  String get remoteEmptiedBody;

  /// No description provided for @remoteEmptiedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Continue only if the remote data is no longer needed.'**
  String get remoteEmptiedConfirm;

  /// No description provided for @emptyInitBody.
  ///
  /// In en, this message translates to:
  /// **'The remote sync file is empty.\n\nInitialise it with this device\'s data? The current version is recorded, so if another device writes meanwhile this initialisation is rejected instead of overwriting it.'**
  String get emptyInitBody;

  /// No description provided for @initialiseAndSync.
  ///
  /// In en, this message translates to:
  /// **'Initialise and Sync'**
  String get initialiseAndSync;

  /// No description provided for @mergeRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge Remote Data?'**
  String get mergeRemoteTitle;

  /// No description provided for @mergeRemoteBody.
  ///
  /// In en, this message translates to:
  /// **'This resumes sync and merges the other device\'s data into this one, adding only what is missing. The merged result is then uploaded, so the remote copy will contain the restored data from this device.'**
  String get mergeRemoteBody;

  /// No description provided for @noTargetConfigured.
  ///
  /// In en, this message translates to:
  /// **'No sync target configured'**
  String get noTargetConfigured;

  /// No description provided for @syncStaysPausedRemoteUntouched.
  ///
  /// In en, this message translates to:
  /// **'Sync stays paused. The remote data was not changed.'**
  String get syncStaysPausedRemoteUntouched;

  /// No description provided for @recreateRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-upload Remote Data?'**
  String get recreateRemoteTitle;

  /// No description provided for @recreateRemoteBody.
  ///
  /// In en, this message translates to:
  /// **'The remote data file no longer exists, perhaps because the repository file was deleted or the path changed.\n\nContinuing uploads this device\'s current data there. If you did not intend to remove the remote data, cancel and check the repository and settings.'**
  String get recreateRemoteBody;

  /// No description provided for @reupload.
  ///
  /// In en, this message translates to:
  /// **'Re-upload'**
  String get reupload;

  /// No description provided for @restoreConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore the Overwritten Value?'**
  String get restoreConflictTitle;

  /// No description provided for @restoreConflictBody.
  ///
  /// In en, this message translates to:
  /// **'{label} · {field} will be changed back to the other value. This is synced to other devices as a new edit.'**
  String restoreConflictBody(String label, String field);

  /// No description provided for @restoredField.
  ///
  /// In en, this message translates to:
  /// **'Restored {field}'**
  String restoredField(String field);

  /// No description provided for @restoredAsNewEdit.
  ///
  /// In en, this message translates to:
  /// **'(synced as a new edit)'**
  String get restoredAsNewEdit;

  /// No description provided for @restoreFailedKept.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore. The conflict record was kept.'**
  String get restoreFailedKept;

  /// No description provided for @fieldWord.
  ///
  /// In en, this message translates to:
  /// **'Word'**
  String get fieldWord;

  /// No description provided for @fieldPhonetic.
  ///
  /// In en, this message translates to:
  /// **'Phonetics'**
  String get fieldPhonetic;

  /// No description provided for @fieldPos.
  ///
  /// In en, this message translates to:
  /// **'Part of Speech'**
  String get fieldPos;

  /// No description provided for @fieldTranslation.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get fieldTranslation;

  /// No description provided for @fieldDefinition.
  ///
  /// In en, this message translates to:
  /// **'English Definition'**
  String get fieldDefinition;

  /// No description provided for @fieldExample.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get fieldExample;

  /// No description provided for @fieldPhrase.
  ///
  /// In en, this message translates to:
  /// **'Phrases'**
  String get fieldPhrase;

  /// No description provided for @fieldNote.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNote;

  /// No description provided for @fieldSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get fieldSource;

  /// No description provided for @fieldExamTags.
  ///
  /// In en, this message translates to:
  /// **'Exam Tags'**
  String get fieldExamTags;

  /// No description provided for @fieldBnc.
  ///
  /// In en, this message translates to:
  /// **'BNC Rank'**
  String get fieldBnc;

  /// No description provided for @fieldCoca.
  ///
  /// In en, this message translates to:
  /// **'COCA Rank'**
  String get fieldCoca;

  /// No description provided for @fieldDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get fieldDeleted;

  /// No description provided for @fieldBookName.
  ///
  /// In en, this message translates to:
  /// **'Word List Name'**
  String get fieldBookName;

  /// No description provided for @fieldBookDescription.
  ///
  /// In en, this message translates to:
  /// **'Word List Description'**
  String get fieldBookDescription;

  /// No description provided for @fieldBookSourceType.
  ///
  /// In en, this message translates to:
  /// **'Word List Source Type'**
  String get fieldBookSourceType;

  /// No description provided for @fieldBookSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Word List Source Link'**
  String get fieldBookSourceUrl;

  /// No description provided for @notDeleted.
  ///
  /// In en, this message translates to:
  /// **'Not deleted'**
  String get notDeleted;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @emptyValue.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get emptyValue;

  /// No description provided for @backupExported.
  ///
  /// In en, this message translates to:
  /// **'Backup exported.'**
  String get backupExported;

  /// No description provided for @exportPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export. Choose another location.'**
  String get exportPickFailed;

  /// No description provided for @turnOffSync.
  ///
  /// In en, this message translates to:
  /// **'Turn Off Sync'**
  String get turnOffSync;

  /// No description provided for @turnOffSyncBody.
  ///
  /// In en, this message translates to:
  /// **'The sync settings and credentials (token / password) stored on this device are deleted. Remote data is not deleted, and study records stay on this device.'**
  String get turnOffSyncBody;

  /// No description provided for @syncTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Sync turned off.'**
  String get syncTurnedOff;

  /// No description provided for @retestAfterSwitch.
  ///
  /// In en, this message translates to:
  /// **'Test the connection again after switching sync method.'**
  String get retestAfterSwitch;

  /// No description provided for @remoteFileMissingNotice.
  ///
  /// In en, this message translates to:
  /// **'The remote data file no longer exists.'**
  String get remoteFileMissingNotice;

  /// No description provided for @syncPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Paused'**
  String get syncPausedTitle;

  /// No description provided for @syncPausedRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'This data came from a restore. Automatic sync stays off until you decide what to do with the remote data.'**
  String get syncPausedRestoreBody;

  /// No description provided for @mergeRemote.
  ///
  /// In en, this message translates to:
  /// **'Merge Remote Data'**
  String get mergeRemote;

  /// No description provided for @keepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep This Device'**
  String get keepLocal;

  /// No description provided for @mergeOnlyAdds.
  ///
  /// In en, this message translates to:
  /// **'Neither side overwrites the other: a merge only adds what is missing.'**
  String get mergeOnlyAdds;

  /// No description provided for @syncMethod.
  ///
  /// In en, this message translates to:
  /// **'Sync Method'**
  String get syncMethod;

  /// No description provided for @connectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection Settings'**
  String get connectionSettings;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @syncOnStart.
  ///
  /// In en, this message translates to:
  /// **'Sync on Launch'**
  String get syncOnStart;

  /// No description provided for @syncOnStartHint.
  ///
  /// In en, this message translates to:
  /// **'The app always shows local data first.'**
  String get syncOnStartHint;

  /// No description provided for @syncOnResume.
  ///
  /// In en, this message translates to:
  /// **'Sync on Return'**
  String get syncOnResume;

  /// No description provided for @syncOnResumeHint.
  ///
  /// In en, this message translates to:
  /// **'Checks for changes when you come back; retries later on failure.'**
  String get syncOnResumeHint;

  /// No description provided for @syncOnChange.
  ///
  /// In en, this message translates to:
  /// **'Sync After Changes'**
  String get syncOnChange;

  /// No description provided for @syncOnChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Runs about 20 seconds after you stop, not after every answer.'**
  String get syncOnChangeHint;

  /// No description provided for @syncOnSessionEnd.
  ///
  /// In en, this message translates to:
  /// **'Sync When a Session Ends'**
  String get syncOnSessionEnd;

  /// No description provided for @syncOnSessionEndHint.
  ///
  /// In en, this message translates to:
  /// **'Runs after a session ends, without changing the flow.'**
  String get syncOnSessionEndHint;

  /// No description provided for @localFileManualOnly.
  ///
  /// In en, this message translates to:
  /// **'A local file is for manual merging only. For automatic sync, choose GitHub or WebDAV.'**
  String get localFileManualOnly;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @autoSyncNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync is paused until Test Connection verifies safe writes.'**
  String get autoSyncNotEnabled;

  /// No description provided for @autoSyncNotEnabledReason.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync is paused. {reason}.'**
  String autoSyncNotEnabledReason(String reason);

  /// No description provided for @syncConflicts.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflicts'**
  String get syncConflicts;

  /// No description provided for @keptValue.
  ///
  /// In en, this message translates to:
  /// **'Kept: {value}'**
  String keptValue(String value);

  /// No description provided for @discardedValue.
  ///
  /// In en, this message translates to:
  /// **'Overwritten: {value}'**
  String discardedValue(String value);

  /// No description provided for @restoreOverwritten.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreOverwritten;

  /// No description provided for @diagnosticOnly.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic only, can\'t be restored'**
  String get diagnosticOnly;

  /// No description provided for @ignoreRecord.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignoreRecord;

  /// No description provided for @conflictExplain.
  ///
  /// In en, this message translates to:
  /// **'Another device changed the same item. MaterialWord kept the newer value and stored the other one here. Restoring changes it back and syncs that as a new edit; entries without a restore action are for diagnostics only.'**
  String get conflictExplain;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get syncStatus;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last Synced'**
  String get lastSynced;

  /// No description provided for @neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never Synced'**
  String get neverSynced;

  /// No description provided for @syncResult.
  ///
  /// In en, this message translates to:
  /// **'Sync Result'**
  String get syncResult;

  /// No description provided for @pendingChanges.
  ///
  /// In en, this message translates to:
  /// **'Pending Changes'**
  String get pendingChanges;

  /// No description provided for @hasLocalChanges.
  ///
  /// In en, this message translates to:
  /// **'Local changes are not uploaded yet.'**
  String get hasLocalChanges;

  /// No description provided for @inSyncWithLast.
  ///
  /// In en, this message translates to:
  /// **'This device matches the last sync.'**
  String get inSyncWithLast;

  /// No description provided for @recreateRemoteAction.
  ///
  /// In en, this message translates to:
  /// **'Re-upload Remote Data…'**
  String get recreateRemoteAction;

  /// No description provided for @syncDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Sync Diagnostics'**
  String get syncDiagnostics;

  /// No description provided for @syncDiagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'View and export recent sync requests (no passwords or study content).'**
  String get syncDiagnosticsHint;

  /// No description provided for @aboutSync.
  ///
  /// In en, this message translates to:
  /// **'About Syncing'**
  String get aboutSync;

  /// No description provided for @aboutSyncBody.
  ///
  /// In en, this message translates to:
  /// **'Remote and local data are merged, never overwritten:\n· one record per word;\n· every answer is kept and progress is recomputed after merging;\n· deleted words and word lists stay deleted;\n· when two devices change the same item, the newer value is kept and the other copy stays under Sync Conflicts.\nTokens and passwords are kept only in the system secure storage (Keychain / Keystore), never in the database, a backup or a log.'**
  String get aboutSyncBody;

  /// No description provided for @connectionNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Connection Not Verified'**
  String get connectionNotVerified;

  /// No description provided for @connectionNotVerifiedHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the address and account, then run Test Connection. Safe writes must be verified before syncing.'**
  String get connectionNotVerifiedHint;

  /// No description provided for @technicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical Details'**
  String get technicalDetails;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note:'**
  String get noteLabel;

  /// No description provided for @syncFilePath.
  ///
  /// In en, this message translates to:
  /// **'Sync File Path'**
  String get syncFilePath;

  /// No description provided for @mobileFolderLimit.
  ///
  /// In en, this message translates to:
  /// **'Phones can\'t keep access to an arbitrary folder. Use the app\'s own file, or export / import from Backup & Restore.'**
  String get mobileFolderLimit;

  /// No description provided for @githubOwner.
  ///
  /// In en, this message translates to:
  /// **'GitHub User or Organization'**
  String get githubOwner;

  /// No description provided for @repoName.
  ///
  /// In en, this message translates to:
  /// **'Repository Name'**
  String get repoName;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @dataFilePath.
  ///
  /// In en, this message translates to:
  /// **'File Path'**
  String get dataFilePath;

  /// No description provided for @accessToken.
  ///
  /// In en, this message translates to:
  /// **'Access Token'**
  String get accessToken;

  /// No description provided for @accessTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Used to access your private repository; kept only in this device\'s secure storage.'**
  String get accessTokenHint;

  /// No description provided for @privateRepoNote.
  ///
  /// In en, this message translates to:
  /// **'Use a dedicated private repository for study data. Never use a public one.'**
  String get privateRepoNote;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server Address (HTTPS)'**
  String get serverAddress;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @appPassword.
  ///
  /// In en, this message translates to:
  /// **'Password or App Password'**
  String get appPassword;

  /// No description provided for @leaveBlankToKeep.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep the saved value'**
  String get leaveBlankToKeep;

  /// No description provided for @remoteFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get remoteFolder;

  /// No description provided for @remoteFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use the server address itself. Browse with the button above rather than copying a name from a sync client.'**
  String get remoteFolderHint;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get fileName;

  /// No description provided for @httpsOnly.
  ///
  /// In en, this message translates to:
  /// **'HTTPS only; certificate checks are never disabled.'**
  String get httpsOnly;

  /// No description provided for @etagNote.
  ///
  /// In en, this message translates to:
  /// **'Sync protects edits from multiple devices with conditional writes or separate snapshots. Automatic sync requires a verified connection.'**
  String get etagNote;

  /// No description provided for @serverNoConditionalWrite.
  ///
  /// In en, this message translates to:
  /// **'This server did not pass the safe-write check.'**
  String get serverNoConditionalWrite;

  /// No description provided for @credentialsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The saved sync credentials can\'t be read. Enter them again. Offline study is unaffected.'**
  String get credentialsUnavailable;

  /// No description provided for @credentialsNotStored.
  ///
  /// In en, this message translates to:
  /// **'The credentials were not saved. Enter them again. Offline study is unaffected.'**
  String get credentialsNotStored;

  /// No description provided for @serverRootFolder.
  ///
  /// In en, this message translates to:
  /// **'server root'**
  String get serverRootFolder;

  /// No description provided for @mergeOnlyAddsShort.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get mergeOnlyAddsShort;

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupAndRestore;

  /// No description provided for @exportBackupDone.
  ///
  /// In en, this message translates to:
  /// **'Backup exported.'**
  String get exportBackupDone;

  /// No description provided for @exportCanceled.
  ///
  /// In en, this message translates to:
  /// **'Export canceled.'**
  String get exportCanceled;

  /// No description provided for @mergeBackup.
  ///
  /// In en, this message translates to:
  /// **'Merge Backup'**
  String get mergeBackup;

  /// No description provided for @mergeToDevice.
  ///
  /// In en, this message translates to:
  /// **'Merges into this device and keeps the existing history; nothing on this device is deleted.'**
  String get mergeToDevice;

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @checkBackup.
  ///
  /// In en, this message translates to:
  /// **'Check Backup'**
  String get checkBackup;

  /// No description provided for @backupInfo.
  ///
  /// In en, this message translates to:
  /// **'Backup Info'**
  String get backupInfo;

  /// No description provided for @schemaVersionLine.
  ///
  /// In en, this message translates to:
  /// **'Format: v{version}'**
  String schemaVersionLine(int version);

  /// No description provided for @createdAtLine.
  ///
  /// In en, this message translates to:
  /// **'Created: {time}'**
  String createdAtLine(String time);

  /// No description provided for @appVersionLine.
  ///
  /// In en, this message translates to:
  /// **'App version: {version}'**
  String appVersionLine(String version);

  /// No description provided for @hasDeviceSettingsLine.
  ///
  /// In en, this message translates to:
  /// **'Device settings included: {value}'**
  String hasDeviceSettingsLine(String value);

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @integrityPassed.
  ///
  /// In en, this message translates to:
  /// **'Integrity check passed: the file can be read safely.'**
  String get integrityPassed;

  /// No description provided for @integrityUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Integrity: unchecked (run Check to read and verify)'**
  String get integrityUnchecked;

  /// No description provided for @cannotReadBackup.
  ///
  /// In en, this message translates to:
  /// **'Can\'t Read'**
  String get cannotReadBackup;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @backupUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This backup can\'t be read: {problem}'**
  String backupUnreadable(String problem);

  /// No description provided for @mergeRestore.
  ///
  /// In en, this message translates to:
  /// **'Merge Backup'**
  String get mergeRestore;

  /// No description provided for @mergeRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'Adds only words and answers this device is missing. Existing data and progress are kept. This is the safe default.'**
  String get mergeRestoreBody;

  /// No description provided for @mergeComplete.
  ///
  /// In en, this message translates to:
  /// **'Merge complete.'**
  String get mergeComplete;

  /// No description provided for @restoreVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore This Version?'**
  String get restoreVersionTitle;

  /// No description provided for @restoreVersionBody.
  ///
  /// In en, this message translates to:
  /// **'Study data on this device returns to the selected version. Changes made after that backup are removed from the current data.\n\nThe current data is backed up automatically first, and sync is paused.'**
  String get restoreVersionBody;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoredProtected.
  ///
  /// In en, this message translates to:
  /// **'Restored. The previous state was saved as {file}.'**
  String restoredProtected(String file);

  /// No description provided for @restoreNextStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Restored: What About the Remote Data?'**
  String get restoreNextStepTitle;

  /// No description provided for @restoreNextStepBody.
  ///
  /// In en, this message translates to:
  /// **'This device now holds the selected version and sync is paused. Choose the next step:\n\n· Keep this device: don\'t sync yet; handle it later on the Sync page.\n· Merge remote data: bring the other device\'s data in (adds only).\n· Use a new target: point sync at a different remote location.'**
  String get restoreNextStepBody;

  /// No description provided for @keepLocalState.
  ///
  /// In en, this message translates to:
  /// **'Keep This Device'**
  String get keepLocalState;

  /// No description provided for @useNewTarget.
  ///
  /// In en, this message translates to:
  /// **'Use a New Target'**
  String get useNewTarget;

  /// No description provided for @mergeRemoteData.
  ///
  /// In en, this message translates to:
  /// **'Merge Remote Data'**
  String get mergeRemoteData;

  /// No description provided for @syncPausedRemoteUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Sync stays paused. The remote data was not changed.'**
  String get syncPausedRemoteUnchanged;

  /// No description provided for @noSyncTargetHint.
  ///
  /// In en, this message translates to:
  /// **'No sync target configured. Set one on the Sync page.'**
  String get noSyncTargetHint;

  /// No description provided for @remoteMerged.
  ///
  /// In en, this message translates to:
  /// **'Remote data merged.'**
  String get remoteMerged;

  /// No description provided for @syncStillPausedUntilTarget.
  ///
  /// In en, this message translates to:
  /// **'Sync stays paused until one sync completes with the new target.'**
  String get syncStillPausedUntilTarget;

  /// No description provided for @deleteBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Backup?'**
  String get deleteBackupTitle;

  /// No description provided for @deleteBackupBody.
  ///
  /// In en, this message translates to:
  /// **'{name}\n\nOnly this local file is deleted. Study data in the database is not affected.'**
  String deleteBackupBody(String name);

  /// No description provided for @backupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Backup deleted.'**
  String get backupDeleted;

  /// No description provided for @backupExportedShort.
  ///
  /// In en, this message translates to:
  /// **'Backup exported.'**
  String get backupExportedShort;

  /// No description provided for @syncPausedBanner.
  ///
  /// In en, this message translates to:
  /// **'Sync Paused'**
  String get syncPausedBanner;

  /// No description provided for @syncPausedBannerBody.
  ///
  /// In en, this message translates to:
  /// **'This data came from a restore and hasn\'t been checked against the remote copy. Automatic sync stays off until you confirm how to handle the remote data on the Sync page.'**
  String get syncPausedBannerBody;

  /// No description provided for @handleSync.
  ///
  /// In en, this message translates to:
  /// **'Open Sync'**
  String get handleSync;

  /// No description provided for @autoBackupLocal.
  ///
  /// In en, this message translates to:
  /// **'Automatic Backup (Local)'**
  String get autoBackupLocal;

  /// No description provided for @autoBackupDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily Automatic Backup'**
  String get autoBackupDaily;

  /// No description provided for @autoBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Checked at launch, on resume and while the app stays open. A new copy is written only when data changed, keeping the last {count}.'**
  String autoBackupHint(int count);

  /// No description provided for @lastAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Last Automatic Backup'**
  String get lastAutoBackup;

  /// No description provided for @noAutoBackupYet.
  ///
  /// In en, this message translates to:
  /// **'No automatic backup yet'**
  String get noAutoBackupYet;

  /// No description provided for @manualBackupJson.
  ///
  /// In en, this message translates to:
  /// **'Manual Backup (JSON)'**
  String get manualBackupJson;

  /// No description provided for @exportTo.
  ///
  /// In en, this message translates to:
  /// **'Export Backup…'**
  String get exportTo;

  /// No description provided for @exportToHint.
  ///
  /// In en, this message translates to:
  /// **'Saves anywhere through the system file picker (includes device settings).'**
  String get exportToHint;

  /// No description provided for @saveBackupNow.
  ///
  /// In en, this message translates to:
  /// **'Save Backup Now'**
  String get saveBackupNow;

  /// No description provided for @saveBackupNowHint.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device and restorable from the list below.'**
  String get saveBackupNowHint;

  /// No description provided for @importAndMerge.
  ///
  /// In en, this message translates to:
  /// **'Import and Merge'**
  String get importAndMerge;

  /// No description provided for @importAndMergeHint.
  ///
  /// In en, this message translates to:
  /// **'Never overwrites local data: merges after de-duplicating words and answers.'**
  String get importAndMergeHint;

  /// No description provided for @backupContentsNote.
  ///
  /// In en, this message translates to:
  /// **'A backup contains words, word lists, links (including delete marks), answer history, favorites, tags, study goals and device settings. It never contains accounts, passwords or sync credentials.'**
  String get backupContentsNote;

  /// No description provided for @localBackups.
  ///
  /// In en, this message translates to:
  /// **'Local Backups'**
  String get localBackups;

  /// No description provided for @noLocalBackups.
  ///
  /// In en, this message translates to:
  /// **'No backups yet. An automatic backup or Save Backup Now will appear here.'**
  String get noLocalBackups;

  /// No description provided for @backupActions.
  ///
  /// In en, this message translates to:
  /// **'Backup Actions'**
  String get backupActions;

  /// No description provided for @viewInfo.
  ///
  /// In en, this message translates to:
  /// **'View Info'**
  String get viewInfo;

  /// No description provided for @checkIntegrity.
  ///
  /// In en, this message translates to:
  /// **'Check Backup'**
  String get checkIntegrity;

  /// No description provided for @mergeRestoreSafe.
  ///
  /// In en, this message translates to:
  /// **'Merge Backup'**
  String get mergeRestoreSafe;

  /// No description provided for @restoreThisVersion.
  ///
  /// In en, this message translates to:
  /// **'Restore This Version…'**
  String get restoreThisVersion;

  /// No description provided for @deleteBackup.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteBackup;

  /// No description provided for @restoreModesNote.
  ///
  /// In en, this message translates to:
  /// **'Merging only adds what is missing, so it is idempotent and safe to repeat. Restoring a version replaces this device\'s data atomically, saves a safety backup first, and pauses sync until you decide how to handle the remote copy.'**
  String get restoreModesNote;

  /// No description provided for @crossDeviceSync.
  ///
  /// In en, this message translates to:
  /// **'Cross-device Sync'**
  String get crossDeviceSync;

  /// No description provided for @openSync.
  ///
  /// In en, this message translates to:
  /// **'Open Sync'**
  String get openSync;

  /// No description provided for @syncTargetsHint.
  ///
  /// In en, this message translates to:
  /// **'GitHub / WebDAV / local file'**
  String get syncTargetsHint;

  /// No description provided for @mergeNeverOverwrites.
  ///
  /// In en, this message translates to:
  /// **'A merge only adds missing content and never overwrites existing words or answers. Importing the same file twice does not double-count.'**
  String get mergeNeverOverwrites;

  /// No description provided for @mergeRulesAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Merge Rules (Advanced)'**
  String get mergeRulesAdvanced;

  /// No description provided for @mergeRulesBody.
  ///
  /// In en, this message translates to:
  /// **'Answers are de-duplicated by global id and learning state is recalculated from the merged history. Word-list links carry versions and delete marks, so an old backup cannot revive a removed word.'**
  String get mergeRulesBody;

  /// No description provided for @syncUploadPending.
  ///
  /// In en, this message translates to:
  /// **'Local data is saved. Upload is pending.'**
  String get syncUploadPending;

  /// No description provided for @syncConflictRetry.
  ///
  /// In en, this message translates to:
  /// **'Another device changed the data. Try syncing again.'**
  String get syncConflictRetry;

  /// No description provided for @syncFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the sync file.'**
  String get syncFileUnreadable;

  /// No description provided for @backupInfoSummary.
  ///
  /// In en, this message translates to:
  /// **'{words} words · {books} word lists · {entries} links · {events} answers'**
  String backupInfoSummary(int words, int books, int entries, int events);

  /// No description provided for @backupInfoTags.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String backupInfoTags(int count);

  /// No description provided for @backupInfoFavorites.
  ///
  /// In en, this message translates to:
  /// **'{count} favorites'**
  String backupInfoFavorites(int count);

  /// No description provided for @backupInfoUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Unreadable: {reason}'**
  String backupInfoUnreadable(String reason);

  /// No description provided for @unknownReason.
  ///
  /// In en, this message translates to:
  /// **'unknown reason'**
  String get unknownReason;

  /// No description provided for @mergeSummaryEvents.
  ///
  /// In en, this message translates to:
  /// **'{count} new answers'**
  String mergeSummaryEvents(int count);

  /// No description provided for @mergeSummaryDuplicates.
  ///
  /// In en, this message translates to:
  /// **'{count} duplicates ignored'**
  String mergeSummaryDuplicates(int count);

  /// No description provided for @mergeSummaryNewWords.
  ///
  /// In en, this message translates to:
  /// **'{count} new words'**
  String mergeSummaryNewWords(int count);

  /// No description provided for @mergeSummaryUpdatedWords.
  ///
  /// In en, this message translates to:
  /// **'{count} words updated'**
  String mergeSummaryUpdatedWords(int count);

  /// No description provided for @mergeSummaryDeletedWords.
  ///
  /// In en, this message translates to:
  /// **'{count} deletions applied'**
  String mergeSummaryDeletedWords(int count);

  /// No description provided for @mergeSummaryNewBooks.
  ///
  /// In en, this message translates to:
  /// **'{count} new word lists'**
  String mergeSummaryNewBooks(int count);

  /// No description provided for @mergeSummaryNewEntries.
  ///
  /// In en, this message translates to:
  /// **'{count} links added'**
  String mergeSummaryNewEntries(int count);

  /// No description provided for @mergeSummaryRemovedEntries.
  ///
  /// In en, this message translates to:
  /// **'{count} links removed'**
  String mergeSummaryRemovedEntries(int count);

  /// No description provided for @mergeSummaryRebuiltStates.
  ///
  /// In en, this message translates to:
  /// **'{count} progress rows recalculated'**
  String mergeSummaryRebuiltStates(int count);

  /// No description provided for @mergeSummaryMetadata.
  ///
  /// In en, this message translates to:
  /// **'{count} favorite or tag changes'**
  String mergeSummaryMetadata(int count);

  /// No description provided for @mergeSummaryConflicts.
  ///
  /// In en, this message translates to:
  /// **'{count} content conflicts (the newer value was kept)'**
  String mergeSummaryConflicts(int count);

  /// No description provided for @restoreSummary.
  ///
  /// In en, this message translates to:
  /// **'Restored {words} words and {events} answers. The previous state was saved as a safety backup.'**
  String restoreSummary(int words, int events);

  /// No description provided for @importOutcomeCreated.
  ///
  /// In en, this message translates to:
  /// **'{count} added'**
  String importOutcomeCreated(int count);

  /// No description provided for @importOutcomeRevived.
  ///
  /// In en, this message translates to:
  /// **'{count} restored'**
  String importOutcomeRevived(int count);

  /// No description provided for @importOutcomeExisting.
  ///
  /// In en, this message translates to:
  /// **'{count} already present'**
  String importOutcomeExisting(int count);

  /// No description provided for @importOutcomeUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count} updated'**
  String importOutcomeUpdated(int count);

  /// No description provided for @importOutcomeLinked.
  ///
  /// In en, this message translates to:
  /// **'{count} linked to the word list'**
  String importOutcomeLinked(int count);

  /// No description provided for @importOutcomeBooks.
  ///
  /// In en, this message translates to:
  /// **'across {count} word lists'**
  String importOutcomeBooks(int count);

  /// No description provided for @importOutcomeSkippedDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count} deleted words skipped'**
  String importOutcomeSkippedDeleted(int count);

  /// No description provided for @importOutcomeDuplicates.
  ///
  /// In en, this message translates to:
  /// **'{count} duplicates in the file'**
  String importOutcomeDuplicates(int count);

  /// No description provided for @importOutcomeInvalid.
  ///
  /// In en, this message translates to:
  /// **'{count} invalid lines ignored'**
  String importOutcomeInvalid(int count);

  /// No description provided for @importOutcomeSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get importOutcomeSeparator;

  /// No description provided for @backupSavedAs.
  ///
  /// In en, this message translates to:
  /// **'Backup saved: {name}'**
  String backupSavedAs(String name);

  /// No description provided for @mergeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{words} words, {books} word lists, {events} answers.\nBackup time: {time}\nMerges into this device, keeps the existing history and deletes nothing.'**
  String mergeConfirmBody(int words, int books, int events, String time);

  /// No description provided for @timeNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'not recorded'**
  String get timeNotRecorded;

  /// No description provided for @mergeRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'{summary}\n\nMerging only adds what this device is missing and keeps existing data and progress. This is the safe default.'**
  String mergeRestoreConfirm(String summary);

  /// No description provided for @mergeCompleteWith.
  ///
  /// In en, this message translates to:
  /// **'Merge complete: {summary}'**
  String mergeCompleteWith(String summary);

  /// No description provided for @restoreSnapshotConfirm.
  ///
  /// In en, this message translates to:
  /// **'{summary}\nCreated: {created}\n\nThis replaces the current data on this device: answers, edits and deletions made after that backup are removed from it. A safety backup is written first, and a failure rolls everything back. Sync stays paused afterwards until you decide what to do with the remote data.'**
  String restoreSnapshotConfirm(String summary, String created);

  /// No description provided for @restoreDoneWith.
  ///
  /// In en, this message translates to:
  /// **'{summary} The previous state was saved as {file}.'**
  String restoreDoneWith(String summary, String file);

  /// No description provided for @createdUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get createdUnknown;

  /// No description provided for @autoBackupHintCount.
  ///
  /// In en, this message translates to:
  /// **'Checked at launch, on resume and while the app stays open. A new copy is written only when data changed, keeping the last {count}.'**
  String autoBackupHintCount(int count);

  /// No description provided for @syncStageIdle.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get syncStageIdle;

  /// No description provided for @syncStageValidating.
  ///
  /// In en, this message translates to:
  /// **'Checking settings'**
  String get syncStageValidating;

  /// No description provided for @syncStageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Reading remote data'**
  String get syncStageDownloading;

  /// No description provided for @syncStageMerging.
  ///
  /// In en, this message translates to:
  /// **'Merging'**
  String get syncStageMerging;

  /// No description provided for @syncStageRebuilding.
  ///
  /// In en, this message translates to:
  /// **'Updating progress'**
  String get syncStageRebuilding;

  /// No description provided for @syncStageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get syncStageUploading;

  /// No description provided for @syncStageVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying upload'**
  String get syncStageVerifying;

  /// No description provided for @syncStageDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get syncStageDone;

  /// No description provided for @syncStageMergedNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'Saved locally, upload pending'**
  String get syncStageMergedNotUploaded;

  /// No description provided for @syncStageWaitingBackoff.
  ///
  /// In en, this message translates to:
  /// **'Waiting to retry'**
  String get syncStageWaitingBackoff;

  /// No description provided for @syncStageAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed'**
  String get syncStageAuthFailed;

  /// No description provided for @syncStageRemoteMissing.
  ///
  /// In en, this message translates to:
  /// **'Remote data missing'**
  String get syncStageRemoteMissing;

  /// No description provided for @syncStageRemoteCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Remote data unreadable'**
  String get syncStageRemoteCorrupt;

  /// No description provided for @syncStageConfigChanged.
  ///
  /// In en, this message translates to:
  /// **'Settings changed'**
  String get syncStageConfigChanged;

  /// No description provided for @syncStagePausedAfterRestore.
  ///
  /// In en, this message translates to:
  /// **'Paused after restore'**
  String get syncStagePausedAfterRestore;

  /// No description provided for @syncStageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get syncStageFailed;

  /// No description provided for @webDavServerResponded.
  ///
  /// In en, this message translates to:
  /// **'The server responded.'**
  String get webDavServerResponded;

  /// No description provided for @webDavFolderBrowsable.
  ///
  /// In en, this message translates to:
  /// **'The folder is accessible and can be browsed.'**
  String get webDavFolderBrowsable;

  /// No description provided for @webDavFolderAccessible.
  ///
  /// In en, this message translates to:
  /// **'The folder is accessible.'**
  String get webDavFolderAccessible;

  /// No description provided for @webDavProbeReadWrite.
  ///
  /// In en, this message translates to:
  /// **'The test file was written and read back.'**
  String get webDavProbeReadWrite;

  /// No description provided for @syncCapabilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Connection not verified'**
  String get syncCapabilityUnknown;

  /// No description provided for @syncCapabilityConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server'**
  String get syncCapabilityConnectionFailed;

  /// No description provided for @syncCapabilityAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Check the account and password.'**
  String get syncCapabilityAuthFailed;

  /// No description provided for @syncCapabilityRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'The server could not process the WebDAV request'**
  String get syncCapabilityRequestRejected;

  /// No description provided for @syncCapabilityNoFolder.
  ///
  /// In en, this message translates to:
  /// **'Connected, but this folder isn\'t accessible'**
  String get syncCapabilityNoFolder;

  /// No description provided for @syncCapabilityReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Connected, but read-only'**
  String get syncCapabilityReadOnly;

  /// No description provided for @syncCapabilityUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Basic file access works, but safe syncing could not be verified'**
  String get syncCapabilityUnsafe;

  /// No description provided for @syncCapabilitySnapshot.
  ///
  /// In en, this message translates to:
  /// **'Connected. Sync uses versioned snapshots.'**
  String get syncCapabilitySnapshot;

  /// No description provided for @syncCapabilitySafe.
  ///
  /// In en, this message translates to:
  /// **'Connected. Ready to sync.'**
  String get syncCapabilitySafe;

  /// No description provided for @syncResultSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncResultSynced;

  /// No description provided for @syncResultUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get syncResultUnchanged;

  /// No description provided for @syncResultRemoteHasData.
  ///
  /// In en, this message translates to:
  /// **'Remote already has this data'**
  String get syncResultRemoteHasData;

  /// No description provided for @syncResultInitialised.
  ///
  /// In en, this message translates to:
  /// **'Remote file initialised from this device'**
  String get syncResultInitialised;

  /// No description provided for @syncResultPartial.
  ///
  /// In en, this message translates to:
  /// **'Saved locally, upload pending'**
  String get syncResultPartial;

  /// No description provided for @syncResultFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncResultFailed;

  /// No description provided for @syncResultSyncedWith.
  ///
  /// In en, this message translates to:
  /// **'Synced: {summary}'**
  String syncResultSyncedWith(String summary);

  /// No description provided for @syncResultUnknown.
  ///
  /// In en, this message translates to:
  /// **'Sync finished'**
  String get syncResultUnknown;

  /// No description provided for @syncTestOk.
  ///
  /// In en, this message translates to:
  /// **'Connection verified'**
  String get syncTestOk;

  /// No description provided for @syncTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection check failed'**
  String get syncTestFailed;

  /// No description provided for @voiceVariantUS.
  ///
  /// In en, this message translates to:
  /// **'US'**
  String get voiceVariantUS;

  /// No description provided for @voiceVariantUK.
  ///
  /// In en, this message translates to:
  /// **'UK'**
  String get voiceVariantUK;

  /// No description provided for @voiceVariantAU.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get voiceVariantAU;

  /// No description provided for @voiceVariantCA.
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get voiceVariantCA;

  /// No description provided for @voiceVariantIE.
  ///
  /// In en, this message translates to:
  /// **'Ireland'**
  String get voiceVariantIE;

  /// No description provided for @voiceVariantIN.
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get voiceVariantIN;

  /// No description provided for @importIssueNotEnglish.
  ///
  /// In en, this message translates to:
  /// **'Not a valid English word'**
  String get importIssueNotEnglish;

  /// No description provided for @importIssueRowInvalid.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: the word field is invalid'**
  String importIssueRowInvalid(int row);

  /// No description provided for @importIssueNotEntry.
  ///
  /// In en, this message translates to:
  /// **'Not a valid entry (expected text or an object)'**
  String get importIssueNotEntry;

  /// No description provided for @importIssueInvalidEntry.
  ///
  /// In en, this message translates to:
  /// **'Invalid entry'**
  String get importIssueInvalidEntry;

  /// No description provided for @importIssueEmpty.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get importIssueEmpty;

  /// No description provided for @exportFormatTxt.
  ///
  /// In en, this message translates to:
  /// **'Plain text (one word per line)'**
  String get exportFormatTxt;

  /// No description provided for @exportFormatCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV (with meanings and examples)'**
  String get exportFormatCsv;

  /// No description provided for @exportFormatJson.
  ///
  /// In en, this message translates to:
  /// **'JSON (structured, lossless round trip)'**
  String get exportFormatJson;

  /// No description provided for @createFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the folder. Check the permissions and try again.'**
  String get createFolderFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
