extends SceneTree
## Construction B13/B19: native characterization of a prospective save namespace.
## This does NOT implement construction or authorize Phase C.
## Only run with an isolated, disposable user:// directory.
const SaveService = preload("res://scripts/save_service.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        printerr("CONSTRUCTION PREFLIGHT ASSERTION FAIL: " + label)

func _equivalent(left: Variant, right: Variant) -> bool:
    if left is Dictionary and right is Dictionary:
        if left.size() != right.size():
            return false
        for key in left:
            if not right.has(key) or not _equivalent(left[key], right[key]):
                return false
        return true
    if left is Array and right is Array:
        if left.size() != right.size():
            return false
        for index in range(left.size()):
            if not _equivalent(left[index], right[index]):
                return false
        return true
    if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
        return float(left) == float(right)
    return left == right

func _isolated_user_directory() -> bool:
    var protected_paths: Array[String] = [
        SaveService.SAVE_PATH, SaveService.TEMP_PATH, SaveService.BACKUP_PATH
    ]
    for index in range(1, SaveService.MAX_QUARANTINE_SLOTS + 1):
        protected_paths.append("%s%03d" % [SaveService.QUARANTINE_PREFIX, index])
    for path in protected_paths:
        if FileAccess.file_exists(path):
            _check(false, "refusing to touch existing save or quarantine: " + path)
            return false
    if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SaveService.WRITE_LOCK_PATH)):
        _check(false, "refusing to touch existing writer lock")
        return false
    return true

func _run() -> void:
    if not _isolated_user_directory():
        quit(1)
        return

    var packed: PackedScene = load("res://scenes/main.tscn")
    _check(packed != null, "real main scene exists")
    if packed == null:
        quit(1)
        return
    var game = packed.instantiate()
    root.add_child(game)
    _check(game.day_epoch() == 1, "baseline monotonic epoch")
    var original_year: int = game.year
    var original_season: int = game.season_index
    var original_day: int = game.day
    game.year = 1
    game.season_index = 3
    game.day = 14
    _check(game.day_epoch() == 56, "last day of year one")
    game.year = 2
    game.season_index = 0
    game.day = 1
    _check(game.day_epoch() == 57, "first day of year two")
    game.year = 2
    game.season_index = 3
    game.day = 14
    _check(game.day_epoch() == 112, "last day of year two")
    game.year = 3
    game.season_index = 0
    game.day = 1
    _check(game.day_epoch() == 113, "first day of year three")
    game.year = original_year
    game.season_index = original_season
    game.day = original_day

    game.save_game(false)
    var baseline: Dictionary = SaveService.read_payload()
    _check(not baseline.is_empty(), "native initial save is readable")
    _check(SaveService.validate_payload(baseline), "baseline accepted by production save service")
    if baseline.is_empty():
        quit(1)
        return

    var probe: Dictionary = baseline.duplicate(true)
    probe["construction"] = {
        "schema": 1,
        "day_epoch": game.day_epoch(),
        "receipts": ["build_001"],
        "structures": [{
            "id": "preflight_cottage",
            "parts": [{"id": "foundation_1", "kind": "foundation", "grid": [0, 0]}]
        }],
        "escrow": {"wood": 2, "stone": 1},
        "nested": {"unknown_future_extension": {"preserve": [true, {"revision": 7}]}}
    }
    var duplicate_probe: Dictionary = probe.duplicate(true)
    duplicate_probe["construction"]["receipts"] = ["build_001", "build_001"]
    duplicate_probe["construction"]["day_epoch"] = game.day_epoch() + 56
    var duplicate_admitted: bool = SaveService.validate_payload(duplicate_probe)
    print("CONSTRUCTION PREFLIGHT duplicate/future receipt admitted: ", duplicate_admitted)
    if duplicate_admitted:
        print("CONSTRUCTION PREFLIGHT BLOCKER: production schema lacks construction receipt/epoch admission rules")
    else:
        print("CONSTRUCTION PREFLIGHT SAFE: duplicate/future construction payload rejected")

    var admitted: bool = SaveService.validate_payload(probe)
    print("CONSTRUCTION PREFLIGHT prospective extension admitted: ", admitted)
    if admitted:
        _check(SaveService.write_payload(probe), "prospective extension write accepted")
        var disk_probe: Dictionary = SaveService.read_payload()
        _check(_equivalent(disk_probe.get("construction", null), probe["construction"]),
               "save service preserves nested construction bytes semantically")
        _check(_equivalent(disk_probe.get("inventory", null), baseline.get("inventory", null)),
               "extension write conserves original inventory")
        _check(_equivalent(disk_probe.get("gold", null), baseline.get("gold", null)),
               "extension write conserves currency")

        game.load_game()
        game.save_game(false)
        var resumed: Dictionary = SaveService.read_payload()
        _check(not resumed.is_empty(), "assembled-game re-save remains readable")
        var preserved: bool = _equivalent(resumed.get("construction", null), probe["construction"])
        if preserved:
            print("CONSTRUCTION PREFLIGHT SAFE: assembled-game load/re-save preserves extension")
        else:
            print("CONSTRUCTION PREFLIGHT BLOCKER: assembled-game load/re-save DROPS construction extension")
        for domain in ["inventory", "gold", "farm", "animals", "village", "festivals"]:
            _check(_equivalent(resumed.get(domain, null), baseline.get(domain, null)),
                   "assembled-game re-save conserves existing " + domain)
        _check(SaveService.validate_payload(resumed), "re-saved baseline remains schema-valid")
    else:
        print("CONSTRUCTION PREFLIGHT SAFE: unrecognized extension rejected before game load")
        _check(_equivalent(SaveService.read_payload(), baseline),
               "rejected extension cannot mutate saved baseline")

    game.queue_free()
    if failures > 0:
        printerr("CONSTRUCTION PREFLIGHT FAIL: ", failures, " of ", checks, " checks")
        quit(1)
        return
    print("CONSTRUCTION PREFLIGHT CHARACTERIZATION PASS: ", checks,
          " checks, 0 failures; printed BLOCKER lines are confirmed integration risks, NOT approvals")
    quit(0)
