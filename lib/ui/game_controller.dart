import 'package:flutter/foundation.dart';

import '../logic/level_generator.dart';
import '../logic/player_progress.dart';
import '../logic/pour_game.dart';
import '../logic/progress_store.dart';
import '../logic/stars.dart';

/// Game state for the screen: the current level, its rules engine, and the
/// saved meta progress. Rules apply instantly; presentation trails behind.
class GameController extends ChangeNotifier {
  GameController(this.store);

  final ProgressStore store;

  int level = 1;
  late Level _level;
  late PourGame game;
  int? selected;
  PourMove? lastMove;
  int moveSerial = 0;

  /// Bumped whenever a level is (re)loaded, so effects can reset.
  int levelSerial = 0;
  bool loaded = false;

  /// Saved progress. Only written after it has been loaded ([loaded]).
  PlayerProgress progress = const PlayerProgress.initial();

  /// Result of the last clear of the current attempt, or null while playing.
  WinOutcome? outcome;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> init() async {
    var saved = const PlayerProgress.initial();
    try {
      saved = await store.load();
    } catch (_) {
      saved = const PlayerProgress.initial();
    }
    if (_disposed) return;
    progress = saved;
    loaded = true;
    loadLevel(saved.lastLevel);
  }

  Future<void> _save() async {
    if (!loaded) return;
    try {
      await store.save(progress);
    } catch (_) {
      // Progress is best effort; the game keeps working without storage.
    }
  }

  int get par => parForLevel(_level);
  int get colors => _level.colors;

  /// Stars the player would get by finishing now.
  int get starsNow =>
      starsForMoves(game.moves, par, usedExtraTube: game.extraTubeUsed);

  void loadLevel(int n) {
    level = n < 1 ? 1 : n;
    _level = generateLevel(level);
    game = PourGame(_level.tubes);
    selected = null;
    lastMove = null;
    outcome = null;
    levelSerial++;
    if (loaded) {
      final next = progress.withLastLevel(level);
      if (!identical(next, progress)) {
        progress = next;
        _save();
      }
    }
    notifyListeners();
  }

  bool get won => game.isWon;

  /// True when the level is not won and no pour is possible.
  bool get stuck {
    if (won) return false;
    final t = game.tubes;
    for (var i = 0; i < t.length; i++) {
      for (var j = 0; j < t.length; j++) {
        if (game.canPour(i, j)) return false;
      }
    }
    return true;
  }

  void tap(int i) {
    if (won || i < 0 || i >= game.tubes.length) return;
    final from = selected;
    if (from == null) {
      if (game.tubes[i].isNotEmpty) selected = i;
    } else if (from == i) {
      selected = null;
    } else {
      final move = game.pour(from, i);
      if (move != null) {
        selected = null;
        lastMove = move;
        moveSerial++;
        if (won) _onWin();
      } else {
        selected = game.tubes[i].isNotEmpty ? i : null;
      }
    }
    notifyListeners();
  }

  void _onWin() {
    final result = progress.applyWin(
      level: level,
      moves: game.moves,
      par: par,
      usedExtraTube: game.extraTubeUsed,
    );
    outcome = result;
    progress = result.progress.withLastLevel(level + 1);
    _save();
  }

  void undo() {
    if (won) return;
    if (game.undo() != null) {
      selected = null;
      lastMove = null;
      notifyListeners();
    }
  }

  void restart() => loadLevel(level);

  void addTube() {
    if (!won && game.addExtraTube()) notifyListeners();
  }

  void nextLevel() => loadLevel(level + 1);

  /// Starts any unlocked level; locked levels are ignored.
  bool playLevel(int n) {
    if (!loaded || !progress.isUnlocked(n)) return false;
    loadLevel(n);
    return true;
  }

  /// Selects an unlocked theme and saves it. Returns false when locked.
  bool selectTheme(PourTheme theme) {
    if (!loaded) return false;
    final next = progress.withTheme(theme);
    if (identical(next, progress)) return progress.selectedTheme == theme;
    progress = next;
    _save();
    notifyListeners();
    return true;
  }
}
