# EVERBLOOM F09 — Finite farm equipment progression (isolated implementation)

Mission: **F09** (farm equipment progression). Status: **implementing / native-test candidate**, NOT integrated gameplay. Source: `scripts/farm_equipment_progression.gd`. Acceptance: `scripts/farm_equipment_acceptance.gd`. Isolated branch: `game/everbloom-farming-f09-tools-20261102`.

## Original player loop and interactions

The player inspects one of four farm tools (hoe, watering can, sickle, rake), chooses a field action at one of the **existing 30** beds, and receives a specific action/energy/wear feedback string. The domain emits an action **proposal** (`till`, `water`, `harvest`, `weed`) and `work_units`; it does not mutate existing beds, crop inventories or the player energy meter. A player can inspect durability and fatigue, pay to repair a worn tool, or pay to upgrade through three tiers. Each tier reduces energy and wear costs while improving efficiency. The player can never work a bed twice with the same tool on one calendar day. Full durability is restored only by a finite, paid repair. Exhaustion, breakage, invalid beds, insufficient energy/materials and repeated actions produce rejection messages without partial changes.

**Proposed controls (NOT YET WIRED):** keyboard/mouse select tool via inventory and click/tap a target bed; controller radial tool wheel + face-button confirm; touch tool carousel + large 44 px context buttons. The authoritative game interaction router must check reach, selected tool, bed state and action suitability before committing. Domain `status(name)`, `preview_upgrade(name)`, `preview_repair(name)` and command results supply player-readable feedback, but **there is no new HUD or physical device input implementation** in this branch.

## Domain state, bounds and resource conservation

- Godot 4.x `RefCounted` model, engine-neutral dictionary serialization. Schema 1; `last_epoch` advances **exactly one** per day, with 56-day year and `day_of_year` derived from `(epoch-1) % 56`; no resetting at year boundaries.
- Four tools, fixed identity/order, tiers 0–3, durability cap `40 + 20*tier`, bounded wear and use counters; each tool has a 30-element array of last-used epochs. Repairs and upgrades each have once-per-day timestamps.
- Global fatigue 0–100, decreases by 30 per daily rest; each operation costs finite energy and increases fatigue. Tier 0 requires four energy and three wear per use; tier 3 requires one energy and one wear. Repairs and upgrades also debit energy/materials.
- Four finite resource ledgers: energy, timber, ore, fiber. For each, `credited = spent + available`. Daily credit is bounded and idempotent. These are **domain receipts only**: they are not authenticated against the game inventory. Do not call `credit_resources` until an authoritative, atomic game debit has settled. Do not treat `operate` as a committed farm action without a corresponding atomic field transition. No money/items are minted by this model.
- `save_state` deep-copies; `load_state` validates the complete nested structure and rejects unknown fields, malformed types, overflows, impossible timestamps and ledger inconsistencies without mutation. `load_json` only normalizes exact integral JSON numbers within finite bounds. JSON equality and adversarial cases are native acceptance gates.
- No external randomness, no unbounded collections, no external assets, no destructive modifications to prior save files.

## Authority and integration contracts

**Principal (P01/P04/P07):** approve optional `farm_equipment` save namespace, schema migrations, authenticated resource receipts, atomic energy/inventory debit, action rollback and player input routing. Principal retains `scripts/game.gd`, `scripts/save_service.gd`, `scripts/hud.gd`. Until that approval, this is a stand-alone tested domain module and must not be enabled in ordinary gameplay.

**Farming:** integrate `operate` with the existing `scripts/farm.gd` action only after ensuring atomicity, reach checks and correct crop/bed conditions; preserve the current 30-bed visual mesh, planting/harvest rules, stamina and all existing inventory. Define whether tier `work_units` means wider area or higher efficiency, never multiply crop yields for free. Do not double-charge energy between game and domain.

**Construction:** timber/ore/fiber upgrade and repair quotes must map to verified material IDs and paid settlement; no assumed free materials or duplicate construction stock.

**Emergence:** severe weather may modify wear/fatigue through an explicitly versioned adapter; no unbounded direct state writes.

## Original asset and performance plan

Create independently authored tier-specific tool silhouettes, wear/dirt masks, repair sparks and upgrade bench props. No copied Harvest Moon assets, sounds or meshes. Aim for one material atlas and four low-poly tool models with mobile LODs; plan for 44 px minimum interactive touch controls, reduced-motion feedback and translated status strings. **These assets are planned, not produced.** Fixed 4 tools × 30 epoch entries = 120 bed markers, O(1) operation and bounded O(120) snapshot validation. Performance budget target: <0.25 ms per command on mid-tier desktop and <0.5 ms on mid-tier mobile, <16 KiB serialized state; **targets only, no hardware measurements**.

## Reproducible acceptance and limitations

Run `godot --headless --path . --editor --import --quit`, then `godot --headless --path . --script res://scripts/farm_equipment_acceptance.gd`. Dedicated push-only workflow `.github/workflows/everbloom-f09-equipment.yml` uses the independently verified Godot 4.7.2 release archive and SHA-256 pin. Native acceptance exercises 112 consecutive days, tier progression, paid repair, stamina/wear failures, duplicate prevention, all resource conservation ledgers, eight 14-day JSON/state checkpoints, and hostile nested save rejection.

**Status is not integrated** until Principal approves the resource/persistence contract, Farming wires actual bed actions, native assembled-game save and UI tests pass, and desktop/mobile/controller performance and usability are measured. Existing F01–F08 isolated work remains preserved; no claim that all F missions or 100 charter missions are complete.
