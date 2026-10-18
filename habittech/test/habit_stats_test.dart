import 'package:flutter_test/flutter_test.dart';
import 'package:habittech/core/date_utils.dart';
import 'package:habittech/logic/habit_stats.dart';
import 'package:habittech/models/habit.dart';
import 'package:habittech/models/habit_completion.dart';

import 'helpers.dart';

HabitStats statsFor(
  List<Habit> habits,
  List<HabitCompletion> completions, {
  int dailyGoal = 1,
  DateTime? now,
}) =>
    HabitStats(
      habits: habits,
      completions: completions,
      dailyGoal: dailyGoal,
      now: now ?? kNow,
    );

void main() {
  final today = dayOnly(kNow); // Wed 2026-10-14

  group('daily completion rate', () {
    test('completed / scheduled for one day', () {
      final habits = [makeHabit('a'), makeHabit('b'), makeHabit('c'), makeHabit('d')];
      final s = statsFor(habits, [done('a', today), done('b', today), done('c', today)]);
      expect(s.dayCount(today), (scheduled: 4, completed: 3));
      expect(s.dailyRate(today), 0.75);
    });

    test('no habits scheduled gives null, never 0 or 100', () {
      expect(statsFor([], []).dailyRate(today), isNull);
    });

    test('a missing record counts as not completed', () {
      final s = statsFor([makeHabit('a')], []);
      expect(s.dailyRate(addDays(today, -3)), 0);
    });
  });

  group('habit applicability', () {
    test('a habit does not count before its start date', () {
      final h = makeHabit('a', start: '2026-10-10');
      final s = statsFor([h], []);
      expect(s.dayCount(DateTime(2026, 10, 9)).scheduled, 0);
      expect(s.dayCount(DateTime(2026, 10, 10)).scheduled, 1);
    });

    test('creating a habit does not change rates before its start', () {
      final a = makeHabit('a');
      final b = makeHabit('b', start: '2026-10-14');
      final before = statsFor([a], [done('a', DateTime(2026, 10, 1))]);
      final after = statsFor([a, b], [done('a', DateTime(2026, 10, 1))]);
      final day = DateTime(2026, 10, 1);
      expect(after.dailyRate(day), before.dailyRate(day));
    });

    test('weekly habits only count on scheduled weekdays', () {
      final h = makeHabit('a',
          type: ScheduleType.weekly, weekdays: const [1, 3]); // Mon, Wed
      final s = statsFor([h], []);
      expect(s.dayCount(DateTime(2026, 10, 12)).scheduled, 1); // Mon
      expect(s.dayCount(DateTime(2026, 10, 13)).scheduled, 0); // Tue
      expect(s.dayCount(DateTime(2026, 10, 14)).scheduled, 1); // Wed
    });

    test('archived habits stop counting after the archive day but keep history', () {
      final h = makeHabit('a', archivedAt: DateTime(2026, 10, 10, 8));
      final c = [done('a', DateTime(2026, 10, 8))];
      final s = statsFor([h], c);
      expect(s.dayCount(DateTime(2026, 10, 8)), (scheduled: 1, completed: 1));
      expect(s.dayCount(DateTime(2026, 10, 10)).scheduled, 1);
      expect(s.dayCount(DateTime(2026, 10, 11)).scheduled, 0);
      expect(s.totalCompletedEntries, 1);
    });
  });

  group('range and month statistics', () {
    test('future days are never counted', () {
      final s = statsFor([makeHabit('a')], [done('a', today)]);
      final r = s.rangeStat(DateTime(2026, 10, 12), DateTime(2026, 10, 31));
      expect(r.scheduled, 3); // 12th, 13th, 14th
      expect(r.completed, 1);
    });

    test('month stat uses real month length and boundaries', () {
      // Feb 2024 has 29 days; the habit starts on Feb 1 and is done daily.
      final h = makeHabit('a', start: '2024-02-01');
      final completions = [
        for (var d = 1; d <= 29; d++) done('a', DateTime(2024, 2, d)),
      ];
      final s = statsFor([h], completions, now: DateTime(2024, 3, 15, 12));
      final feb = s.monthStat(2024, 2);
      expect(feb.scheduled, 29);
      expect(feb.completed, 29);
      expect(feb.rate, 1.0);
      // The first of March belongs to the next month's stats.
      expect(s.monthStat(2024, 3).completed, 0);
    });

    test('consistency differs from completion rate', () {
      // 7 habits, 5 done every day for 3 days, goal = 5.
      final habits = [for (var i = 0; i < 7; i++) makeHabit('h$i')];
      final completions = <HabitCompletion>[];
      for (var d = 0; d < 3; d++) {
        final day = addDays(today, -d);
        for (var i = 0; i < 5; i++) {
          completions.add(done('h$i', day));
        }
      }
      final s = statsFor(habits, completions, dailyGoal: 5);
      final r = s.rangeStat(addDays(today, -2), today);
      expect(r.rate, closeTo(15 / 21, 1e-9));
      expect(r.consistency, 1.0);
    });

    test('lastMonths returns consecutive months across a year change', () {
      final s = statsFor([makeHabit('a')], [],
          now: DateTime(2026, 2, 10, 12));
      final months = s.lastMonths(4);
      expect([for (final m in months) (m.year, m.month)],
          [(2025, 11), (2025, 12), (2026, 1), (2026, 2)]);
    });
  });

  group('streaks', () {
    // Goal of 1 habit per day keeps these scenarios easy to read.
    List<HabitCompletion> run(String id, int from, int to) => [
          for (var back = from; back >= to; back--)
            done(id, addDays(today, -back)),
        ];

    test('consecutive days up to today', () {
      final h = makeHabit('a', start: '2026-10-01');
      final s = statsFor([h], run('a', 3, 0)); // 4 days ending today
      expect(s.streaks().current, 4);
      expect(s.streaks().best, 4);
    });

    test('today in progress does not break the streak', () {
      final h = makeHabit('a', start: '2026-10-01');
      final s = statsFor([h], run('a', 3, 1)); // done yesterday and before
      expect(s.streaks().current, 3);
    });

    test('a missed past day resets the current streak', () {
      final h = makeHabit('a', start: '2026-10-01');
      // done 5,4,3 days ago, missed 2 days ago, done yesterday.
      final c = [...run('a', 5, 3), done('a', addDays(today, -1))];
      final s = statsFor([h], c);
      expect(s.streaks().current, 1);
      expect(s.streaks().best, 3);
    });

    test('best streak comes from history even if current is 0', () {
      final h = makeHabit('a', start: '2026-10-01');
      final s = statsFor([h], run('a', 10, 6)); // 5 days, then nothing
      expect(s.streaks().current, 0);
      expect(s.streaks().best, 5);
    });

    test('streak counts days meeting the daily goal, not perfect days', () {
      final habits = [makeHabit('a', start: '2026-10-10'), makeHabit('b', start: '2026-10-10')];
      final c = [
        for (var back = 3; back >= 0; back--) done('a', addDays(today, -back)),
      ];
      final goal1 = statsFor(habits, c, dailyGoal: 1).streaks();
      final goal2 = statsFor(habits, c, dailyGoal: 2).streaks();
      expect(goal1.current, 4);
      expect(goal2.current, 0);
    });

    test('days with nothing scheduled are neutral', () {
      // Only Mondays and Wednesdays are scheduled.
      final h = makeHabit('a',
          start: '2026-10-01', type: ScheduleType.weekly, weekdays: const [1, 3]);
      final c = [
        done('a', DateTime(2026, 10, 7)), // Wed
        done('a', DateTime(2026, 10, 12)), // Mon
        done('a', DateTime(2026, 10, 14)), // Wed (today)
      ];
      final s = statsFor([h], c);
      expect(s.streaks().current, 3);
    });

    test('no habits means no streak', () {
      expect(statsFor([], []).streaks().current, 0);
      expect(statsFor([], []).streaks().best, 0);
    });
  });

  group('most consistent habit', () {
    test('needs a minimum number of check-ins', () {
      final h = makeHabit('a', start: '2026-10-14'); // only today scheduled
      final s = statsFor([h], [done('a', today)]);
      expect(s.mostConsistent(), isNull);
    });

    test('picks the habit with the best rate', () {
      final a = makeHabit('a', start: '2026-10-01');
      final b = makeHabit('b', start: '2026-10-01');
      final c = [
        for (var back = 0; back < 10; back++) done('a', addDays(today, -back)),
        for (var back = 0; back < 4; back++) done('b', addDays(today, -back)),
      ];
      expect(statsFor([a, b], c).mostConsistent()?.habit.id, 'a');
    });
  });
}
