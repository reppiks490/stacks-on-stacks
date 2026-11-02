# EVERBLOOM Construction Phase B — 100-concept handoff

**Status:** 100 new Construction-owned *design specifications* authored; dedicated offline integrity audit passed on commit `6988b67abe6de0b147cba9ad72c8985f5c0680c2`. They are **not playable features**. No Godot gameplay source, shared save, existing workflows, or other lane paths were edited.

## Authorization and lineage

- Canonical charter: `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Starting canonical main: `593c0296a94549119b4b5ad93149be7f31a9eb68`.
- Frozen Construction Phase A: `game/everbloom-construction-phase1-20261102@0c23b576fc255cce5130a547be549986b685c27e`, EB-B-001..010.
- Frozen Emergence Phase A: `game/everbloom-emergence-phase1-20261102@9ba5b83f2d11d18e23011093c08626b1057f9db2`, EB-E-001..010.
- Principal accepted Phase A and eight ownership boundaries **for Phase B documentation only** in [issue #2](https://github.com/reppiks490/stacks-on-stacks/issues/2#issuecomment-6573235593). No Phase C authorization.
- This isolated branch: `game/everbloom-construction-phaseB-100-20261102`, new IDs EB-B-011..110. Emergence owns EB-E-011..110 independently; no assumption that its additional 100 have been authored or accepted.

## 100 concept breakdown

Ten distinct proposals in each domain:
1. Structural design: surveying/easements, tremor bracing, timber joinery, curved geometry, curing, snow loads, stair navigation, cargo lifts, thermal envelopes, wind braces.
2. Interior living: acoustic privacy, daylight shafts, partitions, physical shelves, pantry spoilage, kitchen routes, finite greywater, botanical finishes, hearth clearances, accessible ramps.
3. Civic construction: bridges, habitat boardwalks, community halls, market stalls, street lighting, storm shelters, communal gardens, transit stops, wayfinding, apprenticeship classrooms.
4. Ecological landscape: root-safe terraces, hedgerows, creek fords, fish ladders, rain basins, compost treatment, meadow roofs, aeration, sediment fences, treehouse decks.
5. Material crafting: sawmills, kilns, glass annealing, stone cutting, cordage, forging, plaster, embossed tiles, salvage grading, bespoke furniture.
6. Site logistics: cargo trolleys, wheelbarrows, finite storage, permits, staging, deliveries, scaffolds, safety drills, counterweight cranes, weatherproof stockpiles.
7. Household function: guest rooms, pet safety, adaptable nurseries, accessible elder homes, shared household rights, home shops, quiet workshops, sunrooms, observatories, cellars.
8. Community events: flood walkways, winter relief, festival pavilions, consensual memorials, beacons, exhibitions, heritage excavations, night repair, murals, open-air cinema.
9. Engineering tooling: dependency lens, mesh checks, material passports, parametric lattices, exact measurements, habitability certification, load tests, demolition quotes, receipt chronology, universal accessibility audit.
10. Architectural art: living trellises, patina, seasonal awnings, shadow lanterns, footstep sound gardens, reflective courtyards, frost glass, kinetic art, astronomical skylights, evolving facades.

Each record contains a distinct player action, simulation invariant, state keys, normalized commands, UI controls for keyboard/mouse/controller/touch, original asset plan, proposed material quote, portability boundary, native acceptance scenario and adversarial checks. The domain-level command and control scaffolding is deliberately shared for compatibility; **these are proposed contracts, not existing engine APIs**.

## Critical integration blockers and caveats

1. **Material IDs not yet implemented.** The inspected canonical `scripts/game.gd` initializes `wood` and `stone` but not proposed `iron`, `fiber`, `clay`, `glass`, `dye`, `seed` (as a generic item), or other new crafting materials. The numeric quotes are *design-stage balancing targets*, not executable recipes or valid existing inventory transactions. Farming and Principal must authorize new catalog IDs, acquisition routes, integer accounting and save migration before Phase C. Do not silently treat absent resources as free.
2. **No authoritative construction command bus exists yet.** Principal must implement or approve typed inventory debits, stable world revisions, assembled save fields and idempotent receipts before Builder gameplay integration. The Phase-A X-01..X-08 boundaries remain the governing contracts.
3. **Cross-catalog novelty is pending.** This validator verifies the Builder tranche internally (IDs, unique titles, domains, required fields and 15 negative mutations); it does not prove the new Emergence 100 have no semantic overlaps. Principal must perform the combined 220-feature review with both immutable source SHA snapshots.
4. **Acceptance is not gameplay proof.** The dedicated Python audit is a design-integrity test. The general Godot CI, when green, only validates the existing Godot baseline. No physical touchscreen/gamepad tests, FPS measurements, newly modeled assets or construction mechanics are claimed.
5. **Phase C is CLOSED.** No new construction or Emergence feature implementation until all 220 distinct concepts are verified, Principal accepts joint boundaries, and a Godot-first implementation plan is approved. Existing Principal/Farming/Village baseline repairs remain independently authorized.

## Evidence and next handoff

- [Phase B catalog](phaseB_100_concepts.json)
- [Offline validator](validate_phaseB_100.py)
- [Dedicated non-Codex workflow](../../../.github/workflows/everbloom-construction-phaseB.yml)
- [Exact-source dedicated catalog audit PASS](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41423094115) — 100 specs in 10 domains and 15 rejected invalid mutations.
- General Godot/Python CI at the final branch tip must be checked separately; do not reuse an older green run as final-HEAD evidence.

**Next owner actions:** Emergence authors its disjoint EB-E-011..110; Principal compares the combined 220 concepts for functional duplication, save/interface collisions, resource feasibility and scope realism; Farming specifies viable material acquisition; Village checks NPC consent and schedule ownership; Construction remains on isolated documentation and feasibility work until Phase C opens.

**Operational safety:** No Codex, PR, force push, merge, paid tool, copyrighted asset import, external publication or Unreal/Unity migration.
