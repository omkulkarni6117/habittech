import 'package:habittech/core/date_utils.dart';
import 'package:habittech/data/in_memory_repository.dart';
import 'package:habittech/models/habit.dart';
import 'package:habittech/models/habit_completion.dart';
import 'package:habittech/state/app_state.dart';

/// Fixed "now" used by tests: Wednesday 14 Oct 2026, midday.
final DateTime kNow = DateTime(2026, 10, 14, 12);

Habit makeHabit(
  String id, {
  String start = '2026-09-01',
  ScheduleType type = ScheduleType.daily,
  List<int>? weekdays,
  DateTime? archivedAt,
  String? name,
}) =>
    Habit(
      id: id,
      name: name ?? 'Habit $id',
      startDate: start,
      createdAt: DateTime(2026, 9, 1),
      scheduleType: type,
      weekdays: weekdays,
      archivedAt: archivedAt,
    );

HabitCompletion done(String habitId, DateTime day) => HabitCompletion(
      habitId: habitId,
      date: dateKey(day),
      completedAt: DateTime(day.year, day.month, day.day, 9),
    );

/// An [AppState] with an empty, non-demo data set and a fixed clock.
Future<(AppState, InMemoryStorageRepository)> emptyState({
  DateTime? now,
}) async {
  final repo = InMemoryStorageRepository();
  final state = AppState(repository: repo, clock: () => now ?? kNow);
  await state.init();
  state.clearDemoData();
  await state.flush();
  return (state, repo);
}
