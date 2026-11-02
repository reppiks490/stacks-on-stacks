# EVERBLOOM E18 — independent frozen 220-concept semantic QA

**Scope:** E03/E18, design-only. **Phase C CLOSED**; not a Godot implementation, playtest, device benchmark, or Principal approval. This is an independent negative acceptance audit of five pinned source catalogs. The authoritative frozen catalogs and all runtime files are unchanged.

## Sources and reproducibility

The source-derived `FROZEN_PROJECTION.json` contains 220 IDs, original titles, domains, player scenarios/verbs, state field declarations, three platform control descriptions, positive/negative acceptance, dependencies and design status. Five Git blob SHA identifiers preserve exact source provenance. The source files are located on **separate frozen branches** and were fetched using their explicit refs:

- Construction Phase A: `game/everbloom-construction-phase1-20261102`, `docs/innovation/construction/phase1_ten_concepts.json`, blob `1fbcafa552dfab5f03e0c22fbb929174dbaa5e87` (10).
- Emergence Phase A: `game/everbloom-emergence-phase1-20261102`, `docs/innovation/emergence/phase1_ten_concepts.json`, blob `883f73fdf8dd31177865107eef82a7125b2703b2` (10).
- Construction Phase B: `game/everbloom-construction-phaseB-100-20261102`, `docs/innovation/construction/phaseB_100_concepts.json`, blob `d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b` (100).
- Emergence Phase B 011–050: `game/everbloom-emergence-phaseB-100-20261102`, `docs/innovation/emergence/phaseB_011_050.json`, blob `a5def76918e77e0ded7e3e8085444698b4e0b549` (40).
- Emergence Phase B 051–110: same branch, `docs/innovation/emergence/phaseB_051_110.json`, blob `eb7c590f43c92ded0e328ecfdf7003fa7c06ceac` (60).

Offline rerun from this branch: `python3 docs/innovation/emergence/joint220_audit/validate_joint220.py --self-test`. The checker enforces source provenance metadata, exactly 110 B + 110 E sequential IDs, normalized title uniqueness, per-source record counts, specified player verbs, schema field declarations, keyboard/mouse/gamepad/touch plans, positive/negative acceptance, frozen defect preservation and a proposed erratum. The self-test deliberately corrupts 23 independent constraints; each must fail closed. The dedicated push-only workflow runs the same check without Codex or a PR.

**Provenance limitation:** the projection preserves source blob SHAs but is not the full original JSON. The checker verifies the projection against *pinned expected SHA metadata*, not a fresh Git blob-byte comparison; an independent full-source SHA verification and semantic human review remain mandatory before Phase C. No claims of semantic uniqueness follow merely from unique titles.

## Confirmed semantic defect and non-destructive correction proposal

**EB-E-102 Community Search Grid** has an unrelated eclipse-puzzle sentence in its negative acceptance, despite its cooperative search-grid state model. This is not a harmless cosmetic string: it would misdirect native acceptance and could allow missing consent, duplicate find receipts or overlapping volunteer assignments to go untested. The frozen `acceptance.adversarial`, `godot_acceptance`, and `adversarial_tests` require coordinated catalog-owner correction. The separate `SEMANTIC_ERRATA.json` proposes search-specific denials and **does not** modify source catalogs. E102 remains an open catalog defect until a reviewed source revision and test regeneration.

Cross-feature authority remains unresolved: Village owns consent and schedule; Principal owns atomic receipts, save schema, replay, inventory and command revisions; Emergence owns search proposals only. An offline consent denial must never teleport an NPC, debit inventory, grant a reward, or mark a cell searched. The feature must remain disabled until native integrated Godot acceptance proves those invariants.

## Remaining independent acceptance

An independent scenario-level review now records all **21 previously flagged title-similarity pairs** in `PAIR_TRIAGE.json`, with `validate_pair_triage.py` enforcing 9 hostile mutations. **18** appear mechanically distinct from their player scenarios and proposed state transitions, pending native/authority integration. **Three remain explicitly authority-blocked:** B084/E036 memorial-versus-kindness memory, E036/E077 kindness-versus-milestone archives, and E040/E075 storytelling-versus-welcome rituals. Village must own consent, visibility, correction and revocation across these boundaries. These are scenario-level dispositions, not proof of complete semantic uniqueness or integration acceptance; neither this mechanical audit nor typed-state tranche CI constitutes a full semantic sign-off. Validate all 21 pairs manually with distinct player verbs/state transitions and interface ownership. Compare the 220 source catalog proposals with the separate typed-state tranches and reject incomplete or conflicting schemas. Principal must reconcile authoritative economy/transactions, 56-day monotonic epoch, nested save migration, cross-domain effects, controller/touch parity and real performance budgets.

**Status:** E18 independent QA advanced; one frozen-source semantic defect isolated and 23 adversarial audit mutations required to reject. All 220 remain **design-only**, and the shared Phase-C implementation gate is **CLOSED**. Native baseline CI may run on this branch but does not establish new feature gameplay.
