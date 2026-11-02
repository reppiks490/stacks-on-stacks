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
