extends RefCounted
## F08 optional, deterministic greenhouse microclimate. No player inventory mutation.
const BAY_COUNT := 4
const YEAR_DAYS := 56
const MAX_EPOCH := 2000000
const MAX_ENERGY := 10000000
const CROPS := ["lettuce", "tomato", "basil"]
const BAY_KEYS := ["installed", "crop", "vent", "heat", "lamps", "temp", "humidity", "light", "gdd", "stress", "stage", "last_control", "last_plant", "last_harvest", "harvest_count"]
const INT_BAY_KEYS := ["vent", "temp", "humidity", "light", "gdd", "stress", "last_control", "last_plant", "last_harvest", "harvest_count"]
const STATE_KEYS := ["schema", "last_epoch", "energy_available", "energy_added", "energy_spent", "last_credit_epoch", "bays"]
const INT_STATE_KEYS := ["schema", "last_epoch", "energy_available", "energy_added", "energy_spent", "last_credit_epoch"]
var _state: Dictionary = {}

func _init() -> void:
    var bays: Array = []
    for i in range(BAY_COUNT):
        bays.append(_empty_bay())
    _state = {"schema": 1, "last_epoch": 0, "energy_available": 0,
        "energy_added": 0, "energy_spent": 0, "last_credit_epoch": -1, "bays": bays}

func _empty_bay() -> Dictionary:
    return {"installed": false, "crop": "", "vent": 0, "heat": false,
        "lamps": false, "temp": 150, "humidity": 55, "light": 0,
        "gdd": 0, "stress": 0, "stage": "empty", "last_control": -1,
        "last_plant": -1, "last_harvest": -1, "harvest_count": 0}

func _keys_match(data: Dictionary, keys: Array) -> bool:
    if data.size() != keys.size():
        return false
    for key in keys:
        if not data.has(key):
            return false
    return true

func _stage(crop: String, degree_days: int) -> String:
    var thresholds: Array = [6, 20, 36, 55]
    if crop == "tomato":
        thresholds = [10, 30, 65, 90]
    elif crop == "basil":
        thresholds = [6, 20, 40, 60]
    if degree_days < int(thresholds[0]):
        return "germination"
    if degree_days < int(thresholds[1]):
        return "vegetative"
    if degree_days < int(thresholds[2]):
        return "flowering"
    if degree_days < int(thresholds[3]):
        return "fruiting"
    return "mature"

func _valid(value: Variant) -> bool:
    if typeof(value) != TYPE_DICTIONARY:
        return false
    var s: Dictionary = value
    if not _keys_match(s, STATE_KEYS):
        return false
    for key in INT_STATE_KEYS:
        if typeof(s[key]) != TYPE_INT:
            return false
    if s["schema"] != 1 or s["last_epoch"] < 0 or s["last_epoch"] > MAX_EPOCH:
        return false
    if s["energy_added"] < 0 or s["energy_added"] > MAX_ENERGY or s["energy_spent"] < 0 or s["energy_spent"] > MAX_ENERGY:
        return false
    if s["energy_available"] < 0 or s["energy_available"] > MAX_ENERGY:
        return false
    if s["energy_added"] != s["energy_spent"] + s["energy_available"]:
        return false
    if s["last_credit_epoch"] < -1 or s["last_credit_epoch"] > s["last_epoch"]:
        return false
    if typeof(s["bays"]) != TYPE_ARRAY or s["bays"].size() != BAY_COUNT:
        return false
    for entry in s["bays"]:
        if typeof(entry) != TYPE_DICTIONARY:
            return false
        var b: Dictionary = entry
        if not _keys_match(b, BAY_KEYS):
            return false
        for key in INT_BAY_KEYS:
            if typeof(b[key]) != TYPE_INT:
                return false
        for key in ["installed", "heat", "lamps"]:
            if typeof(b[key]) != TYPE_BOOL:
                return false
        if typeof(b["crop"]) != TYPE_STRING or typeof(b["stage"]) != TYPE_STRING:
            return false
        if b["vent"] < 0 or b["vent"] > 3 or b["temp"] < -300 or b["temp"] > 650:
            return false
        if b["humidity"] < 0 or b["humidity"] > 100 or b["light"] < 0 or b["light"] > 100:
            return false
        if b["gdd"] < 0 or b["gdd"] > 10000 or b["stress"] < 0 or b["stress"] > 100:
            return false
        if b["harvest_count"] < 0 or b["harvest_count"] > 100000:
            return false
        for key in ["last_control", "last_plant", "last_harvest"]:
            if b[key] < -1 or b[key] > s["last_epoch"]:
                return false
        if not b["installed"]:
            if b != _empty_bay():
                return false
        elif b["crop"] == "":
            if b["stage"] != "empty" or b["gdd"] != 0 or b["stress"] != 0:
                return false
        else:
            if not CROPS.has(b["crop"]):
                return false
            if b["stage"] != "failed" and b["stage"] != _stage(b["crop"], b["gdd"]):
                return false
            if b["stage"] == "failed" and b["stress"] != 100:
                return false
    return true

func save_state() -> Dictionary:
    return _state.duplicate(true)

func load_state(value: Variant) -> bool:
    if not _valid(value):
        return false
    _state = (value as Dictionary).duplicate(true)
    return true

func _json_integer(value: Variant) -> Variant:
    if typeof(value) == TYPE_FLOAT and not is_nan(value) and not is_inf(value):
        if value >= -1.0 and value <= float(MAX_ENERGY) and floor(value) == value:
            return int(value)
    return value

func load_json(raw: String) -> bool:
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    var candidate: Dictionary = (parsed as Dictionary).duplicate(true)
    for key in INT_STATE_KEYS:
        if candidate.has(key):
            candidate[key] = _json_integer(candidate[key])
    if typeof(candidate.get("bays")) == TYPE_ARRAY:
        for entry in candidate["bays"]:
            if typeof(entry) != TYPE_DICTIONARY:
                continue
            for key in INT_BAY_KEYS:
                if entry.has(key):
                    entry[key] = _json_integer(entry[key])
    return load_state(candidate)

func _reject(reason: String) -> Dictionary:
    return {"ok": false, "message": reason}

func _at(bay: int, epoch: int) -> bool:
    return bay >= 0 and bay < BAY_COUNT and epoch >= 1 and epoch == int(_state["last_epoch"])

func install(bay: int, epoch: int) -> Dictionary:
    if not _at(bay, epoch) or _state["bays"][bay]["installed"]:
        return _reject("Select an empty greenhouse bay on the current day.")
    var next: Dictionary = save_state()
    next["bays"][bay]["installed"] = true
    if not _valid(next):
        return _reject("Invalid greenhouse installation.")
    _state = next
    return {"ok": true, "material_required": {"glass": 8, "timber": 6},
        "message": "Greenhouse bay prepared; materials must be debited by the authoritative construction system."}

func plant(bay: int, crop: String, epoch: int) -> Dictionary:
    if not _at(bay, epoch) or not CROPS.has(crop):
        return _reject("Unknown crop, bay, or calendar day.")
    var b: Dictionary = _state["bays"][bay]
    if not b["installed"] or b["crop"] != "":
        return _reject("Install a greenhouse bay and clear its previous crop.")
    var next: Dictionary = save_state()
    var target: Dictionary = next["bays"][bay]
    target["crop"] = crop
    target["gdd"] = 0
    target["stress"] = 0
    target["stage"] = "germination"
    target["last_plant"] = epoch
    if not _valid(next):
        return _reject("Invalid planting state.")
    _state = next
    return {"ok": true, "seed_required": crop + "_seed",
        "message": "Planted %s; seed debit requires authoritative external settlement." % crop}

func set_controls(bay: int, vent: int, heat: bool, lamps: bool, epoch: int) -> Dictionary:
    if not _at(bay, epoch) or vent < 0 or vent > 3:
        return _reject("Invalid bay, ventilation level or day.")
    var b: Dictionary = _state["bays"][bay]
    if not b["installed"] or b["last_control"] == epoch:
        return _reject("Install the bay first; controls can be changed once per day.")
    var next: Dictionary = save_state()
    var target: Dictionary = next["bays"][bay]
    target["vent"] = vent
    target["heat"] = heat
    target["lamps"] = lamps
    target["last_control"] = epoch
    if not _valid(next):
        return _reject("Invalid greenhouse control state.")
    _state = next
    return {"ok": true, "energy_per_day_requested": int(vent > 0) + int(heat) * 3 + int(lamps) * 2,
        "message": "Climate controls set. Power is charged only when controls actually operate."}

## Energy credit is a domain receipt, NOT proof of a paid player transaction.
## Principal must debit authoritative power/fuel first and call this once per epoch.
func credit_energy(epoch: int, units: int) -> Dictionary:
    if epoch < 1 or epoch != int(_state["last_epoch"]) or epoch == int(_state["last_credit_epoch"]):
        return _reject("Energy allocation requires a new current-day receipt.")
    if units < 1 or units > 1000 or int(_state["energy_added"]) + units > MAX_ENERGY:
        return _reject("Invalid or overflowing finite energy allocation.")
    var next: Dictionary = save_state()
    next["energy_added"] += units
    next["energy_available"] += units
    next["last_credit_epoch"] = epoch
    if not _valid(next):
        return _reject("Energy accounting rejected.")
    _state = next
    return {"ok": true, "units": units,
        "message": "Finite greenhouse energy allocated; external authority must have charged the cost."}

func status(bay: int) -> Dictionary:
    if bay < 0 or bay >= BAY_COUNT:
        return _reject("No greenhouse bay at that location.")
    var b: Dictionary = _state["bays"][bay]
    return {"ok": true, "bay": b.duplicate(true), "energy_available": _state["energy_available"],
        "message": "Greenhouse %d: %s, %s, %d.%d C, humidity %d%%, light %d%%, energy %d." % [
            bay + 1, str(b["crop"]) if b["crop"] != "" else "empty",
            str(b["stage"]), int(b["temp"]) / 10, absi(int(b["temp"]) % 10),
            int(b["humidity"]), int(b["light"]), int(_state["energy_available"])]}

func harvest(bay: int, epoch: int) -> Dictionary:
    if not _at(bay, epoch):
        return _reject("Invalid harvest bay or day.")
    var b: Dictionary = _state["bays"][bay]
    if b["stage"] != "mature" or b["last_harvest"] == epoch:
        return _reject("Crop is not ripe or was harvested today.")
    var quantity: int = clampi(2 + int(b["gdd"] >= 120) - int(b["stress"] >= 40), 1, 3)
    var crop: String = str(b["crop"])
    var next: Dictionary = save_state()
    var target: Dictionary = next["bays"][bay]
    target["crop"] = ""
    target["stage"] = "empty"
    target["gdd"] = 0
    target["stress"] = 0
    target["last_harvest"] = epoch
    target["harvest_count"] += 1
    if not _valid(next):
        return _reject("Harvest transition rejected.")
    _state = next
    return {"ok": true, "crop": crop, "quantity_proposed": quantity,
        "message": "Harvested %d %s; inventory credit requires atomic external settlement." % [quantity, crop]}

func clear_failed(bay: int, epoch: int) -> Dictionary:
    if not _at(bay, epoch) or _state["bays"][bay]["stage"] != "failed":
        return _reject("No failed crop to clear.")
    var next: Dictionary = save_state()
    var target: Dictionary = next["bays"][bay]
    target["crop"] = ""
    target["stage"] = "empty"
    target["gdd"] = 0
    target["stress"] = 0
    if not _valid(next):
        return _reject("Failed-crop cleanup rejected.")
    _state = next
    return {"ok": true, "message": "Removed failed plants; the bay is ready for replanting."}

func advance_day(epoch: int, outside_temp_tenths: int, sunlight: int, rain: bool) -> Dictionary:
    if epoch < 1 or epoch > MAX_EPOCH or epoch != int(_state["last_epoch"]) + 1:
        return _reject("Monotonic day epoch must advance by exactly one.")
    if outside_temp_tenths < -300 or outside_temp_tenths > 500 or sunlight < 0 or sunlight > 100:
        return _reject("Weather input is outside finite bounds.")
    var next: Dictionary = save_state()
    next["last_epoch"] = epoch
    var day: int = (epoch - 1) % YEAR_DAYS
    var daylight_factor: int = [80, 100, 75, 45][int(day / 14)]
    var spent: int = 0
    var reports: Array = []
    for i in range(BAY_COUNT):
        var b: Dictionary = next["bays"][i]
        if not b["installed"]:
            continue
        var heater_on: bool = false
        var lamps_on: bool = false
        var fan_on: bool = false
        if b["heat"] and int(next["energy_available"]) >= 3:
            heater_on = true
            next["energy_available"] -= 3
            spent += 3
        if b["lamps"] and int(next["energy_available"]) >= 2:
            lamps_on = true
            next["energy_available"] -= 2
            spent += 2
        if b["vent"] > 0 and int(next["energy_available"]) >= 1:
            fan_on = true
            next["energy_available"] -= 1
            spent += 1
        var fan_level: int = int(b["vent"]) if fan_on else 0
        b["temp"] = clampi(outside_temp_tenths + 30 + int(sunlight / 4) +
            (90 if heater_on else 0) - fan_level * 18, -300, 650)
        b["humidity"] = clampi(int(int(b["humidity"]) * 3 / 4) + 12 +
            (22 if rain else 0) + (5 if b["crop"] != "" else 0) -
            fan_level * 12 - (7 if heater_on else 0), 0, 100)
        b["light"] = clampi(int(sunlight * daylight_factor / 100) +
            (30 if lamps_on else 0), 0, 100)
        if b["crop"] != "" and b["stage"] != "failed":
            var adverse: bool = b["temp"] < 40 or b["temp"] > 420 or b["humidity"] < 20 or b["humidity"] > 95
            if adverse:
                b["stress"] = mini(100, int(b["stress"]) + 12)
            elif b["light"] < 20:
                b["stress"] = mini(100, int(b["stress"]) + 3)
            else:
                b["stress"] = maxi(0, int(b["stress"]) - 2)
            if b["stress"] == 100:
                b["stage"] = "failed"
            elif b["temp"] >= 80 and b["temp"] <= 400 and b["humidity"] >= 25 and b["humidity"] <= 90 and b["light"] >= 25:
                var gain: int = clampi(int((int(b["temp"]) - 80) / 20), 0, 10)
                if b["light"] < 40:
                    gain = maxi(1, int(gain / 2))
                b["gdd"] = mini(10000, int(b["gdd"]) + gain)
                b["stage"] = _stage(str(b["crop"]), int(b["gdd"]))
        reports.append({"bay": i, "temperature_tenths": b["temp"],
            "humidity": b["humidity"], "light": b["light"], "stage": b["stage"],
            "gdd": b["gdd"], "heater_active": heater_on, "lamps_active": lamps_on,
            "fan_active": fan_on})
    next["energy_spent"] += spent
    if not _valid(next):
        return _reject("Greenhouse climate transition failed validation.")
    _state = next
    return {"ok": true, "energy_spent": spent, "energy_remaining": next["energy_available"],
        "bays": reports, "message": "Greenhouse climate updated; %d finite energy units consumed." % spent}
