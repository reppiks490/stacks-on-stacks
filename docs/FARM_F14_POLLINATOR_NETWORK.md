# F14 — Pollinator habitat networks (isolated native-tested candidate)

**Mission:** F14, EVERBLOOM Farming/Ecology. **Owner:** Farming :12. **Engine:** Godot 4.x only.
**Exclusive files:** `scripts/farm_pollinator_network.gd`, `scripts/farm_pollinator_acceptance.gd`, this document, `.github/workflows/everbloom-f14-pollinators.yml`.
**Status:** implementation candidate pending exact-HEAD native acceptance; NOT connected to the live farm, inventory, harvest or save UI.

## Player verbs, feedback, controls and ecology
The original simulation exposes six habitat sites influencing the existing 30 planting-bed identifiers (six columns by five rows). Three verbs are `flower_patch` (2 model credits), `nesting` (3) and `corridor` (4). One action per habitat per monotonic day. `describe_site()` and returned action messages give clear readable feedback. `preview_yield(bed, base)` is a **non-mutating forecast**, not a harvest or inventory grant.

Planting flowers raises local pollination and can improve a nearby crop's projected yield. Nesting reduces storm mortality. Connected neighboring corridors allow finite colony migration in spring/autumn without creating population. Climate and the 56-day calendar affect nectar, seasonal flowers, storm mortality, winter dormancy, drought and crop bloom. Colonies are bounded 0–100 per site; all habitat and nectar fields are bounded. This is a stylized gameplay model, not a scientific bee population forecast.

**Input integration (NOT YET BUILT):** keyboard/mouse select habitat and activate the three verbs; gamepad d-pad/left stick focus + confirm; touch large selectable habitat cards and one-tap action buttons. Principal owns any actual player input routing and save panel; Farming will implement an adapter only after interface approval. No original 3D flower/bee/colony models or VFX have been authored yet. Planned original assets: low-poly flowers in seasonal color variants, colony shelter, pollinator sprites/particles and a legible accessible habitat overlay, with reduced-motion and mobile fallback.

## State, economy and authority
`save_state()/load_state()/load_json()` roundtrip exact nested version/epoch/season/weather/30 bloom levels/6 habitat nodes/ledger. Strict validation rejects missing/extra fields, invalid types, nonfinite/fractional values, impossible bounds and colony or budget conservation mismatches. Failed loads are atomic. `advance_day(epoch,weather,season,bloom)` requires the next monotonic epoch and 30 validated crop bloom levels; same-day and skipped-day replays fail closed. `act(index,action,epoch)` cannot repeat on the same habitat/day.

**Budget invariant:** 60 fixed **model-only test care credits** = spent + remaining. This is not an authorized game inventory currency and must never be credited to the player. **Colony invariant:** 72 founders + births − deaths = sum of six living colonies; corridor migrations conserve that total. The isolated module does not grant seeds, honey, money, harvests or restoration points. No external receipt is authenticated here.

**Principal handoff:** determine an authoritative inventory/energy transaction API, a schema namespace for nested F14 save fields and a single harvest settlement point before attaching this model to `scripts/game.gd` or `scripts/farm.gd`. A signed or otherwise trusted one-time transaction receipt must be checked by the authority; the domain cannot self-authorize spending or yield grants. Preserve existing 30-bed save state and historical save compatibility.

**Construction handoff:** only original pollinator habitat props may be placed after verified terrain clearance; F10 zoning and Builder placement must agree. **Emergence handoff:** climate events supply validated weather/season signals, with no duplicate environmental day processing. **Village handoff:** markets may consume actual settled harvest receipts, never the forecast.

## Reproducibility and limits
Run `Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --import --quit`, then `Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://scripts/farm_pollinator_acceptance.gd`. The isolated runner covers 112 epochs (two 56-day years), deterministic replay, causal yield difference, finite budget/colony invariants, seasonal behavior, corridor migration, eight JSON save checkpoints and hostile-state rejection. Exact-HEAD workflow: `.github/workflows/everbloom-f14-pollinators.yml` (pinned official Godot 4.7.2 SHA256). A successful native runner does **not** establish live gameplay, device performance, mobile/controller interaction, full-game persistence or genuine 3D art.

**Performance design target (not measured):** six sites × 30 beds = at most 180 site-distance contributions per full-bed preview pass, plus O(6) daily updates; target under 0.25 ms per 30-bed update on midrange desktop and under 1 ms on mobile. Require actual profiling on target hardware before integration. No external assets, paid services, Codex, PR, or premature Unreal/Unity port.
