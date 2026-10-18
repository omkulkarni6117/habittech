import '../core/date_utils.dart';
import '../models/app_data.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/reflection.dart';
import '../models/sleep_entry.dart';
import '../models/user_settings.dart';
import '../models/workout.dart';
import 'starter_exercises.dart';

/// How many days of sample history are generated for first-time users.
const int kSeedHistoryDays = 45;

/// Small deterministic pseudo-random generator so sample data is the same
/// every run (and testable) without depending on `dart:math`'s seed.
class _Lcg {
  _Lcg(this._state);
  int _state;

  int next() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => (next() >> 8) / (0x7fffffff >> 8);
}

/// Builds the sample data shown to first-time users.
///
/// [today] is passed in so the history always ends on the current day.
AppData buildSeedData(DateTime today) {
  final now = dayOnly(today);
  final start = addDays(now, -(kSeedHistoryDays - 1));
  final startKey = dateKey(start);
  final created = DateTime(start.year, start.month, start.day, 8);

  Habit habit(String id, String name, String icon, HabitCategory cat,
          double? goal, String unit, String description,
          {String? reminder}) =>
      Habit(
        id: id,
        name: name,
        description: description,
        iconKey: icon,
        category: cat,
        goalValue: goal,
        goalUnit: unit,
        reminderTime: reminder,
        startDate: startKey,
        createdAt: created,
      );

  final habits = <Habit>[
    habit('h-workout', 'Workout', 'fitness_center', HabitCategory.fitness, 30,
        'minutes', '30 minutes'),
    habit('h-water', 'Drink 2L Water', 'water_drop', HabitCategory.health, 2,
        'litres', '2 litres'),
    habit('h-read', 'Read 20 Minutes', 'menu_book', HabitCategory.learning, 20,
        'minutes', '20 minutes'),
    habit('h-meditate', 'Meditate', 'self_improvement',
        HabitCategory.mindfulness, 10, 'minutes', '10 minutes'),
    habit('h-walk', 'Walk 8,000 Steps', 'directions_walk',
        HabitCategory.fitness, 8000, 'steps', '8,000 steps'),
    habit('h-study', 'Study / Learn', 'school', HabitCategory.learning, 45,
        'minutes', '45 minutes'),
    habit('h-sleep', 'Sleep on Time', 'bedtime', HabitCategory.sleep, null, '',
        'In bed by 11 PM',
        reminder: '22:30'),
  ];

  // Each habit has its own "reliability" so analytics show a real spread.
  const reliability = <String, double>{
    'h-workout': 0.72,
    'h-water': 0.88,
    'h-read': 0.7,
    'h-meditate': 0.62,
    'h-walk': 0.78,
    'h-study': 0.74,
    'h-sleep': 0.66,
  };

  final rng = _Lcg(20261012);
  final completions = <HabitCompletion>[];
  for (var i = 0; i < kSeedHistoryDays; i++) {
    final day = addDays(start, i);
    final isToday = isSameDay(day, now);
    for (var hIndex = 0; hIndex < habits.length; hIndex++) {
      final h = habits[hIndex];
      final roll = rng.nextDouble();
      final bool done;
      if (isToday) {
        // Today is "in progress": the first four habits are done.
        done = hIndex < 4;
      } else if (i >= kSeedHistoryDays - 4) {
        // A recent run of good days so the streak card has something to show.
        done = roll < 0.93;
      } else {
        done = roll < (reliability[h.id] ?? 0.7);
      }
      if (done) {
        completions.add(HabitCompletion(
          habitId: h.id,
          date: dateKey(day),
          completedAt: DateTime(day.year, day.month, day.day, 9 + hIndex),
        ));
      }
    }
  }

  final sleep = <SleepEntry>[];
  for (var i = 13; i >= 0; i--) {
    final day = addDays(now, -i);
    // Bedtime 22:30-00:00, duration 6h-8.5h, in 30 minute steps.
    final bedMinutes = 22 * 60 + 30 + (rng.next() % 4) * 30;
    final duration = 360 + (rng.next() % 6) * 30;
    final bed = '${two((bedMinutes ~/ 60) % 24)}:${two(bedMinutes % 60)}';
    final wakeTotal = bedMinutes + duration;
    final wake = '${two((wakeTotal ~/ 60) % 24)}:${two(wakeTotal % 60)}';
    sleep.add(SleepEntry(
      date: dateKey(day),
      bedtime: bed,
      wakeTime: wake,
      durationMinutes: duration,
      quality: 3 + rng.next() % 3,
    ));
  }

  final reflections = <Reflection>[
    Reflection(
      id: 'r-seed-1',
      date: dateKey(addDays(now, -1)),
      content:
          'Kept my morning routine going. Water and reading felt easy today; '
          'meditation slipped. Goal for tomorrow: ten quiet minutes before breakfast.',
      createdAt: DateTime(now.year, now.month, now.day - 1, 21, 15),
      updatedAt: DateTime(now.year, now.month, now.day - 1, 21, 15),
    ),
    Reflection(
      id: 'r-seed-2',
      date: dateKey(addDays(now, -6)),
      content:
          'Three workouts this week. Things to improve: go to bed earlier on weeknights.',
      createdAt: DateTime(now.year, now.month, now.day - 6, 20, 40),
      updatedAt: DateTime(now.year, now.month, now.day - 6, 20, 40),
    ),
  ];

  final exercises = starterExercises();
  final plan = _seedPlan();

  // Mark the first two items of today's planned workout as done.
  final todayPlan = plan.day(now.weekday);
  final progress = <String, Set<String>>{};
  if (todayPlan.isWorkout) {
    progress[dateKey(now)] = {for (final item in todayPlan.items.take(2)) item.id};
  }

  return AppData(
    isDemo: true,
    habits: habits,
    completions: completions,
    sleepEntries: sleep,
    reflections: reflections,
    exercises: exercises,
    workoutPlan: plan,
    workoutProgress: progress,
    settings: const UserSettings(),
  );
}

WorkoutPlan _seedPlan() {
  PlannedExercise item(String day, String exerciseId,
          {int sets = 3, int reps = 10, int? minutes, int rest = 60}) =>
      PlannedExercise(
        id: 'p-$day-$exerciseId',
        exerciseId: exerciseId,
        sets: sets,
        reps: reps,
        durationMin: minutes,
        restSec: rest,
      );

  return WorkoutPlan([
    WorkoutDay(weekday: 1, title: 'Push: Chest & Shoulders', items: [
      item('1', 'ex-bench-press', sets: 4, reps: 8, rest: 90),
      item('1', 'ex-incline-db-press'),
      item('1', 'ex-overhead-press', rest: 90),
      item('1', 'ex-lateral-raise', reps: 15, rest: 45),
      item('1', 'ex-triceps-dips', reps: 12),
    ]),
    WorkoutDay(weekday: 2, title: 'Pull: Back & Biceps', items: [
      item('2', 'ex-pull-ups', reps: 8, rest: 90),
      item('2', 'ex-barbell-row', sets: 4, reps: 8, rest: 90),
      item('2', 'ex-lat-pulldown', reps: 12),
      item('2', 'ex-biceps-curl', reps: 12, rest: 45),
    ]),
    WorkoutDay(weekday: 3, title: 'Legs', items: [
      item('3', 'ex-back-squat', sets: 4, reps: 8, rest: 120),
      item('3', 'ex-rdl', rest: 90),
      item('3', 'ex-lunges', reps: 12),
      item('3', 'ex-calf-raise', sets: 4, reps: 15, rest: 45),
    ]),
    const WorkoutDay(weekday: 4, title: 'Rest & recovery', isRest: true),
    WorkoutDay(weekday: 5, title: 'Full body & core', items: [
      item('5', 'ex-burpees', reps: 12, rest: 45),
      item('5', 'ex-push-ups', reps: 15, rest: 45),
      item('5', 'ex-plank', sets: 1, minutes: 3),
      item('5', 'ex-crunches', reps: 20, rest: 30),
    ]),
    WorkoutDay(weekday: 6, title: 'Cardio & mobility', items: [
      item('6', 'ex-running', sets: 1, minutes: 30),
      item('6', 'ex-stretching', sets: 1, minutes: 10),
    ]),
    const WorkoutDay(weekday: 7, title: 'Rest day', isRest: true),
  ]);
}
