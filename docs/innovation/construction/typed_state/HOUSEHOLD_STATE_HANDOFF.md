# EVERBLOOM — Construction B071–B080 household-function typed-state handoff

**Mission coverage:** B19 catalog state hardening; B15 consequential housing feasibility; B14 multimodal controls; B13 transaction/undo boundaries. **Status: design-only contracts, NOT playable code.** Phase C remains CLOSED until the entire 220-feature ledger receives semantic audit and explicit Principal authorization. Godot 4.x is the sole implementation engine; no Unreal/Unity port.

## Source, ownership and exact baseline

- Canonical mission charter: `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Starting canonical main: `3525f62d439a33b00def7fa9bba7ff4cd1804811`.
- Frozen original 100-concept source: `game/everbloom-construction-phaseB-100-20261102@f6b61bd73dede5703dcf8ef45ea24d47e28b8065`, blob `d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b`.
- Exact source titles, source state fields, first simulation invariant and proposed resource quotes are retained in the JSON. Additional typed names are *design-stage adapter suggestions*, not runtime migrations. None of the source resource quotes is authoritative.
- Exclusive isolated branch: `game/everbloom-construction-b19-household-types-20261102`. New Construction-only paths: `docs/innovation/construction/typed_state/household_071_080.json`, `validate_household_071_080.py`, this handoff, and push-only `.github/workflows/everbloom-construction-b19-household-types.yml`. No existing gameplay, SaveService, assets, farm, village or other lane file is edited.

## Ten independent bounded household proposals

| ID | Mechanic and player consequence | Authoritative dependency |
|---|---|---|
| B071 | Guesthouse rooms, consented finite bookings, occupancy and safe exits | Village NPC consent/schedules; Principal booking receipts |
| B072 | Companion-safe gates, route clearance, reachable water/rest amenities | Farming welfare; Valley pathfinding |
| B073 | Convertible nursery components, guardian consent and one-step age transitions | Village guardian authority; Principal epoch |
| B074 | Resident-specific mobility profiles, accessible ramps/lifts and essential-room reach | Village profiles; Valley geometry/navigation |
| B075 | Shared household rights, revocation and private cabinet access | Village consent/privacy; Principal authoritative inventory |
| B076 | Frontroom shop stock conservation, sales receipts, public shop access without exposing private rooms | Village jobs/commerce; Principal money/inventory |
| B077 | Acoustic barriers, neighbor quiet hours, bounded work sessions | Village quiet-hour reservations; Principal clock |
| B078 | Shade/vent microclimate summary and finite water request | Farming F08 growth/water authority; Principal save |
| B079 | Load/vibration-rated observatory, visibility gates and once-per-day observation claim | Valley geometry; Emergence E14 sky conditions |
| B080 | Cellar support, groundwater separation, food capacity and safe egress | Farming hydrology; Valley terrain/collision |

The JSON provides concrete nested integer/string/boolean/list/object types with bounds, required keys, unique IDs, two valid fixtures per system, domain-specific invalid mutations, control mappings for mouse/keyboard/gamepad/touch, feedback, proposed original art, unmeasured performance targets, dependency and authority contracts, and future Godot acceptance. All preview/commit/undo commands are **proposals**. There is no engine runtime registration.

## Validation and integration caveats

The offline validator enforces exact typed fields, no unknown/missing keys, strict integer-vs-boolean typing, bounded lists/strings, unique receipt and actor IDs, and domain-specific rules. It executes valid nested JSON roundtrips, targeted hostile fixtures, common malformed states and deterministic seeded fuzz. It does **not** prove atomic inventory settlement, real-time geometry collision, NPC consent, crop growth, or playable input parity.

**Critical authority rules:** Principal alone can debit or credit items/currency, sign and deduplicate command receipts, migrate versioned saves, reconcile complete nested state, and authorize undo. Village alone authorizes NPC bookings, household permissions, child/elder consent, work and quiet-hour reservations. Farming alone changes animals, crops, greenhouse energy and finite water. Valley alone provides world-space transforms, collision, navigation and groundwater sampling. Construction owns only the local proposed structure state and ghost preview. An unverified source material ID is a hard blocker, never a free item.

**Calendar:** all `day_epoch` values are monotonic integer indices under 56 days/year; year-two observations/booking checks must not collide with year one. Replaying the same command must not debit twice. Snapshot restoration must preserve nested domain state and deny duplicate rewards. The current typed fixtures do not demonstrate a full assembled-game roundtrip.

**Safety and visuals:** original procedural meshes and icons only, with a provenance manifest and mobile LODs before gameplay integration. Proposed desktop 2 ms/60 FPS and mobile 4 ms/30 FPS preview budgets are **targets, not measured performance**. Keyboard/mouse, gamepad and touch mappings are design contracts only. No third-party proprietary assets, Codex, PR, unapproved spend, publication, force updates, or premature engine migration.

## Native acceptance prerequisites (not yet satisfied)

1. Principal explicitly approves the full 220-feature semantic ledger and resolves authoritative material, money, receipts, save migrations and optional namespaces.
2. Village, Farming and Valley provide immutable consent, mobility, water, climate and world-geometry adapters with stable IDs and deterministic replay.
3. Implement the first physical cottage slice only after approval, with native Godot 4.x place/undo/save/load tests, player-visible feedback, actual input-device parity, exact-head CI and measured performance on PC/mobile.
4. Preserve existing gameplay and all parallel branches; Principal alone coordinates integration after exact SHA comparison and tests.

**Verification status:** the dedicated Python validator is new and requires its own GitHub Actions PASS at the final branch SHA. A generic native Godot baseline PASS, if obtained, only proves the existing baseline; it cannot certify these design-only household features.
