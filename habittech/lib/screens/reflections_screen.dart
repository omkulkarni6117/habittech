import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../models/reflection.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/page_heading.dart';

const int kReflectionMaxLength = 2000;

class ReflectionsScreen extends StatefulWidget {
  const ReflectionsScreen({super.key});

  @override
  State<ReflectionsScreen> createState() => _ReflectionsScreenState();
}

class _ReflectionsScreenState extends State<ReflectionsScreen> {
  late final TextEditingController _text;
  final _search = TextEditingController();
  String _query = '';
  DateTime? _filterDate;
  bool _justSaved = false;

  AppState get _state => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    // The draft lives in AppState, so leaving this tab never loses text.
    _text = TextEditingController(text: _state.reflectionDraft.text);
    _text.addListener(() {
      _state.reflectionDraft.text = _text.text;
      if (_justSaved) setState(() => _justSaved = false);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final draft = _state.reflectionDraft;
    final today = _state.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.date,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      helpText: 'Reflection date',
    );
    if (picked != null && mounted) {
      setState(() => draft.date = picked);
    }
  }

  void _save() {
    final state = _state;
    final draft = state.reflectionDraft;
    if (_text.text.trim().isEmpty) {
      showAppSnack(context, 'Write something first.');
      return;
    }
    state.saveReflection(
      id: draft.editingId,
      date: draft.date,
      content: _text.text,
    );
    state.resetReflectionDraft();
    _text.clear();
    setState(() => _justSaved = true);
  }

  void _startEdit(Reflection r) {
    final draft = _state.reflectionDraft;
    setState(() {
      draft
        ..editingId = r.id
        ..date = tryParseDateKey(r.date) ?? _state.today
        ..text = r.content;
      _text.text = r.content;
      _justSaved = false;
    });
  }

  void _cancelEdit() {
    _state.resetReflectionDraft();
    setState(() {
      _text.clear();
    });
  }

  Future<void> _delete(Reflection r) async {
    final state = _state;
    final ok = await confirmAction(
      context,
      title: 'Delete this reflection?',
      message: 'The note from ${formatLongDate(tryParseDateKey(r.date)!)} will be removed for good.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    if (state.reflectionDraft.editingId == r.id) _cancelEdit();
    state.deleteReflection(r.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final draft = state.reflectionDraft;
    final c = context.hc;
    final editing = draft.editingId != null;

    final all = state.reflections;
    final q = _query.trim().toLowerCase();
    final shown = all.where((r) {
      if (_filterDate != null && r.date != dateKey(_filterDate!)) return false;
      return q.isEmpty || r.content.toLowerCase().contains(q);
    }).toList();

    final length = _text.text.length;

    return ScreenBody(
      children: [
        const PageHeading(
          title: 'Notes & Reflections',
          subtitle: 'Capture how the day went and what you want to improve.',
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SectionTitle(
                        editing ? 'Edit reflection' : 'New reflection'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text(isSameDay(draft.date, state.today)
                        ? 'Today'
                        : formatShortDate(draft.date)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                minLines: 5,
                maxLines: 10,
                maxLength: kReflectionMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textCapitalization: TextCapitalization.sentences,
                decoration: fieldDecoration(
                  context,
                  hint:
                      'Write your daily reflections, monthly goals, achievements, or things to improve...',
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _justSaved
                          ? 'Saved ✓'
                          : '$length / $kReflectionMaxLength characters',
                      style: TextStyle(
                        color: _justSaved ? c.success : c.textSecondary,
                        fontWeight: _justSaved ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (editing)
                    TextButton(
                        onPressed: _cancelEdit, child: const Text('Cancel')),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(editing ? 'Update' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Previous reflections (${all.length})'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: fieldDecoration(
                        context,
                        label: 'Search',
                        suffix: _query.isEmpty
                            ? const Icon(Icons.search)
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: _filterDate == null
                        ? 'Filter by date'
                        : 'Filtering ${formatShortDate(_filterDate!)}. Tap to change.',
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _filterDate ?? state.today,
                        firstDate: DateTime(state.today.year - 5),
                        lastDate: state.today,
                        helpText: 'Show reflections from',
                      );
                      if (picked != null && mounted) {
                        setState(() => _filterDate = picked);
                      }
                    },
                    icon: Icon(
                      Icons.event,
                      color: _filterDate == null ? null : c.primaryStrong,
                    ),
                  ),
                ],
              ),
              if (_filterDate != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InputChip(
                      label: Text('Date: ${formatShortDate(_filterDate!)}'),
                      onDeleted: () => setState(() => _filterDate = null),
                      deleteButtonTooltipMessage: 'Remove date filter',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (all.isEmpty)
                const EmptyState(
                  icon: Icons.edit_note,
                  title: 'No reflections yet',
                  message: 'Your saved notes will show up here.',
                )
              else if (shown.isEmpty)
                const EmptyState(
                  icon: Icons.search_off,
                  title: 'No matches',
                  message: 'Try a different search or clear the date filter.',
                )
              else
                for (final r in shown)
                  _ReflectionTile(
                    reflection: r,
                    onEdit: () => _startEdit(r),
                    onDelete: () => _delete(r),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReflectionTile extends StatelessWidget {
  const _ReflectionTile({
    required this.reflection,
    required this.onEdit,
    required this.onDelete,
  });

  final Reflection reflection;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final date = tryParseDateKey(reflection.date)!;
    final edited = reflection.updatedAt.isAfter(reflection.createdAt);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(kControlRadius),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatLongDate(date)}${edited ? ' · edited' : ''}',
                  style: TextStyle(
                    color: c.primaryStrong,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit reflection from ${formatShortDate(date)}',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'Delete reflection from ${formatShortDate(date)}',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(reflection.content, style: const TextStyle(height: 1.4)),
          ),
        ],
      ),
    );
  }
}
