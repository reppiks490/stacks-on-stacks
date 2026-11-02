# EVERBLOOM Emergence E051–E060 — Exploration Navigation State Handoff

**Missions:** E03, E09, E18. **Status:** design-only, NOT implemented or native-tested. **Phase C:** CLOSED pending Principal acceptance of the entire 220-concept ledger. Godot 4.x remains the sole implementation engine.

## Provenance and ownership

- Source is immutable Phase-B `game/everbloom-emergence-phaseB-100-20261102@63cab5d05c742c61205933482e38fac2a4086764`, `docs/innovation/emergence/phaseB_051_110.json`, blob `eb7c590f43c92ded0e328ecfdf7003fa7c06ceac`.
- Working branch `game/everbloom-emergence-e09-navigation-types-20261102` originated from `main@86aa22c9e7806d85f42b95a8fbd27bbba122a556`. Only new Emergence design/validator/workflow files were claimed; no shared game source, save, assets or other branches modified.
- `navigation_051_060.json` defines 10 bounded, typed, engine-neutral state contracts; `validate_navigation_051_060.py --self-test` rejects malformed fixtures, inconsistent cross-fields, unsafe integer ranges, missing/extra keys and duplicates. JSON serialization roundtrips are **schema fixtures only**, not a native game-save demonstration.
- Principal owns world commands, revisions, day_epoch, authoritative reward receipts and save admission. Valley/Principal own movement, navigation, terrain, water, collision and safe return. Farming owns burrow protection, snow and ecological effects. Village owns NPC property privacy and community consent. Emergence owns discovery projections, clue semantics and independent negative tests. No shadow inventory, reward or NPC ownership.

## Ten original mechanics and blocking integration contracts

| ID | Design acceptance and critical denial |
|---|---|
| E051 | Triangulate three distinct fogbell markers; repeated single-bell observations cannot satisfy route completion. |
| E052 | A bounded low-water cave window must have a durable, independent exit anchor; an in-cave reload cannot strand the player. Current schema validates an exit reservation, but real world teleport/evacuation remains unimplemented. |
| E053 | Snow route costs account for each executed step; protected burrow cells cannot be traversed or overwritten. |
| E054 | Bird-call graph has visible, non-audio alternatives; only valid graph edges may unlock the overlook. |
| E055 | At least two independently logged outcrops support a verified regional path hint; one note cannot unlock other regions. |
| E056 | Day-epoch and fixed seed bind leaf clues to one deterministic day; permanent replay prevention needs Principal command receipts. |
| E057 | Shallow pool waypoints must be surveyed at the same epoch and retain an independently safe shore return. Live depth/navmesh changes must invalidate unsafe routes. |
| E058 | The entire glowing trail and bounded twilight window precede grove discovery; gathering rewards must settle once via Principal. |
| E059 | Kite survey remains tethered and confined to public valley views; no private NPC interior cameras. |
| E060 | Every required landowner consent is present before opening a historical footpath; protected land cannot be opened. |

## Implementation gate — NOT YET MET

1. Principal reviews semantic uniqueness of all 220, state version/migration and globally durable command-id replay protection; issue #2 remains the authority for handoff, not an approval by itself.
2. Valley/Principal implement a safe-return fallback on load and changing water/weather/collision for E052/E057. An exit reservation **alone is not proof** of no softlock.
3. Farming signs off on snow/habitat and tide/depth data ownership; Village signs off on consent/privacy; construction owns any physical path work.
4. Implement actual Godot player verbs, visible HUD feedback, original provenance-verified art/audio and reduced-motion/text alternatives. Validate keyboard/mouse, controller and touch input equivalence with native tests and real device measurements.
5. Reconcile authoritative inventory and reward receipts across duplicate commands, stale revisions, save/load, two-year 56-day calendar rollover, and corruption recovery. Verify full assembled-game state; no simulation-only acceptance.
6. Measure proposed budgets on desktop and mobile; `performance_budget` values are planning targets, not benchmarks.

## Reproduction

```bash
python3 docs/innovation/emergence/typed_state/validate_navigation_051_060.py --self-test
python3 -m py_compile docs/innovation/emergence/typed_state/validate_navigation_051_060.py
```

Dedicated push-only non-Codex workflow: `.github/workflows/everbloom-emergence-navigation-types.yml`. Existing general workflow performs Godot baseline verification independently. Neither proves these designs are playable. No PR was created because generic validation listens to `pull_request`, and auto-review cannot be guaranteed absent.

**Final SHA and exact-head CI:** to be appended in issue #2 only after observed completion; never infer success from workflow creation.
