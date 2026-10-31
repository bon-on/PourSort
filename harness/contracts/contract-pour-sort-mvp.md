---
id: contract-pour-sort-mvp
title: Deliver the PourSort MVP
status: active
related_specs:
  - feature-pour-sort-mvp
  - feature-how-to-play-tutorial
evidence_files:
  - reports/pour-sort-mvp-verification.md
---

# Contract: PourSort MVP

## Goal
Ship a playable, deterministic, always-solvable color sort puzzle for web,
iOS and Android with no network dependency.

## Done Criteria
- Pour rules, win detection, undo, generator and solver have unit tests.
- A widget smoke test covers tap, undo, restart, extra tube, keyboard and
  viewport fit.
- Flutter analyze and tests pass, the web release build succeeds, and the
  harness audit has no critical findings.

## Verification
- flutter analyze
- flutter test
- flutter build web --release --base-href /PourSort/
- harness audit

## Evidence References
- reports/pour-sort-mvp-verification.md
