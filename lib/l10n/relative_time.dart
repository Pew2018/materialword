import 'l10n.dart';

/// "3 minutes ago" / "in 2 days", resolved for the current language.
///
/// Kept out of `core/time_utils.dart` on purpose: the core layer must not depend
/// on a language, so it only formats absolute timestamps.
String relativeTime(DateTime moment, DateTime now, AppLocalizations l10n) {
  final Duration diff = moment.difference(now);
  final bool future = !diff.isNegative;
  final Duration abs = diff.abs();
  final String value;
  if (abs.inMinutes < 1) {
    return l10n.timeJustNow;
  } else if (abs.inMinutes < 60) {
    value = l10n.timeValue(abs.inMinutes);
  } else if (abs.inHours < 24) {
    value = l10n.timeHoursValue(abs.inHours);
  } else if (abs.inDays < 30) {
    value = l10n.timeDaysValue(abs.inDays);
  } else if (abs.inDays < 365) {
    value = l10n.timeMonthsValue(abs.inDays ~/ 30);
  } else {
    value = l10n.timeYearsValue(abs.inDays ~/ 365);
  }
  return future ? l10n.timeIn(value) : l10n.timeAgo(value);
}
