---
id: contract-pour-sort-gamepix
title: Deliver the PourSort GamePix web bundle
status: active
related_specs:
  - feature-pour-sort-gamepix
evidence_files:
  - docs/gamepix.md
  - reports/pour-sort-gamepix-verification.md
---

# Contract: PourSort GamePix web bundle

## Goal
Produce an upload-ready GamePix bundle (SDK-free, relative resources) from the
same Flutter codebase without changing gameplay.

## Done Criteria
- `flutter analyze` and `flutter test` pass.
- `tool/build_gamepix.sh` succeeds and writes `build/pour-sort-gamepix.zip` with
  index.html at the zip root.
- The GamePix `main.dart.js` has no `crazygames` string and `FontManifest.json`
  lists Roboto.
- Results are recorded in `reports/pour-sort-gamepix-verification.md`.

## Verification
- flutter analyze
- flutter test
- flutter test --platform chrome test/web
- tool/build_gamepix.sh
- tool/build_crazygames.sh
- harness audit

## Evidence References
- docs/gamepix.md
- reports/pour-sort-gamepix-verification.md
