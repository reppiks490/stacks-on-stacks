# EVERBLOOM — Source-backed status ledger

**2026-11-02, principal architecture verification.** `main` and `game/everbloom-harvest-sim-rebuild-20261101` were fast-forwarded to reconciled merge commit `63370c98b852ca87b904aec8ba62a33ef01eecea`. The original SABLESTAR history and historical branches are preserved; no force-push or branch deletion was used.

## Verified at exact commit
- Godot 4.7.2 native editor import and GDScript parse passed.
- Godot 4.7.2 120-frame headless scene smoke passed.
- Offline source/data integrity validation and QA Python tests passed.
- Evidence: https://github.com/reppiks490/stacks-on-stacks/actions/runs/41397716313
- Core source includes original procedural valley graybox, farmer controller, 30 farm beds, 8 crop definitions, 6 original villager records, 3 animal types, 4 recipes, 4 quest definitions, 5 regions, HUD, calendar, inventory/economy and local save/load. These are early implementations, not production-grade game content.
- `scripts/game.gd` now persists year, advances it after Winter Day 14 and exposes monotonic `day_epoch()`.
- QA's comprehensive source validator and adversarial regression tests were preserved in the merge. Principal-owned architecture and coordination documents were added.
- Original SVG and generated Godot primitives only. No copied proprietary Harvest Moon game assets.

## Unverified / blocked for release
- Annual daily-action bug persists in `scripts/village.gd` and `scripts/animals.gd` until they call `game.day_epoch()`.
- Save writes still lack backup/atomic recovery and corrupt-save integration tests.
- The 120-frame smoke does not exercise real keyboard interaction, harvest completion, animal production, multi-season progression, romance/family, quests, controller/mobile or visual quality.
- Current art is procedural placeholder geometry, not a finished, stunning world. Original soundtrack, animations, interiors, festivals, NPC schedules and deep relationships remain future work.
- No controller/mobile compatibility or performance budgets have been demonstrated on actual hardware.
- No Codex, PR auto-review, paid tools, unlicensed commercial assets or new releases were used.

**Next acceptance:** Village/animal epoch migration; actual engine-driven season/save/inventory tests; crash-safe persistence; authored art; reproducible controller/mobile tests; then deeper content and full game loops. Coordinate in https://github.com/reppiks490/stacks-on-stacks/issues/2.
