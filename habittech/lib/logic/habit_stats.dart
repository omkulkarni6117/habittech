/// Habit analytics. Pure functions of stored records: no UI, no storage.
///
/// ## Definitions
///
/// * **Scheduled check-in**: a (habit, day) pair where the habit applies
///   (`Habit.appliesOn`): the day is on/after the start date, on/before the
///   archive day, and on one of the habit's scheduled weekdays.
/// * **Completion rate** over a range = completed check-ins / scheduled
///   check-ins. Days after today are never counted, and a missing record is
///   always "not completed" (never assumed done).
/// * **Successful day**: a day with at least one scheduled habit on which
///   `completed >= min(dailyGoal, scheduled)`.
/// * **Consistency** over a range = successful days / days that had scheduled
///   habits. This is calendar-day consistency and deliberately differs from
///   the completion rate: finishing 5 of 7 habits every day is 71% completion
///   but 100% consistency when the daily goal is 5.
/// * **Streak**: consecutive calendar days that are successful. Days with no
///   scheduled habits are neutral (they neither extend nor break a streak).
///   Today does not break the *current* streak while it is still in
///   progress; it only extends it once the daily goal is met.
/// * **Best streak**: the longest streak found anywhere in the history.
library;

import '../core/date_utils.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';

typedef DayCount = ({int scheduled, int completed});

class RangeStat {
  const RangeStat({
    required this.scheduled,
    required this.completed,
    required this.activeDays,
    required this.successfulDays,
  });

  final int scheduled;
  final int completed;

  /// Days in the range with at least one scheduled habit.
  final int activeDays;
  final int successfulDays;

  /// Null when nothing was scheduled.
  double? get rate => scheduled == 0 ? null : completed / scheduled;

  /// Null when no day had scheduled habits.
  double? get consistency =>
      activeDays == 0 ? null : successfulDays / activeDays;
}

class StreakResult {
  const StreakResult({required this.current, required this.best});
  final int current;
  final int best;
}

class HabitPerformance {
  const HabitPerformance({
    required this.habit,
    required this.scheduled,
    required this.completed,
  });

  final Habit habit;
  final int scheduled;
  final int completed;

  double? get rate => scheduled == 0 ? null : completed / scheduled;
}

class MonthStat {
  const MonthStat({required this.year, required this.month, required this.stat});
  final int year;
  final int month;
  final RangeStat stat;
}

/// Longest history scanned for streaks, as a guard against bad start dates.
const int _maxStreakScanDays = 3660;

class HabitStats {
  HabitStats({
    required this.habits,
    required List<HabitCompletion> completions,
    required this.dailyGoal,
    required DateTime now,
  })  : today = dayOnly(now),
        _done = {
          for (final c in completions)
            if (c.completed) c.id,
        },
        totalCompletedEntries = completions.where((c) => c.completed).length,
        trackedDays = {
          for (final c in completions)
            if (c.completed) c.date,
        }.length;

  final List<Habit> habits;
  final int dailyGoal;
  final DateTime today;

  /// Every completed record, including ones for archived habits.
  final int totalCompletedEntries;

  /// Number of distinct calendar days that have at least one completion.
  final int trackedDays;

  final Set<String> _done;

  bool isDone(String habitId, DateTime day) =>
      _done.contains(HabitCompletion.makeId(habitId, dateKey(day)));

  /// Habits that apply on [day].
  List<Habit> scheduledOn(DateTime day) =>
      habits.where((h) => h.appliesOn(day)).toList();

  DayCount dayCount(DateTime day) {
    var scheduled = 0;
    var completed = 0;
    for (final h in habits) {
      if (!h.appliesOn(day)) continue;
      scheduled++;
      if (isDone(h.id, day)) completed++;
    }
    return (scheduled: scheduled, completed: completed);
  }

  /// Completed / scheduled for one day; null when nothing was scheduled.
  double? dailyRate(DateTime day) {
    final c = dayCount(day);
    return c.scheduled == 0 ? null : c.completed / c.scheduled;
  }

  /// True/false once the daily goal is met/missed; null with no habits.
  bool? isSuccessfulDay(DateTime day) {
    final c = dayCount(day);
    if (c.scheduled == 0) return null;
    final needed = dailyGoal < c.scheduled ? dailyGoal : c.scheduled;
    return c.completed >= needed;
  }

  /// Aggregates [from]..[to] inclusive. The end is clamped to today.
  RangeStat rangeStat(DateTime from, DateTime to) {
    final start = dayOnly(from);
    var end = dayOnly(to);
    if (end.isAfter(today)) end = today;
    var scheduled = 0;
    var completed = 0;
    var activeDays = 0;
    var successfulDays = 0;
    for (var d = start; !d.isAfter(end); d = addDays(d, 1)) {
      final c = dayCount(d);
      if (c.scheduled == 0) continue;
      scheduled += c.scheduled;
      completed += c.completed;
      activeDays++;
      final needed = dailyGoal < c.scheduled ? dailyGoal : c.scheduled;
      if (c.completed >= needed) successfulDays++;
    }
    return RangeStat(
      scheduled: scheduled,
      completed: completed,
      activeDays: activeDays,
      successfulDays: successfulDays,
    );
  }

  /// The last [days] days ending today (oldest first).
  RangeStat lastDays(int days) => rangeStat(addDays(today, -(days - 1)), today);

  /// Per-day counts for the last [days] days, oldest first.
  List<({DateTime date, DayCount count})> dailyCounts(int days) => [
        for (var i = days - 1; i >= 0; i--)
          (date: addDays(today, -i), count: dayCount(addDays(today, -i))),
      ];

  RangeStat monthStat(int year, int month) => rangeStat(
        DateTime(year, month, 1),
        DateTime(year, month, daysInMonth(year, month)),
      );

  /// Monthly stats for the [count] months ending with the current month.
  List<MonthStat> lastMonths(int count) {
    final result = <MonthStat>[];
    for (var i = count - 1; i >= 0; i--) {
      final first = DateTime(today.year, today.month - i, 1);
      result.add(MonthStat(
        year: first.year,
        month: first.month,
        stat: monthStat(first.year, first.month),
      ));
    }
    return result;
  }

  StreakResult streaks() {
    if (habits.isEmpty) return const StreakResult(current: 0, best: 0);

    DateTime? earliest;
    for (final h in habits) {
      final start = tryParseDateKey(h.startDate);
      if (start == null) continue;
      if (earliest == null || start.isBefore(earliest)) earliest = start;
    }
    if (earliest == null) return const StreakResult(current: 0, best: 0);

    final floor = addDays(today, -_maxStreakScanDays);
    var cursor = earliest.isBefore(floor) ? floor : earliest;

    var run = 0;
    var best = 0;
    // Everything strictly before today is final: a miss resets the run.
    while (cursor.isBefore(today)) {
      final success = isSuccessfulDay(cursor);
      if (success != null) {
        if (success) {
          run++;
          if (run > best) best = run;
        } else {
          run = 0;
        }
      }
      cursor = addDays(cursor, 1);
    }
    // Today is still in progress: it can extend the run, never break it.
    if (isSuccessfulDay(today) == true) {
      run++;
      if (run > best) best = run;
    }
    return StreakResult(current: run, best: best);
  }

  /// Scheduled / completed check-ins of one habit over [from]..[to],
  /// clamped to today.
  DayCount habitCount(Habit habit, DateTime from, DateTime to) {
    final start = dayOnly(from);
    var end = dayOnly(to);
    if (end.isAfter(today)) end = today;
    var scheduled = 0;
    var completed = 0;
    for (var d = start; !d.isAfter(end); d = addDays(d, 1)) {
      if (!habit.appliesOn(d)) continue;
      scheduled++;
      if (isDone(habit.id, d)) completed++;
    }
    return (scheduled: scheduled, completed: completed);
  }

  /// Performance of every habit that had check-ins in the last [days] days,
  /// best first. Archived habits only appear if they were active in the
  /// window.
  List<HabitPerformance> habitPerformance({int days = 30}) {
    final from = addDays(today, -(days - 1));
    final list = <HabitPerformance>[];
    for (final h in habits) {
      final c = habitCount(h, from, today);
      if (h.isArchived && c.scheduled == 0) continue;
      list.add(HabitPerformance(
          habit: h, scheduled: c.scheduled, completed: c.completed));
    }
    list.sort((a, b) {
      final ra = a.rate ?? -1;
      final rb = b.rate ?? -1;
      final byRate = rb.compareTo(ra);
      if (byRate != 0) return byRate;
      return b.completed.compareTo(a.completed);
    });
    return list;
  }

  /// Habit with the best completion rate over the last [days] days. Needs at
  /// least [minCheckIns] scheduled check-ins so a brand-new habit with one
  /// lucky day does not win.
  HabitPerformance? mostConsistent({int days = 30, int minCheckIns = 3}) {
    for (final p in habitPerformance(days: days)) {
      if (p.scheduled >= minCheckIns && (p.rate ?? 0) > 0) return p;
    }
    return null;
  }
}
