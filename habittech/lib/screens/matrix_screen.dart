import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/habit_dialog.dart';
import '../widgets/page_heading.dart';
import 'dashboard_screen.dart' show percentText;

/// Interactive month grid: one row per habit, one column per day.
class MatrixScreen extends StatefulWidget {
  const MatrixScreen({super.key});

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  int? _year;
  int? _month;

  // Kept in State so tapping a cell (which rebuilds the grid) never resets
  // the horizontal scroll position.
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Start scrolled so today's column is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final today = context.read<AppState>().today;
      final target = ((today.day - 3) * _cellWidth)
          .clamp(0.0, _scroll.position.maxScrollExtent)
          .toDouble();
      _scroll.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const double _nameWidth = 132;
  static const double _cellWidth = 40;
  static const double _rowHeight = 48;

  void _shift(AppState state, int delta) {
    final y = _year ?? state.today.year;
    final m = _month ?? state.today.month;
    final next = DateTime(y, m + delta, 1);
    setState(() {
      _year = next.year;
      _month = next.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.stats;
    final today = state.today;
    final year = _year ?? today.year;
    final month = _month ?? today.month;
    final dim = daysInMonth(year, month);
    final c = context.hc;

    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month, dim);
    // Habits that applied at some point in this month (archived ones keep
    // their history visible).
    final habits = state.habits.where((h) {
      for (var d = 1; d <= dim; d++) {
        if (h.appliesOn(DateTime(year, month, d))) return true;
      }
      return false;
    }).toList();

    final month0 = stats.monthStat(year, month);
    final isFutureMonth = monthStart.isAfter(today);
    final isCurrent = year == today.year && month == today.month;

    Widget dayHeader(int day) {
      final date = DateTime(year, month, day);
      final isToday = isSameDay(date, today);
      return Container(
        width: _cellWidth,
        height: 54,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isToday ? c.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isToday ? Border.all(color: c.primaryStrong, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(kWeekdayInitial[date.weekday - 1],
                style: TextStyle(fontSize: 11, color: c.textSecondary)),
            const SizedBox(height: 2),
            Text('$day',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: c.text)),
          ],
        ),
      );
    }

    Widget cell(String habitId, String habitName, int day) {
      final date = DateTime(year, month, day);
      final habit = state.habitById(habitId)!;
      final applies = habit.appliesOn(date);
      final future = date.isAfter(today);
      final done = stats.isDone(habitId, date);
      final dateLabel = formatLongDate(date);

      if (!applies && !done) {
        return SizedBox(
          width: _cellWidth,
          height: _rowHeight,
          child: Center(
            child: Semantics(
              label: '$habitName not scheduled on $dateLabel',
              child: Container(
                width: 8,
                height: 2,
                color: c.border,
              ),
            ),
          ),
        );
      }

      final Color fill;
      final Widget? mark;
      final String status;
      if (done) {
        fill = c.primaryStrong;
        mark = Icon(Icons.check,
            size: 18, color: Theme.of(context).colorScheme.onPrimary);
        status = 'completed';
      } else if (future) {
        fill = c.background;
        mark = null;
        status = 'upcoming';
      } else {
        fill = c.card;
        mark = null;
        status = 'not completed';
      }

      return SizedBox(
        width: _cellWidth,
        height: _rowHeight,
        child: Center(
          child: Semantics(
            button: !future,
            label: '$habitName, $dateLabel, $status',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: future
                  ? null
                  : () => state.toggleCompletion(habitId, date),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: done
                        ? c.primaryStrong
                        : (future ? c.border : c.primary),
                    width: 1.5,
                  ),
                ),
                child: mark,
              ),
            ),
          ),
        ),
      );
    }

    Widget legendItem(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch,
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
          ],
        );

    Widget box(Color fill, Color border, {Widget? child}) => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: border, width: 1.5),
          ),
          child: child,
        );

    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return ScreenBody(
      children: [
        PageHeading(
          title: 'Monthly Habit Matrix',
          subtitle: 'Tap a day to mark a habit done or undo it.',
          trailing: FilledButton.icon(
            onPressed: () => showHabitDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Habit'),
          ),
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _shift(state, -1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          formatMonthYear(year, month),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          isFutureMonth
                              ? 'Upcoming month'
                              : '${percentText(month0.rate)} completed'
                                  '${month0.scheduled == 0 ? '' : ' · ${month0.completed}/${month0.scheduled}'}',
                          style: TextStyle(color: c.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => _shift(state, 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              if (!isCurrent)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _year = null;
                      _month = null;
                    }),
                    child: const Text('Back to this month'),
                  ),
                ),
              const SizedBox(height: 4),
              AppProgressBar(
                value: month0.rate ?? 0,
                semanticsLabel: 'Monthly completion',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  legendItem(
                      box(c.primaryStrong, c.primaryStrong,
                          child: Icon(Icons.check, size: 13, color: onPrimary)),
                      'Completed'),
                  legendItem(box(c.card, c.primary), 'Not completed'),
                  legendItem(box(c.background, c.border), 'Future'),
                ],
              ),
            ],
          ),
        ),
        if (habits.isEmpty)
          SoftCard(
            child: EmptyState(
              icon: Icons.grid_view,
              title: 'No habits this month',
              message: state.activeHabits.isEmpty
                  ? 'Add a habit to start filling the grid.'
                  : 'None of your habits were active in this month.',
              actionLabel: 'Add habit',
              onAction: () => showHabitDialog(context),
            ),
          )
        else
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Habit names stay put while the days scroll sideways.
                SizedBox(
                  width: _nameWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 54,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.only(left: 14),
                        alignment: Alignment.centerLeft,
                        child: Text('Habit',
                            style: TextStyle(
                                color: c.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5)),
                      ),
                      for (final h in habits)
                        Container(
                          height: _rowHeight,
                          padding: const EdgeInsets.only(left: 14, right: 6),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            h.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: h.isArchived ? c.textSecondary : c.text,
                              fontStyle:
                                  h.isArchived ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _scroll,
                    child: Column(
                      children: [
                        Row(children: [
                          for (var d = 1; d <= dim; d++) dayHeader(d),
                        ]),
                        for (final h in habits)
                          Row(children: [
                            for (var d = 1; d <= dim; d++) cell(h.id, h.name, d),
                          ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!monthEnd.isBefore(monthStart) && habits.isNotEmpty)
          Text(
            'Dashes mean the habit was not scheduled that day. Future days cannot be completed.',
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          ),
      ],
    );
  }
}
