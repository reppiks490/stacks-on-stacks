# V15 ↔ F16: Village market and artisan-processing transaction contract

Status: **specifying / NOT implemented / NOT native-tested**. Village-owned isolated handoff, based on canonical `main@f37cf0f214cab00f75ba62dba9c3a1339e6c40a8`. Cross-loop interface request to Farming F16, Principal P01/P04, Construction B13 and Emergence E102. No shared production or save file is changed by this document.

## Concrete player experience
The player brings an independently authored, catalog-validated artisan good to a village stall, inspects the displayed price and demand, chooses a quantity with keyboard/gamepad/touch, and confirms or cancels. A confirmed sale removes exactly the selected quantity and adds exactly the quoted petals. The receipt appears in the village journal; cancellation or invalid stock leaves both balances unchanged. The shopkeeper remembers a bounded sale category for future dialogue, but **does not** grant additional money or friendship for replaying a receipt.

A separate **processing order** lets the player submit ingredients to a machine at a stable world placement ID. The village only quotes retail prices; Farming owns ingredient-to-product conversion. Construction owns placement validity; Principal owns the authoritative inventory/currency transaction boundary and persistence.

## Proposed engine-neutral command envelope (not approved API)
```json
{
  "schema": 1,
  "command_id": "session-uuid-or-deterministic-replay-id",
  "actor_id": "player",
  "day_epoch": 57,
  "kind": "market.sell",
  "shop_id": "village.market.stall_01",
  "item_id": "everbloom:artisan_berry_preserve",
  "quantity": 2,
  "quote_id": "sha256-of-canonical-quote-fields",
  "quote_unit_petals": 31
}
```
The example item ID is a **proposed original identifier**, not a currently registered catalog item or usable product. The quote hash must bind item, shop, quantity, unit price, stock/demand revision and expiration epoch; never trust a client-supplied unit price. All numbers must be integers, nonnegative where appropriate; quantity must be in 1..99, price in 0..1,000,000, and arithmetic must be overflow-checked. A quote is read-only and may expire without changing resources.

## Authoritative state machine
1. `quote`: validates catalog, opening hours, shop capacity, sellability and finite pricing. Returns an immutable quote and an accessible localized reason on rejection.
2. `confirm`: revalidates current stock, quote revision and clock; checks `command_id` against bounded persisted receipt history; reserves the exact item quantity and applies currency credit as **one atomic transaction**. No partial commit.
3. `committed`: writes receipt `{command_id, day_epoch, shop_id, item_id, quantity, unit_petals, total_petals}` and updates demand once. Replaying an identical command returns the prior receipt **without** another debit/credit; conflicting reuse of an ID fails closed.
4. `cancel/reject`: releases any reservation; no changes to inventory, currency, reputation, social memory or shop demand.
5. `load`: reconstructs receipts and quote revision before accepting commands. Future-dated receipts, duplicate IDs with different payloads, negative balances, unknown items and invalid nested shapes must be rejected by Principal's save admission rather than silently discarded.

**Conservation:** `Δinventory[item] = -quantity`, `Δplayer_petals = +quantity × unit_petals`, `Δshop_treasury = -quantity × unit_petals` (or an explicitly budgeted mint/sink approved by Principal). Shop funds must cover the purchase; otherwise reject. Do not double-count `gold` and `petals` as separate wallets. Shop inventory increases by the purchased quantity; all four changes are a single commit. The existing V07 employment reward is a separate explicitly budgeted wage flow and must not be routed through this sale command.

**Time:** the only yearly/day gate is monotonic `day_epoch`, not `season_index * 14 + day`. An expired quote is never renewed implicitly. Receipts persist across the day-56 → day-57 boundary and later year rollovers.

## Cross-loop dependency and file ownership
- **Principal P01/P04:** approve authoritative atomic item/currency API, schema version, receipt retention/compaction and save validator. Principal alone modifies `scripts/game.gd`, `scripts/save_service.gd` and shared schema. Existing saves must migrate without inventing goods or money.
- **Farming F16:** owns recipe catalog, processing time, ingredients, outputs and cancellation refunds. Processing completion must carry one idempotent output receipt and cannot directly credit shop currency.
- **Construction B13:** owns stable machine placement ID and destruction/move lifecycle. Reject processing orders targeting missing, unbuilt or inaccessible machines; preserve pending order during legitimate relocation by explicit migration.
- **Village V15:** owns market price/demand rules, merchant hours, local UI, localization, sale receipts and deterministic Village-domain tests after Principal approval. No implementation may be mistaken for a functioning shop until assembled-game interaction passes.
- **Emergence E102:** dynamic events may request bounded demand modifiers but cannot mint inventory, override consent, bypass quote revisions or write receipts.
- **V19:** accessible focus, captions and confirm/cancel via mouse, keyboard, gamepad and touch; screen reader and physical device verification remain separate acceptance gates.

## Deterministic acceptance matrix (planned, not run)
| ID | Setup and action | Expected |
|---|---|---|
| V15-A01 | Sell 2 units at 31 petals with treasury ≥62 | -2 player goods, +2 shop goods, +62 player, -62 treasury, one receipt |
| V15-A02 | Replay exact command after save/reload | Same receipt, zero additional deltas |
| V15-A03 | Reuse command ID with different quantity | Reject, zero deltas |
| V15-A04 | Confirm stale quote after demand revision | Reject, zero deltas |
| V15-A05 | Confirm without enough inventory | Reject, zero deltas |
| V15-A06 | Shop treasury <62 | Reject, zero deltas |
| V15-A07 | Year rollover day 56 → 57 and retry | No duplicate; monotonic receipt preserved |
| V15-A08 | Inject duplicate/future receipt into save | Reject entire invalid snapshot; no partial restore |
| V15-A09 | Cancel from focused gamepad/touch/keyboard UI | No resource or relationship deltas |
| V15-A10 | Farm processing completes twice after reload | Only one product output; market funds unchanged |
| V15-A11 | Destroy machine with pending order | Explicit migration/refund policy, no lost or doubled ingredients |
| V15-A12 | Replay 112 days with price modifiers | Deterministic identical final serialized state and receipts |

## Performance and assets
Target ≤0.2 ms per market command on desktop and ≤0.5 ms on mobile at 100 active quotes, with bounded per-shop receipts and no per-frame pricing recomputation. **Targets only; no measurements yet.** Village stall, icons, sound cues, merchant portrait and motion must be original or rights-verified, with provenance recorded before inclusion. Text-only feedback is the fallback for low-end/mobile or reduced-motion tiers.

## Implementation gate
**BLOCKED pending Principal transaction/save-schema approval and Farming/Construction catalog-ID handoffs.** Do not modify shared files or implement speculative wallet mutations. After approval: add Village-owned code and Godot-native tests; run actual assembled-game save/load, command replay and three input paths; report exact source SHA, native logs, CI trigger audit and measured performance. No Codex, PR auto-review, force push, paid services or engine port.
