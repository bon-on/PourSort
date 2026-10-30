---
id: adr-pour-sort-solvable-levels
title: Generate levels by reverse scrambling and verify with a solver
status: accepted
related_specs:
  - feature-pour-sort-mvp
---

# ADR: Generate levels by reverse scrambling and verify with a solver

## Context
Random fills of a color sort puzzle are often unsolvable or trivial. Levels
must be stable per level number and testable without Flutter.

## Decision
Start from the solved state, apply random reverse unit moves with a seeded
`Random` (seed = level number), then run a deterministic weighted best-first
solver on the real pour rules. Keep the level only if the solver finds a
solution of at least `colors + 3` moves; otherwise retry with the same
`Random`. The solver length is an upper bound on the optimum, which is enough
for a too-easy filter. Game rules, solver and generator are pure Dart files in
`lib/logic/`; the UI only reads them through `GameController`.

## Consequences
- Every shipped level is solvable by construction and by verification.
- Levels never change between runs or devices.
- Difficulty is tuned in `colorsForLevel` and `minSolutionLength`.
- Solver results are not guaranteed minimal, so no "optimal moves" display.
