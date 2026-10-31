---
id: feature-sound-effects
title: Sound effects with a mute toggle
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
  - adr-pour-sort-crazygames-web
related_contracts:
  - contract-pour-sort-mvp
  - contract-pour-sort-crazygames
required_evidence:
  - flutter-tests
  - flutter-analyze
  - web-build
  - portal-builds
  - harness-audit
---

# Feature: Sound effects with a mute toggle

## Problem
PourSort is silent. Players expect short feedback sounds on web (GitHub Pages,
CrazyGames, GamePix) and on iOS/Android, and a way to turn them off.

## Scope
- Four bundled sounds in `assets/audio/`, synthesized by the dependency-free
  `tool/generate_sounds.py` (deterministic): `select`, `pour`, `invalid`,
  `level_clear`. No third-party audio.
- `lib/audio/sound_fx.dart` (`SoundFx`, `Sfx`): `play` is a no-op while muted,
  never throws and never awaits. Web uses HTML `Audio` elements
  (`web_sound_web.dart`, conditional import with `web_sound_stub.dart`);
  mobile uses the `pour_sort/audio` MethodChannel (`play {asset, volume}`,
  `disposeAudio`): iOS AVAudioPlayer with the `.ambient` session category,
  Android MediaPlayer with USAGE_GAME. Missing plugins are swallowed.
- Hook points are in `GameScreen`, once per user tap or key press on a tube:
  a new selection plays `select`; a pour plays `pour`; a pour that clears the
  level plays `level_clear`; a tap that cannot select or pour (empty tube with
  nothing selected, or an invalid target that leaves nothing selected) plays
  `invalid`; deselecting, undo, restart, add tube and the tutorial are silent.
- Mute: user toggle persisted in `shared_preferences` key `sound_muted_v1`
  (default on). Effective mute = user mute OR `GamePlatform.isAudioMuted`
  (CrazyGames SDK `game.settings.muteAudio`, updated through
  `addSettingsChangeListener`; the game has no ads; no-op platform: false).
- A sound button (`Icons.volume_up_rounded` / `Icons.volume_off_rounded`,
  tooltip "Sound on"/"Sound off") sits next to the "?" button in the HUD, with
  the same style. Like "?" it is inside the focus-excluded subtree while the
  tutorial card is open, and after a press it refocuses the game so keys keep
  working. No new keyboard shortcut.

## Acceptance Criteria
- Each `Sfx` asset exists on disk and under the pubspec `assets/audio/` entry.
- No sound plays while muted by the user or by the platform; the toggle flips
  the icon and persists the choice; storage failure keeps sound on.
- Select, pour, invalid and level_clear fire at the hook points above, once per
  action.
- Existing tests, `flutter analyze`, web release build, portal build scripts
  and harness audit pass; lib/ stays ASCII.
- The generator produces identical files on two runs.

## Constraints
- No new dependency; audio is bundled (no external requests).
- English UI strings only.

## Evidence
- flutter test, flutter test --platform chrome test/web, flutter analyze
- python3 tool/generate_sounds.py twice with identical shasum
- flutter build web --release --base-href /PourSort/, tool/build_crazygames.sh,
  tool/build_gamepix.sh
- harness-lab audit
