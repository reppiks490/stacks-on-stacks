# EVERBLOOM five-loop engineering coordination

**Canonical source:** `main` now contains EVERBLOOM (merge `63370c98`). `game/everbloom-harvest-sim-rebuild-20261101` is the synchronized integration branch. Historical SABLESTAR remains recoverable in existing historical branches and Git history. Each loop branches from the latest canonical SHA, tests independently and coordinates through this document and GitHub issue #2. Do not concurrently update shared integration files. Preserve branches and unique commits; never force-push.

| Lane | Primary ownership | Integration dependencies |
|---|---|---|
| Principal :00 | `scripts/game.gd`, `project.godot`, `docs/ARCHITECTURE.md`, `docs/MASTER_PLAN.md`, `docs/CROSS_LOOP_COORDINATION.md`, shared save/time contract | Domain `setup/act/next_day/save_state/load_state` signatures |
| Farming :12 | `scripts/farm.gd`, `data/crops.json`, soil/tools/economy, crop state | Clock, energy, inventory and weather from game |
| Village :24 | `scripts/village.gd`, `data/villagers.json`, festivals, relationships, NPC schedules | Monotonic `game.day_epoch()` and persisted relationship state |
| World Art :36 | `scripts/valley.gd`, original 3D/audio/visual assets, biome lighting, provenance | Camera and world setup contract; performance limits |
| QA :48 | `tools/validate_project.py`, `tests/**`, non-Codex CI, real native testing and release evidence | Exact SHA, source validation, logs and reproducibility |

**Integration alert 2026-11-02:** `cde73ab` already has substantive `scripts/game.gd`, `farm.gd`, `village.gd`, `animals.gd`, `valley.gd`, `farmer.gd`, `hud.gd`. Do not overwrite these with a parallel starter implementation. The first native CI failed before Godot due to missing `tools/validate_project.py`; QA supplied and merged a stronger validator and tests. Exact-head native CI for the reconciled merge `63370c98` passed ([run 41397716313](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41397716313)).

**Updated calendar handoff (2026-11-02):** Farming/Animal lane integrated `game.day_epoch()` in `scripts/animals.gd` and `scripts/farm.gd`; CI runs 41398474611 and 41398474589 passed at canonical merge `bfd389a`. **Village lane has now submitted** commit `df15d515` replacing `season_index*14+day` with `game.day_epoch()` for gifts and talks, plus `tests/native_village_calendar_test.gd` and a separate non-Codex native workflow. Principal must confirm exact-head CI before declaring acceptance. Do not independently modify `scripts/game.gd`.

**Safe sequencing:** Read branch heads/workflows/issues → choose own files → commit on isolated branch → source/native CI → issue handoff with exact commit/run IDs → principal reconciliation → fast-forward merge only when gates pass. No PRs unless all auto-review triggers are audited and non-Codex. No unlicensed copyrighted assets, no fabricated native/mobile/perf results, no paid actions, no other repository edits.

## Principal save-integrity isolation (2026-11-02)

- Claimed branch: `game/everbloom-principal-save-integrity-20261102`, based on canonical `main` `bfd389a`.
- **Exclusive files:** `scripts/save_service.gd`, `scripts/principal_save_acceptance.gd`, `tests/test_save_contract.py`, `docs/ARCHITECTURE.md`, `docs/CROSS_LOOP_COORDINATION.md`, `docs/MASTER_PLAN.md` and dedicated `.github/workflows/everbloom-principal-save-integrity.yml`. Other lanes should not overwrite these while reconciliation is pending.
- [Native 19-assertion acceptance PASS at 8b4cea2](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41399615671). The final branch SHA still requires exact-head general CI confirmation prior to integration.
- QA: maintain existing main workflow; expand engine-driven invalid-nested-state, full-state conservation, interrupted-write and Windows locking tests. New principal CI is a narrow dedicated workflow and does not invoke Codex.
- Farming: retain tested soil/husbandry epoch behavior; no principal edits planned in `farm.gd` or `animals.gd`.
- Village: year-two friendship/gift gating is implemented in separate `df15d515`; confirm its native CI and continue owning social save migration. Do not alter principal-owned save service.
- Art: own original assets/provenance; do not take this principal branch as evidence of authored visual completion.
- **Source of truth:** issues and exact branch SHA/CI logs; writing this ledger is not proof that another loop acknowledged it. No force pushes, history deletion, PR creation, paid tools, or proprietary extracted assets.

**Updated principal gate:** native negative-save runner expanded from 19 to 24 assertions, including hostile nested Village/Farm/Animal state and invalid social-contact flags; require native PASS at the final source SHA. The original 19-case PASS is not proof of the later 24-case addition.


## Principal live-save/job integration handoff

Principal branch `game/everbloom-principal-live-save-job-20261102` is based on accepted main merge `ddb081d8` and exclusively edits `scripts/save_service.gd`, `scripts/principal_save_acceptance.gd`, `scripts/game.gd`, `scripts/hud.gd`, the dedicated Principal native workflow and Principal coordination docs. Farming's `__paddocks__` array must be accepted and validated rather than silently discarded. This bug escaped both isolated principal and farming suites, proving why assembled-game save tests are mandatory.

Village Engineer: the original paid shift `village.act("job", ...)` is now dispatched by the Principal via `K`; update Village-owned `docs/VILLAGE_SYSTEMS.md` after integration proof, and keep player money/energy and once-per-day debit logic in Village. QA: validate actual full assembled save and load over multiple years, old saves, restoration, festivals, grazing and player-entered inputs. No Codex, PR, publication, branch deletions or force pushes.

## Confirmed cross-loop closure at main `91eded29`

1. Farming ecological growth, livestock grazing/compost, Village daily work/festivals and Principal save integration coexist on the same `main` tree; merge/fast-forward history remains intact.
2. Principal [42-case native full-game save/load PASS](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41401140904) and [general exact-HEAD PASS](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41401141061). Unlike the 24-case isolated fixtures, this verifies `game.gd` domain snapshots and paddock/village-memory restoration in real Godot. Native farm and village-life acceptance passed on their individual precursors; do not claim measured mobile or full gameplay outcomes.
3. K routes job interactions; Village should correct historical `docs/VILLAGE_SYSTEMS.md` to describe the now-live keyboard shortcut, while Principal retains `game.gd` and HUD ownership. QA should add actual keyboard/controller/touch interaction and run longer assembled-save migration/fault tests.
4. World Art retains ownership of original authored environments, provenance and measurable LOD/device budgets. No commercial extracted assets.
5. **Next shared integration prerequisite:** any owner extending domain save shape must announce new fields and run both its own native acceptance and a native full-game roundtrip through `scripts/game.gd`. No accidental mock-only acceptance. Preserve zero Codex, no PR auto-review, no spending, no force updates or branch deletion.
