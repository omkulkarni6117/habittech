import 'json_helpers.dart';

enum ThemeSetting {
  system('System'),
  light('Light'),
  dark('Dark');

  const ThemeSetting(this.label);
  final String label;
}

class UserSettings {
  const UserSettings({
    this.displayName = 'Alex',
    this.dailyHabitGoal = 5,
    this.sleepGoalMinutes = 480,
    this.theme = ThemeSetting.system,
    this.weekStartsOn = 1,
  });

  final String displayName;

  /// How many habits make a "successful day" (capped by the number of habits
  /// scheduled that day). Drives streaks and weekly consistency.
  final int dailyHabitGoal;
  final int sleepGoalMinutes;
  final ThemeSetting theme;

  /// `DateTime.weekday` numbering: 1 = Monday, 6 = Saturday, 7 = Sunday.
  final int weekStartsOn;

  UserSettings copyWith({
    String? displayName,
    int? dailyHabitGoal,
    int? sleepGoalMinutes,
    ThemeSetting? theme,
    int? weekStartsOn,
  }) =>
      UserSettings(
        displayName: displayName ?? this.displayName,
        dailyHabitGoal: dailyHabitGoal ?? this.dailyHabitGoal,
        sleepGoalMinutes: sleepGoalMinutes ?? this.sleepGoalMinutes,
        theme: theme ?? this.theme,
        weekStartsOn: weekStartsOn ?? this.weekStartsOn,
      );

  Json toJson() => {
        'displayName': displayName,
        'dailyHabitGoal': dailyHabitGoal,
        'sleepGoalMinutes': sleepGoalMinutes,
        'theme': theme.name,
        'weekStartsOn': weekStartsOn,
      };

  factory UserSettings.fromJson(Json j) {
    const defaults = UserSettings();
    final themeName = strOr(j, 'theme', defaults.theme.name);
    final theme = ThemeSetting.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => throw FormatException('Unknown theme "$themeName"'),
    );
    final weekStart = intOr(j, 'weekStartsOn', defaults.weekStartsOn,
        min: 1, max: 7);
    if (weekStart != 1 && weekStart != 6 && weekStart != 7) {
      throw const FormatException(
          '"weekStartsOn" must be 1 (Monday), 6 (Saturday) or 7 (Sunday)');
    }
    return UserSettings(
      displayName:
          strOr(j, 'displayName', defaults.displayName).trim().isEmpty
              ? defaults.displayName
              : strOr(j, 'displayName', defaults.displayName),
      dailyHabitGoal:
          intOr(j, 'dailyHabitGoal', defaults.dailyHabitGoal, min: 1, max: 50),
      sleepGoalMinutes: intOr(
          j, 'sleepGoalMinutes', defaults.sleepGoalMinutes,
          min: 120, max: 960),
      theme: theme,
      weekStartsOn: weekStart,
    );
  }
}
