/// Calendar-day helpers.
///
/// HabitTech works with *local calendar days*, never with UTC instants.
/// A day is stored as a `yyyy-MM-dd` key, so a completion recorded at
/// 11:50 PM stays on that day regardless of the device time zone or DST.
library;

const List<String> kMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> kMonthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Indexed by `DateTime.weekday - 1` (Monday first).
const List<String> kWeekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> kWeekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> kWeekdayInitial = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String two(int n) => n.toString().padLeft(2, '0');

/// `yyyy-MM-dd` key for the local calendar day of [d].
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

final RegExp _dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Strictly parses a `yyyy-MM-dd` key. Returns null for anything else,
/// including impossible dates such as `2026-02-30`.
DateTime? tryParseDateKey(String s) {
  if (!_dateKeyPattern.hasMatch(s)) return null;
  final y = int.parse(s.substring(0, 4));
  final m = int.parse(s.substring(5, 7));
  final d = int.parse(s.substring(8, 10));
  final parsed = DateTime(y, m, d);
  if (parsed.year != y || parsed.month != m || parsed.day != d) return null;
  return parsed;
}

DateTime parseDateKey(String s) =>
    tryParseDateKey(s) ??
    (throw FormatException('Invalid date "$s" (expected yyyy-MM-dd)'));

/// Midnight (local) of the day containing [d].
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Adds whole calendar days. Uses the date constructor so DST changes can
/// never shift the result by an hour into the wrong day.
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Whole calendar days from [a] to [b] (negative if [b] is earlier).
int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day))
    .inDays;

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// Number of days in [month] (1-12) of [year]; handles leap years.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// First day of the week containing [d]. [weekStartsOn] uses
/// `DateTime.weekday` numbering (1 = Monday ... 7 = Sunday).
DateTime startOfWeek(DateTime d, int weekStartsOn) {
  final offset = (d.weekday - weekStartsOn + 7) % 7;
  return addDays(dayOnly(d), -offset);
}

/// Weekday numbers (1-7) in display order for a given week start.
List<int> weekdayOrder(int weekStartsOn) =>
    [for (var i = 0; i < 7; i++) ((weekStartsOn - 1 + i) % 7) + 1];

String formatLongDate(DateTime d) =>
    '${kWeekdayShort[d.weekday - 1]}, ${kMonthShort[d.month - 1]} ${d.day}, ${d.year}';

String formatShortDate(DateTime d) => '${kMonthShort[d.month - 1]} ${d.day}';

String formatMonthYear(int year, int month) => '${kMonthNames[month - 1]} $year';

/// "7h 30m", "8h", "45m".
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Formats a number without a trailing ".0".
String formatNumber(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
