# EVERBLOOM E041–E050 — regional exchange state handoff

**Status:** design-only, **NOT playable**, **NOT native-tested by this design validator**. Phase C closed until Principal's semantic approval of the joint 220-feature ledger. Godot 4.x is the only authorized active engine.

## Provenance and scope

- Canonical 100-mission charter: `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Frozen Emergence Phase-B source: `game/everbloom-emergence-phaseB-100-20261102@63cab5d05c742c61205933482e38fac2a4086764`, `docs/innovation/emergence/phaseB_011_050.json` blob `a5def76918e77e0ded7e3e8085444698b4e0b549`.
- Starting canonical main: `1e456d5e31963575a81dda39d4a20058d98c86ce`. Current main must be rechecked before any integration.
- Missions: E03 (state design), E08 (economic shocks/exchange), E18 (independent negative QA). Exactly 10 new *state contracts* for existing catalog IDs E041–E050; no new feature concepts.
- Exclusive files: this document, `exchange_041_050.json`, `validate_exchange_041_050.py`, and `.github/workflows/everbloom-emergence-exchange-types.yml`. No gameplay, save service, existing catalog, assets, or other lane source modified.

## Exact-once authority and bounded contracts

The contracts specify quotes, single-borrower loans, perishable delivery accounting, seed-lot ownership transfer, staged craft escrow, finite weather mutual-aid fund, reciprocal lesson reservations, future crop obligations, mutually exclusive repair/salvage, and read-only price observations. The original four or five fields for every concept are preserved. New fields are design-only proposals, **not** existing serialized runtime fields.

**Principal** must own all inventory, currency, material escrow, command-id deduplication, immutable settlement receipts, atomic save admission and monotonic `day_epoch=(year-1)*56+season_index*14+day`. **Village** owns NPC schedules, shop access, permission and market quotations. **Farming** owns crop inventory, seed lot identity, harvested produce and their debits. **Emergence** may own only optional world-event proposals, display projections and references to authority-issued receipts; it must never independently credit goods or money.

A snapshot with a missing optional Emergence namespace may default inactive; any **present malformed** namespace, unknown nested field, invalid type, non-finite value, inconsistent conservation or stale command must reject atomically. This proposal does not change the existing schema-1 save format. Principal must approve a versioned migration before adding these namespaces to real saves. A finite cache of receipt IDs is **not** sufficient replay protection; the authoritative owner must retain durable settlement identity or a provably equivalent non-replayable transaction state across restarts and years.

## Independent reproducible validation

`python3 docs/innovation/emergence/typed_state/validate_exchange_041_050.py --self-test`

The validator verifies exact source field sets, bounded recursive types, unknown-field rejection, 10 inactive/10 active fixtures, JSON roundtrips, hostile fixture mutations, unsafe JSON integers, non-finite JSON and 10 separate economic invariants. Its output is a **design-state** test result, not an executable Godot feature result. Generic repository Godot native validation on the same commit is a separate baseline check only.

## Player UX, visual and platform contracts

Each proposal retains the source catalog's scenario, verbs, keyboard/mouse, controller, touch and accessibility contract. Display exact quote/reservation/expiry/quality/settlement state, reasons for invalid actions and safe cancellation before confirming any charge. Text-only readout is the low-spec fallback; original authored iconography, shop/route sounds and seasonal environmental feedback require asset provenance before integration. Proposed cap: 128 active display records per feature, desktop logic target 0.4 ms and mobile 0.2 ms **unmeasured**. Controller/touch parity, actual framerate, input latency, asset LOD and native gameplay proof remain **unverified**.

## Required Phase-C acceptance (blocked)

1. Principal and Farming sign off on stock ownership, unique seed-lot and harvest receipts, transaction history, refunds, versioned save migrations and two-year replay. Village signs off on market quotations, NPC access and lesson scheduling.
2. Native Godot tests must drive real player preview → confirm → authoritative debit/credit → save → restart → replay with no duplicate money, seeds, tools, quality or skills. Include denied, stale, repeated, malformed, corrupt-save and interrupted-write cases.
3. Test 56-day calendar rollover, offline play, keyboard/controller/touch parity, original asset provenance and actual mobile/desktop performance. Run assembled-game and domain-specific native CI at the **same exact final SHA**.
4. Principal verifies full 220-concept semantic and integration gate before any Phase-C implementation. Until then all entries remain **specified_not_implemented**.

**Open design limitations:** A single E044 lot projection does not prove global lot uniqueness; a global authoritative inventory index is mandatory. E046 balances are bounded integer units rather than real banking. E050 observation provenance must come from Village market records, never generated by reading the diary. No Unreal/Unity work authorized.
