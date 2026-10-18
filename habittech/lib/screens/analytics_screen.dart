import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/habit_icons.dart';
import '../widgets/page_heading.dart';
import '../widgets/responsive.dart';
import 'dashboard_screen.dart' show percentText;

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.stats;
    final sleep = state.sleepStats;
    final today = state.today;
    final c = context.hc;
    final weekStartsOn = state.settings.weekStartsOn;

    final hasData = stats.totalCompletedEntries > 0;
    final todayRate = stats.dailyRate(today);
    final month = stats.monthStat(today.year, today.month);
    final streaks = stats.streaks();
    final best = stats.mostConsistent();
    final performance = stats.habitPerformance();
    final counts = stats.dailyCounts(7);

    // Weekly consistency uses the calendar week that contains today.
    final weekStart = startOfWeek(today, weekStartsOn);
    final thisWeek = stats.rangeStat(weekStart, addDays(weekStart, 6));

    final trend = stats.lastMonths(6);

    // Heatmap: the last 12 weeks, columns = weeks, rows = weekdays in the
    // user's week-start order.
    const heatWeeks = 12;
    final firstHeatWeek = addDays(weekStart, -7 * (heatWeeks - 1));
    final order = weekdayOrder(weekStartsOn);
    final heat = <List<double?>>[
      for (var w = 0; w < heatWeeks; w++)
        [
          for (var r = 0; r < 7; r++)
            () {
              final d = addDays(firstHeatWeek, w * 7 + r);
              if (d.isAfter(today)) return null;
              return stats.dailyRate(d);
            }(),
        ],
    ];

    final sleepDays = sleep.lastDays(14);
    final sleepLogged = sleepDays.where((d) => d.minutes != null).length;
    final workoutWeek = state.workoutWeek;

    return ScreenBody(
      children: [
        const PageHeading(
          title: 'Progress Analytics',
          subtitle: 'Every number here is calculated from your own records.',
        ),
        if (!hasData)
          SoftCard(
            child: const EmptyState(
              icon: Icons.insights,
              title: 'Not enough data yet',
              message:
                  'Complete a few habits and your trends, streaks and heatmap will appear here.',
            ),
          )
        else ...[
          ResponsiveGrid(
            children: [
              StatCard(
                icon: Icons.today,
                label: 'Today',
                value: percentText(todayRate),
                caption: 'daily completion',
              ),
              StatCard(
                icon: Icons.date_range,
                label: 'This week',
                value: percentText(thisWeek.rate),
                caption: thisWeek.activeDays == 0
                    ? 'No habits yet'
                    : 'Goal met ${thisWeek.successfulDays}/${thisWeek.activeDays} days',
              ),
              StatCard(
                icon: Icons.calendar_month,
                label: kMonthNames[today.month - 1],
                value: percentText(month.rate),
                caption: '${month.completed}/${month.scheduled} check-ins',
              ),
              StatCard(
                icon: Icons.done_all,
                label: 'Total completed',
                value: '${stats.totalCompletedEntries}',
                caption: 'habit entries, all time',
              ),
              StatCard(
                icon: Icons.local_fire_department_outlined,
                label: 'Current streak',
                value: '${streaks.current}d',
                caption: 'days meeting your goal',
              ),
              StatCard(
                icon: Icons.emoji_events_outlined,
                label: 'Longest streak',
                value: '${streaks.best}d',
                caption: 'best so far',
              ),
              StatCard(
                icon: Icons.verified_outlined,
                label: 'Consistency (30d)',
                value: percentText(stats.lastDays(30).consistency),
                caption: 'days meeting your goal',
              ),
              StatCard(
                icon: Icons.star_outline,
                label: 'Most consistent',
                value: best?.habit.name ?? '-',
                caption: best == null ? 'Needs a few days' : percentText(best.rate),
              ),
            ],
          ),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Daily completion, last 7 days'),
                const SizedBox(height: 12),
                BarChartView(
                  data: [
                    for (final d in counts)
                      BarDatum(
                        label: kWeekdayShort[d.date.weekday - 1],
                        value: d.count.scheduled == 0
                            ? null
                            : d.count.completed / d.count.scheduled,
                        valueText: d.count.scheduled == 0
                            ? null
                            : '${(d.count.completed / d.count.scheduled * 100).round()}%',
                        highlight: isSameDay(d.date, today),
                      ),
                  ],
                  semanticsSummary: 'Daily completion rate for the last 7 days',
                ),
                const SizedBox(height: 10),
                Text(
                  'Completion rate counts habits done out of habits scheduled. '
                  'Consistency counts days on which you met your daily goal of ${state.settings.dailyHabitGoal}, so they can differ.',
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Monthly trend'),
                const SizedBox(height: 12),
                LineChartView(
                  points: [
                    for (final m in trend)
                      TrendPoint(label: kMonthShort[m.month - 1], value: m.stat.rate),
                  ],
                  semanticsSummary: 'Monthly completion rate: ' +
                      [
                        for (final m in trend)
                          '${kMonthShort[m.month - 1]} ${percentText(m.stat.rate)}',
                      ].join(', '),
                ),
              ],
            ),
          ),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Habit by habit (last 30 days)'),
                const SizedBox(height: 10),
                if (performance.isEmpty)
                  Text('No habits to compare yet.',
                      style: TextStyle(color: c.textSecondary))
                else
                  for (final p in performance)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          IconBadge(icon: habitIcon(p.habit.iconKey), size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.habit.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Text(
                                      '${percentText(p.rate)} · ${p.completed}/${p.scheduled}',
                                      style: TextStyle(
                                          color: c.textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                AppProgressBar(
                                  value: p.rate ?? 0,
                                  height: 6,
                                  semanticsLabel: p.habit.name,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Calendar heatmap, last 12 weeks'),
                const SizedBox(height: 12),
                HeatmapView(
                  weeks: heat,
                  rowLabels: [
                    for (final w in order) kWeekdayInitial[w - 1],
                  ],
                  semanticsSummary:
                      'Heatmap of daily completion over the last 12 weeks. Darker squares mean more habits completed.',
                ),
              ],
            ),
          ),
        ],
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Sleep duration, last 14 nights'),
              const SizedBox(height: 12),
              if (sleepLogged == 0)
                const EmptyState(
                  icon: Icons.bedtime_outlined,
                  title: 'No sleep data yet',
                  message: 'Log your sleep to see the trend.',
                )
              else
                BarChartView(
                  maxValue: [
                    10 * 60,
                    state.settings.sleepGoalMinutes + 60,
                    for (final d in sleepDays)
                      if (d.minutes != null) d.minutes! + 30,
                  ].reduce((a, b) => a > b ? a : b).toDouble(),
                  goal: state.settings.sleepGoalMinutes.toDouble(),
                  goalLabel: 'Goal',
                  height: 140,
                  data: [
                    for (final d in sleepDays)
                      BarDatum(
                        label: '${d.date.day}',
                        value: d.minutes?.toDouble(),
                        valueText: d.minutes == null
                            ? null
                            : (d.minutes! / 60).toStringAsFixed(1),
                        highlight: isSameDay(d.date, today),
                      ),
                  ],
                  semanticsSummary: 'Sleep hours over the last 14 nights',
                ),
            ],
          ),
        ),
        SoftCard(
          child: Row(
            children: [
              const IconBadge(icon: Icons.fitness_center, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Workouts this week',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      workoutWeek.plannedSessions == 0
                          ? 'No workouts planned yet.'
                          : '${workoutWeek.completedSessions} of ${workoutWeek.plannedSessions} sessions complete',
                      style: TextStyle(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
