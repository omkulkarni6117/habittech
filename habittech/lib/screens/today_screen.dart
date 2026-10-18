import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../models/habit.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/habit_card.dart';
import '../widgets/habit_dialog.dart';
import '../widgets/page_heading.dart';

enum _Filter { all, completed, remaining }

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  _Filter _filter = _Filter.all;
  bool _showArchived = false;

  Future<void> _onMenu(Habit habit, HabitMenuAction action) async {
    final state = context.read<AppState>();
    switch (action) {
      case HabitMenuAction.edit:
        await showHabitDialog(context, habit: habit);
      case HabitMenuAction.archive:
        {
          final ok = await confirmAction(
            context,
            title: 'Archive "${habit.name}"?',
            message:
                'It stops counting from today but all history is kept. You can restore it any time.',
            confirmLabel: 'Archive',
          );
          if (ok) state.archiveHabit(habit.id);
        }
      case HabitMenuAction.restore:
        {
          final error = state.restoreHabit(habit.id);
          if (error != null && mounted) showAppSnack(context, error);
        }
      case HabitMenuAction.delete:
        {
          final ok = await confirmAction(
            context,
            title: 'Delete "${habit.name}"?',
            message:
                'This permanently deletes the habit and every completion record. Archive it instead to keep your history.',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (ok) state.deleteHabit(habit.id);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.stats;
    final today = state.today;
    final active = state.activeHabits;
    final count = stats.dayCount(today);
    final weekStart = startOfWeek(today, state.settings.weekStartsOn);
    final c = context.hc;

    final scheduledToday = active.where((h) => h.appliesOn(today)).toList();
    final notToday = active.where((h) => !h.appliesOn(today)).toList();

    List<Habit> filtered = scheduledToday;
    if (_filter == _Filter.completed) {
      filtered = scheduledToday.where((h) => stats.isDone(h.id, today)).toList();
    } else if (_filter == _Filter.remaining) {
      filtered =
          scheduledToday.where((h) => !stats.isDone(h.id, today)).toList();
    }

    Widget card(Habit h, {required bool enabled}) {
      final week = stats.habitCount(h, weekStart, today);
      final weekTotal = [
        for (var i = 0; i < 7; i++)
          if (h.appliesOn(addDays(weekStart, i))) 1
      ].length;
      return HabitCard(
        habit: h,
        done: stats.isDone(h.id, today),
        weekDone: week.completed,
        weekScheduled: weekTotal,
        toggleEnabled: enabled && !h.isArchived,
        onToggle: () => state.toggleCompletion(h.id, today),
        onMenu: (a) => _onMenu(h, a),
      );
    }

    final emptyFilterMessage = _filter == _Filter.completed
        ? 'Nothing completed yet. Tap a circle to check a habit off.'
        : 'Everything is done. Nice work!';

    return ScreenBody(
      children: [
        PageHeading(
          title: "Today's Focus",
          subtitle: formatLongDate(today),
          trailing: FilledButton.icon(
            onPressed: () => showHabitDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ),
        if (active.isEmpty)
          SoftCard(
            child: EmptyState(
              icon: Icons.add_task,
              title: 'No habits yet',
              message:
                  'Create your first habit and check it off every day to build a streak.',
              actionLabel: 'Add habit',
              onAction: () => showHabitDialog(context),
            ),
          )
        else ...[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${count.completed} of ${count.scheduled} completed',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      count.scheduled == 0
                          ? '-'
                          : '${(count.completed / count.scheduled * 100).round()}%',
                      style: TextStyle(
                          color: c.primaryStrong, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppProgressBar(
                  value: count.scheduled == 0
                      ? 0
                      : count.completed / count.scheduled,
                  semanticsLabel: 'Habits completed today',
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              PillChip(
                label: 'All',
                selected: _filter == _Filter.all,
                onSelected: () => setState(() => _filter = _Filter.all),
              ),
              PillChip(
                label: 'Completed',
                selected: _filter == _Filter.completed,
                onSelected: () => setState(() => _filter = _Filter.completed),
              ),
              PillChip(
                label: 'Remaining',
                selected: _filter == _Filter.remaining,
                onSelected: () => setState(() => _filter = _Filter.remaining),
              ),
            ],
          ),
          if (filtered.isEmpty && scheduledToday.isNotEmpty)
            SoftCard(
              child: EmptyState(
                icon: Icons.filter_list,
                title: 'Nothing here',
                message: emptyFilterMessage,
              ),
            )
          else if (scheduledToday.isEmpty)
            SoftCard(
              child: const EmptyState(
                icon: Icons.free_breakfast_outlined,
                title: 'Nothing scheduled today',
                message: 'None of your habits are scheduled for today.',
              ),
            )
          else
            Column(
              children: [
                for (final h in filtered) ...[
                  card(h, enabled: true),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          if (notToday.isNotEmpty && _filter == _Filter.all) ...[
            const SectionTitle('Not scheduled today'),
            Column(
              children: [
                for (final h in notToday) ...[
                  card(h, enabled: false),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ],
        ],
        if (state.archivedHabits.isNotEmpty)
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  title: Text('Archived habits (${state.archivedHabits.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Icon(
                      _showArchived ? Icons.expand_less : Icons.expand_more),
                  onTap: () => setState(() => _showArchived = !_showArchived),
                ),
                if (_showArchived)
                  for (final h in state.archivedHabits)
                    ListTile(
                      title: Text(h.name),
                      subtitle: const Text('History kept'),
                      trailing: PopupMenuButton<HabitMenuAction>(
                        tooltip: 'Actions for ${h.name}',
                        onSelected: (a) => _onMenu(h, a),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: HabitMenuAction.restore,
                              child: Text('Restore')),
                          PopupMenuItem(
                              value: HabitMenuAction.delete,
                              child: Text('Delete')),
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
