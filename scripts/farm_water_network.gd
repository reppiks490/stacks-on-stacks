extends RefCounted
## F02 finite reservoir and channel transaction ledger (engine-neutral Dictionary state).
## NOT connected to Farm.act or Game saves until Principal approves the schema.
## Water units are bounded gameplay units, not physical litres.
const BED_COUNT: int = 30
const MAX_BED_WITHDRAWAL: int = 30
const CHANNEL_EFFICIENCY_PERCENT: int = 90
const MAX_CAPACITY: int = 1000000
const MAX_DAILY_INFLOW: int = 1000000
const MAX_TOTAL: int = 1000000000000
const FIELDS := ["schema", "capacity", "initial", "stored", "last_epoch",
    "inflow_total", "spill_total", "evaporated_total", "delivered_total",
    "channel_loss_total", "withdrawals_today"]
const INTEGERS := ["schema", "capacity", "initial", "stored", "last_epoch",
    "inflow_total", "spill_total", "evaporated_total", "delivered_total",
    "channel_loss_total"]
var _state: Dictionary = {}

func _init(capacity: int = 600, initial: int = 240) -> void:
    var safe_capacity: int = clampi(capacity, 1, MAX_CAPACITY)
    var safe_initial: int = clampi(initial, 0, safe_capacity)
    var withdrawals: Array = []
    withdrawals.resize(BED_COUNT)
    withdrawals.fill(0)
    _state = {
        "schema": 1, "capacity": safe_capacity, "initial": safe_initial,
        "stored": safe_initial, "last_epoch": -1, "inflow_total": 0,
        "spill_total": 0, "evaporated_total": 0, "delivered_total": 0,
        "channel_loss_total": 0, "withdrawals_today": withdrawals
    }

func save_state() -> Dictionary:
    return _state.duplicate(true)

func load_state(payload: Variant) -> bool:
    # Reject invalid snapshots without mutating the active reservoir.
    if not _valid_snapshot(payload):
        return false
    _state = (payload as Dictionary).duplicate(true)
    return true

func balance_error() -> int:
    return int(_state["initial"]) + int(_state["inflow_total"]) - (
        int(_state["stored"]) + int(_state["spill_total"]) +
        int(_state["evaporated_total"]) + int(_state["delivered_total"]) +
        int(_state["channel_loss_total"]))

func status() -> Dictionary:
    return {
        "capacity": int(_state["capacity"]),
        "stored": int(_state["stored"]),
        "day_epoch": int(_state["last_epoch"]),
        "balance_error": balance_error()
    }

func next_day(day_epoch: int, runoff_inflow: int, evaporation_demand: int) -> Dictionary:
    # One catchment event per monotonic day. Replays, skips and invalid
    # external input fail atomically: no second rain or resource minting.
    if day_epoch < 1 or day_epoch > 2000000000:
        return _reject("Invalid calendar epoch.")
    var previous: int = int(_state["last_epoch"])
    if previous >= 0 and day_epoch != previous + 1:
        return _reject("Reservoir day must advance exactly once.")
    if runoff_inflow < 0 or runoff_inflow > MAX_DAILY_INFLOW:
        return _reject("Invalid finite runoff inflow.")
    if evaporation_demand < 0 or evaporation_demand > MAX_DAILY_INFLOW:
        return _reject("Invalid evaporation demand.")
    if int(_state["inflow_total"]) > MAX_TOTAL - runoff_inflow:
        return _reject("Reservoir lifetime inflow limit reached.")

    var next: Dictionary = _state.duplicate(true)
    var available: int = int(next["stored"]) + runoff_inflow
    var spill: int = maxi(0, available - int(next["capacity"]))
    var retained: int = mini(available, int(next["capacity"]))
    var evaporated: int = mini(retained, evaporation_demand)
    next["stored"] = retained - evaporated
    next["inflow_total"] = int(next["inflow_total"]) + runoff_inflow
    next["spill_total"] = int(next["spill_total"]) + spill
    next["evaporated_total"] = int(next["evaporated_total"]) + evaporated
    next["last_epoch"] = day_epoch
    var withdrawals: Array = []
    withdrawals.resize(BED_COUNT)
    withdrawals.fill(0)
    next["withdrawals_today"] = withdrawals
    if not _valid_snapshot(next):
        return _reject("Reservoir conservation check failed.")
    _state = next
    return {
        "ok": true, "message": "Reservoir updated.",
        "captured": runoff_inflow - spill, "spilled": spill,
        "evaporated": evaporated, "stored": int(_state["stored"])
    }

func irrigate(bed_index: int, withdrawn_units: int, day_epoch: int) -> Dictionary:
    # All-or-nothing debit. One player irrigation action per bed per day.
    # Fixed 90% channel efficiency: source debit = delivery + channel loss.
    if day_epoch != int(_state["last_epoch"]) or day_epoch < 1:
        return _reject("Advance the farm calendar before watering.")
    if bed_index < 0 or bed_index >= BED_COUNT:
        return _reject("Invalid planting bed.")
    if withdrawn_units < 1 or withdrawn_units > MAX_BED_WITHDRAWAL:
        return _reject("Invalid irrigation amount.")
    if int(_state["withdrawals_today"][bed_index]) != 0:
        return _reject("This bed was already irrigated today.")
    if withdrawn_units > int(_state["stored"]):
        return _reject("Not enough water in the reservoir.")

    var next: Dictionary = _state.duplicate(true)
    var delivered: int = (withdrawn_units * CHANNEL_EFFICIENCY_PERCENT) / 100
    var lost: int = withdrawn_units - delivered
    next["stored"] = int(next["stored"]) - withdrawn_units
    next["delivered_total"] = int(next["delivered_total"]) + delivered
    next["channel_loss_total"] = int(next["channel_loss_total"]) + lost
    next["withdrawals_today"][bed_index] = withdrawn_units
    if not _valid_snapshot(next):
        return _reject("Irrigation conservation check failed.")
    _state = next
    return {
        "ok": true, "message": "Irrigated bed %d with %d water units." % [bed_index, delivered],
        "withdrawn": withdrawn_units, "delivered": delivered,
        "channel_loss": lost, "stored": int(_state["stored"])
    }

func _reject(reason: String) -> Dictionary:
    return {"ok": false, "message": reason, "stored": int(_state["stored"])}

func _valid_snapshot(payload: Variant) -> bool:
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    var s: Dictionary = payload
    if s.size() != FIELDS.size():
        return false
    for key in FIELDS:
        if not s.has(key):
            return false
    for key in INTEGERS:
        if typeof(s[key]) != TYPE_INT:
            return false
    if int(s["schema"]) != 1:
        return false
    var capacity: int = int(s["capacity"])
    var initial: int = int(s["initial"])
    var stored: int = int(s["stored"])
    var epoch: int = int(s["last_epoch"])
    if capacity < 1 or capacity > MAX_CAPACITY:
        return false
    if initial < 0 or initial > capacity or stored < 0 or stored > capacity:
        return false
    if epoch < -1 or epoch > 2000000000:
        return false
    for key in ["inflow_total", "spill_total", "evaporated_total",
            "delivered_total", "channel_loss_total"]:
        if int(s[key]) < 0 or int(s[key]) > MAX_TOTAL:
            return false
    if typeof(s["withdrawals_today"]) != TYPE_ARRAY:
        return false
    var withdrawals: Array = s["withdrawals_today"]
    if withdrawals.size() != BED_COUNT:
        return false
    var day_withdrawn: int = 0
    for amount in withdrawals:
        if typeof(amount) != TYPE_INT:
            return false
        if int(amount) < 0 or int(amount) > MAX_BED_WITHDRAWAL:
            return false
        day_withdrawn += int(amount)
    if epoch == -1 and (day_withdrawn != 0 or int(s["inflow_total"]) != 0):
        return false
    if day_withdrawn > int(s["delivered_total"]) + int(s["channel_loss_total"]):
        return false
    return initial + int(s["inflow_total"]) == (
        stored + int(s["spill_total"]) + int(s["evaporated_total"]) +
        int(s["delivered_total"]) + int(s["channel_loss_total"]))
