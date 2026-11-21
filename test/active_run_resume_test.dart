import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/logic/level_generator.dart';
import 'package:pour_sort/logic/player_progress.dart';
import 'package:pour_sort/logic/pour_game.dart';
import 'package:pour_sort/logic/progress_store.dart';
import 'package:pour_sort/logic/solver.dart';
import 'package:pour_sort/ui/game_controller.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test('snapshot roundtrip retains extra tube, moves and undo history', () {
    final initial = generateLevel(1).tubes;
    final game = PourGame(initial)..addExtraTube();
    final move = legalMoves(game.tubes).first;
    game.pour(move.from, move.to);
    final snapshot = jsonDecode(jsonEncode(game.toSnapshot()));
    final restored = PourGame.restore(snapshot, initial)!;
    expect(restored.tubes, game.tubes);
    expect(restored.moves, 1);
    expect(restored.addExtraTube(), isFalse);
    expect(restored.undo(), move);
    expect(restored.tubes, [...initial, <int>[]]);
  });

  test('corrupt snapshots reject impossible board and undo payloads', () {
    final initial = generateLevel(1).tubes;
    final game = PourGame(initial);
    for (final bad in [
      null,
      {'v': 2},
      {...game.toSnapshot(), 'tubes': []},
      {
        ...game.toSnapshot(),
        'history': [
          [0, 0, 1, 0],
        ],
      },
      {
        ...game.toSnapshot(),
        'history': [
          [0.0, 1, 1, 0],
        ],
      },
    ]) {
      expect(PourGame.restore(bad, initial), isNull);
    }
  });

  test(
    'recreated controller resumes, undoes and replaces attempt on restart',
    () async {
      final store = MemoryProgressStore();
      final first = GameController(store);
      await first.init();
      first.addTube();
      final move = legalMoves(first.game.tubes).first;
      first.tap(move.from);
      first.tap(move.to);
      final board = jsonDecode(jsonEncode(first.game.tubes));
      await flush();
      store.progress = PlayerProgress.fromJson(
        jsonDecode(jsonEncode(store.progress.toJson())),
      );
      first.dispose();
      final second = GameController(store);
      await second.init();
      expect(second.game.tubes, board);
      expect(second.game.extraTubeUsed, isTrue);
      expect(second.game.moves, 1);
      second.undo();
      expect(second.game.moves, 0);
      expect(second.game.tubes, [...generateLevel(1).tubes, <int>[]]);
      second.restart();
      await flush();
      final third = GameController(store);
      await third.init();
      expect(third.game.extraTubeUsed, isFalse);
      expect(third.game.moves, 0);
      second.dispose();
      third.dispose();
    },
  );

  test('win clears attempt with reward; refresh never replays XP', () async {
    final store = MemoryProgressStore();
    final first = GameController(store);
    await first.init();
    final solution = solve(first.game.tubes)!;
    for (final move in solution) {
      first.tap(move.from);
      first.tap(move.to);
    }
    expect(first.won, isTrue);
    await flush();
    final xp = store.progress.totalXp;
    expect(xp, greaterThan(0));
    expect(store.progress.activeRun, isNull);
    first.dispose();
    for (var i = 0; i < 2; i++) {
      final next = GameController(store);
      await next.init();
      await flush();
      expect(next.level, 2);
      expect(next.outcome, isNull);
      expect(next.progress.totalXp, xp);
      next.dispose();
    }
  });

  test(
    'invalid attempt preserves legacy progress and starts current level',
    () async {
      final store = MemoryProgressStore.withProgress(
        PlayerProgress.fromLegacyLevel(
          2,
        ).withActiveRun({'v': 1, 'level': 2, 'game': {}}),
      );
      final controller = GameController(store);
      await controller.init();
      expect(controller.level, 2);
      expect(controller.game.moves, 0);
      expect(controller.progress.totalXp, 40);
      controller.dispose();
    },
  );
}
