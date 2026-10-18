import 'json_helpers.dart';

enum MuscleGroup {
  chest('Chest'),
  back('Back'),
  shoulders('Shoulders'),
  arms('Arms'),
  legs('Legs'),
  core('Core'),
  fullBody('Full body'),
  cardio('Cardio'),
  mobility('Mobility');

  const MuscleGroup(this.label);
  final String label;

  static MuscleGroup parse(String s) => values.firstWhere(
        (e) => e.name == s,
        orElse: () => throw FormatException('Unknown muscle group "$s"'),
      );
}

enum ExerciseKind {
  /// Sets x reps, optional weight.
  strength('Sets & reps'),

  /// A single block of time, e.g. a 30 minute run.
  timed('Timed');

  const ExerciseKind(this.label);
  final String label;

  static ExerciseKind parse(String s) => values.firstWhere(
        (e) => e.name == s,
        orElse: () => throw FormatException('Unknown exercise kind "$s"'),
      );
}

/// An entry in the exercise library. Plans reference exercises by id.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.kind = ExerciseKind.strength,
    this.equipment = '',
    this.notes = '',
    this.defaultSets = 3,
    this.defaultReps = 10,
    this.defaultDurationMin = 20,
    this.defaultRestSec = 60,
  });

  final String id;
  final String name;
  final MuscleGroup muscleGroup;
  final ExerciseKind kind;
  final String equipment;
  final String notes;
  final int defaultSets;
  final int defaultReps;
  final int defaultDurationMin;
  final int defaultRestSec;

  Exercise copyWith({
    String? name,
    MuscleGroup? muscleGroup,
    ExerciseKind? kind,
    String? equipment,
    String? notes,
    int? defaultSets,
    int? defaultReps,
    int? defaultDurationMin,
    int? defaultRestSec,
  }) =>
      Exercise(
        id: id,
        name: name ?? this.name,
        muscleGroup: muscleGroup ?? this.muscleGroup,
        kind: kind ?? this.kind,
        equipment: equipment ?? this.equipment,
        notes: notes ?? this.notes,
        defaultSets: defaultSets ?? this.defaultSets,
        defaultReps: defaultReps ?? this.defaultReps,
        defaultDurationMin: defaultDurationMin ?? this.defaultDurationMin,
        defaultRestSec: defaultRestSec ?? this.defaultRestSec,
      );

  Json toJson() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup.name,
        'kind': kind.name,
        'equipment': equipment,
        'notes': notes,
        'defaultSets': defaultSets,
        'defaultReps': defaultReps,
        'defaultDurationMin': defaultDurationMin,
        'defaultRestSec': defaultRestSec,
      };

  factory Exercise.fromJson(Json j) => Exercise(
        id: reqString(j, 'id'),
        name: reqString(j, 'name'),
        muscleGroup: MuscleGroup.parse(reqString(j, 'muscleGroup')),
        kind: ExerciseKind.parse(reqString(j, 'kind')),
        equipment: strOr(j, 'equipment', ''),
        notes: strOr(j, 'notes', ''),
        defaultSets: intOr(j, 'defaultSets', 3, min: 1, max: 20),
        defaultReps: intOr(j, 'defaultReps', 10, min: 1, max: 200),
        defaultDurationMin: intOr(j, 'defaultDurationMin', 20, min: 1, max: 600),
        defaultRestSec: intOr(j, 'defaultRestSec', 60, min: 0, max: 600),
      );
}

/// One exercise placed on one weekday of the plan, with its own targets.
class PlannedExercise {
  const PlannedExercise({
    required this.id,
    required this.exerciseId,
    this.sets = 3,
    this.reps = 10,
    this.weightKg,
    this.durationMin,
    this.restSec = 60,
    this.notes = '',
  });

  /// Unique per plan entry (the same exercise may appear on several days).
  final String id;
  final String exerciseId;
  final int sets;
  final int reps;
  final double? weightKg;

  /// Only used for [ExerciseKind.timed] exercises.
  final int? durationMin;
  final int restSec;
  final String notes;

  PlannedExercise copyWith({
    int? sets,
    int? reps,
    double? weightKg,
    bool clearWeight = false,
    int? durationMin,
    bool clearDuration = false,
    int? restSec,
    String? notes,
    String? id,
  }) =>
      PlannedExercise(
        id: id ?? this.id,
        exerciseId: exerciseId,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
        durationMin: clearDuration ? null : (durationMin ?? this.durationMin),
        restSec: restSec ?? this.restSec,
        notes: notes ?? this.notes,
      );

  Json toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'sets': sets,
        'reps': reps,
        'weightKg': weightKg,
        'durationMin': durationMin,
        'restSec': restSec,
        'notes': notes,
      };

  factory PlannedExercise.fromJson(Json j) => PlannedExercise(
        id: reqString(j, 'id'),
        exerciseId: reqString(j, 'exerciseId'),
        sets: intOr(j, 'sets', 3, min: 1, max: 20),
        reps: intOr(j, 'reps', 10, min: 1, max: 200),
        weightKg: optDouble(j, 'weightKg', min: 0),
        durationMin: optInt(j, 'durationMin', min: 1, max: 600),
        restSec: intOr(j, 'restSec', 60, min: 0, max: 600),
        notes: strOr(j, 'notes', ''),
      );
}

/// The plan for one weekday.
class WorkoutDay {
  const WorkoutDay({
    required this.weekday,
    this.title = '',
    this.isRest = false,
    this.items = const [],
  });

  /// `DateTime.weekday` numbering (1 = Monday ... 7 = Sunday).
  final int weekday;
  final String title;
  final bool isRest;
  final List<PlannedExercise> items;

  /// A day counts as a workout day when it is not a rest day and has at
  /// least one exercise.
  bool get isWorkout => !isRest && items.isNotEmpty;

  WorkoutDay copyWith({
    String? title,
    bool? isRest,
    List<PlannedExercise>? items,
  }) =>
      WorkoutDay(
        weekday: weekday,
        title: title ?? this.title,
        isRest: isRest ?? this.isRest,
        items: items ?? this.items,
      );

  Json toJson() => {
        'weekday': weekday,
        'title': title,
        'isRest': isRest,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory WorkoutDay.fromJson(Json j) {
    final ids = <String>{};
    final items = <PlannedExercise>[];
    for (final raw in asList(j['items'] ?? const [], 'items')) {
      final item = PlannedExercise.fromJson(asJson(raw, 'items[]'));
      if (!ids.add(item.id)) {
        throw FormatException('Duplicate planned exercise id "${item.id}"');
      }
      items.add(item);
    }
    return WorkoutDay(
      weekday: reqInt(j, 'weekday', min: 1, max: 7),
      title: strOr(j, 'title', ''),
      isRest: boolOr(j, 'isRest', false),
      items: items,
    );
  }
}

/// The weekly workout plan: always exactly seven days, Monday = 1.
class WorkoutPlan {
  WorkoutPlan(List<WorkoutDay> days)
      : days = List<WorkoutDay>.unmodifiable(_normalise(days));

  factory WorkoutPlan.empty() => WorkoutPlan(const []);

  final List<WorkoutDay> days;

  static List<WorkoutDay> _normalise(List<WorkoutDay> given) {
    final byDay = {for (final d in given) d.weekday: d};
    return [
      for (var w = 1; w <= 7; w++) byDay[w] ?? WorkoutDay(weekday: w),
    ];
  }

  WorkoutDay day(int weekday) => days[weekday - 1];

  WorkoutPlan withDay(WorkoutDay updated) => WorkoutPlan([
        for (final d in days) d.weekday == updated.weekday ? updated : d,
      ]);

  Iterable<PlannedExercise> get allItems => days.expand((d) => d.items);

  Json toJson() => {'days': days.map((d) => d.toJson()).toList()};

  factory WorkoutPlan.fromJson(Json j) {
    final seen = <int>{};
    final parsed = <WorkoutDay>[];
    for (final raw in asList(j['days'] ?? const [], 'days')) {
      final day = WorkoutDay.fromJson(asJson(raw, 'days[]'));
      if (!seen.add(day.weekday)) {
        throw FormatException('Duplicate workout day ${day.weekday}');
      }
      parsed.add(day);
    }
    return WorkoutPlan(parsed);
  }
}
