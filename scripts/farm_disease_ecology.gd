extends RefCounted
## F06 isolated plant-disease simulation; never grants/debits inventory or changes live harvests.
const BED_COUNT := 30
const WIDTH := 6
const MAX_EPOCH := 2000000
const CROPS := ["turnip", "carrot", "strawberry", "tomato", "melon", "pumpkin", "winterroot", "bluebell"]
const BED_FIELDS := ["crop", "infection", "immunity", "sanitation_days", "quarantine_days", "treatment_days", "damage", "last_action_epoch"]
var _state: Dictionary = {}

func _init() -> void:
    var beds: Array = []
    for i in range(BED_COUNT):
        beds.append({"crop": "", "infection": 0, "immunity": 0,
            "sanitation_days": 0, "quarantine_days": 0, "treatment_days": 0,
            "damage": 0, "last_action_epoch": -1})
    _state = {"schema": 1, "last_epoch": 0, "beds": beds}

func _reject(message: String) -> Dictionary:
    return {"ok": false, "message": message}

func _valid(payload: Variant) -> bool:
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    var s: Dictionary = payload
    if s.size() != 3 or not s.has("schema") or not s.has("last_epoch") or not s.has("beds"):
        return false
    if typeof(s["schema"]) != TYPE_INT or s["schema"] != 1:
        return false
    if typeof(s["last_epoch"]) != TYPE_INT or s["last_epoch"] < 0 or s["last_epoch"] > MAX_EPOCH:
        return false
    if typeof(s["beds"]) != TYPE_ARRAY or s["beds"].size() != BED_COUNT:
        return false
    for entry in s["beds"]:
        if typeof(entry) != TYPE_DICTIONARY:
            return false
        var b: Dictionary = entry
        if b.size() != BED_FIELDS.size():
            return false
        for key in BED_FIELDS:
            if not b.has(key):
                return false
        if typeof(b["crop"]) != TYPE_STRING or (b["crop"] != "" and not CROPS.has(b["crop"])):
            return false
        for key in BED_FIELDS:
            if key != "crop" and typeof(b[key]) != TYPE_INT:
                return false
        for key in ["infection", "immunity", "damage"]:
            if b[key] < 0 or b[key] > 100:
                return false
        for key in ["sanitation_days", "quarantine_days", "treatment_days"]:
            if b[key] < 0 or b[key] > 14:
                return false
        if b["last_action_epoch"] < -1 or b["last_action_epoch"] > s["last_epoch"]:
            return false
        if b["crop"] == "" and (b["infection"] != 0 or b["damage"] != 0 or b["immunity"] != 0):
            return false
    return true

func save_state() -> Dictionary:
    return _state.duplicate(true)

func load_state(payload: Variant) -> bool:
    if not _valid(payload):
        return false
    _state = (payload as Dictionary).duplicate(true)
    return true

## Godot JSON.parse_string returns floating-point JSON numbers; admit only exact
## bounded integral representations, never clamp or silently truncate corruption.
func _json_integer(value: Variant) -> Variant:
    if typeof(value) == TYPE_FLOAT and not is_nan(value) and not is_inf(value):
        if value >= -1.0 and value <= float(MAX_EPOCH) and floor(value) == value:
            return int(value)
    return value

func load_json(raw: String) -> bool:
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    var s: Dictionary = (parsed as Dictionary).duplicate(true)
    for key in ["schema", "last_epoch"]:
        if s.has(key):
            s[key] = _json_integer(s[key])
    if typeof(s.get("beds")) == TYPE_ARRAY:
        for i in range(s["beds"].size()):
            if typeof(s["beds"][i]) != TYPE_DICTIONARY:
                continue
            var b: Dictionary = s["beds"][i]
            for key in BED_FIELDS:
                if key != "crop" and b.has(key):
                    b[key] = _json_integer(b[key])
    return load_state(s)

func _yield_basis_points(b: Dictionary) -> int:
    return clampi(10000 - int(b["infection"]) * 24 - int(b["damage"]) * 26, 4000, 10000)

func status(index: int) -> Dictionary:
    if index < 0 or index >= BED_COUNT:
        return _reject("Move closer to a planting bed.")
    var b: Dictionary = _state["beds"][index]
    var message: String = "Bed %d: infection %d/100, damage %d/100; expected yield %d%%." % [
        index, int(b["infection"]), int(b["damage"]), int(_yield_basis_points(b) / 100)]
    if b["crop"] == "":
        message = "Empty bed. " + message
    elif int(b["infection"]) >= 35:
        message = "Disease warning. " + message
    elif int(b["infection"]) > 0:
        message = "Watch for spreading symptoms. " + message
    else:
        message = "No active disease. " + message
    return {"ok": true, "crop": b["crop"], "infection": b["infection"],
        "immunity": b["immunity"], "damage": b["damage"],
        "sanitation_days": b["sanitation_days"], "quarantine_days": b["quarantine_days"],
        "treatment_days": b["treatment_days"],
        "yield_basis_points": _yield_basis_points(b), "message": message}

func register_crop(index: int, crop_id: String, epoch: int) -> Dictionary:
    if index < 0 or index >= BED_COUNT or not CROPS.has(crop_id):
        return _reject("Unknown bed or crop.")
    if epoch < 1 or epoch != int(_state["last_epoch"]):
        return _reject("Registration requires current day.")
    var b: Dictionary = _state["beds"][index]
    if b["crop"] != "" or int(b["last_action_epoch"]) == epoch:
        return _reject("Bed occupied or already handled today.")
    b["crop"] = crop_id
    b["infection"] = 0
    b["immunity"] = 12 + (index % 5) * 4
    b["damage"] = 0
    b["sanitation_days"] = 0
    b["quarantine_days"] = 0
    b["treatment_days"] = 0
    b["last_action_epoch"] = epoch
    return {"ok": true, "message": "Registered %s; seed debit remains authoritative elsewhere." % crop_id}

func clear_crop(index: int, epoch: int) -> Dictionary:
    if index < 0 or index >= BED_COUNT or epoch < 1 or epoch != int(_state["last_epoch"]):
        return _reject("Invalid bed or day.")
    var b: Dictionary = _state["beds"][index]
    if b["crop"] == "" or int(b["last_action_epoch"]) == epoch:
        return _reject("No crop to clear or already handled today.")
    b["crop"] = ""
    b["infection"] = 0
    b["immunity"] = 0
    b["damage"] = 0
    b["sanitation_days"] = 0
    b["quarantine_days"] = 0
    b["treatment_days"] = 0
    b["last_action_epoch"] = epoch
    return {"ok": true, "message": "Cleared bed; no harvest, seed or money credited."}

func act(index: int, action: String, epoch: int) -> Dictionary:
    if index < 0 or index >= BED_COUNT or epoch < 1 or epoch != int(_state["last_epoch"]):
        return _reject("Invalid bed or day.")
    if not ["sanitize", "quarantine", "treat"].has(action):
        return _reject("Unknown plant-care action.")
    var b: Dictionary = _state["beds"][index]
    if b["crop"] == "" or int(b["last_action_epoch"]) == epoch:
        return _reject("Plant a crop or wait until tomorrow.")
    var next: Dictionary = _state.duplicate(true)
    var target: Dictionary = next["beds"][index]
    var item: String = ""
    match action:
        "sanitize":
            target["sanitation_days"] = 6
            item = "clean_water"
        "quarantine":
            target["quarantine_days"] = 5
            item = "plant_cover"
        "treat":
            if int(target["infection"]) == 0:
                return _reject("Treatment requires observed infection.")
            target["treatment_days"] = 4
            item = "herbal_tonic"
    target["last_action_epoch"] = epoch
    if not _valid(next):
        return _reject("Disease action exceeds finite state.")
    _state = next
    return {"ok": true, "action": action, "item_required": item,
        "infection": target["infection"], "yield_basis_points": _yield_basis_points(target),
        "message": "%s bed %d; no immediate cure. Resource/stamina settlement remains external." % [action.capitalize(), index]}

func _neighbors(index: int) -> Array:
    var out: Array = []
    var x: int = index % WIDTH
    var y: int = int(index / WIDTH)
    if x > 0:
        out.append(index - 1)
    if x < WIDTH - 1:
        out.append(index + 1)
    if y > 0:
        out.append(index - WIDTH)
    if y < 4:
        out.append(index + WIDTH)
    return out

func advance_day(epoch: int, humidity: int, wind: int) -> Dictionary:
    if epoch < 1 or epoch > MAX_EPOCH or epoch != int(_state["last_epoch"]) + 1:
        return _reject("Day epoch must advance exactly once.")
    if humidity < 0 or humidity > 100 or wind < 0 or wind > 100:
        return _reject("Humidity and wind must be 0..100.")
    var before: Dictionary = _state
    var next: Dictionary = _state.duplicate(true)
    var infected: int = 0
    for i in range(BED_COUNT):
        var old: Dictionary = before["beds"][i]
        var b: Dictionary = next["beds"][i]
        if old["crop"] == "":
            continue
        var incoming: int = 0
        if int(old["quarantine_days"]) == 0:
            for j in _neighbors(i):
                var neighbor: Dictionary = before["beds"][j]
                if neighbor["crop"] != "" and int(neighbor["quarantine_days"]) == 0:
                    incoming += int(int(neighbor["infection"]) / 12)
        var humidity_risk: int = maxi(0, int((humidity - 55) / 10))
        var wind_risk: int = int(wind >= 70 and incoming > 0)
        var sanitation_shield: int = 5 if int(old["sanitation_days"]) > 0 else 0
        var immunity_shield: int = int(int(old["immunity"]) / 25)
        var exposure: int = maxi(0, humidity_risk + incoming + wind_risk - sanitation_shield - immunity_shield)
        var infection: int = int(old["infection"])
        if infection == 0 and exposure >= 3:
            infection = exposure
        elif infection > 0:
            var healing: int = 8 if int(old["treatment_days"]) > 0 else (2 if humidity < 35 else 0)
            infection = clampi(infection + maxi(1, exposure) - healing, 0, 100)
        b["infection"] = infection
        if infection > 0:
            b["damage"] = clampi(int(old["damage"]) + int(infection / 20) + int(infection >= 35), 0, 100)
            infected += 1
        elif int(old["infection"]) > 0:
            b["immunity"] = mini(100, int(old["immunity"]) + 5)
        for key in ["sanitation_days", "quarantine_days", "treatment_days"]:
            b[key] = maxi(0, int(old[key]) - 1)
    next["last_epoch"] = epoch
    if not _valid(next):
        return _reject("Daily disease state failed validation.")
    _state = next
    return {"ok": true, "day_epoch": epoch, "year": int((epoch - 1) / 56) + 1,
        "season_index": int(((epoch - 1) % 56) / 14), "infected_beds": infected,
        "message": "%d planting beds have active symptoms." % infected}
