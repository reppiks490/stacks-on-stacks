extends RefCounted
## F13 isolated deterministic pasture domain; no live animals, inventory or game-save writes.
const PADDOCKS := 3
const FORAGE_CAP := 20
const MANURE_CAP := 20
const ANIMAL_IDS := ["hen", "cow", "sheep"]
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const WEATHER := ["Clear", "Rain", "Storm", "Drought"]
var state: Dictionary = {}

func _init() -> void:
    reset()

func reset() -> void:
    state = {
        "last_epoch":1, "active":0, "last_move_epoch":-1,
        "season":"Spring", "weather":"Clear",
        "paddocks":[], "last_grazed":{"hen":-1, "cow":-1, "sheep":-1},
        "ledger":{"grown":0, "consumed":0, "deposited":0,
            "applied":0, "soil_gained":0, "soil_lost":0}
    }
    for i in range(PADDOCKS):
        state["paddocks"].append({"forage":12, "manure":0, "soil":50,
            "last_amend_epoch":-1})

func save_state() -> Dictionary:
    return state.duplicate(true)

func describe() -> String:
    var active: int = int(state["active"])
    var field: Dictionary = state["paddocks"][active]
    return "Paddock %d: %d/%d forage, %d manure, soil %d/100; %s %s." % [
        active + 1, int(field["forage"]), FORAGE_CAP, int(field["manure"]),
        int(field["soil"]), state["season"], state["weather"]]

func _result(ok: bool, message: String) -> Dictionary:
    return {"ok":ok, "message":message}

func move_to(index: int, epoch: int) -> Dictionary:
    if epoch != int(state["last_epoch"]):
        return _result(false, "Move denied: stale calendar epoch.")
    if index < 0 or index >= PADDOCKS:
        return _result(false, "Move denied: unknown paddock.")
    if index == int(state["active"]) or epoch == int(state["last_move_epoch"]):
        return _result(false, "Move denied: already moved or already grazing here.")
    state["active"] = index
    state["last_move_epoch"] = epoch
    return _result(true, "Animals moved to resting paddock %d." % (index + 1))

func graze(animal_id: String, epoch: int) -> Dictionary:
    if epoch != int(state["last_epoch"]) or not ANIMAL_IDS.has(animal_id):
        return _result(false, "Grazing denied: unknown animal or calendar.")
    if int(state["last_grazed"][animal_id]) == epoch:
        return _result(false, "Grazing denied: animal already ate today.")
    if state["season"] == "Winter" or state["weather"] == "Storm":
        return _result(false, "Grazing denied: unsafe seasonal conditions.")
    var field: Dictionary = state["paddocks"][int(state["active"])]
    if int(field["forage"]) < 1 or int(field["manure"]) >= MANURE_CAP:
        return _result(false, "Grazing denied: no forage or manure storage.")
    field["forage"] = int(field["forage"]) - 1
    field["manure"] = int(field["manure"]) + 1
    if int(field["soil"]) > 0:
        field["soil"] = int(field["soil"]) - 1
        state["ledger"]["soil_lost"] = int(state["ledger"]["soil_lost"]) + 1
    state["last_grazed"][animal_id] = epoch
    state["ledger"]["consumed"] = int(state["ledger"]["consumed"]) + 1
    state["ledger"]["deposited"] = int(state["ledger"]["deposited"]) + 1
    return _result(true, "%s grazed one forage; manure collected." % animal_id.capitalize())

func apply_manure(index: int, epoch: int) -> Dictionary:
    if epoch != int(state["last_epoch"]) or index < 0 or index >= PADDOCKS:
        return _result(false, "Soil amendment denied: invalid calendar or field.")
    var field: Dictionary = state["paddocks"][index]
    if int(field["last_amend_epoch"]) == epoch or int(field["manure"]) < 2:
        return _result(false, "Soil amendment denied: daily limit or insufficient manure.")
    if int(field["soil"]) >= 100:
        return _result(false, "Soil amendment denied: soil already enriched.")
    var actual: int = mini(6, 100 - int(field["soil"]))
    field["soil"] = int(field["soil"]) + actual
    field["manure"] = int(field["manure"]) - 2
    field["last_amend_epoch"] = epoch
    state["ledger"]["applied"] = int(state["ledger"]["applied"]) + 2
    state["ledger"]["soil_gained"] = int(state["ledger"]["soil_gained"]) + actual
    return _result(true, "Two manure units restored %d soil fertility." % actual)

func advance_day(epoch: int, weather: String, season: String) -> Dictionary:
    if epoch != int(state["last_epoch"]) + 1 or not WEATHER.has(weather) or not SEASONS.has(season):
        return _result(false, "Daily transition denied: non-monotonic epoch or invalid climate.")
    state["last_epoch"] = epoch
    state["weather"] = weather
    state["season"] = season
    for i in range(PADDOCKS):
        var field: Dictionary = state["paddocks"][i]
        var recovery: int = 0 if season == "Winter" else (1 if i == int(state["active"]) else 3)
        if season != "Winter" and weather == "Rain":
            recovery += 1
        if weather == "Drought":
            recovery = maxi(0, recovery - 2)
        var actual: int = mini(recovery, FORAGE_CAP - int(field["forage"]))
        field["forage"] = int(field["forage"]) + actual
        state["ledger"]["grown"] = int(state["ledger"]["grown"]) + actual
        if season != "Winter" and i != int(state["active"]):
            var soil_gain: int = mini(1, 100 - int(field["soil"]))
            field["soil"] = int(field["soil"]) + soil_gain
            state["ledger"]["soil_gained"] = int(state["ledger"]["soil_gained"]) + soil_gain
    return _result(true, "Paddocks advanced exactly one day.")

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    var number: float = float(value)
    return is_finite(number) and floor(number) == number and number >= minimum and number <= maximum

func _decode(raw: Variant) -> Dictionary:
    if not (raw is Dictionary) or raw.size() != 8:
        return {}
    for key in ["last_epoch", "active", "last_move_epoch", "season", "weather",
            "paddocks", "last_grazed", "ledger"]:
        if not raw.has(key):
            return {}
    if not _integer(raw["last_epoch"], 1, 100000):
        return {}
    var epoch: int = int(raw["last_epoch"])
    if not _integer(raw["active"], 0, PADDOCKS - 1) or (
            not _integer(raw["last_move_epoch"], -1, epoch)):
        return {}
    if not (raw["season"] is String) or not SEASONS.has(raw["season"]) or (
            not (raw["weather"] is String)) or not WEATHER.has(raw["weather"]):
        return {}
    if not (raw["paddocks"] is Array) or raw["paddocks"].size() != PADDOCKS:
        return {}
    if not (raw["last_grazed"] is Dictionary) or raw["last_grazed"].size() != ANIMAL_IDS.size():
        return {}
    var last_grazed: Dictionary = {}
    for animal_id in ANIMAL_IDS:
        if not raw["last_grazed"].has(animal_id) or (
                not _integer(raw["last_grazed"][animal_id], -1, epoch)):
            return {}
        last_grazed[animal_id] = int(raw["last_grazed"][animal_id])
    var fields: Array = []
    var total_forage: int = 0
    var total_manure: int = 0
    var total_soil: int = 0
    for field in raw["paddocks"]:
        if not (field is Dictionary) or field.size() != 4:
            return {}
        for key in ["forage", "manure", "soil", "last_amend_epoch"]:
            if not field.has(key):
                return {}
        if not _integer(field["forage"], 0, FORAGE_CAP) or (
                not _integer(field["manure"], 0, MANURE_CAP)) or (
                not _integer(field["soil"], 0, 100)) or (
                not _integer(field["last_amend_epoch"], -1, epoch)):
            return {}
        var normalized: Dictionary = {
            "forage":int(field["forage"]), "manure":int(field["manure"]),
            "soil":int(field["soil"]), "last_amend_epoch":int(field["last_amend_epoch"])}
        fields.append(normalized)
        total_forage += int(field["forage"])
        total_manure += int(field["manure"])
        total_soil += int(field["soil"])
    var ledger: Dictionary = {}
    var names: Array = ["grown", "consumed", "deposited", "applied", "soil_gained", "soil_lost"]
    if not (raw["ledger"] is Dictionary) or raw["ledger"].size() != names.size():
        return {}
    for key in names:
        if not raw["ledger"].has(key) or not _integer(raw["ledger"][key], 0, 1000000):
            return {}
        ledger[key] = int(raw["ledger"][key])
    if 36 + int(ledger["grown"]) - int(ledger["consumed"]) != total_forage:
        return {}
    if int(ledger["deposited"]) - int(ledger["applied"]) != total_manure or (
            int(ledger["deposited"]) != int(ledger["consumed"])):
        return {}
    if 150 + int(ledger["soil_gained"]) - int(ledger["soil_lost"]) != total_soil:
        return {}
    return {
        "last_epoch":epoch, "active":int(raw["active"]),
        "last_move_epoch":int(raw["last_move_epoch"]),
        "season":str(raw["season"]), "weather":str(raw["weather"]),
        "paddocks":fields, "last_grazed":last_grazed, "ledger":ledger}

func load_state(raw: Variant) -> bool:
    var candidate: Dictionary = _decode(raw)
    if candidate.is_empty():
        return false
    state = candidate
    return true

func load_json(payload: String) -> bool:
    var parser := JSON.new()
    if parser.parse(payload) != OK:
        return false
    return load_state(parser.data)
