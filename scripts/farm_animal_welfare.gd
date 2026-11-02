extends RefCounted
## F11: optional, deterministic animal-welfare domain. Does not mutate live game inventory.
## Owner: Farming. Integration requires Principal-authorized settlement and save schema.
const IDS := ["hen", "cow", "sheep"]
const TEMPERAMENT := {"hen":70, "cow":55, "sheep":65}
const COSTS := {
    "feed":{"fodder":1},
    "groom":{"energy":2},
    "socialize":{"energy":1},
    "treat":{"gold":12,"energy":2}
}
const METRICS := ["nutrition", "mood", "grooming", "social", "space", "health", "sickness"]
const WEATHER := ["Clear", "Rain", "Storm", "Heat", "Frost"]
const VERSION := 1
var day_epoch: int = 1
var animals: Dictionary = {}

func setup(epoch: int = 1) -> bool:
    if epoch < 1 or epoch > 1000000:
        return false
    day_epoch = epoch
    animals.clear()
    for id in IDS:
        animals[id] = {
            "nutrition":65, "mood":65, "grooming":70, "social":60,
            "space":70, "health":85, "sickness":0,
            "temperament":TEMPERAMENT[id], "treatment_days":0,
            "last_actions":{"feed":-1, "groom":-1, "socialize":-1, "treat":-1}
        }
    return true

func quote_action(id: String, verb: String) -> Dictionary:
    if not animals.has(id) or not COSTS.has(verb):
        return {}
    return COSTS[verb].duplicate(true)

## settle(cost) MUST be a trusted, atomic, authoritative game economy callback.
## No receipt format is considered proof of authority by this isolated domain.
func act(id: String, verb: String, epoch: int, settle: Callable) -> String:
    if not animals.has(id) or not COSTS.has(verb):
        return "denied:unknown"
    if epoch != day_epoch:
        return "denied:epoch"
    var a: Dictionary = animals[id]
    var last: Dictionary = a["last_actions"]
    if int(last[verb]) == epoch:
        return "denied:duplicate"
    if verb == "treat" and int(a["sickness"]) == 0:
        return "denied:healthy"
    if not settle.is_valid():
        return "denied:no_authority"
    var result: Variant = settle.call(quote_action(id, verb))
    if typeof(result) != TYPE_BOOL or not result:
        return "denied:unpaid"
    last[verb] = epoch
    match verb:
        "feed":
            a["nutrition"] = mini(100, int(a["nutrition"]) + 27)
            a["mood"] = mini(100, int(a["mood"]) + 3)
        "groom":
            a["grooming"] = mini(100, int(a["grooming"]) + 32)
            a["mood"] = mini(100, int(a["mood"]) + 5)
        "socialize":
            a["social"] = mini(100, int(a["social"]) + 28)
            a["mood"] = mini(100, int(a["mood"]) + 7)
        "treat":
            # Care schedules a slow recovery; it never instantly removes illness.
            a["treatment_days"] = maxi(3, int(a["treatment_days"]))
    return "ok:%s:%s" % [id, verb]

func next_day(epoch: int, weather: String, space_by_id: Dictionary) -> bool:
    if epoch != day_epoch + 1 or epoch > 1000000 or not WEATHER.has(weather):
        return false
    if space_by_id.size() != IDS.size():
        return false
    for id in IDS:
        if not space_by_id.has(id) or not _bounded_int(space_by_id[id], 0, 100):
            return false
    var updated: Dictionary = animals.duplicate(true)
    for id in IDS:
        var a: Dictionary = updated[id]
        a["space"] = int(space_by_id[id])
        a["nutrition"] = maxi(0, int(a["nutrition"]) - 9)
        a["grooming"] = maxi(0, int(a["grooming"]) - 7)
        a["social"] = maxi(0, int(a["social"]) - 6)
        var deprivation: int = int(int(a["nutrition"]) < 30) + int(int(a["grooming"]) < 30) + int(int(a["social"]) < 30) + int(int(a["space"]) < 35)
        var weather_stress: int = int(weather == "Storm" or weather == "Heat" or weather == "Frost")
        var skittish: int = int(int(a["temperament"]) < 60 and weather_stress > 0)
        a["mood"] = clampi(int(a["mood"]) + (2 if deprivation == 0 and weather_stress == 0 else -3 * deprivation - weather_stress - skittish), 0, 100)
        var exposure: int = int(int(a["grooming"]) < 35) * 3 + int(int(a["space"]) < 30) * 3 + int(int(a["nutrition"]) < 25) * 4
        if weather == "Storm" and int(a["grooming"]) < 50:
            exposure += 2
        a["sickness"] = clampi(int(a["sickness"]) + exposure, 0, 100)
        if int(a["treatment_days"]) > 0:
            a["sickness"] = maxi(0, int(a["sickness"]) - 5)
            a["treatment_days"] = int(a["treatment_days"]) - 1
        var harm: int = int(int(a["sickness"]) >= 30) * 3 + int(int(a["nutrition"]) < 20) * 4 + int(int(a["space"]) < 20) * 2
        a["health"] = clampi(int(a["health"]) - harm + int(harm == 0 and int(a["sickness"]) < 15), 0, 100)
    animals = updated
    day_epoch = epoch
    return true

func forecast(id: String) -> Dictionary:
    if not animals.has(id):
        return {}
    var a: Dictionary = animals[id]
    var risk: int = int(int(a["nutrition"]) < 35) + int(int(a["grooming"]) < 35) + int(int(a["social"]) < 35) + int(int(a["space"]) < 35) + int(int(a["sickness"]) >= 30)
    return {
        "id":id, "day_epoch":day_epoch, "risk":mini(5, risk),
        "nutrition":a["nutrition"], "mood":a["mood"],
        "grooming":a["grooming"], "social":a["social"],
        "space":a["space"], "health":a["health"],
        "sickness":a["sickness"], "treatment_days":a["treatment_days"]
    }

func save_state() -> Dictionary:
    return {"version":VERSION, "day_epoch":day_epoch, "animals":animals.duplicate(true)}

func load_state(saved: Variant) -> bool:
    if not saved is Dictionary or saved.size() != 3:
        return false
    if not _bounded_int(saved.get("version"), VERSION, VERSION):
        return false
    if not _bounded_int(saved.get("day_epoch"), 1, 1000000):
        return false
    var records: Variant = saved.get("animals")
    if not records is Dictionary or records.size() != IDS.size():
        return false
    var epoch: int = int(saved["day_epoch"])
    for id in IDS:
        if not records.has(id) or not records[id] is Dictionary:
            return false
        if not _valid_animal(id, records[id], epoch):
            return false
    # Commit only after validating the entire nested snapshot.
    day_epoch = epoch
    animals = records.duplicate(true)
    return true

func _valid_animal(id: String, a: Dictionary, epoch: int) -> bool:
    if a.size() != 10:
        return false
    for metric in METRICS:
        if not _bounded_int(a.get(metric), 0, 100):
            return false
    if not _bounded_int(a.get("temperament"), int(TEMPERAMENT[id]), int(TEMPERAMENT[id])):
        return false
    if not _bounded_int(a.get("treatment_days"), 0, 3):
        return false
    var actions: Variant = a.get("last_actions")
    if not actions is Dictionary or actions.size() != COSTS.size():
        return false
    for verb in COSTS:
        if not actions.has(verb) or not _bounded_int(actions[verb], -1, epoch):
            return false
    return true

func _bounded_int(value: Variant, low: int, high: int) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    var number: float = float(value)
    return is_finite(number) and number >= float(low) and number <= float(high) and floor(number) == number
