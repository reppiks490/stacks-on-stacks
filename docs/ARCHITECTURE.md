# EVERBLOOM — Integration architecture and persistence contract (principal lane)

**Status:** Active original game development. Canonical `main` at the start of this principal change was `bfd389a`, with [general native CI](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398474611) and [56-day farming native acceptance](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398474589) passing. The isolated principal save-integrity branch received its first [19-assertion native Godot PASS](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41399615671) at `8b4cea2`; it remains independent until exact final SHA gates pass. No completed-game, mobile, visual-quality or crash-durability claim is established.

## Runtime topology (observed from current integration branch)
```
scenes/main.tscn
  └─ scripts/game.gd — session coordinator, input, calendar, economy, save/load
      ├─ scripts/valley.gd — procedural valley, paths, lake, forest, foraging/fishing
      ├─ scripts/farm.gd — 30 planting beds, crop interactions, watering/growth
      ├─ scripts/village.gd — original residents, talk/gifts, affection
      ├─ scripts/animals.gd — barn animals, feeding/care and products
      ├─ scripts/farmer.gd — CharacterBody3D controller
      └─ scripts/hud.gd — readable on-screen status and controls
data/{world,crops,villagers,animals,recipes,quests}.json
assets/provenance.json and original SVG
```
These are actual tracked source components, not proof of full gameplay, polish or native correctness.

## Contract A: deterministic calendar
Game orchestrator is the sole calendar authority: `year >= 1`, `season_index = 0..3`, `day = 1..14`, `minute_of_day`, `weather`. 4 seasons × 14 days = 56 days/year. A monotonic `day_epoch() = (year-1)*56 + season_index*14 + day` is required for once-per-day talk, gift, animal care and festival triggers. Using `season_index*14+day` alone repeats epochs every year and incorrectly blocks annual interactions. All domain modules must accept calendar snapshots, not mutate global date. Weather must be reproducible for a given calendar and save state.

**Current state:** `game.gd` persists `year`, increments at Winter rollover and exposes `day_epoch()`. `farm.gd` and `animals.gd` now consume that monotonic epoch; the native Farming acceptance exercises the year-two animal-care case. **Village correction:** separate Village commit `df15d515` changed talk/gift admission to `game.day_epoch()` and added two-year native regression coverage. Its native test and canonical integration result must be confirmed at the new HEAD before marking that gate closed.

## Contract B: persistence
Current `game.gd` writes `user://everbloom_save_v1.json` with `schema=1`. Retain compatibility for existing schema-1 saves. Required persisted fields: `year` (optional in pre-upgrade v1; default 1), `day`, `season`, `minute`, `gold`, `energy`, `weather`, `restoration`, `crops_harvested`, `social_contacts`, `care_actions`, `inventory`, `farm`, `village`, `animals`, `hero_position`. Domain save structures are delegated to their owners.

**Acceptance:** Save/load round trip across a seasonal rollover, no item duplication, no negative balances, corrupted/unknown-schema rejection, preservation of the current session on invalid saves, backup and migration fixtures. Integrated `scripts/save_service.gd` adds schema-1 validation, temporary-file readback, previous-primary backup and backup fallback. **Native Godot filesystem roundtrip and deliberately corrupted-primary recovery passed** at `29a5c083` ([run 41398131319](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398131319)). Power-loss crash consistency, file-lock behavior, data-conservation and save migration are still unverified. Future v2 requires explicit migration and preserved backups. No silent overwrite of corrupt primary data. The isolated principal save-integrity branch adds finite-number checks, integer-precision conservation (up to JSON's exact 2^53−1 boundary), disallows negative/fractional inventory or gold, rejects malformed farm and livestock shapes, validates year/season/day/coordinates and rejects nested non-JSON state. A separate native Godot test executes 19 adversarial assertions; existing valid/legacy schema-1 layouts remain supported.

## Contract C: domain ownership and integration
- **Principal:** `scripts/game.gd`, `project.godot`, architecture, shared API contracts, time/save orchestration, merge decisions.
- **Farming:** `scripts/farm.gd`, `data/crops.json`, crops/economy/soil/tool upgrades. Public methods: `setup(host)`, `act(tool, world_position) -> String`, `next_day(weather)`, `save_state() -> Array`, `load_state(Array)`.
- **Village:** `scripts/village.gd`, `data/villagers.json`, `act(action, world_position)`, `next_day()`, `save_state() -> Dictionary`, `load_state(Dictionary)`. Must use monotonic day epoch.
- **Animals:** `scripts/animals.gd`, `data/animals.json`, `act(world_position)`, `next_day()`, `save_state() -> Dictionary`, `load_state(Dictionary)`. Must use monotonic day epoch.
- **Art/world:** `scripts/valley.gd`, original world assets, `setup(host)`, `act(action, world_position)`. Must support future world-streaming without breaking save schema.
- **QA:** `tools/validate_project.py`, `tests/**`, non-Codex CI, native Godot smoke and regression evidence. Principal supplied an interim validator to unblock broken CI; QA takes ownership and expands it.

All domain actions return user-facing messages now; migrate to typed action result contracts (`success`, `reason`, `inventory_delta`, `energy_delta`, `event_id`) when tested. Cross-domain effects should be emitted once, with transaction IDs to prevent duplicated grants on reload.

## Contract D: simulation & accessibility
Target 60 FPS on desktop and measured 30/60 FPS mobile modes; these are goals, not measured facts. Camera follow and keyboard movement are implemented in source. Controller/touch remapping, scalable UI, accessibility, character animation, interior scenes, asset streaming, LOD, localization, robust input and perf profiling remain unverified. No copyrighted game assets or extracted commercial models/audio may be redistributed.

## Non-Codex acceptance gates
1. Review exact branch HEAD, workflow triggers and external integrations before PRs; **no Codex CLI/agents/bots/reviews**.
2. Offline validator + unit tests pass.
3. Exact SHA Godot 4.7.2 `--headless --editor --import --quit` succeeds with no script/resource errors.
4. Same SHA `--headless --quit-after 120` succeeds with no runtime errors.
5. QA records artifact logs and checks real input/save/season/animal/villager behavior; 120 frames alone cannot prove interactions.
6. Provenance/licensing audit; original assets or rights-verified external resources only.
7. Integrate isolated branch non-destructively only after checks; never force-push/delete history.

## Open technical risks
- Prior CI failed before native tests because `tools/validate_project.py` was missing. QA supplied a stronger validator and tests; this blocker is **resolved** at merge commit `63370c98`.
- No independent gameplay tests for crop progression, inventory conservation or save recovery.
- Village and animal care both use monotonic epoch after Village commit `df15d515`; verify the Village native workflow at its exact commit and again after cross-lane integration.
- Native engine import and headless smoke have passed at the cited commits; comprehensive input/gameplay/device behavior and mobile performance remain unverified.
- Primary saves now use validated temp writes and backup fallback, with a native recovery test. Power-loss atomicity, Windows file locks, migration fixtures and long-running save integrity remain unverified.
- Scene's current meshes are graybox placeholders; visual quality is not yet production-level.

## Preservation and negative-save acceptance contract (2026-11-02)

The serializer must reject malformed or non-finite JSON state *before* either overwriting a save or mutating the active player session. For integer-valued economy counters (gold, inventory quantities, year and daily indices), a non-integral float must not be silently truncated. Integers above 2^53−1 may be rounded by JSON number handling and are rejected rather than misreported as exact. Pre-year schema-1 saves remain readable (`year` defaults to 1). Numeric positions must be finite and within a conservative world-coordinate safety bound; do not reinterpret arbitrary strings/objects as player positions.

**Evidence separation:** [principal-native acceptance at `8b4cea2`](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41399615671) proves 19 negative/legacy schema tests in real Godot. Existing [filesystem save test](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398474611) proves two writes/backup and corrupted-primary fallback. Neither proves Windows locking, interrupted rename, power-loss durability, or preservation of full domain state after a hostile nested save. QA must add fault-injection and full-state fixtures before release.

**Pending expanded check:** the same principal branch now includes five additional hostile nested-state cases (24 total) covering malformed village contact maps, fractional soil age, animal health/epoch and social flags; this expansion must pass at final source SHA before integration.
