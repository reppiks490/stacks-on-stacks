# F01 — Finite soil biogeochemistry, Godot domain candidate

**Status: implementing; isolated, not connected to canonical Farm/Game/save service.** Based on `main@0a334a0eba0a74a042f331d606c7f3156abb06c2`. Original gameplay abstraction, not a calibrated agricultural or physical nutrient model. Existing 30-bed farm, crops, animals, inventory, and player saves are untouched.

## Model and conservation

`res://scripts/farm_soil_ledger.gd` represents 30 fixed planting beds. Each contains integer texture class (0 sandy, 1 loam, 2 clay), compaction 0–100, pH in tenths 40–90, nitrogen/phosphorus/potassium 0–1000, organic carbon 0–1000 and monotonic last-care epoch. Separate cumulative initial, externally added, plant uptake and lost ledgers track each of N/P/K/carbon. For each element: **initial + added = stored in 30 beds + uptake + lost**. Saturation overflow counts as loss, never minted material. Invalid snapshots reject atomically, without coercion or mutation. Crop growth draws bounded nutrients; rainfall causes bounded leaching and carbon respiration. pH/compaction are bounded scores, not conserved mass. No spontaneous N/P/K generation.

`advance_day(epoch, rain, planted_flags)` requires exactly the next `day_epoch`, rainfall 0–100 and 30 boolean crop flags. Duplicate/skipped days fail closed. `act(bed, action, epoch)` accepts `cultivate`, `compost` and `leaf_mulch` once per bed per day; provides player-readable feedback and required-item receipt. **Transaction boundary:** the module does not consume inventory, energy or money. Do not expose `act()` to live gameplay until Principal/Farming coordinate atomic resource reservation and optional versioned save integration. A domain receipt is not proof of external inventory debit.

## Reproducible native verification

Run Godot 4.x headless with `--headless --path . --editor --import --quit`, then `--headless --path . --script res://scripts/farm_soil_ledger_acceptance.gd`. Acceptance exercises 112 monotonic days (two 56-day years), 30 beds, rainfall/crop-uptake differences, amendments, duplicate-day/action rejection, eight 14-day save/load checkpoints, deterministic independent replay, deep-copy isolation and hostile nested-state rejection. Dedicated `everbloom-f01-soil-ledger.yml` uses checksum-pinned official Godot 4.7.2, read-only GitHub permissions and no Codex, PR or review trigger. Only a successful exact-HEAD workflow with inspected logs establishes native PASS.

## Integration, player UX, controls, dependencies, budgets

- **Player verbs:** inspect soil condition, cultivate compacted soil, spend compost/leaf mulch, observe fertility and crop effects. The model has deterministic domain actions and `status()` feedback; the in-game UI adapter does not yet exist.
- **Dependencies:** Principal owns Game, SaveService, inventory/energy authority, HUD and input. Farming owns existing Farm and animal compost. Preserve all 30 existing bed IDs. Construction owns original compost-bin/soil-station assets and material contracts; Emergence owns bounded extreme-weather inputs.
- **Controls plan:** reuse existing keyboard/mouse till action and proximity selection; add focusable controller/touch actions after router review. No measured device input/accessibility proof.
- **Persistence:** propose optional schema-1 `soil_biogeochemistry` snapshot with exactly-once legacy defaults and atomic full-game load; Principal approval required. Model-only nested `save_state`/`load_state` already roundtrip.
- **Original assets:** reuse procedural soil colors. Future compacted/healthy ground textures, pH/nutrient tooltips and low-cost soil panel must be independently authored with provenance; no external assets added.
- **Performance:** fixed O(30) daily arithmetic and snapshot, O(1) bed action, four ledgers; <1 ms daily update is an **unmeasured target**, not a result.
- **Next acceptance:** atomic inventory debit/rollback, full-game two-year save/reload, player HUD, controller/touch parity and measured device budgets. **F01 not mission-complete.** No engine port or innovation Phase-C authorization.
