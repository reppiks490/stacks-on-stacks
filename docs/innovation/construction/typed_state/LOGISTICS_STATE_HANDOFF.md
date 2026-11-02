# EVERBLOOM Construction B061–B070 — site-logistics typed-state handoff

**Mission ownership:** B19 (Phase-B concepts 61–70), B12 (construction logistics), B13 (reversible operations), B07 (load and stability design), B14 (input parity), B18 (village events). **Status:** design-only, NOT playable. **Engine:** Godot 4.x only. **Canonical main at claim:** `709fb9c665504610ea18c6b93245fb4b7dbeb7c8`. **Source ledger:** `game/everbloom-construction-phaseB-100-20261102@f6b61bd73dede5703dcf8ef45ea24d47e28b8065`. **Phase C:** CLOSED until Principal verifies all 220 specs and authorizes implementation.

## Specific design rules and adversarial rejection

| ID | Player-facing proposed mechanic | Nested typed state | Domain rejection rules |
| --- | --- | --- | --- |
| B061 | Cratewheel Manual Lift — align an anchored trolley track and hoist a crate | `trolley_track`, `cargo_id` | Mass conservation; referenced segment; anchor; load capacity; effort bound from slope and friction. |
| B062 | Barrowbalance Transport Trial — balance and recover uneven-ground loads | `barrow_load`, `spill_receipts` | Delivered + spilled + remaining = input; rated capacity; stable delivery; per-trip spill receipts and references. |
| B063 | Drydock Supply Shed — protect finite-capacity material bins | `bin_capacity`, `material_lots` | Lot mass conservation; finite bin volume; humidity-driven spoilage when unsealed/unprotected; bounded density. |
| B064 | Village Build Permit Hearing — seek consent for a public-impact plan | `permit_id`, `impact_report` | Approved setback, heritage consent, nonempty council receipt, approval after submission and not in future. |
| B065 | Site Staging Planner — position pallets while maintaining safe routes | `staging_zones`, `route_graph` | Finite loaded capacity, unobstructed emergency route, minimum route width and reachable exit. |
| B066 | Courier Window Scheduler — book deliveries around closures | `order_id`, `arrival_epoch` | Dispatch/schedule/arrival ordering, closure detour, unique settlement receipts, exact counts, no future arrival. |
| B067 | Reversible Scaffold Builder — build and dismantle temporary platforms | `scaffold_nodes`, `crew_positions` | Load rating, bracing, crew-to-node reference, no dismantling occupied platform, no load on absent platform. |
| B068 | Workshop Safety Drill — assess hazard and crew readiness | `hazard_cells`, `crew_readiness` | Light, clutter, fatigue, certification, reviewed hazards and valid cell reference before readiness. |
| B069 | Counterweight Crane Assembly — balance a fictional hand crane | `boom_angle`, `counterweight_mass` | Load capacity, bounded moment, safe angle, anchor and reach envelope. |
| B070 | Weatherproof Material Tarps — cover lots ahead of storms | `tarp_footprints`, `protected_lots` | Lot mass conservation, finite area, sufficient tie-downs, wind rating, epoch and valid tarp references. |

The load/moment/effort formulas are **bounded game abstractions**, not real construction engineering or safe lifting instructions. Cross-domain positions, route reachability, and weather forecasts are *proposed* input contracts only, not verified world data. None of the local checks authorizes settlement or NPC consent.

## Data integrity and explicit authority boundaries

- All fields are strict typed JSON with exact nested shapes, bounded signed integers, nonempty unique nested list IDs, unique capped local receipt IDs, and no NaN, Infinity, unknown keys, control characters, or booleans masquerading as integers. Active states require nonempty `site_id`, revision >=1 and monotonic `day_epoch` >=1. `day_epoch=(year-1)*56+season_index*14+day` remains Principal-owned. Annual once-per-day checks must use epoch, never day-of-season alone.
- Principal owns authoritative inventory/currency, material source receipts, settlement atomicity, command idempotency across the entire save lifetime, and migration registration. The 128-entry local receipt cap is **not** durable global replay prevention. B062 spill receipts, B066 courier settlement receipts and B070 protected-lot IDs require cross-feature provenance; local uniqueness cannot prevent duplicate inventory or item grants.
- Village owns build-permit approval, NPC schedules and consent, and crew readiness; Construction may only cache immutable authorized summaries. Farming owns harvested material lots and resource flows. Valley owns terrain, wind, collision, emergency access and navigation. B065 route booleans are NOT a substitute for authoritative pathfinding; B067 removal requires real occupancy and navigation checks. Any stale revision, revoked permit or changed route invalidates a preview.
- Source-ledger material quotes are **unapproved and potentially incoherent** (for example, glass as a crane input, seeds as courier-scheduler input). No gameplay debit/refund, construction material creation, economic balancing, NPC labor award or delivery settlement is authorized. Undo is an explicit Principal-validated inverse, not a replayed grant. Save/load must preserve nested domain fields without phantom resources.

## Controls, art and performance — requirements, not evidence

Each concept retains the source ledger's exact mouse/keyboard, gamepad and touch `preview/adjust/commit/cancel/undo` contracts. Future Godot UI must show snapped/unsnapped ghost, structural warning, inaccessible-route reason, material quote, cancellation, undo and final receipt. Touch must offer visible precision steppers and Confirm/Cancel without long-press; controller and keyboard must reach equivalent commands. Accessible cues must not rely on color alone.

Only original modular models, textures, status icons, self-authored audio and documented provenance may be integrated. Use cached meshes/LOD and static preview where possible. Source desktop target <=2ms preview at 60fps and mobile target <=4ms preview at 30fps are **unmeasured design targets**, not benchmarks; real Godot profiler/device evidence is required.

## Reproducibility and remaining gates

Offline validation: `python3 docs/innovation/construction/typed_state/validate_logistics_061_070.py`. Dedicated push-only non-Codex workflow `.github/workflows/everbloom-construction-b19-logistics-types.yml` compiles and runs the validator. Generic main push CI separately validates the *existing* Godot baseline. Its success must never be represented as B061–B070 native gameplay proof.

Proposed save namespaces `construction.eb_b_061` through `construction.eb_b_070` are **not** registered in SaveService. Absent namespace remains inactive; present malformed namespace must fail atomic admission after Principal migration approval. After the joint 220-feature gate, native acceptance must use assembled `game.gd` and SaveService, exercise each player verb, save/restart/load across epochs 56→57 and 112→113, reject repeated command IDs and stale quotes without money/item/resource changes, test actual touch/controller parity, inspect original asset provenance and measure desktop/mobile performance. No native implementation has been started.

**Files isolated to new Construction innovation documents, Python validator and push-only workflow.** Existing gameplay, saves, all other lanes, unrelated repositories and Git history untouched. No Codex, PR, force push, engine port, paid service or proprietary third-party assets.
