# EVERBLOOM — Phase-A Joint Review and Construction Transaction RFC
**Date:** 2026-11-02. **Status:** candidate engineering review; Principal approval PENDING. **Owner:** Construction Inventor (B01/B02/B03/B07/B13/B19). **Active engine:** Godot 4.x only.

## Verified source provenance and mechanical audit
- Canonical `main` at branch creation: `2cba34afe7d6ae5e2eb7d2dc30230b6539c927e4`.
- Isolated audit branch: `game/everbloom-construction-crossaudit-20261102`; it does not modify game scripts, save schema, Principal/Farming/Village/Emergence files, or existing workflows.
- Builder source: `game/everbloom-construction-phase1-20261102@0c23b576fc255cce5130a547be549986b685c27e`; catalog Git blob `1fbcafa552dfab5f03e0c22fbb929174dbaa5e87`.
- Emergence source: `game/everbloom-emergence-phase1-20261102@9ba5b83f2d11d18e23011093c08626b1057f9db2`; catalog Git blob `883f73fdf8dd31177865107eef82a7125b2703b2`.
- Both catalogs are copied **byte-for-byte** into `docs/innovation/construction/snapshots/` as immutable review inputs; source ownership remains with their respective inventors. The offline auditor checks Git blob SHA of each copy, 20 unique IDs/titles/domains, substantive specification fields, Godot-only status, explicit 220 gate, and eight interface/authority boundaries.
- `python3 docs/innovation/construction/validate_phaseA_joint.py --self-test` tests 13 deliberately invalid mutations (duplicate IDs/titles/domains, missing touch, missing acceptance, negative materials, missing state, false implementation, early engine migration, forged approval, missing overlap, missing authority, weakened gate).
- This is a **design integrity audit**, not a native Godot gameplay or mobile performance test. Previous independent catalogs were validated at their source commits; the combined review requires Principal sign-off before Phase B.

## Eight non-overlapping ownership contracts
1. **B-004 ↔ E-002:** Builder owns roof geometry and finite cistern ledger; Emergence owns river/fish habitat; Farming owns rainfall/runoff. Partition daily water exactly once.
2. **B-008 ↔ E-010:** Builder owns paid construction crews; Emergence owns nonconstruction cooperative chores; Village owns NPC consent, fatigue and exclusive schedule slots.
3. **B-005 ↔ E-003:** Builder owns room privacy and warmth; Emergence owns confidential letter promises; Village owns relationship and entry consent.
4. **B-010 ↔ E-001:** Builder owns insulation, building damage and repairs; Emergence owns causal event triggers and journal; Principal owns weather and day_epoch.
5. **B-010 ↔ E-007:** Builder owns physical climate effects; Emergence owns evolving community rituals; Village owns fixed annual festivals and NPC invitations.
6. **B-007 ↔ E-008:** Builder owns structural blueprints; Emergence owns textile patterns; Principal inventory owns typed resources and template namespaces.
7. **B-002 ↔ E-009:** Builder owns terrain foundation occupancy; Emergence owns canoe route plans; Valley/Principal own canonical world geometry and navigation.
8. **B-009 ↔ E-004:** Builder owns salvage eligibility/quality; Emergence owns caravan stock and escrow; Principal owns authoritative inventory/currency receipts.

The machine-readable binding document is `PHASEA_CROSS_LOOP_CONTRACT.json`. Its `approval` fields deliberately remain `pending_principal_review`; no sign-off is fabricated.

## B01/B02/B03/B07/B13 — proposed portable command protocol
This is an interface proposal, **not code wired into the current Godot game**.

```json
{
  "schema": 1,
  "command_id": "uuid-or-deterministic-unique-token",
  "site_id": "persistent-site-id",
  "actor_id": "player",
  "day_epoch": 57,
  "expected_world_revision": 13,
  "expected_inventory_revision": 28,
  "intent": "place_part",
  "mode": "socket",
  "part_catalog_id": "wood_post_01",
  "transform_cm": {"x": 0, "y": 0, "z": 0, "yaw_deg": 90},
  "anchor_id": "foundation_socket_03",
  "quote_id": "stable-cost-and-support-digest"
}
```

**Mode semantics:** (1) `socket` selects nearest compatible typed anchor; (2) `magnet` attracts within bounded radius but cannot override collisions; (3) `grid` quantizes translation and yaw; (4) `freeform` permits precision nudges but still checks support, occupancy and reach; (5) `blueprint` expands a prevalidated plan into explicit parts with staged costs; (6) `continuous` emits independently idempotent commands at bounded spatial intervals. All modes feed the **same** `preview → validate → commit` pipeline and share one undo/redo model.

**Pure preview:** `preview_part(site_id, part_id, mode, transform, world_revision)` returns validity, textual/color-independent reasons, candidate sockets, support dependencies, cost and predicted occupancy. It never mutates money, materials, geometry, quest state or player stamina. Preview may be invalidated when the world revision changes.

**Typed socket compatibility:** each anchor declares `anchor_id`, `kind`, `accepts_part_kinds`, `local_transform`, `max_load_units`, `occupied_by`, `support_parent_ids` and `revision`. Snap resolves deterministic tie-breaking by compatibility, distance, angle and stable anchor ID. Reject occupied, incompatible, stale, unsupported and intersecting placements with accessible explanations. No freeform bypass of structural rules.

**Commit transaction:** verify command idempotency; revalidate world/inventory revisions, placement, supports and cost; reserve materials; add structure graph node and occupancy; produce one authoritative receipt; commit both graph and resource debit to a single assembled snapshot. On any failure restore the exact pre-command state. A duplicate command ID returns the existing receipt without a second debit or geometry insertion. Never make a separate hidden construction save that can diverge from `scripts/game.gd`.

**Undo and recovery:** the action journal contains exact inverse receipts and dependent-node edges. Undo a leaf reverses its debit/refund once. Undo a load-bearing parent with dependents must either reject with a visible reason or request explicit cascade confirmation. Save/load must retain partial structures, revisions, receipts, material quality and command IDs. Crash or invalid save must preserve a valid prior assembled snapshot; Principal retains save schema authority.

**House assembly state machine:** `surveyed → founded → framed → enclosed → habitable → furnished`, with explicit allowed reverse transitions and weather/repair states. Every transition requires its prerequisite structural graph and accounted material receipts; visual construction stages reflect real player actions rather than a single static model appearing instantly. Floor and roof stages require load-path validity; doors/stairs require navigable egress; household bonuses activate only at the `habitable` stage.

**Input parity:** pointer drag/click, controller stick/shoulder/A/B and touch drag/rotate/large confirm/cancel map to the same normalized intents. Precision nudge and snap-mode changes must be discoverable without keyboard modifiers. No pointer-only feature may be necessary for baseline completion.

**Performance design targets (not measured):** one active ghost; bounded socket query (desktop 64, mobile 24); no per-frame mesh regeneration for static parts; typed anchors indexed spatially; predictable graph traversal and LOD variants for original meshes. Quantize serialized transforms; keep visual interpolation local to Godot adapters.

## Acceptance matrix for the eventual native Godot vertical slice (AFTER 220 gate)
1. Preview with insufficient wood rejects without mutation.
2. Confirm a valid post debits exactly two wood and creates exactly one structure ID.
3. Duplicate command ID returns the original receipt and does not double debit.
4. Stale world revision rejects and requires a fresh preview.
5. Incompatible socket/occupied anchor/collision/unsupported freeform each reject with distinct text reasons.
6. Rapid input, controller double-press and touch double-tap remain idempotent.
7. Cancelled preview consumes no materials or stamina.
8. Undo leaf restores exact pre-command state; redo charges once.
9. Undo structural parent with dependents requires explicit cascade or refuses.
10. Save/reload of partially framed cottage preserves parts, anchors, ledger, command journal and occupancy.
11. Year-one Winter to year-two Spring replay preserves `day_epoch` and construction event cooldowns.
12. Invalid/corrupted assembled save leaves current session and backup intact.
13. Rain capture cannot mint water in both cistern and river.
14. NPC construction shift cannot overlap an already booked cooperative chore.
15. Mouse, gamepad and touch scripted intents produce identical canonical building states; device performance must be measured separately.

## Required owner acknowledgements / next actions
- **Principal:** review eight boundaries, accept/reject the joint 20-spec phase gate, assign inventory/save/command gateway and typed world revision authority; if accepted, coordinate the Phase B 200-concept expansion. This document cannot grant itself that approval.
- **Emergence:** review the eight shared edges and confirm the frozen Emergence catalog reflects the exact source SHA; preserve E-001..010 ownership.
- **Farming:** provide a bounded daily runoff/rainfall contract, and resource pricing/material transactions; no double water minting.
- **Village:** provide exclusive NPC schedule/consent reservations, not direct construction crew edits.
- **Valley/Principal:** address the independently reported fishing/foraging day-number cooldown and persistence defect with an agreed `day_epoch` plus assembled-save contract; this branch does not edit `valley.gd`.
- **Builder next:** wait for explicit Phase A acceptance, then author EB-B-011..110 as genuinely distinct full specs in its own namespace; do not implement gameplay before all 220 specs are verified.

**Security and operational controls:** no Codex, PRs, destructive history changes, unapproved spend, proprietary assets, publication, or Unreal/Unity migration. Native Godot project CI is separate from concept validation; never conflate the two.
