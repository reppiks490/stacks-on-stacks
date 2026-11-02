# F05 — Weed and pest ecology (isolated native domain candidate)

**Mission:** F05 in the 100-mission charter, authored 2026-11-02. **Status:** implementing; native verification and gameplay integration must be recorded separately. Godot 4.x only.

## Behavior and player contract
Thirty original planting beds each track finite weed load, pest pressure, beneficial habitat, mulch duration, trap duration, cumulative crop stress and last action day. All integer values remain in bounded ranges. The deterministic `advance_day(day_epoch, rain_risk, heat_risk)` applies weather-driven growth, weed/pest interaction, beneficial-habitat suppression, finite mulch/trap effects, and crop stress. One calendar year is exactly 56 days. Daily updates require strictly increasing consecutive monotonic day epochs; replay or skipped days is rejected without mutation.

Player verbs (future Godot presentation adapter): inspect a bed for readable weed/pest/yield feedback; weed by hand; apply leaf mulch; set a pest trap; plant a beneficial flower strip; sow and clear crops. Each action returns a text receipt with `ok`, `message` and optional `item_required`. Player action routing, reach, energy, actual seed/tool/material debit, item availability, visual animations, and authoritative harvest remain in the existing Farm/Game/Principal systems and **are not wired by this module**.

The `yield_basis_points` forecast (4000–10000) is a domain-only deterministic pressure penalty; it does **not** mint produce, adjust existing Farm yield, or authorize harvesting. Counterfactual native tests compare identical 112-day weather and planted crops with/without preventive actions, demonstrating a causal forecast difference. This is a gameplay model, not an empirical claim about agricultural yield.

## Dependencies and authority boundaries
- Principal owns `game.gd`, `save_service.gd`, inventory/stamina, migration and the authoritative `day_epoch`. Request an optional versioned `farm_pest_ecology` save domain with strict schema-1 admission and legacy defaults. Do not alter those files in this lane.
- Farming owns `farm.gd` and 30 existing beds. Integrate by mapping index 0..29, existing crop IDs and daily weather once. Never double-apply legacy weed growth/yield penalties or silently change crop rewards. Atomic external item debit + ecology action + rollback must be proved by an assembled-game native test.
- Emergence owns bounded environmental risk/weather events; provide 0..100 integer rain and heat risk inputs with one canonical source per day.
- Construction owns original physical traps, mulching and flower-strip geometry; coordinate material contracts. F14 later owns pollinator network, so habitat here suppresses pests only, not pollination bonuses.
- Village/market must never settle the same yield adjustment twice. No new inventory, currency, animal or NPC fields.

## Native acceptance and limitations
`scripts/farm_pest_ecology_acceptance.gd` exercises 112 consecutive days, all 30 beds, a deterministic replay, identical-weather untreated control, multiple preventive interventions, bounded state and yield forecasts, eight seasonal JSON/deep-copy checkpoints, year rollover, 18 malformed nested saves, idempotent day/action gates and no money/item mutation. The dedicated push-only read-only Godot workflow must report exact SHA, native assertion count, and zero failures; until that run succeeds, this document is not proof.

**Still outstanding:** actual player-facing integration, harvest causality in the assembled game (only forecast is exercised here), save migration/authority, inventory/stamina rollback, keyboard/mouse/gamepad/touch physical input, original visual/audio assets, measured desktop/mobile frame-time and memory. Target per-day domain work is O(30) with bounded integer operations; this is an analytical budget, **not a measured device benchmark**. Art plan: original weed silhouettes, trap props, mulch material and flowering habitat markers with provenance manifests and desktop/mobile LOD tiers. No external/proprietary assets introduced.

**Integration gate:** Principal reviews save schema and receipt authority; Farming then binds existing actions/feedback and runs real assembled two-year conservation with QA. No Phase-C innovation features, PRs, Codex, engine port, or unrelated edits.
