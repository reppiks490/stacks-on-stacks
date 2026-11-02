# Emergence E06/E18: native two-year festival denial and replay QA

Status: **isolated test implementation; not a new gameplay feature.** Phase C remains CLOSED.

## Scope and ownership
- Read pinned 100-mission charter at `b8a1e635792b08b0a3d87b987e593a539ac5c123`, current main, coordination document and issue #2.
- Own only this `docs/innovation/emergence/native_festival_denial/` directory and the dedicated push-only workflow. No edits to `game.gd`, `save_service.gd`, `festivals.gd`, any player save, asset, catalog, or other lane.
- Uses the actual Godot 4.x `scenes/main.tscn` and `Game.next_day()` with the production festival and save services, not a detached Python mock.
- CI runs under disposable `XDG_DATA_HOME` and fails closed if any primary, backup, temp or writer-lock path already exists.

## Acceptance contract
1. Walk 112 actual days, verifying monotonic `day_epoch` and 56-day year boundaries.
2. On every one of 12 original annual festival dates in each of two years, verify denial for remote position, closed hours, absent materials and zero energy. No denied action may award petals or create a receipt.
3. For each of 24 legitimate annual entitlements, verify exact item debit, energy debit, currency, ribbon, bounded restoration and one receipt.
4. Save and load actual assembled Farm/Village/Animal/Festival state after every event, then replay the event on the same day and assert zero further debit or reward.
5. After year-three rollover, verify all 24 receipts remain, and malformed duplicate, future-year and invented event receipts fail the real SaveService admission check without modifying valid saved bytes.
6. Native workflow must pass at the exact final branch HEAD, with import and test logs inspected. A green baseline smoke test alone is not sufficient.

## Limitations and cross-loop dependencies
- The test calls actual gameplay service methods; it does **not** simulate physical keyboard, mouse, gamepad or touch, prove rendered aesthetics, or measure mobile performance.
- Resource inputs are deliberately set by the test fixture to isolate admission logic; this is not an economy-balancing or player-progression demonstration.
- Principal owns authoritative persistence and replay policy; Village owns NPC consent; Farming owns material economy. This test neither assumes nor implements those pending Phase-C contracts.
- Any discovered failure must be fixed in the owning domain via coordination rather than silently modifying shared game source.
- Original game and saved data remain untouched; no engine migration, proprietary content, PR, force push, or paid service.

## Reproduction
`godot --headless --path . --editor --import --quit` then, under a **fresh disposable** `XDG_DATA_HOME`, `godot --headless --path . --script res://docs/innovation/emergence/native_festival_denial/native_acceptance.gd`. The pinned official Godot 4.7.2 binary and SHA256 are specified in the workflow. This document does not assert passing CI until exact-HEAD logs have been checked.
