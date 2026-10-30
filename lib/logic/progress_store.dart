import 'package:shared_preferences/shared_preferences.dart';

abstract class ProgressStore {
  Future<int> loadLevel();
  Future<void> saveLevel(int level);
}

class PrefsProgressStore implements ProgressStore {
  static const _key = 'pour_sort.level';

  @override
  Future<int> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.get(_key);
    final v = raw is int ? raw : 1;
    return v < 1 ? 1 : v;
  }

  @override
  Future<void> saveLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, level);
  }
}

class MemoryProgressStore implements ProgressStore {
  MemoryProgressStore([this.level = 1]);
  int level;

  @override
  Future<int> loadLevel() async => level;

  @override
  Future<void> saveLevel(int value) async => level = value;
}
