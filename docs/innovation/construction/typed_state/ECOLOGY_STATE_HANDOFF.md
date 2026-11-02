# EVERBLOOM Construction B041–B050 ecological landscape typed-state handoff

**Owner:** Construction Inventor. **Mission IDs:** B19 (typed design), B04 (terrain), B07 (integrity), B15 (housing/ecology consequences), B18 (environmental recovery), B20 (future gated integration). **Status:** design-only, not native-tested gameplay. **Engine:** Godot 4.x exclusively. **Source main at claim:** `86aa22c9e7806d85f42b95a8fbd27bbba122a556`. **Frozen feature catalog:** `f6b61bd73dede5703dcf8ef45ea24d47e28b8065`, blob `d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b`. **Phase C:** CLOSED pending Principal acceptance of the full 220-feature roster.

## Domain-specific design invariants

| Feature | Nested persisted state | Negative cases required |
| --- | --- | --- |
| B041 Contour Orchard Terracing | `terrace_steps`, `root_buffers` | Excavation cut and slope limits; known tree references; exclusion radius plus clearance. |
| B042 Windward Living Hedgerow | `hedge_segments`, `wind_shadow` | Shadow references known hedge; maturity/porosity bound shelter; exposure + reduction = 100%. |
| B043 Fordstone Creek Crossing | `stone_positions`, `flow_limit` | Safe depth/gap; flood threshold forces closure; no safe crossing when closed. |
| B044 Salmonrise Fish Passage | `ladder_steps`, `flow_split` | Passable rise/depth; mill + ladder + spill conserve inflow; bypass sum matches ladder allocation. |
| B045 Spongegarden Rain Basin | `basin_cells`, `overflow_outlet` | Each cell conserves water; finite storage; outlet exactly reconciles inflow/overflow and release limit. |
| B046 Reedloop Composting Privy | `treatment_chambers`, `compost_grade` | Fictional chamber mass accounting; only mature treated compost releasable; release epoch follows maintenance and precedes current day. |
| B047 Skymeadow Living Roof | `roof_soil_depth`, `drainage` | Soil depth and wet load within roof capacity; wet >= dry; retained + outflow = inflow. |
| B048 Pondbreath Aeration Mill | `paddle_speed`, `oxygen_index` | Wind caps RPM; gear condition caps RPM; oxygen gain bounded by rotation and total concentration. |
| B049 Slopeweave Erosion Fence | `fence_rows`, `sediment_captured` | Upstream = trapped + downstream; finite capture; aggregate upstream debit and receipt epoch reconcile. |
| B050 Rootbridge Treehouse Deck | `deck_supports`, `trunk_clearance` | Supported/anchored loads; trunk sway clearance; tree root buffer. |

All ten contracts have exact field shapes, strict JSON types (booleans are never integers), bounded signed integers, unique list IDs, disallowed control characters, an inactive legacy default, nonempty valid fixtures, and three targeted hostile cases per feature. The validator separately confirms that each hostile case triggers its *intended* rule, not merely a coincidental schema failure. It also tests 13 common adversarial mutations per feature, including duplicate local receipt, unexpected key, nonfinite revision, overflow, and orphan active state. These tests are **offline specification checks**, not an assembled-game/native gameplay demonstration.

## Authority, gameplay and platform contracts

**Construction** owns nonmutating placement preview, local modular geometry, typed sockets, load/collision hints, proposed ecological structures and visual feedback. **Farming** owns actual tree/root locations, soil movement, wind exposure to crops, fish stocks, water balances, compost fertilizer, oxygen and sediment conservation. **Principal** owns `day_epoch=(year-1)*56+season_index*14+day`, immutable world IDs, atomic full-game save admission, material/currency ledger and permanent command settlement; local capped `receipts` cannot enforce lifetime anti-replay. **Valley** owns terrain occupation, waterway collision, NPC navigation and streamable geometry. **Village** owns resident permission and town contracts. Construction must not independently mint water, compost, fish, oxygen, sediment or inventory. All cross-domain effects require explicit owner-approved commands with versioned snapshots.

Each catalog feature retains keyboard/mouse, gamepad and touch controls: drag/adjust ghost, explicit confirm/cancel, visible resource quote, precision steppers on touch, color-independent invalid reasons and undo preview. Original modular terrace pieces, hedges, stepping stones, fish ladders, basin tiles, sealed fictional privy props, living-roof patches, pond mills, sediment fences and treehouse supports require provenance manifest, collision LOD and cached mobile variants. The catalog's desktop <=2 ms preview and mobile <=4 ms preview are **unmeasured design targets**; no device or visual proof is claimed.

## Save/migration and eventual native acceptance

1. Optional namespaces `construction.eb_b_041`–`construction.eb_b_050` are proposed schema v1. Missing legacy namespaces mean inactive; a present malformed namespace must fail **atomically** without silently truncating nested lists, clamping values or duplicating resources. Principal owns migrations and acceptance.
2. In the future, implement a deterministic Godot 4.x player route: preview an original terrain-adaptive module, reject unstable geometry, confirm with a real authoritative material quote, undo, save/restart/reload, replay the same command, and prove identical serialized state and no double debit. Repeat across 56→57 and 112→113 year boundaries; exercise keyboard/mouse, gamepad and touch adapters.
3. Native regression must use actual `game.gd` and `save_service.gd`, Farming ecology, Valley geometry and input events. An isolated Python schema PASS or generic Godot baseline PASS is insufficient to claim B20, player interactions, performance or cross-domain settlement.
4. The frozen catalog includes unapproved material quotes; Farming and Principal must resolve actual acquisition, quantity and refund economics. The proposed privy is **fictional game simulation**, not real sanitation guidance.
5. Semantic differentiation requires Principal review against existing farming hydrology, fish passage, wind shelter and terrain systems. Reject duplicate/reskin mechanics before implementation; cross-branch exact-ID/title uniqueness alone is insufficient.

**Offline verification:** `python3 docs/innovation/construction/typed_state/validate_ecology_041_050.py`. Dedicated push-only CI runs the same validator and syntax compilation without Codex. No existing gameplay/source/save/asset file is edited by this tranche. The isolated branch is not authorization to merge or open a PR.
