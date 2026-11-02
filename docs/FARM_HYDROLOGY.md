# F02 — Bounded crop-bed hydrology contract (2026-11-02)

**Status:** implementing, pending exact-head native CI; **not a complete F02 watershed/irrigation feature**. Owned by Farming. Baseline: main@39f2fe3f9b6168d09aa01f7e51ea4dbb7e52081a. Godot 4.x only.

## Real player loop and integration
The existing 30 farm beds, sow/water/till/harvest tools, rain, drought stress, seasonal failure, soil-darkening visual feedback and HUD messages remain in place. This patch replaces the previous implicit rain-and-evaporation moisture subtraction with an original deterministic water-accounting adapter. The existing watering-can action costs one energy, cannot be repeated on a watered/saturated bed, and raises bed moisture to 100. That water is **externally supplied**; no reservoir, finite can capacity, aquifer, channels or transport network is claimed.

For every daily transition, the model takes previous bed moisture (0..100), rainfall (68 units on the existing Rain weather; otherwise 0), summer flag and weed density (0..5). Rainfall is clamped to bed capacity; overflow is recorded as runoff. Excess saturated topsoil above 90 loses half its excess (integer floor) to deep drainage, then evaporates at 22 units on rainy days, 35 in summer otherwise 29, plus two units per weed level. Evaporation is bounded by remaining water. The invariant is:

    moisture_before + rain = runoff + drainage + evaporation + moisture_after

All terms are nonnegative integers, moisture_after is in [0,100]. The growth decision still uses water available after rainfall but before daily losses, preserving the existing crop timing and seasonal semantics. The daily ledger is transient and derived, so the only persistent value remains the already-saved bed moisture; no SaveService schema or Game authority change. Inputs and output are deterministic; no RNG or global mutable state.

## Verification and controls
Native Godot runner: \`godot --headless --path . --script res://scripts/farming_acceptance.gd\`. It exercises 112 successive deterministic hydrology days, exact daily conservation, saturated runoff/drainage, wet-versus-dry response, real farm next_day integration, and existing save/load; existing native 56-day farm/animal tests continue. The Farming workflow must pass on the **final SHA** before integration, together with general and QA native runs. No success is asserted merely because this document or code exists.

Keyboard/mouse: the existing farming tool selection and proximity-based interact controls; gamepad/touch mapping and physical-device validation remain Principal-owned integration gaps. No new artwork is imported; original procedural wet-soil material continues as visual feedback. Runtime cost: constant arithmetic per bed, O(30) per day, no allocation persisted, negligible relative to existing meshes; **no device FPS measurement**.

## Dependencies and deferred scope
Principal owns day_epoch (56-day year), Game, HUD and SaveService. Farming owns farm.gd, this hydrology adapter and its acceptance. Emergence must supply any future extreme-weather rain volume via a reviewed weather interface; Construction owns any waterworks/building placement and material reservation. Before extending save fields or irrigation inventory, coordinate with Principal and Builder and add assembled-game roundtrip/transaction tests. F02 still lacks water reservoirs, finite irrigation supply, channels, routing, drainage infrastructure, terrain slopes, evapotranspiration from temperature/wind and actual watershed calibration. This is a conserved, playable bed-level foundation only.
