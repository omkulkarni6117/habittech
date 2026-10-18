import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_data.dart';
import '../models/json_helpers.dart';

/// Result of reading saved data.
class LoadResult {
  const LoadResult({this.data, this.warning});

  /// Null when nothing usable was stored.
  final AppData? data;

  /// Set when stored data existed but could not be read.
  final String? warning;
}

/// Where HabitTech keeps its data.
///
/// The UI only talks to [AppState], and [AppState] only talks to this
/// interface, so a cloud implementation (for example Supabase with
/// row-level security, one row set per authenticated user) can replace
/// [LocalStorageRepository] without UI changes.
abstract class StorageRepository {
  Future<LoadResult> load();
  Future<void> save(AppData data);
  Future<void> clear();
}

/// Local-first storage in the platform key-value store
/// (SharedPreferences: NSUserDefaults / Android SharedPreferences).
class LocalStorageRepository implements StorageRepository {
  LocalStorageRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String dataKey = 'habittech.data.v1';

  /// Unreadable data is copied here before being discarded, so it is never
  /// silently destroyed.
  static const String corruptBackupKey = 'habittech.data.unreadable-backup';

  @override
  Future<LoadResult> load() async {
    final raw = _prefs.getString(dataKey);
    if (raw == null) return const LoadResult();
    try {
      final decoded = jsonDecode(raw);
      final data = AppData.fromJson(asJson(decoded, 'Saved data'));
      return LoadResult(data: data);
    } catch (e) {
      final reason = e is FormatException ? e.message : e.toString();
      await _prefs.setString(corruptBackupKey, raw);
      await _prefs.remove(dataKey);
      return LoadResult(
        warning: 'Your saved data could not be read ($reason). '
            'A copy was kept on the device and sample data was loaded instead.',
      );
    }
  }

  @override
  Future<void> save(AppData data) async {
    final ok = await _prefs.setString(dataKey, jsonEncode(data.toJson()));
    if (!ok) throw StateError('The device refused to store HabitTech data.');
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(dataKey);
  }
}
