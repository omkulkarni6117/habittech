import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'habit_icons.dart';

/// Round completion toggle with a short pop animation.
class HabitCheckButton extends StatelessWidget {
  const HabitCheckButton({
    super.key,
    required this.done,
    required this.onPressed,
    required this.label,
  });

  final bool done;
  final VoidCallback onPressed;

  /// Spoken by screen readers, e.g. "Workout".
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final duration = motionDuration(context, 220);
    return Semantics(
      button: true,
      checked: done,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? c.primaryStrong : Colors.transparent,
                border: Border.all(color: c.primaryStrong, width: 2),
              ),
              child: AnimatedScale(
                scale: done ? 1 : 0,
                duration: duration,
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum HabitMenuAction { edit, archive, restore, delete }

/// One habit row: icon, name, target, weekly progress, check and menu.
class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.done,
    required this.weekDone,
    required this.weekScheduled,
    required this.onToggle,
    required this.onMenu,
    this.toggleEnabled = true,
  });

  final Habit habit;
  final bool done;

  /// Completed / scheduled check-ins so far this week.
  final int weekDone;
  final int weekScheduled;
  final VoidCallback onToggle;
  final ValueChanged<HabitMenuAction> onMenu;

  /// False when the habit is not scheduled today (or is archived).
  final bool toggleEnabled;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final subtitleParts = <String>[
      if (habit.description.trim().isNotEmpty)
        habit.description.trim()
      else if (habit.goalLabel.isNotEmpty)
        habit.goalLabel,
      if (habit.scheduleType == ScheduleType.weekly) habit.scheduleLabel,
    ];
    final subtitle = subtitleParts.join(' · ');

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(
        children: [
          IconBadge(icon: habitIcon(habit.iconKey), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: done ? c.textSecondary : c.text,
                    decoration:
                        done ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: c.textSecondary,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                if (!toggleEnabled)
                  Text(
                    habit.isArchived ? 'Archived' : 'Not scheduled today',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else if (weekScheduled > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$weekDone/$weekScheduled this week',
                      style: TextStyle(
                        color: c.primaryStrong,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (toggleEnabled)
            HabitCheckButton(
              done: done,
              onPressed: onToggle,
              label: done
                  ? '${habit.name}, completed. Tap to mark as not done.'
                  : '${habit.name}, not completed. Tap to mark as done.',
            ),
          PopupMenuButton<HabitMenuAction>(
            tooltip: 'More actions for ${habit.name}',
            onSelected: onMenu,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: HabitMenuAction.edit,
                child: Text('Edit'),
              ),
              if (habit.isArchived)
                const PopupMenuItem(
                  value: HabitMenuAction.restore,
                  child: Text('Restore'),
                )
              else
                const PopupMenuItem(
                  value: HabitMenuAction.archive,
                  child: Text('Archive'),
                ),
              const PopupMenuItem(
                value: HabitMenuAction.delete,
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
