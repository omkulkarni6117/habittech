import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../logic/workout_logic.dart';
import '../models/workout.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/habit_card.dart';
import '../widgets/page_heading.dart';
import '../widgets/responsive.dart';
import '../widgets/workout_dialogs.dart';

/// Weekly workout planner: build a plan per weekday from the exercise
/// library, then tick exercises off on the day you do them.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  /// Weekday (1-7) being viewed/edited. Null = today.
  int? _selected;

  Color _statusColor(HabitColors c, WorkoutDayStatus s) => switch (s) {
        WorkoutDayStatus.done => c.success,
        WorkoutDayStatus.partial => c.warning,
        WorkoutDayStatus.missed => c.error,
        WorkoutDayStatus.todo => c.primaryStrong,
        WorkoutDayStatus.upcoming => c.primary,
        WorkoutDayStatus.rest => c.textSecondary,
        WorkoutDayStatus.unplanned => c.border,
      };

  String _statusLabel(WorkoutDayStatus s) => switch (s) {
        WorkoutDayStatus.done => 'Done',
        WorkoutDayStatus.partial => 'In progress',
        WorkoutDayStatus.missed => 'Missed',
        WorkoutDayStatus.todo => 'To do',
        WorkoutDayStatus.upcoming => 'Planned',
        WorkoutDayStatus.rest => 'Rest',
        WorkoutDayStatus.unplanned => 'Empty',
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = state.today;
    final c = context.hc;
    final week = state.workoutWeek;
    final selectedWeekday = _selected ?? today.weekday;
    final selectedEntry =
        week.days.firstWhere((d) => d.date.weekday == selectedWeekday);
    final day = selectedEntry.day;
    final date = selectedEntry.date;
    final index = state.exerciseById;
    final isFuture = date.isAfter(today);
    final done = completedItems(day, state.workoutProgress, date);

    return ScreenBody(
      children: [
        PageHeading(
          title: 'Workout Planner',
          subtitle: 'Plan your week, add any exercise, and tick sets off as you go.',
          trailing: OutlinedButton.icon(
            onPressed: () => showExerciseLibrary(context),
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Exercises'),
          ),
        ),
        ResponsiveGrid(
          minItemWidth: 140,
          children: [
            StatCard(
              icon: Icons.event_available,
              label: 'Workouts this week',
              value: '${week.completedSessions}/${week.plannedSessions}',
              caption: week.plannedSessions == 0
                  ? 'Nothing planned'
                  : '${((week.completion ?? 0) * 100).round()}% complete',
            ),
            StatCard(
              icon: Icons.fitness_center,
              label: 'Planned exercises',
              value: '${week.totalExercises}',
              caption: 'across the week',
            ),
            StatCard(
              icon: Icons.timer_outlined,
              label: 'Planned time',
              value: week.totalMinutes == 0
                  ? '0m'
                  : formatDuration(week.totalMinutes),
              caption: 'estimate',
            ),
            StatCard(
              icon: Icons.spa_outlined,
              label: 'Rest days',
              value: '${week.restDays}',
              caption: 'this week',
            ),
          ],
        ),
        SoftCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: SectionTitle('Your week'),
              ),
              Row(
                children: [
                  for (final entry in week.days)
                    Expanded(
                      child: _DayTab(
                        label: kWeekdayShort[entry.date.weekday - 1],
                        dayNumber: entry.date.day,
                        color: _statusColor(c, entry.status),
                        status: _statusLabel(entry.status),
                        selected: entry.date.weekday == selectedWeekday,
                        isToday: isSameDay(entry.date, today),
                        onTap: () =>
                            setState(() => _selected = entry.date.weekday),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        _DayPlanCard(
          weekday: selectedWeekday,
          date: date,
          day: day,
          index: index,
          done: done,
          isFuture: isFuture,
          onCopyFrom: () => _copyFrom(context, selectedWeekday),
        ),
      ],
    );
  }

  Future<void> _copyFrom(BuildContext context, int toWeekday) async {
    final state = context.read<AppState>();
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Copy to ${kWeekdayLong[toWeekday - 1]} from'),
        children: [
          for (var w = 1; w <= 7; w++)
            if (w != toWeekday)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(w),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${kWeekdayLong[w - 1]}'
                    '${state.workoutPlan.day(w).title.isEmpty ? '' : ' · ${state.workoutPlan.day(w).title}'}',
                  ),
                ),
              ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final target = state.workoutPlan.day(toWeekday);
    if (target.items.isNotEmpty) {
      final ok = await confirmAction(
        context,
        title: 'Replace ${kWeekdayLong[toWeekday - 1]}\'s plan?',
        message:
            'Its ${target.items.length} exercises will be replaced by a copy of ${kWeekdayLong[choice - 1]}.',
        confirmLabel: 'Replace',
        destructive: true,
      );
      if (!ok) return;
    }
    state.copyWorkoutDay(choice, toWeekday);
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.label,
    required this.dayNumber,
    required this.color,
    required this.status,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final int dayNumber;
  final Color color;
  final String status;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $dayNumber, $status${isToday ? ', today' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? c.primaryStrong : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ExcludeSemantics(
            child: Column(
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('$dayNumber',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                        color: c.text)),
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayPlanCard extends StatelessWidget {
  const _DayPlanCard({
    required this.weekday,
    required this.date,
    required this.day,
    required this.index,
    required this.done,
    required this.isFuture,
    required this.onCopyFrom,
  });

  final int weekday;
  final DateTime date;
  final WorkoutDay day;
  final Map<String, Exercise> index;
  final int done;
  final bool isFuture;
  final VoidCallback onCopyFrom;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final c = context.hc;
    final progress = context.select<AppState, Map<String, Set<String>>>(
        (s) => s.workoutProgress);
    final ticked = progress[dateKey(date)] ?? const <String>{};
    final groups = groupsTrained(day, index);

    Future<void> clearDay() async {
      final ok = await confirmAction(
        context,
        title: 'Clear ${kWeekdayLong[weekday - 1]}?',
        message: 'This removes all ${day.items.length} planned exercises from this day.',
        confirmLabel: 'Clear day',
        destructive: true,
      );
      if (ok) state.clearWorkoutDay(weekday);
    }

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${kWeekdayLong[weekday - 1]} · ${formatShortDate(date)}',
                      style: TextStyle(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                    Text(
                      day.title.isEmpty
                          ? (day.isRest ? 'Rest day' : 'Untitled session')
                          : day.title,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Day options',
                onSelected: (v) async {
                  switch (v) {
                    case 'title':
                      {
                        final title = await promptText(
                          context,
                          title: 'Session name',
                          label: 'Name',
                          hint: 'e.g. Push day',
                          initial: day.title,
                          maxLength: 40,
                          allowEmpty: true,
                        );
                        if (title != null) state.setWorkoutTitle(weekday, title);
                      }
                    case 'rest':
                      state.setWorkoutRest(weekday, !day.isRest);
                    case 'copy':
                      onCopyFrom();
                    case 'clear':
                      await clearDay();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'title', child: Text('Rename session')),
                  PopupMenuItem(
                    value: 'rest',
                    child: Text(day.isRest ? 'Make a workout day' : 'Mark as rest day'),
                  ),
                  const PopupMenuItem(value: 'copy', child: Text('Copy from another day')),
                  if (day.items.isNotEmpty)
                    const PopupMenuItem(value: 'clear', child: Text('Clear day')),
                ],
              ),
            ],
          ),
          if (day.isRest) ...[
            const SizedBox(height: 8),
            EmptyState(
              icon: Icons.spa_outlined,
              title: 'Rest day',
              message:
                  'Recovery is part of training. Add an exercise if you want to make this a workout day.',
              actionLabel: 'Add exercise',
              onAction: () => showAddToPlan(context, weekday),
            ),
          ] else if (day.items.isEmpty) ...[
            const SizedBox(height: 8),
            EmptyState(
              icon: Icons.fitness_center,
              title: 'No exercises yet',
              message:
                  'Add exercises from your library, or create a new one, to build this day.',
              actionLabel: 'Add exercise',
              onAction: () => showAddToPlan(context, weekday),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in groups) _Tag(g.label),
                _Tag('${day.items.length} exercises'),
                _Tag('~${estimatedDayMinutes(day, index)} min'),
                if (totalSets(day, index) > 0)
                  _Tag('${totalSets(day, index)} sets'),
              ],
            ),
            const SizedBox(height: 12),
            if (!isFuture) ...[
              AppProgressBar(
                value: done / day.items.length,
                semanticsLabel: 'Workout progress',
              ),
              const SizedBox(height: 4),
              Text(
                done == day.items.length
                    ? 'Session complete. Great work!'
                    : '$done of ${day.items.length} done',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Upcoming. You can tick exercises off on the day itself.',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
              ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: day.items.length,
              onReorder: (a, b) => state.reorderPlannedExercise(weekday, a, b),
              itemBuilder: (context, i) {
                final item = day.items[i];
                final ex = index[item.exerciseId];
                return _PlannedTile(
                  key: ValueKey(item.id),
                  position: i,
                  item: item,
                  exercise: ex,
                  checked: ticked.contains(item.id),
                  canTick: !isFuture,
                  onToggle: () => state.toggleWorkoutItem(date, item.id),
                  onEdit: () => showEditPlanned(context, weekday, item),
                  onRemove: () => state.removePlannedExercise(weekday, item.id),
                  onMoveUp: i == 0
                      ? null
                      : () => state.reorderPlannedExercise(weekday, i, i - 1),
                  onMoveDown: i == day.items.length - 1
                      ? null
                      : () => state.reorderPlannedExercise(weekday, i, i + 2),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showAddToPlan(context, weekday),
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: c.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _PlannedTile extends StatelessWidget {
  const _PlannedTile({
    super.key,
    required this.position,
    required this.item,
    required this.exercise,
    required this.checked,
    required this.canTick,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int position;
  final PlannedExercise item;
  final Exercise? exercise;
  final bool checked;
  final bool canTick;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final name = exercise?.name ?? 'Unknown exercise';
    final summary = plannedSummary(item, exercise);
    final restText = exercise?.kind == ExerciseKind.timed || item.restSec == 0
        ? ''
        : ' · ${item.restSec}s rest';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
      decoration: BoxDecoration(
        color: checked ? c.primarySoft : c.background,
        borderRadius: BorderRadius.circular(kControlRadius),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          if (canTick)
            HabitCheckButton(
              done: checked,
              onPressed: onToggle,
              label: checked
                  ? '$name, done. Tap to undo.'
                  : '$name, not done. Tap to mark done.',
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: checked ? c.textSecondary : c.text,
                        decoration:
                            checked ? TextDecoration.lineThrough : null,
                        decorationColor: c.textSecondary,
                      ),
                    ),
                    Text(
                      '$summary$restText',
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                    if (item.notes.trim().isNotEmpty)
                      Text(
                        item.notes.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions for $name',
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  onEdit();
                case 'up':
                  onMoveUp?.call();
                case 'down':
                  onMoveDown?.call();
                case 'remove':
                  onRemove();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit sets & reps')),
              if (onMoveUp != null)
                const PopupMenuItem(value: 'up', child: Text('Move up')),
              if (onMoveDown != null)
                const PopupMenuItem(value: 'down', child: Text('Move down')),
              const PopupMenuItem(value: 'remove', child: Text('Remove from day')),
            ],
          ),
          ReorderableDragStartListener(
            index: position,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_handle, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
