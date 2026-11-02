# EVERBLOOM Emergence E071–E080: voluntary rituals typed-state handoff

**2026-11-02 · owner:** Emergence · **missions:** E03, E06, E18 · **status:** design-only, not implemented, not integrated.

## Exact source and isolation

- Pinned charter: `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Inspected canonical `main@edeeb2e4acffdc8f6f5d1b08a5e41c2ca6786867`, `docs/CROSS_LOOP_COORDINATION.md`, GitHub issue #2 and all twelve workflow definitions before writing.
- Immutable source ledger: `game/everbloom-emergence-phaseB-100-20261102/docs/innovation/emergence/phaseB_051_110.json`, blob `eb7c590f43c92ded0e328ecfdf7003fa7c06ceac`, authored in source commit `63cab5d05c742c61205933482e38fac2a4086764`.
- Isolated branch: `game/everbloom-emergence-e06-ritual-types-20261102`. Exclusive new files: `ritual_071_080.json`, `validate_ritual_071_080.py`, this handoff and dedicated push-only non-Codex workflow. No existing gameplay, assets, scripts, central save, economy, or other lane paths changed.
- The ten source concepts already exist in the Phase-B 100-concept ledger. **These are additional typed-state and adversarial contracts, not ten new playable features and not a fresh 220-feature approval.** Phase C remains closed.

## Scope and meaningful player actions

| ID | Interaction and hard negative boundary |
| --- | --- |
| E071 | Host a consented seasonal meal with dietary previews; each serving needs a distinct authoritative food debit. |
| E072 | Share memories of an actual recorded storm; no invented weather or public leakage of private stories. |
| E073 | Co-compose an original melody; contributor opt-out blocks public performance; visual rhythm alternative required. |
| E074 | Release and retrieve reusable floating lights; escrow and return receipts must account for every instance. |
| E075 | Invite a new resident once; declining is nonpunitive, no arrival reward replay. |
| E076 | Hold a silent/captioned observatory; Village booking clearance required, 56-day year checked by `day_epoch`. |
| E077 | Publish, privatize or retract a milestone; retraction removes the public projection receipt. |
| E078 | Run one eligible consented ballot per resident; serving requires actual stock debit receipts. |
| E079 | Trade optional story prompts, not currency; each spent token has one consented relationship receipt at most. |
| E080 | Propose an annual theme with voluntary projects; closing credit is bounded and year/booking gated. |

## Save and authority contract

Every feature uses a versioned, strictly typed, bounded `emergence.eb_e_###` namespace and two canonical fixtures (inactive/active), plus explicit hostile mutations. No implicit conversion of booleans to integers, no unbounded lists, no unknown nested keys, no duplicated ID or receipt inside the feature. The validator rejects invalid nested state; actual **atomic assembled-game save/load**, migrations, historical receipts and replay protection remain Principal-owned integration obligations. A valid local string receipt is **not proof** that the authoritative service issued it.

- **Principal** owns `day_epoch=(year-1)*56+season_index*14+day`, command IDs, immutable settlement receipts, transaction replay protection, save migrations and player input router. Only Principal may debit/reward inventory, money or energy.
- **Village** owns actual resident consent, schedule, arrival, festival calendar, reservations and relationship awards. Emergence must query Village, never trust saved proposed consent as authority.
- **Farming** owns actual food/seed stock and source provenance; a proposed meal/recipe does not create food.
- **Construction** owns reusable physical props/placements and structural art interfaces.
- **Emergence** owns optional ritual proposals, authored player choice and non-authoritative journal views. No cross-lane gameplay mutations have been made.

## Accessibility, original assets and performance

Design controls require keyboard/mouse focus and cancel, controller D-pad/stick and A/B, large touch targets and long-press details; all ritual content requires captions, readable high-contrast text, reduced motion and non-audio/non-color alternatives. These are specifications, **not device-tested UI**. Proposed logic targets 0.4 ms desktop and 0.2 ms mobile per active ritual, up to twelve active instances and four additional mobile draw calls. None are measured. Original, locally authored stylized-realistic icon/prop/short-audio kits require per-asset provenance, low-LOD fallback and license review before inclusion. No proprietary game media has been imported.

## Verification and integration gate

Reproduce local schema QA with `python docs/innovation/emergence/typed_state/validate_ritual_071_080.py --self-test`. Dedicated GitHub Actions runs this offline validator on push. Generic native CI also runs on push and validates the **existing** Godot baseline; it does not make these rituals playable.

Before Phase C: Principal independently approves the complete deduplicated 220-ledger, resolves authority and migrations, and selects a Godot slice. For each ritual, native Godot must then prove player interaction, consent and scheduling, authoritative finite inventory/relationship receipts, duplicate command denial, save/reload, 112-day rollover, keyboard/controller/touch parity, and measured desktop/mobile budgets. No Unreal/Unity port without owner approval.

**No PR** (generic workflow has a PR trigger; external autoreview cannot be ruled out), no Codex, no force push, no merge, no spending or publication. CI receipts and final exact branch SHA must be appended to issue #2 only after actually observed.
