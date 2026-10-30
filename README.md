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
- Keyboard: `1`-`9`, `0` select tubes 1-10, `U` undo, `R` restart, `E` extra
  tube, `Enter`/`N` next level after winning.
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

## Project layout

- `lib/logic/` - rules, solver, level generator, progress store (no widgets)
- `lib/ui/` - game screen, tube painter, confetti
- `test/` - unit tests and a widget smoke test
- `harness/` - specs, ADRs and contracts (spec-driven development)

## License

MIT, see `LICENSE`.
