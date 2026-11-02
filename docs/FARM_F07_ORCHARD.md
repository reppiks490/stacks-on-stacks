# F07 — Orchards and perennial systems (isolated Farming candidate)

**Mission:** F07, status **implementing until exact-HEAD native evidence is inspected**. This is executable Godot 4.x domain code, not assembled gameplay and not a completed mission.

## Authority and integration boundaries

- Owner Farming. New pure `RefCounted` model `scripts/farm_orchard_ecology.gd` owns eight separate original orchard tree slots. It **does not replace or modify the existing 30 crop beds**, farm/animal scripts, Principal Game/HUD/SaveService, Village, Builder, Emergence or innovation catalog.
- Schema-1 save `{schema:1,last_epoch,trees[8],ledger:{generated,harvested,spoiled}}` is versioned, deeply copied and strictly validated. Tree fields: species (apple/pear/plum), rootstock (dwarf/standard), age_days, health, stress, pruned_year, harvested_year, fruit_units, quality, dormant and last_action_epoch. Save/load is isolated; **Principal approval required** before embedding under authoritative game save.
- Monotonic `day_epoch` starts at 1, advances once per day; year `floor((epoch-1)/56)+1`, 14 days per season. Calls with duplicate or skipped epochs fail atomically. No `year * day` collision.
- `plant(slot,species,rootstock,epoch)` returns a **proposed** sapling item requirement. `prune(slot,epoch)` returns proposed stamina cost. `harvest(slot,epoch)` returns proposed fruit quantity/quality and updates orchard's internal finite ledger. These methods **do not debit or credit** game inventory, stamina, gold, or reward. Before live integration Principal must authorize proximity, costs, durable unique command receipts and atomic settlement with rollback/retry semantics. Never call harvest directly from an untrusted UI; it is not an authenticated receipt.
- `advance_day(epoch,temperature_c,rainfall_mm)` uses replayable bounded weather values; Emergence must provide deterministic event weather through Principal's time authority, never mutate tree state directly. F01 soil/F02 water/F03 physiology adapters may be proposed later, not silently assumed.
- Builder owns original sapling/tree meshes, pruning and fruit props, seasonal material variation, touch-friendly tree interaction collider and material provenance. No third-party protected art included.

## Actual simulated behavior

- Tree age increases by one day per monotonic epoch, with bounded stress/health response to rain and heat. Dwarf rootstock offers a bounded yield bonus but is more sensitive to drought/heat. Spring pruning is at most once per tree per year and cannot be repeated or applied in another season.
- At Autumn Day 1 (day-of-year index 28), trees aged at least 56 days with sufficient health set fruit according to species, rootstock, stress and current-year pruning. Fruit quantity is 1..20 per tree; quality 1..5. First-year saplings cannot produce fruit.
- Winter Day 1 (index 42) marks remaining unharvested fruit spoiled; dormancy persists through winter and ends at spring rollover. Dormant trees recover stress more rapidly. No unlimited fruit or instant harvests.
- Conserved integer fruit ledger: `generated == harvested + spoiled + sum(tree.fruit_units)`. Every valid daily and harvest transition enforces this. The model intentionally does not count fruit as player inventory until Principal implements authoritative atomic settlement; the isolated `harvested` counter is a proposal/escrow ledger, **not proof of inventory credit**.
- Exact field sets and integer bounds reject malformed/negative/fractional/unknown/oversized state; `load_json` converts only mathematically integral, finite bounded Godot JSON numbers and rejects invalid values without mutating prior state.

## Player actions, UI and accessibility

- **Not yet active in game.** Planned: focus/tap orchard tree -> inspect species, rootstock, age, health, fruit readiness and quality; plant purchased sapling; spring prune; autumn harvest. Equivalent keyboard/mouse, gamepad face button and touch tap should call one authoritative interaction router; minimum 44px touch targets, text + icon cues (not color alone), visible cost/receipt and explicit error feedback. The domain `status(slot)` already returns player-readable messages but no on-screen orchard panel exists.
- Save-state namespace and engine-neutral integer contracts are portable; Godot is the only active implementation. Unreal/Unity port is prohibited until reliable Godot baseline and owner authorization.

## Reproducible acceptance and budgets

- `scripts/farm_orchard_acceptance.gd` executes 224 days / four 56-day years, exact duplicate replay, annual pruning and unpruned control, first-year maturity denial, finite autumn fruit/quality, winter dormancy, eight slots' daily feedback, 14-day save checkpoints, JSON roundtrips, negative state mutation and strict fruit conservation. It checks that pruning measurably improves actual harvest **proposals** and quality, without changing a separate simulated inventory.
- Run official SHA-256 verified Godot 4.x headlessly: `godot --headless --path . --editor --import --quit` then `godot --headless --path . --script res://scripts/farm_orchard_acceptance.gd`. Dedicated `.github/workflows/everbloom-f07-orchard.yml` uses read-only, push-only, non-Codex Actions with exact-head logs.
- Intended budget O(8) per day, O(8) save size, zero per-frame orchard simulation; these are **algorithmic estimates, not measured CPU/memory/FPS**. Physical PC/mobile device performance, input, assembled-game save/recovery, authoritative economy conservation and actual original orchard art remain unverified.

## Cross-owner handoff

Principal: approve nested `farm_orchard` schema migration, transactional sapling/stamina/fruit settlement, real Game/HUD and 112+ day assembled save tests. Farming: wire farm lifecycle and preserve existing 30 beds only after approvals. Builder: original tree/fruit asset kit and placement rules; Emergence: bounded weather events. No PRs due unresolved auto-review risk, no Codex, no forced refs, no paid actions, no publication.
