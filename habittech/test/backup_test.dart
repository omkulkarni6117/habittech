import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habittech/data/backup.dart';
import 'package:habittech/data/seed_data.dart';

import 'helpers.dart';

/// A valid backup as a mutable map, built from the sample data.
Map<String, dynamic> validBackup() {
  final json = jsonDecode(BackupCodec.export(buildSeedData(kNow)));
  return json as Map<String, dynamic>;
}

BackupParseResult parseMap(Map<String, dynamic> m) =>
    BackupCodec.parse(jsonEncode(m));

void main() {
  test('a valid export parses back to the same content', () {
    final data = buildSeedData(kNow);
    final result = BackupCodec.parse(BackupCodec.export(data));
    expect(result.isValid, isTrue, reason: result.error);
    final back = result.data!;
    expect(back.habits.length, data.habits.length);
    expect(back.completions.length, data.completions.length);
    expect(back.sleepEntries.length, data.sleepEntries.length);
    expect(back.reflections.length, data.reflections.length);
    expect(back.exercises.length, data.exercises.length);
    expect(back.workoutPlan.allItems.length, data.workoutPlan.allItems.length);
    expect(back.workoutProgress, data.workoutProgress);
    expect(back.settings.sleepGoalMinutes, data.settings.sleepGoalMinutes);
  });

  group('rejects invalid backups', () {
    test('empty and non-JSON text', () {
      expect(BackupCodec.parse('').isValid, isFalse);
      expect(BackupCodec.parse('   ').isValid, isFalse);
      expect(BackupCodec.parse('hello').isValid, isFalse);
      expect(BackupCodec.parse('[1,2,3]').isValid, isFalse);
    });

    test('another app or an unknown schema version', () {
      final other = validBackup()..['app'] = 'SomethingElse';
      expect(parseMap(other).isValid, isFalse);
      final future = validBackup()..['schemaVersion'] = 99;
      expect(parseMap(future).error, contains('version'));
    });

    test('missing sections', () {
      final m = validBackup()..remove('habits');
      expect(parseMap(m).isValid, isFalse);
    });

    test('impossible dates and times', () {
      final badDate = validBackup();
      (badDate['completions'] as List).first['date'] = '2026-02-30';
      expect(parseMap(badDate).isValid, isFalse);

      final badTime = validBackup();
      (badTime['sleepEntries'] as List).first['bedtime'] = '25:99';
      expect(parseMap(badTime).isValid, isFalse);
    });

    test('duplicate completion for the same habit and day', () {
      final m = validBackup();
      final list = m['completions'] as List;
      list.add(Map<String, dynamic>.from(list.first as Map));
      expect(parseMap(m).error, contains('Duplicate completion'));
    });

    test('completion pointing at an unknown habit', () {
      final m = validBackup();
      (m['completions'] as List).first['habitId'] = 'ghost';
      expect(parseMap(m).error, contains('unknown habit'));
    });

    test('duplicate ids', () {
      final m = validBackup();
      final habits = m['habits'] as List;
      habits[1]['id'] = habits[0]['id'];
      expect(parseMap(m).error, contains('Duplicate habit'));
    });

    test('two sleep entries on one date', () {
      final m = validBackup();
      final sleep = m['sleepEntries'] as List;
      sleep[1]['date'] = sleep[0]['date'];
      expect(parseMap(m).isValid, isFalse);
    });

    test('out-of-range numbers and unknown enum values', () {
      final q = validBackup();
      (q['sleepEntries'] as List).first['quality'] = 9;
      expect(parseMap(q).isValid, isFalse);

      final cat = validBackup();
      (cat['habits'] as List).first['category'] = 'astrology';
      expect(parseMap(cat).isValid, isFalse);

      final week = validBackup();
      (week['settings'] as Map)['weekStartsOn'] = 3;
      expect(parseMap(week).isValid, isFalse);
    });

    test('workout plan referencing a missing exercise', () {
      final m = validBackup();
      final day = (m['workoutPlan']['days'] as List)
          .firstWhere((d) => (d['items'] as List).isNotEmpty);
      day['items'][0]['exerciseId'] = 'ex-does-not-exist';
      expect(parseMap(m).error, contains('unknown exercise'));
    });

    test('workout day listed twice', () {
      final m = validBackup();
      final days = m['workoutPlan']['days'] as List;
      days[1]['weekday'] = days[0]['weekday'];
      expect(parseMap(m).isValid, isFalse);
    });

    test('malformed workout progress', () {
      final m = validBackup();
      m['workoutProgress'] = {'not-a-date': ['x']};
      expect(parseMap(m).isValid, isFalse);
    });
  });

  test('a backup without optional workout data still imports', () {
    final m = validBackup()
      ..remove('exercises')
      ..remove('workoutPlan')
      ..remove('workoutProgress');
    final result = parseMap(m);
    expect(result.isValid, isTrue, reason: result.error);
    expect(result.data!.exercises, isEmpty);
    expect(result.data!.workoutPlan.days.length, 7);
  });
}
