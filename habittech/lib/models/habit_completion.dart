import 'json_helpers.dart';

/// One habit completed on one calendar day.
///
/// The id is derived from `habitId` and `date`, so two records for the same
/// habit and day can never coexist: toggling twice replaces, never duplicates.
class HabitCompletion {
  HabitCompletion({
    required this.habitId,
    required this.date,
    this.completed = true,
    required this.completedAt,
  });

  final String habitId;

  /// Local calendar day, `yyyy-MM-dd`.
  final String date;
  final bool completed;
  final DateTime completedAt;

  String get id => makeId(habitId, date);

  static String makeId(String habitId, String date) => '${habitId}_$date';

  Json toJson() => {
        'id': id,
        'habitId': habitId,
        'date': date,
        'completed': completed,
        'completedAt': completedAt.toIso8601String(),
      };

  factory HabitCompletion.fromJson(Json j) => HabitCompletion(
        habitId: reqString(j, 'habitId'),
        date: reqDateKey(j, 'date'),
        completed: boolOr(j, 'completed', true),
        completedAt: reqDateTime(j, 'completedAt'),
      );
}
