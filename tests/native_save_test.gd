extends SceneTree
## Native Godot persistence integration: actual filesystem readback and backup.
## Runs only on disposable CI runners; never run against a player's real save.

const SaveService = preload("res://scripts/save_service.gd")

func _initialize() -> void:
    _run_test()

func _fail(message: String) -> void:
    printerr("NATIVE SAVE TEST FAIL: " + message)
    quit(1)

func _run_test() -> void:
    for path: String in [SaveService.SAVE_PATH, SaveService.TEMP_PATH, SaveService.BACKUP_PATH]:
        if FileAccess.file_exists(path):
            if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
                _fail("could not clear isolated test save")
                return

    var first: Dictionary = {
        "schema": 1, "year": 1, "day": 14, "season": 3,
        "minute": 900.0, "gold": 125, "energy": 85.0,
        "weather": "Clear", "restoration": 7,
        "inventory": {"turnip": 3}, "farm": [],
        "village": {}, "animals": {}, "hero_position": [0.0, 1.0, 0.0]
    }
    if not SaveService.write_payload(first):
        _fail("initial save rejected")
        return
    var loaded: Dictionary = SaveService.read_payload()
    if int(loaded.get("gold", -1)) != 125:
        _fail("initial readback mismatched")
        return

    var second: Dictionary = first.duplicate(true)
    second["gold"] = 175
    second["year"] = 2
    if not SaveService.write_payload(second):
        _fail("second save rejected")
        return
    loaded = SaveService.read_payload()
    if int(loaded.get("gold", -1)) != 175 or int(loaded.get("year", -1)) != 2:
        _fail("second save readback mismatched")
        return

    var file: FileAccess = FileAccess.open(SaveService.SAVE_PATH, FileAccess.WRITE)
    if file == null:
        _fail("could not simulate primary corruption")
        return
    file.store_string("{invalid-json")
    file.close()
    loaded = SaveService.read_payload()
    if int(loaded.get("gold", -1)) != 125 or int(loaded.get("year", -1)) != 1:
        _fail("backup recovery failed")
        return

    print("NATIVE SAVE TEST PASS: two writes, versioned readback and corrupted-primary backup recovery")
    quit(0)
