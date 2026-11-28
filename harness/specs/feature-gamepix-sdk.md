---
id: feature-gamepix-sdk
title: PourSort GamePix SDK v3 integration
status: active
owner: games
related_adrs:
  - adr-gamepix-sdk
related_contracts:
  - contract-pour-sort-gamepix
required_evidence:
  - flutter-tests
  - flutter-web-tests
  - flutter-analyze
  - gamepix-web-build
---

# Feature Spec: PourSort GamePix SDK v3 integration

## Problem
The SDK-free GamePix package misses the extra exposure that SDK games get on the portal. The SDK v3 guide (my.gamepix.com/sdk/doc) asks for pause/resume handlers that mute audio, manual lifecycle signals, ads only at natural breaks and localStorage read by known key names.

## Scope
- GamePix web build (`--dart-define=GAMEPIX=true`) only: `GamePixPlatform` adapter, `GamePlatform.showsRunBreakAds`/`showRunBreakAd`, the break-ad wiring in `lib/ui/game_screen.dart` and `tool/build_gamepix.sh`.
- Out of scope: gameplay and level generation, CrazyGames/Pages/mobile behaviour, rewarded ads, login, `happyMoment`/`sadMoment`, loading percentages.
- PourSort has no real-time clock or timer: gameplay only changes on player taps, so pause only mutes audio and no `setPauseListener` is needed. Input is blocked while an ad runs.

## Ad break points
An interstitial may play only on the win card of a cleared level, when the player presses:
- Next (button, or Enter / N / Esc): starts the next level after the ad.
- Replay (button, or R): replays the cleared level after the ad.

Never shown: while a level is played, on Restart / Undo / Add tube, on level or theme picking (Levels on the win card and the picker are not breaks), on app start or on the tutorial. After the ad the state is rechecked: the action runs only if the same level is still cleared.

## Acceptance Criteria
- S1: The GamePix `index.html` sets `window.GamePixConfig = { lifecycle: 'manual' }` and loads `https://integration.gamepix.com/sdk/v3/gamepix.sdk.js` exactly once, both before the Flutter bootstrap. Only the local `flutter_bootstrap.js` is loaded besides it; no other external script, link or URL; the build script fails otherwise.
- S2: The adapter registers `pause` and `resume`. Pause mutes all game audio (`isAudioMuted`, sound effects and music), resume restores it; the Player's `soundOff`/`soundOn` do the same; repeated events change nothing.
- S3: `lifecycle.loaded()` is sent once after the first Flutter frame; `lifecycle.gameStart()` is sent when gameplay starts, after `loaded()`. A Player that never answers does not block the game (10 s timeout).
- S4: Interstitials (`ads.interstitial()`) play only at the break points above, never mid-level, at least 2 minutes after the previous ad (the first break may show one; the Player caps ads at one every 3 minutes), and never twice at once. Input and double taps are blocked while the ad runs. A failed, unfilled or hung ad (120 s) still starts the next level.
- S5: Preferences are kept in one localStorage item read with `getItem` by name (`poursort.prefs_v1`), so GamePix storage sync restores progress. Progress saved before the SDK (enumerated `flutter.` keys) is kept on the first SDK session, and those keys are never cleared.
- S6: Without the SDK (blocked script, direct page) the adapter behaves like the no-op platform: no ads.
- S7: The CrazyGames and Pages bundles contain no GamePix adapter code, and the GamePix bundle no CrazyGames code.

## Constraints
- GamePix rules: no other third-party SDK, no external links, no timer-triggered ads, the game pauses and mutes during ads.
- A broken SDK must never keep the game from starting or continuing.
- `createGamePlatform` keeps the constant ternary on the compile-time flags; calling a helper with the flags as arguments stops dart2js from tree-shaking the unused adapter.

## Stack Notes
- `lib/platform/gamepix_platform.dart` reuses `CloudPrefsStore` with the prefixed localStorage item as the "cloud", an in-memory mirror seeded from the old keys and no local stamp, so the named item is always the source.
- shared_preferences_web lists keys with `localStorage.key(i)`, which GamePix sync does not see; that is why the named item is needed.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`.
- `tool/build_gamepix.sh` and `tool/build_crazygames.sh` succeed; `GamePix` strings only in the GamePix `main.dart.js`.
