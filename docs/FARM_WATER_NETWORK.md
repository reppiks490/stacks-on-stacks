# F02 — finite water catchment and irrigation-channel contract

**Status:** implementing, isolated engine-executable module; **NOT yet integrated** with player watering, save service or HUD. Existing 30 beds, crops, animals, calendar, inventory and economy remain untouched. This is baseline F02 work, not a new Phase-C innovation feature.

## Player-facing acceptance target (not yet claimed)
The player will collect rain runoff into a finite farm reservoir, inspect its level, and irrigate one of the existing 30 beds. A full reservoir visibly spills, a dry reservoir denies watering without consuming stamina, and each bed may be irrigated only once per monotonic day. A contextual water bar and a short action result must show withdrawn, delivered and lost units. Proposed bindings: keyboard E/use or existing farm water tool, mouse click on targeted bed, controller face-button/context action, touch tap/context button. Principal owns input/HUD wiring. These are design targets, not current playable controls.

## Implemented Godot domain module
`scripts/farm_water_network.gd` is a standalone RefCounted state machine with `next_day(day_epoch, runoff_inflow, evaporation_demand)`, `irrigate(bed_index, withdrawn_units, day_epoch)`, `status()`, `save_state()`, `load_state(payload)`, `balance_error()`. All external commands return an `ok` flag and a player-readable message; invalid commands are atomic. The first daily tick may begin at any positive epoch; subsequent ticks require exact +1 progression. Every daily tick accepts **one** runoff-capture amount, so duplicate catchment events cannot create water. Watering consumes finite stored water, is limited to 30 units per bed per day, and is not repeatable after reload on the same day. Channel delivery is 90% of source withdrawal, rounded down; the rest is accounted channel loss.

**Conservation (integer gameplay units):**
`initial + inflow_total = stored + spill_total + evaporated_total + delivered_total + channel_loss_total`.
All amounts are bounded, snapshots deep-copied, nested 30-element daily ledger validated, and malformed saves rejected without changing live state. Catchment inflow must be **diverted from** the existing F02 runoff, not counted in both soil and reservoir. The module does not claim hydrologically accurate litres, river routing or 3D channel construction.

## Ownership and dependency gates
- Farming owns this module and native test; existing F02 soil moisture integration candidate is isolated at `game/everbloom-farming-f02-reconcile-20261102@3606e294` and remains separate.
- Principal must approve a **new optional** farm-water-network snapshot schema in `scripts/save_service.gd` and `scripts/game.gd`; legacy saves must default to a single reservoir without minting initial water on repeated loads. No direct modification to Principal files is authorized here.
- Farming will integrate runoff diversion, real farm watering, stamina and finite source debit in one transaction only after the assembled save contract is agreed. Do not double-charge or double-credit resources.
- Construction may later supply original reservoir/channel meshes and placement materials; Emergence supplies rain/drought/storm inputs with exactly-once epoch semantics. Neither loop should mutate this ledger directly.
- Mobile/desktop target: O(1) per daily catchment update and O(1) per bed watering, 30 integer entries per snapshot; target <0.1 ms/transition on reference desktop and low-end mobile **unmeasured**. No rendering or external assets currently required; planned assets must be original or independently rights-verified.

## Reproduction and gates
`godot --headless --path . --script res://scripts/farm_water_network_acceptance.gd` runs the actual GDScript domain state machine for 112 days, 30 beds, eight seasonal save/load checkpoints, forged snapshot rejection, daily duplicate prevention, source exhaustion, overflow and channel conservation. Dedicated non-Codex workflow: `.github/workflows/everbloom-farm-water-network.yml`; official Godot 4.7.2 zip is SHA256-checked before native import and execution. Exact SHA and workflow receipts belong in GitHub issue #2, not an unverified static completion claim.

**Mission completion:** F02 remains partial. Real player integration, persisted full Game roundtrip, weather coupling, channels as placeable geometry, controller/touch verification and measured device performance are outstanding.
