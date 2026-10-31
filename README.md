# PourSort

A small color sort puzzle built with Flutter (web, iOS, Android). Pour colored
liquid between tubes until every tube holds a single color.

## How to play

- Tap (or click) a tube to select it, then tap another tube to pour.
- The top run of one color moves as far as the target has room. You can pour
  onto an empty tube or onto a tube whose top color matches.
- Each tube holds 4 segments. Win when every tube is empty or full of one color.
- Every color also has its own symbol, so the game is playable without
  telling hues apart.
- Buttons: Undo (unlimited), Restart, and add one extra empty tube per level.
- Keyboard: `1`-`9`, `0`, then `Q W E T Y I` select tubes (shown under each
  tube), `U` undo, `R` restart, `A` extra tube, `Enter`/`N` next level after
  winning. Undo is disabled after a win; restarting a level restores its extra
  tube.
- First launch shows a skippable "How to play" card; the `?` button reopens
  it (Enter/Space next, Esc skip, arrows to move between steps).
- Levels start with 3 colors and grow to 10. Level N is always the same level,
  and every level is verified solvable. Progress (current level) is saved
  locally.

## Run, test, build

```sh
flutter pub get
flutter run -d chrome          # or any device
flutter analyze
flutter test
flutter build web --release --base-href /PourSort/
```

## CrazyGames build

`tool/build_crazygames.sh` builds `build/pour-sort-crazygames.zip` for the CrazyGames portal (SDK gameplay events, no ads). See `docs/crazygames.md`.

## GamePix build

`tool/build_gamepix.sh` builds `build/pour-sort-gamepix.zip` for GamePix (no portal SDK, no ads, relative resources). See `docs/gamepix.md`.

## Fonts

Roboto (Regular, Medium, Bold, Black) is bundled in `assets/fonts/` so web builds never fetch it from fonts.gstatic.com. Roboto is licensed under Apache 2.0, see `assets/fonts/Roboto_LICENSE.txt`.

## Project layout

- `lib/logic/` - rules, solver, level generator, progress store (no widgets)
- `lib/ui/` - game screen, tube painter, confetti
- `test/` - unit tests and a widget smoke test
- `harness/` - specs, ADRs and contracts (spec-driven development)

## License

MIT, see `LICENSE`.
