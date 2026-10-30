# Constraints

- Default policy mode: warn on drift, block critical gaps.
- Every feature change needs a feature spec in `harness/specs/`.
- Architectural or cross-cutting decisions need an ADR in `harness/adrs/`.
- AI responses must cite the spec, ADRs, and rules they used.
- If the repo state contradicts the spec or ADR, escalate instead of guessing.

## Project Constraints

- Flutter app (web, iOS, Android). Keep dependencies minimal; only
  `shared_preferences` is allowed beyond the Flutter SDK without an ADR.
- No network access, ads SDKs, accounts or leaderboards in v1.
- Game rules, solver and level generator stay in `lib/logic/` with no Flutter
  imports and must have unit tests.
- Level generation is deterministic: level N uses seed N, and `Random` stays
  injectable for tests.
- Every color keeps a distinct symbol (colorblind support).
- Layouts must not overflow at 390x844 and 1280x720.
- Never commit secrets, personal paths or emails. Commits follow Conventional
  Commits.
- Pushing, creating remotes, and opening PRs or issues require explicit
  approval from the repo owner.
