# GamePix build

Building with `--dart-define=GAMEPIX=true` produces a GamePix bundle that loads the
GamePix SDK v3 (manual lifecycle, feature-gamepix-sdk) and no other third-party
script: no hub link, no leaderboard or result upload, no other external requests
(Roboto is bundled in `assets/fonts/`). GamePix interstitials play only on the win
card when the player presses Next or Replay, at least 2 minutes apart (the Player
caps them at one every 3 minutes); never mid-level.

## Build

```sh
tool/build_gamepix.sh
```

Output:

- `build/gamepix/`: bundle folder
- `build/pour-sort-gamepix.zip`: zip to upload (files at the zip root, `index.html` first level)

The script runs `flutter build web --release --base-href / --no-web-resources-cdn
--dart-define=GAMEPIX=true`, switches `<base href>` to `./`, drops the template
comment with an external URL, injects `window.GamePixConfig = { lifecycle: 'manual' }`
and the SDK script (exactly once, in that order, before `flutter_bootstrap.js`),
removes `*.symbols` and checks: relative base, no `crazygames`/`bon-on.github.io`,
no script other than the SDK and `flutter_bootstrap.js`, no other external
`src`/`href` in `index.html`, viewport `user-scalable=no`, Roboto in
`FontManifest.json`, `index.html` at the zip root and no `crazygames` string in
`main.dart.js`. It prints file count and size.

## Upload notes

| Item | Value |
|---|---|
| Zip | `build/pour-sort-gamepix.zip` |
| Icon | 256x256 (not created yet) |
| Cover | 1360x850 (not created yet) |
| Orientation | portrait and landscape; the layout fits any iframe size |
| Desktop / Mobile friendly | both (mouse, touch and keyboard) |
| SDK integration | yes (GamePix SDK v3, interstitial ads, pause/resume, localStorage sync) |
| Language | English |

## Saved progress

Progress is saved through `shared_preferences`, which the GamePix build keeps in one
named localStorage item (`poursort.prefs_v1`). GamePix syncs localStorage items read
with `getItem` by name, and `shared_preferences_web` only enumerates keys, so the
adapter swaps in `CloudPrefsStore` backed by that item. Progress saved before the SDK
(`flutter.` keys) is copied in on the first session.

## Platform flags

`GAMEPIX=true` selects `GamePixPlatform` (`allowsResultRegistration` is false,
`showsRunBreakAds` is true once the SDK is found). It wins over `CRAZYGAMES=true`; the
CrazyGames adapter is only used when `CRAZYGAMES=true` and `GAMEPIX` is not set.
Without the SDK (blocked script) the adapter behaves like the no-op platform.
`tool/build_crazygames.sh` fails if `GamePix` appears in its `main.dart.js`.

## Tests

```sh
flutter test
flutter test --platform chrome test/web
flutter test --platform chrome test/web --dart-define=GAMEPIX=true --dart-define=CRAZYGAMES=true
```

## Verification notes

- `grep -ci crazygames build/gamepix/main.dart.js` and `grep -c GamePix build/crazygames/main.dart.js` should print 0.
- `main.dart.js` still contains the engine's default `https://fonts.gstatic.com/s/`
  constant. The app does not request Roboto from there because Roboto is bundled.
- Roboto comes from the Flutter SDK cache (`material_fonts/`); its license is
  `assets/fonts/Roboto_LICENSE.txt` (Apache 2.0).
- Glyphs missing from Roboto make the engine fetch a fallback font from
  fonts.gstatic.com. Keep UI text to characters Roboto covers and avoid U+00B7.
- Local check: `cd build && python3 -m http.server 8765`, then open
  `http://localhost:8765/gamepix/`. Test 640x480 and 360x640 iframes.
