# F15 — Fishing and wetland ecology (isolated Godot candidate)

**Mission:** F15, pinned 100-mission charter `b8a1e635792b08b0a3d87b987e593a539ac5c123`. **Owner:** Farming. **Status:** standalone executable ecology candidate; **not integrated** into live fishing, player inventory, Principal save service, or rendered world. **Files:** `scripts/farm_wetland_ecology.gd`, `scripts/farm_wetland_acceptance.gd`, push-only `.github/workflows/everbloom-f15-wetlands.yml`.

## Player loop and deterministic state

Three model habitats — Glimmer Lake (silverfin), Willow Stream (brookling) and Reedfen Marsh (reedperch) — begin with 24 fish each. A player can inspect a site's current stock, habitat condition, water temperature, rod requirement and model catch chance; cast at most once per site per monotonic day; or spend **three model-only stewardship credits** to restore habitat once per site per day. Reedfen requires rod tier >=2 and closes in winter. Storms, unsuitable temperatures and critically low stock prevent fishing. A valid cast has a reproducible, tier-dependent 60/70/80% **model** catch chance and consumes exactly one simulated fish on success; a miss consumes none. A successful model catch is **not** a live inventory item, currency, food, or authoritative receipt. The returned `proposal_id` is diagnostic only, not a permission to grant a fish.

The 56-day year uses `epoch = (year - 1) * 56 + season_index * 14 + day`; `advance_day` accepts only the next epoch and its canonical season. Five weather conditions (Clear, Rain, Mist, Storm, Drought) change water temperature. Deterministic recruitment depends on season, temperature and habitat; temperature stress/drought cause finite mortality. Stewardship raises future recruitment rather than instantly generating fish. Population capacity is 50 per site. No per-frame simulation.

State schema v1 contains epoch, season, weather, three site records (population, habitat, temperature, last cast and last stewardship epochs), and a seven-field conservation ledger. `save_state()` deep-copies; `load_state()`/`load_json()` validate nested fields, exact keys, integral finite numbers, calendar and climate, then atomically replace state. JSON's integral floating-point values are normalized. Save rejection does not alter a valid state. This is corruption protection, **not cryptographic receipt authentication**.

**Invariants:**
- `72 founders + actual births - actual deaths - simulated catches = live fish in all three sites`.
- `90 model stewardship credits = spent + remaining`, with nonnegative balances.
- `0 <= population <= 50`, `0 <= habitat <= 95`, bounded temperature and monotonic action epochs.
- Rejected or duplicate actions are atomic and cannot create additional catches or resources.

## Critical integration conflict: existing live fishing

`scripts/valley.gd` already has a real `act("fish", position)` route, which grants `game.grant_item("fish", 1)` after spending 8 energy. It uses `fishing_day == game.day` instead of `game.day_epoch()`: the same day number can repeat annually, causing incorrect gating at year rollover. **Do not enable F15 as a second inventory-granting fish source** or directly swap out `valley.gd` without World Art/Principal ownership approval. The new model intentionally does not call `game.grant_item`, `game.spend_energy`, or the save service. Its `energy_quote=6` is a future UI planning value only; current live fishing costs 8 energy and must remain authoritative until a single settlement contract is approved.

**Principal handoff:** approve an optional `wetland_ecology` save namespace, schema migration, atomic `cast`/energy/inventory transaction with a trusted one-time settlement receipt, and full assembled-game two-year save/load. The `proposal_id` is not such a receipt. Preserve existing `fish` inventory and live fishing state on migration. **World Art/Construction handoff:** validate lake/stream/marsh positions, fishable banks, collisions, and original water props. **Emergence handoff:** supply a single validated daily climate event, not two competing weather clocks. **Village handoff:** markets may use only settled fish inventory, never model catch totals. **F09 Farming handoff:** use one authoritative rod durability/upgrade source; the tier argument here is not equipment inventory.

## Controls, UI, assets and budgets

Proposed player UI: three wetland cards showing species, live stock estimate, temperature, rod eligibility and habitat health; cast/restore buttons with clear denial text, visible energy quote, daily cooldown and stewardship cost. Keyboard arrows/Enter/Escape, mouse click, controller D-pad/A/B and touch targets >=44 px; on-screen button alternatives for mobile. **Not implemented in live UI.** Original asset plan: authored lake-edge fishing zones, stylized fish silhouettes and splash particles, three rod meshes, floating reed clusters, restoration overlays and ambient water audio with recorded provenance. No extracted commercial game assets.

Complexity: O(3) per day, O(1) cast, fixed-size state and no physics/per-frame allocations. **Targets, not measured:** <0.5 ms daily update desktop, <1 ms entry-level mobile, <4 KB JSON save, 30/60 FPS mobile/desktop presentation tiers. Profile physical hardware before release.

## Native proof and status gates

Run official Godot 4.7.2 headless import then `--headless --path . --script res://scripts/farm_wetland_acceptance.gd`. The isolated runner covers 112 monotonic days, exact 14-day seasons, three stocks, temperature/weather, catch and stewardship denials, causal habitat recruitment, deterministic two-run equality, eight seasonal JSON checkpoints, malformed/hostile nested snapshots, and exact stock/credit conservation. Push-only workflow uses the existing project's checksum-pinned official Godot 4.7.2; general CI checks Python, import, assembled scene smoke and existing saves. CI logs must be tied to the exact final SHA before acceptance is claimed.

**Not yet proven:** full assembled-game F15 persistence, actual rod input, real inventory settlement, real device controller/touch interactions, original finished 3D art, mobile/desktop performance, actual fishing animations, or a migration of the existing live fishing cooldown. F15 is a baseline Farming mission, **not** Phase-C implementation of the 220-concept innovation ledger. No Codex, PR, force push, paid service, proprietary assets, publication or premature engine port.
