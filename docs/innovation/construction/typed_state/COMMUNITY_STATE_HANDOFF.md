# EVERBLOOM Construction B081–B090 — community-event typed-state handoff

**Scope and evidence status:** Original, independently specified design contracts and a standard-library Python adversarial validator. **Not playable code.** No Godot scenes, save service, NPC schedules, navigation meshes, art, audio, or inventory have been modified. The shared 220-concept phase gate remains **CLOSED** pending independent audit and Principal authorization.

## Immutable provenance and ownership

- Canonical charter: `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Source concepts: `game/everbloom-construction-phaseB-100-20261102@f6b61bd73dede5703dcf8ef45ea24d47e28b8065`, blob `d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b`.
- Isolated branch based on canonical `main@a23694581967c980c7352fb08444578947703431`.
- Claim and handoff: GitHub issue #2. No PR because existing general validation has a pull-request trigger; never invoke Codex.
- Construction owns ghost placement, modular structures, local bounded proposals and typed schemas. Principal owns **all authoritative inventory/money/receipt mutations**, replay, `day_epoch`, schema registration and save migrations. Village owns consent, bookings and community memory; Farming owns water/weather/ecological supply; Valley owns geometry, collision, visibility and safe navigation.
- Catalog's material quotes are **provisional**; several source IDs (e.g. seed for screen construction) may require review. Never treat unknown material IDs as free. Preview and validator must never debit resources.

## Ten genuinely different state transitions

| ID | Feature | Critical state invariant | Principal/Village/Farming/Valley dependency |
|---|---|---|---|
| B081 | Floodline Emergency Walkway | All evacuation nodes above flood depth; connected path to a shelter | Authoritative hydrology, safe routes, accessibility |
| B082 | Frostlight Winter Relief Hall | Fuel conserved, enough heat, consented occupants, clear exits and capacity | Fuel settlement, NPC consent, winter weather |
| B083 | Sunrise Festival Pavilion | No stage overload, overcapacity, double-booking or blocked egress | Village booking authority, structural loads |
| B084 | Memory Grove Remembrance Craft | Active author permission and guardian consent; protected plots rejected | Village memory/consent, protected-land registry |
| B085 | Tempest Beacon Watchtower | Powered sound structure, visible signal route, unique event/day warning | Storm event identity, optical occlusion and replay |
| B086 | Wanderers Gallery Installation | Licensed consensual artwork, bay capacity, safe exits and booking exclusivity | Artist ownership and permission, public routing |
| B087 | Heritage Renovation Excavation | Survey and active permit, no protected digging, depth and find provenance | Protected heritage registry and artifact receipts |
| B088 | Moonshift Safe Construction | Consenting crew, night-only shifts, safe lighting, bounded fatigue and noise | Village schedules, worker welfare and lighting |
| B089 | Mosaic Commons Collaborative Mural | Each tile has valid contributor authority; pigments conserved exactly | Original art provenance, inventory settlement |
| B090 | Starlit Pop-up Picturehouse | Rights-cleared stories, stable weather-safe screen, capacity/accessibility and booking | Event/weather director, authored story permissions |

Each JSON record contains original catalog player verbs, scenario, input mappings, dependency map, original asset plan, unmeasured desktop/mobile performance targets, provisional resource quote, exact typed nested schema, two positive fixtures and feature-specific hostile mutations. Source `typed_value` aliases are mapped to explicit nested structures, not silently dropped.

## Deterministic tests and limits

Run from repository root:

```bash
python -m py_compile docs/innovation/construction/typed_state/validate_community_081_090.py
python docs/innovation/construction/typed_state/validate_community_081_090.py
```

The validator enforces exact IDs and namespace uniqueness, strict nested typing (booleans never accepted as integers), finite bounded arrays, foreign-key integrity, event scheduling, material conservation **inside design fixtures**, consent, provenance, duplicate receipt rejection, deterministic JSON roundtrips, hostile mutations, seeded typed-leaf fuzz and 112-day monotonic epoch acceptance. The fixture ledger does **not** prove global transaction conservation, save migration, native Godot gameplay, physical controls, or device performance.

Before any Phase-C work: Principal must verify 220 semantically unique concepts and authorize integration; establish transactional inventory receipts and replay dedupe across domains; validate full assembled Game save/load and rollback, Village consent revocation, Farming flood/heat/weather authorities, Valley nav/egress/occlusion and original art provenance. After that, build one interactive Godot vertical slice with keyboard/mouse, controller and touch parity, actual player feedback, native regression and measured desktop/mobile budgets.

**Risk notes:** B081 path model is graph-level only, not an actual navigation mesh; B085 visibility flag is not a raycast; B088 night shift rejects cross-midnight shifts until a properly bounded split-shift representation is designed; B090 content-rights flag must be backed by independent asset proof. These cannot be represented as complete gameplay.
