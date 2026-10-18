import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../models/workout.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';

// --------------------------------------------------------------- text prompt

/// Asks for one line of text. Returns null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  String initial = '',
  int maxLength = 60,
  bool allowEmpty = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      hint: hint,
      initial: initial,
      maxLength: maxLength,
      allowEmpty: allowEmpty,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.initial,
    required this.maxLength,
    required this.allowEmpty,
  });

  final String title;
  final String label;
  final String? hint;
  final String initial;
  final int maxLength;
  final bool allowEmpty;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              fieldDecoration(context, label: widget.label, hint: widget.hint),
          validator: (v) => !widget.allowEmpty && (v ?? '').trim().isEmpty
              ? 'Enter a value'
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

// ------------------------------------------------------- planned exercise

/// Opens the sets/reps editor for an item already on the plan.
Future<void> showEditPlanned(
    BuildContext context, int weekday, PlannedExercise item) {
  final state = context.read<AppState>();
  final exercise = state.exerciseById[item.exerciseId];
  if (exercise == null) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (_) => _PlannedEditorDialog(
      weekday: weekday,
      exercise: exercise,
      existing: item,
    ),
  );
}

/// Pick an exercise from the library (or create one) and add it to a day.
Future<void> showAddToPlan(BuildContext context, int weekday) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ExercisePicker(weekday: weekday),
  );
}

class _PlannedEditorDialog extends StatefulWidget {
  const _PlannedEditorDialog({
    required this.weekday,
    required this.exercise,
    this.existing,
  });

  final int weekday;
  final Exercise exercise;
  final PlannedExercise? existing;

  @override
  State<_PlannedEditorDialog> createState() => _PlannedEditorDialogState();
}

class _PlannedEditorDialogState extends State<_PlannedEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  late final TextEditingController _duration;
  late final TextEditingController _rest;
  late final TextEditingController _notes;

  bool get _timed => widget.exercise.kind == ExerciseKind.timed;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    final p = widget.existing;
    _sets = TextEditingController(text: '${p?.sets ?? e.defaultSets}');
    _reps = TextEditingController(text: '${p?.reps ?? e.defaultReps}');
    _weight = TextEditingController(
        text: p?.weightKg == null ? '' : formatNumber(p!.weightKg!));
    _duration = TextEditingController(
        text: '${p?.durationMin ?? e.defaultDurationMin}');
    _rest = TextEditingController(text: '${p?.restSec ?? e.defaultRestSec}');
    _notes = TextEditingController(text: p?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_sets, _reps, _weight, _duration, _rest, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _intRule(String? v, int min, int max, String what) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a number';
    if (n < min || n > max) return '$what: $min to $max';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final weightText = _weight.text.trim();
    final weight = weightText.isEmpty ? null : double.parse(weightText);
    final existing = widget.existing;
    final item = PlannedExercise(
      id: existing?.id ?? state.newId('p'),
      exerciseId: widget.exercise.id,
      sets: _timed ? 1 : int.parse(_sets.text.trim()),
      reps: _timed ? widget.exercise.defaultReps : int.parse(_reps.text.trim()),
      weightKg: _timed ? null : weight,
      durationMin: _timed ? int.parse(_duration.text.trim()) : null,
      restSec: _timed ? 0 : int.parse(_rest.text.trim()),
      notes: _notes.text.trim(),
    );
    if (existing == null) {
      state.addPlannedExercise(widget.weekday, item);
    } else {
      state.updatePlannedExercise(widget.weekday, item);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    Widget row(List<Widget> children) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: children[i]),
            ],
          ],
        );

    return AlertDialog(
      title: Text(widget.exercise.name),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_timed)
                TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration:
                      fieldDecoration(context, label: 'Duration (minutes)'),
                  validator: (v) => _intRule(v, 1, 600, 'Minutes'),
                )
              else ...[
                row([
                  TextFormField(
                    controller: _sets,
                    keyboardType: TextInputType.number,
                    decoration: fieldDecoration(context, label: 'Sets'),
                    validator: (v) => _intRule(v, 1, 20, 'Sets'),
                  ),
                  TextFormField(
                    controller: _reps,
                    keyboardType: TextInputType.number,
                    decoration: fieldDecoration(context, label: 'Reps'),
                    validator: (v) => _intRule(v, 1, 200, 'Reps'),
                  ),
                ]),
                const SizedBox(height: 12),
                row([
                  TextFormField(
                    controller: _weight,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: fieldDecoration(context,
                        label: 'Weight (kg)', helper: 'Optional'),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final n = double.tryParse(t);
                      if (n == null || n < 0 || n > 1000) return '0 to 1000';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _rest,
                    keyboardType: TextInputType.number,
                    decoration: fieldDecoration(context, label: 'Rest (sec)'),
                    validator: (v) => _intRule(v, 0, 600, 'Rest'),
                  ),
                ]),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLength: 120,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: fieldDecoration(context,
                    label: 'Notes (optional)', hint: 'Tempo, cues, machine setting'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEdit ? 'Save' : 'Add to ${kWeekdayLong[widget.weekday - 1]}'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ exercise picker

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({required this.weekday});
  final int weekday;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _query = '';
  MuscleGroup? _group;

  Future<void> _pick(Exercise exercise) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _PlannedEditorDialog(
        weekday: widget.weekday,
        exercise: exercise,
      ),
    );
    if (added == true && mounted) {
      // Grab the messenger first: the sheet's own context is gone after pop.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Added ${exercise.name}')));
    }
  }

  Future<void> _createNew() async {
    final created = await showDialog<Exercise>(
      context: context,
      builder: (_) => const _ExerciseFormDialog(),
    );
    if (created != null && mounted) await _pick(created);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.hc;
    final day = state.workoutPlan.day(widget.weekday);
    final onDay = {for (final i in day.items) i.exerciseId};
    final q = _query.trim().toLowerCase();
    final list = state.exercises.where((e) {
      if (_group != null && e.muscleGroup != _group) return false;
      return q.isEmpty || e.name.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Add to ${kWeekdayLong[widget.weekday - 1]}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _createNew,
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: fieldDecoration(context,
                  label: 'Search exercises',
                  suffix: const Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: PillChip(
                    label: 'All',
                    selected: _group == null,
                    onSelected: () => setState(() => _group = null),
                  ),
                ),
                for (final g in MuscleGroup.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PillChip(
                      label: g.label,
                      selected: _group == g,
                      onSelected: () => setState(() => _group = g),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: Icons.search_off,
                      title: 'No matching exercises',
                      message: 'Try another search, or create a new exercise.',
                      actionLabel: 'New exercise',
                      onAction: _createNew,
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final e = list[i];
                      final already = onDay.contains(e.id);
                      return ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        title: Text(e.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          [
                            e.muscleGroup.label,
                            if (e.equipment.isNotEmpty) e.equipment,
                            if (already) 'already on this day',
                          ].join(' · '),
                          style: TextStyle(color: c.textSecondary),
                        ),
                        trailing: Icon(Icons.add_circle_outline,
                            color: c.primaryStrong),
                        onTap: () => _pick(e),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- exercise library

/// Manage the exercise library: add, edit and delete exercises.
Future<void> showExerciseLibrary(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _LibrarySheet(),
  );
}

class _LibrarySheet extends StatelessWidget {
  const _LibrarySheet();

  Future<void> _delete(BuildContext context, Exercise e) async {
    final state = context.read<AppState>();
    final used = state.planUsageCount(e.id);
    final ok = await confirmAction(
      context,
      title: 'Delete "${e.name}"?',
      message: used == 0
          ? 'It will be removed from your library.'
          : 'It is used $used time${used == 1 ? '' : 's'} in your weekly plan and will be removed from there too.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok) state.deleteExercise(e.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.hc;
    final groups = <MuscleGroup, List<Exercise>>{};
    for (final e in state.exercises) {
      groups.putIfAbsent(e.muscleGroup, () => []).add(e);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Exercise library',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showDialog<Exercise>(
                    context: context,
                    builder: (_) => const _ExerciseFormDialog(),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.exercises.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.fitness_center,
                      title: 'No exercises yet',
                      message: 'Create your first exercise to start planning.',
                    ),
                  )
                : ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    children: [
                      for (final g in MuscleGroup.values)
                        if (groups[g] != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                            child: Text(g.label,
                                style: TextStyle(
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ),
                          for (final e in (groups[g]!
                            ..sort((a, b) => a.name.compareTo(b.name))))
                            ListTile(
                              title: Text(e.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                e.kind == ExerciseKind.timed
                                    ? 'Timed · ${e.defaultDurationMin} min'
                                    : '${e.defaultSets} x ${e.defaultReps}'
                                        '${e.equipment.isEmpty ? '' : ' · ${e.equipment}'}',
                                style: TextStyle(color: c.textSecondary),
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Actions for ${e.name}',
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    showDialog<Exercise>(
                                      context: context,
                                      builder: (_) =>
                                          _ExerciseFormDialog(existing: e),
                                    );
                                  } else {
                                    _delete(context, e);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- exercise form

class _ExerciseFormDialog extends StatefulWidget {
  const _ExerciseFormDialog({this.existing});
  final Exercise? existing;

  @override
  State<_ExerciseFormDialog> createState() => _ExerciseFormDialogState();
}

class _ExerciseFormDialogState extends State<_ExerciseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _equipment;
  late final TextEditingController _notes;
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _duration;
  late final TextEditingController _rest;
  late MuscleGroup _group;
  late ExerciseKind _kind;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _equipment = TextEditingController(text: e?.equipment ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _sets = TextEditingController(text: '${e?.defaultSets ?? 3}');
    _reps = TextEditingController(text: '${e?.defaultReps ?? 10}');
    _duration = TextEditingController(text: '${e?.defaultDurationMin ?? 20}');
    _rest = TextEditingController(text: '${e?.defaultRestSec ?? 60}');
    _group = e?.muscleGroup ?? MuscleGroup.fullBody;
    _kind = e?.kind ?? ExerciseKind.strength;
  }

  @override
  void dispose() {
    for (final c in [_name, _equipment, _notes, _sets, _reps, _duration, _rest]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _intRule(String? v, int min, int max) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a number';
    if (n < min || n > max) return '$min to $max';
    return null;
  }

  void _save() {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final existing = widget.existing;
    final draft = Exercise(
      id: existing?.id ?? state.newId('ex'),
      name: _name.text.trim(),
      muscleGroup: _group,
      kind: _kind,
      equipment: _equipment.text.trim(),
      notes: _notes.text.trim(),
      defaultSets: _kind == ExerciseKind.timed ? 1 : int.parse(_sets.text.trim()),
      defaultReps: int.parse(_reps.text.trim()),
      defaultDurationMin: int.parse(_duration.text.trim()),
      defaultRestSec: _kind == ExerciseKind.timed ? 0 : int.parse(_rest.text.trim()),
    );
    final error =
        existing == null ? state.addExercise(draft) : state.updateExercise(draft);
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final timed = _kind == ExerciseKind.timed;
    return AlertDialog(
      title: Text(widget.existing == null ? 'New exercise' : 'Edit exercise'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                autofocus: widget.existing == null,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: fieldDecoration(context,
                    label: 'Exercise name', hint: 'e.g. Cable Fly'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 8),
              Text('Muscle group',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: context.hc.text)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final g in MuscleGroup.values)
                    PillChip(
                      label: g.label,
                      selected: _group == g,
                      onSelected: () => setState(() => _group = g),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<ExerciseKind>(
                segments: [
                  for (final k in ExerciseKind.values)
                    ButtonSegment(value: k, label: Text(k.label)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 12),
              if (timed)
                TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: fieldDecoration(context,
                      label: 'Default duration (minutes)'),
                  validator: (v) => _intRule(v, 1, 600),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sets,
                        keyboardType: TextInputType.number,
                        decoration: fieldDecoration(context, label: 'Sets'),
                        validator: (v) => _intRule(v, 1, 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _reps,
                        keyboardType: TextInputType.number,
                        decoration: fieldDecoration(context, label: 'Reps'),
                        validator: (v) => _intRule(v, 1, 200),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _rest,
                        keyboardType: TextInputType.number,
                        decoration: fieldDecoration(context, label: 'Rest s'),
                        validator: (v) => _intRule(v, 0, 600),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _equipment,
                maxLength: 40,
                decoration: fieldDecoration(context,
                    label: 'Equipment (optional)', hint: 'Dumbbells, bench...'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notes,
                maxLength: 120,
                maxLines: 2,
                minLines: 1,
                decoration: fieldDecoration(context, label: 'Notes (optional)'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.existing == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
