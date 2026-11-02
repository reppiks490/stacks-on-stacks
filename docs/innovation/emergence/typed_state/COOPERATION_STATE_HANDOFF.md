# EVERBLOOM E101–E110 — Cooperative agency typed-state handoff

**Status:** Phase B design contracts only. **Phase C CLOSED.** Nothing in this tranche is playable, instantiated in Godot, or permitted to debit inventory, grant relationship points, move NPCs, or alter the canonical save. Mission coverage: **E03 / E16 / E18**, with E07/E12 integration dependencies.

## Provenance and isolation

- Canonical charter: `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Frozen Emergence source catalog: `game/everbloom-emergence-phaseB-100-20261102:docs/innovation/emergence/phaseB_051_110.json`, blob `eb7c590f43c92ded0e328ecfdf7003fa7c06ceac`.
- Baseline inspected: `main@e63bee33176259a295ff0118c15ca1bd46d69be7`; coordination `docs/CROSS_LOOP_COORDINATION.md`; issue #2.
- Exclusive files: `cooperation_101_110.json`, `validate_cooperation_101_110.py`, this handoff, dedicated push-only workflow. No shared source/save/gameplay files changed.
- The source catalog supplies the original concept IDs, player verbs, controls, dependencies, art requirements, costs and acceptance; this tranche adds strict nested state and negative fixtures, not another ten concepts.

## Typed-state boundaries

| ID | Feature | Local bounded invariant | External authority needed |
| --- | --- | --- | --- |
| E101 | Shared Tool Queue | Unique booking IDs; overlapping noncancelled bookings rejected; release only canceled booking | Principal authoritative tool ownership and transactions; Village NPC schedule |
| E102 | Community Search Grid | Unique cells and volunteers; one verified find receipt per search | Principal world positions and clue inventory; Village NPC consent/navigation |
| E103 | Care Network Check-in | Request/slot consent; no duplicate care receipt or volunteer shift | Village relationships, privacy, schedules and consent |
| E104 | Accessible Puzzle Partner | Completion receipt single-use; hints and accessible mode cannot alter reward | Principal puzzle outcome and accessibility input |
| E105 | Chore Preference Auction | Consenting bids; no NPC overlapping assignment; wages bounded | Village work schedule, Principal wage ledger |
| E106 | Seasonal Volunteer Rota | Unique per-NPC/day slot, consent expiration, completion once | Village schedule, 56-day Principal calendar |
| E107 | Emergency Signal Chain | Cyclic graph permitted; bounded delivered set and one acknowledgment per NPC | Principal weather event and deduplicated event bus |
| E108 | Shared Discovery Field Trip | Participants consent; reachable waypoint references; rest receipt once | Principal world coordinates/pathfinding, Village fatigue |
| E109 | Neighborhood Exchange Mentor | Both parties consent; lesson receipts unique; capped local mastery | Village identity, skills and global mastery ledger |
| E110 | Village Consensus Noticeboard | Unique voter per proposal revision; dissent persisted; decision tied to revision | Village eligibility/consent; Principal global proposal receipt |

**Important limitations:** These are *snapshot-local* checks. A JSON document cannot prove NPC schedule availability, world-path reachability, weather authenticity, consent provenance, global inventory conservation, cross-save receipt uniqueness, or actual physical controller/touch parity. All must be verified against authoritative services after the shared 220-ledger gate. E102's source-catalog negative-case text mentions eclipse fallback even though this is a search grid; retain the source text for provenance and flag for semantic correction by Principal/Emergence before integration.

## State and replay contract

Each `emergence.cooperation.NNN` namespace is version 2, strictly typed with exact nested keys, bounded arrays, monotonic `day_epoch`, `revision`, and command receipts (`command_id`, `expected_revision`, `effect_digest`, `day_epoch`). The year is 56 days: year 2 spring day 1 = epoch 57; year 3 spring day 1 = epoch 113. Repeated command IDs, future receipts, invalid nested fields and stale revisions reject atomically. A preview cannot change state or debit resources. The Principal save service owns atomic persistence and migrations; absent optional namespaces may default, malformed *present* namespaces must reject without replacing a valid save.

**Caveat:** Schema-level receipt lists are finite (64), so runtime replay safety needs Principal's durable deduplication journal when older receipts are compacted. Local progression caps are not sufficient to prevent global circular mastery/reward farming. Cross-feature receipt IDs require authoritative global uniqueness.

## Interaction, visual and performance handoff

Every concept retains its authored player verbs, keyboard/mouse, gamepad and touch routes, large confirm/cancel targets, captions and text equivalents. Implement UI only after approval; use consent and conflict explanations, reversible previews, visible fallback when unavailable, and no punishment for declining. Original independently-authored icons, legible schedules and subtle ambient audio require provenance manifests; never import proprietary game art. The proposed `0.4 ms desktop / 0.2 ms mobile` per active feature and `4` mobile draw calls are **targets, not measurements**. Defer rendering and device-FPS claims until actual hardware benchmarks.

## Reproducible tests and acceptance

```sh
python -m py_compile docs/innovation/emergence/typed_state/validate_cooperation_101_110.py
python docs/innovation/emergence/typed_state/validate_cooperation_101_110.py --self-test
```

The validator exercises two valid fixtures per feature, deterministic canonical JSON, monotonic rollover to epoch 113, strict nested typing, feature-specific denial, duplicate receipt/stale revision/future epoch, and seeded hostile-state mutations. The dedicated push-only workflow verifies exact `GITHUB_SHA` and a clean checkout. Existing Godot native baseline is independently checked by the repository's normal workflow; a baseline pass **does not** mean E101–E110 are integrated or native-playtested.

**Next handoff:** Principal/Emergence should independently audit 220 unique source IDs, novelty, field parity, inconsistent negative-case language, all typed tranches and cross-feature replay boundaries. Construction remains sole owner of physical structures and materials. Village remains sole authority for consent, jobs, schedules and relationships. Farming remains sole authority for crop/animal resources. No Phase-C feature vertical slice before independent 220 verification and explicit Principal authorization.
