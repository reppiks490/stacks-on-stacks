# Construction B19 — typed structural-state handoff (design only)

**Project:** EVERBLOOM: The Living Valley · **Engine:** Godot 4.x · **Scope:** EB-B-011 through EB-B-020. **Status:** design contracts and offline validator only. No gameplay code, scene, save payload, inventory or existing catalog was modified.

## Provenance and phase gate

- Canonical charter: `game/everbloom-100-mission-charter-20261102` at `b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Starting canonical `main`: `60ddc826630dc7e7279b4f9d2cf7e7ca39a40eec`. Builder source: `game/everbloom-construction-phaseB-100-20261102` at `f6b61bd73dede5703dcf8ef45ea24d47e28b8065`, exact JSON blob `d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b`.
- Machine-readable new file: `structural_011_020.json`; offline executable validator: `validate_structural_011_020.py`. Run `python3 docs/innovation/construction/typed_state/validate_structural_011_020.py --self-test`.
- The joint 220-feature catalog has **not** been fully approved; Phase C implementation remains CLOSED. This is a non-authorizing hardening tranche, not a playable system or a Godot native test.

## Ten concrete state contracts

| ID | Feature | Typed fields | Domain rules | Cross-system authority |
|---|---|---:|---:|---|
| EB-B-011 | Surveyor Ribbon Parcel Exchange | 6 | 3 | Village consent; Valley parcels |
| EB-B-012 | Quakeproof Footprint Puzzle | 6 | 2 | Farming soil; Construction supports |
| EB-B-013 | Grainwise Joinery Bench | 7 | 1 | Principal material debit; Construction joinery |
| EB-B-014 | Curvecraft Wall Spline | 6 | 3 | Valley collision/nav; Construction walls |
| EB-B-015 | Mortar Clock Masonry | 6 | 2 | Principal clock/weather; Construction masonry |
| EB-B-016 | Snowdrift Roof Sculptor | 6 | 2 | Principal weather; Construction roofs |
| EB-B-017 | Stairflow Route Designer | 6 | 3 | Valley pathfinding; Construction stairs |
| EB-B-018 | Loftlift Hoist Assembly | 7 | 3 | Principal cargo ledger; Construction lifts |
| EB-B-019 | Heatmap Envelope Studio | 6 | 2 | Principal weather; Village comfort |
| EB-B-020 | Windlace Bracing Workshop | 6 | 3 | Principal weather; Construction load paths |

**Totals:** 62 typed fields (including shared `site_id`, `revision`, `day_epoch`, `receipts`), 24 explicit domain invariants and 20 feature-specific negative fixtures. All ten source field sets are preserved; B013 adds `input_mass_g`, B018 adds `rated_capacity_kg`, with additions explicitly recorded.

## State and economic contract

- Every field is typed, bounded and supplied with an inactive default. Present nested state is strict: missing keys, extra keys, nonfinite numbers, booleans masquerading as integers, duplicate receipt IDs, orphaned active sites and malformed geometry fail closed.
- The feature namespace is optional for older saves. Missing namespace means an empty, inactive feature; **present malformed namespace must never be silently discarded or replaced with defaults**. Principal must approve any new assembled-save schema, migrations and backup recovery. The offline validator is not wired to SaveService.
- Construction proposes and validates geometry, but **Principal owns inventory, currency, commit idempotence, rollback and durable settlement receipts**. Preview must not debit. Atomic placement must verify revision, material ownership, typed attachment and world occupancy at commit. Refunds require dependency-safe reversibility and must never be granted twice.
- Local `receipts` are capped at 128 for bounded optional state. **This is not a durable replay-proof settlement ledger**: evicted IDs could otherwise be replayed. Principal must provide a persistent authoritative command receipt index or monotonic non-reusable sequence before implementation. This unresolved design hazard is a release blocker.
- Source Phase-B costs reference `fiber`, `clay`, `iron`, `glass`, `dye` and `seed` without verified acquisition and debit integration. Farming/Principal must approve canonical IDs, recipes, yields, costs and conservation before any resource transactions.
- Consent strings in B011 are **references**, not proof of permission. Village owns opt-in access decisions and revocation. Terrain geometry and path clearance require Valley validation. Roofing, masonry, bracing, thermal and snow rules here are intentionally bounded **gameplay approximations**, not real-world engineering safety models.

## Native implementation acceptance after authorization

1. Validate each proposed state under real Godot 4.x, not just this Python validator; reject malformed nested saves atomically without altering authoritative player state.
2. Replay 112 days across two 56-day years, duplicate/reordered placement commands, interrupted save, stale revision, expired permissions, and partial rollback; compare canonical state and material/currency conservation before and after save/load.
3. Build the original hybrid socket/magnet/grid/freeform/blueprint/continuous preview and construction UI only when Principal opens Phase C. Verify mouse/keyboard, gamepad and touchscreen command parity, accessibility, path clearance, and visible failure reasons.
4. Profile real desktop and mobile tiers; previous 2 ms/4 ms previews are **unmeasured design targets**, not achieved benchmarks. Ensure no paid services, proprietary assets, Codex, PR-triggered review, engine migration or unrelated repository changes.

## Ownership handoff

Principal: confirm optional namespace, immutable command receipts, transaction authority, migration and native assembled-save test. Farming: canonical materials/soil/hydrology. Village: parcel consent, NPC routes and comfort. Valley/Construction: geometry, occupancy, collision, structural graphs and original art provenance. Emergence: adverse-event inputs and independent QA. Record explicit approvals in GitHub issue #2; comments alone do not constitute acceptance.

**Evidence rule:** A passing offline schema workflow only proves structural validation of this design artifact. It is not native Godot proof, feature approval, actual controller/mobile parity or Phase-C authorization.
