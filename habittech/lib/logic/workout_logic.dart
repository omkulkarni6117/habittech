import '../core/date_utils.dart';
import '../models/workout.dart';

/// Rough time a strength set takes to perform, excluding rest.
const int kSecondsPerSet = 40;

/// Looks up exercises by id.
Map<String, Exercise> exerciseIndex(List<Exercise> exercises) =>
    {for (final e in exercises) e.id: e};

int totalSets(WorkoutDay day, Map<String, Exercise> index) {
  var sets = 0;
  for (final item in day.items) {
    final ex = index[item.exerciseId];
    if (ex == null || ex.kind == ExerciseKind.timed) continue;
    sets += item.sets;
  }
  return sets;
}

/// Estimated minutes for one planned item. Strength sets are estimated at
/// [kSecondsPerSet] of work plus the rest period; timed items use their
/// duration. This is an estimate, not a measurement.
int estimatedMinutes(PlannedExercise item, Exercise? exercise) {
  if (exercise != null && exercise.kind == ExerciseKind.timed) {
    return item.durationMin ?? exercise.defaultDurationMin;
  }
  final seconds = item.sets * (kSecondsPerSet + item.restSec);
  return (seconds / 60).ceil();
}

int estimatedDayMinutes(WorkoutDay day, Map<String, Exercise> index) {
  var total = 0;
  for (final item in day.items) {
    total += estimatedMinutes(item, index[item.exerciseId]);
  }
  return total;
}

/// Muscle groups trained on a day, in order of first appearance.
List<MuscleGroup> groupsTrained(WorkoutDay day, Map<String, Exercise> index) {
  final groups = <MuscleGroup>[];
  for (final item in day.items) {
    final ex = index[item.exerciseId];
    if (ex != null && !groups.contains(ex.muscleGroup)) {
      groups.add(ex.muscleGroup);
    }
  }
  return groups;
}

/// How many of the day's items are ticked off on [date].
int completedItems(
    WorkoutDay day, Map<String, Set<String>> progress, DateTime date) {
  final done = progress[dateKey(date)] ?? const <String>{};
  return day.items.where((i) => done.contains(i.id)).length;
}

bool isDayComplete(
        WorkoutDay day, Map<String, Set<String>> progress, DateTime date) =>
    day.isWorkout && completedItems(day, progress, date) == day.items.length;

enum WorkoutDayStatus { rest, unplanned, upcoming, todo, partial, done, missed }

class WorkoutWeekDay {
  const WorkoutWeekDay({
    required this.date,
    required this.day,
    required this.status,
    required this.completed,
  });

  final DateTime date;
  final WorkoutDay day;
  final WorkoutDayStatus status;
  final int completed;
}

class WorkoutWeekSummary {
  const WorkoutWeekSummary({
    required this.days,
    required this.plannedSessions,
    required this.completedSessions,
    required this.restDays,
    required this.totalExercises,
    required this.totalMinutes,
  });

  final List<WorkoutWeekDay> days;
  final int plannedSessions;
  final int completedSessions;
  final int restDays;
  final int totalExercises;
  final int totalMinutes;

  double? get completion =>
      plannedSessions == 0 ? null : completedSessions / plannedSessions;
}

/// Summarises the calendar week that contains [today].
///
/// A session counts as completed when every exercise planned for that day
/// was ticked off on that date.
WorkoutWeekSummary summariseWeek({
  required WorkoutPlan plan,
  required Map<String, Set<String>> progress,
  required List<Exercise> exercises,
  required DateTime today,
  required int weekStartsOn,
}) {
  final index = exerciseIndex(exercises);
  final first = startOfWeek(today, weekStartsOn);
  final todayOnly = dayOnly(today);
  final days = <WorkoutWeekDay>[];
  var planned = 0;
  var completedSessions = 0;
  var rest = 0;
  var exerciseCount = 0;
  var minutes = 0;

  for (var i = 0; i < 7; i++) {
    final date = addDays(first, i);
    final day = plan.day(date.weekday);
    final done = completedItems(day, progress, date);
    final WorkoutDayStatus status;
    if (day.isRest) {
      status = WorkoutDayStatus.rest;
      rest++;
    } else if (day.items.isEmpty) {
      status = WorkoutDayStatus.unplanned;
    } else {
      planned++;
      exerciseCount += day.items.length;
      minutes += estimatedDayMinutes(day, index);
      if (done == day.items.length) {
        status = WorkoutDayStatus.done;
        completedSessions++;
      } else if (date.isAfter(todayOnly)) {
        status = WorkoutDayStatus.upcoming;
      } else if (done > 0) {
        status = WorkoutDayStatus.partial;
      } else if (date.isBefore(todayOnly)) {
        status = WorkoutDayStatus.missed;
      } else {
        status = WorkoutDayStatus.todo;
      }
    }
    days.add(WorkoutWeekDay(
        date: date, day: day, status: status, completed: done));
  }

  return WorkoutWeekSummary(
    days: days,
    plannedSessions: planned,
    completedSessions: completedSessions,
    restDays: rest,
    totalExercises: exerciseCount,
    totalMinutes: minutes,
  );
}

/// One-line description such as "4 x 8 @ 60 kg" or "30 min".
String plannedSummary(PlannedExercise item, Exercise? exercise) {
  if (exercise != null && exercise.kind == ExerciseKind.timed) {
    return '${item.durationMin ?? exercise.defaultDurationMin} min';
  }
  final base = '${item.sets} x ${item.reps}';
  final w = item.weightKg;
  return w == null ? base : '$base @ ${formatNumber(w)} kg';
}
