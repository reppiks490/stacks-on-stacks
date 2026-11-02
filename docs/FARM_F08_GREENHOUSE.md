# EVERBLOOM F08 — Greenhouse Microclimate (isolated Farming candidate)

**Mission:** F08, `native-test pending` until exact-HEAD CI succeeds. **Engine:** Godot 4.x only. **Authority:** Farming domain; Principal owns game/save/energy/inventory. **Branch:** `game/everbloom-farming-f08-greenhouse-20261102`. **Source:** `scripts/farm_greenhouse_microclimate.gd`. **Native acceptance:** `scripts/farm_greenhouse_acceptance.gd`.

## Scope and boundaries

An original optional, deterministic four-bay greenhouse microclimate model. **It does not replace or modify the existing 30 outdoor beds**, existing farm/animal code, game, HUD, saves, construction, Village, Emergence, or either innovation ledger. No player-visible greenhouse is integrated yet. It is a real GDScript domain implementation, not an illustrated gameplay claim. The 220-idea innovation phase gates remain independent and closed to premature implementation.

Each installed bay tracks its own crop (lettuce, tomato, basil), heater, grow lamps, forced ventilation (0–3), temperature in tenths of Celsius, humidity, effective daylight, growth-degree units, stress, phenological stage, once-per-day control epoch, last planting/harvest epochs, and lifetime harvest count. Year length is exactly **56 days**: spring/summer/autumn/winter 14 days each, daylight factors 80/100/75/45 percent. No annual gating uses modulo day alone; actions use monotonic `day_epoch`. Weather inputs are bounded external measurements, not independently invented random weather. The microclimate is deliberately stylized and not a scientific agronomy predictor.

### Deterministic daily order

1. Caller supplies exactly the next monotonic day, external temperature (tenths °C), sunlight (0–100), rain (boolean). Skips/repeats fail atomically.
2. Each installed bay in stable index order requests 3 finite energy units for heating, 2 for grow lamps, 1 for active ventilation. If insufficient, that control **does not activate**; passive growth continues. No energy debt or negative inventory.
3. Compute bounded microclimate from external weather, seasonal daylight, active controls and previous humidity. Heater adds 9.0 °C; active fans remove heat and moisture; lamps add 30 points of effective light. Rain increases humidity.
4. Apply frost/heat/humidity stress, light limitation, temperature-dependent growth-degree units and deterministic germination → vegetative → flowering → fruiting → mature transitions. Failure requires accumulated stress and is not instantly cured.
5. Return a player-readable report with climate, stage, control activation, power consumption and available power. All persistent nested fields are validated and JSON roundtripped.

**Finite-energy invariant:** `energy_added == energy_spent + energy_available`, nonnegative and bounded at 10 million. Only one energy-credit receipt per monotonic day is accepted by the model; duplicated funding fails without mutation. **Important authority limitation:** `credit_energy(epoch, units)` validates structure and idempotence but cannot authenticate an external receipt. The real game must debit a trusted power/fuel or money source **before** crediting; the domain alone is not an anti-cheat or payment authority. This is an integration gate, not a completed economic feature.

**Inventory authority:** `install()` returns required 8 glass + 6 timber as a proposed material contract, `plant()` returns a required seed ID, and `harvest()` returns bounded proposed yield (1–3) while clearing the bay. These methods never grant, consume or duplicate player inventory or gold. Principal/Builder must provide atomic authoritative debit/credit with rollback, otherwise do not expose these actions in live gameplay.

### Intended player interactions and UX (not yet integrated)

- **Inspect:** Aim at bay, interact; see current °C, humidity, daylight, stage, stress, energy remaining and 56-day season.
- **Install:** Construction placement preview, collision and material reservation (Builder/Principal).
- **Plant:** Seed pouch selection, valid crop, seed debit and clear planting confirmation.
- **Adjust:** Toggle heater, lamps, fan level 0–3 once per day; show predicted daily energy cost and actual control activation (including power shortages).
- **Harvest/clear:** Harvest mature crops through an atomic inventory receipt; remove failed crops; display cause and recovery action.
- **Keyboard/mouse:** Target, E to inspect, contextual buttons for install/plant/adjust/harvest. **Controller:** A confirm, D-pad to select control, B cancel. **Touch:** Large tap targets and persistent context controls; avoid hover-only affordances. **These are design contracts only**; no actual control bindings are installed by F08.
- **Accessibility:** Numeric status + text labels rather than color-only feedback; reduced-motion and scalable UI must be integrated by Principal.

### Integration dependencies and handoffs

- **Principal:** Authoritative energy credit/debit and harvest/seed/material transactions, schema-versioned nested `greenhouse` state in `scripts/game.gd` and save service, atomic recovery and backward compatibility, UI/input and full-game two-year conservation. No Principal-owned file was changed.
- **Builder:** Reserved construction footprints, glass/timber provenance and reversible build/cancel material settlement. No construction source was changed.
- **Emergence:** External weather/daylight and extreme-event inputs (bounded, typed); greenhouse does not invent event state.
- **Farming:** Map greenhouse crop IDs and growth to current crop definitions, coordinate with F03/F04/F05/F06 without double-running growth or minting harvest, and provide player-visible crop meshes after authority approval.

### Original asset and performance plan

Author original modular timber/glass frames, interior beds, fan silhouettes, sun shades, heater controls, seedling/flower/fruit growth meshes, and gentle UI status icons. No extracted Harvest Moon assets. Use simple reusable meshes/materials and low-draw-call static structures, optional glass transparency and particle effects for desktop; mobile tier uses opaque/translucent substitutes and simplified plant geometry. **Target, not measured:** 4 bays, O(4) daily CPU, <1 ms total greenhouse update on baseline desktop and <2 ms on target mobile, <=16 added draw calls mobile before batching. Physical device profiling, input tests, localization, and provenance audit are outstanding.

### Acceptance and reproducibility

Dedicated **push-only** workflow runs official SHA-256-pinned Godot 4.7.2, headless import, and `godot --headless --path . --script res://scripts/farm_greenhouse_acceptance.gd`. Native regression covers 112 days, two 56-day years, deterministic replay, energy conservation and no duplicate funding, charged growth advantage over unpowered passive bay, climate controls, seasonal JSON and nested state recovery, malformed and hostile state rejection, crop harvest proposals, insufficient power, and out-of-order weather. General repository workflow separately runs Python validation, Godot import, smoke and existing save tests. **Native evidence must be read from exact final SHA**; this document alone does not prove success.

**Status:** isolated implementation candidate. Do not mark `integrated` until authoritative energy/material/inventory/save/UI/player controls and actual assembled-game tests pass. No Codex, PR, forced update, paid service, publication, proprietary game assets, or engine migration.
