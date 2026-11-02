extends RefCounted
## Versioned, allowlisted local save. user:// is engine-managed per application.
const SAVE_PATH := "user://sablestar_slot_01.json"
const MAX_SAVE_BYTES := 65536

static func write_save(state) -> bool:
    var payload := JSON.stringify(state.to_save_data(), "  ")
    if payload.length() > MAX_SAVE_BYTES:
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(payload)
    file.flush()
    file.close()
    return true

static func read_save(state) -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null or file.get_length() > MAX_SAVE_BYTES:
        return false
    var contents := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(contents)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    return state.from_save_data(parsed)
