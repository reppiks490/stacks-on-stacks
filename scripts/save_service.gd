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

static func validate_payload(payload: Dictionary) -> bool:
    if not _is_number(payload.get("schema", null)) or int(payload["schema"]) != SCHEMA:
        return false
    for key: String in ["day", "season", "minute", "gold", "energy"]:
        if not _is_number(payload.get(key, null)):
            return false
    if int(payload["day"]) < 1 or int(payload["day"]) > 14:
        return false
    if int(payload["season"]) < 0 or int(payload["season"]) > 3:
        return false
    if float(payload["minute"]) < 0.0 or float(payload["minute"]) > 1440.0:
        return false
    if float(payload["gold"]) < 0.0 or float(payload["energy"]) < 0.0:
        return false
    if payload.has("year") and (not _is_number(payload["year"]) or int(payload["year"]) < 1):
        return false
    if typeof(payload.get("inventory", null)) != TYPE_DICTIONARY:
        return false
    if typeof(payload.get("farm", null)) != TYPE_ARRAY:
        return false
    if typeof(payload.get("village", null)) != TYPE_DICTIONARY:
        return false
    if typeof(payload.get("animals", null)) != TYPE_DICTIONARY:
        return false
    var position: Variant = payload.get("hero_position", null)
    if typeof(position) != TYPE_ARRAY:
        return false
    var coordinates: Array = position
    if coordinates.size() != 3:
        return false
    for value: Variant in coordinates:
        if not _is_number(value):
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
