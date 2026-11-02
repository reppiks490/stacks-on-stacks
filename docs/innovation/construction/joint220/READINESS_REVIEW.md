# EVERBLOOM — 220-feature cross-branch readiness audit (Construction B19)

**Status:** evidence-backed design triage, **NOT Principal approval, semantic certification, implemented gameplay, or native Godot proof**. Godot 4.x remains the only active engine. Phase C is **CLOSED**. Generated 2026-11-02 from canonical `main@e0d3eaf10daa53f1082f3a253f49711bedcc725c` and exact pinned catalog commits; no gameplay source was changed.

## Frozen source receipts

| Catalog | Exact commit | Git blob SHA | Records |
|---|---|---|---:|
| B_A `docs/innovation/construction/phase1_ten_concepts.json` | `0c23b576fc255cce5130a547be549986b685c27e` | `1fbcafa552dfab5f03e0c22fbb929174dbaa5e87` | 10 |
| E_A `docs/innovation/emergence/phase1_ten_concepts.json` | `9ba5b83f2d11d18e23011093c08626b1057f9db2` | `883f73fdf8dd31177865107eef82a7125b2703b2` | 10 |
| B_B `docs/innovation/construction/phaseB_100_concepts.json` | `f6b61bd73dede5703dcf8ef45ea24d47e28b8065` | `d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b` | 100 |
| E_B1 `docs/innovation/emergence/phaseB_011_050.json` | `63cab5d05c742c61205933482e38fac2a4086764` | `a5def76918e77e0ded7e3e8085444698b4e0b549` | 40 |
| E_B2 `docs/innovation/emergence/phaseB_051_110.json` | `63cab5d05c742c61205933482e38fac2a4086764` | `eb7c590f43c92ded0e328ecfdf7003fa7c06ceac` | 60 |

The companion `READINESS_LEDGER.json` contains a per-feature provenance link, domain, player verbs, controls, state fields, proposed material inputs, explicit risk flags and a non-authorizing review status for **all 220 designs**. The ledger is a compact review index; the five full specifications remain on their original preserved branches. It is not a new canonical implementation source.

## Reproducible mechanical findings

- **220 records / 220 distinct exact IDs / 220 distinct case-folded titles**, split 20 Phase-A and 200 Phase-B, 110 Builder and 110 Emergence. This establishes identifier/title uniqueness, **not semantic uniqueness**.
- **21 title-token similarity pairs** (Jaccard >=0.25 after documented stop-word filtering) warrant semantic review; many are false positives. Six concrete pairs received preliminary human-readable triage below. No automatic rejection based solely on title similarity.
- **200 designs contain unresolved state field typing**: Builder Phase-B uses `typed_value` placeholders and Emergence Phase-B lists bare field names without concrete type definitions. Versioned schemas and migration rules are not implementation-ready. This is a **blocking specification gap**, not proof of a runtime bug.
- **106 designs reference proposed material IDs not present in the pinned baseline inventory/recipe output set**; counts by unverified ID: `fiber` (27), `clay` (25), `iron` (25), `glass` (25), `dye` (25), `seed` (24), `wildflower_seed` (1), `reed_seed` (1), `cloth` (1), `flower` (1), `dye_plant` (1), `apple` (1). Availability through future acquisition systems remains unverified. `gold` is currency and must use Principal's money ledger, not a material item.
- **0 records lack explicit touch or controller control-key presence; 0 lack a positive acceptance field; 0 lack a negative acceptance field.** These are presence checks only: real device performance, accessibility and actual Godot behavior remain untested.
- All new concepts remain design-only. Generic idempotency/preview boilerplate does not demonstrate a working atomic transaction, load migration or native replay.

## Six preliminary semantic and interface decisions

1. **EB-E-024 / EB-E-062 — distinct on review.** Tree beetle habitat intervention vs companion-guided stranded-animal rescue; separate authoritative state and player actions.
2. **EB-E-040 / EB-E-075 — distinct on review.** Editable consent-governed storytelling vs newcomer welcoming ceremony; shared NPC consent must be centralized.
3. **EB-E-036 / EB-E-077 — distinct on review.** Verified favors and reciprocity vs opt-in life milestone archive; unify visibility and revocation semantics.
4. **EB-B-053 / EB-B-107 — distinct on review.** Glass casting/annealing vs seasonal condensation decoration; Foundry supplies actual panes and Frostlace owns only cosmetic mask.
5. **EB-B-015 / EB-E-098 — distinct on review.** Curing mortar under weather constraints vs astronomical appointment puzzle; no shared state owner.
6. **EB-B-084 / EB-E-036 — needs interface contract.** Memorial garden dedications and social favors both handle consented resident memories; Village must own privacy permissions and revocation receipts.

**Remaining 15 flagged title pairs** are listed with IDs and scores in the JSON ledger; none are automatically approved. The 220 concepts also require broader semantic review beyond title overlap, especially multiple NPC memory, weather, construction logistics, hydrology and town-project proposals.

## Owner/authority gates before Phase C

1. **Principal:** approve explicit typed feature state schemas, save-service optional namespaces, inventory/currency authority, monotonic `day_epoch`, command revision/idempotency, full assembled snapshot migration and fail-closed corrupted data. Own final Phase-C authorization.
2. **Farming:** specify finite wood/stone/fiber/clay/iron/glass/dye/seed acquisition and crafting, source/sink accounting, runoff transfer and seasonal yield; reconcile with isolated F02 finite-water branch. Never credit one rain event twice.
3. **Village:** own NPC consent, privacy, job/festival time reservations and resident memory; construction crews and Emergence collaborations must request exclusive slots, not duplicate NPC agency.
4. **Construction:** replace `typed_value` with concrete bounded types, quantized transforms and stable IDs, typed socket compatibility, support graph, collision rules, single-debit materials, dependency-aware undo and LOD budgets. Start first physical cottage only **after** the 220 approval gate.
5. **Emergence:** type all Phase-B state fields, replace generic resource quotes with bounded authoritative cost contracts, bind causal event effects to owner adapters, and prevent replayed event rewards or duplicate construction material transfers.
6. **Independent QA:** after approval and real Godot code, test full-house placement/undo/save/reload, 112-day replay, crash recovery, invalid saves, touch/controller intent parity and actual mobile/PC performance at the exact implementation SHA. Catalog format tests do not satisfy this gate.

## Proposed first implementation acceptance sequence (NOT AUTHORIZED)

**Slice 1 — B02/B03/B13:** unified pure placement preview, typed anchors, deterministic command IDs, stale revision rejection and exact inventory rollback. **Slice 2 — B01/B04/B07:** terrain survey, foundation/support graph, framing and roof enclosure with meaningful material/structural rules. **Slice 3 — B06/B09/B10/B15:** door/stair navigation, habitable-room effects, furnishings and NPC comfort. **Slice 4 — B08/B11/B12/B18:** fictional utility network, blueprints, labor and restoration events. All require assembled save/replay, accessibility, original rights-verified assets and device budgets. Do not port to Unreal/Unity until verified Godot baseline and owner decision.

## Limitations and next handoff

This run read all five full catalogs at exact pinned Git commits, current `main` game inventory/recipes, charter, coordination and issue #2. The analysis is **static design triage**; no Godot runtime was available in this execution environment, no native tests were executed, and no source or gameplay file was modified. The per-feature ledger and independent offline validator are prepared for Principal review; **Principal sign-off remains outstanding**. No PR was opened, and no Codex was used.
