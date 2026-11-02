extends RefCounted
## F05 original bounded weed/pest ecology. No inventory or authoritative harvest mutation.
const BED_COUNT := 30
const MAX_EPOCH := 2000000
const CROPS := ["turnip", "carrot", "strawberry", "tomato", "melon", "pumpkin", "winterroot", "bluebell"]
const BED_FIELDS := ["crop", "weeds", "pests", "habitat", "mulch_days", "trap_days", "stress", "last_action_epoch"]
var _state: Dictionary = {}

func _init() -> void:
    var beds: Array = []
    for i in range(BED_COUNT):
        beds.append({"crop": "", "weeds": 12, "pests": 10, "habitat": 20,
            "mulch_days": 0, "trap_days": 0, "stress": 0, "last_action_epoch": -1})
    _state = {"schema": 1, "last_epoch": 0, "beds": beds}

func _reject(message: String) -> Dictionary:
    return {"ok": false, "message": message}

func _integer(value: Variant) -> bool:
    return typeof(value) == TYPE_INT

func _valid(payload: Variant) -> bool:
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    var state: Dictionary = payload
    if state.size() != 3 or not state.has("schema") or not state.has("last_epoch") or not state.has("beds"):
        return false
    if not _integer(state["schema"]) or state["schema"] != 1:
        return false
    if not _integer(state["last_epoch"]) or state["last_epoch"] < 0 or state["last_epoch"] > MAX_EPOCH:
        return false
    if typeof(state["beds"]) != TYPE_ARRAY or state["beds"].size() != BED_COUNT:
        return false
    for value in state["beds"]:
        if typeof(value) != TYPE_DICTIONARY:
            return false
        var bed: Dictionary = value
        if bed.size() != BED_FIELDS.size():
            return false
        for key in BED_FIELDS:
            if not bed.has(key):
                return false
        if typeof(bed["crop"]) != TYPE_STRING or (bed["crop"] != "" and not CROPS.has(bed["crop"])):
            return false
        for key in BED_FIELDS:
            if key == "crop":
                continue
            if not _integer(bed[key]):
                return false
        for key in ["weeds", "pests", "habitat", "stress"]:
            if bed[key] < 0 or bed[key] > 100:
                return false
        for key in ["mulch_days", "trap_days"]:
            if bed[key] < 0 or bed[key] > 14:
                return false
        if bed["last_action_epoch"] < -1 or bed["last_action_epoch"] > state["last_epoch"]:
            return false
        if bed["crop"] == "" and bed["stress"] != 0:
            return false
    return true

func save_state() -> Dictionary:
    return _state.duplicate(true)

func load_state(payload: Variant) -> bool:
    if not _valid(payload):
        return false
    _state = (payload as Dictionary).duplicate(true)
    return true

func _factor(bed: Dictionary) -> int:
    return clampi(10000 - int(bed["weeds"]) * 22 - int(bed["pests"]) * 28 - int(bed["stress"]) * 25, 4000, 10000)

func status(index: int) -> Dictionary:
    if index < 0 or index >= BED_COUNT:
        return _reject("Move closer to a valid planting bed.")
    var bed: Dictionary = _state["beds"][index]
    var factor: int = _factor(bed)
    var message: String = "Weeds %d/100, pests %d/100; projected yield %d%% of baseline." % [
        int(bed["weeds"]), int(bed["pests"]), int(factor / 100)]
    if bed["crop"] == "":
        message = "Empty bed. " + message
    elif factor < 7500:
        message = "Crops need care. " + message
    else:
        message = "Crop health stable. " + message
    return {"ok": true, "crop": bed["crop"], "weeds": bed["weeds"], "pests": bed["pests"],
        "habitat": bed["habitat"], "stress": bed["stress"], "mulch_days": bed["mulch_days"],
        "trap_days": bed["trap_days"], "yield_basis_points": factor, "message": message}

func register_crop(index: int, crop_id: String, epoch: int) -> Dictionary:
    if index < 0 or index >= BED_COUNT or not CROPS.has(crop_id):
        return _reject("Invalid bed or crop.")
    if epoch < 1 or epoch != int(_state["last_epoch"]):
        return _reject("Crop registration requires the current day.")
    var bed: Dictionary = _state["beds"][index]
    if bed["crop"] != "" or int(bed["last_action_epoch"]) == epoch:
        return _reject("Bed already occupied or handled today.")
    bed["crop"] = crop_id
    bed["stress"] = 0
    bed["last_action_epoch"] = epoch
    return {"ok": true, "message": "Registered %s; authoritative seed debit remains external." % crop_id}

func clear_crop(index: int, epoch: int) -> Dictionary:
    if index < 0 or index >= BED_COUNT or epoch < 1 or epoch != int(_state["last_epoch"]):
        return _reject("Invalid bed or day.")
    var bed: Dictionary = _state["beds"][index]
    if bed["crop"] == "" or int(bed["last_action_epoch"]) == epoch:
        return _reject("No crop to clear or already handled today.")
    bed["crop"] = ""
    bed["stress"] = 0
    bed["last_action_epoch"] = epoch
    return {"ok": true, "message": "Crop cleared; no produce or seeds credited."}

func act(index: int, action: String, epoch: int) -> Dictionary:
    if index < 0 or index >= BED_COUNT or epoch < 1 or epoch != int(_state["last_epoch"]):
        return _reject("Invalid bed or day.")
    if not ["weed", "mulch", "trap", "habitat"].has(action):
        return _reject("Unknown ecology action.")
    var bed: Dictionary = _state["beds"][index]
    if int(bed["last_action_epoch"]) == epoch:
        return _reject("This bed was already tended today.")
    var next: Dictionary = _state.duplicate(true)
    var target: Dictionary = next["beds"][index]
    var required_item: String = ""
    match action:
        "weed":
            target["weeds"] = maxi(0, int(target["weeds"]) - 35)
        "mulch":
            target["weeds"] = maxi(0, int(target["weeds"]) - 12)
            target["mulch_days"] = 7
            required_item = "leaf_mulch"
        "trap":
            target["pests"] = maxi(0, int(target["pests"]) - 12)
            target["trap_days"] = 7
            required_item = "pest_trap"
        "habitat":
            target["habitat"] = mini(100, int(target["habitat"]) + 20)
            target["pests"] = maxi(0, int(target["pests"]) - 5)
            required_item = "flower_seed"
    target["last_action_epoch"] = epoch
    if not _valid(next):
        return _reject("Ecology action exceeded finite state bounds.")
    _state = next
    return {"ok": true, "action": action, "item_required": required_item,
        "yield_basis_points": _factor(target),
        "message": "Applied %s to bed %d; resource/stamina settlement remains external." % [action, index]}

func advance_day(epoch: int, rain: int, heat: int) -> Dictionary:
    if epoch < 1 or epoch > MAX_EPOCH or epoch != int(_state["last_epoch"]) + 1:
        return _reject("Day epoch must advance exactly once.")
    if rain < 0 or rain > 100 or heat < 0 or heat > 100:
        return _reject("Rain and heat risk must be bounded 0..100.")
    var next: Dictionary = _state.duplicate(true)
    var stressed: int = 0
    for i in range(BED_COUNT):
        var bed: Dictionary = next["beds"][i]
        var mulched: bool = int(bed["mulch_days"]) > 0
        var trapped: bool = int(bed["trap_days"]) > 0
        var weed_delta: int = 2 + int(rain / 30) + int(bed["crop"] != "") - (4 if mulched else 0) - (1 if int(bed["habitat"]) >= 60 else 0)
        bed["weeds"] = clampi(int(bed["weeds"]) + weed_delta, 0, 100)
        var pest_delta: int = 1 + int(heat / 35) + (2 if int(bed["weeds"]) >= 35 else 0) - int(int(bed["habitat"]) / 25) - (5 if trapped else 0)
        bed["pests"] = clampi(int(bed["pests"]) + pest_delta, 0, 100)
        bed["mulch_days"] = maxi(0, int(bed["mulch_days"]) - 1)
        bed["trap_days"] = maxi(0, int(bed["trap_days"]) - 1)
        if bed["crop"] != "":
            var damage: int = int(int(bed["weeds"]) >= 35) + int(int(bed["pests"]) >= 35)
            bed["stress"] = clampi(int(bed["stress"]) + (damage if damage > 0 else -1), 0, 100)
            stressed += int(int(bed["stress"]) > 0)
        else:
            bed["stress"] = 0
    next["last_epoch"] = epoch
    if not _valid(next):
        return _reject("Daily ecology state failed validation.")
    _state = next
    return {"ok": true, "day_epoch": epoch, "year": int((epoch - 1) / 56) + 1,
        "season_index": int(((epoch - 1) % 56) / 14), "stressed_beds": stressed,
        "message": "%d crop beds show weed or pest stress." % stressed}
