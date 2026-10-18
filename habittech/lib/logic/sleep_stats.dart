import '../core/date_utils.dart';
import '../models/sleep_entry.dart';

/// Informal duration descriptions shown on the sleep tracker. They describe
/// how long someone slept; they are not medical categories.
class SleepPreset {
  const SleepPreset(this.hours, this.label);
  final int hours;
  final String label;
  int get minutes => hours * 60;
}

const List<SleepPreset> kSleepPresets = [
  SleepPreset(5, 'Fair'),
  SleepPreset(6, 'Good'),
  SleepPreset(7, 'Great'),
  SleepPreset(8, 'Optimal'),
  SleepPreset(9, 'Deep'),
];

class SleepStats {
  SleepStats({
    required List<SleepEntry> entries,
    required DateTime now,
    required this.goalMinutes,
  })  : today = dayOnly(now),
        _byDate = {for (final e in entries) e.date: e};

  final DateTime today;
  final int goalMinutes;
  final Map<String, SleepEntry> _byDate;

  SleepEntry? entryOn(DateTime day) => _byDate[dateKey(day)];

  /// Entries for the last [days] days ending today (oldest first); a night
  /// without an entry has null minutes.
  List<({DateTime date, int? minutes})> lastDays(int days) => [
        for (var i = days - 1; i >= 0; i--)
          (
            date: addDays(today, -i),
            minutes: entryOn(addDays(today, -i))?.durationMinutes,
          ),
      ];

  /// Average over the nights that were logged in the last 7 days, or null
  /// when none were.
  double? weeklyAverageMinutes() {
    final logged = lastDays(7).where((e) => e.minutes != null).toList();
    if (logged.isEmpty) return null;
    final total = logged.fold<int>(0, (sum, e) => sum + (e.minutes ?? 0));
    return total / logged.length;
  }

  int nightsLoggedLast7() => lastDays(7).where((e) => e.minutes != null).length;

  /// Positive when the weekly average beats the goal.
  double? weeklyDeltaVsGoal() {
    final avg = weeklyAverageMinutes();
    return avg == null ? null : avg - goalMinutes;
  }

  /// Entries in the given month, newest first.
  List<SleepEntry> entriesInMonth(int year, int month) {
    final prefix = '$year-${two(month)}-';
    final list = _byDate.values.where((e) => e.date.startsWith(prefix)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  double? monthAverageMinutes(int year, int month) {
    final list = entriesInMonth(year, month);
    if (list.isEmpty) return null;
    return list.fold<int>(0, (s, e) => s + e.durationMinutes) / list.length;
  }

  /// Number of logged nights in the last 7 days that reached the goal.
  int nightsMeetingGoalLast7() => lastDays(7)
      .where((e) => e.minutes != null && e.minutes! >= goalMinutes)
      .length;
}
