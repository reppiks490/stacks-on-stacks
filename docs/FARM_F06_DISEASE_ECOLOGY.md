# F06 — Plant disease ecology (isolated native candidate)

**Status:** implementing; only mark native-tested after exact-HEAD Godot logs. No player-facing integration or completed F06 claim.

## Authority and ownership

- New `scripts/farm_disease_ecology.gd` is a pure `RefCounted` deterministic model for the existing **30** planting beds and original eight crop IDs. It does not replace `scripts/farm.gd`, own `scripts/game.gd`, mutate Principal's `save_service.gd`, or alter authoritative inventory, currency, stamina, harvest, and seeds.
- Owner: Farming F06. Principal must approve versioned nested `farm_disease` persistence, atomic resource debit/rollback and day sequencing before activation. F05 weed/pest ecology may later provide a bounded disease-exposure modifier only through a documented, replayable adapter. Emergence supplies external humidity/storm events, never direct unverified state edits.
- Use `advance_day(day_epoch, humidity_0_100, wind_0_100)` **exactly once** per monotonic day; 56-day year is `(epoch-1)/56+1`. `register_crop(index, crop_id, epoch)` and `clear_crop(index, epoch)` require authoritative crop lifecycle receipts, not direct calls from an untrusted UI.
- `act(index, "sanitize"|"quarantine"|"treat", epoch)` returns proposed `item_required` and feedback, but **does not debit** it. Principal's atomic transaction must authorize stamina, proximity, inventory and a durable unique command receipt **before** committing model action, or restore the previous snapshot if settlement fails. A once-per-bed daily action guard does not replace durable command replay protection.
- `status(index)` is a player-readable view: infection, acquired immunity, cumulative damage, projected yield. It does **not** change actual farm harvest quantity until Farming and Principal integrate the authoritative harvest calculation.

## Mechanisms and limits

- Every day, 6x5 cardinal neighbors supply radius-one exposure from the **previous day's** infection, never order-dependent current-day mutations. Quarantine blocks inbound and outbound local spread while active; it is not a cure. High humidity drives pressure, wind amplifies existing incoming spread; sanitation temporarily reduces exposure.
- Infection and damage are integers bounded 0..100. Existing infection can recede over multiple days under treatment or dry conditions; treatment never changes infection immediately. Recovery can add bounded immunity. No instantaneous blanket clearing, negative infection or unlimited chain spread.
- Strict schema-1 save: `{schema,last_epoch,beds[30]}`; exact field sets and integer bounds, valid crop catalog, no infection/immunity/damage on empty beds. `save_state()` deep copies; `load_state()` fails closed atomically. `load_json()` only converts mathematically integral JSON floats within finite bounds, then applies identical validation. No migrations, old-save rewrites or automatic integration.
- Existing calendar and game visuals are untouched. Intended original art: procedural leaf speckles and localized leaf discoloration, simple quarantine mesh/rope icon, disease inspection card; all original assets with provenance before integration.

## Player interaction / UI / controls

- Planned: inspect bed (mouse click / keyboard interact / controller face button / touch tap) to read infection risk; contextual sanitize, cover, and treat options with explicit item, stamina and duration; 44px touch targets and colorblind-safe shape/text disease severity, non-flashing warnings, subtitles for cues. This **is not implemented** by the isolated model.
- Engine-neutral domain state is a bounded integer dictionary; Godot is currently the sole implementation engine. Unreal/Unity ports are out of scope.

## Acceptance and performance

- `scripts/farm_disease_ecology_acceptance.gd` exercises deterministic 112-day replay, once-per-day rejection, 56-day rollover, all 30 bounded bed feedback paths, treatment causal forecast, radius-one spread and quarantine control, eight 14-day save checkpoints, deep copy, JSON roundtrip and malformed nested save rejection.
- Target: O(30 × 4) neighbor evaluations per day, zero per-frame simulation work and bounded snapshot size. **Not a measured device performance result**; mobile/controller physical hardware, assembled game save, in-game treatment UI, inventory conservation and crash recovery remain unverified.
- Native command (after installing checksum-verified official Godot 4.x): `godot --headless --path . --editor --import --quit`, then `godot --headless --path . --script res://scripts/farm_disease_ecology_acceptance.gd`.
- Dedicated push-only, read-only CI workflow `.github/workflows/everbloom-f06-disease.yml` uses no Codex and preserves logs. Do not create PRs: existing generic workflow has a `pull_request` trigger and auto-review cannot be ruled out.

## Integration handoff

Principal: approve persistent nested domain contract and authoritative transactional action receipts, then run assembled-game two-year save/recovery. Farming: reconcile F01–F05 and attach F06 to real crop lifecycle and harvest only after integration approval. Emergence: provide replayable humidity/weather signals; Builder: original greenhouse/quarantine assets and resource contract. Do not claim this as integrated gameplay or a completed F06 mission.

## Reconciliation checkpoint

The isolated F06 branch incorporates the disjoint Principal main changes through a non-force two-parent merge at `addf9b6aef15440e0295d3d0056a6de421ff7a28` (source main `5415067e5803fe087d25e27f413e62201a534269`). Only four new Farming-owned paths differ from that source main. This is **not** a merge into canonical `main`. CI must be rerun against the subsequent exact branch HEAD before acceptance; future main movement requires another fresh comparison.
