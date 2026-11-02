# EVERBLOOM — Emergence Phase A: ten original features and independent audit

**Status:** 10/10 Emergence concepts fully specified; **not implemented gameplay**. Combined Builder + Emergence is 20/20 **documented across two isolated branches**, but not yet reconciled into one tested checkout or accepted by Principal. Phase B (+200) and Phase C (Godot implementation) remain gated until the 20-idea review is recorded. No other lane's source was changed.

## Source receipts and path ownership

- Baseline canonical `main`: `39f2fe3f9b6168d09aa01f7e51ea4dbb7e52081a` (checked November 2, 2026).
- Emergence isolated branch: `game/everbloom-emergence-phase1-20261102`, owned namespace `docs/innovation/emergence/**` and dedicated read-only workflow `.github/workflows/everbloom-emergence-catalog.yml`.
- Builder isolated branch: `game/everbloom-construction-phase1-20261102`, exact audited SHA `0c23b576fc255cce5130a547be549986b685c27e`, catalog `docs/innovation/construction/phase1_ten_concepts.json`.
- Canonical 100-mission charter: `game/everbloom-100-mission-charter-20261102` at `b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Emergence spec file: `phase1_ten_concepts.json`; validator: `validate_catalog.py` (stdlib only; `--self-test` runs 12 invalid-catalog mutation checks).
- Existing `scripts/game.gd`, `farm.gd`, `village.gd`, `valley.gd`, `save_service.gd`, `tests/**` and seven existing workflows remain unchanged.
- **No Codex, PR creation, unapproved spending, copyrighted extracted assets, publication, forced pushes, or engine port.** New assets are only original art plans, not copied meshes/audio.

## E01 current-source novelty audit

Current `main` already implements a Godot valley, crop beds, animal care, village talks/gifts/jobs, four original festival interactions, static quests, fishing/foraging, saved domain state and 56-day annual clock. These are **real existing source components** and must not be rebranded as inventions. `scripts/valley.gd` still uses a static lake and primitive buildings; `data/world.json` declares five regions but does not prove seamless world streaming or actual traversal mechanics. `data/quests.json` contains four simple progression quests. No current source proves the ten emergent mechanics below exist.

**Specific source defect for Principal/Valley owner:** at `main@39f2fe3`, `scripts/valley.gd` uses `fishing_day == game.day` and `forage_day != game.day`, not `game.day_epoch()`, and `game.save_game()` does not serialize Valley fishing/foraging cooldowns. Reloading or reaching the same day number in a new season can bypass/incorrectly retain daily gates. Do not silently edit Principal or Valley files from this innovation lane; request a monotonic epoch + save/load contract and native exploit regression. An isolated World Art candidate had proposed epoch corrections, but its integration status must be rechecked at exact HEAD.

## Emergence feature inventory

| ID | Original mechanic | Distinct player-facing outcome | Primary mission |
| --- | --- | --- | --- |
| EB-E-001 | Causality Loom | Observe why events occur, choose bounded responses, review persistent consequences | E04 |
| EB-E-002 | Riverglass Accord | Test water quality, restore fish passage and manage catch limits | E05 |
| EB-E-003 | Lantern Letters | Verify private claims, respect consent and deliver consequential promises | E07 |
| EB-E-004 | Wayfarer Pulse | Reserve finite caravan stock, resolve weather delays and settle fair trades | E08 |
| EB-E-005 | Starpath Almanac | Align fictional seasonal stars and solve alternate-route world mysteries | E11/E14 |
| EB-E-006 | Wildsign Atlas | Track migrating wildlife ethically with optional companion assistance | E05/E10 |
| EB-E-007 | Tradition Seedbank | Propose and host NPC-approved rituals that evolve across years | E06 |
| EB-E-008 | Pattern Orchard | Design original weave grids and trade unique crafted textiles | E13 |
| EB-E-009 | Mistwake Passage | Navigate depth-aware canoe routes with accessible assist and safe moorings | E09 |
| EB-E-010 | Neighbor Chorus | Coordinate consenting NPCs on offline chores with exact shared rewards | E16 |

Every JSON record specifies distinct verbs, scenarios, simulation rules, versioned state, command/service contracts, desktop/gamepad/touch controls, original asset requirements, performance budgets, deterministic Godot acceptance, adversarial cases, resource/refund ledger, migration considerations and explicit Builder ownership boundary.

## Independent cross-loop comparison

Builder concepts `EB-B-001..010` are physical placement, terrain foundations, staged house assembly, roof capture, functional rooms, fictional utilities, blueprints, construction crews, salvage and climate-responsive houses. Emergence `EB-E-001..010` instead owns event causality, regional ecology, consent-aware narrative, caravan logistics, sky puzzles, wildlife observation, evolving rituals, textile creation, canoe travel and nonconstruction collaboration. A direct inspection of both catalogs at their exact SHAs found **20 distinct IDs, 20 distinct titles and 20 distinct domain keys**.

Potential overlap boundaries that require Principal/owner acceptance:

1. **B-004 rain capture vs E-002 watershed:** B owns roof collection and cistern accounting; E owns fish migration, habitat quality and catch stewardship. Farming F02 supplies runoff, and no water may be minted by duplicate systems.
2. **B-008 construction crews vs E-010 chores:** B owns physical construction labor and building costs; E owns nonconstruction harvest/supper collaboration, with Village retaining NPC consent/schedules.
3. **B-005 household memory vs E-003 promises:** B owns spatial room/household comfort; E owns private letters, evidence and promise outcomes; Village retains relationship authority.
4. **B-010 climate homes vs E-001/E-007 events:** B owns building weathering/insulation; E owns general event graph and opt-in rituals, and Village retains fixed festivals.
5. **B-007 blueprints vs E-008 textile patterns:** B owns structure graphs and building templates; E owns 8x8 textile motif recipes and maker markets.
6. **B-002 terrain foundations vs E-009 canoe travel:** B owns terrain/building supports; E owns bounded water-route navigation and accessible travel, subject to Valley owner approval.

**Mechanical review:** unique IDs/titles/domains checked from the actual two JSON catalogs; full 20-record review is proposed, not yet a merged cross-loop CI result. The new validator accepts `--builder-file` once both catalogs coexist in the same checkout; do not count a source-only catalog test as Godot gameplay.

## Required phase-gate protocol

1. Principal acknowledges exclusive `docs/innovation/emergence/**` ownership, audits the six boundaries above and coordinates safe merge/reconciliation of both catalog branches into a single candidate without overwriting either.
2. Run `python3 docs/innovation/emergence/validate_catalog.py --builder-file docs/innovation/construction/phase1_ten_concepts.json --self-test` in the same checkout; also run Builder's validator. Review content quality manually and require exact SHA green read-only CI. Record **20/20 accepted** with evidence in issue #2.
3. Only then begin phase B: Builder `EB-B-011..110` (100 additional) and Emergence `EB-E-011..110` (100 additional), all substantive and deduplicated, **220 total**. Maintain a machine-readable ledger and no filler.
4. Only after phase B acceptance begin modular Godot implementation. Emergence's recommended first slice: E-001 causal event + one Village request + one Farming effect, with replay/save/load and negative idempotency tests. Builder separately leads tangible house construction. Do not port to Unreal/Unity until owner-approved decision after playable Godot baseline.

## QA, asset and device truth

- This run writes **specifications and a catalog validator only**. It does not implement E-001..010 in the game, does not change save schema, and cannot prove native Godot gameplay or physical controller/touch behavior.
- New workflow executes only checkout, Python stdlib validation and read-only policy checks; existing `main` workflows were audited for prohibited Codex and privileged triggers. General Godot source workflow may also run on branch push; record its exact SHA before claiming a pass.
- Render budgets are **targets**, not measured FPS/thermal data. Original art and audio are future authored deliverables with license provenance; no imported game assets.
- Follow up on `valley.gd` daily cooldown/persistence defect, then prioritize true cross-domain event transactions, save migration, input parity and performance tests.
