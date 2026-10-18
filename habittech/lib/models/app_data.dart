import '../core/date_utils.dart';
import 'habit.dart';
import 'habit_completion.dart';
import 'json_helpers.dart';
import 'reflection.dart';
import 'sleep_entry.dart';
import 'user_settings.dart';
import 'workout.dart';

/// Everything HabitTech stores, as one immutable snapshot.
///
/// This is the unit that is persisted, exported and imported. Keeping it a
/// single value makes backups atomic and lets a future Supabase repository
/// sync the same shape without touching the UI.
class AppData {
  AppData({
    required this.isDemo,
    required this.habits,
    required this.completions,
    required this.sleepEntries,
    required this.reflections,
    required this.exercises,
    required this.workoutPlan,
    required this.workoutProgress,
    required this.settings,
  });

  /// Bump when the JSON shape changes incompatibly.
  static const int currentSchemaVersion = 1;

  factory AppData.empty({
    UserSettings settings = const UserSettings(),
    List<Exercise> exercises = const [],
  }) =>
      AppData(
        isDemo: false,
        habits: const [],
        completions: const [],
        sleepEntries: const [],
        reflections: const [],
        exercises: exercises,
        workoutPlan: WorkoutPlan.empty(),
        workoutProgress: const {},
        settings: settings,
      );

  /// True while the data is the generated sample data.
  final bool isDemo;
  final List<Habit> habits;
  final List<HabitCompletion> completions;
  final List<SleepEntry> sleepEntries;
  final List<Reflection> reflections;
  final List<Exercise> exercises;
  final WorkoutPlan workoutPlan;

  /// Date key -> ids of [PlannedExercise]s ticked off that day.
  final Map<String, Set<String>> workoutProgress;
  final UserSettings settings;

  AppData copyWith({
    bool? isDemo,
    List<Habit>? habits,
    List<HabitCompletion>? completions,
    List<SleepEntry>? sleepEntries,
    List<Reflection>? reflections,
    List<Exercise>? exercises,
    WorkoutPlan? workoutPlan,
    Map<String, Set<String>>? workoutProgress,
    UserSettings? settings,
  }) =>
      AppData(
        isDemo: isDemo ?? this.isDemo,
        habits: habits ?? this.habits,
        completions: completions ?? this.completions,
        sleepEntries: sleepEntries ?? this.sleepEntries,
        reflections: reflections ?? this.reflections,
        exercises: exercises ?? this.exercises,
        workoutPlan: workoutPlan ?? this.workoutPlan,
        workoutProgress: workoutProgress ?? this.workoutProgress,
        settings: settings ?? this.settings,
      );

  Json toJson() => {
        'app': 'HabitTech',
        'schemaVersion': currentSchemaVersion,
        'isDemo': isDemo,
        'settings': settings.toJson(),
        'habits': habits.map((e) => e.toJson()).toList(),
        'completions': completions.map((e) => e.toJson()).toList(),
        'sleepEntries': sleepEntries.map((e) => e.toJson()).toList(),
        'reflections': reflections.map((e) => e.toJson()).toList(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'workoutPlan': workoutPlan.toJson(),
        'workoutProgress': {
          for (final e in workoutProgress.entries)
            if (e.value.isNotEmpty) e.key: (e.value.toList()..sort()),
        },
      };

  /// Strictly parses and cross-checks a snapshot. Throws [FormatException]
  /// describing the first problem found; never returns partial data.
  factory AppData.fromJson(Json j) {
    final version = reqInt(j, 'schemaVersion');
    if (version != currentSchemaVersion) {
      throw FormatException(
          'Unsupported backup version $version (this app reads version $currentSchemaVersion)');
    }

    final habits = <Habit>[];
    final habitIds = <String>{};
    for (final raw in asList(j['habits'], 'habits')) {
      final h = Habit.fromJson(asJson(raw, 'habits[]'));
      if (!habitIds.add(h.id)) {
        throw FormatException('Duplicate habit id "${h.id}"');
      }
      habits.add(h);
    }

    final completions = <HabitCompletion>[];
    final completionIds = <String>{};
    for (final raw in asList(j['completions'], 'completions')) {
      final c = HabitCompletion.fromJson(asJson(raw, 'completions[]'));
      if (!habitIds.contains(c.habitId)) {
        throw FormatException(
            'A completion refers to unknown habit "${c.habitId}"');
      }
      if (!completionIds.add(c.id)) {
        throw FormatException(
            'Duplicate completion for habit "${c.habitId}" on ${c.date}');
      }
      completions.add(c);
    }

    final sleep = <SleepEntry>[];
    final sleepDates = <String>{};
    for (final raw in asList(j['sleepEntries'], 'sleepEntries')) {
      final s = SleepEntry.fromJson(asJson(raw, 'sleepEntries[]'));
      if (!sleepDates.add(s.date)) {
        throw FormatException('Two sleep entries share the date ${s.date}');
      }
      sleep.add(s);
    }

    final reflections = <Reflection>[];
    final reflectionIds = <String>{};
    for (final raw in asList(j['reflections'], 'reflections')) {
      final r = Reflection.fromJson(asJson(raw, 'reflections[]'));
      if (!reflectionIds.add(r.id)) {
        throw FormatException('Duplicate reflection id "${r.id}"');
      }
      reflections.add(r);
    }

    final exercises = <Exercise>[];
    final exerciseIds = <String>{};
    for (final raw in asList(j['exercises'] ?? const [], 'exercises')) {
      final e = Exercise.fromJson(asJson(raw, 'exercises[]'));
      if (!exerciseIds.add(e.id)) {
        throw FormatException('Duplicate exercise id "${e.id}"');
      }
      exercises.add(e);
    }

    final plan = WorkoutPlan.fromJson(
        j['workoutPlan'] == null ? <String, dynamic>{} : asJson(j['workoutPlan'], 'workoutPlan'));
    final itemIds = <String>{};
    for (final item in plan.allItems) {
      if (!exerciseIds.contains(item.exerciseId)) {
        throw FormatException(
            'The workout plan refers to unknown exercise "${item.exerciseId}"');
      }
      if (!itemIds.add(item.id)) {
        throw FormatException('Duplicate planned exercise id "${item.id}"');
      }
    }

    final progress = <String, Set<String>>{};
    final rawProgress = j['workoutProgress'];
    if (rawProgress != null) {
      final map = asJson(rawProgress, 'workoutProgress');
      for (final entry in map.entries) {
        if (tryParseDateKey(entry.key) == null) {
          throw FormatException(
              'workoutProgress has an invalid date "${entry.key}"');
        }
        final ids = <String>{};
        for (final id in asList(entry.value, 'workoutProgress.${entry.key}')) {
          if (id is! String) {
            throw FormatException(
                'workoutProgress.${entry.key} must list item ids');
          }
          ids.add(id);
        }
        progress[entry.key] = ids;
      }
    }

    return AppData(
      isDemo: boolOr(j, 'isDemo', false),
      habits: habits,
      completions: completions,
      sleepEntries: sleep,
      reflections: reflections,
      exercises: exercises,
      workoutPlan: plan,
      workoutProgress: progress,
      settings: j['settings'] == null
          ? const UserSettings()
          : UserSettings.fromJson(asJson(j['settings'], 'settings')),
    );
  }
}
