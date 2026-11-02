# EVERBLOOM — Source-backed status ledger

**2026-11-02, principal architecture and persistence verification.** `main` and `game/everbloom-harvest-sim-rebuild-20261101` were fast-forwarded through reconciled merge `63370c98` and persistence commit `29a5c08328466ddda1dd76459f4758babe15a301`. The original SABLESTAR history and historical branches are preserved; no force-push or branch deletion was used.

## Verified at exact commit
- Godot 4.7.2 native editor import and GDScript parse passed.
- Godot 4.7.2 120-frame headless scene smoke passed.
- Native Godot schema-1 save roundtrip and corrupted-primary backup recovery passed at `29a5c083`.
- Offline source/data integrity validation and QA Python tests passed.
- Evidence: https://github.com/reppiks490/stacks-on-stacks/actions/runs/41397716313 and https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398131319
- Core source includes original procedural valley graybox, farmer controller, 30 farm beds, 8 crop definitions, 6 original villager records, 3 animal types, 4 recipes, 4 quest definitions, 5 regions, HUD, calendar, inventory/economy and local save/load. These are early implementations, not production-grade game content.
- `scripts/game.gd` now persists year, advances it after Winter Day 14 and exposes monotonic `day_epoch()`.
- QA's comprehensive source validator and adversarial regression tests were preserved in the merge. Principal-owned architecture and coordination documents were added.
- Original SVG and generated Godot primitives only. No copied proprietary Harvest Moon game assets.

## Unverified / blocked for release
- Annual daily-action bug persists in `scripts/village.gd` and `scripts/animals.gd` until they call `game.day_epoch()`.
- Schema-1 save validation, temp-file readback, previous-primary backup and corrupted-primary fallback passed a native Godot filesystem test at commit `29a5c083` ([run 41398131319](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398131319)). Power-loss crash consistency, file-lock behavior, save migration and full-state conservation remain unverified.
- The 120-frame smoke and targeted native save test do not exercise real keyboard interaction, harvest completion, animal production, multi-season progression, romance/family, quests, controller/mobile or visual quality.
- Current art is procedural placeholder geometry, not a finished, stunning world. Original soundtrack, animations, interiors, festivals, NPC schedules and deep relationships remain future work.
- No controller/mobile compatibility or performance budgets have been demonstrated on actual hardware.
- No Codex, PR auto-review, paid tools, unlicensed commercial assets or new releases were used.

**Next acceptance:** Village/animal epoch migration; engine-driven season/inventory/relationship conservation tests; Windows file-lock and power-loss persistence checks; authored art; reproducible controller/mobile tests; then deeper content and full game loops. Coordinate in https://github.com/reppiks490/stacks-on-stacks/issues/2.
