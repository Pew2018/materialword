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
  reviewOnly('review', '仅复习');

  const StudyMode(this.code, this.label);

  final String code;
  final String label;

  static StudyMode fromCode(String? code) => StudyMode.values.firstWhere(
    (StudyMode v) => v.code == code,
    orElse: () => StudyMode.mixed,
  );
}
