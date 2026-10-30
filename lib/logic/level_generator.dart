import 'dart:math';

import 'pour_game.dart';
import 'solver.dart';

/// Small deterministic PRNG (Park-Miller). All products stay below 2^53, so the
/// sequence is identical on the Dart VM and in dart2js.
class SeededRandom implements Random {
  SeededRandom(int seed) : _state = (seed.abs() % 2147483646) + 1 {
    for (var i = 0; i < 4; i++) {
      _next();
    }
  }

  int _state;

  int _next() => _state = (_state * 48271) % 2147483647;

  @override
  int nextInt(int max) {
    if (max <= 0 || max > 0x7fffffff) {
      throw RangeError.range(max, 1, 0x7fffffff, 'max');
    }
    return _next() % max;
  }

  @override
  double nextDouble() => (_next() - 1) / 2147483646;

  @override
  bool nextBool() => _next().isEven;
}

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

  /// Length of the solution found by the solver (an upper bound on the
  /// minimum), or -1 if the fallback level could not be verified.
  final int solutionLength;
}

const int kMaxColors = 10;
const int kEmptyTubes = 2;
const int _attemptsPerSeed = 150;
const int _maxSubSeeds = 6;

int colorsForLevel(int level) => min(kMaxColors, 3 + (level - 1) ~/ 3);

/// Minimum solver solution length for a level to count as non-trivial.
int minSolutionLength(int colors) => colors + 3;

List<List<int>> _randomFill(int colors, Random rng) {
  final units = [
    for (var c = 0; c < colors; c++)
      for (var k = 0; k < kTubeCapacity; k++) c,
  ];
  for (var i = units.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final t = units[i];
    units[i] = units[j];
    units[j] = t;
  }
  return [
    for (var t = 0; t < colors; t++)
      units.sublist(t * kTubeCapacity, (t + 1) * kTubeCapacity),
    for (var e = 0; e < kEmptyTubes; e++) <int>[],
  ];
}

bool _hasUniformFullTube(List<List<int>> tubes) {
  for (final t in tubes) {
    if (t.length == kTubeCapacity && t.every((c) => c == t.first)) return true;
  }
  return false;
}

/// Builds a solvable level. Level N uses seed N unless [random] is injected.
///
/// Every colored tube starts full (a shuffle of the color multiset) plus
/// [kEmptyTubes] empty tubes. A candidate is accepted only if no tube starts
/// uniform, the solver solves it, and the solution is long enough. Attempts are
/// bounded; after [_attemptsPerSeed] tries the next deterministic sub-seed is
/// used, and as a last resort the best verified (or plain) candidate is returned.
Level generateLevel(int number, {Random? random}) {
  final colors = colorsForLevel(number);
  final minLen = minSolutionLength(colors);
  Level? best;
  List<List<int>>? lastFill;
  for (var sub = 0; sub < _maxSubSeeds; sub++) {
    final rng = random ?? SeededRandom(sub == 0 ? number : number * 7919 + sub);
    for (var attempt = 0; attempt < _attemptsPerSeed; attempt++) {
      final tubes = _randomFill(colors, rng);
      lastFill = tubes;
      if (_hasUniformFullTube(tubes)) continue;
      final solution = solve(tubes);
      if (solution == null) continue;
      final level = Level(
        number: number,
        colors: colors,
        tubes: tubes,
        solutionLength: solution.length,
      );
      if (solution.length >= minLen) return level;
      if (best == null || level.solutionLength > best.solutionLength) {
        best = level;
      }
    }
  }
  return best ??
      Level(
        number: number,
        colors: colors,
        tubes: lastFill ?? _randomFill(colors, SeededRandom(number)),
        solutionLength: -1,
      );
}
