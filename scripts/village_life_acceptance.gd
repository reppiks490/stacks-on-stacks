extends SceneTree
## Native Godot behavioral acceptance: authored NPC routines, work, memory, festivals.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("VILLAGE LIFE ACCEPTANCE FAILED: " + label)

func _run() -> void:
    var host = load("res://scripts/village_life_test_host.gd").new()
    root.add_child(host)
    var village = load("res://scripts/village.gd").new()
    root.add_child(village)
    village.setup(host)
    _check(village.residents.size() == 6, "six resident actors loaded")
    _check(village.life_data.get("schema_version", 0) == 1, "authored routine schema")
    _check(village.life_data.get("festivals", []).size() == 4, "four authored festivals")
    var mira: Dictionary = village.residents[0]
    var rid: String = str(mira["id"])
    _check(rid == "mira", "canonical resident order")
    _check(str(mira["place"]) == "home", "at home before dawn")
    var home: Vector3 = mira["node"].global_position
    _check(home.distance_to(Vector3(27, 0, 9)) < 0.01, "original home retained")

    host.minute_of_day = 600.0
    village.sync_schedule(true)
    var workplace: Vector3 = mira["node"].global_position
    _check(str(mira["place"]) == "herbal_garden", "Mira works in garden at ten")
    _check(workplace.distance_to(Vector3(26, 0, 11)) < 0.01, "real worksite position")
    var gold_before: int = host.gold
    var energy_before: float = host.energy
    _check("Earned 24 petals" in village.act("job", workplace), "first civic shift completes")
    _check(host.gold == gold_before + 24, "one shift pays 24 petals")
    _check(is_equal_approx(host.energy, energy_before - 12.0), "one shift spends 12 energy")
    _check(int(village.memories[rid]["jobs"]) == 1, "job remembered")
    _check("already helped" in village.act("job", workplace), "repeat shift denied")
    _check(host.gold == gold_before + 24, "repeat shift does not mint currency")
    _check(is_equal_approx(host.energy, energy_before - 12.0), "repeat shift spends no energy")

    host.inventory["wild_herb"] = 0
    var flower_before: int = int(host.inventory["bluebell"])
    _check("treasured favorite" in village.act("gift", workplace).to_lower(), "favorite flower reaction")
    _check(int(village.affection[rid]) == 18, "favorite gives 18 friendship")
    _check(int(host.inventory["bluebell"]) == flower_before - 1, "one flower consumed")
    _check(str(village.memories[rid]["last_gift_item"]) == "bluebell", "specific gift memory")
    _check(int(village.memories[rid]["gifts"]) == 1, "gift count recorded")
    _check("One gift each day" in village.act("gift", workplace), "second gift denied")
    _check(int(host.inventory["bluebell"]) == flower_before - 1, "no gift duplication")
    _check("Mira:" in village.act("talk", workplace), "work-context conversation")
    _check(int(village.affection[rid]) == 22, "first talk gives four friendship")
    _check("Mira:" in village.act("talk", workplace), "same-day dialogue remains available")
    _check(int(village.affection[rid]) == 22, "repeat talk gives no extra friendship")

    var saved: Variant = JSON.parse_string(JSON.stringify(village.save_state()))
    _check(saved is Dictionary, "JSON save roundtrip")
    var reloaded = load("res://scripts/village.gd").new()
    root.add_child(reloaded)
    reloaded.setup(host)
    if saved is Dictionary:
        reloaded.load_state(saved)
    _check(int(reloaded.affection[rid]) == 22, "friendship restored")
    _check(int(reloaded.memories[rid]["jobs"]) == 1, "job memory restored")
    _check(int(reloaded.memories[rid]["gifts"]) == 1, "gift memory restored")
    _check("already helped" in reloaded.act("job", workplace), "save reload cannot repeat paid job")
    _check("One gift each day" in reloaded.act("gift", workplace), "save reload cannot repeat gift")
    _check(host.gold == gold_before + 24, "no reload currency duplication")

    # A fresh calendar day isolates lunch admission from yesterday's paid shift cap.
    host.day = 2
    host.minute_of_day = 750.0
    reloaded.sync_schedule(true)
    _check(str(reloaded.residents[0]["place"]) == "village_square", "midday break at square")
    _check("no work shift" in reloaded.act("job", reloaded.residents[0]["node"].global_position), "no lunch-time shift")
    host.minute_of_day = 1020.0
    host.weather = "Rain"
    reloaded.sync_schedule(true)
    _check(str(reloaded.residents[0]["place"]) == "covered_market", "rain shelter at dusk")
    host.weather = "Clear"
    host.day = 3
    host.minute_of_day = 600.0
    reloaded.sync_schedule(true)
    _check(str(reloaded.residents[0]["place"]) == "orchard_edge", "individual weekday rest")
    _check("no work shift" in reloaded.act("job", reloaded.residents[0]["node"].global_position), "rest day has no paid shift")

    host.day = 7
    host.minute_of_day = 1100.0
    reloaded.sync_schedule(true)
    var square: Vector3 = Vector3(31, 0, 4)
    for resident in reloaded.residents:
        _check(str(resident["place"]) == "village_square", "festival gathers resident")
        _check(resident["node"].global_position.distance_to(square) < 0.01, "festival uses authored square")
    var before_festival: int = host.restoration
    _check("Seed Lantern Walk" in reloaded.act("talk", square), "original spring festival joined")
    _check(host.restoration == before_festival + 4, "talk plus one-time civic celebration reward")
    _check(int(reloaded.memories[rid]["festivals"]) == 1, "festival memory persists")
    _check("Seed Lantern Walk" not in reloaded.act("talk", square), "no duplicate festival ceremony")
    _check(host.restoration == before_festival + 4, "no festival restoration duplication")
    _check(reloaded.festival_visits.has("1:seed_lantern_walk"), "year-specific festival ledger")

    host.year = 2
    host.day = 7
    reloaded.sync_schedule(true)
    _check("Seed Lantern Walk" in reloaded.act("talk", square), "festival repeats in next year")
    _check(reloaded.festival_visits.has("2:seed_lantern_walk"), "new-year festival identity")
    _check(int(reloaded.memories[rid]["festivals"]) == 2, "year-two celebration remembered")
    var festival_saved: Variant = JSON.parse_string(JSON.stringify(reloaded.save_state()))
    var third = load("res://scripts/village.gd").new()
    root.add_child(third)
    third.setup(host)
    if festival_saved is Dictionary:
        third.load_state(festival_saved)
    var after_reload: int = host.restoration
    _check("Seed Lantern Walk" not in third.act("talk", square), "reload cannot re-award festival")
    _check(host.restoration == after_reload, "reload festival reward conserved")

    host.season_index = 3
    host.day = 2
    host.minute_of_day = 1020.0
    third.sync_schedule(true)
    var winter: String = third.act("talk", third.residents[0]["node"].global_position)
    _check("windowsill garden" in winter, "original winter seasonal dialogue")
    _check("acquaintance" in winter, "friendship tier surfaced in dialogue")

    # Every resident follows a defined deterministic place across an entire year.
    host.year = 3
    host.season_index = 0
    host.day = 1
    for i in range(56):
        for hour in [360, 600, 750, 1020, 1100]:
            host.minute_of_day = float(hour)
            third.sync_schedule(true)
            for resident in third.residents:
                var place: String = str(resident["place"])
                var point: Vector3 = resident["node"].global_position
                _check(place == "home" or third.life_data["places"].has(place), "known destination")
                _check(point.distance_to(third._place_position(resident, place)) < 0.01, "deterministic placement")
        host.advance_day()
    _check(host.year == 4 and host.day == 1, "full-year calendar rollover")
    _check(host.gold >= 0 and host.energy >= 0.0, "economy conserved")
    print("EVERBLOOM VILLAGE LIFE NATIVE ACCEPTANCE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
