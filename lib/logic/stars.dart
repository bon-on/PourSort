/// Star rating per level. Pure Dart, no Flutter imports.
library;

import 'level_generator.dart';

const int kMaxStars = 3;

/// Par for a level: the solver's solution length (an upper bound on the
/// optimum, so it is shown as "Par", never as "optimal"). Unverified fallback
/// levels (solutionLength -1) use `colors * 3`.
int parForLevel(Level level) => parFor(level.solutionLength, level.colors);

int parFor(int solutionLength, int colors) =>
    solutionLength > 0 ? solutionLength : colors * 3;

/// Extra moves over par that still earn two stars: ceil(par * 0.3), at
/// least 3.
int twoStarSlack(int par) {
  final slack = (par * 3 + 9) ~/ 10;
  return slack < 3 ? 3 : slack;
}

/// Stars for finishing with [moves]: 3 at or under par, 2 within
/// [twoStarSlack] of par, else 1. Using the extra tube caps the rating at 2.
int starsForMoves(int moves, int par, {bool usedExtraTube = false}) {
  var stars = moves <= par
      ? 3
      : moves <= par + twoStarSlack(par)
      ? 2
      : 1;
  if (usedExtraTube && stars > 2) stars = 2;
  return stars;
}
