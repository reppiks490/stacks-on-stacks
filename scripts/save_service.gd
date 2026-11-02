extends RefCounted
## EVERBLOOM save boundary. Compatible with existing schema-1 save payloads.
## A temporary file + validated backup makes failed writes recoverable.
## The backup is never treated as a second active save slot.
## Resumed backup saves quarantine corrupt primaries; this is not power-loss atomicity.
## Nested schema-1 bounds mirror the current Farm/Animals/Village loader clamps.
## This is fail-closed admission, not concurrent-writer or fsync durability proof.

const SAVE_PATH: String = "user://everbloom_save_v1.json"
const TEMP_PATH: String = "user://everbloom_save_v1.json.tmp"
const BACKUP_PATH: String = "user://everbloom_save_v1.json.bak"
# Damaged primary bytes are retained separately; never overwrite an earlier quarantine.
const QUARANTINE_PREFIX: String = "user://everbloom_save_v1.json.corrupt."
const MAX_QUARANTINE_SLOTS: int = 8
const SCHEMA: int = 1
# Canonical original festival IDs. Update this schema boundary and its catalog
# parity test together when a new festival is authored; unknown awards cannot
# be silently discarded by Festival.load_state().
const FESTIVAL_EVENT_IDS := [
    "spring_seed_exchange", "spring_garden_table", "spring_bluebell_evening",
    "summer_lake_promenade", "summer_berry_picnic", "summer_lantern_making",
    "autumn_carrot_fair", "autumn_pumpkin_story", "autumn_wool_market",
    "winter_hearth_market", "winter_woodwork_day", "winter_starlight_feast"
]

static func _is_number(value: Variant) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

## Reject invalid and non-JSON state *before* any gameplay state is mutated.
## Integers stay within JSON's exact IEEE-754 range to avoid silent currency/item drift.
const MAX_SAFE_INTEGER: float = 9007199254740991.0
# A full 56-day year must fit in the JSON-exact integer range.
const MAX_SAFE_YEAR: int = 160842843834660

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
    if payload.has("year") and not _whole_in_range(payload["year"], 1.0, float(MAX_SAFE_YEAR)):
        return false
    # One calendar authority for every saved daily-action ledger. Never
    # normalize future epochs into the present during a domain load.
    var saved_epoch: float = ((float(payload.get("year", 1)) - 1.0) * 56.0
            + float(payload["season"]) * 14.0 + float(payload["day"]))
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
    # Farm.load_state() clamps these ranges. An accepted save must never
    # silently lose soil state through that clamp. Optional legacy keys remain
    # optional; unrecognized nested fields require an explicit schema upgrade.
    const FARM_LIMITS := {
        "age": 100.0, "watered_days": 100.0, "moisture": 100.0,
        "fertility": 100.0, "weeds": 5.0, "stress": 9.0,
        "rotation_bonus": 1.0, "seed_vigor": 2.0
    }
    for record in field_records:
        if typeof(record) != TYPE_DICTIONARY:
            return false
        var soil: Dictionary = record
        for attribute in soil:
            if not attribute in ["tilled", "watered", "crop", "last_family",
                                 "last_harvest_epoch"] and not FARM_LIMITS.has(attribute):
                return false
        for attribute: String in ["tilled", "watered"]:
            if soil.has(attribute) and typeof(soil[attribute]) != TYPE_BOOL:
                return false
        for attribute: String in ["crop", "last_family"]:
            if soil.has(attribute) and typeof(soil[attribute]) != TYPE_STRING:
                return false
        if soil.has("last_family") and (soil["last_family"] as String).length() > 32:
            return false
        for attribute in FARM_LIMITS:
            if soil.has(attribute) and not _whole_in_range(
                    soil[attribute], 0.0, FARM_LIMITS[attribute]):
                return false
        if soil.has("last_harvest_epoch") and not _whole_in_range(
                soil["last_harvest_epoch"], -1.0, saved_epoch):
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
            var upper_bound: float = 1000.0 if attribute == "affection" else saved_epoch
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
        # Keep the schema-1 memory additions optional for older player saves.
        # New gift-recollection epochs must be bounded by the saved calendar.
        var current_epoch: float = saved_epoch
        for rid in memory_records:
            if typeof(memory_records[rid]) != TYPE_DICTIONARY:
                return false
            var memory: Dictionary = memory_records[rid]
            # Village.load_state() saturates memory counters at one million.
            for attribute: String in ["talks", "gifts", "jobs", "festivals"]:
                if memory.has(attribute) and not _whole_in_range(
                        memory[attribute], 0.0, 1000000.0):
                    return false
            if memory.has("last_gift_epoch") and not _whole_in_range(
                    memory["last_gift_epoch"], -1.0, current_epoch):
                return false
            if memory.has("last_gift_item") and typeof(memory["last_gift_item"]) != TYPE_STRING:
                return false
            if memory.has("last_gift_favorite") and typeof(memory["last_gift_favorite"]) != TYPE_BOOL:
                return false
            if memory.has("recalled_gift_epoch") and not _whole_in_range(
                    memory["recalled_gift_epoch"], -1.0, current_epoch):
                return false
            if memory.has("gift_recollections") and not _whole_in_range(
                    memory["gift_recollections"], 0.0, 1000000.0):
                return false
            # A recollection cannot precede its referenced gift, nor refer to
            # a nonexistent gift. Reject malformed snapshots before load_state
            # silently clamps them into plausible but historically false data.
            var gift_epoch: float = float(memory.get("last_gift_epoch", -1))
            var recall_epoch: float = float(memory.get("recalled_gift_epoch", -1))
            if recall_epoch >= 0.0 and (gift_epoch < 0.0 or recall_epoch < gift_epoch):
                return false
            # Village V19: earned dialogue is a bounded, chronological record.
            # Accept absent logs from legacy schema-1 saves, but reject any
            # present malformed history before Village.load_state() can filter it.
            # The 12-entry / 256-character limits mirror Village's authoring caps.
            if memory.has("dialogue_log"):
                if typeof(memory["dialogue_log"]) != TYPE_ARRAY:
                    return false
                var history: Array = memory["dialogue_log"]
                if history.size() > 12:
                    return false
                var previous_epoch: float = 0.0
                for entry in history:
                    if typeof(entry) != TYPE_DICTIONARY:
                        return false
                    var line: Dictionary = entry
                    if line.size() != 3 or not line.has("epoch") or not line.has("locale") or not line.has("text"):
                        return false
                    if not _whole_in_range(line["epoch"], 1.0, saved_epoch):
                        return false
                    var line_epoch: float = float(line["epoch"])
                    if line_epoch <= previous_epoch:
                        return false
                    if typeof(line["locale"]) != TYPE_STRING or not line["locale"] in ["en", "es"]:
                        return false
                    if typeof(line["text"]) != TYPE_STRING:
                        return false
                    var spoken: String = line["text"]
                    if spoken.is_empty() or spoken.length() > 256:
                        return false
                    previous_epoch = line_epoch

    # Festival rewards are once-per-event-per-year. Reject malformed award
    # ledgers before Game.load_game() can silently drop or normalize entries.
    # This optional schema-1 domain remains absent in historical saves.
    if payload.has("festivals"):
        if typeof(payload["festivals"]) != TYPE_DICTIONARY:
            return false
        var festival_state: Dictionary = payload["festivals"]
        if festival_state.size() != 2:
            return false
        if not _whole_in_range(festival_state.get("schema", null), 1.0, 1.0):
            return false
        if typeof(festival_state.get("awarded", null)) != TYPE_ARRAY:
            return false
        var awarded: Array = festival_state["awarded"]
        if awarded.size() > 5000:
            return false
        var award_keys: Dictionary = {}
        var saved_year: int = int(payload.get("year", 1))
        for raw in awarded:
            if typeof(raw) != TYPE_STRING:
                return false
            var key: String = raw
            var parts: PackedStringArray = key.split(":")
            if parts.size() != 2 or not parts[0].is_valid_int():
                return false
            var award_year: int = int(parts[0])
            if award_year < 1 or award_year > saved_year or str(award_year) != parts[0]:
                return false
            var event_id: String = parts[1]
            if event_id.is_empty() or event_id.length() > 64:
                return false
            if not FESTIVAL_EVENT_IDS.has(event_id):
                return false
            for i in range(event_id.length()):
                if not "abcdefghijklmnopqrstuvwxyz0123456789_".contains(event_id.substr(i, 1)):
                    return false
            if award_keys.has(key):
                return false
            award_keys[key] = true

    var livestock: Variant = payload.get("animals", null)
    if typeof(livestock) != TYPE_DICTIONARY:
        return false
    # The original animal catalog has production cycles of 2/3/4 days.
    # The loader silently ignores unknown IDs and clamps these counters;
    # reject both forms of loss rather than admitting an altered snapshot.
    const PRODUCTION_MAX := {"hen": 1.0, "cow": 2.0, "sheep": 3.0}
    const ANIMAL_LIMITS := {
        "bond": 100.0, "happiness": 100.0, "health": 100.0,
        "hunger": 100.0, "cleanliness": 100.0,
        "neglect_days": 365.0, "compost_counter": 2.0
    }
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
        if not PRODUCTION_MAX.has(id) or typeof(livestock[id]) != TYPE_DICTIONARY:
            return false
        var animal: Dictionary = livestock[id]
        for attribute in animal:
            if attribute != "last_care" and attribute != "production_counter" and not ANIMAL_LIMITS.has(attribute):
                return false
        for attribute in ANIMAL_LIMITS:
            if animal.has(attribute) and not _whole_in_range(
                    animal[attribute], 0.0, ANIMAL_LIMITS[attribute]):
                return false
        if animal.has("production_counter") and not _whole_in_range(
                animal["production_counter"], 0.0, PRODUCTION_MAX[id]):
            return false
        if animal.has("last_care") and not _whole_in_range(
                animal["last_care"], -1.0, saved_epoch):
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

static func _available_quarantine_path() -> String:
    for slot in range(1, MAX_QUARANTINE_SLOTS + 1):
        var candidate: String = "%s%03d" % [QUARANTINE_PREFIX, slot]
        if not FileAccess.file_exists(candidate):
            return candidate
    return ""

static func write_payload(payload: Dictionary) -> bool:
    if not validate_payload(payload):
        push_error("EVERBLOOM: refused to write invalid schema-1 save")
        return false

    # A recovered player must be able to save again. Preserve the corrupt
    # primary byte-for-byte in a free quarantine slot, and keep the last valid
    # backup intact. Without a valid backup, fail closed instead of inventing
    # an authoritative save or destroying forensic evidence.
    var damaged_primary: bool = FileAccess.file_exists(SAVE_PATH) and _read_one(SAVE_PATH).is_empty()
    var quarantine_path: String = ""
    if damaged_primary:
        if _read_one(BACKUP_PATH).is_empty():
            push_error("EVERBLOOM: damaged primary has no valid backup; refusing overwrite")
            return false
        quarantine_path = _available_quarantine_path()
        if quarantine_path.is_empty():
            push_error("EVERBLOOM: damaged-save quarantine is full; refusing overwrite")
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
    if damaged_primary:
        # Only the corrupt primary is moved. Never copy its bytes over a
        # validated backup, and never reuse an occupied quarantine filename.
        if DirAccess.rename_absolute(target, ProjectSettings.globalize_path(quarantine_path)) != OK:
            push_error("EVERBLOOM: could not quarantine damaged primary; backup preserved")
            return false
        push_warning("EVERBLOOM: damaged primary quarantined at " + quarantine_path)
    elif FileAccess.file_exists(SAVE_PATH):
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
