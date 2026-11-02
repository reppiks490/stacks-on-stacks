# Farming and husbandry integration contract — EVERBLOOM

## Owner / compatibility
Farming Architect owns `scripts/farm.gd`, `scripts/animals.gd`, `data/crops.json` and the separate native farming acceptance runner. Principal Architect retains `scripts/game.gd`, calendar, saves, inventory and tool inputs. QA retains its existing main validation workflow. No PR or Codex automation is involved.

The public methods are unchanged: `setup(host)`, `act(tool, global_position)` for farm; `act(global_position)` for livestock; `next_day(weather)` for farm and `next_day()` for animals; `save_state()` and `load_state(payload)`. The existing seven-tool controller continues to work without changes.

## Implemented farming mechanics
- Thirty fixed planting beds, now with persistent soil fertility (0–100), moisture (0–100), weed pressure (0–5), drought stress, crop age and watering days.
- Per-crop nutrient draw, drought tolerance, family and seasonal suitability; crop rotation bonus when alternating families. Seed vigor is a deterministic 0–2 trait derived from bed index, crop and monotonic day. This is *not* a complete genetics/breeding system.
- Water persists in the soil for more than one day; rainfall restores moisture. Growth requires sufficient moisture and fertility, and severe drought kills seedlings. Fallow tilled soil recovers gradually.
- The **existing till tool** becomes context-sensitive: till bare ground, clear weeds from an existing bed, or apply two wild herbs as natural mulch to restore fertility. This avoids an unimplemented new input binding.
- When seeds are depleted, planting purchases one seed directly for its catalog price if funds permit. Crop harvesting yields a small quality-based bonus, updates restoration and enforces one harvest per monotonic day. Strawberry and tomato regrow only after further growth days.
- Three growth-stage visuals are represented by continuous plant size and fruit size; these are original primitive placeholder meshes, not completed art.

## Implemented animal care
- Monotonic `game.day_epoch()` prevents daily action collisions after the first year.
- Each animal has persisted hunger, cleanliness, health, happiness, affection, neglect days and product cycle.
- Care requires fodder, wild herbs or a paid ration (6 petals). One care per day per animal; product generation requires adequate health and happiness. Neglect reduces wellbeing and interrupts production. This is a gentle simulation, not an animal welfare training resource.
- Save records are backward-compatible with older keys and clamp invalid numeric values.

## External contract and honest limitations
- The principal owns `game.day_epoch()` and must preserve its monotonic behavior; the farm calls it for seed vigor and harvest idempotence, and animals for once-per-day care.
- Crops remain inventory items without quality-tier-specific sale prices. Full genetic inheritance, advanced fertilizer recipes, farm buildings, grazing/illness treatment, bespoke meshes/animations, farm stores and full controller/mobile UX are **not** implemented.
- Farming/animal actions are triggered through the existing tool keys; `till` is the soil service tool. The existing `game.gd` shipping chest sells crops at catalog price, regardless of quality.
- Source validator and QA's main workflow remain unchanged. Independent native acceptance runner `scripts/farming_acceptance.gd` covers deterministic growth, regrowth, seed purchases, harvest, rotation, year rollover, livestock care, old saves and 56 days of calendar progression. Its dedicated non-Codex workflow is `.github/workflows/everbloom-farming-acceptance.yml`.
- Native import and engine-run acceptance **must pass on the exact branch commit before integration**. A 56-day scripted simulation is not evidence of completed content, graphics, actual device performance or an end-to-end playthrough.

## Second farming increment — bounded grazing and closed-loop compost (candidate)

- Animal care checks a seven-day rotating active paddock before spending fodder, herbs or petals. A full paddock has **7 forage units**; grazing consumes exactly one unit per care. Animals cannot graze in winter or rain. Depleted paddocks fall back to inventory/currency feeding. With no feed, care and rewards are denied.
- Three persistent paddocks recover forage each day, faster while resting than while active, with a modest rain-assisted recovery outside winter. Recovery is bounded by seven units. Week rotation uses monotonic day epochs. This is a deterministic resource model, not grazing AI or animal animation.
- Each animal yields one **compost** item per three successful separate-day care actions. The per-animal production ledger is persisted, clamped on load and not increased on failed or repeated same-day care. The existing till soil-service action consumes one compost (preferred over two herbs) to restore **32 fertility** and 12 moisture at an energy cost of 2. Livestock now supplies farm resources without requiring edits to the Principal-owned game code.
- Weeds now affect play: at pressure 2+ they reduce harvest quality, at 4+ they block growth until cleared, and every weed increases soil moisture loss. Clear them with the existing till action.
- Root save schema remains 1. Livestock state adds reserved key __paddocks__ with a length-three forage snapshot and per-animal compost_counter; previously saved animal records remain readable, invalid counters and forage are clamped, missing pasture entries start at full capacity. Compost uses the existing inventory ledger; Principal may expose a dedicated inventory slot later.
- Native farm acceptance now covers forage conservation, per-day recovery, free grazing balance, feed-shortage atomicity, compost minting and soil consumption, tampered save clamping and weeds halting growth. It does not prove actual grazing animation, pathfinding, breeding, winter barn systems, manual gameplay, mobile/controller behavior or performance. Capture exact-head native CI proof before integrating.

**Shared handoff:** Principal and QA should preserve game.weather, game.season(), game.day_epoch(), game.consume_item(), game.grant_item() and game.spend_energy() contracts. Village/World Art may add original paddock geometry, seasonal sensory cues and tutorials separately. No external assets added.
