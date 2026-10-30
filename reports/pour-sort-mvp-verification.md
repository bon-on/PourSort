# PourSort MVP verification

Spec: `harness/specs/feature-pour-sort-mvp.md`

## Checks
- `flutter analyze`: no issues.
- `flutter test`: 15 tests pass (`test/pour_game_test.dart`: pour rules, win,
  undo, extra tube, levels 1..30 solvable and replayable, determinism, ramp;
  `test/widget_test.dart`: tap/undo/restart/extra tube, keyboard, viewport fit
  at 390x844 and 1280x720 for levels 12 and 30).
- `flutter build web --release --base-href /PourSort/`: succeeds.
- Headless Chrome screenshots at 1280x720 and 390x844 inspected; no overflow.
- Harness audit: no critical findings.

## Not verified
- iOS and Android builds, and real touch input on devices.
- Pour animation timing was only checked by tests and by eye on code, not
  recorded.
