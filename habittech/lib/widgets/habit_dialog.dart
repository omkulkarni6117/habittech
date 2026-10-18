import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../core/time_utils.dart';
import '../models/habit.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'habit_icons.dart';

/// Opens the add/edit habit dialog. Pass [habit] to edit.
Future<void> showHabitDialog(BuildContext context, {Habit? habit}) {
  return showDialog<void>(
    context: context,
    builder: (_) => HabitDialog(habit: habit),
  );
}

class HabitDialog extends StatefulWidget {
  const HabitDialog({super.key, this.habit});

  final Habit? habit;

  @override
  State<HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<HabitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _goalValue;
  late final TextEditingController _goalUnit;
  late String _icon;
  late HabitCategory _category;
  late ScheduleType _schedule;
  late Set<int> _weekdays;
  String? _reminder;
  late DateTime _startDate;
  bool _saving = false;
  String? _formError;
  String? _weekdayError;

  bool get _isEdit => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _name = TextEditingController(text: h?.name ?? '');
    _description = TextEditingController(text: h?.description ?? '');
    _goalValue = TextEditingController(
        text: h?.goalValue == null ? '' : formatNumber(h!.goalValue!));
    _goalUnit = TextEditingController(text: h?.goalUnit ?? '');
    _icon = h?.iconKey ?? 'task_alt';
    _category = h?.category ?? HabitCategory.custom;
    _schedule = h?.scheduleType ?? ScheduleType.daily;
    _weekdays = h != null && h.scheduleType == ScheduleType.weekly
        ? h.weekdays.toSet()
        : {1, 2, 3, 4, 5};
    _reminder = h?.reminderTime;
    _startDate = h == null
        ? context.read<AppState>().today
        : (tryParseDateKey(h.startDate) ?? context.read<AppState>().today);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _goalValue.dispose();
    _goalUnit.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final today = context.read<AppState>().today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(today.year - 3, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
      helpText: 'Habit start date',
    );
    if (picked != null && mounted) setState(() => _startDate = picked);
  }

  Future<void> _pickReminder() async {
    final minutes = _reminder == null ? 8 * 60 : (parseHm(_reminder!) ?? 480);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: 'Reminder time',
    );
    if (picked != null && mounted) {
      setState(() => _reminder = '${two(picked.hour)}:${two(picked.minute)}');
    }
  }

  String? _validateName(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Enter a habit name';
    if (text.length > 40) return 'Keep the name under 40 characters';
    return null;
  }

  String? _validateGoalValue(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;
    final n = double.tryParse(text);
    if (n == null || n <= 0) return 'Enter a number greater than 0';
    if (n > 1000000) return 'That number is too large';
    return null;
  }

  String? _validateGoalUnit(String? v) {
    final hasValue = _goalValue.text.trim().isNotEmpty;
    if (hasValue && (v ?? '').trim().isEmpty) {
      return 'Add a unit, e.g. minutes';
    }
    if ((v ?? '').trim().length > 20) return 'Max 20 characters';
    return null;
  }

  void _save() {
    if (_saving) return; // prevents double submission
    final formOk = _formKey.currentState!.validate();
    final daysOk = _schedule == ScheduleType.daily || _weekdays.isNotEmpty;
    setState(() => _weekdayError = daysOk ? null : 'Pick at least one day');
    if (!formOk || !daysOk) return;

    setState(() {
      _saving = true;
      _formError = null;
    });

    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final goalText = _goalValue.text.trim();
    final goal = goalText.isEmpty ? null : double.parse(goalText);
    final days = _schedule == ScheduleType.daily
        ? const [1, 2, 3, 4, 5, 6, 7]
        : (_weekdays.toList()..sort());
    final existing = widget.habit;

    final String? error;
    if (existing == null) {
      error = state.addHabit(Habit(
        id: state.newId('h'),
        name: _name.text.trim(),
        description: _description.text.trim(),
        iconKey: _icon,
        category: _category,
        scheduleType: _schedule,
        weekdays: days,
        goalValue: goal,
        goalUnit: goal == null ? '' : _goalUnit.text.trim(),
        reminderTime: _reminder,
        startDate: dateKey(_startDate),
        createdAt: state.now,
      ));
    } else {
      error = state.updateHabit(existing.copyWith(
        name: _name.text.trim(),
        description: _description.text.trim(),
        iconKey: _icon,
        category: _category,
        scheduleType: _schedule,
        weekdays: days,
        goalValue: goal,
        clearGoal: goal == null,
        goalUnit: goal == null ? '' : _goalUnit.text.trim(),
        reminderTime: _reminder,
        clearReminder: _reminder == null,
        startDate: dateKey(_startDate),
      ));
    }

    if (error != null) {
      setState(() {
        _saving = false;
        _formError = error;
      });
      return;
    }
    final name = _name.text.trim();
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Saved "$name"' : 'Added "$name"'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: c.text,
      fontSize: 14,
    );

    Widget field(String label, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(height: 8),
            child,
          ],
        );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius + 2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit habit' : 'Add habit',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _name,
                        autofocus: !_isEdit,
                        maxLength: 40,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        decoration: fieldDecoration(context,
                            label: 'Habit name', hint: 'e.g. Morning run'),
                        validator: _validateName,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _description,
                        maxLength: 100,
                        maxLines: 2,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: fieldDecoration(context,
                            label: 'Description (optional)',
                            hint: 'What counts as done?'),
                      ),
                      const SizedBox(height: 8),
                      field(
                        'Icon',
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in kHabitIcons.entries)
                              _IconChoice(
                                iconKey: entry.key,
                                icon: entry.value,
                                selected: _icon == entry.key,
                                onTap: () => setState(() => _icon = entry.key),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      field(
                        'Category',
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final cat in HabitCategory.values)
                              PillChip(
                                label: cat.label,
                                selected: _category == cat,
                                onSelected: () =>
                                    setState(() => _category = cat),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      field(
                        'Schedule',
                        SegmentedButton<ScheduleType>(
                          segments: const [
                            ButtonSegment(
                              value: ScheduleType.daily,
                              label: Text('Daily'),
                              icon: Icon(Icons.today),
                            ),
                            ButtonSegment(
                              value: ScheduleType.weekly,
                              label: Text('Specific days'),
                              icon: Icon(Icons.date_range),
                            ),
                          ],
                          selected: {_schedule},
                          onSelectionChanged: (s) =>
                              setState(() => _schedule = s.first),
                        ),
                      ),
                      if (_schedule == ScheduleType.weekly) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (var w = 1; w <= 7; w++)
                              FilterChip(
                                label: Text(kWeekdayShort[w - 1]),
                                selected: _weekdays.contains(w),
                                showCheckmark: false,
                                selectedColor: c.primarySoft,
                                side: BorderSide(
                                  color: _weekdays.contains(w)
                                      ? c.primaryStrong
                                      : c.border,
                                  width: _weekdays.contains(w) ? 2 : 1,
                                ),
                                onSelected: (on) => setState(() {
                                  if (on) {
                                    _weekdays.add(w);
                                  } else {
                                    _weekdays.remove(w);
                                  }
                                  _weekdayError = null;
                                }),
                              ),
                          ],
                        ),
                        if (_weekdayError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _weekdayError!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12.5),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _weekdays.isEmpty
                                  ? ''
                                  : 'Target: ${_weekdays.length}x per week',
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 12.5),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      Text('Goal (optional)', style: labelStyle),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _goalValue,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration:
                                  fieldDecoration(context, label: 'Amount'),
                              validator: _validateGoalValue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _goalUnit,
                              decoration: fieldDecoration(context,
                                  label: 'Unit', hint: 'minutes, litres...'),
                              validator: _validateGoalUnit,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Reminder (optional)', style: labelStyle),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickReminder,
                              icon: const Icon(Icons.alarm),
                              label: Text(_reminder == null
                                  ? 'Set reminder time'
                                  : format12h(_reminder!)),
                            ),
                          ),
                          if (_reminder != null)
                            IconButton(
                              tooltip: 'Remove reminder',
                              onPressed: () => setState(() => _reminder = null),
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Saved with the habit. This version does not send device notifications.',
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Start date', style: labelStyle),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickStart,
                        icon: const Icon(Icons.event),
                        label: Text(formatLongDate(_startDate)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'The habit only counts from this day, so it never changes your past statistics.',
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 12.5),
                        ),
                      ),
                      if (_formError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _formError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_isEdit ? 'Save changes' : 'Add habit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.iconKey,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String iconKey;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Icon ${iconKey.replaceAll('_', ' ')}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? c.primaryStrong : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Icon(icon, color: c.primaryStrong, size: 22),
        ),
      ),
    );
  }
}
