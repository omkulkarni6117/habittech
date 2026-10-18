import 'dart:convert';

import '../models/app_data.dart';
import '../models/json_helpers.dart';

/// Outcome of validating a pasted JSON backup.
class BackupParseResult {
  const BackupParseResult.ok(AppData this.data) : error = null;
  const BackupParseResult.failed(String this.error) : data = null;

  final AppData? data;
  final String? error;

  bool get isValid => data != null;
}

/// Export / import of the whole data set as JSON.
///
/// Imports are validated completely (types, dates, times, unique ids and
/// cross references) before anything is replaced.
class BackupCodec {
  const BackupCodec._();

  static String export(AppData data, {DateTime? exportedAt}) {
    final json = data.toJson()
      ..['exportedAt'] = (exportedAt ?? DateTime.now()).toIso8601String();
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  static BackupParseResult parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const BackupParseResult.failed('The backup is empty.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return const BackupParseResult.failed(
          'That is not valid JSON. Paste the full text of a HabitTech backup.');
    }
    try {
      final json = asJson(decoded, 'The backup');
      if (json['app'] != null && json['app'] != 'HabitTech') {
        return const BackupParseResult.failed(
            'This backup was not created by HabitTech.');
      }
      return BackupParseResult.ok(AppData.fromJson(json));
    } catch (e) {
      final reason = e is FormatException ? e.message : e.toString();
      return BackupParseResult.failed('Invalid backup: $reason');
    }
  }
}
