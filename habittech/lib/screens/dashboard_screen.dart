import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/sections.dart';
import '../core/date_utils.dart';
import '../logic/workout_logic.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/habit_card.dart';
import '../widgets/habit_dialog.dart';
import '../widgets/habit_icons.dart';
import '../widgets/motivation_card.dart';
import '../widgets/page_heading.dart';
import '../widgets/responsive.dart';

String percentText(double? v) => v == null ? '-' : '${(v * 100).round()}%';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.stats;
    final today = state.today;
    final hour = state.now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final goal = state.settings.dailyHabitGoal;

    final week = stats.lastDays(7);
    final todayCount = stats.dayCount(today);
    final streaks = stats.streaks();
    final month = stats.monthStat(today.year, today.month);

    String days(int n) => '$n ${n == 1 ? 'day' : 'days'}';

    return ScreenBody(
      children: [
        PageHeading(
          title: '$greeting, ${state.settings.displayName} 👋',
          subtitle: 'Small habits. Big change. Build consistency every day.',
        ),
        if (state.isDemo) const _DemoBanner(),
        ResponsiveGrid(
          children: [
            StatCard(
              icon: Icons.percent,
              label: 'Completion Rate',
              value: percentText(week.rate),
              caption: 'Last 7 days',
            ),
            StatCard(
              icon: Icons.task_alt,
              label: 'Completed Today',
              value: '${todayCount.completed}/${todayCount.scheduled}',
              caption: 'habits done',
            ),
            StatCard(
              icon: Icons.local_fire_department_outlined,
              label: 'Current Streak',
              value: days(streaks.current),
              caption: 'Days meeting your goal',
            ),
            StatCard(
              icon: Icons.emoji_events_outlined,
              label: 'Best Streak',
              value: days(streaks.best),
              caption: 'Goal: $goal habits a day',
            ),
          ],
        ),
        const _TodayCard(),
        _WeekCard(state: state),
        TwoUp(
          left: _MonthCard(
            rate: month.rate,
            completed: month.completed,
            scheduled: month.scheduled,
            monthName: kMonthNames[today.month - 1],
          ),
          right: const _MostConsistentCard(),
        ),
        const _WorkoutTodayCard(),
        MotivationCard(today: today),
      ],
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return SoftCard(
      color: c.primarySoft,
      child: Row(
        children: [
          Icon(Icons.info_outline, color: c.primaryStrong),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You are looking at sample data. Clear it whenever you are ready to start fresh.',
              style: TextStyle(height: 1.35),
            ),
          ),
          TextButton(
            onPressed: () async {
              final state = context.read<AppState>();
              final ok = await confirmAction(
                context,
                title: 'Clear sample data?',
                message:
                    'This removes the sample habits, history, sleep entries, notes and workout plan. Your settings and the exercise library stay.',
                confirmLabel: 'Clear',
                destructive: true,
              );
              if (ok) state.clearDemoData();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.stats;
    final today = state.today;
    final scheduled = stats.scheduledOn(today);
    final count = stats.dayCount(today);
    final c = context.hc;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            "Today's habits",
            trailing: TextButton(
              onPressed: () => state.goTo(AppSection.today),
              child: const Text('View all'),
            ),
          ),
          if (scheduled.isEmpty)
            EmptyState(
              icon: Icons.add_task,
              title: state.activeHabits.isEmpty
                  ? 'No habits yet'
                  : 'Nothing scheduled today',
              message: state.activeHabits.isEmpty
                  ? 'Add your first habit to start building consistency.'
                  : 'Enjoy the day off, or add another habit.',
              actionLabel: 'Add habit',
              onAction: () => showHabitDialog(context),
            )
          else ...[
            AppProgressBar(
              value: count.scheduled == 0 ? 0 : count.completed / count.scheduled,
              semanticsLabel: 'Habits completed today',
            ),
            const SizedBox(height: 6),
            Text(
              '${count.completed} of ${count.scheduled} completed',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            for (final habit in scheduled.take(5))
              Row(
                children: [
                  HabitCheckButton(
                    done: stats.isDone(habit.id, today),
                    label: habit.name,
                    onPressed: () => state.toggleCompletion(habit.id, today),
                  ),
                  Icon(habitIcon(habit.iconKey), size: 20, color: c.primaryStrong),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: stats.isDone(habit.id, today)
                            ? c.textSecondary
                            : c.text,
                        decoration: stats.isDone(habit.id, today)
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            if (scheduled.length > 5)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(
                  '+${scheduled.length - 5} more on the Today screen',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showHabitDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add habit'),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    final today = state.today;
    final c = context.hc;
    final counts = stats.dailyCounts(7);
    final week = stats.lastDays(7);
    final data = [
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
    ];
    final summary = 'Daily completion, last 7 days: ' +
        [
          for (final d in data) '${d.label} ${d.valueText ?? 'no habits'}',
        ].join(', ');

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('This week'),
          const SizedBox(height: 12),
          if (stats.trackedDays == 0)
            const EmptyState(
              icon: Icons.bar_chart,
              title: 'Your week will appear here',
              message: 'Complete a habit and the chart fills in right away.',
            )
          else ...[
            BarChartView(data: data, semanticsSummary: summary),
            const SizedBox(height: 10),
            Text(
              week.activeDays == 0
                  ? 'No habits were scheduled this week.'
                  : 'You met your daily goal on ${week.successfulDays} of ${week.activeDays} days.',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.rate,
    required this.completed,
    required this.scheduled,
    required this.monthName,
  });

  final double? rate;
  final int completed;
  final int scheduled;
  final String monthName;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            '$monthName progress',
            trailing: TextButton(
              onPressed: () =>
                  context.read<AppState>().goTo(AppSection.matrix),
              child: const Text('Open matrix'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            percentText(rate),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          AppProgressBar(
            value: rate ?? 0,
            semanticsLabel: '$monthName completion',
          ),
          const SizedBox(height: 8),
          Text(
            scheduled == 0
                ? 'No check-ins scheduled yet this month.'
                : '$completed of $scheduled habit check-ins so far.',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MostConsistentCard extends StatelessWidget {
  const _MostConsistentCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final best = state.stats.mostConsistent();
    final c = context.hc;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Most consistent habit'),
          const SizedBox(height: 10),
          if (best == null)
            Text(
              'Track a few days and your steadiest habit shows up here.',
              style: TextStyle(color: c.textSecondary, height: 1.35),
            )
          else
            Row(
              children: [
                IconBadge(icon: habitIcon(best.habit.iconKey), size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        best.habit.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${percentText(best.rate)} · ${best.completed} of ${best.scheduled} in the last 30 days',
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WorkoutTodayCard extends StatelessWidget {
  const _WorkoutTodayCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = state.today;
    final day = state.workoutPlan.day(today.weekday);
    final index = state.exerciseById;
    final done = completedItems(day, state.workoutProgress, today);
    final c = context.hc;

    final String headline;
    final String detail;
    if (day.isRest) {
      headline = day.title.isEmpty ? 'Rest day' : day.title;
      detail = 'Recovery is part of the plan.';
    } else if (day.items.isEmpty) {
      headline = 'No workout planned';
      detail = 'Build your weekly plan to see today\'s session here.';
    } else {
      headline = day.title.isEmpty ? kWeekdayLong[today.weekday - 1] : day.title;
      detail =
          '$done of ${day.items.length} exercises done · about ${estimatedDayMinutes(day, index)} min';
    }

    return SoftCard(
      onTap: () => state.goTo(AppSection.workout),
      child: Row(
        children: [
          const IconBadge(icon: Icons.fitness_center, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's workout",
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                Text(headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w800)),
                Text(detail,
                    style: TextStyle(color: c.textSecondary, fontSize: 13)),
                if (day.isWorkout) ...[
                  const SizedBox(height: 8),
                  AppProgressBar(
                    value: done / day.items.length,
                    semanticsLabel: 'Workout progress today',
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.textSecondary),
        ],
      ),
    );
  }
}
