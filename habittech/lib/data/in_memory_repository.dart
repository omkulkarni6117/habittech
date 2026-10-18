import 'dart:convert';

import '../models/app_data.dart';
import '../models/json_helpers.dart';
import 'storage_repository.dart';

/// A [StorageRepository] that keeps one JSON string in memory.
///
/// Used by tests (it round-trips through JSON exactly like the real
/// repository, so "persistence after reload" tests are meaningful) and
/// handy for previews.
class InMemoryStorageRepository implements StorageRepository {
  InMemoryStorageRepository({String? initialRaw}) : raw = initialRaw;

  /// The stored JSON, or null when nothing is stored. Tests may overwrite it
  /// to simulate corrupted storage.
  String? raw;

  int saveCount = 0;

  @override
  Future<LoadResult> load() async {
    final stored = raw;
    if (stored == null) return const LoadResult();
    try {
      final data = AppData.fromJson(asJson(jsonDecode(stored), 'Saved data'));
      return LoadResult(data: data);
    } catch (e) {
      final reason = e is FormatException ? e.message : e.toString();
      return LoadResult(warning: 'Unreadable saved data: $reason');
    }
  }

  @override
  Future<void> save(AppData data) async {
    saveCount++;
    raw = jsonEncode(data.toJson());
  }

  @override
  Future<void> clear() async {
    raw = null;
  }
}
