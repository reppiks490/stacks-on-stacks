# EVERBLOOM F03 — Crop physiology and phenology (isolated domain candidate)

**Mission:** F03 · **Status:** implementing / native test pending at authorship. Not integrated into canonical Farm/Game. Godot 4.x only.

## What is actually implemented

- Original `scripts/farm_phenology.gd` is an engine-native, scene-independent `RefCounted` domain model with **30 indexed beds**, all eight existing first-party crop IDs, a **56-day year**, and a strictly increasing monotonic `day_epoch`.
- Each crop accumulates **fixed-point growth-degree days in tenths of °C** above its crop-specific base temperature. Five visible growth stages are `germinating`, `vegetative`, `flowering`, `fruiting`, and `mature`. `failed`, `dormant` and `empty` are distinct persistent states.
- Crop-specific planting seasons, lethal frost thresholds, heat stress and moisture stress cause deterministic outcomes. Strawberry survives autumn/winter via once-per-year dormancy and reactivates in spring. This is a simplified stylized simulation, **not a validated agronomic prediction**.
- `plant(index, crop_id, epoch)`, `advance_day(epoch, temp_tenths, moisture[30])`, `harvest(index, epoch)`, `clear_failed(index, epoch)`, `status(index)`, `save_state()`, `load_state(payload)` expose player-action and feedback contracts. Daily updates and actions reject duplicate epochs; `load_state` rejects invalid nested payloads atomically. All resource counters are bounded integers.
- Harvest returns a deterministic authorization receipt and existing-catalog yield units **without touching inventory**. It is **not** an economic transaction; a caller must atomically debit seed/stamina, commit crop changes and credit inventory. Do not wire it into player rewards until Principal approves this boundary.

## Native verification and reproducibility

`scripts/farm_phenology_acceptance.gd` runs a deterministic 112-day replay over all 30 beds, eight 14-day save/load checkpoints, negative duplicate-day tests, strict hostile nested-save rejection, controlled frost/heat/drought failures, spring reactivation and perennial regrowth. Execute:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://scripts/farm_phenology_acceptance.gd
```

Dedicated non-Codex push-only workflow: `.github/workflows/everbloom-f03-phenology.yml`, pinned official Godot 4.7.2 release SHA-256, native import and exact-HEAD acceptance. **Do not claim PASS before inspecting the workflow run at the actual commit.**

## Dependency and integration handoff

| Boundary | Owner | Contract / open gate |
| --- | --- | --- |
| Calendar/weather | Principal | Supply monotonic `game.day_epoch()`, temperature in tenths of °C, 30 moisture integers 0..100; call `advance_day` once per day, including days with no planted crop. |
| Existing crop visuals, 30 beds and growth | Farming | Preserve `scripts/farm.gd` and `data/crops.json`; stage-to-mesh/animation mapping is not wired. Crop threshold profiles are original proposed balancing constants, not measured crop science. |
| Inventory, energy, sale economy | Principal/Farming | Authoritative seed debit and harvest credit must be one recoverable transaction with a unique receipt. No item/money duplication or free stamina. |
| Persistence | Principal | Optional versioned `farm_phenology` nested snapshot with strict admission and atomic full-game roundtrip; old saves must get deterministic defaults, not destructive migration. No changes to `save_service.gd` or `game.gd` in this branch. |
| Hydrology/soil | Farming | Eventually derive moisture and nutrient stress from F01/F02; those candidates remain on separate isolated branches. Do not double-apply water or nutrient consumption. |
| Events/weather | Emergence | Provide bounded, causally sourced temperature and frost inputs; no feature-catalog implementation is authorized by this candidate. |

## Player experience / device controls / art

Planned action: inspect a bed to see stage, thermal progress and failure/dormancy explanation; plant an in-season seed, water, tend, harvest or clear failed crops. Existing game control routing is **not changed**. Proposed keyboard/mouse: use current tool selection and proximity interaction; gamepad: same focused bed/context action; touch: tap bed and confirm accessible action sheet. These mappings require native end-to-end device testing and are **not yet verified**. Feedback strings in `status` are real domain outputs but not yet rendered by HUD.

Original-asset plan: authored stylized seedling/leaf/flower/fruit meshes and dormancy silhouettes per crop, seasonal particle and soil-shading cues, readable high-contrast progress indicator; no imported proprietary assets. Rendering adapters must support desktop and mobile LOD. **Target**, not measured: O(30) daily work, <1 ms on desktop reference hardware, no per-frame allocations in the domain, <=30 active growth meshes; mobile frame/memory budgets and controller/touch latency require device measurement.

## Honest limitations

This is **native-testable isolated code, not a playable crop replacement**. Existing `farm.gd` still uses integer age and water-day thresholds; F03 thresholds are not yet synchronized with actual crop balance. There is no assembled-game save roundtrip, inventory transaction, HUD, art, animation, mobile/controller proof or external agronomy calibration. Principal approval and assembled-game QA are mandatory before integration. Other mission IDs and the 220-concept innovation phase gate are unchanged.
