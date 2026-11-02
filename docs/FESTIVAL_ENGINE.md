# EVERBLOOM — Original Annual Festival Engine

## In-game feature, not concept art

The original seasonal calendar has **12 distinct celebration days, three per season**, with unique names, offering requirements, authored flavor descriptions, bounded rewards, an original lantern stage, Godot input binding and HUD status. It is inspired by the idea of a close-knit farming village celebrating together, **not copied from a commercial title**.

**Where:** Larkspur Village lantern stage, near world position `(30,0,0)`. **When:** open at 08:00, closes at 20:00. **Control:** `T` near the stage. You must bring the advertised items and have 3 energy. A successful contribution consumes only the declared offering, awards bounded petals, restores a little valley harmony and issues one original festival ribbon. A contribution is permitted **once per festival, per calendar year**; repeat requests don't spend resources or duplicate rewards.

## Fully authored calendar

| Season | Day 3 | Day 8 | Day 13 |
|---|---|---|---|
| Spring | Dewwake Seed Exchange | First Bloom Table | Bluebell Evening |
| Summer | Glimmer Lake Promenade | Sunberry Picnic | Solstice Lantern Workshop |
| Autumn | Amberroot Fair | Ember Orchard Stories | Cloudthread Weaving Day |
| Winter | Hearthglass Market | Evergreen Craft Fair | Nightglow Promise |

The engine loads `data/festivals.json`, a distinct event for each season/day pair. All offering requirements are verified against obtainable crop seeds/produce, animal products, wild herbs or fish. The original Winter craft-fair offering uses foraged herbs, since the first game build does not yet implement wood gathering. The events have original descriptions, distinct themes and rain shelter design, not third-party artwork or music. The prototype stage currently uses **original Godot primitive materials** and two softly pulsing lantern lights. Real art, stalls, animations, villagers and minigames are future production work.

## Canonical integration contracts

- **Principal:** `scripts/game.gd` instantiates `scripts/festivals.gd`, calls `next_day`, registers `T` and persists `festivals` in optional schema-1 save data. Existing schema-1 saves without a festival field remain loadable.
- **Festival:** synchronous `act(position)` is gated by real world proximity, event day, opening hours, inventory, energy and an annual `year:id` entitlement key. The method debits costs **before** recording the single successful award and does not persist user-provided bonuses.
- **HUD:** line shows the next event countdown, today's needed item or a completed state.
- **Village owner:** responsible for eventual NPC schedules, social participation, unique festival conversations and romantic/family attendance. No Village-owned scripts modified.
- **Art owner:** upgrades the primitive booth, adds seasonal decorations, animations and individually authored soundscapes. No world/valley files modified.
- **QA:** exact-HEAD Python catalog/mutation tests plus **real Godot main-scene** event/debit/duplicate/year-two/save-load acceptance.

## Source/native acceptance

```bash
python -m unittest tests.test_festival_catalog -v
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/native_festival_acceptance.gd
```

The non-Codex GitHub workflow `.github/workflows/everbloom-festival-acceptance.yml` pins official Godot 4.7.2 with its SHA-256. Its engine test directly loads the **actual main scene**, checks time/location/item gates, all 12 events, one-year duplicate resistance, second-year reset, JSON save roundtrip through the existing save service, invalid future/unknown awards, and verifies no resource duplication.

**Limits:** Festival participation is one offering interaction plus visual lantern stage, not yet a full social gathering, party NPC animations, minigames, bespoke musical score, family participation, authored cutscenes or a polished retail-quality experience. Source/native headless checks do not prove actual player input ergonomics, device FPS or visual excellence. No imported proprietary Harvest Moon resources, no licensed-offline asset claims, no paid features, no Codex.


## Integrated native save-compatibility repair

Independent festival testing against the concurrent farming/village update exposed a
**real full-game save failure**: Farming now writes `animals["__paddocks__"]`
as a three-element array of `{"forage": int}` records, while the Principal
schema-1 validator previously assumed every livestock record is a dictionary.
As a result, daily autosaves and manual saves could fail despite passing the
separate synthetic save test and 120-frame scene smoke.

The source guard now specifically accepts this known reserved paddock array
and requires **exactly three records, each with only integer forage 0..7**.
It retains the original strict per-animal validation for all other entries,
rejects malformed, out-of-range, extended and truncated paddock claims, and
continues accepting older schema-1 saves without the optional paddock data.

The real main-scene festival native test also verifies serialized paddock
compatibility, valid full-game save/load and duplicate-reward denial after
reload. The dedicated workflow is triggered by changes to `animals.gd` or
`save_service.gd` as an independent cross-lane integration regression.

This addresses one concrete source/runtime incompatibility. It does not
claim tested desktop power-loss atomicity, mobile storage permissions,
long-horizon save migrations, or complete multigenerational persistence.
