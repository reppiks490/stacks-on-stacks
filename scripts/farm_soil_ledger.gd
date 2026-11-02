extends RefCounted
## F01 finite integer soil stores; not yet wired into canonical Farm/Game.
const BED_COUNT := 30
const MAX_STORE := 1000
const MAX_LIFETIME := 1000000000000
const ELEMENTS := ["n", "p", "k", "carbon"]
const SOIL_FIELDS := ["texture", "compaction", "ph_tenths", "n", "p", "k", "carbon", "last_action_epoch"]
const TOTAL_FIELDS := ["initial", "added", "uptake", "lost"]
const AMENDMENTS := {
    "compost": {"n": 15, "p": 10, "k": 12, "carbon": 25},
    "leaf_mulch": {"n": 3, "p": 2, "k": 4, "carbon": 35}
}
var _state: Dictionary = {}

func _init() -> void:
    var beds: Array = []
    var initial := _zeros()
    for i in range(BED_COUNT):
        var texture: int = i % 3
        var bed := {
            "texture": texture, "compaction": 25 + texture * 8,
            "ph_tenths": 65, "n": 120, "p": 100, "k": 110,
            "carbon": 160, "last_action_epoch": -1
        }
        beds.append(bed)
        for key in ELEMENTS:
            initial[key] = int(initial[key]) + int(bed[key])
    _state = {"schema": 1, "last_epoch": 0, "beds": beds,
        "initial": initial, "added": _zeros(), "uptake": _zeros(), "lost": _zeros()}

func _zeros() -> Dictionary:
    return {"n": 0, "p": 0, "k": 0, "carbon": 0}

func save_state() -> Dictionary:
    return _state.duplicate(true)

func load_state(payload: Variant) -> bool:
    if not _valid(payload):
        return false
    _state = (payload as Dictionary).duplicate(true)
    return true

func status(bed_index: int) -> Dictionary:
    if bed_index < 0 or bed_index >= BED_COUNT:
        return {"ok": false, "message": "Invalid soil bed."}
    var bed: Dictionary = _state["beds"][bed_index]
    return {"ok": true, "texture": int(bed["texture"]),
        "compaction": int(bed["compaction"]), "ph_tenths": int(bed["ph_tenths"]),
        "n": int(bed["n"]), "p": int(bed["p"]), "k": int(bed["k"]),
        "carbon": int(bed["carbon"]), "balance_error": balance_error()}

func balance_error() -> int:
    var total: int = 0
    for key in ELEMENTS:
        var stored: int = 0
        for bed in _state["beds"]:
            stored += int(bed[key])
        total += absi(int(_state["initial"][key]) + int(_state["added"][key]) -
            int(_state["uptake"][key]) - int(_state["lost"][key]) - stored)
    return total

func advance_day(epoch: int, rain: int, planted: Array) -> Dictionary:
    if epoch < 1 or epoch > 2000000000 or epoch != int(_state["last_epoch"]) + 1:
        return _reject("Soil day must advance exactly once.")
    if rain < 0 or rain > 100 or planted.size() != BED_COUNT:
        return _reject("Invalid daily soil inputs.")
    for value in planted:
        if typeof(value) != TYPE_BOOL:
            return _reject("Crop flags must be booleans.")
    var next: Dictionary = _state.duplicate(true)
    for i in range(BED_COUNT):
        var bed: Dictionary = next["beds"][i]
        var texture: int = int(bed["texture"])
        var leach: int = (rain / 25) if texture == 0 else (rain / 50)
        for key in ["n", "p", "k"]:
            var available: int = int(bed[key])
            var uptake: int = mini(available, (3 if key == "n" else 2) if bool(planted[i]) else 0)
            available -= uptake
            var loss: int = mini(available, leach if key == "n" else (leach / 2))
            bed[key] = available - loss
            next["uptake"][key] = int(next["uptake"][key]) + uptake
            next["lost"][key] = int(next["lost"][key]) + loss
        var respiration: int = mini(int(bed["carbon"]), 1 + int(rain >= 75))
        bed["carbon"] = int(bed["carbon"]) - respiration
        next["lost"]["carbon"] = int(next["lost"]["carbon"]) + respiration
        bed["compaction"] = clampi(int(bed["compaction"]) + (1 if rain >= 75 else 0), 0, 100)
        if rain >= 75 and int(bed["ph_tenths"]) > 40:
            bed["ph_tenths"] = int(bed["ph_tenths"]) - 1
    next["last_epoch"] = epoch
    if not _valid(next):
        return _reject("Soil daily conservation limit reached.")
    _state = next
    return {"ok": true, "message": "Soil nutrients and carbon updated.",
        "day_epoch": epoch, "balance_error": balance_error()}

func act(bed_index: int, action: String, epoch: int) -> Dictionary:
    # External inventory authority must debit inputs before applying this receipt.
    if bed_index < 0 or bed_index >= BED_COUNT:
        return _reject("Invalid planting bed.")
    if epoch != int(_state["last_epoch"]) or epoch < 1:
        return _reject("Soil action requires the current calendar day.")
    if action != "cultivate" and not AMENDMENTS.has(action):
        return _reject("Unknown soil action.")
    if int(_state["beds"][bed_index]["last_action_epoch"]) == epoch:
        return _reject("This bed already received soil care today.")
    var next: Dictionary = _state.duplicate(true)
    var bed: Dictionary = next["beds"][bed_index]
    if action == "cultivate":
        bed["compaction"] = maxi(0, int(bed["compaction"]) - 15)
    else:
        var amendment: Dictionary = AMENDMENTS[action]
        for key in ELEMENTS:
            var added: int = int(amendment[key])
            var free: int = MAX_STORE - int(bed[key])
            var retained: int = mini(free, added)
            bed[key] = int(bed[key]) + retained
            next["added"][key] = int(next["added"][key]) + added
            next["lost"][key] = int(next["lost"][key]) + added - retained
        if action == "compost":
            bed["ph_tenths"] = mini(90, int(bed["ph_tenths"]) + 1)
    bed["last_action_epoch"] = epoch
    if not _valid(next):
        return _reject("Soil transaction rejected without mutation.")
    _state = next
    return {"ok": true, "message": "Soil care applied: " + action + ".",
        "item_required": action if action != "cultivate" else "",
        "balance_error": balance_error()}

func _reject(message: String) -> Dictionary:
    return {"ok": false, "message": message}

func _valid(payload: Variant) -> bool:
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    var s: Dictionary = payload
    if s.size() != 7 or typeof(s.get("schema")) != TYPE_INT or int(s["schema"]) != 1:
        return false
    if typeof(s.get("last_epoch")) != TYPE_INT:
        return false
    var epoch: int = int(s["last_epoch"])
    if epoch < 0 or epoch > 2000000000 or typeof(s.get("beds")) != TYPE_ARRAY:
        return false
    var beds: Array = s["beds"]
    if beds.size() != BED_COUNT:
        return false
    for bed_value in beds:
        if typeof(bed_value) != TYPE_DICTIONARY:
            return false
        var bed: Dictionary = bed_value
        if bed.size() != SOIL_FIELDS.size():
            return false
        for field in SOIL_FIELDS:
            if typeof(bed.get(field)) != TYPE_INT:
                return false
        if int(bed["texture"]) < 0 or int(bed["texture"]) > 2:
            return false
        if int(bed["compaction"]) < 0 or int(bed["compaction"]) > 100:
            return false
        if int(bed["ph_tenths"]) < 40 or int(bed["ph_tenths"]) > 90:
            return false
        if int(bed["last_action_epoch"]) < -1 or int(bed["last_action_epoch"]) > epoch:
            return false
        for key in ELEMENTS:
            if int(bed[key]) < 0 or int(bed[key]) > MAX_STORE:
                return false
    for total_name in TOTAL_FIELDS:
        if typeof(s.get(total_name)) != TYPE_DICTIONARY:
            return false
        var totals: Dictionary = s[total_name]
        if totals.size() != ELEMENTS.size():
            return false
        for key in ELEMENTS:
            if typeof(totals.get(key)) != TYPE_INT:
                return false
            if int(totals[key]) < 0 or int(totals[key]) > MAX_LIFETIME:
                return false
    for key in ELEMENTS:
        var stored: int = 0
        for bed in beds:
            stored += int(bed[key])
        if int(s["initial"][key]) + int(s["added"][key]) != (
                stored + int(s["uptake"][key]) + int(s["lost"][key])):
            return false
    return true
