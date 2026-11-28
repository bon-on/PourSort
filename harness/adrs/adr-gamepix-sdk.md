---
id: adr-gamepix-sdk
title: Integrate the GamePix SDK v3 in the GamePix build
status: accepted
related_specs:
  - feature-gamepix-sdk
  - feature-pour-sort-gamepix
---

# ADR: Integrate the GamePix SDK v3 in the GamePix build

## Context
The GamePix build was SDK-free by design (adr-pour-sort-gamepix-web). SDK-free games miss the portal's SDK exposure.

## Decision
- `GAMEPIX=true` web builds select `GamePixPlatform` (SDK v3, manual lifecycle). The SDK script is injected by `tool/build_gamepix.sh` before the Flutter bootstrap; it is the only external script allowed.
- Pause/resume and soundOff/soundOn mute audio; interstitials only on the win card when the player starts the next or replays a cleared level, with a 2 minute cooldown; preferences in one named localStorage item via `CloudPrefsStore`.
- This supersedes the "no SDK / no ads" part of adr-pour-sort-gamepix-web and feature-pour-sort-gamepix; its other rules (no outbound links, bundled Roboto, relative paths, GAMEPIX wins over CRAZYGAMES) stay.

## Alternatives
- Stay SDK-free: no work, but no SDK exposure.
- Legacy automatic lifecycle: less code, but load-time analytics are less accurate.
- Keep shared_preferences_web as is: GamePix sync would not restore progress, because the plugin enumerates keys.

## Consequences
- The GamePix bundle makes requests to integration.gamepix.com and shows GamePix ads.
- No real-time clock exists, so pause affects audio only; input is blocked while an ad runs.
- Existing players keep their progress: the first SDK session copies the enumerated local keys into the named item.
