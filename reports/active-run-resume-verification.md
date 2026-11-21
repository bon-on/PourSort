# Active run resume verification — 2026-11-22

Base commit: `3732405` plus the active-run-resume working tree committed with this report.

| Check | Command | Result |
|---|---|---|
| Analyze | `flutter analyze` | exit 0, no issues |
| Tests | `flutter test` | exit 0, 105 passed |
| Pages build | `flutter build web --release --base-href /PourSort/` | exit 0, no CrazyGames SDK in `index.html` |
| CrazyGames build | `bash tool/build_crazygames.sh` | exit 0; `build/pour-sort-crazygames.zip` 12.4 MB |
| GamePix build | `bash tool/build_gamepix.sh` | exit 0; `build/pour-sort-gamepix.zip` 12.4 MB |
| Harness audit | `node <harness-lab>/dist/index.js audit . --format md` | exit 0, Critical 0, warnings 1 |
| Independent review | code-reviewer | approve with comments, no Critical/High |

Review follow-ups: the evidence path now points here; the lifecycle pause shipped with this change is described in `feature-pour-sort-crazygames.md`.

Not verified: real portal QA (iframe focus, cloud save on a signed-in account) and native devices.
