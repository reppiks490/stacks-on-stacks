# EVERBLOOM — Source-backed status ledger

**2026-11-02, cross-lane architecture, farming, village and persistence verification.** `main` and `game/everbloom-harvest-sim-rebuild-20261101` were fast-forwarded through reconciled merge `63370c98` and persistence commit `29a5c08328466ddda1dd76459f4758babe15a301`. The original SABLESTAR history and historical branches are preserved; no force-push or branch deletion was used.

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
- Annual daily-action collision has now been repaired in `scripts/animals.gd` (farming merge `bfd389a`) and `scripts/village.gd` (Village commit `df15d515`). Both have individual native acceptance evidence; combined integration must still be tested.
- Schema-1 save validation, temp-file readback, previous-primary backup and corrupted-primary fallback passed a native Godot filesystem test at commit `29a5c083` ([run 41398131319](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398131319)). Power-loss crash consistency, file-lock behavior, save migration and full-state conservation remain unverified.
- The 120-frame smoke and targeted native save test do not exercise real keyboard interaction, harvest completion, animal production, multi-season progression, romance/family, quests, controller/mobile or visual quality.
- Current art is procedural placeholder geometry, not a finished, stunning world. Original soundtrack, animations, interiors, festivals, NPC schedules and deep relationships remain future work.
- No controller/mobile compatibility or performance budgets have been demonstrated on actual hardware.
- No Codex, PR auto-review, paid tools, unlicensed commercial assets or new releases were used.

**Next acceptance:** Village/animal epoch migration; engine-driven season/inventory/relationship conservation tests; Windows file-lock and power-loss persistence checks; authored art; reproducible controller/mobile tests; then deeper content and full game loops. Coordinate in https://github.com/reppiks490/stacks-on-stacks/issues/2.

## Principal save-integrity candidate (isolated branch)

`game/everbloom-principal-save-integrity-20261102` adds stricter schema-1 finite-number, inventory/gold precision, annual date, domain snapshot and hero-coordinate boundaries; a dedicated Godot-native negative-case suite and non-Codex workflow; and updated coordination docs. Initial [19-assertion native acceptance at 8b4cea2](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41399615671) passed. The runner has subsequently expanded to 24 assertions and must be reverified at the final branch SHA; integration into `main` must not be assumed until merged and main exact-head CI passes.

Independent Village [native two-year acceptance at df15d515](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41399543271) and [general source validation](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41399543272) passed. Independent farming native acceptance passed at `bfd389a` ([run](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398474589)). None of these is evidence of finished visual art, mobile performance, completed family gameplay, packaging or full release readiness.


## Critical integration follow-up — full-game saves

Main `ddb081d8` accepted exact-head [native principal](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41400381188) and [general import/smoke](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41400381323), but a manual cross-system source audit found a genuine save schema mismatch: Farming ecology serializes `animals.__paddocks__` as an Array and Principal's older validator refused it. The preceding 24 synthetic assertions did not capture a full assembled save. This is an integration defect, **not** proof of safe full gameplay saving.

The isolated `game/everbloom-principal-live-save-job-20261102` candidate now accepts validated grazing arrays and the expanded Village memory schema; it adds an actual Game-coordinator save/reload test and wires keyboard `K` to existing paid work. These changes are **unverified at final SHA** until native CI passes and the branch is merged non-destructively. No real player saves, mobile devices, published binaries or commercial game assets were accessed.

## Canonical accepted state — 2026-11-02, after real assembled-save regression

**Current integration SHA:** `91eded29b6208bcbcbc25bf9713e8da3f942ce13` is verified on `main` and on the historical EVERBLOOM integration branch (fast-forward updates, no branch deletion or force). This section supersedes the earlier candidate/pending language above.

- [Native 42-assertion principal acceptance PASS on main](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41401140904) and [general Python+Godot editor/scene native PASS on main](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41401141061) at that exact SHA.
- Native principal acceptance now instantiates the **real game** with farm, animals and Village, serializes current game-owned state, and checks restoration after in-memory mutation. It confirms persisted calendar, currency, inventory, paddock forage, village memory and the `K` job input mapping. This catches the previously missed reserved `animals.__paddocks__` Array mismatch.
- Independent [farming ecology native acceptance](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41400266506) ran at `48d0ed21`; [Village life native acceptance](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41399964398) at `d18b2830`. Both feature lines were preserved without overlapping file overwrites.
- Implemented source now includes real soil moisture/fertility/compost/grazing logic, deterministic villager schedules, four recurring festivals, paid village work and year-monotonic farm/animal/social action caps, along with the earlier graybox valley.

**Still open:** No power-failure atomic-save proof, actual Windows file-lock tests, cross-domain transaction journal, full migration/fuzz corpus, end-to-end manual controls, controller/touch/mobile measurements, full family/marriage/child arcs, finished visual/audio assets, interiors, or game release packaging. A successful native test does not establish these outcomes.
