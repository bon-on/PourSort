import 'package:flutter/foundation.dart';

import '../logic/level_generator.dart';
import '../logic/pour_game.dart';
import '../logic/progress_store.dart';

class GameController extends ChangeNotifier {
  GameController(this.store);

  final ProgressStore store;

  int level = 1;
  late Level _level;
  late PourGame game;
  int? selected;
  PourMove? lastMove;
  int moveSerial = 0;
  bool loaded = false;

  Future<void> init() async {
    loadLevel(await store.loadLevel());
    loaded = true;
    notifyListeners();
  }

  void loadLevel(int n) {
    level = n < 1 ? 1 : n;
    _level = generateLevel(level);
    game = PourGame(_level.tubes);
    selected = null;
    lastMove = null;
    notifyListeners();
  }

  bool get won => game.isWon;

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
        if (won) store.saveLevel(level + 1);
      } else {
        selected = game.tubes[i].isNotEmpty ? i : null;
      }
    }
    notifyListeners();
  }

  void undo() {
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
}
