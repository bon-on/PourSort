import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'player_progress.dart';

/// Loads and saves [PlayerProgress].
///
/// The level-only API ([loadLevel] / [saveLevel]) is the pre-v1 contract; the
/// default [load] / [save] build on it so simple stores keep working. Callers
/// must treat any failure as "use the defaults" and keep playing.
abstract class ProgressStore {
  Future<int> loadLevel();
  Future<void> saveLevel(int level);

  Future<PlayerProgress> load() async =>
      PlayerProgress.fromLegacyLevel(await loadLevel());

  Future<void> save(PlayerProgress progress) => saveLevel(progress.lastLevel);
}

/// shared_preferences store. Progress lives as JSON under [progressKey]; a
/// save that predates it ([legacyKey], the resume level) is migrated on
/// load. The legacy key is kept up to date (resume level) and never removed,
/// so an older build still resumes at the right level.
class PrefsProgressStore extends ProgressStore {
  static const String progressKey = 'pour_sort.progress_v1';
  static const String legacyKey = 'pour_sort.level';

  @override
  Future<int> loadLevel() async => (await load()).lastLevel;

  @override
  Future<void> saveLevel(int level) async {
    final current = await load();
    await save(current.withLastLevel(level));
  }

  @override
  Future<PlayerProgress> load() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return const PlayerProgress.initial();
    }
    final raw = _read(prefs, progressKey);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        // Anything but an object is corrupt: try the legacy value first.
        if (decoded is Map) return PlayerProgress.fromJson(decoded);
      } catch (_) {
        // Corrupt JSON: fall through to the legacy value, then defaults.
      }
    }
    final legacy = _read(prefs, legacyKey);
    if (legacy is int) return PlayerProgress.fromLegacyLevel(legacy);
    return const PlayerProgress.initial();
  }

  @override
  Future<void> save(PlayerProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(progressKey, jsonEncode(progress.toJson()));
      await prefs.setInt(legacyKey, progress.lastLevel);
    } catch (_) {
      // Progress is best effort; the game keeps working without storage.
    }
  }

  static Object? _read(SharedPreferences prefs, String key) {
    try {
      return prefs.get(key);
    } catch (_) {
      return null;
    }
  }
}

/// In-memory store for tests. `MemoryProgressStore(4)` behaves like a pre-v1
/// save at level 4.
class MemoryProgressStore extends ProgressStore {
  MemoryProgressStore([int level = 1])
    : progress = PlayerProgress.fromLegacyLevel(level);

  MemoryProgressStore.withProgress(this.progress);

  PlayerProgress progress;
  int saveCount = 0;

  /// The resume level, like the pre-v1 store.
  int get level => progress.lastLevel;

  @override
  Future<int> loadLevel() async => progress.lastLevel;

  @override
  Future<void> saveLevel(int value) async =>
      save(progress.withLastLevel(value));

  @override
  Future<PlayerProgress> load() async => progress;

  @override
  Future<void> save(PlayerProgress progress) async {
    this.progress = progress;
    saveCount++;
  }
}
