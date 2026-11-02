# EVERBLOOM five-loop engineering coordination

**Integration:** `game/everbloom-harvest-sim-rebuild-20261101` (not `main`; `main` remains recoverable SABLESTAR). Each loop uses its own branch from the latest integration SHA, tests its changes and communicates through this document and GitHub issues. Do not concurrently update the same integration branch. Preserve branches and unique commits, no force-push.

| Lane | Primary ownership | Integration dependencies |
|---|---|---|
| Principal :00 | `scripts/game.gd`, `project.godot`, `docs/ARCHITECTURE.md`, `docs/MASTER_PLAN.md`, `docs/CROSS_LOOP_COORDINATION.md`, shared save/time contract | Domain `setup/act/next_day/save_state/load_state` signatures |
| Farming :12 | `scripts/farm.gd`, `data/crops.json`, soil/tools/economy, crop state | Clock, energy, inventory and weather from game |
| Village :24 | `scripts/village.gd`, `data/villagers.json`, festivals, relationships, NPC schedules | Monotonic `game.day_epoch()` and persisted relationship state |
| World Art :36 | `scripts/valley.gd`, original 3D/audio/visual assets, biome lighting, provenance | Camera and world setup contract; performance limits |
| QA :48 | `tools/validate_project.py`, `tests/**`, non-Codex CI, real native testing and release evidence | Exact SHA, source validation, logs and reproducibility |

**Integration alert 2026-11-02:** `cde73ab` already has substantive `scripts/game.gd`, `farm.gd`, `village.gd`, `animals.gd`, `valley.gd`, `farmer.gd`, `hud.gd`. Do not overwrite these with a parallel starter implementation. The first native CI failed before Godot due to missing `tools/validate_project.py`; principal has staged interim QA files in a separate branch to unblock the test gate. QA should adopt and strengthen them after merge.

**Critical shared bug:** day index currently repeats each year, causing once-per-day animal and village actions to be falsely blocked on later years. Principal adds `year` and `day_epoch()`; Village and Farming/Animal lanes must update uses of `game.season_index*14+game.day` to `game.day_epoch()` after the principal branch is integrated. Do not independently edit `game.gd`.

**Safe sequencing:** Read branch heads/workflows/issues → choose own files → commit on isolated branch → source/native CI → issue handoff with exact commit/run IDs → principal reconciliation → fast-forward merge only when gates pass. No PRs unless all auto-review triggers are audited and non-Codex. No unlicensed copyrighted assets, no fabricated native/mobile/perf results, no paid actions, no other repository edits.
