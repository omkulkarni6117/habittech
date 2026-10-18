import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../core/time_utils.dart';
import '../logic/sleep_stats.dart';
import '../models/sleep_entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/page_heading.dart';
import '../widgets/responsive.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  late DateTime _date = context.read<AppState>().today;
  String _bed = '23:00';
  String _wake = '07:00';
  int? _quality;
  final _notes = TextEditingController();
  int? _presetHours;
  String? _loadedFor;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Load the form from the saved entry for the selected night, or from
  /// sensible defaults when there is none.
  void _syncForm(AppState state) {
    final key = dateKey(_date);
    if (_loadedFor == key) return;
    _loadedFor = key;
    final entry = state.sleepStats.entryOn(_date);
    if (entry != null) {
      _bed = entry.bedtime;
      _wake = entry.wakeTime;
      _quality = entry.quality;
      _notes.text = entry.notes;
      _presetHours = entry.durationMinutes % 60 == 0
          ? entry.durationMinutes ~/ 60
          : null;
    } else {
      _bed = '23:00';
      _wake = '07:00';
      _quality = null;
      _notes.text = '';
      _presetHours = null;
    }
  }

  int get _minutes => sleepDurationMinutes(_bed, _wake);

  Future<void> _pickTime(bool bed) async {
    final current = parseHm(bed ? _bed : _wake) ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: bed ? 'Bedtime' : 'Wake-up time',
    );
    if (picked == null || !mounted) return;
    final value = '${two(picked.hour)}:${two(picked.minute)}';
    setState(() {
      if (bed) {
        _bed = value;
      } else {
        _wake = value;
      }
      _presetHours = _minutes % 60 == 0 ? _minutes ~/ 60 : null;
    });
  }

  /// Choosing a duration keeps the wake time and moves the bedtime back.
  void _pickPreset(SleepPreset p) {
    final wake = parseHm(_wake) ?? 7 * 60;
    setState(() {
      _presetHours = p.hours;
      _bed = hmFromMinutes(wake - p.minutes);
    });
  }

  Future<void> _pickDate() async {
    final today = context.read<AppState>().today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 2, today.month, today.day),
      lastDate: today,
      helpText: 'Night you woke up on',
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _loadedFor = null;
      });
    }
  }

  void _save(AppState state) {
    if (_minutes <= 0) {
      showAppSnack(context, 'Bedtime and wake-up time cannot be the same.');
      return;
    }
    state.saveSleep(SleepEntry.fromTimes(
      date: dateKey(_date),
      bedtime: _bed,
      wakeTime: _wake,
      quality: _quality,
      notes: _notes.text.trim(),
    ));
    showAppSnack(context, 'Sleep saved for ${formatShortDate(_date)}');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _syncForm(state);
    final sleep = state.sleepStats;
    final today = state.today;
    final c = context.hc;
    final goal = state.settings.sleepGoalMinutes;
    final avg = sleep.weeklyAverageMinutes();
    final delta = sleep.weeklyDeltaVsGoal();
    final hasEntry = sleep.entryOn(_date) != null;

    final week = sleep.lastDays(7);
    final maxMinutes = [
      12 * 60,
      goal + 60,
      for (final d in week)
        if (d.minutes != null) d.minutes! + 30,
    ].reduce((a, b) => a > b ? a : b).toDouble();

    final monthEntries = sleep.entriesInMonth(today.year, today.month);

    return ScreenBody(
      children: [
        const PageHeading(
          title: 'Sleep Tracker',
          subtitle:
              'Log how long you slept. These are simple self-tracking notes, not medical advice.',
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionTitle('Log sleep')),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text(isSameDay(_date, today)
                        ? 'Last night'
                        : formatShortDate(_date)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Saved under the day you woke up (${formatLongDate(_date)}).',
                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              Text('How long did you sleep?',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final p in kSleepPresets)
                    PillChip(
                      label: '${p.hours}h · ${p.label}',
                      selected: _presetHours == p.hours,
                      onSelected: () => _pickPreset(p),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: 'Bedtime',
                      value: format12h(_bed),
                      icon: Icons.bedtime_outlined,
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeButton(
                      label: 'Wake up',
                      value: format12h(_wake),
                      icon: Icons.wb_sunny_outlined,
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _minutes <= 0
                    ? 'Choose two different times.'
                    : 'Total: ${formatDuration(_minutes)}'
                        '${_minutes >= goal ? ' · goal reached' : ' · ${formatDuration(goal - _minutes)} under your goal'}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _minutes <= 0
                        ? Theme.of(context).colorScheme.error
                        : c.text),
              ),
              const SizedBox(height: 14),
              Text('Sleep quality (optional)',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var q = 1; q <= 5; q++)
                    Semantics(
                      button: true,
                      selected: _quality == q,
                      label: 'Quality $q of 5',
                      child: IconButton(
                        tooltip: 'Quality $q of 5',
                        onPressed: () =>
                            setState(() => _quality = _quality == q ? null : q),
                        icon: Icon(
                          (_quality ?? 0) >= q ? Icons.star : Icons.star_border,
                          color: (_quality ?? 0) >= q ? c.warning : c.textSecondary,
                          size: 28,
                        ),
                      ),
                    ),
                ],
              ),
              TextField(
                controller: _notes,
                maxLength: 120,
                decoration: fieldDecoration(context, label: 'Notes (optional)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _minutes <= 0 ? null : () => _save(state),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(hasEntry ? 'Update sleep' : 'Save sleep'),
                    ),
                  ),
                  if (hasEntry) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () async {
                        final ok = await confirmAction(
                          context,
                          title: 'Delete this entry?',
                          message:
                              'Remove the sleep entry for ${formatLongDate(_date)}?',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (ok) {
                          state.deleteSleep(dateKey(_date));
                          setState(() => _loadedFor = null);
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        ResponsiveGrid(
          children: [
            StatCard(
              icon: Icons.bedtime_outlined,
              label: 'Weekly average',
              value: avg == null ? '-' : formatDuration(avg.round()),
              caption: sleep.nightsLoggedLast7() == 0
                  ? 'No nights logged'
                  : '${sleep.nightsLoggedLast7()} of 7 nights logged',
            ),
            StatCard(
              icon: Icons.flag_outlined,
              label: 'Sleep goal',
              value: formatDuration(goal),
              caption: delta == null
                  ? 'Change it in Settings'
                  : (delta >= 0
                      ? '${formatDuration(delta.round())} above goal'
                      : '${formatDuration((-delta).round())} below goal'),
            ),
            StatCard(
              icon: Icons.check_circle_outline,
              label: 'Goal nights',
              value: '${sleep.nightsMeetingGoalLast7()}/7',
              caption: 'reached your goal this week',
            ),
          ],
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Last 7 nights'),
              const SizedBox(height: 12),
              if (sleep.nightsLoggedLast7() == 0)
                const EmptyState(
                  icon: Icons.bedtime_outlined,
                  title: 'No sleep logged this week',
                  message: 'Save last night above and your chart appears here.',
                )
              else
                BarChartView(
                  maxValue: maxMinutes,
                  goal: goal.toDouble(),
                  goalLabel: 'Goal',
                  data: [
                    for (final d in week)
                      BarDatum(
                        label: kWeekdayShort[d.date.weekday - 1],
                        value: d.minutes?.toDouble(),
                        valueText:
                            d.minutes == null ? null : formatDuration(d.minutes!),
                        highlight: isSameDay(d.date, today),
                      ),
                  ],
                  semanticsSummary: 'Sleep duration for the last 7 nights: ' +
                      [
                        for (final d in week)
                          '${kWeekdayShort[d.date.weekday - 1]} ${d.minutes == null ? 'not logged' : formatDuration(d.minutes!)}',
                      ].join(', '),
                ),
            ],
          ),
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                '${kMonthNames[today.month - 1]} history',
                trailing: Text(
                  sleep.monthAverageMinutes(today.year, today.month) == null
                      ? ''
                      : 'Avg ${formatDuration(sleep.monthAverageMinutes(today.year, today.month)!.round())}',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
              ),
              if (monthEntries.isEmpty)
                const EmptyState(
                  icon: Icons.history,
                  title: 'No entries this month',
                  message: 'Your nightly entries will be listed here.',
                )
              else
                for (final e in monthEntries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${formatLongDate(tryParseDateKey(e.date)!)} · ${formatDuration(e.durationMinutes)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${format12h(e.bedtime)} to ${format12h(e.wakeTime)}'
                      '${e.quality == null ? '' : ' · quality ${e.quality}/5'}'
                      '${e.notes.isEmpty ? '' : ' · ${e.notes}'}',
                      style: TextStyle(color: c.textSecondary),
                    ),
                    trailing: IconButton(
                      tooltip: 'Edit ${e.date}',
                      icon: Icon(Icons.edit_outlined, color: c.primaryStrong),
                      onPressed: () {
                        setState(() {
                          _date = tryParseDateKey(e.date)!;
                          _loadedFor = null;
                        });
                      },
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      button: true,
      label: '$label, $value. Tap to change.',
      child: InkWell(
        borderRadius: BorderRadius.circular(kControlRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(kControlRadius),
            border: Border.all(color: c.border, width: 1.4),
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(icon, color: c.primaryStrong),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 12.5)),
                      Text(value,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
