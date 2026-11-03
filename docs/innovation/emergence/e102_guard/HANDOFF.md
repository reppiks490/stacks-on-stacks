# E102 — Community Search Grid: isolated adversarial handoff

Status: **REFERENCE QA ONLY; Phase C CLOSED**. Mission E18. No Godot gameplay files changed.

Source erratum: `docs/innovation/emergence/joint220_audit/SEMANTIC_ERRATA.json` at commit `1204ed50cb84572fad77450f836863901e0635ca`. The original E102 acceptance text accidentally refers to an eclipse puzzle. This is a different mechanic and must not gate Community Search Grid.

## Proposed admission contract (not approved)
Each volunteer assignment must carry team, volunteer, search cell, shift, monotonic day_epoch, consent revision, and globally unique receipt. Reject an assignment before any mutation if consent is absent/stale, the receipt was used, the same cell+shift+day is occupied, or the same volunteer+shift+day is occupied. Overlaps are **day-scoped**, not permanent: a cell can be searched again in another year. Receipt uniqueness is **global**, including across years. A denied action must leave inventory, rewards, schedules, movement, and save state unchanged. Save/load must preserve the full nested receipt and assignment ledger.

## Reproducible independent reference checks
A standalone Python 3 standard-library oracle was exercised locally with **11 passing tests** after correcting a discovered year-boundary collision bug in the oracle itself. Tests covered valid claim, exact replay, cell collision, volunteer collision, missing consent, stale consent, past epoch, future epoch, negative shift, cross-cell receipt reuse, and year-three reuse of a cell. This is **local reference verification**, not exact-HEAD native Godot CI. No remote workflow success is claimed.

## Authorities and remaining gates
Village owns NPC consent and schedules; Principal owns authoritative global receipts, transaction idempotence, calendar admission and save migrations; Emergence owns independent denial/replay tests. E102 canonical catalog correction requires reviewed source and typed-state updates, then native Godot regression at exact commit. Do not interpret this document as permission to open Phase C or implement the feature.

Original assets: none required for the reference test. Eventual presentation: original grid overlays and iconography; keyboard/mouse, controller and touch equivalent selection/confirmation/cancellation. Budget target (not measured): O(n) search of active assignments, capped per-day grid occupancy; production should index by (day,cell,shift) and (day,volunteer,shift).
