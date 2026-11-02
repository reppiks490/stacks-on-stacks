extends RefCounted
## F09 optional finite equipment progression; no authoritative inventory or farm mutation.
## A caller MUST atomically settle resource credits and field effects before enabling gameplay.
const BED_COUNT := 30
const YEAR_DAYS := 56
const MAX_EPOCH := 2000000
const MAX_TOTAL := 10000000
const RESOURCES := ["energy", "timber", "ore", "fiber"]
const TOOL_NAMES := ["hoe", "watering_can", "sickle", "rake"]
const ACTIONS := ["till", "water", "harvest", "weed"]
const STATE_KEYS := ["schema", "last_epoch", "fatigue", "last_credit_epoch", "resources", "tools"]
const TOOL_KEYS := ["name", "tier", "wear", "uses", "last_upgrade", "last_repair", "last_beds"]
const TOOL_INT_KEYS := ["tier", "wear", "uses", "last_upgrade", "last_repair"]
const RESOURCE_KEYS := ["credited", "spent", "available"]
var _state: Dictionary = {}

func _init() -> void:
    var resources: Dictionary = {}
    for name in RESOURCES:
        resources[name] = {"credited": 0, "spent": 0, "available": 0}
    var tools: Array = []
    for name in TOOL_NAMES:
        tools.append(_new_tool(name))
    _state = {"schema": 1, "last_epoch": 0, "fatigue": 0,
        "last_credit_epoch": -1, "resources": resources, "tools": tools}

func _new_tool(name: String) -> Dictionary:
    var last_beds: Array = []
    last_beds.resize(BED_COUNT)
    last_beds.fill(-1)
    return {"name": name, "tier": 0, "wear": 0, "uses": 0,
        "last_upgrade": -1, "last_repair": -1, "last_beds": last_beds}

func _keys_match(data: Dictionary, keys: Array) -> bool:
    if data.size() != keys.size():
        return false
    for key in keys:
        if not data.has(key):
            return false
    return true

func _max_wear(tier: int) -> int:
    return 40 + tier * 20

func _valid(candidate: Variant) -> bool:
    if typeof(candidate) != TYPE_DICTIONARY:
        return false
    var s: Dictionary = candidate
    if not _keys_match(s, STATE_KEYS):
        return false
    for key in ["schema", "last_epoch", "fatigue", "last_credit_epoch"]:
        if typeof(s[key]) != TYPE_INT:
            return false
    if s["schema"] != 1 or s["last_epoch"] < 0 or s["last_epoch"] > MAX_EPOCH:
        return false
    if s["fatigue"] < 0 or s["fatigue"] > 100:
        return false
    if s["last_credit_epoch"] < -1 or s["last_credit_epoch"] > s["last_epoch"]:
        return false
    if typeof(s["resources"]) != TYPE_DICTIONARY or not _keys_match(s["resources"], RESOURCES):
        return false
    for name in RESOURCES:
        var ledger: Variant = s["resources"][name]
        if typeof(ledger) != TYPE_DICTIONARY or not _keys_match(ledger, RESOURCE_KEYS):
            return false
        for key in RESOURCE_KEYS:
            if typeof(ledger[key]) != TYPE_INT or ledger[key] < 0 or ledger[key] > MAX_TOTAL:
                return false
        if ledger["credited"] != ledger["spent"] + ledger["available"]:
            return false
    if typeof(s["tools"]) != TYPE_ARRAY or s["tools"].size() != TOOL_NAMES.size():
        return false
    for i in range(TOOL_NAMES.size()):
        var entry: Variant = s["tools"][i]
        if typeof(entry) != TYPE_DICTIONARY or not _keys_match(entry, TOOL_KEYS):
            return false
        var t: Dictionary = entry
        if typeof(t["name"]) != TYPE_STRING or t["name"] != TOOL_NAMES[i]:
            return false
        for key in TOOL_INT_KEYS:
            if typeof(t[key]) != TYPE_INT:
                return false
        if t["tier"] < 0 or t["tier"] > 3 or t["wear"] < 0 or t["wear"] > _max_wear(t["tier"]):
            return false
        if t["uses"] < 0 or t["uses"] > 1000000:
            return false
        for key in ["last_upgrade", "last_repair"]:
            if t[key] < -1 or t[key] > s["last_epoch"]:
                return false
        if typeof(t["last_beds"]) != TYPE_ARRAY or t["last_beds"].size() != BED_COUNT:
            return false
        for last in t["last_beds"]:
            if typeof(last) != TYPE_INT or last < -1 or last > s["last_epoch"]:
                return false
    return true

func save_state() -> Dictionary:
    return _state.duplicate(true)

func load_state(candidate: Variant) -> bool:
    if not _valid(candidate):
        return false
    _state = (candidate as Dictionary).duplicate(true)
    return true

func _json_integer(value: Variant) -> Variant:
    if typeof(value) == TYPE_FLOAT and not is_nan(value) and not is_inf(value):
        if value >= -1.0 and value <= float(MAX_TOTAL) and floor(value) == value:
            return int(value)
    return value

func load_json(raw: String) -> bool:
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    var next: Dictionary = (parsed as Dictionary).duplicate(true)
    for key in ["schema", "last_epoch", "fatigue", "last_credit_epoch"]:
        if next.has(key):
            next[key] = _json_integer(next[key])
    if typeof(next.get("resources")) == TYPE_DICTIONARY:
        for name in RESOURCES:
            if typeof(next["resources"].get(name)) == TYPE_DICTIONARY:
                for key in RESOURCE_KEYS:
                    if next["resources"][name].has(key):
                        next["resources"][name][key] = _json_integer(next["resources"][name][key])
    if typeof(next.get("tools")) == TYPE_ARRAY:
        for t in next["tools"]:
            if typeof(t) != TYPE_DICTIONARY:
                continue
            for key in TOOL_INT_KEYS:
                if t.has(key):
                    t[key] = _json_integer(t[key])
            if typeof(t.get("last_beds")) == TYPE_ARRAY:
                for i in range(t["last_beds"].size()):
                    t["last_beds"][i] = _json_integer(t["last_beds"][i])
    return load_state(next)

func _reject(message: String) -> Dictionary:
    return {"ok": false, "message": message}

func _current(epoch: int) -> bool:
    return epoch >= 1 and epoch == int(_state["last_epoch"])

func _tool_index(name: String) -> int:
    return TOOL_NAMES.find(name)

func _cost_upgrade(tier: int) -> Dictionary:
    return {"energy": 5, "timber": 2 + tier, "ore": 1 + 2 * tier, "fiber": 1}

func _cost_repair(name: String, wear: int) -> Dictionary:
    return {"energy": 2, "timber": int(name == "hoe" or name == "rake"),
        "ore": maxi(1, int((wear + 19) / 20)),
        "fiber": int(name == "watering_can" or name == "sickle")}

func _can_pay(s: Dictionary, cost: Dictionary) -> bool:
    for name in RESOURCES:
        if int(s["resources"][name]["available"]) < int(cost.get(name, 0)):
            return false
    return true

func _pay(s: Dictionary, cost: Dictionary) -> void:
    for name in RESOURCES:
        var amount: int = int(cost.get(name, 0))
        s["resources"][name]["available"] -= amount
        s["resources"][name]["spent"] += amount

func advance_day(epoch: int) -> Dictionary:
    if epoch < 1 or epoch > MAX_EPOCH or epoch != int(_state["last_epoch"]) + 1:
        return _reject("Advance the 56-day calendar by exactly one monotonic day.")
    var next: Dictionary = save_state()
    next["last_epoch"] = epoch
    next["fatigue"] = maxi(0, int(next["fatigue"]) - 30)
    if not _valid(next):
        return _reject("Equipment day transition rejected.")
    _state = next
    return {"ok": true, "year": int((epoch - 1) / YEAR_DAYS) + 1,
        "day_of_year": (epoch - 1) % YEAR_DAYS + 1,
        "message": "Rest restored some stamina; tool wear remains."}

## This is a finite DOMAIN credit, not an authenticated player-inventory receipt.
## Principal must debit the authoritative inventory/energy atomically before crediting.
func credit_resources(epoch: int, allocation: Variant) -> Dictionary:
    if not _current(epoch) or epoch == int(_state["last_credit_epoch"]):
        return _reject("One settled equipment allocation is allowed per day.")
    if typeof(allocation) != TYPE_DICTIONARY or not _keys_match(allocation, RESOURCES):
        return _reject("Supply allocation must name all four finite resources.")
    var total: int = 0
    for name in RESOURCES:
        var amount: Variant = allocation[name]
        var limit: int = 100 if name == "energy" else 30
        if typeof(amount) != TYPE_INT or amount < 0 or amount > limit:
            return _reject("Invalid or excessive equipment supply allocation.")
        total += amount
        if int(_state["resources"][name]["credited"]) + amount > MAX_TOTAL:
            return _reject("Lifetime supply ledger capacity reached.")
    if total == 0:
        return _reject("Empty allocation is not a resource receipt.")
    var next: Dictionary = save_state()
    for name in RESOURCES:
        next["resources"][name]["credited"] += allocation[name]
        next["resources"][name]["available"] += allocation[name]
    next["last_credit_epoch"] = epoch
    if not _valid(next):
        return _reject("Equipment supply conservation failed.")
    _state = next
    return {"ok": true, "credited": allocation.duplicate(true),
        "message": "Finite supplies credited; external debit is required."}

func preview_upgrade(name: String) -> Dictionary:
    var i: int = _tool_index(name)
    if i < 0:
        return _reject("Unknown farming tool.")
    var t: Dictionary = _state["tools"][i]
    if int(t["tier"]) >= 3:
        return _reject("This tool has reached its final tier.")
    return {"ok": true, "cost": _cost_upgrade(int(t["tier"])),
        "next_tier": int(t["tier"]) + 1,
        "message": "Upgrading improves reach/efficiency but does not erase wear."}

func upgrade(name: String, epoch: int) -> Dictionary:
    var i: int = _tool_index(name)
    if i < 0 or not _current(epoch):
        return _reject("Unknown tool or invalid calendar day.")
    var t: Dictionary = _state["tools"][i]
    if int(t["tier"]) >= 3 or int(t["last_upgrade"]) == epoch:
        return _reject("Maximum tier or duplicate daily upgrade.")
    var cost: Dictionary = _cost_upgrade(int(t["tier"]))
    if not _can_pay(_state, cost) or int(_state["fatigue"]) + 15 > 100:
        return _reject("Insufficient materials, stamina or power for upgrade.")
    var next: Dictionary = save_state()
    _pay(next, cost)
    next["fatigue"] += 15
    next["tools"][i]["tier"] += 1
    next["tools"][i]["last_upgrade"] = epoch
    if not _valid(next):
        return _reject("Upgrade transition rejected.")
    _state = next
    return {"ok": true, "tier": int(_state["tools"][i]["tier"]),
        "debited": cost, "message": "%s upgraded; previous wear preserved." % name}

func preview_repair(name: String) -> Dictionary:
    var i: int = _tool_index(name)
    if i < 0:
        return _reject("Unknown farming tool.")
    var t: Dictionary = _state["tools"][i]
    if int(t["wear"]) == 0:
        return _reject("Tool already has full durability.")
    return {"ok": true, "cost": _cost_repair(name, int(t["wear"])),
        "restored_wear": int(t["wear"]),
        "message": "Repair consumes finite materials; no free restoration."}

func repair(name: String, epoch: int) -> Dictionary:
    var i: int = _tool_index(name)
    if i < 0 or not _current(epoch):
        return _reject("Unknown tool or invalid calendar day.")
    var t: Dictionary = _state["tools"][i]
    if int(t["wear"]) == 0 or int(t["last_repair"]) == epoch:
        return _reject("Tool is sound or already repaired today.")
    var cost: Dictionary = _cost_repair(name, int(t["wear"]))
    if not _can_pay(_state, cost) or int(_state["fatigue"]) + 6 > 100:
        return _reject("Insufficient repair supplies or stamina.")
    var next: Dictionary = save_state()
    _pay(next, cost)
    next["fatigue"] += 6
    var restored: int = int(t["wear"])
    next["tools"][i]["wear"] = 0
    next["tools"][i]["last_repair"] = epoch
    if not _valid(next):
        return _reject("Repair transition rejected.")
    _state = next
    return {"ok": true, "restored_wear": restored, "debited": cost,
        "message": "%s repaired with accounted materials." % name}

## Emits a proposed farm action, never mutates farm beds or player inventory.
## Caller must commit tool+farm effects together or roll back both.
func operate(name: String, bed: int, epoch: int) -> Dictionary:
    var i: int = _tool_index(name)
    if i < 0 or bed < 0 or bed >= BED_COUNT or not _current(epoch):
        return _reject("Choose a valid tool, one of 30 beds and today's date.")
    var t: Dictionary = _state["tools"][i]
    if int(t["last_beds"][bed]) == epoch:
        return _reject("This tool already worked that bed today.")
    var tier: int = int(t["tier"])
    var energy_cost: int = 4 - tier
    var wear_cost: int = maxi(1, 3 - tier)
    if int(t["wear"]) + wear_cost > _max_wear(tier):
        return _reject("Tool is too worn; repair before working.")
    if int(_state["resources"]["energy"]["available"]) < energy_cost:
        return _reject("Not enough settled energy to operate.")
    if int(_state["fatigue"]) + energy_cost * 3 > 100:
        return _reject("Too fatigued; rest before continuing.")
    if int(t["uses"]) >= 1000000:
        return _reject("Tool lifetime use counter is full.")
    var next: Dictionary = save_state()
    _pay(next, {"energy": energy_cost})
    next["fatigue"] += energy_cost * 3
    next["tools"][i]["wear"] += wear_cost
    next["tools"][i]["uses"] += 1
    next["tools"][i]["last_beds"][bed] = epoch
    if not _valid(next):
        return _reject("Equipment operation rejected.")
    _state = next
    return {"ok": true, "action": ACTIONS[i], "bed": bed,
        "work_units": tier + 1, "energy_spent": energy_cost,
        "wear_added": wear_cost,
        "message": "%s used on bed %d; %d energy spent, %d wear." % [
            name, bed + 1, energy_cost, wear_cost]}

func status(name: String) -> Dictionary:
    var i: int = _tool_index(name)
    if i < 0:
        return _reject("Unknown farming tool.")
    var t: Dictionary = _state["tools"][i]
    var durability: int = _max_wear(int(t["tier"])) - int(t["wear"])
    return {"ok": true, "tool": t.duplicate(true), "durability": durability,
        "max_durability": _max_wear(int(t["tier"])),
        "fatigue": int(_state["fatigue"]),
        "message": "%s tier %d, durability %d/%d, fatigue %d/100." % [
            name, int(t["tier"]), durability, _max_wear(int(t["tier"])),
            int(_state["fatigue"])]}
