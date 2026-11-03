# F16 — Artisan and Processing Economy | isolated engineering contract
Status: specifying (NOT implemented, NOT native-tested, NOT integrated)
Owner: Farming :12. Branch: game/everbloom-farming-f16-processing-contract-20261102
Authority: Principal owns inventory, currency, save service, clock and UI routing. Construction owns machine placement. Village owns customer orders. Farming owns recipe validation and deterministic processing proposals.

## Existing system compatibility and defects to avoid
The current playable farm harvests via game.grant_item; animals produce via game.grant_item. Processing MUST NOT separately mint outputs before an authoritative inventory settlement. The existing 30 beds, three animals, and 56-day monotonic game.day_epoch() remain unchanged. No edits to scripts/game.gd, scripts/farm.gd or scripts/animals.gd are authorized by this specification.

## Proposed interface v1 (engine-neutral payload; Godot adapter later)
`propose_start(machine_id, recipe_id, quantity, day_epoch, inventory_snapshot, machine_snapshot) -> {ok, reason, input_debits, batch_id, finish_epoch, machine_revision}`
`propose_complete(batch_id, day_epoch, machine_snapshot) -> {ok, reason, output_credits, waste_credits, machine_revision}`
`propose_cancel(batch_id, machine_snapshot) -> {ok, reason, return_credits, waste_credits, machine_revision}`
`propose_spoil(batch_id, day_epoch, machine_snapshot) -> {ok, reason, waste_credits, machine_revision}`
All proposals are side-effect-free. Principal executes debits/credits and state transition atomically in a single authoritative transaction; if any inventory debit or save precondition fails, neither machine nor inventory may change. Each command carries a unique idempotency key and expected machine revision. Completion can occur only once; cancellation after completion fails closed.

## Recipe ledger (original balancing proposal, not live game data)
| Recipe | Machine | Inputs per batch | Output | Days | Spoil window after completion |
|---|---|---|---|---:|---:|
| cultured_milk | dairy_vat | milk:2 | cultured_milk:1 | 2 | 4 |
| berry_preserve | preserving_kettle | strawberry:3, wild_herb:1 | berry_preserve:2 | 2 | 12 |
| herb_dye | dye_vat | wild_herb:3, water_token:1 | herb_dye:1 | 1 | 20 |
| wool_thread | spinning_wheel | wool:2 | wool_thread:2 | 1 | 30 |
All names are candidate IDs; `water_token` is a proposed item and must not be debited until Principal confirms its existence. Do not assume that milk, wool, strawberry or wild_herb are present in the current canonical item catalog without validation. Invalid or unavailable recipes are disabled rather than silently substituted.

## Persistent schema v1
`{schema:1, last_epoch:int, next_batch_id:int, machines:[{id,kind,revision,capacity,queue:[{batch_id,recipe_id,quantity,started_epoch,finish_epoch,status,completed_epoch,expiry_epoch}]}], journal:[{command_id,batch_id,operation,epoch,inventory_transaction_id}]}`.
All nested IDs unique; queue bounded to 2 batches per machine, 8 machines maximum, 16 pending batches maximum, quantity 1..10, journal bounded only through checkpointed compaction with preserved idempotency watermark. Reject invalid status, negative quantities, future last_epoch, duplicate batch IDs, missing transaction receipts, and invalid recipe versions. Loading must validate a deep copy completely before replacing live state; JSON numeric normalization must not discard fractional fields silently.

## Conservation and transactional invariants
For every item `i`, `initial_i + external_authorized_grants_i + processed_outputs_i + cancellations_i - processing_inputs_i - sales_i - spoilage_i = current_i`; track each source once. Transformations are not item-count conserving: they are **recipe-balanced** via exact integer input/output/waste records. Never claim physical mass conservation for differing item units. Failed start, duplicate completion, restart replay and stale revision produce zero net inventory changes. Perishable batches spoil at most once, and no processing transition can move backwards in day_epoch. `finish_epoch = started_epoch + duration_days`; an annual rollover must not reset completion eligibility.

## Player interaction, feedback, accessibility
Inspect machine -> preview ingredients, output, completion date, spoil risk and inventory shortfall -> confirm start -> see progress -> collect, cancel or discard spoiled batch. Keyboard/mouse context action, controller focus/confirm/cancel and touch tap/hold must map to the same command ID semantics. Show explicit 'missing ingredients', 'machine occupied', 'ready to collect', 'expired' and 'already collected' messages. No instant-cure/instant-production shortcuts. UI and input remain unimplemented.

## Art and performance
Original meshes: kettle, vat, spindle, jars, ingredient silhouettes; original progress indicator and low-motion alternatives. No external proprietary materials. Target <=8 machines, <=16 active batches, O(active batches) day tick, zero per-frame processing allocations; targets are NOT measured performance results. Construction must provide placement and collision IDs; Emergence weather inputs are optional, never allowed to mutate inventory directly.

## Deterministic acceptance plan (not yet executed)
1. Start with exactly 6 strawberries and 2 herbs; start 2 preserve batches; verify 4 preserve output after 2 days and exact input depletion.
2. Attempt same command twice and restart between calls; verify no additional debits.
3. Attempt completion one day early, twice on finish day, and after save/load; only first eligible completion succeeds.
4. Simulate day_epoch 55..60 and 111..115; processing and spoilage occur once across both year boundaries.
5. Cancel before completion and verify explicitly documented return policy (proposed: 100% unprocessed inputs; after processing starts cancellation produces waste, not refunded food). Principal must approve policy before implementation.
6. Fuzz nested JSON: duplicate IDs, negative counts, fractional counts, future timestamps, unknown recipe, forged receipt, oversized queue; reject atomically.
7. Two-year assembled game replay: farm harvest -> processing -> sale -> save -> reload -> same final inventories and money as uninterrupted replay.
8. Godot 4.x headless import + native domain acceptance + assembled save acceptance at same exact commit; keyboard/controller/touch tests when available.

## Integration gate
Await Principal inventory transaction/receipt and save-schema approval, Village pricing contract, Construction machine IDs. Until then F16 is a documented contract only, not a playable mechanic. Do not enable recipes in shipping gameplay or add unverified catalog items.
