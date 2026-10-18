/// Strict JSON readers used by every model's `fromJson`.
///
/// All of them throw [FormatException] with a readable message, which the
/// storage layer and the backup importer turn into user-facing errors.
library;

import '../core/date_utils.dart';
import '../core/time_utils.dart';

typedef Json = Map<String, dynamic>;

Json asJson(Object? value, String where) {
  if (value is Map) {
    return value.map<String, dynamic>((k, v) => MapEntry(k.toString(), v));
  }
  throw FormatException('$where must be an object');
}

List<dynamic> asList(Object? value, String where) {
  if (value is List) return value;
  throw FormatException('$where must be a list');
}

String reqString(Json j, String key, {bool allowEmpty = false}) {
  final v = j[key];
  if (v is String && (allowEmpty || v.trim().isNotEmpty)) return v;
  throw FormatException(
      '"$key" must be ${allowEmpty ? 'a string' : 'a non-empty string'}');
}

String strOr(Json j, String key, String fallback) {
  final v = j[key];
  if (v == null) return fallback;
  if (v is String) return v;
  throw FormatException('"$key" must be a string');
}

String? optString(Json j, String key) {
  final v = j[key];
  if (v == null) return null;
  if (v is String) return v;
  throw FormatException('"$key" must be a string');
}

int reqInt(Json j, String key, {int? min, int? max}) {
  final v = j[key];
  int? n;
  if (v is int) {
    n = v;
  } else if (v is num && v == v.roundToDouble()) {
    n = v.toInt();
  }
  if (n == null) throw FormatException('"$key" must be a whole number');
  if (min != null && n < min) throw FormatException('"$key" must be >= $min');
  if (max != null && n > max) throw FormatException('"$key" must be <= $max');
  return n;
}

int intOr(Json j, String key, int fallback, {int? min, int? max}) {
  if (j[key] == null) return fallback;
  return reqInt(j, key, min: min, max: max);
}

int? optInt(Json j, String key, {int? min, int? max}) {
  if (j[key] == null) return null;
  return reqInt(j, key, min: min, max: max);
}

double? optDouble(Json j, String key, {double? min}) {
  final v = j[key];
  if (v == null) return null;
  if (v is! num) throw FormatException('"$key" must be a number');
  final d = v.toDouble();
  if (min != null && d < min) throw FormatException('"$key" must be >= $min');
  return d;
}

bool boolOr(Json j, String key, bool fallback) {
  final v = j[key];
  if (v == null) return fallback;
  if (v is bool) return v;
  throw FormatException('"$key" must be true or false');
}

String reqDateKey(Json j, String key) {
  final v = reqString(j, key);
  if (tryParseDateKey(v) == null) {
    throw FormatException('"$key" must be a valid date (yyyy-MM-dd), got "$v"');
  }
  return v;
}

String reqTimeKey(Json j, String key) {
  final v = reqString(j, key);
  if (parseHm(v) == null) {
    throw FormatException('"$key" must be a time (HH:mm), got "$v"');
  }
  return v;
}

String? optTimeKey(Json j, String key) {
  final v = optString(j, key);
  if (v == null) return null;
  if (parseHm(v) == null) {
    throw FormatException('"$key" must be a time (HH:mm), got "$v"');
  }
  return v;
}

DateTime reqDateTime(Json j, String key) {
  final v = reqString(j, key);
  return DateTime.tryParse(v) ??
      (throw FormatException('"$key" must be an ISO-8601 date-time'));
}

DateTime? optDateTime(Json j, String key) {
  final v = optString(j, key);
  if (v == null) return null;
  return DateTime.tryParse(v) ??
      (throw FormatException('"$key" must be an ISO-8601 date-time'));
}
