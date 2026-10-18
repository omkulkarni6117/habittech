import 'package:flutter/material.dart';

/// The app's top-level screens, in navigation order.
enum AppSection {
  dashboard('Dashboard', 'Home', Icons.dashboard_outlined, Icons.dashboard),
  today("Today's Focus", 'Today', Icons.check_circle_outline,
      Icons.check_circle),
  matrix('Monthly Habit Matrix', 'Matrix', Icons.grid_view_outlined,
      Icons.grid_view),
  workout('Workout Planner', 'Workout', Icons.fitness_center,
      Icons.fitness_center),
  sleep('Sleep Tracker', 'Sleep', Icons.bedtime_outlined, Icons.bedtime),
  analytics('Progress Analytics', 'Analytics', Icons.insights_outlined,
      Icons.insights),
  reflections('Notes & Reflections', 'Notes', Icons.edit_note, Icons.edit_note),
  settings('Settings & Profile', 'Settings', Icons.settings_outlined,
      Icons.settings);

  const AppSection(this.title, this.shortLabel, this.icon, this.selectedIcon);

  final String title;
  final String shortLabel;
  final IconData icon;
  final IconData selectedIcon;
}
