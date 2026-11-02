# EVERBLOOM B031–B040 civic construction typed-state handoff

**Owner:** Construction Inventor. **Mission IDs:** B19 (state hardening), B18 (civic event contracts), B03/B07/B14/B15 (dependency design only). **Status:** design-only; Phase C CLOSED. **Godot:** 4.x only. **Baseline:** main at 1e456d5e31963575a81dda39d4a20058d98c86ce. **Frozen source:** `f6b61bd73dede5703dcf8ef45ea24d47e28b8065`, `docs/innovation/construction/phaseB_100_concepts.json`, blob `d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b`.

## Contract coverage and distinct adversarial invariants

| ID | Persisted bounded domain fields | Domain rejection requirements |
| --- | --- | --- |
| B031 Spanwright Bridge | `bridge_spans`, `council_vote` | Abutment load capacity, minimum river clearance, certified vote with matching revision and epoch. |
| B032 Reedwalk | `walkway_segments`, `nesting_buffer` | Pier-to-nest distance squared, minimum accessible walkway width, no self-loop. |
| B033 Gatherhall | `hall_zones`, `exit_graph` | Room occupancy, open exit reference, aggregate exit throughput and width. |
| B034 Market Stalls | `stall_modules`, `vendor_slots` | Storm folding, registered stalls, nonoverlapping vendor and stall time intervals. |
| B035 Lanternline | `lantern_nodes`, `fuel_tanks` | Valid fuel references, per-tank aggregate consumption and zero visibility when unlit. |
| B036 Stormhaven | `shelter_anchors`, `capacity` | Wind forecast versus anchor rating, usable capacity, exact protected population totals. |
| B037 Pocketgarden | `plot_owners`, `harvest_receipts` | Consent ownership, finite harvest quotas, consent-to-harvest epoch order. |
| B038 Waystation | `waystation_ids`, `route_links` | Capacity, known distinct route endpoints, no active travel through closed station. |
| B039 Signpost | `sign_graph`, `language_keys` | Reachable destinations, referenced localized keys, required English/Spanish pairs. |
| B040 Apprentice Classroom | `class_stations`, `mentor_slots` | Station capacity, assigned mentor, nonoverlapping lesson intervals on each day. |

All states additionally require exact field shapes, strict JSON primitive types, finite bounded integers, unique list IDs, valid non-control text, 56-day-year monotonic `day_epoch`, and exact JSON roundtrip. The test runner exercises an inactive default and a nonempty valid state per feature, three feature-specific invalid states, and thirteen common hostile mutations per feature. This is **design contract verification**, not a working Godot gameplay system.

## Authority and integration gates

- **Principal:** authoritative inventory and currency, transaction settlement and permanent replay protection, `SaveService` migrations and atomic full-game admission. Local capped `receipts` are audit hints only and **cannot** guarantee lifelong command idempotence. Never debit on preview; never mint/refund on invalid/stale/duplicate commands.
- **Village:** owns NPC consent, council votes, vendor/mentor availability, town attendance, gift and quest consequences. Construction stores only immutable consent/approval references until the owner confirms validity.
- **Farming:** owns river habitat, nesting zones, harvest allocations, ecology, water and fuel source accounting. Bridge/boardwalk impact and communal harvest must not directly alter Farming's ledger.
- **Valley/Principal:** stable world-space coordinates and authoritative navigation graph, physics and scene streaming. A locally consistent route is not proof that it is navigable in the assembled game.
- **Asset provenance:** author original modular bridge spans, reed piers, market stalls, lanterns, shelter frames, garden markers, waystation roofs, bilingual signs and classroom props. No extracted third-party game assets. Use cached mesh variants and LODs; desktop <=2 ms preview/64 anchors and mobile <=4 ms/24 anchors are **targets only**, never measured.
- **Controls:** each feature inherits catalog keyboard/mouse, gamepad and touch verbs; no equivalence has been verified on devices. UI must provide color-independent invalid reasons, material quotes, accessible confirm/cancel, and non-mutating ghost preview.

## Save/migration and implementation prerequisites

1. The ten namespaces `construction.eb_b_031` through `construction.eb_b_040` are optional **design-only** schema v1. Absent legacy namespaces should load inactive. Present malformed namespaces must be rejected atomically by Principal; never silently clamp or drop nested fields.
2. No new game code, assets, scene adapters, currency, or save fields were changed in this tranche. No new playable civic features can be claimed. The 220-feature semantic/ownership review and Principal acceptance remain pending.
3. Material quotes in the frozen catalog are **unapproved** (some use seed/dye/glass/iron as placeholders). Reconcile acquisition and costs with Farming/Principal before implementation.
4. Native Godot full-game test plan, once authorized: create civic object via actual input, display feedback, reject stale revision, missing consent, blocked route, excess wind/occupancy, and insufficient resources; save/restart/reload with all nested fields; verify identical state hash and durable receipts; replay duplicate commands; test 56-day year boundary; compare mouse/controller/touch parity and desktop/mobile budgets.
5. Run `python3 docs/innovation/construction/typed_state/validate_civic_031_040.py` for offline schema checks. The dedicated workflow is push-only and invokes no Codex. General baseline Godot CI is independent; its success does not prove these proposed features work.

**Handoff request:** Principal to approve/deny schema migration and durable command settlement; Village to approve civic consent/schedule snapshots; Farming to approve habitat and harvest authority; Valley to approve route/terrain references. Do not integrate Phase C until joint 220 acceptance.
