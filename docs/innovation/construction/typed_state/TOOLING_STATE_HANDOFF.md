# EVERBLOOM Construction B091–B100 — engineering-tooling typed-state handoff

**Status:** Ten original *design-only* engineering-tool state contracts and a deterministic standard-library adversarial validator. **NOT playable features.** No Godot scene, source script, HUD, inventory, authoritative save, physical controller/mobile test or asset changed. Shared Phase C remains **CLOSED** until independent semantic audit of all 220 feature ideas and Principal authorization.

## Pinned provenance and disjoint ownership

- Canonical charter: `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Frozen source catalog: `game/everbloom-construction-phaseB-100-20261102@f6b61bd73dede5703dcf8ef45ea24d47e28b8065`, blob `d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b`.
- Isolated branch created from `main@e63bee33176259a295ff0118c15ca1bd46d69be7`; exclusive files are this handoff, `tooling_091_100.json`, `validate_tooling_091_100.py` and a dedicated push-only workflow. Coordination claim is in GitHub issue #2.
- Principal owns canonical revision, monotonic 56-day `day_epoch`, authoritative inventory/receipt/undo, save schema registration and migrations. Construction owns only proposed tooling, preview and typed design state. Farming owns material provenance and protected land; Village owns resident consent; Valley owns mesh/geometry, route and collision truth.
- Existing main workflow includes `pull_request`; no PR is created. No Codex tools or review, force-push, branch deletion, unapproved spend, publication, proprietary assets or engine port.

## Ten distinct engineering decisions

| ID | Player-facing proposal | Deterministic contract invariant | Real-world integration gate |
|---|---|---|---|
| B091 | Anchorgraph Constraint Lens | Current graph revision, acyclic typed references and exact removable leaves | Real structural dependency graph, authoritative undo |
| B092 | Meshfold Self-Intersection Inspector | 64-hex mesh digest, referenced distinct face pairs and complete repair target set | Godot mesh topology/geometry validation; fixture cannot prove watertightness |
| B093 | Material Passport Registry | Verified source lot, grade never exceeds lot, unique repair provenance | Signed supplier lots, original assets and inventory ledger |
| B094 | Parametric Lattice Pattern Lab | Immutable spacing definition, quantized non-overlapping paid instances | Template identity, actual material charge and transform snapping |
| B095 | Measuredline Dimension Tool | Axis-aligned integer-centimeter distance exactly matches stored measurement | Authoritative world transform, collision clearances and unit adapters |
| B096 | Habitable Room Inspection | Ventilation/egress/weather criteria and current-revision unexpired certificate | Real nav/weather/airflow, revocation on geometry edits |
| B097 | Loadtrial Structural Test Rig | Virtual load capacity and minimum stress margin, zero structure mutations | Real structural solver and safe bounded physics; no physical stress proof |
| B098 | Deconstruction Cost Forecaster | Revisioned quote, salvage <= source, no refund before confirmed removal | Atomic authoritative demolition and salvage receipt, anti-dupe |
| B099 | Build Chronicle Time-Lapse | Monotonic authentic event ordering and no milestone absent from local receipts | Principal global action journal and actual event provenance |
| B100 | Universal Build Accessibility Audit | Per-actor width/step failures exactly derived and at least one safe route | Actual navigation graph, wheelchair/child/companion collision probes |

Every JSON record retains source novelty, player verbs, controls for keyboard/mouse/gamepad/touch, feedback, dependency owners, original asset plan, unmeasured desktop/mobile targets, provisional source material quote, exact typed nested schema, two positive fixtures, four feature-specific negative mutations and acceptance obligations. The 10 concepts are already in the frozen source catalog; this tranche **hardens their state contracts**, not an additional ten inventions.

## Test protocol and evidence boundary

```bash
python -m py_compile docs/innovation/construction/typed_state/validate_tooling_091_100.py
python docs/innovation/construction/typed_state/validate_tooling_091_100.py
```

Validator checks strict types (bool is not int), bounded nested objects/arrays, exact IDs and namespaces, missing/unknown keys, unique synthetic receipts, each feature's domain invariants, hostile mutations, seeded wrong-type fuzz, canonical JSON roundtrips and two-year 56-day epoch separation. Synthetic fixture receipts are **not authenticated debits** and do not establish global idempotence or conservation. CI results and exact checked-out SHA must be inspected separately; no native Godot proof is asserted by this document.

## Acceptance and next gates

1. Principal independently audit all 220 concepts for semantic uniqueness, complete fields, no reskins and ownership, then explicitly authorize Phase C; until then B20 cottage implementation is blocked.
2. Principal approve canonical versioned save namespace, command envelopes, atomic material debit/undo and cross-domain duplicate-receipt protection. Reconcile catalog's provisional costs (some unrelated materials appear in tool quotes) rather than treating missing IDs as free.
3. Construction/Valley verify actual meshes, world coordinates, structural graph, physics, route clearances and navigation; Village/Farming approve permissions and material provenance.
4. After Phase-C authorization, implement player-visible Godot vertical slice with input parity, original/provenance-verified modular assets, real assembled-game save/load/replay, hostile state tests and measured desktop/mobile budgets. No engine port until Godot baseline independently accepted.

**Known limitations:** Mesh digest is syntactic only, not computed from triangles; B091 leaf rules are graph-level, not structural simulation; B093 verified flag is not cryptographic provenance; B096 certificate is a fixture, not an inspection; B098 confirmed removal has no authoritative settlement; B099 local event receipts cannot prove global history; B100 abstract routes are not navigable world geometry. These are explicit integration blockers, not completed gameplay.
