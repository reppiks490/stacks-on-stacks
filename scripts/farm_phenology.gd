extends RefCounted
## F03 deterministic crop phenology candidate. Not connected to canonical Farm/Game.
## Temperatures and thermal thresholds are fixed-point tenths of degrees Celsius.
## Caller owns seed/inventory debits and atomic integration into persistent gameplay.
const BED_COUNT := 30
const MAX_EPOCH := 2000000
const MAX_THERMAL := 20000
const STAGES := ["empty", "germinating", "vegetative", "flowering", "fruiting", "mature", "dormant", "failed"]
const BED_FIELDS := ["crop", "stage", "thermal_tenths", "stress_days", "last_action_epoch", "harvest_count", "dormancy_count"]
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const CROPS := {
    "turnip": {"base": 50, "germ": 90, "veg": 240, "flower": 360, "mature": 480, "frost": -10, "heat": 340, "seasons": [0, 2], "yield": 2, "regrow": false},
    "carrot": {"base": 50, "germ": 100, "veg": 300, "flower": 480, "mature": 650, "frost": -10, "heat": 340, "seasons": [0, 2], "yield": 2, "regrow": false},
    "strawberry": {"base": 50, "germ": 120, "veg": 340, "flower": 570, "mature": 800, "frost": -20, "heat": 350, "seasons": [0, 1], "yield": 3, "regrow": true},
    "tomato": {"base": 80, "germ": 120, "veg": 340, "flower": 570, "mature": 800, "frost": 20, "heat": 370, "seasons": [1, 2], "yield": 3, "regrow": true},
    "melon": {"base": 100, "germ": 130, "veg": 420, "flower": 700, "mature": 1000, "frost": 40, "heat": 380, "seasons": [1], "yield": 2, "regrow": false},
    "pumpkin": {"base": 80, "germ": 130, "veg": 420, "flower": 700, "mature": 1000, "frost": 20, "heat": 360, "seasons": [2], "yield": 2, "regrow": false},
    "winterroot": {"base": -30, "germ": 100, "veg": 280, "flower": 480, "mature": 700, "frost": -120, "heat": 260, "seasons": [3], "yield": 2, "regrow": false},
    "bluebell": {"base": 50, "germ": 100, "veg": 300, "flower": 480, "mature": 650, "frost": -10, "heat": 340, "seasons": [0, 1], "yield": 2, "regrow": false}
}
var _state: Dictionary = {}

func _init() -> void:
    var beds: Array = []
    for i in range(BED_COUNT):
        beds.append(_empty_bed())
    _state = {"schema": 1, "last_epoch": 0, "beds": beds}

func _empty_bed() -> Dictionary:
    return {"crop": "", "stage": "empty", "thermal_tenths": 0,
        "stress_days": 0, "last_action_epoch": -1,
        "harvest_count": 0, "dormancy_count": 0}

func _reject(message: String) -> Dictionary:
    return {"ok": false, "message": message}

func _season_index(epoch: int) -> int:
    return int(((epoch - 1) % 56) / 14)

func save_state() -> Dictionary:
    return _state.duplicate(true)

func load_state(payload: Variant) -> bool:
    if not _valid(payload):
        return false
    _state = (payload as Dictionary).duplicate(true)
    return true

func _is_integer(value: Variant) -> bool:
    return typeof(value) == TYPE_INT

func _valid(payload: Variant) -> bool:
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    var state: Dictionary = payload
    if state.size() != 3 or not state.has("schema") or not state.has("last_epoch") or not state.has("beds"):
        return false
    if not _is_integer(state["schema"]) or state["schema"] != 1:
        return false
    if not _is_integer(state["last_epoch"]) or state["last_epoch"] < 0 or state["last_epoch"] > MAX_EPOCH:
        return false
    if typeof(state["beds"]) != TYPE_ARRAY or state["beds"].size() != BED_COUNT:
        return false
    for entry in state["beds"]:
        if typeof(entry) != TYPE_DICTIONARY:
            return false
        var bed: Dictionary = entry
        if bed.size() != BED_FIELDS.size():
            return false
        for key in BED_FIELDS:
            if not bed.has(key):
                return false
        if typeof(bed["crop"]) != TYPE_STRING or typeof(bed["stage"]) != TYPE_STRING:
            return false
        if not STAGES.has(bed["stage"]):
            return false
        if bed["crop"] == "":
            if bed["stage"] != "empty" or bed["thermal_tenths"] != 0 or bed["stress_days"] != 0:
                return false
        elif not CROPS.has(bed["crop"]) or bed["stage"] == "empty":
            return false
        if bed["stage"] == "dormant" and bed["crop"] != "strawberry":
            return false
        for key in ["thermal_tenths", "stress_days", "last_action_epoch", "harvest_count", "dormancy_count"]:
            if not _is_integer(bed[key]):
                return false
        if bed["thermal_tenths"] < 0 or bed["thermal_tenths"] > MAX_THERMAL:
            return false
        if bed["stress_days"] < 0 or bed["stress_days"] > 4:
            return false
        if bed["last_action_epoch"] < -1 or bed["last_action_epoch"] > state["last_epoch"]:
            return false
        if bed["harvest_count"] < 0 or bed["harvest_count"] > MAX_EPOCH:
            return false
        if bed["dormancy_count"] < 0 or bed["dormancy_count"] > MAX_EPOCH:
            return false
    return true

func status(bed_index: int) -> Dictionary:
    if bed_index < 0 or bed_index >= BED_COUNT:
        return _reject("Move closer to a valid planting bed.")
    var bed: Dictionary = _state["beds"][bed_index]
    var stage: String = bed["stage"]
    var message: String = "Bed is ready for planting."
    if stage == "mature":
        message = "Ready to harvest."
    elif stage == "dormant":
        message = "Perennial resting until spring."
    elif stage == "failed":
        message = "Crop failed; clear the bed before replanting."
    elif stage != "empty":
        message = "%s: %s; %d thermal tenths accumulated." % [bed["crop"], stage, bed["thermal_tenths"]]
    return {"ok": true, "crop": bed["crop"], "stage": stage,
        "thermal_tenths": bed["thermal_tenths"], "stress_days": bed["stress_days"],
        "message": message}

func plant(bed_index: int, crop_id: String, epoch: int) -> Dictionary:
    if bed_index < 0 or bed_index >= BED_COUNT or not CROPS.has(crop_id):
        return _reject("Unknown crop or planting bed.")
    if epoch < 1 or epoch != _state["last_epoch"]:
        return _reject("Planting requires the current day epoch.")
    if not CROPS[crop_id]["seasons"].has(_season_index(epoch)):
        return _reject("Seeds cannot germinate in this season.")
    var bed: Dictionary = _state["beds"][bed_index]
    if bed["crop"] != "" or bed["last_action_epoch"] == epoch:
        return _reject("Bed occupied or already acted upon today.")
    bed["crop"] = crop_id
    bed["stage"] = "germinating"
    bed["thermal_tenths"] = 0
    bed["stress_days"] = 0
    bed["last_action_epoch"] = epoch
    return {"ok": true, "message": "Sowed %s; germination has begun." % crop_id}

func clear_failed(bed_index: int, epoch: int) -> Dictionary:
    if bed_index < 0 or bed_index >= BED_COUNT or epoch < 1 or epoch != _state["last_epoch"]:
        return _reject("Invalid bed or day.")
    var bed: Dictionary = _state["beds"][bed_index]
    if bed["stage"] != "failed" or bed["last_action_epoch"] == epoch:
        return _reject("Only failed crops may be cleared once per day.")
    bed["crop"] = ""
    bed["stage"] = "empty"
    bed["thermal_tenths"] = 0
    bed["stress_days"] = 0
    bed["last_action_epoch"] = epoch
    return {"ok": true, "message": "Removed failed crop; bed can be replanted tomorrow."}

func harvest(bed_index: int, epoch: int) -> Dictionary:
    if bed_index < 0 or bed_index >= BED_COUNT or epoch < 1 or epoch != _state["last_epoch"]:
        return _reject("Invalid harvest bed or day.")
    var bed: Dictionary = _state["beds"][bed_index]
    if bed["stage"] != "mature" or bed["last_action_epoch"] == epoch:
        return _reject("Crop is not ready or was already handled today.")
    var crop_id: String = bed["crop"]
    var profile: Dictionary = CROPS[crop_id]
    if bed["harvest_count"] >= MAX_EPOCH:
        return _reject("Harvest count limit reached.")
    bed["harvest_count"] += 1
    bed["last_action_epoch"] = epoch
    if profile["regrow"]:
        bed["stage"] = "flowering"
        bed["thermal_tenths"] = int(profile["veg"])
        bed["stress_days"] = 0
    else:
        bed["crop"] = ""
        bed["stage"] = "empty"
        bed["thermal_tenths"] = 0
        bed["stress_days"] = 0
    # Receipt is NOT an inventory grant; caller must atomically debit/credit.
    return {"ok": true, "crop": crop_id, "units": int(profile["yield"]),
        "receipt": "F03:%d:%d:%s" % [bed_index, epoch, crop_id],
        "message": "Harvest authorized; inventory transaction still required."}

func advance_day(epoch: int, temperature_tenths: int, moisture: Array) -> Dictionary:
    if epoch < 1 or epoch > MAX_EPOCH or epoch != int(_state["last_epoch"]) + 1:
        return _reject("Day must advance exactly once and without gaps.")
    if temperature_tenths < -200 or temperature_tenths > 500 or moisture.size() != BED_COUNT:
        return _reject("Invalid weather or moisture input.")
    for value in moisture:
        if not _is_integer(value) or value < 0 or value > 100:
            return _reject("All thirty moisture values must be bounded integers.")
    var next: Dictionary = _state.duplicate(true)
    var season: int = _season_index(epoch)
    var failed: int = 0
    var ready: int = 0
    for i in range(BED_COUNT):
        var bed: Dictionary = next["beds"][i]
        var crop_id: String = bed["crop"]
        if crop_id == "" or bed["stage"] == "failed":
            continue
        var profile: Dictionary = CROPS[crop_id]
        if not profile["seasons"].has(season):
            if crop_id == "strawberry":
                if bed["stage"] != "dormant":
                    bed["dormancy_count"] += 1
                bed["stage"] = "dormant"
                continue
            bed["stage"] = "failed"
            failed += 1
            continue
        if bed["stage"] == "dormant":
            bed["stage"] = "vegetative"
            bed["thermal_tenths"] = int(profile["veg"])
            bed["stress_days"] = 0
        if temperature_tenths < int(profile["frost"]):
            bed["stage"] = "failed"
            failed += 1
            continue
        var penalty: int = 0
        if temperature_tenths > int(profile["heat"]):
            penalty += 2
        if int(moisture[i]) < 30:
            penalty += 1
        if penalty > 0:
            bed["stress_days"] = mini(4, int(bed["stress_days"]) + penalty)
        else:
            bed["stress_days"] = maxi(0, int(bed["stress_days"]) - 1)
        if bed["stress_days"] >= 4:
            bed["stage"] = "failed"
            failed += 1
            continue
        if bed["stage"] == "mature":
            ready += 1
            continue
        var gained: int = maxi(0, temperature_tenths - int(profile["base"]))
        bed["thermal_tenths"] = mini(MAX_THERMAL, int(bed["thermal_tenths"]) + gained)
        var thermal: int = bed["thermal_tenths"]
        if thermal < int(profile["germ"]):
            bed["stage"] = "germinating"
        elif thermal < int(profile["veg"]):
            bed["stage"] = "vegetative"
        elif thermal < int(profile["flower"]):
            bed["stage"] = "flowering"
        elif thermal < int(profile["mature"]):
            bed["stage"] = "fruiting"
        else:
            bed["stage"] = "mature"
            ready += 1
    next["last_epoch"] = epoch
    if not _valid(next):
        return _reject("Phenology state limit reached; day not applied.")
    _state = next
    return {"ok": true, "day_epoch": epoch, "season": SEASONS[season],
        "failed": failed, "ready": ready, "message": "%d beds ready; %d new crop failures." % [ready, failed]}
