extends SceneTree
## QA-owned actual main-scene multi-year integration. Disposable CI user:// only.
## Calls gameplay methods, not physical keyboard/controller/touch or rendered play.
const SaveService = preload("res://scripts/save_service.gd")
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, detail: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("QA MULTIYEAR FAILED: " + detail)

func _run() -> void:
    # Fail closed rather than destroy an existing local player's saves.
    for path: String in [SaveService.SAVE_PATH, SaveService.BACKUP_PATH, SaveService.TEMP_PATH]:
        if FileAccess.file_exists(path):
            _check(false, "test user:// is not isolated: " + path)
            quit(1)
            return

    var scene: PackedScene = load("res://scenes/main.tscn")
    _check(scene != null, "actual game scene can load")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    _check(game.day_epoch() == 1, "initial calendar epoch")
    _check(game.festivals.entries.size() == 12, "twelve original contribution festivals")
    var festival_awards: int = 0

    # 112 real Game.next_day() calls, including every season and two year rollovers.
    # The real coordinator automatically writes the assembled farm/village/animal/
    # festival save each day; this is not a detached mock calendar.
    for elapsed in range(1, 113):
        game.next_day()
        var expected_year: int = 1 + int(elapsed / 56)
        var expected_season: int = int((elapsed % 56) / 14)
        var expected_day: int = (elapsed % 14) + 1
        _check(game.day_epoch() == elapsed + 1, "epoch at elapsed day %d" % elapsed)
        _check(game.year == expected_year and game.season_index == expected_season
                and game.day == expected_day, "calendar at elapsed day %d" % elapsed)
        var persisted: Dictionary = SaveService.read_payload()
        _check(not persisted.is_empty(), "automatic save at elapsed day %d" % elapsed)
        _check(SaveService.validate_payload(persisted),
                "full-game payload valid at elapsed day %d" % elapsed)
        _check(int(persisted.get("year", -1)) == expected_year
                and int(persisted.get("day", -1)) == expected_day
                and int(persisted.get("season", -1)) == expected_season,
                "saved calendar at elapsed day %d" % elapsed)
        var paddocks: Variant = persisted.get("animals", {}).get("__paddocks__", [])
        _check(paddocks is Array and paddocks.size() == 3,
                "three persisted pasture records at elapsed day %d" % elapsed)
        _check(persisted.get("farm", []).size() == 30,
                "all thirty beds persisted at elapsed day %d" % elapsed)
        _check(persisted.get("village", {}).has("memories"),
                "social memory persisted at elapsed day %d" % elapsed)
        if game.season_index == 0 and game.day == 3 and game.year <= 2:
            game.minute_of_day = 600.0
            game.hero.global_position = Vector3(30.0, 1.0, 0.0)
            game.inventory["turnip_seed"] = 2
            var gold_before: int = game.gold
            var answer: String = game.festivals.act(Vector3(30.0, 0.0, 0.0))
            _check("Thank you" in answer, "year %d festival admission" % game.year)
            _check(game.gold == gold_before + 26, "exact year %d reward" % game.year)
            _check(int(game.inventory["turnip_seed"]) == 0,
                    "year %d offering consumed exactly" % game.year)
            _check("already contributed" in game.festivals.act(Vector3(30.0, 0.0, 0.0)),
                    "year %d same-day duplicate denied" % game.year)
            festival_awards += 1
            game.save_game(false)
            _check(SaveService.read_payload().get("festivals", {}).get("awarded", []).size()
                    == festival_awards, "festival ledger persisted year %d" % game.year)

    _check(festival_awards == 2, "independent awards in years one and two")
    _check(game.year == 3 and game.season_index == 0 and game.day == 1,
            "112 days end on Spring 1 of year three")
    var primary: Dictionary = SaveService.read_payload()
    var previous: Dictionary = SaveService._read_one(SaveService.BACKUP_PATH)
    _check(int(primary.get("year", -1)) == 3, "latest primary is year three")
    _check(int(previous.get("year", -1)) == 2
            and int(previous.get("season", -1)) == 3
            and int(previous.get("day", -1)) == 14,
            "backup is the preceding Winter 14, not a stale year")
    _check(previous.get("festivals", {}).get("awarded", []).size() == 2,
            "prior-day backup retains both original festival grants")

    # Real assembled-session reload restores domain data and calendar.
    game.year = 1
    game.gold = 9999
    game.inventory["turnip_seed"] = 99
    game.animals.paddocks[0]["forage"] = 0
    game.festivals.awarded.clear()
    game.load_game()
    _check(game.year == 3 and game.day_epoch() == 113, "latest calendar restored")
    _check(game.gold == int(primary.get("gold", -1)), "currency restored")
    _check(int(game.inventory.get("turnip_seed", -1))
            == int(primary.get("inventory", {}).get("turnip_seed", -1)),
            "inventory restored")
    var expected_paddocks: Array = primary.get("animals", {}).get("__paddocks__", [])
    var paddocks_match: bool = game.animals.paddocks.size() == expected_paddocks.size()
    if paddocks_match:
        for index in range(expected_paddocks.size()):
            if int(game.animals.paddocks[index].get("forage", -1)) != int(
                    expected_paddocks[index].get("forage", -2)):
                paddocks_match = false
    _check(paddocks_match, "all three paddocks restored; actual=%s expected=%s" % [
            str(game.animals.paddocks), str(expected_paddocks)])
    _check(game.festivals.awarded.size() == 2, "festival entitlements restored")

    # Simulate an interrupted temp write and corrupted primary, without touching
    # source or external files. Recovery must choose last valid backup, not temp.
    var temporary: FileAccess = FileAccess.open(SaveService.TEMP_PATH, FileAccess.WRITE)
    _check(temporary != null, "create interrupted temporary save")
    if temporary != null:
        temporary.store_string("{partial")
        temporary.close()
    var damaged: FileAccess = FileAccess.open(SaveService.SAVE_PATH, FileAccess.WRITE)
    _check(damaged != null, "simulate primary corruption")
    if damaged != null:
        damaged.store_string("{invalid-json")
        damaged.close()
    var recovered: Dictionary = SaveService.read_payload()
    _check(int(recovered.get("year", -1)) == 2
            and int(recovered.get("season", -1)) == 3
            and int(recovered.get("day", -1)) == 14,
            "backup wins over corrupt primary and incomplete temp")
    game.load_game()
    _check(game.year == 2 and game.season_index == 3 and game.day == 14,
            "actual game loads prior valid day after corruption")
    _check(game.festivals.awarded.size() == 2,
            "recovery cannot re-award previously earned festival rewards")

    # Cleanup only the three files created inside the isolated CI user-data root.
    for path: String in [SaveService.SAVE_PATH, SaveService.BACKUP_PATH, SaveService.TEMP_PATH]:
        if FileAccess.file_exists(path):
            _check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK,
                    "clean up isolated test artifact: " + path)
    print("EVERBLOOM QA MULTIYEAR NATIVE: %d assertions, %d failures" % [
          assertions, failures])
    quit(0 if failures == 0 else 1)
