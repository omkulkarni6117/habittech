import 'package:flutter_test/flutter_test.dart';
import 'package:habittech/app/sections.dart';
import 'package:habittech/core/date_utils.dart';
import 'package:habittech/data/in_memory_repository.dart';
import 'package:habittech/models/habit.dart';
import 'package:habittech/models/sleep_entry.dart';
import 'package:habittech/state/app_state.dart';

import 'helpers.dart';

void main() {
  final today = dayOnly(kNow); // Wednesday

  group('toggling completion', () {
    test('marks a habit done, then undone', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('a', start: '2026-10-01'));

      expect(state.toggleCompletion('a', today), isTrue);
      expect(state.isHabitDone('a', today), isTrue);
      expect(state.stats.dayCount(today).completed, 1);

      expect(state.toggleCompletion('a', today), isTrue);
      expect(state.isHabitDone('a', today), isFalse);
      expect(state.data.completions, isEmpty);
    });

    test('never creates two records for the same habit and day', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('a', start: '2026-10-01'));
      // Tap fast, many times, on the same day.
      for (var i = 0; i < 7; i++) {
        state.toggleCompletion('a', today);
      }
      final records = state.data.completions
          .where((c) => c.habitId == 'a' && c.date == dateKey(today));
      expect(records.length, 1); // odd number of taps leaves exactly one
      expect({for (final c in state.data.completions) c.id}.length,
          state.data.completions.length);
    });

    test('uses the calendar day regardless of time of day', () async {
      final (state, _) = await emptyState(now: DateTime(2026, 10, 14, 23, 58));
      state.addHabit(makeHabit('a', start: '2026-10-01'));
      state.toggleCompletion('a', DateTime(2026, 10, 14, 0, 1));
      expect(state.data.completions.single.date, '2026-10-14');
    });

    test('future days cannot be completed', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('a', start: '2026-10-01'));
      expect(state.toggleCompletion('a', addDays(today, 1)), isFalse);
      expect(state.data.completions, isEmpty);
    });

    test('unknown habits and unscheduled days are rejected', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('w',
          start: '2026-10-01', type: ScheduleType.weekly, weekdays: const [1]));
      expect(state.toggleCompletion('nope', today), isFalse);
      expect(state.toggleCompletion('w', today), isFalse); // Wed, Monday-only
      expect(state.toggleCompletion('w', DateTime(2026, 10, 12)), isTrue);
      // Before the start date.
      expect(state.toggleCompletion('w', DateTime(2026, 9, 28)), isFalse);
    });

    test('listeners are notified so the UI updates immediately', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('a', start: '2026-10-01'));
      var calls = 0;
      state.addListener(() => calls++);
      state.toggleCompletion('a', today);
      expect(calls, 1);
    });
  });

  group('habit management', () {
    test('rejects blank and duplicate names (case-insensitive)', () async {
      final (state, _) = await emptyState();
      expect(state.addHabit(makeHabit('a', name: 'Run')), isNull);
      expect(state.addHabit(makeHabit('b', name: '  run ')), isNotNull);
      expect(state.addHabit(makeHabit('c', name: '   ')), isNotNull);
      expect(state.habits.length, 1);
    });

    test('archive keeps history, restore brings the habit back', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('a', start: '2026-10-01'));
      state.toggleCompletion('a', today);
      state.archiveHabit('a');
      expect(state.activeHabits, isEmpty);
      expect(state.archivedHabits.length, 1);
      expect(state.data.completions.length, 1);
      state.restoreHabit('a');
      expect(state.activeHabits.length, 1);
    });

    test('delete removes the habit and its completions', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('a', start: '2026-10-01'));
      state.addHabit(makeHabit('b', start: '2026-10-01'));
      state.toggleCompletion('a', today);
      state.toggleCompletion('b', today);
      state.deleteHabit('a');
      expect(state.habits.map((h) => h.id), ['b']);
      expect(state.data.completions.map((c) => c.habitId), ['b']);
    });

    test('editing a habit updates stats immediately', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('a', start: '2026-10-01'));
      expect(state.stats.dayCount(today).scheduled, 1);
      state.updateHabit(state.habitById('a')!.copyWith(startDate: '2026-10-20'));
      expect(state.stats.dayCount(today).scheduled, 0);
    });
  });

  group('persistence', () {
    test('everything survives a reload', () async {
      final (state, repo) = await emptyState();
      state.addHabit(makeHabit('a', start: '2026-10-01'));
      state.toggleCompletion('a', today);
      state.saveSleep(SleepEntry.fromTimes(
          date: '2026-10-14', bedtime: '23:00', wakeTime: '07:00', quality: 4));
      state.saveReflection(date: today, content: 'A good day');
      await state.flush();

      final reloaded = AppState(repository: repo, clock: () => kNow);
      await reloaded.init();
      expect(reloaded.habits.map((h) => h.id), ['a']);
      expect(reloaded.isHabitDone('a', today), isTrue);
      expect(reloaded.sleepEntries.single.durationMinutes, 480);
      expect(reloaded.reflections.single.content, 'A good day');
      expect(reloaded.isDemo, isFalse);
    });

    test('first launch loads sample data and stores it', () async {
      final repo = InMemoryStorageRepository();
      final state = AppState(repository: repo, clock: () => kNow);
      await state.init();
      await state.flush();
      expect(state.isDemo, isTrue);
      expect(state.habits.length, 7);
      expect(repo.raw, isNotNull);
    });

    test('unreadable storage falls back safely with a warning', () async {
      final repo = InMemoryStorageRepository(initialRaw: '{not json');
      final state = AppState(repository: repo, clock: () => kNow);
      await state.init();
      expect(state.loadWarning, isNotNull);
      expect(state.habits, isNotEmpty); // sample data, app still usable
      expect(state.isLoading, isFalse);
    });

    test('structurally invalid storage is treated as unreadable', () async {
      final repo = InMemoryStorageRepository(
          initialRaw: '{"schemaVersion":1,"habits":"oops"}');
      final state = AppState(repository: repo, clock: () => kNow);
      await state.init();
      expect(state.loadWarning, isNotNull);
    });
  });

  group('sleep and reflections', () {
    test('one sleep entry per date: saving again replaces it', () async {
      final (state, _) = await emptyState();
      state.saveSleep(SleepEntry.fromTimes(
          date: '2026-10-14', bedtime: '23:00', wakeTime: '06:00'));
      state.saveSleep(SleepEntry.fromTimes(
          date: '2026-10-14', bedtime: '22:00', wakeTime: '06:00'));
      expect(state.sleepEntries.length, 1);
      expect(state.sleepEntries.single.durationMinutes, 480);
    });

    test('weekly sleep average uses only logged nights', () async {
      final (state, _) = await emptyState();
      state.saveSleep(SleepEntry.fromTimes(
          date: '2026-10-14', bedtime: '23:00', wakeTime: '07:00')); // 8h
      state.saveSleep(SleepEntry.fromTimes(
          date: '2026-10-13', bedtime: '00:00', wakeTime: '06:00')); // 6h
      state.saveSleep(SleepEntry.fromTimes(
          date: '2026-09-01', bedtime: '00:00', wakeTime: '02:00')); // old
      expect(state.sleepStats.weeklyAverageMinutes(), 420);
      expect(state.sleepStats.nightsLoggedLast7(), 2);
    });

    test('reflections keep created time and update the edit time', () async {
      final times = [
        DateTime(2026, 10, 14, 8),
        DateTime(2026, 10, 14, 9),
      ];
      var i = 0;
      final repo = InMemoryStorageRepository();
      final state = AppState(repository: repo, clock: () => times[i]);
      await state.init();
      state.clearDemoData();
      final first = state.saveReflection(date: today, content: 'v1');
      i = 1;
      final edited =
          state.saveReflection(id: first.id, date: today, content: 'v2');
      expect(state.reflections.length, 1);
      expect(edited.createdAt, times[0]);
      expect(edited.updatedAt, times[1]);
      state.deleteReflection(first.id);
      expect(state.reflections, isEmpty);
    });

    test('the reflection draft survives tab changes', () async {
      final (state, _) = await emptyState();
      state.reflectionDraft.text = 'half written';
      state.goTo(AppSection.sleep);
      state.goTo(AppSection.reflections);
      state.goTo(AppSection.dashboard);
      expect(state.reflectionDraft.text, 'half written');
      expect(state.reflectionDraft, isA<ReflectionDraft>());
      // Saving clears the draft.
      state.saveReflection(date: today, content: state.reflectionDraft.text);
      state.resetReflectionDraft();
      expect(state.reflectionDraft.text, isEmpty);
    });
  });

  group('data tools', () {
    test('export then import restores identical data', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('a', start: '2026-10-01'));
      state.toggleCompletion('a', today);
      final backup = state.exportJson();

      final (other, _) = await emptyState();
      expect(other.importJson(backup), isNull);
      expect(other.habits.map((h) => h.id), ['a']);
      expect(other.isHabitDone('a', today), isTrue);
    });

    test('a bad import changes nothing', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('a', start: '2026-10-01'));
      expect(state.importJson('definitely not json'), isNotNull);
      expect(state.importJson('{"schemaVersion":1}'), isNotNull);
      expect(state.habits.map((h) => h.id), ['a']);
    });

    test('clear sample data keeps settings and the exercise library', () async {
      final repo = InMemoryStorageRepository();
      final state = AppState(repository: repo, clock: () => kNow);
      await state.init();
      final exerciseCount = state.exercises.length;
      state.clearDemoData();
      expect(state.isDemo, isFalse);
      expect(state.habits, isEmpty);
      expect(state.exercises.length, exerciseCount);
    });

    test('erase all resets everything to a clean slate', () async {
      final (state, _) = await emptyState();
      state.addHabit(makeHabit('a'));
      state.clearAllData();
      expect(state.habits, isEmpty);
      expect(state.settings.displayName, 'Alex');
    });
  });
}
