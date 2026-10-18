import 'package:flutter/foundation.dart';

import '../app/sections.dart';
import '../core/date_utils.dart';
import '../data/backup.dart';
import '../data/seed_data.dart';
import '../data/starter_exercises.dart';
import '../data/storage_repository.dart';
import '../logic/habit_stats.dart';
import '../logic/sleep_stats.dart';
import '../logic/workout_logic.dart';
import '../models/app_data.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/reflection.dart';
import '../models/sleep_entry.dart';
import '../models/user_settings.dart';
import '../models/workout.dart';

/// Reflection text being typed. Lives here (not in the screen) so switching
/// tabs never loses what the user wrote.
class ReflectionDraft {
  ReflectionDraft({this.text = '', required this.date, this.editingId});

  String text;
  DateTime date;

  /// Set while editing an existing reflection.
  String? editingId;

  bool get isBlank => text.trim().isEmpty && editingId == null;
}

/// Single source of truth for the UI.
///
/// Every mutation builds a new immutable [AppData], swaps it in, notifies
/// listeners (so every screen updates immediately) and queues a write to the
/// [StorageRepository].
class AppState extends ChangeNotifier {
  AppState({
    required StorageRepository repository,
    DateTime Function()? clock,
  })  : _repo = repository,
        _clock = clock ?? DateTime.now;

  final StorageRepository _repo;
  final DateTime Function() _clock;

  AppData _data = AppData.empty(exercises: starterExercises());
  bool _loading = true;
  String? _loadWarning;
  String? _saveError;
  AppSection _section = AppSection.dashboard;
  Future<void> _saveChain = Future<void>.value();
  int _idCounter = 0;

  HabitStats? _habitStats;
  String? _habitStatsDay;
  SleepStats? _sleepStats;
  String? _sleepStatsDay;

  late ReflectionDraft reflectionDraft = ReflectionDraft(date: today);

  // ---------------------------------------------------------------- loading

  Future<void> init() async {
    final result = await _repo.load();
    _loadWarning = result.warning;
    var data = result.data;
    if (data == null) {
      data = buildSeedData(_clock());
      _queueSave(data);
    }
    _data = data;
    _loading = false;
    _invalidateStats();
    notifyListeners();
  }

  /// Completes when every queued write has finished (used by tests).
  Future<void> flush() => _saveChain;

  bool get isLoading => _loading;
  String? get loadWarning => _loadWarning;
  String? get saveError => _saveError;

  void dismissLoadWarning() {
    _loadWarning = null;
    notifyListeners();
  }

  /// Call when the app returns to the foreground so "today" is current.
  void refreshDate() {
    _invalidateStats();
    notifyListeners();
  }

  // ------------------------------------------------------------- navigation

  AppSection get section => _section;

  void goTo(AppSection section) {
    if (_section == section) return;
    _section = section;
    notifyListeners();
  }

  // ------------------------------------------------------------------ reads

  DateTime get now => _clock();
  DateTime get today => dayOnly(_clock());
  AppData get data => _data;
  UserSettings get settings => _data.settings;
  bool get isDemo => _data.isDemo;

  List<Habit> get habits => _data.habits;
  List<Habit> get activeHabits =>
      _data.habits.where((h) => !h.isArchived).toList();
  List<Habit> get archivedHabits =>
      _data.habits.where((h) => h.isArchived).toList();
  Habit? habitById(String id) {
    for (final h in _data.habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  List<SleepEntry> get sleepEntries => _data.sleepEntries;

  List<Reflection> get reflections {
    final list = [..._data.reflections];
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  List<Exercise> get exercises => _data.exercises;
  Map<String, Exercise> get exerciseById => exerciseIndex(_data.exercises);
  WorkoutPlan get workoutPlan => _data.workoutPlan;
  Map<String, Set<String>> get workoutProgress => _data.workoutProgress;

  HabitStats get stats {
    final key = dateKey(today);
    if (_habitStats == null || _habitStatsDay != key) {
      _habitStats = HabitStats(
        habits: _data.habits,
        completions: _data.completions,
        dailyGoal: _data.settings.dailyHabitGoal,
        now: _clock(),
      );
      _habitStatsDay = key;
    }
    return _habitStats!;
  }

  SleepStats get sleepStats {
    final key = dateKey(today);
    if (_sleepStats == null || _sleepStatsDay != key) {
      _sleepStats = SleepStats(
        entries: _data.sleepEntries,
        now: _clock(),
        goalMinutes: _data.settings.sleepGoalMinutes,
      );
      _sleepStatsDay = key;
    }
    return _sleepStats!;
  }

  WorkoutWeekSummary get workoutWeek => summariseWeek(
        plan: _data.workoutPlan,
        progress: _data.workoutProgress,
        exercises: _data.exercises,
        today: today,
        weekStartsOn: _data.settings.weekStartsOn,
      );

  bool isHabitDone(String habitId, DateTime day) => stats.isDone(habitId, day);

  // ---------------------------------------------------------------- habits

  String newId(String prefix) =>
      '$prefix-${_clock().microsecondsSinceEpoch.toRadixString(36)}-${_idCounter++}';

  bool _habitNameTaken(String name, {String? exceptId}) {
    final wanted = name.trim().toLowerCase();
    return _data.habits.any((h) =>
        !h.isArchived &&
        h.id != exceptId &&
        h.name.trim().toLowerCase() == wanted);
  }

  /// Adds a habit. Returns an error message, or null on success.
  String? addHabit(Habit habit) {
    if (habit.name.trim().isEmpty) return 'Give the habit a name.';
    if (_habitNameTaken(habit.name)) {
      return 'You already have a habit called "${habit.name.trim()}".';
    }
    if (_data.habits.any((h) => h.id == habit.id)) {
      return 'That habit was already saved.';
    }
    _commit(_data.copyWith(habits: [..._data.habits, habit]));
    return null;
  }

  String? updateHabit(Habit habit) {
    if (habit.name.trim().isEmpty) return 'Give the habit a name.';
    if (!habit.isArchived && _habitNameTaken(habit.name, exceptId: habit.id)) {
      return 'You already have a habit called "${habit.name.trim()}".';
    }
    if (habitById(habit.id) == null) return 'That habit no longer exists.';
    _commit(_data.copyWith(habits: [
      for (final h in _data.habits) h.id == habit.id ? habit : h,
    ]));
    return null;
  }

  void archiveHabit(String id) {
    final habit = habitById(id);
    if (habit == null || habit.isArchived) return;
    updateHabit(habit.copyWith(archivedAt: _clock()));
  }

  /// Returns an error message (for example when an active habit already uses
  /// the same name), or null on success.
  String? restoreHabit(String id) {
    final habit = habitById(id);
    if (habit == null || !habit.isArchived) return null;
    return updateHabit(habit.copyWith(clearArchived: true));
  }

  /// Permanently removes a habit and all of its completion records.
  void deleteHabit(String id) {
    _commit(_data.copyWith(
      habits: _data.habits.where((h) => h.id != id).toList(),
      completions: _data.completions.where((c) => c.habitId != id).toList(),
    ));
  }

  /// Marks [habitId] complete on [day], or clears it if already complete.
  ///
  /// Returns false (and changes nothing) for future days, unknown habits and
  /// days on which the habit does not apply. Because a completion's id is
  /// `habitId_date`, a habit can never have two records for one day.
  bool toggleCompletion(String habitId, DateTime day) {
    final d = dayOnly(day);
    if (d.isAfter(today)) return false;
    final habit = habitById(habitId);
    if (habit == null || !habit.appliesOn(d)) return false;

    final id = HabitCompletion.makeId(habitId, dateKey(d));
    final exists = _data.completions.any((c) => c.id == id);
    final List<HabitCompletion> next;
    if (exists) {
      next = _data.completions.where((c) => c.id != id).toList();
    } else {
      next = [
        ..._data.completions,
        HabitCompletion(
          habitId: habitId,
          date: dateKey(d),
          completedAt: _clock(),
        ),
      ];
    }
    _commit(_data.copyWith(completions: next));
    return true;
  }

  // ----------------------------------------------------------------- sleep

  void saveSleep(SleepEntry entry) {
    _commit(_data.copyWith(sleepEntries: [
      ..._data.sleepEntries.where((s) => s.date != entry.date),
      entry,
    ]));
  }

  void deleteSleep(String date) {
    _commit(_data.copyWith(
      sleepEntries: _data.sleepEntries.where((s) => s.date != date).toList(),
    ));
  }

  // ----------------------------------------------------------- reflections

  Reflection saveReflection({
    String? id,
    required DateTime date,
    required String content,
  }) {
    final text = content.trim();
    final now = _clock();
    final existing = id == null
        ? null
        : _data.reflections.where((r) => r.id == id).firstOrNull;
    final Reflection saved;
    final List<Reflection> next;
    if (existing != null) {
      saved = existing.copyWith(
          date: dateKey(date), content: text, updatedAt: now);
      next = [
        for (final r in _data.reflections) r.id == existing.id ? saved : r,
      ];
    } else {
      saved = Reflection(
        id: newId('r'),
        date: dateKey(date),
        content: text,
        createdAt: now,
        updatedAt: now,
      );
      next = [..._data.reflections, saved];
    }
    _commit(_data.copyWith(reflections: next));
    return saved;
  }

  void deleteReflection(String id) {
    _commit(_data.copyWith(
      reflections: _data.reflections.where((r) => r.id != id).toList(),
    ));
  }

  void resetReflectionDraft() {
    reflectionDraft = ReflectionDraft(date: today);
  }

  // -------------------------------------------------------------- settings

  void updateSettings(UserSettings settings) {
    _commit(_data.copyWith(settings: settings));
  }

  // --------------------------------------------------------------- workout

  bool _exerciseNameTaken(String name, {String? exceptId}) {
    final wanted = name.trim().toLowerCase();
    return _data.exercises
        .any((e) => e.id != exceptId && e.name.trim().toLowerCase() == wanted);
  }

  String? addExercise(Exercise exercise) {
    if (exercise.name.trim().isEmpty) return 'Give the exercise a name.';
    if (_exerciseNameTaken(exercise.name)) {
      return 'The library already has "${exercise.name.trim()}".';
    }
    _commit(_data.copyWith(exercises: [..._data.exercises, exercise]));
    return null;
  }

  String? updateExercise(Exercise exercise) {
    if (exercise.name.trim().isEmpty) return 'Give the exercise a name.';
    if (_exerciseNameTaken(exercise.name, exceptId: exercise.id)) {
      return 'The library already has "${exercise.name.trim()}".';
    }
    _commit(_data.copyWith(exercises: [
      for (final e in _data.exercises) e.id == exercise.id ? exercise : e,
    ]));
    return null;
  }

  /// Number of planned entries that use [exerciseId].
  int planUsageCount(String exerciseId) =>
      _data.workoutPlan.allItems.where((i) => i.exerciseId == exerciseId).length;

  /// Removes an exercise from the library and from every day of the plan.
  void deleteExercise(String exerciseId) {
    final removedItemIds = {
      for (final i in _data.workoutPlan.allItems)
        if (i.exerciseId == exerciseId) i.id,
    };
    var plan = _data.workoutPlan;
    for (final day in _data.workoutPlan.days) {
      plan = plan.withDay(day.copyWith(
        items: day.items.where((i) => i.exerciseId != exerciseId).toList(),
      ));
    }
    _commit(_data.copyWith(
      exercises: _data.exercises.where((e) => e.id != exerciseId).toList(),
      workoutPlan: plan,
      workoutProgress: _prunedProgress(removedItemIds),
    ));
  }

  Map<String, Set<String>> _prunedProgress(Set<String> removedItemIds) {
    if (removedItemIds.isEmpty) return _data.workoutProgress;
    final result = <String, Set<String>>{};
    for (final e in _data.workoutProgress.entries) {
      final kept = e.value.difference(removedItemIds);
      if (kept.isNotEmpty) result[e.key] = kept;
    }
    return result;
  }

  void _replaceDay(WorkoutDay day, {Set<String> removedItemIds = const {}}) {
    _commit(_data.copyWith(
      workoutPlan: _data.workoutPlan.withDay(day),
      workoutProgress: _prunedProgress(removedItemIds),
    ));
  }

  void setWorkoutTitle(int weekday, String title) {
    _replaceDay(_data.workoutPlan.day(weekday).copyWith(title: title.trim()));
  }

  void setWorkoutRest(int weekday, bool isRest) {
    _replaceDay(_data.workoutPlan.day(weekday).copyWith(isRest: isRest));
  }

  void addPlannedExercise(int weekday, PlannedExercise item) {
    final day = _data.workoutPlan.day(weekday);
    _replaceDay(day.copyWith(isRest: false, items: [...day.items, item]));
  }

  void updatePlannedExercise(int weekday, PlannedExercise item) {
    final day = _data.workoutPlan.day(weekday);
    _replaceDay(day.copyWith(items: [
      for (final i in day.items) i.id == item.id ? item : i,
    ]));
  }

  void removePlannedExercise(int weekday, String itemId) {
    final day = _data.workoutPlan.day(weekday);
    _replaceDay(
      day.copyWith(items: day.items.where((i) => i.id != itemId).toList()),
      removedItemIds: {itemId},
    );
  }

  void clearWorkoutDay(int weekday) {
    final day = _data.workoutPlan.day(weekday);
    _replaceDay(day.copyWith(items: const []),
        removedItemIds: {for (final i in day.items) i.id});
  }

  /// Moves an item within a day. Uses Flutter's ReorderableListView index
  /// convention (the target index is counted before the item is removed).
  void reorderPlannedExercise(int weekday, int oldIndex, int newIndex) {
    final day = _data.workoutPlan.day(weekday);
    if (oldIndex < 0 || oldIndex >= day.items.length) return;
    final items = [...day.items];
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, items.length - 1).toInt();
    final moved = items.removeAt(oldIndex);
    items.insert(target, moved);
    _replaceDay(day.copyWith(items: items));
  }

  /// Copies the plan of [fromWeekday] onto [toWeekday], replacing it.
  void copyWorkoutDay(int fromWeekday, int toWeekday) {
    if (fromWeekday == toWeekday) return;
    final from = _data.workoutPlan.day(fromWeekday);
    final to = _data.workoutPlan.day(toWeekday);
    final copies = [
      for (final i in from.items) i.copyWith(id: newId('p')),
    ];
    _replaceDay(
      to.copyWith(title: from.title, isRest: from.isRest, items: copies),
      removedItemIds: {for (final i in to.items) i.id},
    );
  }

  /// Ticks or un-ticks one planned exercise on [date]. Future dates and
  /// items that are not part of that weekday's plan are ignored.
  bool toggleWorkoutItem(DateTime date, String itemId) {
    final d = dayOnly(date);
    if (d.isAfter(today)) return false;
    final day = _data.workoutPlan.day(d.weekday);
    if (!day.items.any((i) => i.id == itemId)) return false;

    final key = dateKey(d);
    final current = {...(_data.workoutProgress[key] ?? const <String>{})};
    if (!current.add(itemId)) current.remove(itemId);
    final next = {..._data.workoutProgress};
    if (current.isEmpty) {
      next.remove(key);
    } else {
      next[key] = current;
    }
    _commit(_data.copyWith(workoutProgress: next));
    return true;
  }

  // ------------------------------------------------------------ data tools

  String exportJson() => BackupCodec.export(_data, exportedAt: _clock());

  /// Validates and, only if everything checks out, replaces all data.
  /// Returns an error message, or null on success.
  String? importJson(String raw) {
    final result = BackupCodec.parse(raw);
    final imported = result.data;
    if (imported == null) return result.error ?? 'The backup could not be read.';
    resetReflectionDraft();
    _commit(imported);
    return null;
  }

  /// Replaces everything with fresh sample data (keeps your settings).
  void resetDemoData() {
    resetReflectionDraft();
    _commit(buildSeedData(_clock()).copyWith(settings: _data.settings));
  }

  /// Removes the sample habits, history, sleep, notes and workout plan.
  /// Keeps your settings and the exercise library.
  void clearDemoData() {
    resetReflectionDraft();
    _commit(AppData.empty(
        settings: _data.settings, exercises: _data.exercises));
  }

  /// Erases everything, including settings and custom exercises.
  void clearAllData() {
    resetReflectionDraft();
    _commit(AppData.empty(exercises: starterExercises()));
  }

  // -------------------------------------------------------------- plumbing

  void _invalidateStats() {
    _habitStats = null;
    _sleepStats = null;
  }

  void _commit(AppData next) {
    _data = next;
    _invalidateStats();
    _queueSave(next);
    notifyListeners();
  }

  void _queueSave(AppData snapshot) {
    _saveChain = _saveChain
        .then((_) => _repo.save(snapshot))
        .then((_) {
      if (_saveError != null) {
        _saveError = null;
        notifyListeners();
      }
    }).catchError((Object e) {
      _saveError = 'Could not save your latest changes: $e';
      notifyListeners();
    });
  }
}
