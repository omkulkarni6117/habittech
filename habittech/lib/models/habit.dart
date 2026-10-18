import '../core/date_utils.dart';
import 'json_helpers.dart';

enum HabitCategory {
  fitness('Fitness'),
  health('Health'),
  learning('Learning'),
  mindfulness('Mindfulness'),
  productivity('Productivity'),
  personalGrowth('Personal Growth'),
  sleep('Sleep'),
  custom('Custom');

  const HabitCategory(this.label);
  final String label;

  static HabitCategory parse(String s) => values.firstWhere(
        (e) => e.name == s,
        orElse: () => throw FormatException('Unknown habit category "$s"'),
      );
}

enum ScheduleType { daily, weekly }

/// A habit the user wants to track.
///
/// Counting rules (see [appliesOn]):
///  * a habit never counts before its [startDate], so creating a habit today
///    cannot inflate or deflate historical rates;
///  * an archived habit stops counting after its archive day but keeps its
///    history;
///  * weekly habits only count on their scheduled [weekdays].
class Habit {
  Habit({
    required this.id,
    required this.name,
    this.description = '',
    this.iconKey = 'task_alt',
    this.category = HabitCategory.custom,
    this.scheduleType = ScheduleType.daily,
    List<int>? weekdays,
    this.goalValue,
    this.goalUnit = '',
    this.reminderTime,
    required this.startDate,
    required this.createdAt,
    this.archivedAt,
  }) : weekdays = List<int>.unmodifiable(weekdays ?? const [1, 2, 3, 4, 5, 6, 7]);

  final String id;
  final String name;
  final String description;
  final String iconKey;
  final HabitCategory category;
  final ScheduleType scheduleType;

  /// `DateTime.weekday` numbers (1 = Monday ... 7 = Sunday). Always all seven
  /// for daily habits.
  final List<int> weekdays;
  final double? goalValue;
  final String goalUnit;

  /// Optional `HH:mm`. Stored as a preference; this version does not deliver
  /// device notifications.
  final String? reminderTime;

  /// First day the habit counts, as `yyyy-MM-dd`.
  final String startDate;
  final DateTime createdAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  String? get _archivedKey =>
      archivedAt == null ? null : dateKey(archivedAt!);

  bool isScheduledOn(DateTime day) =>
      scheduleType == ScheduleType.daily || weekdays.contains(day.weekday);

  /// True when [day] falls between the start date and the archive day.
  bool isActiveOn(DateTime day) {
    final k = dateKey(day);
    if (k.compareTo(startDate) < 0) return false;
    final archived = _archivedKey;
    return archived == null || k.compareTo(archived) <= 0;
  }

  /// True when completing this habit on [day] is possible and counted.
  bool appliesOn(DateTime day) => isActiveOn(day) && isScheduledOn(day);

  String get scheduleLabel {
    if (scheduleType == ScheduleType.daily) return 'Every day';
    final sorted = [...weekdays]..sort();
    final names = sorted.map((w) => kWeekdayShort[w - 1]).join(', ');
    return '$names (${sorted.length}x/week)';
  }

  /// "30 minutes", "8000 steps", or an empty string when no goal is set.
  String get goalLabel {
    final v = goalValue;
    if (v == null) return '';
    return '${formatNumber(v)} $goalUnit'.trim();
  }

  Habit copyWith({
    String? name,
    String? description,
    String? iconKey,
    HabitCategory? category,
    ScheduleType? scheduleType,
    List<int>? weekdays,
    double? goalValue,
    bool clearGoal = false,
    String? goalUnit,
    String? reminderTime,
    bool clearReminder = false,
    String? startDate,
    DateTime? archivedAt,
    bool clearArchived = false,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      category: category ?? this.category,
      scheduleType: scheduleType ?? this.scheduleType,
      weekdays: weekdays ?? this.weekdays,
      goalValue: clearGoal ? null : (goalValue ?? this.goalValue),
      goalUnit: goalUnit ?? this.goalUnit,
      reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
      startDate: startDate ?? this.startDate,
      createdAt: createdAt,
      archivedAt: clearArchived ? null : (archivedAt ?? this.archivedAt),
    );
  }

  Json toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': iconKey,
        'category': category.name,
        'scheduleType': scheduleType.name,
        'weekdays': weekdays,
        'goalValue': goalValue,
        'goalUnit': goalUnit,
        'reminderTime': reminderTime,
        'startDate': startDate,
        'createdAt': createdAt.toIso8601String(),
        'archivedAt': archivedAt?.toIso8601String(),
      };

  factory Habit.fromJson(Json j) {
    final type = reqString(j, 'scheduleType');
    final scheduleType = ScheduleType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => throw FormatException('Unknown schedule "$type"'),
    );
    final rawDays = asList(j['weekdays'] ?? const <int>[1, 2, 3, 4, 5, 6, 7],
        'weekdays');
    final days = <int>{};
    for (final d in rawDays) {
      if (d is! int || d < 1 || d > 7) {
        throw const FormatException('"weekdays" must contain numbers 1-7');
      }
      days.add(d);
    }
    if (scheduleType == ScheduleType.weekly && days.isEmpty) {
      throw const FormatException('A weekly habit needs at least one weekday');
    }
    return Habit(
      id: reqString(j, 'id'),
      name: reqString(j, 'name'),
      description: strOr(j, 'description', ''),
      iconKey: strOr(j, 'icon', 'task_alt'),
      category: HabitCategory.parse(reqString(j, 'category')),
      scheduleType: scheduleType,
      weekdays: scheduleType == ScheduleType.daily
          ? const [1, 2, 3, 4, 5, 6, 7]
          : (days.toList()..sort()),
      goalValue: optDouble(j, 'goalValue', min: 0),
      goalUnit: strOr(j, 'goalUnit', ''),
      reminderTime: optTimeKey(j, 'reminderTime'),
      startDate: reqDateKey(j, 'startDate'),
      createdAt: reqDateTime(j, 'createdAt'),
      archivedAt: optDateTime(j, 'archivedAt'),
    );
  }
}
