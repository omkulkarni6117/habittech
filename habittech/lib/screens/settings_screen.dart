import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../models/user_settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/page_heading.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  final _nameKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: context.read<AppState>().settings.displayName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _saveName() {
    if (!_nameKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    state.updateSettings(
        state.settings.copyWith(displayName: _name.text.trim()));
    FocusScope.of(context).unfocus();
    showAppSnack(context, 'Name saved');
  }

  Future<void> _export() async {
    final state = context.read<AppState>();
    final json = state.exportJson();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export backup'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy this text and keep it somewhere safe. Paste it into "Import" to restore everything.',
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ctx.hc.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ctx.hc.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      json,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: json));
              if (ctx.mounted) Navigator.of(ctx).pop();
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                    const SnackBar(content: Text('Backup copied to clipboard')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final state = context.read<AppState>();
    final controller = TextEditingController();
    String? error;

    final imported = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Import backup'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste a HabitTech backup. It is fully checked first; if anything is wrong nothing changes. A valid backup replaces all current data.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 6,
                  maxLines: 10,
                  decoration: fieldDecoration(ctx, label: 'Backup JSON'),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    controller.text = data?.text ?? '';
                    setLocal(() => error = null);
                  },
                  icon: const Icon(Icons.paste),
                  label: const Text('Paste from clipboard'),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final result = state.importJson(controller.text);
                if (result == null) {
                  Navigator.of(ctx).pop(true);
                } else {
                  setLocal(() => error = result);
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (imported == true && mounted) {
      _name.text = state.settings.displayName;
      showAppSnack(context, 'Backup imported');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final c = context.hc;

    Widget row(String title, String? subtitle, Widget trailing) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (subtitle != null)
                      Text(subtitle,
                          style: TextStyle(color: c.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        );

    Widget stepper(int value, int min, int max, int step,
        ValueChanged<int> onChanged, String label, String Function(int) show) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            tooltip: 'Decrease $label',
            onPressed: value > min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 64,
            child: Text(show(value),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          IconButton.outlined(
            tooltip: 'Increase $label',
            onPressed: value < max ? () => onChanged(value + step) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      );
    }

    return ScreenBody(
      children: [
        const PageHeading(
          title: 'Settings & Profile',
          subtitle: 'Make HabitTech yours. Everything is stored on this device.',
        ),
        SoftCard(
          child: Form(
            key: _nameKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Profile'),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _name,
                        maxLength: 24,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            fieldDecoration(context, label: 'Display name'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                        onFieldSubmitted: (_) => _saveName(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: FilledButton(
                          onPressed: _saveName, child: const Text('Save')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Preferences'),
              const SizedBox(height: 10),
              Text('Theme',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 8),
              SegmentedButton<ThemeSetting>(
                segments: [
                  for (final t in ThemeSetting.values)
                    ButtonSegment(value: t, label: Text(t.label)),
                ],
                selected: {s.theme},
                onSelectionChanged: (v) =>
                    state.updateSettings(s.copyWith(theme: v.first)),
              ),
              const SizedBox(height: 16),
              Text('Week starts on',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Mon')),
                  ButtonSegment(value: 6, label: Text('Sat')),
                  ButtonSegment(value: 7, label: Text('Sun')),
                ],
                selected: {s.weekStartsOn},
                onSelectionChanged: (v) =>
                    state.updateSettings(s.copyWith(weekStartsOn: v.first)),
              ),
              const Divider(height: 28),
              row(
                'Daily habit goal',
                'Habits to finish for a successful day. Drives streaks and consistency.',
                stepper(
                  s.dailyHabitGoal,
                  1,
                  20,
                  1,
                  (v) => state.updateSettings(s.copyWith(dailyHabitGoal: v)),
                  'daily goal',
                  (v) => '$v',
                ),
              ),
              row(
                'Sleep goal',
                'Used in the sleep tracker and analytics.',
                stepper(
                  s.sleepGoalMinutes,
                  240,
                  720,
                  30,
                  (v) => state.updateSettings(s.copyWith(sleepGoalMinutes: v)),
                  'sleep goal',
                  formatDuration,
                ),
              ),
            ],
          ),
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Your data'),
              const SizedBox(height: 4),
              Text(
                state.isDemo
                    ? 'You are using sample data.'
                    : 'Your data is stored only on this device.',
                style: TextStyle(color: c.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Export backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.download),
                    label: const Text('Import backup'),
                  ),
                ],
              ),
              const Divider(height: 28),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await confirmAction(
                        context,
                        title: 'Reset sample data?',
                        message:
                            'This replaces ALL habits, history, sleep, notes and workout plans with fresh sample data.',
                        confirmLabel: 'Reset',
                        destructive: true,
                      );
                      if (ok) state.resetDemoData();
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset sample data'),
                  ),
                  if (state.isDemo)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await confirmAction(
                          context,
                          title: 'Clear sample data?',
                          message:
                              'Removes the sample habits, history, sleep, notes and workout plan. Settings and your exercise library stay.',
                          confirmLabel: 'Clear',
                          destructive: true,
                        );
                        if (ok) state.clearDemoData();
                      },
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Clear sample data'),
                    ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kDestructive,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final ok = await confirmAction(
                        context,
                        title: 'Erase everything?',
                        message:
                            'This permanently deletes every habit, record, sleep entry, note, workout plan and setting on this device. Export a backup first if you might want it back.',
                        confirmLabel: 'Erase everything',
                        destructive: true,
                      );
                      if (ok) {
                        state.clearAllData();
                        _name.text = state.settings.displayName;
                      }
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Erase all data'),
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
              const SectionTitle('About'),
              const SizedBox(height: 8),
              const HabitTechLogo(),
              const SizedBox(height: 8),
              Text(
                'Build Better Habits. Become Better Every Day.',
                style: TextStyle(color: c.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Habit reminders are saved with each habit; this version does not send device notifications.',
                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
