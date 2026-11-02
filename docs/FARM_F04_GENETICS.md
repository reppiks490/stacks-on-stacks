# EVERBLOOM F04 — Heritable seed genetics (isolated Farming candidate)

**Mission:** F04 · **Status at authorship:** implementing, native verification pending. This is baseline-domain work, **not** one of the 220 gated Construction/Emergence innovation features. Godot 4.x only.

## Implemented contract

- `scripts/farm_genetics.gd` is an original scene-independent `RefCounted` model retaining **30 indexed planting beds**, eight existing original crop IDs, and a monotonic `day_epoch` over **56-day years**.
- Three bounded diploid loci (`yield`, `pigment`, `hardiness`) each contain exactly two integer alleles in 0..3. The phenotype returns yield bonus 0..2, color variant 0..6, hardiness 0..3. These are **fictional gameplay genetics**, not real crop science.
- `sow(bed,crop,genome,epoch)` records the genotype only after an external authoritative seed debit; `pollinate(mother,donor,epoch)` requires distinct, same-crop established parents and snapshots donor alleles so later removal does not rewrite ancestry. `propose_seed_save(bed,epoch,harvested_units,harvest_receipt)` deterministically selects one allele per locus from each parent and returns up to four bounded seed-genotype **proposals**. Replanting an offspring genome retains inherited phenotype. The user sees `status(bed)` feedback and cross state.
- **No authoritative inventory, gold, stamina, crop age or harvest output is changed.** The external `F03:bed:epoch:crop` receipt is only string-shape checked, **not cryptographically or authoritatively verified**. This model must never be connected directly to item grants. Principal must provide authenticated, durable, replay-resistant harvest and inventory settlement before gameplay integration.
- A plant can be crossed and have seeds proposed only once per sow; no same-day sow/clear/cross/reward reuse. Seed proposal count 1..4 is a gameplay cap. Further perennial seed harvests require a future explicitly versioned contract, not a hidden reset.
- `advance_day(epoch)` requires exact sequential epochs. `save_state()` deep-copies all nested fields; `load_state(payload)` strictly validates schema, 30 beds, exact field names, allele bounds, chronology, cross donor, types and consistency **before** atomic replacement. Unknown/invalid states are rejected rather than clamped.

## Reproducible native proof

Run from repository root with Godot 4.x:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://scripts/farm_genetics_acceptance.gd
```

The native runner covers **112 sequential days**, all 30 beds, eight seasonal nested-save checkpoints, two generations of allele inheritance, identical replay and restoration, crop mismatch, immature pollination, forged receipt shape, duplicate seed prevention, bounded phenotype, deep-copy isolation and adversarial corrupt nested state. The runner uses **synthetic F03 receipt strings** for domain-only proof; it does not demonstrate a real harvested crop or item credit. Dedicated non-Codex push-only CI is `.github/workflows/everbloom-f04-genetics.yml`, with checksum-pinned official Godot 4.7.2. Do not report native PASS without actual exact-commit workflow evidence.

## Cross-loop dependencies and player experience

| Boundary | Owner | Integration condition |
| --- | --- | --- |
| Calendar and weather | Principal | Use `game.day_epoch()` and only advance once per day; no change to `game.gd` in this candidate. |
| Existing 30 beds and eight crops | Farming | Keep `farm.gd`, `data/crops.json`, current harvesting and visuals intact. F03 phenology/harvest and F01 soil/F02 hydrology are separate isolated candidates. |
| Seed inventory and economy | Principal + Farming | Debit a **specific genetic seed lot** atomically on sow, verify actual F03 harvest before proposing, settle only one durable F04 receipt, and never credit twice after restart. Current seed inventory lacks lot/genome provenance. |
| Save admission and migrations | Principal | Approve optional versioned `farm_genetics` snapshot and reject lossy nested state; legacy saves must default deterministically. Native assembled-game 112-day roundtrip mandatory. |
| Village and construction | Village + Builder | Seed exchange/market prices and house material costs must be approved before integration. No assumptions about existing sale or build APIs. |
| Environmental events | Emergence | Future frost/disease selection may consume bounded hardiness phenotype, never rewrite alleles without an explicit breeding action. |
| Rendering and controls | Principal + Farming | Proposed inspect/plant/cross/seed-save UI: keyboard/mouse focused-bed context action, controller focus and confirm, touch tap plus accessible action sheet. Existing player routing and HUD remain unchanged. |

**Original asset plan:** authored color-variant seed packet icons, parent lineage glyphs, three-tier hardiness leaf silhouettes, cross-pollination flower cues and a high-contrast pedigree panel. No external protected assets. **Target, not measurement:** O(30) save validation, O(3) offspring per seed, at most four seed proposals per action, no per-frame simulation; <1 ms/day on reference desktop and mobile-friendly small HUD. Real PC/mobile performance, gamepad/touch parity, legibility and accessibility are **unmeasured**.

## Honest limitations and next gate

This is a **native-testable isolated genetics model**, not player-facing seed breeding in the assembled game. No real seed lot inventory, UI, audio, art, greenhouse pollination, genetics-aware sale economy, persistence migration, or end-to-end controller/touch test exists in this increment. External receipt authenticity is an explicit blocker. F04 must not be marked integrated or fully accepted until Principal approves atomic seed/harvest settlement, Farm supplies the adapter, and exact-head assembled Godot proof passes. Other missions and the innovation Phase-C gate are unchanged.
