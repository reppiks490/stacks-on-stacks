extends RefCounted
## EVERBLOOM save boundary. Compatible with existing schema-1 save payloads.
## A temporary file + validated backup makes failed writes recoverable.
## The backup is never treated as a second active save slot.

const SAVE_PATH: String = "user://everbloom_save_v1.json"
const TEMP_PATH: String = "user://everbloom_save_v1.json.tmp"
const BACKUP_PATH: String = "user://everbloom_save_v1.json.bak"
const SCHEMA: int = 1

static func _is_number(value: Variant) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

## Reject invalid and non-JSON state *before* any gameplay state is mutated.
## Integers stay within JSON's exact IEEE-754 range to avoid silent currency/item drift.
const MAX_SAFE_INTEGER: float = 9007199254740991.0

static func _finite_number(value: Variant) -> bool:
    if not _is_number(value):
        return false
    var number: float = float(value)
    return not is_nan(number) and not is_inf(number)

static func _whole_in_range(value: Variant, minimum: float, maximum: float) -> bool:
    if not _finite_number(value):
        return false
    var number: float = float(value)
    return number >= minimum and number <= maximum and floor(number) == number

static func _safe_json_tree(value: Variant, depth: int = 0) -> bool:
    if depth > 16:
        return false
    match typeof(value):
        TYPE_NIL, TYPE_BOOL:
            return true
        TYPE_STRING:
            return (value as String).length() <= 4096
        TYPE_INT, TYPE_FLOAT:
            return _finite_number(value)
        TYPE_ARRAY:
            var items: Array = value
            for item in items:
                if not _safe_json_tree(item, depth + 1):
                    return false
            return true
        TYPE_DICTIONARY:
            var mapping: Dictionary = value
            for key in mapping:
                if typeof(key) != TYPE_STRING or (key as String).is_empty():
                    return false
                if not _safe_json_tree(mapping[key], depth + 1):
                    return false
            return true
    return false

static func validate_payload(payload: Dictionary) -> bool:
    if not _safe_json_tree(payload):
        return false
    if not _whole_in_range(payload.get("schema", null), 1.0, 1.0):
        return false
    if not _whole_in_range(payload.get("day", null), 1.0, 14.0):
        return false
    if not _whole_in_range(payload.get("season", null), 0.0, 3.0):
        return false
    # Pre-year schema-1 saves are valid: game.gd defaults a missing year to 1.
    if payload.has("year") and not _whole_in_range(payload["year"], 1.0, MAX_SAFE_INTEGER):
        return false
    if not _finite_number(payload.get("minute", null)):
        return false
    if float(payload["minute"]) < 0.0 or float(payload["minute"]) > 1440.0:
        return false
    if not _whole_in_range(payload.get("gold", null), 0.0, MAX_SAFE_INTEGER):
        return false
    if not _finite_number(payload.get("energy", null)):
        return false
    if float(payload["energy"]) < 0.0 or float(payload["energy"]) > 100.0:
        return false
    if payload.has("weather") and typeof(payload["weather"]) != TYPE_STRING:
        return false
    if payload.has("restoration") and not _whole_in_range(payload["restoration"], 0.0, 100.0):
        return false
    for counter: String in ["care_actions", "crops_harvested"]:
        if payload.has(counter) and not _whole_in_range(payload[counter], 0.0, MAX_SAFE_INTEGER):
            return false
    if payload.has("social_contacts"):
        if typeof(payload["social_contacts"]) != TYPE_DICTIONARY:
            return false
        var contacts: Dictionary = payload["social_contacts"]
        for rid in contacts:
            if typeof(contacts[rid]) != TYPE_BOOL:
                return false

    var items: Variant = payload.get("inventory", null)
    if typeof(items) != TYPE_DICTIONARY:
        return false
    var inventory: Dictionary = items
    for id in inventory:
        if not _whole_in_range(inventory[id], 0.0, MAX_SAFE_INTEGER):
            return false
    var field_records: Variant = payload.get("farm", null)
    if typeof(field_records) != TYPE_ARRAY:
        return false
    for record in field_records:
        if typeof(record) != TYPE_DICTIONARY:
            return false
        var soil: Dictionary = record
        for attribute: String in ["tilled", "watered"]:
            if soil.has(attribute) and typeof(soil[attribute]) != TYPE_BOOL:
                return false
        for attribute: String in ["crop", "last_family"]:
            if soil.has(attribute) and typeof(soil[attribute]) != TYPE_STRING:
                return false
        for attribute: String in ["age", "watered_days", "moisture", "fertility",
                                  "weeds", "stress", "rotation_bonus", "seed_vigor"]:
            if soil.has(attribute) and not _whole_in_range(soil[attribute], 0.0, MAX_SAFE_INTEGER):
                return false
        if soil.has("last_harvest_epoch") and not _whole_in_range(
                soil["last_harvest_epoch"], -1.0, MAX_SAFE_INTEGER):
            return false

    var villagers: Variant = payload.get("village", null)
    if typeof(villagers) != TYPE_DICTIONARY:
        return false
    var social_state: Dictionary = villagers
    for attribute: String in ["affection", "talked", "gifted", "worked"]:
        if not social_state.has(attribute):
            continue
        if typeof(social_state[attribute]) != TYPE_DICTIONARY:
            return false
        var values: Dictionary = social_state[attribute]
        for rid in values:
            var lower_bound: float = 0.0 if attribute == "affection" else -1.0
            var upper_bound: float = 1000.0 if attribute == "affection" else MAX_SAFE_INTEGER
            if not _whole_in_range(values[rid], lower_bound, upper_bound):
                return false
    if social_state.has("festivals"):
        if typeof(social_state["festivals"]) != TYPE_DICTIONARY:
            return false
        var festival_records: Dictionary = social_state["festivals"]
        for key in festival_records:
            if typeof(festival_records[key]) != TYPE_BOOL:
                return false
    if social_state.has("memories"):
        if typeof(social_state["memories"]) != TYPE_DICTIONARY:
            return false
        var memory_records: Dictionary = social_state["memories"]
        for rid in memory_records:
            if typeof(memory_records[rid]) != TYPE_DICTIONARY:
                return false
            var memory: Dictionary = memory_records[rid]
            for attribute: String in ["talks", "gifts", "jobs", "festivals"]:
                if memory.has(attribute) and not _whole_in_range(
                        memory[attribute], 0.0, MAX_SAFE_INTEGER):
                    return false
            if memory.has("last_gift_epoch") and not _whole_in_range(
                    memory["last_gift_epoch"], -1.0, MAX_SAFE_INTEGER):
                return false
            if memory.has("last_gift_item") and typeof(memory["last_gift_item"]) != TYPE_STRING:
                return false

    var livestock: Variant = payload.get("animals", null)
    if typeof(livestock) != TYPE_DICTIONARY:
        return false
    for id in livestock:
        # Farming ecology stores grazing capacity at a reserved top-level key.
        # This is intentionally an Array, unlike per-animal Dictionary records.
        if id == "__paddocks__":
            if typeof(livestock[id]) != TYPE_ARRAY:
                return false
            var paddock_records: Array = livestock[id]
            if paddock_records.size() != 3:
                return false
            for paddock in paddock_records:
                if typeof(paddock) != TYPE_DICTIONARY:
                    return false
                var record: Dictionary = paddock
                if record.size() != 1 or not record.has("forage"):
                    return false
                if not _whole_in_range(paddock.get("forage", null), 0.0, 7.0):
                    return false
            continue
        if typeof(livestock[id]) != TYPE_DICTIONARY:
            return false
        var animal: Dictionary = livestock[id]
        for attribute: String in ["bond", "happiness", "health", "hunger", "cleanliness",
                                  "production_counter", "neglect_days", "compost_counter"]:
            if animal.has(attribute) and not _whole_in_range(animal[attribute], 0.0, MAX_SAFE_INTEGER):
                return false
        if animal.has("last_care") and not _whole_in_range(
                animal["last_care"], -1.0, MAX_SAFE_INTEGER):
            return false

    var position: Variant = payload.get("hero_position", null)
    if typeof(position) != TYPE_ARRAY:
        return false
    var coordinates: Array = position
    if coordinates.size() != 3:
        return false
    for value in coordinates:
        if not _finite_number(value) or absf(float(value)) > 1000000.0:
            return false
    return true

static func _read_one(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var content: String = file.get_as_text()
    file.close()
    var decoded: Variant = JSON.parse_string(content)
    if typeof(decoded) != TYPE_DICTIONARY:
        return {}
    var candidate: Dictionary = decoded
    if not validate_payload(candidate):
        return {}
    return candidate

static func read_payload() -> Dictionary:
    var primary: Dictionary = _read_one(SAVE_PATH)
    if not primary.is_empty():
        return primary
    var backup: Dictionary = _read_one(BACKUP_PATH)
    if not backup.is_empty():
        push_warning("EVERBLOOM: primary save unavailable; recovered last valid backup")
        return backup
    return {}

static func write_payload(payload: Dictionary) -> bool:
    if not validate_payload(payload):
        push_error("EVERBLOOM: refused to write invalid schema-1 save")
        return false

    # Never overwrite an existing corrupt save: preserve it for manual recovery.
    if FileAccess.file_exists(SAVE_PATH) and _read_one(SAVE_PATH).is_empty():
        push_error("EVERBLOOM: existing primary is invalid; refusing to overwrite")
        return false

    var temp: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null:
        push_error("EVERBLOOM: cannot create temporary save")
        return false
    temp.store_string(JSON.stringify(payload, "\t"))
    temp.flush()
    var write_error: Error = temp.get_error()
    temp.close()
    if write_error != OK:
        push_error("EVERBLOOM: temporary save write failed")
        return false
    if _read_one(TEMP_PATH).is_empty():
        push_error("EVERBLOOM: temporary save failed readback validation")
        return false

    var source: String = ProjectSettings.globalize_path(TEMP_PATH)
    var target: String = ProjectSettings.globalize_path(SAVE_PATH)
    var backup: String = ProjectSettings.globalize_path(BACKUP_PATH)
    if FileAccess.file_exists(SAVE_PATH):
        if DirAccess.copy_absolute(target, backup) != OK:
            push_error("EVERBLOOM: could not create save backup; original preserved")
            return false
        if DirAccess.remove_absolute(target) != OK:
            push_error("EVERBLOOM: could not replace original save; backup preserved")
            return false
    if DirAccess.rename_absolute(source, target) != OK:
        if FileAccess.file_exists(BACKUP_PATH):
            DirAccess.copy_absolute(backup, target)
        push_error("EVERBLOOM: save replacement failed; recovery backup retained")
        return false
    return true
