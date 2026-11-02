extends RefCounted
## F12 optional original herd-lineage domain. Not wired to live animals or inventory.
## Pure day-epoch transitions; caller owns welfare, housing, resources and spawning.
const MAX_HERD := 18
const MAX_PER_SPECIES := 6
const MATURITY_DAYS := 56
const MIN_WELFARE := 70
const MAX_GENERATION := 4
const GESTATION := {"hen":14, "cow":28, "sheep":21}
const SPECIES := ["hen", "cow", "sheep"]
const TRAITS := ["vigor", "temperament", "productivity"]
var state: Dictionary = {}

func _init() -> void:
    reset()

func reset() -> void:
    state = {"last_epoch":1, "next_serial":10, "total_births":0, "animals":[]}
    for species in SPECIES:
        for index in range(3):
            var serial: int = state["animals"].size() + 1
            var sex: String = "male" if index == 1 else "female"
            var animal: Dictionary = _record(species, serial, sex, "", "", -111, 0,
                {"vigor":70 + index * 3, "temperament":66 + index * 4,
                 "productivity":62 + index * 5})
            animal["age_days"] = 112
            state["animals"].append(animal)

func _record(species: String, serial: int, sex: String, mother: String,
        father: String, birth_epoch: int, generation: int, traits: Dictionary) -> Dictionary:
    return {
        "id":"%s-%03d" % [species, serial], "species":species, "sex":sex,
        "mother":mother, "father":father, "birth_epoch":birth_epoch,
        "age_days":int(state.get("last_epoch", 1)) - birth_epoch,
        "generation":generation, "traits":traits.duplicate(true),
        "last_bred_epoch":-1, "pregnancy":{}
    }

func save_state() -> Dictionary:
    return state.duplicate(true)

func _find(id: String, records: Array) -> Dictionary:
    for animal in records:
        if str(animal["id"]) == id:
            return animal
    return {}

func _count_species(species: String) -> int:
    var count: int = 0
    for animal in state["animals"]:
        if animal["species"] == species:
            count += 1
    return count

func _pending_species(species: String) -> int:
    var count: int = 0
    for animal in state["animals"]:
        if animal["species"] == species and not animal["pregnancy"].is_empty():
            count += 1
    return count

func _pending_total() -> int:
    var count: int = 0
    for animal in state["animals"]:
        if not animal["pregnancy"].is_empty():
            count += 1
    return count

func _ancestors(id: String, records: Array) -> Dictionary:
    var visited: Dictionary = {}
    var queue: Array = [id]
    while not queue.is_empty():
        var current: String = str(queue.pop_front())
        if current == "" or visited.has(current):
            continue
        visited[current] = true
        var animal: Dictionary = _find(current, records)
        if not animal.is_empty():
            queue.append(animal["mother"])
            queue.append(animal["father"])
    return visited

func _related(first: String, second: String, records: Array) -> bool:
    var first_family: Dictionary = _ancestors(first, records)
    var second_family: Dictionary = _ancestors(second, records)
    for id in first_family:
        if second_family.has(id):
            return true
    return false

func describe(id: String) -> String:
    var animal: Dictionary = _find(id, state["animals"])
    if animal.is_empty():
        return "No animal with that herd identity."
    var note: String = " Expecting a calf, chick or lamb." if not animal["pregnancy"].is_empty() else ""
    return "%s: %s %s, age %d days, generation %d.%s" % [
        id, animal["sex"], animal["species"], animal["age_days"], animal["generation"], note]

func request_breeding(mother_id: String, father_id: String, epoch: int,
        welfare: Dictionary) -> Dictionary:
    if epoch != int(state["last_epoch"]):
        return {"ok":false, "message":"Breeding denied: stale calendar epoch."}
    var mother: Dictionary = _find(mother_id, state["animals"])
    var father: Dictionary = _find(father_id, state["animals"])
    if mother.is_empty() or father.is_empty():
        return {"ok":false, "message":"Breeding denied: animal identity missing."}
    if mother["sex"] != "female" or father["sex"] != "male" or mother["species"] != father["species"]:
        return {"ok":false, "message":"Breeding denied: incompatible parents."}
    if int(mother["age_days"]) < MATURITY_DAYS or int(father["age_days"]) < MATURITY_DAYS:
        return {"ok":false, "message":"Breeding denied: animals must mature first."}
    if int(mother["generation"]) >= MAX_GENERATION or int(father["generation"]) >= MAX_GENERATION:
        return {"ok":false, "message":"Breeding denied: lineage generation safeguard."}
    if not mother["pregnancy"].is_empty() or (
            int(mother["last_bred_epoch"]) >= 0 and epoch - int(mother["last_bred_epoch"]) < 28):
        return {"ok":false, "message":"Breeding denied: mother needs recovery."}
    if _related(mother_id, father_id, state["animals"]):
        return {"ok":false, "message":"Breeding denied: shared ancestry."}
    if state["animals"].size() + _pending_total() >= MAX_HERD or (
            _count_species(mother["species"]) + _pending_species(mother["species"]) >= MAX_PER_SPECIES):
        return {"ok":false, "message":"Breeding denied: reserve housing capacity first."}
    for id in [mother_id, father_id]:
        if not welfare.has(id) or not _integer(welfare[id], 0, 100) or int(welfare[id]) < MIN_WELFARE:
            return {"ok":false, "message":"Breeding denied: verified welfare below safe threshold."}
    mother["last_bred_epoch"] = epoch
    mother["pregnancy"] = {"father_id":father_id, "due_epoch":epoch + int(GESTATION[mother["species"]])}
    return {"ok":true, "message":"Breeding planned; one offspring is due after a full gestation."}

func _child(mother: Dictionary, father: Dictionary, epoch: int) -> Dictionary:
    var serial: int = int(state["next_serial"])
    var traits: Dictionary = {}
    for i in range(TRAITS.size()):
        var trait_name: String = TRAITS[i]
        var drift: int = (serial * 7 + epoch * 3 + i * 11) % 5 - 2
        traits[trait_name] = clampi(int(round((int(mother["traits"][trait_name]) +
            int(father["traits"][trait_name])) / 2.0)) + drift, 0, 100)
    var child: Dictionary = _record(str(mother["species"]), serial,
        "male" if serial % 2 == 0 else "female", str(mother["id"]),
        str(father["id"]), epoch, maxi(int(mother["generation"]), int(father["generation"])) + 1,
        traits)
    child["age_days"] = 0
    return child

func advance_day(epoch: int) -> Dictionary:
    if epoch != int(state["last_epoch"]) + 1:
        return {"ok":false, "births":[], "message":"Calendar must advance by exactly one day."}
    state["last_epoch"] = epoch
    var births: Array = []
    var children: Array = []
    for animal in state["animals"]:
        animal["age_days"] = epoch - int(animal["birth_epoch"])
        if animal["pregnancy"].is_empty():
            continue
        if int(animal["pregnancy"]["due_epoch"]) != epoch:
            continue
        var father: Dictionary = _find(str(animal["pregnancy"]["father_id"]), state["animals"])
        var child: Dictionary = _child(animal, father, epoch)
        children.append(child)
        births.append(child["id"])
        animal["pregnancy"] = {}
        state["next_serial"] = int(state["next_serial"]) + 1
        state["total_births"] = int(state["total_births"]) + 1
    for child in children:
        state["animals"].append(child)
    return {"ok":true, "births":births, "message":"Herd advanced one calendar day."}

func _integer(value: Variant, low: int, high: int) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    var number: float = float(value)
    return is_finite(number) and number >= low and number <= high and floor(number) == number

func _decode(raw: Variant) -> Dictionary:
    if not (raw is Dictionary) or raw.size() != 4:
        return {}
    for key in ["last_epoch", "next_serial", "total_births", "animals"]:
        if not raw.has(key):
            return {}
    if not _integer(raw["last_epoch"], 1, 100000) or not (raw["animals"] is Array):
        return {}
    var epoch: int = int(raw["last_epoch"])
    var records: Array = raw["animals"]
    if records.size() < 9 or records.size() > MAX_HERD:
        return {}
    if not _integer(raw["total_births"], 0, MAX_HERD - 9) or (
            int(raw["total_births"]) != records.size() - 9):
        return {}
    if not _integer(raw["next_serial"], 10, MAX_HERD + 1) or (
            int(raw["next_serial"]) != records.size() + 1):
        return {}
    var normalized: Dictionary = {
        "last_epoch":epoch, "next_serial":int(raw["next_serial"]),
        "total_births":int(raw["total_births"]), "animals":[]}
    var seen: Dictionary = {}
    var counts: Dictionary = {"hen":0, "cow":0, "sheep":0}
    for i in range(records.size()):
        var original: Variant = records[i]
        if not (original is Dictionary) or original.size() != 11:
            return {}
        for key in ["id","species","sex","mother","father","birth_epoch","age_days",
                    "generation","traits","last_bred_epoch","pregnancy"]:
            if not original.has(key):
                return {}
        if not (original["id"] is String) or not (original["species"] is String) or (
                not (original["sex"] is String)) or not (original["mother"] is String) or (
                not (original["father"] is String)):
            return {}
        var species: String = original["species"]
        var id: String = original["id"]
        if not SPECIES.has(species) or id != ("%s-%03d" % [species, i + 1]) or seen.has(id):
            return {}
        seen[id] = true
        counts[species] = int(counts[species]) + 1
        if counts[species] > MAX_PER_SPECIES:
            return {}
        if not ["male", "female"].has(original["sex"]):
            return {}
        if not _integer(original["birth_epoch"], -10000, epoch) or (
                not _integer(original["age_days"], 0, 110000)) or (
                int(original["age_days"]) != epoch - int(original["birth_epoch"])):
            return {}
        if not _integer(original["generation"], 0, MAX_GENERATION) or (
                not _integer(original["last_bred_epoch"], -1, epoch)):
            return {}
        if not (original["traits"] is Dictionary) or original["traits"].size() != 3:
            return {}
        var traits: Dictionary = {}
        for trait_name in TRAITS:
            if not original["traits"].has(trait_name) or not _integer(original["traits"][trait_name], 0, 100):
                return {}
            traits[trait_name] = int(original["traits"][trait_name])
        if not (original["pregnancy"] is Dictionary):
            return {}
        var pregnancy: Dictionary = original["pregnancy"]
        if not pregnancy.is_empty():
            if pregnancy.size() != 2 or not pregnancy.has("father_id") or (
                    not pregnancy.has("due_epoch")) or not (pregnancy["father_id"] is String) or (
                    not _integer(pregnancy["due_epoch"], epoch + 1, epoch + 28)):
                return {}
            pregnancy = {"father_id":str(pregnancy["father_id"]),
                "due_epoch":int(pregnancy["due_epoch"])}
        if i < 9:
            var expected_species: String = SPECIES[int(i / 3)]
            var expected_sex: String = "male" if i % 3 == 1 else "female"
            if species != expected_species or original["sex"] != expected_sex or (
                    original["mother"] != "" or original["father"] != "" or (
                    int(original["generation"]) != 0) or int(original["birth_epoch"]) != -111):
                return {}
        elif original["mother"] == "" or original["father"] == "" or int(original["generation"]) == 0:
            return {}
        normalized["animals"].append({
            "id":id, "species":species, "sex":str(original["sex"]),
            "mother":str(original["mother"]), "father":str(original["father"]),
            "birth_epoch":int(original["birth_epoch"]), "age_days":int(original["age_days"]),
            "generation":int(original["generation"]), "traits":traits,
            "last_bred_epoch":int(original["last_bred_epoch"]), "pregnancy":pregnancy
        })
    var pending_total: int = 0
    var pending_species: Dictionary = {"hen":0, "cow":0, "sheep":0}
    for i in range(normalized["animals"].size()):
        var animal: Dictionary = normalized["animals"][i]
        if i >= 9:
            var mother: Dictionary = _find(str(animal["mother"]), normalized["animals"])
            var father: Dictionary = _find(str(animal["father"]), normalized["animals"])
            if mother.is_empty() or father.is_empty() or mother["sex"] != "female" or (
                    father["sex"] != "male") or mother["species"] != animal["species"] or (
                    father["species"] != animal["species"]) or (
                    int(mother["birth_epoch"]) >= int(animal["birth_epoch"])) or (
                    int(father["birth_epoch"]) >= int(animal["birth_epoch"])) or (
                    int(animal["generation"]) != maxi(int(mother["generation"]),
                    int(father["generation"])) + 1) or (
                    _related(str(mother["id"]), str(father["id"]), normalized["animals"])):
                return {}
        if animal["pregnancy"].is_empty():
            continue
        var sire: Dictionary = _find(str(animal["pregnancy"]["father_id"]), normalized["animals"])
        if animal["sex"] != "female" or sire.is_empty() or sire["sex"] != "male" or (
                sire["species"] != animal["species"]) or (
                int(animal["age_days"]) < MATURITY_DAYS) or (
                int(sire["age_days"]) < MATURITY_DAYS) or (
                int(animal["generation"]) >= MAX_GENERATION) or (
                int(sire["generation"]) >= MAX_GENERATION) or (
                _related(str(animal["id"]), str(sire["id"]), normalized["animals"])) or (
                int(animal["last_bred_epoch"]) < 1) or (
                int(animal["pregnancy"]["due_epoch"]) !=
                int(animal["last_bred_epoch"]) + int(GESTATION[animal["species"]])):
            return {}
        pending_total += 1
        pending_species[animal["species"]] = int(pending_species[animal["species"]]) + 1
    if records.size() + pending_total > MAX_HERD:
        return {}
    for species in SPECIES:
        if int(counts[species]) + int(pending_species[species]) > MAX_PER_SPECIES:
            return {}
    return normalized

func load_state(raw: Variant) -> bool:
    var candidate: Dictionary = _decode(raw)
    if candidate.is_empty():
        return false
    state = candidate
    return true

func load_json(text: String) -> bool:
    var parser := JSON.new()
    if parser.parse(text) != OK:
        return false
    return load_state(parser.data)
