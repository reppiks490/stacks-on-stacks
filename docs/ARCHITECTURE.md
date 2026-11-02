# EVERBLOOM — Integration architecture and persistence contract (principal lane)

**Status:** Source implementation in progress. The current integration candidate is not accepted as native verified until exact-head Godot CI passes. Never infer a completed game from file counts or tests.

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

**Current known issue:** Original `game.gd` lacks a persisted year counter and domain modules use repeating day indices. The principal lane will add a year counter; village/animal lanes must switch their daily gating to `game.day_epoch()` after coordination.

## Contract B: persistence
Current `game.gd` writes `user://everbloom_save_v1.json` with `schema=1`. Retain compatibility for existing schema-1 saves. Required persisted fields: `year` (optional in pre-upgrade v1; default 1), `day`, `season`, `minute`, `gold`, `energy`, `weather`, `restoration`, `crops_harvested`, `social_contacts`, `care_actions`, `inventory`, `farm`, `village`, `animals`, `hero_position`. Domain save structures are delegated to their owners.

**Acceptance:** Save/load round trip across a seasonal rollover, no item duplication, no negative balances, corrupted/unknown-schema rejection, preservation of the current session on invalid saves, backup and migration fixtures. The first implementation has basic load/clamp, not all these guarantees. Never silently overwrite incompatible saves. Any future v2 must use an explicit migration and preserve a backup.

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
- Existing CI fails before native tests because `tools/validate_project.py` was missing.
- No independent gameplay tests for crop progression, inventory conservation or save recovery.
- Daily social/animal gating repeats annually without monotonic epoch.
- Unverified engine parsing and unknown mobile performance.
- Direct save writes are not crash-safe; add backup/atomic replacement after native test coverage.
- Scene's current meshes are graybox placeholders; visual quality is not yet production-level.
