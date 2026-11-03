# CrazyGames build

Building with `--dart-define=CRAZYGAMES=true` enables the CrazyGames HTML5 SDK v3
gameplay events. Builds without the flag (GitHub Pages, mobile) never touch the SDK.

## Build

```sh
tool/build_crazygames.sh
```

Output:

- `build/crazygames/`: bundle folder
- `build/pour-sort-crazygames.zip`: zip to upload

The script runs `flutter build web --release --base-href / --no-web-resources-cdn
--dart-define=CRAZYGAMES=true`, switches `<base href>` to `./`, inserts the SDK script
before `flutter_bootstrap.js`, removes `*.symbols` and checks the limits (at most 1500
files, 50MB) and the result. It fails loudly if any check fails.

## Tests

```sh
flutter test                              # game flow with a recording fake platform
flutter test --platform chrome test/web   # SDK adapter against a fake window.CrazyGames
```

## Local check

```sh
cd build && python3 -m http.server 8765
# open http://localhost:8765/crazygames/index.html
```

On `localhost` the SDK environment is `local`; the console logs
`Requesting gameplay start` style messages.

## SDK events

| When | Call |
|---|---|
| App start | `SDK.init()`; SDK disabled unless environment is `crazygames` or `local` |
| Playing (tutorial closed, level not cleared) | `gameplayStart()` |
| How-to-play, level select or theme overlay opens | `gameplayStop()` |
| Overlay closes | `gameplayStart()` |
| level cleared | `gameplayStop()` |
| Next level / restart after clear | `gameplayStart()` |

Only transitions are reported. On first launch the first start comes after the tutorial
closes.

Audio: `game.settings.muteAudio` and `addSettingsChangeListener` mute effects and the
background music at once (the music also waits for the first user input and pauses while
the tab is hidden).

## Disabled in the CrazyGames build

Nothing needs disabling: the game has no ads, no leaderboard or result upload and no
hub navigation bar, and `index.html` contains no outbound links.

## Progress save

Progress is saved through the SDK Data module (`feature-crazygames-cloud-save`). On the portal submission screen, **Progress Save** must be set to "Yes, using the Data Module from the CrazyGames SDK"; otherwise the Data module is disabled and progress stays in browser localStorage only.

- All preferences live in one Data module key, `prefs_v1`, as `{rev, owner, values}`, and are mirrored to localStorage. The localStorage item `cg_prefs_stamp_v1` records the mirror's owner (username, null for guests) and revision.
- On start, a local mirror of the same player with an equal or higher revision wins; otherwise the account copy is used. Another player's mirror is never used. Progress from before this feature is adopted only while no account copy exists.
- A login or logout (`user.addAuthListener`) to a different player reloads the page. If the initial user cannot be determined, cloud save stays off.

## Upload checklist

- [ ] Submit through Basic Launch first (ads are not allowed there).
- [ ] Progress Save: choose "Yes, using the Data Module from the CrazyGames SDK" (see Progress save).
- [ ] Orientation: portrait and landscape both work; the board fits any size.
- [ ] Input: mouse/touch and keyboard (see README).
- [ ] Covers (not created yet): 1920x1080, 800x1200, 800x800.
- [ ] Check loading and gameplay events in the portal QA tool.
