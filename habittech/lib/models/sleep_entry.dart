import '../core/time_utils.dart';
import 'json_helpers.dart';

/// One night of sleep.
///
/// [date] is the day the person **woke up**, so "last night" is stored under
/// today's date. There is at most one entry per date.
class SleepEntry {
  SleepEntry({
    required this.date,
    required this.bedtime,
    required this.wakeTime,
    required this.durationMinutes,
    this.quality,
    this.notes = '',
  });

  /// Builds an entry and derives the duration from the two times
  /// (overnight-aware).
  factory SleepEntry.fromTimes({
    required String date,
    required String bedtime,
    required String wakeTime,
    int? quality,
    String notes = '',
  }) =>
      SleepEntry(
        date: date,
        bedtime: bedtime,
        wakeTime: wakeTime,
        durationMinutes: sleepDurationMinutes(bedtime, wakeTime),
        quality: quality,
        notes: notes,
      );

  final String date;
  final String bedtime;
  final String wakeTime;
  final int durationMinutes;

  /// Optional self-rating, 1 (poor) to 5 (excellent).
  final int? quality;
  final String notes;

  String get id => date;

  Json toJson() => {
        'id': id,
        'date': date,
        'bedtime': bedtime,
        'wakeTime': wakeTime,
        'durationMinutes': durationMinutes,
        'quality': quality,
        'notes': notes,
      };

  factory SleepEntry.fromJson(Json j) => SleepEntry(
        date: reqDateKey(j, 'date'),
        bedtime: reqTimeKey(j, 'bedtime'),
        wakeTime: reqTimeKey(j, 'wakeTime'),
        durationMinutes: reqInt(j, 'durationMinutes', min: 1, max: 1439),
        quality: optInt(j, 'quality', min: 1, max: 5),
        notes: strOr(j, 'notes', ''),
      );
}
