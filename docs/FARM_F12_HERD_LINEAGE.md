# F12 — Herd lineage and reproduction (isolated native candidate)

**Mission:** F12 of the pinned EVERBLOOM charter `b8a1e635792b08b0a3d87b987e593a539ac5c123`. **Owner:** Farming. **Engine:** Godot 4.x. **Status:** implementing; native CI receipt required before marking native-tested. **Source:** `scripts/farm_herd_lineage.gd`. **Acceptance:** `scripts/farm_lineage_acceptance.gd`.

## Player experience and boundary

A future in-game animal ledger will let the player inspect a named animal's age, species, parent IDs, generation and inherited vigor/temperament/productivity; select two adults; inspect a clear rejection reason (immature, related, incompatible, low welfare, occupied housing, recovery); and approve one gestation. Gestation progresses through real game days; one birth creates one distinct, persistable animal identity. There is **no live UI, actual 3D animal spawn, economic purchase, feeding, or authoritative inventory credit** in this isolated candidate. `describe` and `request_breeding` return player-readable feedback for a future adapter. No assets or saved games were changed.

## Domain contract

- `reset()` seeds nine independent founders (two female, one male per species: hen/cow/sheep). This is an **optional genealogy test population**, not the three currently visible live animals. Preserve the live three animals until Principal approves a migration/ID contract.
- `request_breeding(mother_id, father_id, epoch, welfare_scores)` requires the exact monotonic day, correct species/sex, both adults aged >=56 days, generation <4, disjoint ancestral sets, 70/100 or better authoritative welfare for both, 28-day maternal recovery, and sufficient *reserved* herd capacity. It returns `{ok,message}`; failures never mutate. Welfare scores are supplied by a trusted future F11 adapter; untrusted client input is not a security boundary.
- `advance_day(epoch)` requires `epoch == last_epoch+1`, derives ages from birth epoch, and resolves exactly one offspring per due pregnancy: hen 14 days, sheep 21, cow 28. Pregnancy reserves capacity immediately, so delayed births cannot exceed total 18 or six per species. No random engine state or wall-clock time affects reproduction.
- `save_state()`, `load_state(Variant)`, `load_json(String)` roundtrip nested genealogy, gestation, ages, traits, counters, and IDs. Restoration validates the **whole** candidate snapshot before committing any field. JSON integral floats are normalized to ints; fractional, NaN, out-of-range, inconsistent ancestry, impossible gestation, duplicate IDs, oversubscribed capacity and hostile records are rejected without changing live state. No silent migration.
- Inheritance is deterministic: bounded parent-trait average plus a reproducible -2..+2 drift based on serial/day/trait. The model is a stylized game abstraction, not an animal genetics predictor.
- No removal/death/adoption yet. Founder records remain available so ancestor checks never silently lose their evidence. Future retirement must preserve immutable lineage tombstones before introducing removals. `next_serial` and `total_births` prevent ID reuse and accidental reproduction minting.

## Integration dependencies and ownership

**Principal:** approve optional nested `herd_lineage` save schema and migration from the current `animals` domain; own transactional save authority, input routing, one-and-only-one animal-spawn receipt and stable world IDs. Never patch `scripts/game.gd` or `scripts/save_service.gd` in this Farming branch. **F11 Farming:** map actual existing animal welfare to authoritative scores and validate identity; the current three animals must remain functional. **Construction:** supply real barn/paddock capacity; **Emergence:** supply bounded weather/welfare events; **Village:** optional animal names and community tasks. A future adapter must use a single authoritative transaction to settle births, housing and any feed cost, with idempotent receipts. This standalone domain does not alter money, items, player energy, crops, or production.

**Input/UX:** desktop inspect via existing interaction router, select parents with mouse/keyboard; controller focus/confirm/cancel; touch two-tap selection and explicit confirmation. All require native assembled-game tests and device checks; none are implemented here. Feedback must show parents, remaining capacity, due date, welfare gating and persistent lineage.

**Original asset plan:** independently authored juvenile/adult silhouette meshes for hen/cow/sheep, age-appropriate scale/idle animations, family-tree icons, barn-capacity UI and gestation markers. No copied game resources or licensed art are included.

**Performance target (unmeasured):** at most 18 live genealogy records, bounded ancestor traversal, one tick per in-game day, <1ms desired CPU per tick on mobile baseline and <32KB desired serialized domain payload. These are *budgets*, not measured performance claims; measure in native desktop/mobile before release.

## Deterministic acceptance

Run `godot --headless --editor --path . --import --quit`, then `godot --headless --path . --script res://scripts/farm_lineage_acceptance.gd`. Tests exercise 112-day repeated replay, annual 56-day rollover, two-generation hen ancestry, parent/sibling restrictions, maternal recovery, three species' gestation timing, capacity, welfare, duplicate epoch, 14-day nested JSON checkpoints, malformed/corrupt snapshot rejection and immutable failure state. CI is push-only `.github/workflows/everbloom-f12-lineage.yml` using checksum-pinned official Godot 4.7.2; general validation is independently push-triggered. A green domain test **does not** establish playable integration, hardware controls, real animal spawn, financial conservation across the assembled game or mobile performance.

**Release gate:** obtain exact-HEAD native log and general CI receipts; coordinate issue #2; Principal approval and full assembled-game save/restore are mandatory before changing mission status to integrated. The shared 220-feature invention ledger is separate and Phase C remains closed.
