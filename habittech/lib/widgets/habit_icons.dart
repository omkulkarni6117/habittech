import 'package:flutter/material.dart';

/// Icons a habit can use. Keys are stored in the data, so never rename them.
const Map<String, IconData> kHabitIcons = {
  'fitness_center': Icons.fitness_center,
  'water_drop': Icons.water_drop,
  'menu_book': Icons.menu_book,
  'self_improvement': Icons.self_improvement,
  'directions_walk': Icons.directions_walk,
  'school': Icons.school,
  'bedtime': Icons.bedtime,
  'favorite': Icons.favorite,
  'restaurant': Icons.restaurant,
  'code': Icons.code,
  'brush': Icons.brush,
  'music_note': Icons.music_note,
  'savings': Icons.savings,
  'cleaning_services': Icons.cleaning_services,
  'wb_sunny': Icons.wb_sunny,
  'eco': Icons.eco,
  'timer': Icons.timer,
  'edit_note': Icons.edit_note,
  'spa': Icons.spa,
  'directions_run': Icons.directions_run,
  'pedal_bike': Icons.pedal_bike,
  'local_cafe': Icons.local_cafe,
  'language': Icons.language,
  'psychology': Icons.psychology,
  'task_alt': Icons.task_alt,
};

IconData habitIcon(String key) => kHabitIcons[key] ?? Icons.task_alt;
