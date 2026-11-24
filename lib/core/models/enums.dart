/// Domain enums shared by the scheduler, repositories and UI.
///
/// The numeric/string values are persisted in SQLite and in the sync protocol,
/// so they must never be renumbered.
library;

/// The three answer levels the user can pick for a card.
enum AnswerResult {
  unknown(0, '不认识'),
  hazy(1, '模糊'),
  known(2, '认识');

  const AnswerResult(this.code, this.label);

  final int code;
  final String label;

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
  newWord(0, '未学习'),

  /// Answered at least once, still on the short learning steps.
  learning(1, '学习中'),

  /// On the long-term review ladder (1/3/7/14/30 days).
  review(2, '复习中'),

  /// Recently failed; must be re-learnt before returning to the ladder.
  relearning(3, '重学中');

  const StudyStage(this.code, this.label);

  final int code;
  final String label;

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
  system('system', '跟随系统'),
  light('light', '浅色'),
  dark('dark', '深色');

  const ThemePreference(this.code, this.label);

  final String code;
  final String label;

  static ThemePreference fromCode(String? code) =>
      ThemePreference.values.firstWhere(
        (ThemePreference v) => v.code == code,
        orElse: () => ThemePreference.system,
      );
}

/// How the study session builds its queue.
enum StudyMode {
  mixed('mixed', '新词 + 复习'),
  newOnly('new', '仅新词'),
  reviewOnly('review', '仅复习'),
  special('special', '专项复习');

  const StudyMode(this.code, this.label);

  final String code;
  final String label;

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
  none('none', '普通学习'),
  hard('hard', '困难词专项'),
  recentMistakes('mistakes', '近期错误专项'),
  inBook('book', '词书内专项');

  const SpecialReview(this.code, this.label);

  final String code;
  final String label;

  static SpecialReview fromCode(String? code) =>
      SpecialReview.values.firstWhere(
        (SpecialReview v) => v.code == code,
        orElse: () => SpecialReview.none,
      );
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

  /// Recorded when the user marks a word as mastered by hand.
  static const String manualMastered = 'manual-mastered';

  /// Recorded when the user resets the word's progress. Replay treats it as
  /// "forget everything before this point".
  static const String reset = 'reset';

  static bool isReset(String? value) => value == reset;

  static String forSpecial(SpecialReview review) => switch (review) {
    SpecialReview.hard => specialHard,
    SpecialReview.recentMistakes => specialMistakes,
    SpecialReview.inBook => specialBook,
    SpecialReview.none => normal,
  };
}

/// Sort order of the word-management list.
enum ManagedSort {
  addedDesc('added', '添加时间（新→旧）'),
  alpha('alpha', '字母顺序'),
  wrongDesc('wrong', '错误次数（多→少）'),
  lastStudiedDesc('last', '最近学习时间');

  const ManagedSort(this.code, this.label);

  final String code;
  final String label;

  static ManagedSort fromCode(String? code) => ManagedSort.values.firstWhere(
    (ManagedSort v) => v.code == code,
    orElse: () => ManagedSort.addedDesc,
  );
}

/// Learning-state filter of the word-management list.
enum ManagedStageFilter {
  all('all', '全部'),
  unlearned('unlearned', '未学习'),
  learning('learning', '学习中'),
  review('review', '复习中'),
  relearning('relearning', '重学中'),
  hard('hard', '困难词'),
  mastered('mastered', '已掌握');

  const ManagedStageFilter(this.code, this.label);

  final String code;
  final String label;

  static ManagedStageFilter fromCode(String? code) =>
      ManagedStageFilter.values.firstWhere(
        (ManagedStageFilter v) => v.code == code,
        orElse: () => ManagedStageFilter.all,
      );
}
