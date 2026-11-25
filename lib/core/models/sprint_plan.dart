class SprintPlan {
  const SprintPlan({
    this.enabled = false,
    this.examDate,
    this.bookId,
    this.roundSize = 30,
    this.prioritizeHard = true,
    this.prioritizeRecent = true,
    this.prioritizeUnmastered = true,
    this.includeUnlearned = false,
    this.allowOverReviewLimit = false,
  });

  final bool enabled,
      prioritizeHard,
      prioritizeRecent,
      prioritizeUnmastered,
      includeUnlearned,
      allowOverReviewLimit;
  final String? examDate, bookId;
  final int roundSize;

  Map<String, Object?> toJson() => {
    'version': 1,
    'enabled': enabled,
    'examDate': examDate,
    'bookId': bookId,
    'roundSize': roundSize,
    'prioritizeHard': prioritizeHard,
    'prioritizeRecent': prioritizeRecent,
    'prioritizeUnmastered': prioritizeUnmastered,
    'includeUnlearned': includeUnlearned,
    'allowOverReviewLimit': allowOverReviewLimit,
  };

  factory SprintPlan.fromJson(Map<String, Object?> data) {
    if (data['version'] is! int || data['version'] != 1) {
      throw const FormatException('不支持的冲刺计划版本');
    }
    for (final key in [
      'enabled',
      'prioritizeHard',
      'prioritizeRecent',
      'prioritizeUnmastered',
      'includeUnlearned',
      'allowOverReviewLimit',
    ]) {
      if (data[key] is! bool) throw const FormatException('冲刺计划开关无效');
    }
    final date = data['examDate'],
        book = data['bookId'],
        size = data['roundSize'];
    if (date != null) {
      if (date is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
        throw const FormatException('考试日期无效');
      }
      final parts = date.split('-').map(int.parse).toList();
      final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
      if (parsed.year != parts[0] ||
          parsed.month != parts[1] ||
          parsed.day != parts[2]) {
        throw const FormatException('考试日期无效');
      }
    }
    if (book != null &&
        (book is! String || book.trim().isEmpty || book.trim() != book)) {
      throw const FormatException('冲刺词书无效');
    }
    if (size is! int || size < 1 || size > 500) {
      throw const FormatException('每轮单词数量须为 1–500');
    }
    if (data['enabled'] == true && (date == null || book == null)) {
      throw const FormatException('请选择考试日期和目标词书');
    }
    return SprintPlan(
      enabled: data['enabled'] as bool,
      examDate: date as String?,
      bookId: book as String?,
      roundSize: size,
      prioritizeHard: data['prioritizeHard'] as bool,
      prioritizeRecent: data['prioritizeRecent'] as bool,
      prioritizeUnmastered: data['prioritizeUnmastered'] as bool,
      includeUnlearned: data['includeUnlearned'] as bool,
      allowOverReviewLimit: data['allowOverReviewLimit'] as bool,
    );
  }

  int? daysUntil(DateTime now) {
    if (examDate == null) return null;
    final date = examDate!.split('-').map(int.parse).toList(),
        local = now.toLocal();
    return DateTime.utc(
      date[0],
      date[1],
      date[2],
    ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
  }
}

class SprintOverview {
  const SprintOverview({
    required this.total,
    required this.unlearned,
    required this.hard,
    required this.recentMistakes,
    required this.eligible,
    required this.reviewAllowance,
    required this.wordIds,
    required this.bookAvailable,
  });
  final int total, unlearned, hard, recentMistakes, eligible, reviewAllowance;
  final List<String> wordIds;
  final bool bookAvailable;
}
