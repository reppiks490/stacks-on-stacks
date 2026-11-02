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

**Updated calendar handoff (2026-11-02):** Farming/Animal lane integrated `game.day_epoch()` in `scripts/animals.gd` and `scripts/farm.gd`; CI runs 41398474611 and 41398474589 passed at canonical merge `bfd389a`. **Village lane remains responsible** for replacing `game.season_index*14+game.day` in `scripts/village.gd` with `game.day_epoch()` for gifts and talks and submitting real year-rollover native evidence. Do not independently modify `scripts/game.gd`.

**Safe sequencing:** Read branch heads/workflows/issues → choose own files → commit on isolated branch → source/native CI → issue handoff with exact commit/run IDs → principal reconciliation → fast-forward merge only when gates pass. No PRs unless all auto-review triggers are audited and non-Codex. No unlicensed copyrighted assets, no fabricated native/mobile/perf results, no paid actions, no other repository edits.

## Principal save-integrity isolation (2026-11-02)

- Claimed branch: `game/everbloom-principal-save-integrity-20261102`, based on canonical `main` `bfd389a`.
- **Exclusive files:** `scripts/save_service.gd`, `scripts/principal_save_acceptance.gd`, `tests/test_save_contract.py`, `docs/ARCHITECTURE.md`, `docs/CROSS_LOOP_COORDINATION.md`, `docs/MASTER_PLAN.md` and dedicated `.github/workflows/everbloom-principal-save-integrity.yml`. Other lanes should not overwrite these while reconciliation is pending.
- [Native 19-assertion acceptance PASS at 8b4cea2](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41399615671). The final branch SHA still requires exact-head general CI confirmation prior to integration.
- QA: maintain existing main workflow; expand engine-driven invalid-nested-state, full-state conservation, interrupted-write and Windows locking tests. New principal CI is a narrow dedicated workflow and does not invoke Codex.
- Farming: retain tested soil/husbandry epoch behavior; no principal edits planned in `farm.gd` or `animals.gd`.
- Village: own year-two friendship/gift gating and social save migration; do not alter principal-owned save service.
- Art: own original assets/provenance; do not take this principal branch as evidence of authored visual completion.
- **Source of truth:** issues and exact branch SHA/CI logs; writing this ledger is not proof that another loop acknowledged it. No force pushes, history deletion, PR creation, paid tools, or proprietary extracted assets.
