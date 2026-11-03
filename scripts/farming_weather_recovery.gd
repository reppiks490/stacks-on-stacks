extends RefCounted
## F18 isolated, side-effect-free farm weather impact ledger.
## Never directly modifies canonical farm, inventory or game state.
const MAX_BEDS := 30
const EVENTS := ["clear", "heat", "storm", "flood", "frost", "drought"]
const RECOVERY_COST := {"heat": 2, "storm": 3, "flood": 4, "frost": 3, "drought": 2}
var last_epoch := -1
var bed_stress: Array = []
var receipts: Dictionary = {}
var recovery_credits := 0
var credits_spent := 0

func _init(beds: int = MAX_BEDS, credits: int = 40) -> void:
    assert(beds > 0 and beds <= MAX_BEDS)
    assert(credits >= 0)
    bed_stress.resize(beds)
    bed_stress.fill(0)
    recovery_credits = credits

func advance(epoch: int, event_name: String, severity: int) -> Dictionary:
    if epoch <= last_epoch or epoch < 0 or not EVENTS.has(event_name) or severity < 0 or severity > 3:
        return {"ok": false, "reason": "invalid_or_duplicate_epoch"}
    var increments := {"clear": -2, "heat": 2, "storm": 3, "flood": 4, "frost": 3, "drought": 2}
    var delta: int = int(increments[event_name]) * severity
    if event_name == "clear":
        delta = -2
    for i in range(bed_stress.size()):
        bed_stress[i] = clampi(int(bed_stress[i]) + delta, 0, 100)
    last_epoch = epoch
    return {"ok": true, "epoch": epoch, "event": event_name, "stress": bed_stress.duplicate()}

func recover(command_id: String, bed_id: int, event_name: String) -> Dictionary:
    if command_id.is_empty() or receipts.has(command_id) or bed_id < 0 or bed_id >= bed_stress.size() or not RECOVERY_COST.has(event_name):
        return {"ok": false, "reason": "invalid_or_replayed_command"}
    var cost: int = int(RECOVERY_COST[event_name])
    if recovery_credits < cost or int(bed_stress[bed_id]) == 0:
        return {"ok": false, "reason": "insufficient_credits_or_no_damage"}
    recovery_credits -= cost
    credits_spent += cost
    bed_stress[bed_id] = maxi(0, int(bed_stress[bed_id]) - 12)
    receipts[command_id] = {"bed": bed_id, "epoch": last_epoch, "cost": cost}
    return {"ok": true, "cost": cost, "remaining": recovery_credits, "stress": bed_stress[bed_id]}

func snapshot() -> Dictionary:
    return {"schema": 1, "last_epoch": last_epoch, "bed_stress": bed_stress.duplicate(), "receipts": receipts.duplicate(true), "recovery_credits": recovery_credits, "credits_spent": credits_spent}

func restore(state: Dictionary) -> bool:
    if state.size() != 6 or int(state.get("schema", -1)) != 1:
        return false
    if not state.get("bed_stress") is Array or not state.get("receipts") is Dictionary:
        return false
    var stresses: Array = state["bed_stress"]
    if stresses.size() != bed_stress.size():
        return false
    for v in stresses:
        if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
            return false
        if float(v) != float(int(v)) or int(v) < 0 or int(v) > 100:
            return false
    for key in ["last_epoch", "recovery_credits", "credits_spent"]:
        var v = state.get(key)
        if (typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT) or float(v) != float(int(v)):
            return false
    if int(state["last_epoch"]) < -1 or int(state["recovery_credits"]) < 0 or int(state["credits_spent"]) < 0:
        return false
    var checked: Dictionary = {}
    var spent := 0
    for command in state["receipts"]:
        var record = state["receipts"][command]
        if not command is String or String(command).is_empty() or not record is Dictionary or record.size() != 3:
            return false
        for k in ["bed", "epoch", "cost"]:
            var v = record.get(k)
            if (typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT) or float(v) != float(int(v)):
                return false
        if int(record["bed"]) < 0 or int(record["bed"]) >= stresses.size() or int(record["epoch"]) > int(state["last_epoch"]) or int(record["epoch"]) < -1 or not RECOVERY_COST.values().has(int(record["cost"])):
            return false
        spent += int(record["cost"])
        checked[command] = {"bed": int(record["bed"]), "epoch": int(record["epoch"]), "cost": int(record["cost"])}
    if spent != int(state["credits_spent"]):
        return false
    var normalized: Array = []
    for v in stresses:
        normalized.append(int(v))
    bed_stress = normalized
    receipts = checked
    last_epoch = int(state["last_epoch"])
    recovery_credits = int(state["recovery_credits"])
    credits_spent = int(state["credits_spent"])
    return true
