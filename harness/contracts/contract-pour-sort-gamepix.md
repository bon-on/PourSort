---
id: contract-pour-sort-gamepix
title: Deliver the PourSort GamePix web bundle
status: active
related_specs:
  - feature-pour-sort-gamepix
  - feature-gamepix-sdk
evidence_files:
  - docs/gamepix.md
  - reports/pour-sort-gamepix-verification.md
---

# Contract: PourSort GamePix web bundle

## Goal
Produce an upload-ready GamePix bundle (GamePix SDK v3 only, relative resources; see feature-gamepix-sdk) from the
same Flutter codebase without changing gameplay.

## Done Criteria
- `flutter analyze` and `flutter test` pass.
- `tool/build_gamepix.sh` succeeds and writes `build/pour-sort-gamepix.zip` with
  index.html at the zip root.
- The GamePix `main.dart.js` has no `crazygames` string, the CrazyGames
  `main.dart.js` has no `GamePix` string, `index.html` loads only the GamePix
  SDK before `flutter_bootstrap.js`, and `FontManifest.json` lists Roboto.
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
