extends RefCounted
## F07 isolated orchard ecology. Never modifies game inventory, money or the 30 beds.
const SLOT_COUNT := 8
const YEAR_DAYS := 56
const MAX_EPOCH := 2000000
const MAX_FRUIT := 10000000
const SPECIES := ["apple", "pear", "plum"]
const ROOTSTOCKS := ["dwarf", "standard"]
const TREE_FIELDS := ["species", "rootstock", "age_days", "health", "stress",
    "pruned_year", "harvested_year", "fruit_units", "quality", "dormant", "last_action_epoch"]
const LEDGER_FIELDS := ["generated", "harvested", "spoiled"]
var _state: Dictionary = {}

func _init() -> void:
    var trees: Array = []
    for i in range(SLOT_COUNT):
        trees.append(_empty_tree())
    _state = {"schema": 1, "last_epoch": 0, "trees": trees,
        "ledger": {"generated": 0, "harvested": 0, "spoiled": 0}}

func _empty_tree() -> Dictionary:
    return {"species": "", "rootstock": "", "age_days": 0, "health": 0,
        "stress": 0, "pruned_year": 0, "harvested_year": 0, "fruit_units": 0,
        "quality": 0, "dormant": false, "last_action_epoch": -1}

func _year(epoch: int) -> int:
    return int((epoch - 1) / YEAR_DAYS) + 1 if epoch > 0 else 0

func _day_of_year(epoch: int) -> int:
    return (epoch - 1) % YEAR_DAYS if epoch > 0 else -1

func _exact_keys(value: Dictionary, expected: Array) -> bool:
    if value.size() != expected.size():
        return false
    for key in expected:
        if not value.has(key):
            return false
    return true

func _valid(payload: Variant) -> bool:
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    var s: Dictionary = payload
    if not _exact_keys(s, ["schema", "last_epoch", "trees", "ledger"]):
        return false
    if typeof(s["schema"]) != TYPE_INT or s["schema"] != 1:
        return false
    if typeof(s["last_epoch"]) != TYPE_INT or s["last_epoch"] < 0 or s["last_epoch"] > MAX_EPOCH:
        return false
    if typeof(s["trees"]) != TYPE_ARRAY or s["trees"].size() != SLOT_COUNT:
        return false
    if typeof(s["ledger"]) != TYPE_DICTIONARY:
        return false
    var ledger: Dictionary = s["ledger"]
    if not _exact_keys(ledger, LEDGER_FIELDS):
        return false
    for key in LEDGER_FIELDS:
        if typeof(ledger[key]) != TYPE_INT or ledger[key] < 0 or ledger[key] > MAX_FRUIT:
            return false
    var fruit_remaining: int = 0
    for entry in s["trees"]:
        if typeof(entry) != TYPE_DICTIONARY:
            return false
        var t: Dictionary = entry
        if not _exact_keys(t, TREE_FIELDS):
            return false
        if typeof(t["species"]) != TYPE_STRING or typeof(t["rootstock"]) != TYPE_STRING:
            return false
        if typeof(t["dormant"]) != TYPE_BOOL:
            return false
        for key in TREE_FIELDS:
            if key != "species" and key != "rootstock" and key != "dormant":
                if typeof(t[key]) != TYPE_INT:
                    return false
        if t["last_action_epoch"] < -1 or t["last_action_epoch"] > s["last_epoch"]:
            return false
        if t["age_days"] < 0 or t["age_days"] > s["last_epoch"]:
            return false
        if t["health"] < 0 or t["health"] > 100 or t["stress"] < 0 or t["stress"] > 100:
            return false
        if t["quality"] < 0 or t["quality"] > 5 or t["fruit_units"] < 0 or t["fruit_units"] > 20:
            return false
        if t["pruned_year"] < 0 or t["pruned_year"] > _year(s["last_epoch"]):
            return false
        if t["harvested_year"] < 0 or t["harvested_year"] > _year(s["last_epoch"]):
            return false
        if t["species"] == "":
            if t != _empty_tree():
                return false
        else:
            if not SPECIES.has(t["species"]) or not ROOTSTOCKS.has(t["rootstock"]):
                return false
            if t["health"] == 0 and t["age_days"] == 0:
                return false
            if t["fruit_units"] > 0 and (t["quality"] == 0 or t["harvested_year"] == _year(s["last_epoch"])):
                return false
            if t["fruit_units"] == 0 and t["quality"] != 0:
                return false
            if t["dormant"] and _day_of_year(s["last_epoch"]) < 42:
                return false
        fruit_remaining += int(t["fruit_units"])
    return int(ledger["generated"]) == int(ledger["harvested"]) + int(ledger["spoiled"]) + fruit_remaining

func save_state() -> Dictionary:
    return _state.duplicate(true)

func load_state(payload: Variant) -> bool:
    if not _valid(payload):
        return false
    _state = (payload as Dictionary).duplicate(true)
    return true

## Godot JSON decoding may represent integral numbers as floats. Convert only
## exact bounded integers; fractions, infinities, NaNs and out-of-range values fail.
func _json_int(value: Variant) -> Variant:
    if typeof(value) == TYPE_FLOAT and not is_nan(value) and not is_inf(value):
        if value >= -1.0 and value <= float(MAX_FRUIT) and floor(value) == value:
            return int(value)
    return value

func load_json(raw: String) -> bool:
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    var s: Dictionary = (parsed as Dictionary).duplicate(true)
    for key in ["schema", "last_epoch"]:
        if s.has(key):
            s[key] = _json_int(s[key])
    if typeof(s.get("ledger")) == TYPE_DICTIONARY:
        for key in LEDGER_FIELDS:
            if s["ledger"].has(key):
                s["ledger"][key] = _json_int(s["ledger"][key])
    if typeof(s.get("trees")) == TYPE_ARRAY:
        for entry in s["trees"]:
            if typeof(entry) != TYPE_DICTIONARY:
                continue
            for key in TREE_FIELDS:
                if key != "species" and key != "rootstock" and key != "dormant" and entry.has(key):
                    entry[key] = _json_int(entry[key])
    return load_state(s)

func _reject(message: String) -> Dictionary:
    return {"ok": false, "message": message}

func status(slot: int) -> Dictionary:
    if slot < 0 or slot >= SLOT_COUNT:
        return _reject("No orchard tree at that location.")
    var t: Dictionary = _state["trees"][slot]
    if t["species"] == "":
        return {"ok": true, "message": "Empty orchard space; plant a sapling.", "fruit_units": 0}
    var message: String = "%s (%s rootstock), age %d days, health %d/100, %d fruit, quality %d/5." % [
        str(t["species"]).capitalize(), str(t["rootstock"]), int(t["age_days"]),
        int(t["health"]), int(t["fruit_units"]), int(t["quality"])]
    if bool(t["dormant"]):
        message += " Dormant for winter."
    elif int(t["fruit_units"]) > 0:
        message += " Ready to harvest."
    return {"ok": true, "species": t["species"], "rootstock": t["rootstock"],
        "age_days": t["age_days"], "health": t["health"], "stress": t["stress"],
        "fruit_units": t["fruit_units"], "quality": t["quality"],
        "dormant": t["dormant"], "message": message}

func plant(slot: int, species: String, rootstock: String, epoch: int) -> Dictionary:
    if slot < 0 or slot >= SLOT_COUNT or not SPECIES.has(species) or not ROOTSTOCKS.has(rootstock):
        return _reject("Invalid orchard slot, species or rootstock.")
    if epoch < 1 or epoch != int(_state["last_epoch"]):
        return _reject("Planting requires the current monotonic day.")
    if _state["trees"][slot]["species"] != "":
        return _reject("This orchard space is occupied.")
    var next: Dictionary = _state.duplicate(true)
    next["trees"][slot] = {"species": species, "rootstock": rootstock,
        "age_days": 0, "health": 80, "stress": 0, "pruned_year": 0,
        "harvested_year": 0, "fruit_units": 0, "quality": 0,
        "dormant": false, "last_action_epoch": epoch}
    if not _valid(next):
        return _reject("Invalid sapling transition.")
    _state = next
    return {"ok": true, "item_required": species + "_" + rootstock + "_sapling",
        "message": "Planted %s sapling; sapling debit requires external authority." % species}

func prune(slot: int, epoch: int) -> Dictionary:
    if slot < 0 or slot >= SLOT_COUNT or epoch < 1 or epoch != int(_state["last_epoch"]):
        return _reject("Invalid orchard slot or day.")
    var day: int = _day_of_year(epoch)
    if day < 0 or day >= 14:
        return _reject("Prune only during spring.")
    var t: Dictionary = _state["trees"][slot]
    if t["species"] == "" or int(t["last_action_epoch"]) == epoch:
        return _reject("No sapling to prune or already acted today.")
    if int(t["pruned_year"]) == _year(epoch):
        return _reject("This tree was already pruned this year.")
    var next: Dictionary = _state.duplicate(true)
    next["trees"][slot]["pruned_year"] = _year(epoch)
    next["trees"][slot]["last_action_epoch"] = epoch
    next["trees"][slot]["stress"] = maxi(0, int(t["stress"]) - 3)
    if not _valid(next):
        return _reject("Invalid pruning transition.")
    _state = next
    return {"ok": true, "stamina_required": 2, "message": "Pruned for a healthier autumn crop; stamina settlement remains external."}

func harvest(slot: int, epoch: int) -> Dictionary:
    if slot < 0 or slot >= SLOT_COUNT or epoch < 1 or epoch != int(_state["last_epoch"]):
        return _reject("Invalid orchard slot or day.")
    var t: Dictionary = _state["trees"][slot]
    if t["species"] == "" or int(t["fruit_units"]) == 0 or int(t["last_action_epoch"]) == epoch:
        return _reject("No ripe fruit or already acted today.")
    var quantity: int = int(t["fruit_units"])
    var quality: int = int(t["quality"])
    var next: Dictionary = _state.duplicate(true)
    next["trees"][slot]["fruit_units"] = 0
    next["trees"][slot]["quality"] = 0
    next["trees"][slot]["harvested_year"] = _year(epoch)
    next["trees"][slot]["last_action_epoch"] = epoch
    next["ledger"]["harvested"] = int(next["ledger"]["harvested"]) + quantity
    if not _valid(next):
        return _reject("Orchard harvest ledger rejected.")
    _state = next
    return {"ok": true, "species": t["species"], "quantity": quantity,
        "quality": quality, "message": "Harvested %d %s (quality %d/5); inventory credit requires atomic external settlement." % [
            quantity, str(t["species"]), quality]}

func advance_day(epoch: int, temperature_c: int, rainfall_mm: int) -> Dictionary:
    if epoch < 1 or epoch > MAX_EPOCH or epoch != int(_state["last_epoch"]) + 1:
        return _reject("Day epoch must advance exactly once without gaps.")
    if temperature_c < -40 or temperature_c > 55 or rainfall_mm < 0 or rainfall_mm > 250:
        return _reject("Invalid finite weather input.")
    var next: Dictionary = _state.duplicate(true)
    next["last_epoch"] = epoch
    var day: int = _day_of_year(epoch)
    var year: int = _year(epoch)
    var generated: int = 0
    var spoiled: int = 0
    for i in range(SLOT_COUNT):
        var t: Dictionary = next["trees"][i]
        if t["species"] == "":
            continue
        t["age_days"] = mini(MAX_EPOCH, int(t["age_days"]) + 1)
        t["dormant"] = day >= 42
        if day == 42 and int(t["fruit_units"]) > 0:
            spoiled += int(t["fruit_units"])
            t["fruit_units"] = 0
            t["quality"] = 0
        if bool(t["dormant"]):
            t["stress"] = maxi(0, int(t["stress"]) - 2)
        elif temperature_c > 34 or rainfall_mm == 0:
            t["stress"] = mini(100, int(t["stress"]) + (2 if t["rootstock"] == "dwarf" else 1))
        else:
            t["stress"] = maxi(0, int(t["stress"]) - 2)
        if int(t["stress"]) >= 25:
            t["health"] = maxi(1, int(t["health"]) - 1)
        elif rainfall_mm >= 3 and not bool(t["dormant"]):
            t["health"] = mini(100, int(t["health"]) + 1)
        if day == 28 and int(t["age_days"]) >= 56 and int(t["health"]) >= 35:
            var base: int = 6 if t["species"] == "apple" else (5 if t["species"] == "pear" else 7)
            var pruning_bonus: int = 2 if int(t["pruned_year"]) == year else 0
            var rootstock_bonus: int = 2 if t["rootstock"] == "dwarf" else 0
            var quantity: int = clampi(base + pruning_bonus + rootstock_bonus - int(int(t["stress"]) / 20), 1, 20)
            t["fruit_units"] = quantity
            t["quality"] = clampi(2 + int(int(t["health"]) >= 75) + int(int(t["pruned_year"]) == year) - int(int(t["stress"]) >= 40), 1, 5)
            generated += quantity
    next["ledger"]["generated"] = int(next["ledger"]["generated"]) + generated
    next["ledger"]["spoiled"] = int(next["ledger"]["spoiled"]) + spoiled
    if not _valid(next):
        return _reject("Finite orchard transition rejected without mutation.")
    _state = next
    return {"ok": true, "epoch": epoch, "year": year, "season_index": int(day / 14),
        "fruit_generated": generated, "fruit_spoiled": spoiled,
        "message": "Orchard day %d: %d new fruit, %d spoiled." % [epoch, generated, spoiled]}
