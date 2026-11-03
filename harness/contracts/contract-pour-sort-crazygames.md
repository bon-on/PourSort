---
id: contract-pour-sort-crazygames
title: Deliver the PourSort CrazyGames web bundle
status: active
related_specs:
  - feature-pour-sort-crazygames
  - feature-sound-effects
  - feature-retention-polish
  - feature-crazygames-cloud-save
evidence_files:
  - docs/crazygames.md
  - reports/pour-sort-crazygames-verification.md
---

# Contract: PourSort CrazyGames web bundle

## Goal
Produce an upload-ready CrazyGames bundle from the same Flutter codebase,
without changing the Pages or mobile builds.

## Done Criteria
- `flutter analyze` and `flutter test` pass.
- `tool/build_crazygames.sh` succeeds and writes `build/pour-sort-crazygames.zip`.
- The Pages build output contains no CrazyGames SDK script.
- Results are recorded in `reports/pour-sort-crazygames-verification.md`.

## Verification
- flutter analyze
- flutter test
- flutter test --platform chrome test/web
- tool/build_crazygames.sh
- flutter build web --release --base-href /PourSort/
- harness audit

## Evidence References
- docs/crazygames.md
- reports/pour-sort-crazygames-verification.md
