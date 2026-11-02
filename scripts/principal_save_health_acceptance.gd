extends SceneTree
## P04/P05: native read-only save-health diagnostics on an isolated CI user://.
## Never execute against an existing player profile.
const SaveService = preload("res://scripts/save_service.gd")
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("PRINCIPAL SAVE HEALTH FAIL: " + reason)

func _write_raw(path: String, contents: String) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(contents)
    file.flush()
    var status: Error = file.get_error()
    file.close()
    return status == OK

func _run() -> void:
    var paths: Array[String] = [SaveService.SAVE_PATH, SaveService.BACKUP_PATH,
                                SaveService.TEMP_PATH]
    for slot in range(1, SaveService.MAX_QUARANTINE_SLOTS + 1):
        paths.append("%s%03d" % [SaveService.QUARANTINE_PREFIX, slot])
    var lock_path: String = ProjectSettings.globalize_path(SaveService.WRITE_LOCK_PATH)
    if DirAccess.dir_exists_absolute(lock_path):
        _check(false, "refuse existing writer lock in non-isolated profile")
        quit(1)
        return
    for path in paths:
        if FileAccess.file_exists(path):
            _check(false, "refuse existing player save: " + path)
            quit(1)
            return

    var empty: Dictionary = SaveService.inspect_save_health()
    _check(empty["selected_source"] == "none", "empty profile has no source")
    _check(empty["recovery_reason"] == "no_valid_snapshot", "empty reason explicit")
    _check(empty["primary_status"] == "missing" and empty["backup_status"] == "missing",
           "empty slot statuses explicit")
    _check(not empty["writer_lock_present"], "no lock in clean profile")

    var first: Dictionary = {
        "schema": 1, "year": 2, "season": 3, "day": 14, "minute": 900.0,
        "gold": 300, "energy": 80.0, "inventory": {"turnip": 5},
        "farm": [], "village": {"affection": {"mira": 20}},
        "animals": {"__paddocks__": [{"forage": 7}, {"forage": 5}, {"forage": 3}]},
        "hero_position": [0.0, 1.0, 0.0]
    }
    _check(SaveService.write_payload(first), "first valid save")
    var first_health: Dictionary = SaveService.inspect_save_health()
    _check(first_health["selected_source"] == "primary", "primary is selected")
    _check(first_health["primary_status"] == "valid", "valid primary identified")
    _check(first_health["backup_status"] == "missing", "no fabricated backup")

    var second: Dictionary = first.duplicate(true)
    second["gold"] = 450
    second["inventory"]["turnip"] = 8
    _check(SaveService.write_payload(second), "second valid save")
    var healthy: Dictionary = SaveService.inspect_save_health()
    _check(healthy["backup_status"] == "valid", "previous primary is valid backup")
    _check(healthy["recovery_reason"] == "primary_healthy", "healthy reason explicit")
    var primary_bytes: String = FileAccess.get_file_as_string(SaveService.SAVE_PATH)
    var backup_bytes: String = FileAccess.get_file_as_string(SaveService.BACKUP_PATH)

    _check(DirAccess.make_dir_absolute(lock_path) == OK, "create simulated active lock")
    var locked: Dictionary = SaveService.inspect_save_health()
    _check(locked["writer_lock_present"], "active lock is visible")
    _check(locked["selected_source"] == "primary", "lock does not alter selection")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == primary_bytes
           and FileAccess.get_file_as_string(SaveService.BACKUP_PATH) == backup_bytes,
           "inspection under lock is byte-for-byte read-only")
    _check(DirAccess.remove_absolute(lock_path) == OK, "release test lock")

    _check(_write_raw(SaveService.TEMP_PATH, "{interrupted"), "inject torn temp")
    var interrupted: Dictionary = SaveService.inspect_save_health()
    _check(interrupted["temp_status"] == "malformed_json", "torn temp identified")
    _check(interrupted["selected_source"] == "primary", "temp is never authoritative")

    _check(_write_raw(SaveService.SAVE_PATH, "{broken"), "inject torn primary")
    var recovered: Dictionary = SaveService.inspect_save_health()
    _check(recovered["primary_status"] == "malformed_json", "torn primary identified")
    _check(recovered["selected_source"] == "backup", "valid backup selected")
    _check(recovered["recovery_reason"] == "primary_unavailable_backup_available",
           "recovery reason explicit")
    _check(int(SaveService.read_payload().get("gold", -1)) == 300,
           "diagnostics preserve actual backup recovery")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == "{broken"
           and FileAccess.get_file_as_string(SaveService.BACKUP_PATH) == backup_bytes,
           "inspection never repairs or overwrites damaged primary")

    var invalid: Dictionary = first.duplicate(true)
    invalid["schema"] = 99
    _check(_write_raw(SaveService.SAVE_PATH, JSON.stringify(invalid)),
           "inject parseable but invalid primary")
    _check(SaveService.inspect_save_health()["primary_status"] == "invalid_payload",
           "schema invalid distinguished from malformed JSON")
    _check(SaveService.inspect_save_health()["selected_source"] == "backup",
           "invalid primary cannot displace valid backup")
    _check(_write_raw(SaveService.BACKUP_PATH, "{bad-backup"), "corrupt backup")
    var lost: Dictionary = SaveService.inspect_save_health()
    _check(lost["selected_source"] == "none", "no valid source explicitly reported")
    _check(lost["recovery_reason"] == "no_valid_snapshot", "no valid snapshot reason")
    _check(FileAccess.get_file_as_string(SaveService.BACKUP_PATH) == "{bad-backup",
           "diagnostics preserve forensic backup bytes")

    for slot in range(1, SaveService.MAX_QUARANTINE_SLOTS + 1):
        _check(_write_raw("%s%03d" % [SaveService.QUARANTINE_PREFIX, slot], "forensic"),
               "reserve quarantine slot %d" % slot)
    var full: Dictionary = SaveService.inspect_save_health()
    _check(full["quarantine_occupied"] == SaveService.MAX_QUARANTINE_SLOTS,
           "full quarantine occupancy reported")
    _check(full["quarantine_capacity"] == SaveService.MAX_QUARANTINE_SLOTS,
           "quarantine capacity reported")
    _check(full["selected_source"] == "none", "full quarantine cannot invent recovery")

    for path in paths:
        if FileAccess.file_exists(path):
            _check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK,
                   "remove only test-created artifact " + path)
    _check(not DirAccess.dir_exists_absolute(lock_path), "test leaves no lock")
    print("PRINCIPAL SAVE HEALTH: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
