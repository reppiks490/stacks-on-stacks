# Construction Inventor — Phase A handoff (10 of 20 initial concepts)

**Status:** Ten original, individually specified construction ideas exist as *design specifications*, not implemented gameplay. All remain `specified_pending_review` until the Emergence Inventor adds its ten distinct concepts and Principal checks novelty and interface overlap. This is not the 220-feature gate.

## Exact source and ownership

- **Starting canonical main:** `39f2fe3f9b6168d09aa01f7e51ea4dbb7e52081a` (Principal recovery-resume integration).
- **Isolated branch:** `game/everbloom-construction-phase1-20261102`. Only new `docs/innovation/construction/**` and a new read-only non-Codex `.github/workflows/everbloom-construction-catalog.yml` are touched. No edits to `scripts/game.gd`, `scripts/valley.gd`, `scripts/farm.gd`, `scripts/village.gd`, `tests/**`, save schema, or existing workflows.
- **Machine-readable specification:** `phase1_ten_concepts.json`. Every record includes unique ID, novelty audit, player scenario and verbs, concrete player loop, state schema, commands and interfaces, mouse/controller/touch mapping, art provenance plan, desktop/mobile budgets, positive and negative acceptance, migration risks, effort, dependencies and material conservation.
- **Validation:** `python3 docs/innovation/construction/validate_catalog.py --self-test`; eight deliberate malformed-catalog mutations must be detected. The dedicated workflow validates this on branch pushes. This tests *documentation integrity*, not Godot engine behavior.
- **No Codex, PR auto-review, spending, copyrighted asset copying, publication, forced history changes or premature Unreal/Unity port.**

## Ten new concepts and their distinct player loops

| ID | Feature | Direct player outcome | Main dependency |
| --- | --- | --- | --- |
| EB-B-001 | Joinery Loom | Six consistent click-and-stick placement modes, precise previews, safe undo | Interaction router, StructureGraph, Inventory |
| EB-B-002 | Groundweave | Slope-aware terrace/pier/pad foundation decisions, protected farmland | TerrainQuery, FarmOccupancy |
| EB-B-003 | Framewright | Build a house in real visible foundation/frame/shell/habitable stages | StructureGraph, construction ledger |
| EB-B-004 | Rainroof Atelier | Roof and gutter design physically harvests bounded rain for farm use | Farming F02 hydrology contract |
| EB-B-005 | Roomheart | Built rooms affect warmth, NPC consent, household routine and comfort | VillageLife, Navigation, save |
| EB-B-006 | Hearth Threads | Fictionalized capacity-limited light/heat/water socket networks | Roomheart, typed sockets |
| EB-B-007 | Memory Blueprints | Copy plans, not resources; adapt houses to terrain with staged cost | StructureGraph, TerrainQuery |
| EB-B-008 | Village Build Commons | NPC-assisted community projects and paid construction shifts | Village schedules, economy, navigation |
| EB-B-009 | Salvage Ledger | Dependency-safe dismantling and material-quality-conserving salvage | StructureGraph, inventory |
| EB-B-010 | Seasonwright Homes | Climate-responsive homes, insulation, seasonal wear and habitat tradeoffs | Weather, Village comfort, Farm pollination |

## Proposed implementation order after 220-feature gate

**Vertical slice 1:** EB-B-001 + EB-B-003 + EB-B-009 (one cottage post/floor/wall/roof; ghost/snap/freeform; material charge, cancellation, undo and exact save/load). The goal is a tangible player-built house from scratch, not static decorative placement.

**Vertical slice 2:** EB-B-002 + EB-B-007 (terrain foundation and reusable blueprints). Preserve existing farmland and the current procedural valley. Never mutate terrain or farm state without agreed interfaces.

**Vertical slice 3:** EB-B-005 + EB-B-010 (habitable room and weather comfort with NPC/farm effects). Requires Village/Principal domain contract approval and a real native assembled-save regression.

**Vertical slice 4:** EB-B-004 + EB-B-006 + EB-B-008 (rain capture, fictional utility routing, NPC construction). Cross-system resource conservation and native tests are mandatory.

These priorities are provisional and must be reconciled with the other 210 ideas and Principal's baseline gates.

## Interface proposal for Principal / Farming / Village / Emergence

1. **Immutable preview:** `preview_part(site_id, part_id, mode, transform, world_revision)` returns `{valid,reasons,anchors,cost}`; never consumes materials.
2. **Atomic transaction:** `commit_placement(command_id, revision)` validates structure and inventory together; identical command IDs are idempotent. Undo uses a dependency-aware inverse and a precise refund ledger.
3. **Canonical state:** IDs, quantized meter transforms, graph edges, staged build progress, room usage, material receipts and versioned blueprint records are persisted through the *assembled* game coordinator, not in an isolated duplicate save file.
4. **Calendar:** weather/aging/water capture and NPC shifts use `game.day_epoch()`, never `game.day` alone. Rainwater, wages and salvage are accounted exactly once.
5. **Input adapters:** map pointer, touch and controller to the same intent commands. Preview reasons must have text/icon alternatives for accessibility.
6. **Rendering:** Godot is the only implementation target until a verified playable baseline. The state graph is engine-neutral, while meshes, navigation, collision, lighting, sounds and shaders remain replaceable adapters for a later owner-approved Unreal 5/Unity 6 decision.
7. **Current world caveat:** `scripts/valley.gd` creates a static primitive farmhouse and flat land, so this is **new gameplay**, not an existing construction feature. Godot native interaction, actual device performance, terrain modifications, NPC housing and new save compatibility are not yet proven.

## Shared 220-feature gate

**First:** Builder has 10 IDs `EB-B-001..010`; Emergence must independently provide 10 IDs `EB-E-001..010` and cross-deduplicate all 20.

**Second:** after 20 pass review, Builder adds 100 new unique IDs `EB-B-011..110` and Emergence adds 100 `EB-E-011..110`. No filler, reskins or schema-only entries.

**Third:** after all 220 unique records pass substantive specification and overlap checks, implement staged Godot gameplay with genuine native and real-device acceptance. Existing baseline repairs by other roles may continue meanwhile.

**Handoff request:** Principal should confirm the construction-owned namespace and eventual command/save adapter boundaries. Emergence should avoid the ten above, especially structural placement, terrain foundations, blueprint duplication, salvaging and construction labor, and focus on distinct systemic world mechanics. This document is a handoff request, not evidence of acknowledgement.
