/// Time-of-day helpers used by the sleep tracker and habit reminders.
///
/// Times are stored as `HH:mm` (24-hour) strings.
library;

import 'date_utils.dart';

final RegExp _hmPattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

/// Minutes since midnight for an `HH:mm` string, or null when malformed.
int? parseHm(String s) {
  final m = _hmPattern.firstMatch(s);
  if (m == null) return null;
  return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

/// `HH:mm` for minutes since midnight. Values wrap around 24 hours.
String hmFromMinutes(int minutes) {
  final m = ((minutes % 1440) + 1440) % 1440;
  return '${two(m ~/ 60)}:${two(m % 60)}';
}

/// "11:30 PM" for `23:30`. Returns the input unchanged if it is malformed.
String format12h(String hm) {
  final m = parseHm(hm);
  if (m == null) return hm;
  final h24 = m ~/ 60;
  final minute = m % 60;
  final suffix = h24 >= 12 ? 'PM' : 'AM';
  var h = h24 % 12;
  if (h == 0) h = 12;
  return '$h:${two(minute)} $suffix';
}

/// Minutes slept between [bedtime] and [wakeTime] (both `HH:mm`).
///
/// If the wake time is earlier than the bedtime the sleep crossed midnight,
/// so 23:00 -> 07:00 is 480 minutes. Identical times give 0 (invalid
/// entry); a full 24h sleep is not representable by design.
int sleepDurationMinutes(String bedtime, String wakeTime) {
  final bed = parseHm(bedtime);
  final wake = parseHm(wakeTime);
  if (bed == null || wake == null) return 0;
  return (wake - bed + 1440) % 1440;
}
