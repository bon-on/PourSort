import 'dart:math';

import 'pour_game.dart';
import 'solver.dart';

class Level {
  const Level({
    required this.number,
    required this.colors,
    required this.tubes,
    required this.solutionLength,
  });

  final int number;
  final int colors;

  /// Bottom-to-top colors for each tube.
  final List<List<int>> tubes;

  /// Length of the solution found by the solver (an upper bound on the minimum).
  final int solutionLength;
}

const int kMaxColors = 10;
const int kEmptyTubes = 2;

int colorsForLevel(int level) => min(kMaxColors, 3 + (level - 1) ~/ 3);

/// Minimum solver solution length for a level to count as non-trivial.
int minSolutionLength(int colors) => colors + 3;

/// Builds a solvable level. Level N uses seed N unless [random] is injected.
///
/// Starts from the solved state, applies random reverse moves, then verifies
/// with the solver and rejects levels that are unsolvable or too easy.
Level generateLevel(int number, {Random? random}) {
  final rng = random ?? Random(number);
  final colors = colorsForLevel(number);
  final tubeCount = colors + kEmptyTubes;
  final minLen = minSolutionLength(colors);
  Level? best;
  for (var attempt = 0; attempt < 300; attempt++) {
    final tubes = <List<int>>[
      for (var c = 0; c < colors; c++)
        List<int>.filled(kTubeCapacity, c, growable: true),
      for (var e = 0; e < kEmptyTubes; e++) <int>[],
    ];
    final steps = 40 + colors * 20;
    for (var s = 0; s < steps; s++) {
      final srcs = [
        for (var i = 0; i < tubeCount; i++)
          if (tubes[i].isNotEmpty) i,
      ];
      final src = srcs[rng.nextInt(srcs.length)];
      final dsts = [
        for (var i = 0; i < tubeCount; i++)
          if (i != src && tubes[i].length < kTubeCapacity) i,
      ];
      if (dsts.isEmpty) continue;
      final dst = dsts[rng.nextInt(dsts.length)];
      tubes[dst].add(tubes[src].removeLast());
    }
    if (isSolved(tubes)) continue;
    final solution = solve(tubes);
    if (solution == null) continue;
    final level = Level(
      number: number,
      colors: colors,
      tubes: tubes,
      solutionLength: solution.length,
    );
    if (best == null || level.solutionLength > best.solutionLength) {
      best = level;
    }
    if (solution.length >= minLen) return level;
  }
  return best!;
}
