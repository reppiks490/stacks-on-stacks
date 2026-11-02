# EVERBLOOM — Emergence E061–E070 companion-state handoff

**Scope:** E03, E10 and E18. Ten original companion intelligence feature **design contracts**, NOT implemented Godot gameplay, production assets, authoritative save migrations, or mobile performance evidence.

## Immutable sources and ownership

- Canonical mission charter: `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Original 100-feature Emergence Phase-B ledger: `game/everbloom-emergence-phaseB-100-20261102@63cab5d05c742c61205933482e38fac2a4086764`, source blob `eb7c590f43c92ded0e328ecfdf7003fa7c06ceac`.
- Isolated branch `game/everbloom-emergence-e10-companion-types-20261102` based on `main@07546c9402bd0d44c899719a115c1a46b91d85cc`. Only NEW Emergence typed-state docs/validator and dedicated push-only CI are in scope.
- Read `docs/CROSS_LOOP_COORDINATION.md` and issue #2 before claiming work. Main workflow has `pull_request` trigger; no PR created. No Codex, proprietary assets, unapproved spending, publication, destructive Git, force pushes or engine migration.

## Design-state rules (all require later native implementation)

| ID | Mechanic | State integrity and negative proof target |
|---|---|---|
| E061 | Scent Mosaic Tracker | Unique samples, finite confidence gain, rest epoch; replayed sample cannot maximize skill. |
| E062 | Rescue Bark Triangulation | Two distinct alerts, reachable target, stamina and unique rescue receipt; no teleport or double rescue. |
| E063 | Herd Whisper Formation | Consented livestock waypoint proposals, reject animals assigned elsewhere; Farming alone commits movement. |
| E064 | Comfort Companion Signals | Bounded per-epoch relief and mandatory pause under high stress; petting cannot instantly cure. |
| E065 | Burrow-Safe Treasure Sniff | Protected cells cannot yield finds, fatigue cannot be bypassed, unique search receipts. |
| E066 | Weather-Savvy Companion Shelter | Monotonic warning epoch, optional available shelter and nonfatal rest state. |
| E067 | Trail Partnership Rotation | Distinct active/standby, owned segment receipts and no swap while action pending. |
| E068 | Companion Gesture Lexicon | Learned and mapped accessible cues, visual fallback, consent; no audio-only prerequisite. |
| E069 | Wildlife Distance Etiquette | Protected nest radius, observation epoch and knowledge-only rewards; no close approach. |
| E070 | Senior Companion Mentorship | Distinct mentor/learner, finite completed lessons, welfare consent and no canceled skill grant. |

The machine-readable JSON includes strict nested fields, player scenario/verbs, input mappings, original art plan, proposed **unmeasured** desktop/mobile budgets, Principal command receipts and save migration gate. The Python validator checks two positive states per feature, four feature-specific invalid patches, missing/unknown fields, wrong types, duplicate/oversized collections, integer bounds, boolean-as-integer rejection and deterministic JSON roundtrips. It is **not** a native Godot gameplay test. Read exact-HEAD workflow result before claiming a PASS.

## Cross-owner gates and future acceptance

**Principal:** owns `day_epoch=(year-1)*56+season_index*14+day`, globally durable idempotent command IDs, save namespace/version migrations, receipt settlement, authoritative economy and assembled-game recovery. Reject stale revisions and unknown nested fields atomically.

**Farming:** owns animals, welfare/energy, livestock assignments and companion fatigue; companion proposals must never directly mutate livestock or grant skill, goods or money. **Valley/Construction:** owns terrain, protected nests, route reachability and collision; E065/E069 must not alter protected habitats. **Village:** owns resident consent and any NPC dialogue. Emergence owns only future companion choice logic, UI projections and adversarial feature tests.

**Native Phase-C gate:** only after independent and joint 220-feature ledger approval, implement a bounded Godot 4.x event -> player choice -> animal/world consequence -> save/replay vertical slice with real keyboard/mouse, controller and touch interaction, negative receipt/rollback tests, two-year calendar replay, original asset provenance and measured device budgets. Current ten designs do not grant Phase-C authorization. Existing Godot baseline may continue to be repaired by its owners.

**Known limits:** Local receipt uniqueness is not lifetime/global exactly-once settlement; `reachable=true` is a proposed state field, not actual navmesh reachability proof. E064 relief conservation across multiple sessions requires an authoritative durable welfare ledger. E070 progress must be settled by Farming, not this design projection. No live save fields have been changed.
