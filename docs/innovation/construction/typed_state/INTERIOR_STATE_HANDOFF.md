# EVERBLOOM Construction B19/B10/B15 — interior state-contract tranche B021–B030

**Status:** design-state specifications and offline negative validator only; **not** playable Godot features, authoritative save integration, or a construction implementation. Phase C remains CLOSED until the complete 220-feature catalog is semantically accepted by Principal. No existing gameplay files were changed.

## Immutable source and ownership
- Charter: `docs/EVERBLOOM_100_ADVANCED_MISSIONS.md` at pinned `b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Baseline main at claim: `21d325eb4f05c90f37c1047a76a48b2a90767e31`.
- Original Phase-B Builder catalog: `game/everbloom-construction-phaseB-100-20261102@f6b61bd73dede5703dcf8ef45ea24d47e28b8065`, JSON blob `d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b`.
- Construction-only new files: `interior_021_030.json`, `validate_interior_021_030.py`, this handoff, dedicated push-only CI. Do not alter Principal, Farming, Village, Emergence, prior Builder contracts, main or integration branches.
- Run offline: `python3 docs/innovation/construction/typed_state/validate_interior_021_030.py --self-test`. Passing means **only** proposed schemas and fixtures were checked; native Godot gameplay remains untested.

## Distinct bounded invariants

| ID | Proposed player interaction | State and rejection boundary | Authoritative integration owner |
|---|---|---|---|
| B021 | Move sound baffles, preview room-to-room privacy | Room IDs must match, bounded deterministic spill calculation | Village privacy/comfort; Construction baffles |
| B022 | Shape a daylight shaft | Simple noncrossing polygon, no light without shaft, sunlight/occlusion model | Principal sun/calendar; Valley occlusion |
| B023 | Slide partitions to repurpose rooms | Valid track travel, distinct room endpoints, egress preserved, room revision matches | Valley navigation; Village occupants |
| B024 | Arrange goods on weight-rated shelves | Exact item mass and volume reconciliation, cell references and capacity | Principal authoritative inventory |
| B025 | Tune pantry vents | Inspection epoch cannot be future; bounded environmental spoilage floor | Farming perishables; Principal inventory |
| B026 | Reposition sink/prep/stove | Three unique fixtures and exact Manhattan-route cost | Village chores; Valley traversability |
| B027 | Route fictional washwater through reed filters | Exact input/untreated/treated/used conservation and finite filter capacity | Farming/Valley water; Principal settlement |
| B028 | Mix botanical pigments and coat walls | Pigment references, 10g/coat accounting, epoch, RGB syntax | Farming pigments; Principal debit |
| B029 | Place fictional hearth surrounds | Near-combustible cells require typed rated tiles; no orphan tile | Construction visual safety gameplay; Valley collision |
| B030 | Build accessible indoor ramps | 1:12 game slope bound, >=90cm width, >=120cm landing and referenced passable routes | Valley pathfinding; Village accessibility |

The acoustic, daylight, chore-time, spoilage and hearth rules are deliberately **fictional, simplified gameplay models**. They are not acoustic/lighting/food/fire/building-code or real-world safety advice. Performance targets in the source are **unmeasured**. No mobile/controller interaction or visual quality is claimed to have been verified.

## Save, material, interaction and performance handoff

Each state has `site_id`, `revision`, monotonic `day_epoch`, and at most 128 local receipts, plus domain-specific bounded fields and an inactive default. Present nested objects are strict; missing or unknown keys, type confusion (including bool-as-int), duplicate receipts, overflow, future epoch and invalid cross-field state fail closed. Optional namespaces absent from legacy saves are inactive. Principal must approve schema versions and full-game migration before integration. **128 local receipts do not prevent replay after eviction**: Principal must provide durable authoritative settlement receipts and idempotent material debits/refunds, including interruption recovery. Never debit for a ghost preview.

Source resource costs include `iron`, `glass`, `fiber`, `dye`, `clay`, `seed` and other material IDs whose acquisition and economics are not all verified. Farming/Principal must approve canonical item IDs, storage ownership and transaction conservation; do not create phantom inventory or silently substitute materials. For B024, the local `stored_ids` are references only, never inventory ownership. For B027, water totals are local proposal quantities, not authorized withdrawals. For B025, Farming owns decay transitions; this contract does not mutate crops.

After phase authorization, each feature requires a Godot 4.x player preview with validity reasons and undo, keyboard/mouse, controller and touch command parity, accessible non-color-only feedback, original procedural modular meshes/texture/audio with provenance, desktop/mobile tier budgets measured on devices, native hostile-save rejection, 112-day calendar replay, duplicate-command no-debit proof, full assembled Game save/reload, and negative occupancy/pathfinding tests. Proposed visuals are not generated assets. No Unreal/Unity port is authorized.

## Test and release gate

The offline validator accepts 10 valid feature fixtures and 10 inactive defaults, rejects 20 feature-specific hostile fixtures and 90 generic hostile mutations (110 rejected total), and verifies JSON roundtrips and source-field coverage. A separate non-Codex workflow runs this validator on pushes to the isolated branch. The existing general Godot workflow may also run on push, but passing it does not prove these proposed systems are playable. Preserve exact commit SHA, workflow run URL and any failures in issue #2 before considering reconciliation. **No PR**: generic workflow has a `pull_request` trigger and auto-review cannot be ruled out outside inspected workflow bodies.
