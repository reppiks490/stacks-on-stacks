extends SceneTree
## Principal P04/P05: filesystem recovery-resume test on isolated CI user://.
## Do not run against a player's user-data directory.
const SaveService = preload("res://scripts/save_service.gd")
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, context: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("PRINCIPAL RECOVERY FAIL: " + context)

func _write_raw(path: String, value: String) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(value)
    file.flush()
    var status: Error = file.get_error()
    file.close()
    return status == OK

func _run() -> void:
    var paths: Array[String] = [SaveService.SAVE_PATH, SaveService.TEMP_PATH,
                                SaveService.BACKUP_PATH]
    for slot in range(1, SaveService.MAX_QUARANTINE_SLOTS + 1):
        paths.append("%s%03d" % [SaveService.QUARANTINE_PREFIX, slot])
    # Fail closed; never erase or replace somebody else's local saves.
    var lock_absolute: String = ProjectSettings.globalize_path(SaveService.WRITE_LOCK_PATH)
    if DirAccess.dir_exists_absolute(lock_absolute):
        _check(false, "non-isolated writer lock already exists")
        quit(1)
        return
    for path in paths:
        if FileAccess.file_exists(path):
            _check(false, "non-isolated user-data path exists: " + path)
            quit(1)
            return

    var first: Dictionary = {
        "schema": 1, "year": 1, "day": 14, "season": 3,
        "minute": 900.0, "gold": 125, "energy": 85.0,
        "inventory": {"turnip": 3}, "farm": [],
        "village": {"affection": {"mira": 5}},
        "animals": {"__paddocks__": [{"forage": 7}, {"forage": 4}, {"forage": 2}]},
        "hero_position": [0.0, 1.0, 0.0]
    }
    _check(SaveService.validate_payload(first), "nested original fixture validates")
    # Simulate another process holding an exclusive writer lock. No temporary
    # file, backup, primary, or currency may be touched by the rejected write.
    _check(DirAccess.make_dir_absolute(lock_absolute) == OK,
           "create exclusive writer lock before first save")
    _check(not SaveService.write_payload(first),
           "second writer rejected while lock held before first save")
    _check(not FileAccess.file_exists(SaveService.SAVE_PATH)
           and not FileAccess.file_exists(SaveService.TEMP_PATH)
           and not FileAccess.file_exists(SaveService.BACKUP_PATH),
           "locked first write created no save artifacts")
    _check(DirAccess.remove_absolute(lock_absolute) == OK,
           "release simulated first writer lock")
    _check(SaveService.write_payload(first), "first durable write")
    _check(not DirAccess.dir_exists_absolute(lock_absolute),
           "successful save released writer lock")
    var second: Dictionary = first.duplicate(true)
    second["gold"] = 175
    second["inventory"]["turnip"] = 4
    second["village"]["affection"]["mira"] = 6
    _check(SaveService.write_payload(second), "second durable write")
    _check(int(SaveService._read_one(SaveService.BACKUP_PATH).get("gold", -1)) == 125,
           "backup is previous valid state")
    var primary_locked_bytes: String = FileAccess.get_file_as_string(SaveService.SAVE_PATH)
    var backup_locked_bytes: String = FileAccess.get_file_as_string(SaveService.BACKUP_PATH)
    _check(DirAccess.make_dir_absolute(lock_absolute) == OK,
           "simulate competing writer with valid primary and backup")
    var competing: Dictionary = second.duplicate(true)
    competing["gold"] = 999
    competing["inventory"]["turnip"] = 999
    _check(not SaveService.write_payload(competing),
           "competing writer rejected without currency or inventory mutation")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == primary_locked_bytes
           and FileAccess.get_file_as_string(SaveService.BACKUP_PATH) == backup_locked_bytes,
           "competing writer preserved authoritative primary and backup bytes")
    _check(not FileAccess.file_exists(SaveService.TEMP_PATH),
           "competing writer never created temporary save")
    _check(DirAccess.remove_absolute(lock_absolute) == OK,
           "release simulated competing writer lock")
    _check(SaveService.write_payload(second), "writer resumes after lock release")
    _check(not DirAccess.dir_exists_absolute(lock_absolute),
           "resumed save released exclusive writer lock")

    _check(_write_raw(SaveService.TEMP_PATH, "{interrupted"), "inject torn temp")
    _check(_write_raw(SaveService.SAVE_PATH, "{broken-01"), "inject corrupt primary")
    var recovered: Dictionary = SaveService.read_payload()
    _check(int(recovered.get("gold", -1)) == 125, "read recovers backup, not torn temp")
    _check(int(recovered.get("inventory", {}).get("turnip", -1)) == 3,
           "recovered inventory conserved")
    _check(int(recovered.get("village", {}).get("affection", {}).get("mira", -1)) == 5,
           "recovered social relationship conserved")
    var resumed: Dictionary = recovered.duplicate(true)
    resumed["gold"] = 333
    resumed["inventory"]["turnip"] = 9
    resumed["village"]["affection"]["mira"] = 10
    _check(SaveService.write_payload(resumed), "resume write after corrupt-primary recovery")
    var loaded: Dictionary = SaveService.read_payload()
    _check(int(loaded.get("gold", -1)) == 333, "resumed currency persists")
    _check(int(loaded.get("inventory", {}).get("turnip", -1)) == 9,
           "resumed inventory persists exactly, no duplicate")
    _check(int(loaded.get("village", {}).get("affection", {}).get("mira", -1)) == 10,
           "resumed relationship persists exactly")
    _check(int(loaded.get("animals", {}).get("__paddocks__", [])[1].get("forage", -1)) == 4,
           "resumed nested paddock persists exactly")
    _check(int(SaveService._read_one(SaveService.BACKUP_PATH).get("gold", -1)) == 125,
           "quarantine recovery never overwrites valid backup")
    _check(FileAccess.get_file_as_string(SaveService.QUARANTINE_PREFIX + "001") == "{broken-01",
           "first damaged primary preserved byte-for-byte")
    _check(not FileAccess.file_exists(SaveService.TEMP_PATH),
           "validated temporary save promoted to primary")

    var next: Dictionary = resumed.duplicate(true)
    next["gold"] = 355
    _check(SaveService.write_payload(next), "normal writes continue after recovery")
    _check(int(SaveService._read_one(SaveService.BACKUP_PATH).get("gold", -1)) == 333,
           "normal backup advances to last good primary")
    _check(_write_raw(SaveService.SAVE_PATH, "{broken-02"), "second corrupt primary")
    _check(int(SaveService.read_payload().get("gold", -1)) == 333,
           "second recovery uses last valid backup")
    var resumed_again: Dictionary = resumed.duplicate(true)
    resumed_again["gold"] = 444
    _check(SaveService.write_payload(resumed_again), "second recovery resumes saving")
    _check(int(SaveService.read_payload().get("gold", -1)) == 444,
           "second recovered save is authoritative")
    _check(FileAccess.get_file_as_string(SaveService.QUARANTINE_PREFIX + "001") == "{broken-01",
           "earlier quarantine never overwritten")
    _check(FileAccess.get_file_as_string(SaveService.QUARANTINE_PREFIX + "002") == "{broken-02",
           "second quarantine gets independent slot")
    _check(int(SaveService._read_one(SaveService.BACKUP_PATH).get("gold", -1)) == 333,
           "second recovery retains last valid backup")

    _check(_write_raw(SaveService.SAVE_PATH, "{broken-no-backup"),
           "inject primary with no recoverable backup")
    _check(_write_raw(SaveService.BACKUP_PATH, "{broken-backup"),
           "inject corrupt backup")
    _check(not SaveService.write_payload(resumed_again),
           "fail closed without valid backup")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == "{broken-no-backup",
           "unrecoverable primary remains unchanged")
    _check(FileAccess.get_file_as_string(SaveService.BACKUP_PATH) == "{broken-backup",
           "unrecoverable backup remains unchanged")
    _check(not FileAccess.file_exists(SaveService.QUARANTINE_PREFIX + "003"),
           "no quarantine on rejected write")

    _check(_write_raw(SaveService.BACKUP_PATH, JSON.stringify(resumed)),
           "restore valid backup for capacity test")
    for slot in range(3, SaveService.MAX_QUARANTINE_SLOTS + 1):
        _check(_write_raw("%s%03d" % [SaveService.QUARANTINE_PREFIX, slot], "reserved"),
               "fill quarantine slot %d" % slot)
    _check(not SaveService.write_payload(resumed_again), "fail closed when quarantine full")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == "{broken-no-backup",
           "quarantine capacity failure preserves primary")
    _check(int(SaveService._read_one(SaveService.BACKUP_PATH).get("gold", -1)) == 333,
           "quarantine capacity failure preserves valid backup")

    for path in paths:
        if FileAccess.file_exists(path):
            _check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK,
                   "remove only test-created artifact: " + path)
    # Exercise the assembled Game coordinator, not just SaveService fixtures.
    # The recovered session must be able to earn/spend/save without restoring
    # a stale corrupt primary or doubling any domain balance.
    var game = load("res://scripts/game.gd").new()
    root.add_child(game)
    game.year = 2
    game.season_index = 3
    game.day = 13
    game.gold = 500
    game.inventory["turnip_seed"] = 10
    game.village.memories["mira"]["talks"] = 3
    game.animals.paddocks[0]["forage"] = 5
    game.save_game(false)
    _check(int(SaveService.read_payload().get("gold", -1)) == 500,
           "assembled first game save")
    game.gold = 510
    game.inventory["turnip_seed"] = 8
    game.village.memories["mira"]["talks"] = 4
    game.animals.paddocks[0]["forage"] = 4
    game.save_game(false)
    _check(int(SaveService._read_one(SaveService.BACKUP_PATH).get("gold", -1)) == 500,
           "assembled backup is previous live state")
    _check(_write_raw(SaveService.SAVE_PATH, "{assembled-damage"),
           "damage assembled primary")
    game.gold = 0
    game.inventory["turnip_seed"] = 0
    game.village.memories["mira"]["talks"] = 0
    game.animals.paddocks[0]["forage"] = 0
    game.load_game()
    _check(game.gold == 500 and game.year == 2 and game.day == 13,
           "assembled game restores backed-up calendar and currency")
    _check(int(game.inventory["turnip_seed"]) == 10
           and int(game.village.memories["mira"]["talks"]) == 3
           and int(game.animals.paddocks[0]["forage"]) == 5,
           "assembled game restores all nested domains")
    game.gold += 7
    game.inventory["turnip_seed"] -= 2
    game.village.memories["mira"]["talks"] += 1
    game.animals.paddocks[0]["forage"] -= 1
    game.save_game(false)
    var assembled: Dictionary = SaveService.read_payload()
    _check(int(assembled.get("gold", -1)) == 507,
           "assembled resumed currency conserved")
    _check(int(assembled.get("inventory", {}).get("turnip_seed", -1)) == 8,
           "assembled resumed inventory conserved")
    _check(int(assembled.get("village", {}).get("memories", {}).get("mira", {}).get("talks", -1)) == 4,
           "assembled resumed social history conserved")
    _check(int(assembled.get("animals", {}).get("__paddocks__", [])[0].get("forage", -1)) == 4,
           "assembled resumed grazing state conserved")
    _check(int(SaveService._read_one(SaveService.BACKUP_PATH).get("gold", -1)) == 500,
           "assembled resume does not replace valid backup with corrupt bytes")
    _check(FileAccess.get_file_as_string(SaveService.QUARANTINE_PREFIX + "001")
           == "{assembled-damage", "assembled corrupt primary quarantined intact")
    for path in paths:
        if FileAccess.file_exists(path):
            _check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK,
                   "remove assembled test artifact: " + path)
    _check(not DirAccess.dir_exists_absolute(lock_absolute),
           "all successful and failed writes released writer lock")
    print("PRINCIPAL RECOVERY RESUME: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
