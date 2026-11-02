---
id: adr-pour-sort-solvable-levels
title: Generate levels by shuffling full tubes and verifying with a solver
status: accepted
related_specs:
  - feature-pour-sort-mvp
  - feature-retention-polish
---

# ADR: Generate levels by shuffling full tubes and verifying with a solver

## Context
Random puzzle fills are often unsolvable or trivial. Levels must be stable per
level number and testable without Flutter, on the VM and on the web.

## Decision
Every colored tube starts full: shuffle the multiset of `colors x 4` segments
with a seeded PRNG (seed = level number) and cut it into full tubes, plus 2
empty tubes. Accept a candidate only if no tube starts uniform-full, a
deterministic weighted best-first solver (bounded by `maxNodes`) solves it on
the real pour rules, and the solution has at least `colors + 3` moves.
Attempts are bounded; after 150 failed attempts the next deterministic
sub-seed is used, and as a last resort the best verified (or plain) candidate
is returned, so generation never throws. The PRNG is `SeededRandom`
(Park-Miller; products stay below 2^53) so sequences are identical in the Dart
VM and dart2js. Rules, solver and generator are pure Dart in `lib/logic/`.

## Consequences
- Every shipped level is verified solvable, stable across runs and platforms.
- Difficulty is tuned in `colorsForLevel` and `minSolutionLength`.
- Solver length is an upper bound on the optimum, so no "optimal moves" display.
- Restarting a level restores the extra-tube allowance (it is per attempt).
