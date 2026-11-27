/// Domain enums shared by the scheduler, repositories and UI.
///
/// The numeric/string values are persisted in SQLite and in the sync protocol,
/// so they must never be renumbered. Display names are *not* part of the enums:
/// they live in `lib/l10n` and are resolved per language at the UI boundary.
library;

/// The three answer levels the user can pick for a card.
enum AnswerResult {
  unknown(0),
  hazy(1),
  known(2);

  const AnswerResult(this.code);

  /// Persisted value. Never renumber: it is written to SQLite and to the sync
  /// protocol. The display name comes from `enum_labels.dart`.
  final int code;

  static AnswerResult fromCode(int code) => AnswerResult.values.firstWhere(
    (AnswerResult v) => v.code == code,
    orElse: () => AnswerResult.unknown,
  );

  static AnswerResult? tryParse(Object? value) {
    if (value is int) return fromCode(value);
    if (value is String) {
      final String normalized = value.toLowerCase();
      for (final AnswerResult result in AnswerResult.values) {
        if (result.name == normalized) return result;
      }
      final int? code = int.tryParse(normalized);
      if (code != null) return fromCode(code);
    }
    return null;
  }
}

/// Where a word currently sits in the learning pipeline.
enum StudyStage {
  /// Never answered yet.
  newWord(0),

  /// Answered at least once, still on the short learning steps.
  learning(1),

  /// On the long-term review ladder (1/3/7/14/30 days).
  review(2),

  /// Recently failed; must be re-learnt before returning to the ladder.
  relearning(3);

  const StudyStage(this.code);

  final int code;

  static StudyStage fromCode(int code) => StudyStage.values.firstWhere(
    (StudyStage v) => v.code == code,
    orElse: () => StudyStage.newWord,
  );

  bool get isLearned => this != StudyStage.newWord;
}

/// Whether an answer belongs to the "new words" or the "review" queue.
enum ReviewType {
  study('study'),
  review('review');

  const ReviewType(this.code);

  final String code;

  static ReviewType fromCode(String code) => ReviewType.values.firstWhere(
    (ReviewType v) => v.code == code,
    orElse: () => ReviewType.study,
  );
}

/// Application theme preference.
enum ThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const ThemePreference(this.code);

  final String code;

  static ThemePreference fromCode(String? code) =>
      ThemePreference.values.firstWhere(
        (ThemePreference v) => v.code == code,
        orElse: () => ThemePreference.system,
      );
}

/// Which Material type scale the shell uses.
///
/// `material2014` is the shipped classic scale (with this app's size
/// overrides). `material2018` is Flutter's 2018 geometry with no extra size
/// overrides. The code is stored on this device only.
enum TypographyScale {
  material2014('material2014'),
  material2018('material2018');

  const TypographyScale(this.code);

  final String code;

  static TypographyScale fromCode(String? code) {
    for (final TypographyScale scale in TypographyScale.values) {
      if (scale.code == code) return scale;
    }
    return TypographyScale.material2014;
  }
}

/// How the study session builds its queue.
enum StudyMode {
  mixed('mixed'),
  newOnly('new'),
  reviewOnly('review'),
  special('special');

  const StudyMode(this.code);

  final String code;

  static StudyMode fromCode(String? code) => StudyMode.values.firstWhere(
    (StudyMode v) => v.code == code,
    orElse: () => StudyMode.mixed,
  );
}

/// A special review queue that does not permanently occupy the normal review
/// queue. Answers in these modes are still recorded as ordinary `review`
/// events (so they count towards today's review allowance and move the
/// next-review date), but the queue itself is built from a different filter.
enum SpecialReview {
  none('none'),
  hard('hard'),
  recentMistakes('mistakes'),
  inBook('book'),
  favorites('favorites'),
  sessionMistakes('session-mistakes'),
  sprint('sprint');

  const SpecialReview(this.code);

  final String code;

  static SpecialReview fromCode(String? code) =>
      SpecialReview.values.firstWhere(
        (SpecialReview v) => v.code == code,
        orElse: () => SpecialReview.none,
      );
}

/// Explicit practice drills. They reuse the same event log, statistics and sync
/// path as ordinary answers, but a practice answer never moves the long-term
/// review ladder: spelling a word correctly today says nothing about whether it
/// is still known in 14 days.
enum PracticeKind {
  spelling('spelling'),
  dictation('dictation'),
  choice('choice'),
  cloze('cloze');

  const PracticeKind(this.code);

  final String code;

  static PracticeKind fromCode(String? code) => PracticeKind.values.firstWhere(
    (PracticeKind v) => v.code == code,
    orElse: () => PracticeKind.spelling,
  );

  /// Whether the drill asks the user to type the word (so text normalisation
  /// and case rules apply) instead of picking an option.
  bool get isTyped => this != PracticeKind.choice;
}

/// Explicit event semantics.
///
/// Everything that changes learning state goes through [ReviewEvents] so that
/// a merge cannot silently revert a manual action: "mark as mastered" and
/// "reset progress" are recorded as events (and replayed deterministically)
/// instead of poking the derived `learning_states` row.
class ReviewEventMode {
  const ReviewEventMode._();

  static const String normal = 'normal';
  static const String specialHard = 'special-hard';
  static const String specialMistakes = 'special-mistakes';
  static const String specialBook = 'special-book';
  static const String specialFavorites = 'special-favorites';
  static const String specialSessionMistakes = 'special-session-mistakes';
  static const String specialSprint = 'special-sprint';

  /// Recorded when the user marks a word as mastered by hand.
  static const String manualMastered = 'manual-mastered';

  /// Recorded when the user resets the word's progress. Replay treats it as
  /// "forget everything before this point".
  static const String reset = 'reset';
  static const String manualUnmastered = 'manual-unmastered';
  static const String repeat = 'repeat';
  static const String undoPrefix = 'undo:';

  /// Practice drills prefix their events with this, so replay can keep the
  /// long-term interval untouched while still writing a real, syncable event.
  static const String practicePrefix = 'practice-';

  static bool isManagement(String mode) =>
      mode == reset ||
      mode == manualMastered ||
      mode == manualUnmastered ||
      mode.startsWith(undoPrefix);

  static bool isPractice(String mode) => mode.startsWith(practicePrefix);

  static bool isReset(String? value) => value == reset;

  static String forPractice(PracticeKind kind) => '$practicePrefix${kind.code}';

  static String forSpecial(SpecialReview review) => switch (review) {
    SpecialReview.hard => specialHard,
    SpecialReview.recentMistakes => specialMistakes,
    SpecialReview.inBook => specialBook,
    SpecialReview.favorites => specialFavorites,
    SpecialReview.sessionMistakes => specialSessionMistakes,
    SpecialReview.sprint => specialSprint,
    SpecialReview.none => normal,
  };
}

/// Sort order of the word-management list.
enum ManagedSort {
  addedDesc('added'),
  alpha('alpha'),
  wrongDesc('wrong'),
  lastStudiedDesc('last');

  const ManagedSort(this.code);

  final String code;

  static ManagedSort fromCode(String? code) => ManagedSort.values.firstWhere(
    (ManagedSort v) => v.code == code,
    orElse: () => ManagedSort.addedDesc,
  );
}

/// Learning-state filter of the word-management list.
enum ManagedStageFilter {
  all('all'),
  unlearned('unlearned'),
  learning('learning'),
  review('review'),
  relearning('relearning'),
  hard('hard'),
  mastered('mastered');

  const ManagedStageFilter(this.code);

  final String code;

  static ManagedStageFilter fromCode(String? code) =>
      ManagedStageFilter.values.firstWhere(
        (ManagedStageFilter v) => v.code == code,
        orElse: () => ManagedStageFilter.all,
      );
}
