# EVERBLOOM — Source-backed status ledger

**2026-11-02, principal architecture review.** The active Everbloom integration branch is `game/everbloom-harvest-sim-rebuild-20261101`; `main` still contains the historical SABLESTAR game. No branch or commit history was deleted.

- Everbloom source commit `cde73ab0a2d4af906803f97b65b79574bc608e9a` contains a Godot scene, original graybox valley, farmer controller, farm/village/animal interaction scripts, HUD and local save/load.
- Data includes 8 crop types, 6 original villager records, 3 animal types, 4 recipes, 4 quest definitions and 5 regions. These are modest foundation counts, not final content goals.
- Current GitHub Actions run `41397364228` failed in the offline step because `tools/validate_project.py` did not exist; native Godot stages were skipped. It would be false to call the Everbloom build native verified.
- Principal isolated branch `game/everbloom-principal-contracts-20261102` supplies an interim validator, offline tests and architecture contracts. QA owns future expansion.
- Original SVG and generated Godot primitives only; no copied Harvest Moon proprietary assets.
- Critical risks: year rollover and annual daily-action epoch, save crash recovery, native import/parser errors, cross-lane file collisions, performance, mobile controls and real art.
- Merge only after exact-head source and native gates. Preserve old SABLESTAR branches, no Codex and no unapproved purchases.
