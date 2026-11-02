# F11 — Animal welfare, deterministic domain candidate (2026-11-02)

**Mission:** F11 from `docs/EVERBLOOM_100_ADVANCED_MISSIONS.md` at charter commit `b8a1e635792b08b0a3d87b987e593a539ac5c123`. **Owner:** Farming. **Status:** executable isolated Godot 4.x domain and native regression candidate; NOT wired into playable animal care, shared save, HUD, or game inventory. The existing three animal actors and `scripts/animals.gd` are preserved.

## Domain and player actions

The original model tracks three stable animal IDs (`hen`, `cow`, `sheep`) with seven bounded 0–100 needs: nutrition, mood, grooming, social contact, space, health and sickness. Species temperament is immutable. Daily environmental pressure depends on finite space and explicit weather; sickness cannot disappear instantly, and treatment is a three-day course reducing severity by at most five per day. Extreme deprivation can reduce health; ordinary care improves welfare. `forecast(id)` exposes a bounded risk score and actionable needs for player-facing panels.

Proposed interaction: approach the existing barn animal and select Feed, Groom, Socialize or Veterinary Care from an accessible action wheel. Show quote, exact cost, welfare forecast, current treatment days and an explicit denial for insufficient resources or repeated action. A single completed action per animal/verb/monotonic day is permitted. Existing animal care remains authoritative until Principal approves an adapter. Proposed keyboard/mouse: proximity + E, mouse wheel/number choice and Enter; controller: interact face button, D-pad selection, confirm; touch: large 48px minimum animal target and 48px action tiles with confirmation. These are **design mappings, not tested or implemented controls**.

## Authoritative economy and state semantics

`act(id, verb, day_epoch, settle:Callable)` accepts an atomic, trusted settlement callback. It validates the animal, action, epoch, duplicate guard and treatment eligibility **before** calling `settle(cost)`. Only an explicit boolean `true` permits welfare mutation. A denied or duplicate action leaves state unchanged and does not call settlement. No item, money, animal product or restoration credit is ever created in this domain. The callback must be owned by Principal's game economy and atomically debit real resources, not a caller-provided unverifiable receipt. Existing `scripts/animals.gd` already charges grazing/feed and produces goods: **never invoke both care authorities for the same player action** or double-charge/debit. Do not expose untrusted callback selection to saves or player input.

`next_day(epoch, weather, space_by_id)` requires exactly the next epoch, a known weather value and one finite 0–100 space score for each existing animal. All input validation precedes state mutation. Year transitions use `day_epoch`, not repeating season/day counters; 56 days per year. The caller is responsible for advancing the shared calendar exactly once. Weather should be supplied by Emergence's authorized weather stream; space scores should come from Construction-approved occupancy/animal housing, not player-controlled free-form input.

`save_state()` emits `{version:1,day_epoch,animals:{hen,cow,sheep}}`, with each animal storing all seven metrics, immutable temperament, treatment_days and last_actions by verb. `load_state` strictly validates every nested field, rejects missing/extra species and fractional/negative/nonfinite values, and commits atomically only after full validation. Godot JSON numeric integral floats are accepted. Principal owns migration and schema placement; never add `welfare` to `game.gd` or `save_service.gd` without assembled-game save/load tests and schema review.

## Acceptance and regression

`scripts/farm_welfare_acceptance.gd` runs in actual Godot SceneTree headless. It checks three species, quote and failed-payment atomicity, duplicate daily debits, treatment not instantly curing illness, 112 daily transitions, eight 14-day JSON restore checkpoints, two independent deterministic replays, strict hostile nested-save rejection, finite needs, stable economy debits, and cared-versus-neglected welfare outcomes. Run with `godot --headless --path . --script res://scripts/farm_welfare_acceptance.gd`. Exact-head CI receipts and native assertion totals must be appended to issue #2 only after logs are verified; script presence is not a PASS.

## Dependency and performance budget

- **Principal:** approve authoritative atomic settlement, live UI dispatch and optional nested save schema; preserve old saves and fail-closed recovery.
- **Farming:** retain `scripts/animals.gd` baseline, never duplicate products or spend feed twice; reconcile F11 welfare into existing three-animal care after Principal approval.
- **Construction:** provide space/capacity scores and original barn enclosure plans; no unapproved house/material charges.
- **Emergence:** provide weather events and possible disease-risk inputs through validated, bounded contracts.
- **Village:** optional animal affinity and dialogue; no unauthorized social currency.
- **QA:** assembled-game 112-day native save/load, controller/touch hardware testing, input focus, Windows interrupted-write and device measurements.

Runtime goal: O(3) per day and O(3) per forecast, zero new scene nodes/physics bodies, no allocations proportional to elapsed years, <= 0.2 ms welfare step on target desktop and <= 0.5 ms on midrange mobile **as unverified targets**, not benchmarks. Original asset plan: independently authored simple animal health glyphs, feed/groom/treatment icons, colorblind-safe risk indicators, small welfare feedback animations and localized English/Spanish text; no extracted third-party artwork. Current presentation remains existing original primitive animals. No new paid services, Codex, PR auto-review or Unreal/Unity migration.

## Integration gate

The isolated native-tested domain alone is **not** F11 playable completion. Require exact-HEAD non-Codex CI, Principal authorization, integrated game save/load roundtrip across two years, player-driven input and UI, transaction conservation, and real desktop/mobile profiling before marking F11 accepted.
