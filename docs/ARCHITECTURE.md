# EVERBLOOM — Integration architecture and persistence contract (principal lane)

**Status:** Active original game development. Canonical `main` at the start of this principal change was `bfd389a`, with [general native CI](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398474611) and [56-day farming native acceptance](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398474589) passing. The isolated principal save-integrity branch received its first [19-assertion native Godot PASS](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41399615671) at `8b4cea2`; it remains independent until exact final SHA gates pass. No completed-game, mobile, visual-quality or crash-durability claim is established.

## Runtime topology (observed from current integration branch)
```
scenes/main.tscn
  └─ scripts/game.gd — session coordinator, input, calendar, economy, save/load
      ├─ scripts/valley.gd — procedural valley, paths, lake, forest, foraging/fishing
      ├─ scripts/farm.gd — 30 planting beds, crop interactions, watering/growth
      ├─ scripts/village.gd — original residents, talk/gifts, affection
      ├─ scripts/animals.gd — barn animals, feeding/care and products
      ├─ scripts/farmer.gd — CharacterBody3D controller
      └─ scripts/hud.gd — readable on-screen status and controls
data/{world,crops,villagers,animals,recipes,quests}.json
assets/provenance.json and original SVG
```
These are actual tracked source components, not proof of full gameplay, polish or native correctness.

## Contract A: deterministic calendar
Game orchestrator is the sole calendar authority: `year >= 1`, `season_index = 0..3`, `day = 1..14`, `minute_of_day`, `weather`. 4 seasons × 14 days = 56 days/year. A monotonic `day_epoch() = (year-1)*56 + season_index*14 + day` is required for once-per-day talk, gift, animal care and festival triggers. Using `season_index*14+day` alone repeats epochs every year and incorrectly blocks annual interactions. All domain modules must accept calendar snapshots, not mutate global date. Weather must be reproducible for a given calendar and save state.

**Current state:** `game.gd` persists `year`, increments at Winter rollover and exposes `day_epoch()`. `farm.gd` and `animals.gd` now consume that monotonic epoch; the native Farming acceptance exercises the year-two animal-care case. **Village correction:** separate Village commit `df15d515` changed talk/gift admission to `game.day_epoch()` and added two-year native regression coverage. Its native test and canonical integration result must be confirmed at the new HEAD before marking that gate closed.

## Contract B: persistence
Current `game.gd` writes `user://everbloom_save_v1.json` with `schema=1`. Retain compatibility for existing schema-1 saves. Required persisted fields: `year` (optional in pre-upgrade v1; default 1), `day`, `season`, `minute`, `gold`, `energy`, `weather`, `restoration`, `crops_harvested`, `social_contacts`, `care_actions`, `inventory`, `farm`, `village`, `animals`, `hero_position`. Domain save structures are delegated to their owners.

**Acceptance:** Save/load round trip across a seasonal rollover, no item duplication, no negative balances, corrupted/unknown-schema rejection, preservation of the current session on invalid saves, backup and migration fixtures. Integrated `scripts/save_service.gd` adds schema-1 validation, temporary-file readback, previous-primary backup and backup fallback. **Native Godot filesystem roundtrip and deliberately corrupted-primary recovery passed** at `29a5c083` ([run 41398131319](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398131319)). Power-loss crash consistency, file-lock behavior, data-conservation and save migration are still unverified. Future v2 requires explicit migration and preserved backups. No silent overwrite of corrupt primary data. The isolated principal save-integrity branch adds finite-number checks, integer-precision conservation (up to JSON's exact 2^53−1 boundary), disallows negative/fractional inventory or gold, rejects malformed farm and livestock shapes, validates year/season/day/coordinates and rejects nested non-JSON state. A separate native Godot test executes 19 adversarial assertions; existing valid/legacy schema-1 layouts remain supported.

## Contract C: domain ownership and integration
- **Principal:** `scripts/game.gd`, `project.godot`, architecture, shared API contracts, time/save orchestration, merge decisions.
- **Farming:** `scripts/farm.gd`, `data/crops.json`, crops/economy/soil/tool upgrades. Public methods: `setup(host)`, `act(tool, world_position) -> String`, `next_day(weather)`, `save_state() -> Array`, `load_state(Array)`.
- **Village:** `scripts/village.gd`, `data/villagers.json`, `act(action, world_position)`, `next_day()`, `save_state() -> Dictionary`, `load_state(Dictionary)`. Must use monotonic day epoch.
- **Animals:** `scripts/animals.gd`, `data/animals.json`, `act(world_position)`, `next_day()`, `save_state() -> Dictionary`, `load_state(Dictionary)`. Must use monotonic day epoch.
- **Art/world:** `scripts/valley.gd`, original world assets, `setup(host)`, `act(action, world_position)`. Must support future world-streaming without breaking save schema.
- **QA:** `tools/validate_project.py`, `tests/**`, non-Codex CI, native Godot smoke and regression evidence. Principal supplied an interim validator to unblock broken CI; QA takes ownership and expands it.

All domain actions return user-facing messages now; migrate to typed action result contracts (`success`, `reason`, `inventory_delta`, `energy_delta`, `event_id`) when tested. Cross-domain effects should be emitted once, with transaction IDs to prevent duplicated grants on reload.

## Contract D: simulation & accessibility
Target 60 FPS on desktop and measured 30/60 FPS mobile modes; these are goals, not measured facts. Camera follow and keyboard movement are implemented in source. Controller/touch remapping, scalable UI, accessibility, character animation, interior scenes, asset streaming, LOD, localization, robust input and perf profiling remain unverified. No copyrighted game assets or extracted commercial models/audio may be redistributed.

## Non-Codex acceptance gates
1. Review exact branch HEAD, workflow triggers and external integrations before PRs; **no Codex CLI/agents/bots/reviews**.
2. Offline validator + unit tests pass.
3. Exact SHA Godot 4.7.2 `--headless --editor --import --quit` succeeds with no script/resource errors.
4. Same SHA `--headless --quit-after 120` succeeds with no runtime errors.
5. QA records artifact logs and checks real input/save/season/animal/villager behavior; 120 frames alone cannot prove interactions.
6. Provenance/licensing audit; original assets or rights-verified external resources only.
7. Integrate isolated branch non-destructively only after checks; never force-push/delete history.

## Open technical risks
- Prior CI failed before native tests because `tools/validate_project.py` was missing. QA supplied a stronger validator and tests; this blocker is **resolved** at merge commit `63370c98`.
- No independent gameplay tests for crop progression, inventory conservation or save recovery.
- Village and animal care both use monotonic epoch after Village commit `df15d515`; verify the Village native workflow at its exact commit and again after cross-lane integration.
- Native engine import and headless smoke have passed at the cited commits; comprehensive input/gameplay/device behavior and mobile performance remain unverified.
- Primary saves now use validated temp writes and backup fallback, with a native recovery test. Power-loss atomicity, Windows file locks, migration fixtures and long-running save integrity remain unverified.
- Scene's current meshes are graybox placeholders; visual quality is not yet production-level.

## Preservation and negative-save acceptance contract (2026-11-02)

The serializer must reject malformed or non-finite JSON state *before* either overwriting a save or mutating the active player session. For integer-valued economy counters (gold, inventory quantities, year and daily indices), a non-integral float must not be silently truncated. Integers above 2^53−1 may be rounded by JSON number handling and are rejected rather than misreported as exact. Pre-year schema-1 saves remain readable (`year` defaults to 1). Numeric positions must be finite and within a conservative world-coordinate safety bound; do not reinterpret arbitrary strings/objects as player positions.

**Evidence separation:** [principal-native acceptance at `8b4cea2`](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41399615671) proves 19 negative/legacy schema tests in real Godot. Existing [filesystem save test](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41398474611) proves two writes/backup and corrupted-primary fallback. Neither proves Windows locking, interrupted rename, power-loss durability, or preservation of full domain state after a hostile nested save. QA must add fault-injection and full-state fixtures before release.

**Pending expanded check:** the same principal branch now includes five additional hostile nested-state cases (24 total) covering malformed village contact maps, fractional soil age, animal health/epoch and social flags; this expansion must pass at final source SHA before integration.


## Cross-lane ecology save and paid-shift input integration

**Discovered at canonical merge `ddb081d8`:** Farming Ecology's `animals.save_state()` includes a reserved `__paddocks__` array, but the previous Principal validator required every animal key to be a dictionary. That mismatch made full-game saves fail even though earlier synthetic save fixtures passed. The corrective isolated branch `game/everbloom-principal-live-save-job-20261102` validates `__paddocks__` as an array of nonnegative integral forage records, and validates the new Village `worked`, `festivals` and `memories` fields. Unknown schema remains rejected.

The principal also binds `K` to `village.act("job", hero.global_position)` and documents the shortcut in the HUD, exposing the existing Village shift to keyboard players. The Village subsystem owns payment logic, schedule rules, and daily job idempotence; no changes were made to Village-owned source. Touch/controller UI remains pending.

**Evidence requirement:** the expanded `scripts/principal_save_acceptance.gd` creates the real assembled `scripts/game.gd`, populates live soil/village/livestock state, writes `user://` on an isolated native CI runner, reads it back, mutates in-memory values, reloads, and checks currency, inventory, date, village memory and paddock counts. Earlier 24-case native fixtures did *not* cover the ecology array. Native combined-HEAD validation must pass before closing this regression; it is not proof of power-loss durability or a consumer device playthrough.

## Final accepted principal integration checkpoint

The earlier note describing a paddock-save *candidate* is superseded: `scripts/save_service.gd` now recognizes `animals.__paddocks__` as an Array of forage dictionaries while validating individual livestock records and nested Village `worked`/`festivals`/`memories`. The valid assembled-state save regression is closed at source/native-test level on `main` `91eded29`, with [42 engine-native assertions PASS](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41401140904). All critical daily action owners use monotonic epochs; independent farm and Village native tests verify rollover behavior.

`scripts/game.gd` owns the `K` input mapping and dispatch to `village.act("job", position)`; `scripts/hud.gd` describes the keyboard shortcut. Village retains responsibility for working-hour checks, pay, energy debits, rest days and idempotence. Touch/controller input and player-facing interaction affordances remain design/QA gates.

The persistence boundary remains **fail-closed**, not fully transactional: validated temp+backup and corrupt-primary recovery work in the tested environment, but no guarantee is made for power-loss durability, file-lock behavior or all hostile historic schemas. Future cross-system changes must add a real assembled-game roundtrip to tests before touching canonical main, not just isolated domain fixture tests.


## P04/P05 corrupt-primary recovery-resume contract (2026-11-02)

At canonical starting point `main@95e54aa1ba1ae516e9b10c7608f48b6441baa465`, the assembled two-year QA test proved backup *reading* after corrupt-primary JSON but exposed that `write_payload()` subsequently refused every write, permanently stranding resumed players. The Principal-owned isolated branch `game/everbloom-principal-recovery-resume-20261102` addresses this without editing other domains.

**Authority and filesystem semantics:** `read_payload()` prefers a valid primary and falls back to the validated `.bak`; it never treats an interrupted `.tmp` as authoritative. On the next `write_payload(validated_snapshot)`, if the primary is corrupt, require a valid backup and a free `.corrupt.001` through `.corrupt.008` quarantine slot. Validate and flush/read back the new temporary snapshot **before** moving the corrupt primary to its unique quarantine file; rename the temporary snapshot to the primary; **do not overwrite the valid backup with corrupt bytes**. Normal subsequent writes still rotate the last valid primary into `.bak`. If there is no valid backup, no free quarantine slot, or the quarantine rename fails, reject the write and preserve the damaged primary and backup. Quarantine files are never automatically removed. The current UI reports save failure; user-facing recovery/quarantine notices need future work.

**Native acceptance:** `scripts/principal_recovery_acceptance.gd` uses an empty isolated `XDG_DATA_HOME` and verifies interrupted temporary writes, backup fallback, recovered gold/inventory/relationship/paddock conservation, first and second resumed saves, immutable quarantine bytes, normal backup rotation, fail-closed behavior with corrupt backup, and full quarantine capacity. The dedicated non-Codex workflow must pass at its **final exact commit SHA**; a source commit alone is not acceptance.

**Limitations:** This is a bounded single-process recovery protocol, **not** an atomic multi-file transaction. There is no OS-level fsync of parent directories, cross-process lock, Windows open-handle/file-lock test, power-loss fault-injection or schema-2 migration. Simultaneous writers are unsupported. Godot Linux headless tests are not evidence of those properties.


## P04/P05 schema-1 Village recollection hardening — 2026-11-02

Village V03/V06 added optional `last_gift_favorite` (boolean), `recalled_gift_epoch` (integer day index), and `gift_recollections` (bounded count). The Principal save boundary validates these fields **when present** without requiring them in preexisting schema-1 saves. Both gift and recall epochs must be between -1 and the snapshot's 56-day-year monotonic calendar epoch (capped to JSON's exact integer range); a nonnegative recall must reference a real gift and cannot predate that gift. Recollection counts must be integral in [0, 1,000,000], matching Village's runtime saturation limit. Invalid types, impossible chronology, and future-dated histories are rejected before writing or loading rather than silently coerced. The Village domain retains ownership of dialogue, memory production, and legacy favorite inference; no schema version increment or Village source edit is required.

Native regression adds hostile memory mutations, verifies invalid assembled snapshots leave authoritative bytes and active currency untouched, and roundtrips favorite/recalled epoch/count through real Game save/load. The Principal dedicated CI acceptance uses a strict anchored zero-failure summary rather than a brittle assertion-count literal; native execution at the exact changed SHA is required before calling this integrated. Windows locking, multi-writer isolation, power-loss durability and full migration coverage remain open.

## P04/P05 nested loader-admission parity — 2026-11-02 (isolated candidate)

**Problem:** Previously the central schema-1 validator accepted farm ages, soil
moisture/fertility, weed/stress counters, animal health/production, and Village
memory counts outside the corresponding loader ranges. A subsequent
`load_game()` silently clamped those accepted values. Unknown farm fields and
animal IDs could also be ignored, so a valid-looking snapshot was not guaranteed
to survive an assembled-game roundtrip.

**Bounded contract:** Principal now validates each optional original soil field
against the explicit loader maxima (age/watered days/moisture/fertility 100,
weeds 5, stress 9, rotation bonus 1, seed vigor 2, last family 32 characters);
validates livestock health/bond/happiness/hunger/cleanliness 100, neglect 365,
compost 2 and species-specific production counters (hen 1, cow 2, sheep 3);
rejects unknown nested soil fields/animal IDs/animal fields rather than silently
discarding them; and caps Village memory action counters at the existing
1,000,000 loader limit. Existing optional schema-1 fields and empty legacy farm
fixtures remain accepted. These limits mirror **current Godot 4.x loaders**;
any future Farming/Village field or animal species must update its owner,
Principal admission, native regression and migration together.

**Proof gate:** The isolated branch must pass the native Principal adversarial
suite, assembled 112-day QA, festival integration and general Python/Godot CI
at a single exact commit before canonical integration. Native tests include
positive upper bounds, each out-of-range field, unknown fields/species,
two non-hen production cycles and actual assembled invalid-write rejection
without modifying authoritative save bytes, currency, inventory or paddocks.
Passing headless CI does not prove physical hardware, power-loss durability,
multi-writer exclusion, Windows file locking or schema-2 migrations.

**Independent Village handoff:** Village currently clamps
`recalled_gift_epoch` to `last_gift_epoch` on load, although recollection may
legitimately occur later. The Village owner must correct that separate
lossy loader behavior with its own multi-epoch native roundtrip; Principal
should not reject legitimate later recollections to hide the defect.


## P04/P05 farm snapshot admission parity — isolated candidate (2026-11-02)

`Farm.load_state()` requires exactly 30 ordered beds and skips a bed with an unknown crop ID. The central save boundary previously admitted arbitrary farm array lengths and any crop string, allowing a superficially valid snapshot to discard planted fields on load. Principal now rejects nonempty arrays other than 30 beds and nonempty crop IDs outside the original catalog, before touching active player state. Empty `farm: []` remains accepted solely for historical pre-farm schema-1 fixtures; it is **not** evidence of a fully restored farm and must be handled explicitly in any future migration. The crop registry and bed count are checked against `data/crops.json` and `Farm.BED_COUNT` by a separate Python contract test. Native regression covers positive 30-bed/8-crop cases, partial and oversized arrays, unknown crops, and assembled-game rejected writes preserving authoritative bytes, gold and inventory. This is schema-1 fail-closed admission, not a schema-2 migration, concurrent-write lock, physical-device proof or fsync durability guarantee. Candidate requires exact-HEAD native CI and full assembled QA before integration; no changes to Farming-owned source.
