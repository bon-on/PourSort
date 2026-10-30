import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/logic/level_generator.dart';
import 'package:pour_sort/logic/pour_game.dart';
import 'package:pour_sort/logic/solver.dart';

void main() {
  group('pour rules', () {
    test('moves the whole top run onto an empty tube', () {
      final g = PourGame([
        [1, 0, 0],
        [],
      ]);
      final m = g.pour(0, 1)!;
      expect(m.count, 2);
      expect(g.tubes, [
        [1],
        [0, 0],
      ]);
    });

    test('only onto matching top color', () {
      final g = PourGame([
        [0, 1],
        [2, 0],
      ]);
      expect(g.pour(0, 1), isNull);
      expect(g.pour(1, 0), isNull);
      expect(g.moves, 0);
    });

    test('limited by capacity', () {
      final g = PourGame([
        [0, 0, 0],
        [1, 0, 0],
      ]);
      final m = g.pour(1, 0)!;
      expect(m.count, 1);
      expect(g.tubes[0], [0, 0, 0, 0]);
      expect(g.tubes[1], [1, 0]);
    });

    test('rejects same tube, empty source and full destination', () {
      final g = PourGame([
        [0, 0, 0, 0],
        [],
        [0],
      ]);
      expect(g.pour(0, 0), isNull);
      expect(g.pour(1, 2), isNull);
      expect(g.pour(2, 0), isNull);
      expect(g.pour(9, 0), isNull);
    });
  });

  group('win and undo', () {
    test('win detection', () {
      expect(
        isSolved([
          [0, 0, 0, 0],
          [],
          [1, 1, 1, 1],
        ]),
        isTrue,
      );
      expect(
        isSolved([
          [0, 0, 0],
          [0],
        ]),
        isFalse,
      );
      expect(
        isSolved([
          [0, 0, 0, 1],
          [],
        ]),
        isFalse,
      );
    });

    test('pouring the last pieces wins', () {
      final g = PourGame([
        [0, 0, 0],
        [0],
      ]);
      expect(g.isWon, isFalse);
      g.pour(1, 0);
      expect(g.isWon, isTrue);
    });

    test('undo restores state and move counter', () {
      final g = PourGame([
        [1, 0, 0],
        [0],
        [],
      ]);
      final before = [for (final t in g.tubes) List<int>.of(t)];
      g.pour(0, 1);
      g.pour(1, 2);
      expect(g.moves, 2);
      g.undo();
      g.undo();
      expect(g.moves, 0);
      expect(g.tubes, before);
      expect(g.undo(), isNull);
    });

    test('extra tube once per level and undo still works', () {
      final g = PourGame([
        [0, 1],
        [1, 0],
      ]);
      expect(g.addExtraTube(), isTrue);
      expect(g.addExtraTube(), isFalse);
      expect(g.tubes.length, 3);
      g.pour(0, 2);
      g.undo();
      expect(g.tubes[0], [0, 1]);
    });
  });

  group('generator', () {
    test('levels 1..30 are solvable, non-trivial and well-formed', () {
      for (var n = 1; n <= 30; n++) {
        final level = generateLevel(n);
        expect(level.colors, colorsForLevel(n));
        expect(level.tubes.length, level.colors + kEmptyTubes);
        final counts = <int, int>{};
        for (final t in level.tubes) {
          expect(t.length, lessThanOrEqualTo(kTubeCapacity));
          for (final c in t) {
            counts[c] = (counts[c] ?? 0) + 1;
          }
        }
        expect(counts.length, level.colors);
        expect(counts.values.every((v) => v == kTubeCapacity), isTrue);
        expect(isSolved(level.tubes), isFalse, reason: 'level $n');
        final solution = solve(level.tubes);
        expect(solution, isNotNull, reason: 'level $n unsolved');
        expect(
          solution!.length,
          greaterThanOrEqualTo(minSolutionLength(level.colors)),
          reason: 'level $n too easy',
        );
        // Replaying the solution on the real rules must win.
        final g = PourGame(level.tubes);
        for (final m in solution) {
          expect(g.pour(m.from, m.to), isNotNull);
        }
        expect(g.isWon, isTrue, reason: 'level $n');
      }
    });

    test('deterministic per level number and injectable Random', () {
      expect(generateLevel(7).tubes, generateLevel(7).tubes);
      expect(generateLevel(7).tubes, isNot(generateLevel(8).tubes));
      expect(
        generateLevel(5, random: Random(99)).tubes,
        generateLevel(5, random: Random(99)).tubes,
      );
    });

    test('difficulty ramps from 3 up to 10 colors', () {
      expect(colorsForLevel(1), 3);
      expect(colorsForLevel(100), 10);
    });
  });
}
