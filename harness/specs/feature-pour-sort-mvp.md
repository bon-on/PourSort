---
id: feature-pour-sort-mvp
title: PourSort color sort puzzle MVP
status: active
owner: games
related_adrs:
  - adr-pour-sort-solvable-levels
related_contracts:
  - contract-pour-sort-mvp
required_evidence:
  - flutter-tests
  - harness-audit
---

# Feature: PourSort color sort puzzle MVP

## Problem
There is no PourSort game yet. We need a small, dependency-light color sort
puzzle that runs on phone portrait and desktop landscape, whose levels are
always solvable and stable between sessions.

## Scope
- Tubes hold up to 4 colored segments. Tap a tube to select it, tap another to
  pour the contiguous top run of one color, as far as capacity allows, onto an
  empty tube or a tube with the same top color.
- Win when every tube is empty or holds 4 segments of a single color.
- Level N is generated from seed N: colors ramp from 3 up to 10, plus 2 empty
  tubes. Generation uses random reverse moves from the solved state, then a
  solver verifies solvability and rejects levels that are too easy.
- HUD: level, moves, undo (unlimited), restart, and one extra empty tube per
  level. The current level is saved locally (shared_preferences).
- Pour animation (lift, tilt, fill), confetti on win, and a distinct symbol on
  every color for colorblind players.
- Input: tap or click; keyboard 1-9/0 select tubes, U undo, R restart, E extra
  tube, Enter/N next level after a win.
- Game rules, solver and generator live in widget-free files under `lib/logic/`.

## Acceptance Criteria
- Pours are rejected onto a different top color, a full tube, the same tube or
  from an empty tube; a pour moves min(top run, free space) segments.
- Levels 1..30 are solvable by the solver, replaying the solution on the real
  rules wins, and each has at least `colors + 3` solution moves.
- `generateLevel(n)` returns identical tubes on every call; an injected
  `Random` is honored.
- Undo restores tubes and the move counter; the extra tube works once per level.
- Tubes stay inside the viewport at 390x844 and 1280x720 for levels 12 and 30.
- Flutter analyze, flutter tests, web release build and harness audit pass.

## Constraints
- No network, ads, accounts or leaderboard in v1.
- Only `shared_preferences` beyond the Flutter SDK.

## Evidence
- flutter test
- flutter analyze
- flutter build web --release --base-href /PourSort/
- harness audit
- reports/pour-sort-mvp-verification.md
