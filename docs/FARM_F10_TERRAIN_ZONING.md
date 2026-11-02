# EVERBLOOM F10 — Irregular farm terrain and collision-safe zoning

**Mission:** F10. **Status:** isolated Godot 4.x implementation candidate, NOT integrated into normal gameplay. Branch: `game/everbloom-farming-f10-terrain-zoning-20261102`. Domain: `scripts/farm_terrain_zoning.gd`; native acceptance: `scripts/farm_terrain_acceptance.gd`; workflow: `.github/workflows/everbloom-f10-terrain.yml`.

## Original player loop and UX design

Player selects Inspect Terrain to preview a translucent, original grid over the existing homestead. They trace a connected, irregular plough footprint (including an L shape), reserve an agricultural field, extend an accessible path, or preview a small building footprint. Green/amber/red previews show allowed terrain, steep grades and collisions; text feedback explains rejected placements. A path cannot be cancelled while it is needed to reach a building. Cancelling an unbuilt proposal releases only its cells; it cannot refund materials that were never charged. Same-day cancel/recreate is blocked.

**Proposed controls, NOT implemented:** mouse drag/click with keyboard Escape and mode shortcuts; gamepad stick selection, face-button confirm, B cancel; touch drag with focusable >=44 px Confirm/Cancel buttons, non-color-only feedback and localized strings. There is no live overlay, new input binding, actual plough footprint or constructed building in this isolated module.

## Domain, conservation and persistence

- Fixed 18x14 (252-cell) integer planning map. All **30** existing farm beds are permanently reserved at `(1+2*x,1+2*z)` for `x=0..5,z=0..4`; none are relocated or replaced. Twelve permanent public trail cells at `x=12,z=0..11` exist in the **planning model only**, not as rendered assets.
- Proposed mapping from planning grid to the existing farm's X/Z positions: `world_x=-20+0.9*(x-1)`, `world_z=-1+0.9*(z-1)`. Existing bed centers remain at `(-20+1.8*x,-1+1.8*z)`. Terrain grade is a deterministic 0–25 **proxy**, not an actual mesh slope or elevation measurement; Construction must validate real geometry.
- Sorted unique orthogonally connected footprints contain 1–12 cells (buildings require >=2). Max grade: field 18, path 24, building 16 with <=9 grade variation. Fields must border an existing bed/trail/reachable path; buildings must border a trail/reachable path; every new path must remain connected to a protected bed/trail through the access network. No farm/building/path overlap.
- Stable plan IDs start at 31, are never reused, and permit at most 100 live proposals. `advance_day(epoch)` requires exactly one monotonic increment; 56 days/year, no yearly reset. `changed` timestamps reject same-day cancel/recreate. Domain status and command results return player-readable feedback.
- Every cell is either one of 30 immutable beds, one of 12 immutable trail cells, unoccupied, or referenced exactly once by a live plan. `save_state` deep copies; `load_state` checks exact nested keys, integer bounds, immutable bed/trail geometry, deterministic grade, plan/cell bijection, connectivity, timestamps and nonoverlap before committing. `load_json` converts only bounded exact integral JSON numeric values. Invalid nested states reject atomically.
- **No money, stamina, materials, crops, terrain meshes or actual buildings are modified.** These are planning reservations, not authoritative build/cancel inventory transactions. F19 owns real resource settlement.

## Cross-loop handoffs

**Principal P01/P04/P07/P08:** approve a versioned optional `farm_terrain_zoning` save namespace, atomic player command and rollback, authoritative reach checks, input/UI accessibility and assembled-game save roundtrip. Do not edit Principal-owned `scripts/game.gd`, `scripts/save_service.gd` or HUD until coordinated.

**Farming F01/F02/F03/F09:** preserve 30 live beds and existing farm interactions; future irregular plots require a new bed-ID/migration contract. Never double-charge stamina or treat a planning reservation as a harvested/tilled bed.

**Construction/F19:** verify physical slope, clearance, building materials, labor and construction transactions; preserve path dependencies. This existing F10 baseline work is separate from the 220-concept invention backlog and does not open innovation Phase C.

**Emergence/F18:** weather, flood and erosion changes require explicit deterministic terrain authority, versioning and save migration; no environmental event integration is claimed.

**Original asset plan:** original painterly translucent cell overlay, contour/grade decals, green/amber/red footprint ghosts, readable localized warnings, controller focus indicators. All assets require independent provenance.

## Verification and performance limits

Native command: `godot --headless --path . --script res://scripts/farm_terrain_acceptance.gd` after Godot import. Push-only non-Codex CI downloads SHA-256-pinned official Godot 4.7.2 and retains import/acceptance logs. Runner covers 112 days (two 56-day years), deterministic parallel replay, all 30 protected beds, irregular L field, path-dependent building, forbidden overlaps, safe cancellation, eight seasonal JSON/deep save checkpoints, hostile nested mutations and 252-cell occupancy conservation.

Target future planning budget <=1 ms per action on mobile, <=0.5 ms on desktop; these are **unmeasured targets**. A CI-host microsecond duration is not mobile FPS, real-world slope proof, touch/controller verification, a playable building system, or assembled-game persistence. Update status only after inspecting exact-commit CI logs. No Codex, PR, force, spending, publication, proprietary assets or engine port.
