import '../app/theme.dart';
import '../core/models/enums.dart';
import '../services/word_form_guesser.dart';
import 'l10n.dart';

/// Display names for the domain enums.
///
/// The enums themselves only carry *persistence* values (numeric codes and
/// protocol ids). Every user-visible name lives here, so the same value cannot
/// be called "困难词专项" on one page and "困难词复习" on another, and so the
/// database and the sync protocol are completely language-independent.
extension AnswerResultLabels on AnswerResult {
  String label(AppLocalizations l10n) => switch (this) {
    AnswerResult.unknown => l10n.answerDontKnow,
    AnswerResult.hazy => l10n.answerNotSure,
    AnswerResult.known => l10n.answerKnow,
  };
}

extension StudyStageLabels on StudyStage {
  String label(AppLocalizations l10n) => switch (this) {
    StudyStage.newWord => l10n.stageNotStudied,
    StudyStage.learning => l10n.stageLearning,
    StudyStage.review => l10n.stageReviewing,
    StudyStage.relearning => l10n.stageRelearning,
  };
}

extension ThemePreferenceLabels on ThemePreference {
  String label(AppLocalizations l10n) => switch (this) {
    ThemePreference.system => l10n.themeSystem,
    ThemePreference.light => l10n.themeLight,
    ThemePreference.dark => l10n.themeDark,
  };
}

extension TypographyScaleLabels on TypographyScale {
  String label(AppLocalizations l10n) => switch (this) {
    TypographyScale.material2014 => l10n.typographyMaterial2014,
    TypographyScale.material2018 => l10n.typographyMaterial2018,
  };
}

extension StudyModeLabels on StudyMode {
  String label(AppLocalizations l10n) => switch (this) {
    StudyMode.mixed => l10n.modeMixed,
    StudyMode.newOnly => l10n.modeNewOnly,
    StudyMode.reviewOnly => l10n.modeReviewOnly,
    StudyMode.special => l10n.modeSpecial,
  };
}

extension SpecialReviewLabels on SpecialReview {
  String label(AppLocalizations l10n) => switch (this) {
    SpecialReview.none => l10n.specialNone,
    SpecialReview.hard => l10n.specialHard,
    SpecialReview.recentMistakes => l10n.specialMistakes,
    SpecialReview.inBook => l10n.specialBook,
    SpecialReview.favorites => l10n.specialFavorites,
    SpecialReview.sessionMistakes => l10n.specialSessionMistakes,
    SpecialReview.sprint => l10n.specialSprint,
  };
}

extension PracticeKindLabels on PracticeKind {
  String label(AppLocalizations l10n) => switch (this) {
    PracticeKind.spelling => l10n.practiceSpelling,
    PracticeKind.dictation => l10n.practiceDictation,
    PracticeKind.choice => l10n.practiceChoice,
    PracticeKind.cloze => l10n.practiceCloze,
  };

  String description(AppLocalizations l10n) => switch (this) {
    PracticeKind.spelling => l10n.practiceSpellingDesc,
    PracticeKind.dictation => l10n.practiceDictationDesc,
    PracticeKind.choice => l10n.practiceChoiceDesc,
    PracticeKind.cloze => l10n.practiceClozeDesc,
  };
}

extension ManagedSortLabels on ManagedSort {
  String label(AppLocalizations l10n) => switch (this) {
    ManagedSort.addedDesc => l10n.sortAddedDesc,
    ManagedSort.alpha => l10n.sortAlpha,
    ManagedSort.wrongDesc => l10n.sortWrongDesc,
    ManagedSort.lastStudiedDesc => l10n.sortLastStudied,
  };
}

extension ManagedStageFilterLabels on ManagedStageFilter {
  String label(AppLocalizations l10n) => switch (this) {
    ManagedStageFilter.all => l10n.filterAll,
    ManagedStageFilter.unlearned => l10n.filterUnlearned,
    ManagedStageFilter.learning => l10n.filterLearning,
    ManagedStageFilter.review => l10n.filterReviewing,
    ManagedStageFilter.relearning => l10n.filterRelearning,
    ManagedStageFilter.hard => l10n.filterHard,
    ManagedStageFilter.mastered => l10n.filterMastered,
  };
}

extension WordFormRelationLabels on WordFormRelation {
  /// Short form used inside a sentence ("… is the past tense or past participle
  /// of run").
  String label(AppLocalizations l10n) => switch (this) {
    WordFormRelation.pluralThirdPerson => l10n.relationPlural,
    WordFormRelation.pastParticiple => l10n.relationPastParticiple,
    WordFormRelation.presentParticiple => l10n.relationPresentParticiple,
    WordFormRelation.comparative => l10n.relationComparative,
    WordFormRelation.superlative => l10n.relationSuperlative,
  };
}

extension AccentPaletteLabels on AccentPalette {
  /// Localised preset name. Never persisted: the colour (or the stable id in
  /// tests) is what is stored.
  String label(AppLocalizations l10n) => switch (id) {
    'classic.clearSkyBlue' => l10n.accentClearSkyBlue,
    'classic.deepSeaBlue' => l10n.accentDeepSeaBlue,
    'classic.goldenOrange' => l10n.accentGoldenOrange,
    'classic.lemonYellow' => l10n.accentLemonYellow,
    'classic.grassGreen' => l10n.accentGrassGreen,
    'classic.jadeGreen' => l10n.accentJadeGreen,
    'classic.violet' => l10n.accentViolet,
    'classic.deepIndigo' => l10n.accentDeepIndigo,
    'classic.skyBlue' => l10n.accentSkyBlue,
    'classic.vibrantPink' => l10n.accentVibrantPink,
    'classic.orchidPink' => l10n.accentOrchidPink,
    'material.blue' => l10n.accentBlue,
    'material.teal' => l10n.accentTeal,
    'material.green' => l10n.accentGreen,
    'material.red' => l10n.accentRed,
    'material.orange' => l10n.accentOrange,
    'material.purple' => l10n.accentPurple,
    'material.cyan' => l10n.accentCyan,
    'material.indigo' => l10n.accentIndigo,
    'material.pink' => l10n.accentPink,
    'material.blueGray' => l10n.accentBlueGray,
    'material.deepOrange' => l10n.accentDeepOrange,
    'material.lightGreen' => l10n.accentLightGreen,
    _ => l10n.accentCustom,
  };
}
