import 'package:flutter_test/flutter_test.dart';
import 'package:habittech/core/date_utils.dart';
import 'package:habittech/logic/workout_logic.dart';
import 'package:habittech/models/workout.dart';
import 'package:habittech/state/app_state.dart';

import 'helpers.dart';

PlannedExercise item(String id, String exerciseId,
        {int sets = 3, int reps = 10, int rest = 60, int? minutes}) =>
    PlannedExercise(
      id: id,
      exerciseId: exerciseId,
      sets: sets,
      reps: reps,
      restSec: rest,
      durationMin: minutes,
    );

void main() {
  final today = dayOnly(kNow); // Wednesday = weekday 3

  group('building the weekly plan', () {
    test('the plan always has seven days, Monday first', () async {
      final (state, _) = await emptyState();
      final days = state.workoutPlan.days;
      expect(days.length, 7);
      expect([for (final d in days) d.weekday], [1, 2, 3, 4, 5, 6, 7]);
    });

    test('add, edit and remove exercises on a day', () async {
      final (state, _) = await emptyState();
      state.addPlannedExercise(1, item('p1', 'ex-back-squat', sets: 4, reps: 8));
      state.addPlannedExercise(1, item('p2', 'ex-lunges'));
      expect(state.workoutPlan.day(1).items.map((i) => i.id), ['p1', 'p2']);

      state.updatePlannedExercise(1, item('p1', 'ex-back-squat', sets: 5, reps: 5));
      expect(state.workoutPlan.day(1).items.first.sets, 5);

      state.removePlannedExercise(1, 'p1');
      expect(state.workoutPlan.day(1).items.map((i) => i.id), ['p2']);
    });

    test('adding an exercise turns a rest day into a workout day', () async {
      final (state, _) = await emptyState();
      state.setWorkoutRest(2, true);
      expect(state.workoutPlan.day(2).isRest, isTrue);
      state.addPlannedExercise(2, item('p1', 'ex-plank', sets: 1, minutes: 2));
      expect(state.workoutPlan.day(2).isRest, isFalse);
      expect(state.workoutPlan.day(2).isWorkout, isTrue);
    });

    test('the same exercise can appear on several days', () async {
      final (state, _) = await emptyState();
      state.addPlannedExercise(1, item('p1', 'ex-push-ups'));
      state.addPlannedExercise(4, item('p2', 'ex-push-ups'));
      expect(state.planUsageCount('ex-push-ups'), 2);
    });

    test('reordering follows the list widget convention', () async {
      final (state, _) = await emptyState();
      for (final id in ['a', 'b', 'c']) {
        state.addPlannedExercise(1, item(id, 'ex-lunges'));
      }
      // Drag "a" below "b": the widget reports newIndex 2.
      state.reorderPlannedExercise(1, 0, 2);
      expect(state.workoutPlan.day(1).items.map((i) => i.id), ['b', 'a', 'c']);
      // Drag "c" to the top.
      state.reorderPlannedExercise(1, 2, 0);
      expect(state.workoutPlan.day(1).items.map((i) => i.id), ['c', 'b', 'a']);
      // Out-of-range input is ignored.
      state.reorderPlannedExercise(1, 9, 0);
      expect(state.workoutPlan.day(1).items.length, 3);
    });

    test('copying a day gives fresh ids and replaces the target', () async {
      final (state, _) = await emptyState();
      state.setWorkoutTitle(1, 'Legs');
      state.addPlannedExercise(1, item('p1', 'ex-back-squat'));
      state.addPlannedExercise(3, item('old', 'ex-plank'));
      state.copyWorkoutDay(1, 3);
      final copied = state.workoutPlan.day(3);
      expect(copied.title, 'Legs');
      expect(copied.items.length, 1);
      expect(copied.items.single.exerciseId, 'ex-back-squat');
      expect(copied.items.single.id, isNot('p1'));
    });
  });

  group('exercise library', () {
    test('add rejects blank and duplicate names', () async {
      final (state, _) = await emptyState();
      expect(
          state.addExercise(const Exercise(
              id: 'x1', name: 'Cable Fly', muscleGroup: MuscleGroup.chest)),
          isNull);
      expect(
          state.addExercise(const Exercise(
              id: 'x2', name: 'cable fly', muscleGroup: MuscleGroup.chest)),
          isNotNull);
      expect(
          state.addExercise(const Exercise(
              id: 'x3', name: ' ', muscleGroup: MuscleGroup.chest)),
          isNotNull);
    });

    test('deleting an exercise removes it from the plan and progress', () async {
      final (state, _) = await emptyState();
      state.addPlannedExercise(3, item('p1', 'ex-plank', sets: 1, minutes: 2));
      state.addPlannedExercise(3, item('p2', 'ex-lunges'));
      state.toggleWorkoutItem(today, 'p1');
      state.deleteExercise('ex-plank');
      expect(state.exercises.any((e) => e.id == 'ex-plank'), isFalse);
      expect(state.workoutPlan.day(3).items.map((i) => i.id), ['p2']);
      expect(state.workoutProgress, isEmpty);
    });
  });

  group('ticking exercises off', () {
    test('toggle on and off', () async {
      final (state, _) = await emptyState();
      state.addPlannedExercise(3, item('p1', 'ex-lunges'));
      expect(state.toggleWorkoutItem(today, 'p1'), isTrue);
      expect(state.workoutProgress[dateKey(today)], {'p1'});
      expect(state.toggleWorkoutItem(today, 'p1'), isTrue);
      expect(state.workoutProgress, isEmpty);
    });

    test('future dates and items from other days are ignored', () async {
      final (state, _) = await emptyState();
      state.addPlannedExercise(3, item('p1', 'ex-lunges'));
      state.addPlannedExercise(4, item('p2', 'ex-lunges'));
      expect(state.toggleWorkoutItem(addDays(today, 1), 'p2'), isFalse);
      expect(state.toggleWorkoutItem(today, 'p2'), isFalse); // Thursday's item
      expect(state.toggleWorkoutItem(today, 'ghost'), isFalse);
      expect(state.workoutProgress, isEmpty);
    });

    test('progress survives a reload', () async {
      final (state, repo) = await emptyState();
      state.addPlannedExercise(3, item('p1', 'ex-lunges'));
      state.toggleWorkoutItem(today, 'p1');
      await state.flush();
      final reloaded = AppState(repository: repo, clock: () => kNow);
      await reloaded.init();
      expect(reloaded.workoutProgress[dateKey(today)], {'p1'});
      expect(reloaded.workoutPlan.day(3).items.single.id, 'p1');
    });
  });

  group('weekly summary', () {
    test('counts sessions, rest days and statuses for the current week',
        () async {
      final (state, _) = await emptyState();
      // Mon: done, Tue: missed, Wed (today): partial, Thu: upcoming,
      // Fri: rest, Sat/Sun empty.
      state.addPlannedExercise(1, item('m1', 'ex-lunges'));
      state.addPlannedExercise(2, item('t1', 'ex-lunges'));
      state.addPlannedExercise(3, item('w1', 'ex-lunges'));
      state.addPlannedExercise(3, item('w2', 'ex-plank', sets: 1, minutes: 2));
      state.addPlannedExercise(4, item('th1', 'ex-lunges'));
      state.setWorkoutRest(5, true);

      state.toggleWorkoutItem(DateTime(2026, 10, 12), 'm1');
      state.toggleWorkoutItem(today, 'w1');

      final week = state.workoutWeek;
      final statuses = [for (final d in week.days) d.status];
      expect(statuses, [
        WorkoutDayStatus.done,
        WorkoutDayStatus.missed,
        WorkoutDayStatus.partial,
        WorkoutDayStatus.upcoming,
        WorkoutDayStatus.rest,
        WorkoutDayStatus.unplanned,
        WorkoutDayStatus.unplanned,
      ]);
      expect(week.plannedSessions, 4);
      expect(week.completedSessions, 1);
      expect(week.restDays, 1);
      expect(week.totalExercises, 5);
      expect(week.completion, 0.25);
    });

    test('the week follows the week-start setting', () async {
      final (state, _) = await emptyState();
      state.updateSettings(state.settings.copyWith(weekStartsOn: 7));
      final week = state.workoutWeek;
      expect(week.days.first.date, DateTime(2026, 10, 11)); // Sunday
      expect(week.days.first.date.weekday, 7);
    });
  });

  group('estimates', () {
    test('strength sets use work time plus rest, timed items use duration', () {
      final lunges = const Exercise(
          id: 'l', name: 'Lunges', muscleGroup: MuscleGroup.legs);
      final run = const Exercise(
          id: 'r',
          name: 'Run',
          muscleGroup: MuscleGroup.cardio,
          kind: ExerciseKind.timed);
      // 3 sets x (40s + 60s) = 300s = 5 min
      expect(estimatedMinutes(item('a', 'l'), lunges), 5);
      expect(estimatedMinutes(item('b', 'r', minutes: 25), run), 25);
      expect(plannedSummary(item('a', 'l', sets: 4, reps: 8), lunges), '4 x 8');
      expect(plannedSummary(item('b', 'r', minutes: 25), run), '25 min');
    });

    test('plan JSON round trips', () {
      final plan = WorkoutPlan([
        WorkoutDay(
            weekday: 2, title: 'Pull', items: [item('p1', 'ex-pull-ups')]),
      ]);
      final back = WorkoutPlan.fromJson(plan.toJson());
      expect(back.days.length, 7);
      expect(back.day(2).title, 'Pull');
      expect(back.day(2).items.single.exerciseId, 'ex-pull-ups');
      expect(back.day(1).items, isEmpty);
    });
  });
}
