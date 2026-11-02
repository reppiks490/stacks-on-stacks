# Emergence E091–E100 — sky mysteries, typed-state engineering handoff

**Mission IDs:** E03, E14, E18 (E01 novelty recheck required at integration). **Status:** Phase B design only; no playable Godot feature, no native feature test, no real device performance measurement. **Phase C remains CLOSED** until the shared 220-concept ledger is independently verified and Principal approves integration.

**Canonical charter:** `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`. **Frozen original source:** `game/everbloom-emergence-phaseB-100-20261102:docs/innovation/emergence/phaseB_051_110.json`, blob `eb7c590f43c92ded0e328ecfdf7003fa7c06ceac`. This tranche adds **ten concrete version-2 nested design-state contracts**, not ten new concepts and not playable features. All ten source field sets remain exact.

## Player verbs, meaningful feedback and negative acceptance

| ID | Player interaction and feedback | Independent fail-closed rule |
| --- | --- | --- |
| E091 Meteor Trail Triangulator | Record two distinct timed meteor bearings; map highlights finite search sector and clue budget | Duplicate vantage or bearing cannot mint a sector/reward |
| E092 Eclipse Shadow Cipher | Align safe indirect shadow model, receive readable puzzle clues; offline model remains usable after eclipse | Missed event cannot permanently lock puzzle |
| E093 Aurora Color Chronicle | Capture seeded aurora pattern with named text description in personal journal | Color/graphics settings cannot change discovery |
| E094 Moonphase Wildlife Watch | Quietly observe one species at a real habitat; compare phase-tagged notes | One night cannot count as several moon phases |
| E095 Cloud Atlas Riddles | Interpret sky clues, preview optional forecast-based outing and validity window | Reload cannot reroll Principal's weather snapshot |
| E096 Sky Reflection Survey | Align two landmarks on a reflection or equivalent flat diagram to uncover an inscription | Low-graphics or reduced-motion mode cannot block completion |
| E097 Constellation Oral History | Ask consenting NPC narrators and compare separately attributed versions | No NPC can impersonate another or overwrite attributed history |
| E098 Seasonal Sky Clock | Set appointment in sky window and NPC availability; calendar reports status | Invalid time cannot teleport NPC or create duplicate reward |
| E099 Falling Star Provenance | Trace finite fragment receipt, choose to keep or donate, inspect ownership record | Donation and personal sale cannot both succeed |
| E100 Horizon Weather Lanterns | Read two peak forecast signals, select north/south route with accessible return | Incorrect forecast never creates permanent softlock |

## State, save and authority

Every optional namespace `emergence.sky.091..100` has exactly **four source-specific fields** plus `revision`, monotonic `day_epoch`, and bounded `command_receipts`. Nested objects and arrays are strictly shaped and bounded. `validate_sky_091_100.py --self-test` checks two accepted fixtures per contract, deterministic JSON roundtrips, duplicate command IDs, future receipt epochs, invalid types/unknown fields, seeded hostile mutations and at least five feature-specific negative cases per concept. This is Python contract validation; it **does not prove** authoritative settlement, event scheduling, collision safety, native Godot behavior, real player controls, or hardware benchmarks.

**Principal:** authoritative `day_epoch=(year-1)*56+season_index*14+day`, weather snapshots, deterministic seeds, world coordinates, command revision and global idempotent receipt ledger, inventory/energy debits, save migrations, atomic recovery. The stored `command_receipts` are untrusted proposed references until Principal reconciles them; local uniqueness cannot establish global exactly-once semantics. **Village:** NPC consent, oral history provenance, availability, appointments and relationship changes. **Farming/Valley:** real wildlife/habitat observation permissions, terrain/nav routes, safe returns, pools and protected sites. **Construction:** any physical observatory, lantern installation or permanent world geometry. **Emergence:** owns optional sky-puzzle decisions, authored clues, journal representations and negative contract tests, not external authoritative state.

**Calendar:** never derive a once-per-day or annual event key from the day-of-season alone. At 56 days/year, epoch 57 and 113 are different days despite matching day-of-year. E092 must have a permanent model fallback; E094 lunar phase requires Principal's canonical phase service; E095 must pin a weather digest, not reroll weather; E098 must check the live Village schedule; E100 must verify safe traversal and return natively. Current validators can reject contradictory local snapshots but cannot validate external authority.

**Inventory:** E099 fragment acquisition/donation is an authoritative one-item transaction with exclusive disposition; no speculative mineral item, sale, or duplicated donation reward may be materialized by Emergence. All other sky interactions default to time/energy-only proposals and may not debit in preview. Any cancellation refunds only a real unused reservation. No source field authorizes free items.

## UX, assets and performance

**Keyboard/mouse:** focus/inspect, remappable choice navigation, confirm/cancel, accessible clue journal. **Controller:** D-pad/stick focus, shoulder choice changes, A/B confirmation/cancellation. **Touch:** >=44px controls, tap-to-inspect, long-press details, no required precision drag. **Accessibility:** captioned and textual sky signals, explicit landmark diagram alternative, non-color-dependent rewards, reduced-motion sky overlays, non-audio clue access, scalable text and pausable events. All are specifications; no physical-device parity is claimed.

**Original art/audio:** author a fictional meteor streak and bearing map, indirect eclipse model, aurora bands with text patterns, moonphase icons, cloud glyphs, flat reflection diagram, constellation chart and narration captions, sky clock, fragment provenance card, peak weather lights and safe route overlay. Record provenance, mesh/texture budgets, mobile LOD and no third-party proprietary assets. Catalog target of <=8 active instances, <=0.4ms desktop/<=0.2ms mobile logic and <=4 mobile draw calls is **unmeasured**; obtain actual profile traces after Phase C.

## Reproducibility and release gates

Run `python -m py_compile docs/innovation/emergence/typed_state/validate_sky_091_100.py` and `python docs/innovation/emergence/typed_state/validate_sky_091_100.py --self-test` from repository root. Dedicated workflow is push-only, non-Codex, read-only and checks `git rev-parse HEAD == GITHUB_SHA`. The existing general push workflow separately tests the unchanged Godot baseline; it cannot establish these ten features as playable. Avoid PRs because general CI also has a pull_request trigger and auto-review behavior is not proven safe.

**Before E20 or any new feature implementation:** Principal independently verifies all 220 unique concepts, validates exact costs, receipts, save migrations, domain ownership and source novelty; then coordinate Godot adapter integration and native assembled-game save/replay, two-year calendar, real encounter, choice, effect, cancellation, touch/controller, localization and frame/memory acceptance. No port to Unreal or Unity without later owner authorization. Preserve other lanes, source and existing save data.
