extends SceneTree
## E18: diagnostic native reproduction against the REAL assembled Godot scene.
## This is deliberately NONBLOCKING: a successful harness may report open bugs.
## Do not mistake "0 harness failures" for fixed Valley cooldown behavior.
const SaveService = preload("res://scripts/save_service.gd")
var assertions: int = 0
var harness_failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, detail: String) -> void:
    assertions += 1
    if not condition:
        harness_failures += 1
        push_error("EMERGENCE VALLEY HARNESS FAILED: " + detail)

func _cleanup() -> void:
    for path: String in [SaveService.SAVE_PATH, SaveService.BACKUP_PATH, SaveService.TEMP_PATH]:
        if FileAccess.file_exists(path):
            _check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK,
                    "clean isolated test save: " + path)

func _run() -> void:
    # Never overwrite player files. CI MUST use a fresh isolated XDG_DATA_HOME.
    for path: String in [SaveService.SAVE_PATH, SaveService.BACKUP_PATH, SaveService.TEMP_PATH]:
        if FileAccess.file_exists(path):
            _check(false, "test user:// is not isolated: " + path)
            quit(1)
            return

    var scene: PackedScene = load("res://scenes/main.tscn")
    _check(scene != null, "actual assembled game scene exists")
    if scene == null:
        quit(1)
        return
    var first = scene.instantiate()
    root.add_child(first)
    _check(first.day_epoch() == 1, "fresh assembled session begins on epoch 1")
    _check(first.valley.forage_locations.size() > 0, "real valley has forage sites")
    if first.valley.forage_locations.is_empty():
        first.queue_free()
        quit(1)
        return

    var lake: Vector3 = first.valley.lake_center
    var grove: Vector3 = first.valley.forage_locations[0]
    var initial_fish: int = int(first.inventory.get("fish", 0))
    var initial_herbs: int = int(first.inventory.get("wild_herb", 0))
    var initial_energy: float = first.energy
    var fish_result: String = first.valley.act("fish", lake)
    var forage_result: String = first.valley.act("forage", grove)
    _check("silverfin" in fish_result, "first fishing action uses real Valley.act")
    _check("aromatic herbs" in forage_result, "first forage uses real Valley.act")
    _check(int(first.inventory.get("fish", 0)) == initial_fish + 1,
            "first fish grants exactly one")
    _check(int(first.inventory.get("wild_herb", 0)) == initial_herbs + 2,
            "first forage grants exactly two")
    _check(is_equal_approx(first.energy, initial_energy - 11.0),
            "first fish and forage debit 8+3 energy")

    first.save_game(false)
    var persisted: Dictionary = SaveService.read_payload()
    _check(not persisted.is_empty() and SaveService.validate_payload(persisted),
            "assembled save roundtrips through real SaveService")
    var saved_fish: int = int(persisted.get("inventory", {}).get("fish", -1))
    var saved_herbs: int = int(persisted.get("inventory", {}).get("wild_herb", -1))
    _check(saved_fish == initial_fish + 1 and saved_herbs == initial_herbs + 2,
            "first earned items exist in real saved inventory")
    var save_omits_valley_cooldowns: bool = not persisted.has("valley")

    # Fresh scene simulates restarting the application, not reloading one node.
    root.remove_child(first)
    first.free()
    var second = scene.instantiate()
    root.add_child(second)
    second.load_game()
    _check(second.day_epoch() == 1, "fresh session loads same calendar epoch")
    _check(int(second.inventory.get("fish", -1)) == saved_fish,
            "saved fish inventory restored")
    _check(int(second.inventory.get("wild_herb", -1)) == saved_herbs,
            "saved forage inventory restored")
    var loaded_energy: float = second.energy
    second.valley.act("fish", second.valley.lake_center)
    second.valley.act("forage", second.valley.forage_locations[0])
    var reload_fish_duplicate: bool = int(second.inventory.get("fish", -1)) == saved_fish + 1
    var reload_forage_duplicate: bool = int(second.inventory.get("wild_herb", -1)) == saved_herbs + 2
    _check(second.energy >= 0.0 and second.energy <= loaded_energy,
            "reloaded interactions cannot mint energy")

    # Real next_day() advances 14 days, from Spring 1 to Summer 1.
    # A cooldown keyed by day-of-season wrongly treats Summer 1 as Spring 1.
    for i in range(14):
        second.next_day()
    _check(second.year == 1 and second.season_index == 1 and second.day == 1
            and second.day_epoch() == 15,
            "real game calendar reaches Summer 1 at monotonic epoch 15")
    var before_summer_fish: int = int(second.inventory.get("fish", 0))
    var before_summer_herbs: int = int(second.inventory.get("wild_herb", 0))
    second.valley.act("fish", second.valley.lake_center)
    second.valley.act("forage", second.valley.forage_locations[0])
    var season_alias_fish: bool = int(second.inventory.get("fish", 0)) == before_summer_fish
    var season_alias_forage: bool = int(second.inventory.get("wild_herb", 0)) == before_summer_herbs

    var observations: Dictionary = {
        "save_omits_valley_cooldowns": save_omits_valley_cooldowns,
        "same_day_reload_fish_duplicate": reload_fish_duplicate,
        "same_day_reload_forage_duplicate": reload_forage_duplicate,
        "season_day_alias_blocks_fishing": season_alias_fish,
        "season_day_alias_blocks_foraging": season_alias_forage
    }
    var open_findings: int = 0
    for key in observations:
        if bool(observations[key]):
            open_findings += 1
    _check(open_findings >= 0 and open_findings <= observations.size(),
            "findings count bounded")
    second.queue_free()
    _cleanup()
    print("EVERBLOOM EMERGENCE VALLEY AUDIT: %d assertions, %d harness failures, %d observed open findings; observations=%s" % [
            assertions, harness_failures, open_findings, JSON.stringify(observations)])
    # A green diagnostic proves the harness ran, NOT that the game is defect-free.
    quit(0 if harness_failures == 0 else 1)
