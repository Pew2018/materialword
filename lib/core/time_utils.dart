/// Time helpers.
///
/// Every persisted timestamp is "milliseconds since epoch, UTC". Anything that
/// depends on the calendar day (daily targets, "today's progress", the review
/// queue) is computed in the **device local time zone**, which is also what the
/// user sees on screen.
library;

/// Injectable clock so that scheduler tests can control "now" completely.
abstract class Clock {
  const Clock();

  DateTime now();
}

class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// `2026-11-24` in the local time zone.
String localDayKey(DateTime moment) {
  final DateTime local = moment.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// Local midnight that starts the day containing [moment].
DateTime startOfLocalDay(DateTime moment) {
  final DateTime local = moment.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Local midnight of the following day.
DateTime endOfLocalDay(DateTime moment) {
  final DateTime start = startOfLocalDay(moment);
  return start.add(const Duration(days: 1));
}

/// Midnight after [days] local days, used by the scheduler for day-granular
/// intervals. Anchoring to local midnight means "1 day" really means
/// "tomorrow", not "24 hours from now at 23:58".
DateTime localDayStartPlus(DateTime moment, int days) =>
    startOfLocalDay(moment).add(Duration(days: days));

/// `2026-11-24 21:03`
String formatDateTime(DateTime moment) {
  final DateTime local = moment.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

/// `11-24`
String formatShortDate(DateTime moment) {
  final DateTime local = moment.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)}';
}
