# F17 — Market pricing and logistics: settlement contract v1

Status: **specifying; not implemented, not native-tested, not integrated**. Farming owns market shipment proposal and settlement validation; Village owns demand/orders, Principal owns authoritative inventory/currency/save and input routing, Construction owns physical loading zones. Base main SHA: `f37cf0f214cab00f75ba62dba9c3a1339e6c40a8`.

## Player loop and boundaries
At a shipping crate, player inspects available crops, quality, current village demand, transport capacity, fees and expected proceeds. Player chooses quantity/grade, confirms reservation, watches a day-epoch-based dispatch status, then collects a settlement receipt. A rejected or cancelled shipment visibly releases reservations; completed shipments cannot be sold again. Keyboard/mouse, controller focus/confirm/cancel and touch selection/confirm must produce equivalent commands. No direct edits to `game.gd`, farm, animals, Village or shared saves in this increment.

## Engine-neutral command contracts
- `quote(order_id, item_id, grade, quantity, day_epoch, demand_snapshot, inventory_revision) -> {quote_id, expires_epoch, gross_minor, fee_minor, net_minor, demand_revision, inventory_revision}`.
- `reserve(command_id, quote_id, expected_revisions) -> {shipment_id, reserved_items, dispatch_epoch, arrival_epoch, revision}`.
- `dispatch(command_id, shipment_id, epoch, transport_capacity) -> {shipment_revision, status}`.
- `settle(command_id, shipment_id, epoch, delivery_proof) -> {inventory_debit_receipt, money_credit_receipt, net_minor, shipment_revision}`.
- `cancel(command_id, shipment_id, epoch) -> {release_reservation, revision}`.
All proposal functions are side-effect-free. Principal must commit inventory, reservation, shipment revision, money and journal together or commit nothing. Unique command IDs and revisions reject replay and stale quotes. A quote is not a credit; dispatch is not a sale; only verified delivery settles.

## Fixed-point price model (proposed, not live balance)
All monetary amounts use integer minor units. Grade multipliers: standard 100/100, fine 120/100, premium 150/100. Demand multiplier is clamped to 70..160/100. Unit price = floor(base_minor * grade_factor * demand_factor / 10000), with integer arithmetic and explicit intermediate overflow checks. Gross = unit_price * accepted_quantity. Fee = ceil(gross * transport_fee_basis_points / 10000), with fee basis points 0..2000; net = gross - fee. Reject unknown item/grade, zero/negative/fractional quantity, negative price, missing demand revision, excessive quantities, expired quote and net < 0. No random demand changes without a recorded deterministic seed/event ID.

## Save and conservation
Schema candidate: `{schema:1,last_epoch:int,next_shipment_id:int,shipments:[{id,order_id,item_id,grade,quantity,quote_revision,inventory_revision,dispatch_epoch,arrival_epoch,status,gross_minor,fee_minor,net_minor,settlement_id}],commands:[{id,shipment_id,operation,epoch,receipt_id}],reserved_by_item:{}}`.
Validate nested state before applying; preserve every field across JSON roundtrip, normalize integer JSON values only after type/range checks. Use monotonic `day_epoch` across 56-day years. Maximum 32 open shipments, 128 pending units per shipment; archive completed records only with a durable idempotency watermark. For each item: available + reserved + delivered + authorized_other_debits = starting_inventory + authorized_grants (with explicit period accounting). For currency: ending_money = starting_money + sum(unique settled net receipts) + other_authorized_credits - other_authorized_debits. Transport fees are a ledger debit against gross, not a second inventory charge. Failure, cancellation and replay must have zero net change.

## Dependencies and handoffs
Principal: confirm reservation semantics, atomic transaction receipts, money units, migration and assembled-game save tests. Village: provide authoritative order IDs, item catalog, demand revisions and deterministic shock events; no parallel market payouts. Construction: stable loading dock/crate IDs and collision-safe interaction. Emergence: weather disruptions as deterministic delay proposals, never direct resource mutation. F16: artisan outputs can be shipped only after a confirmed inventory credit. Do not enable this domain before contracts are approved.

## Deterministic acceptance scenarios (planned, not executed)
1. Ship 3 standard crops at base 100 minor, demand 100%, fee 500bp: gross 300, fee 15, net 285, exactly 3 inventory units debited once.
2. Duplicate reserve, dispatch and settle commands before/after restart: no second reservation, item debit or money credit.
3. Stale demand revision and expired quote: reject without mutation; fresh quote reprices deterministically.
4. Reserve 5 units from inventory 4: reject; two simultaneous reservations totaling > inventory: second rejects.
5. Cancel before dispatch: full reservation release, no money; cancel after settlement: reject.
6. Day epochs 55..60 and 111..115: delivery and settlement remain once-only across year boundaries.
7. Spoiled/damaged shipment: explicit accepted quantity and loss receipt; payout cannot exceed delivered accepted units.
8. Corrupt nested JSON (duplicate shipment ID, negative fee, forged receipt, fractional count, invalid status, oversized queue): reject atomically.
9. Two-year assembled replay with farm harvest -> F16 processing -> shipping -> sale -> save/load: same money/items as uninterrupted replay.
10. Native Godot 4.x headless tests, full-game save tests and keyboard/controller/touch parity at exact final SHA before native-tested or integrated status.

## UI, original assets and performance
Original shipping crate, cart, grade markers, receipt icons, village market sign and shipment progress UI; provenance required. Provide explicit messages for reserved, insufficient stock, awaiting transport, weather delay, delivered, paid, cancelled and duplicate command. Accessibility: focus order, readable totals, reduced-motion receipt confirmation. Target <=32 open shipments, O(open shipments) daily update, zero per-frame logistics allocation; **unmeasured targets**, not device benchmarks.

## Gate
This commit documents the contract only. It does not prove functioning shipments, native CI, mobile controls or gameplay integration. Principal/Village/Construction approvals and exact-HEAD native acceptance are required before activation.
