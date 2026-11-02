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
    host.minute_of_day = 600.0
    reloaded.sync_schedule(true)
    var recollection_spot: Vector3 = reloaded.residents[0]["node"].global_position
    var remembered_line: String = reloaded.act("talk", recollection_spot)
    _check("herb journal" in remembered_line and "bluebell" in remembered_line, "authored favorite-gift recollection on later day")
    _check(int(reloaded.memories[rid]["recalled_gift_epoch"]) == 1, "recollection keyed to original monotonic gift epoch")
    _check(int(reloaded.memories[rid]["gift_recollections"]) == 1, "one personal recollection counted")
    _check("herb journal" not in reloaded.act("talk", recollection_spot), "same-day repeat dialogue cannot repeat gift memory")
    var recollection_save: Variant = JSON.parse_string(JSON.stringify(reloaded.save_state()))
    if recollection_save is Dictionary:
        reloaded.load_state(recollection_save)
    _check(int(reloaded.memories[rid]["gift_recollections"]) == 1, "recollection counter survives JSON reload")
    _check("herb journal" not in reloaded.act("talk", recollection_spot), "reloaded memory cannot repeat recollection")
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

    # A gift on the last day of year four must be remembered in year five.
    host.year = 4
    host.season_index = 3
    host.day = 14
    host.minute_of_day = 600.0
    third.sync_schedule(true)
    var rowan_spot: Vector3 = third.residents[1]["node"].global_position
    var wood_before: int = int(host.inventory["wood"])
    _check("treasured favorite" in third.act("gift", rowan_spot).to_lower(), "year-end favorite gift given")
    _check(int(host.inventory["wood"]) == wood_before - 1, "year-end gift conserves inventory")
    var year_end_save: Variant = JSON.parse_string(JSON.stringify(third.save_state()))
    var fourth = load("res://scripts/village.gd").new()
    root.add_child(fourth)
    fourth.setup(host)
    if year_end_save is Dictionary:
        fourth.load_state(year_end_save)
    host.year = 5
    host.season_index = 0
    host.day = 1
    fourth.sync_schedule(true)
    var rowan_new_spot: Vector3 = fourth.residents[1]["node"].global_position
    var year_five_line: String = fourth.act("talk", rowan_new_spot)
    _check("wood" in year_five_line and "lovely grain" in year_five_line, "gift memory crosses year boundary")
    _check(int(fourth.memories["rowan"]["recalled_gift_epoch"]) == 224, "recollection uses absolute day 224")
    _check(int(fourth.memories["rowan"]["gift_recollections"]) == 1, "year-spanning memory recalled once")
    _check("lovely grain" not in fourth.act("talk", rowan_new_spot), "no duplicate year-spanning recollection")
    _check(int(host.inventory["wood"]) == wood_before - 1, "memory dialogue does not consume another gift")

    # Older schema-1 memory records lack the new keys; infer favorite safely.
    if year_end_save is Dictionary:
        var legacy_save: Dictionary = year_end_save.duplicate(true)
        var legacy_rowan: Dictionary = legacy_save["memories"]["rowan"]
        legacy_rowan.erase("last_gift_favorite")
        legacy_rowan.erase("recalled_gift_epoch")
        legacy_rowan.erase("gift_recollections")
        var legacy = load("res://scripts/village.gd").new()
        root.add_child(legacy)
        legacy.setup(host)
        legacy.load_state(legacy_save)
        _check(legacy.memories["rowan"]["last_gift_favorite"] == true, "legacy favorite inferred from original catalog")
        legacy.sync_schedule(true)
        _check("lovely grain" in legacy.act("talk", legacy.residents[1]["node"].global_position), "legacy gift history remains narratively reachable")

    # A preferred (non-favorite) gift has its own authored later-day reaction.
    host.day = 2
    host.inventory["wild_herb"] = 0
    host.inventory["bluebell"] = 4
    fourth.sync_schedule(true)
    var soren_spot: Vector3 = fourth.residents[5]["node"].global_position
    _check("thoughtful choice" in fourth.act("gift", soren_spot).to_lower(), "non-favorite preferred gift accepted")
    _check(fourth.memories["soren"]["last_gift_favorite"] == false, "non-favorite intent saved")
    host.day = 3
    fourth.sync_schedule(true)
    _check("archive shelves" in fourth.act("talk", fourth.residents[5]["node"].global_position), "distinct preferred-gift memory voiced")
    _check(int(fourth.memories["soren"]["gift_recollections"]) == 1, "preferred gift recollection once")

    # V05: player-earned shifts unlock deterministic authored dialogue branches.
    # Separate fixture preserves existing festival, gift and multiyear assertions.
    var dialogue_host = load("res://scripts/village_life_test_host.gd").new()
    root.add_child(dialogue_host)
    dialogue_host.minute_of_day = 600.0
    var dialogue_village = load("res://scripts/village.gd").new()
    root.add_child(dialogue_village)
    dialogue_village.setup(dialogue_host)
    var dialogue_spot: Vector3 = dialogue_village.residents[0]["node"].global_position
    _check("Sorting seedlings" in dialogue_village.act("talk", dialogue_spot), "no shift keeps legacy work dialogue")
    _check("Earned 24 petals" in dialogue_village.act("job", dialogue_spot), "V05 prerequisite earned by real job verb")
    _check("young mint" in dialogue_village.act("talk", dialogue_spot), "first-shift branch reachable via existing talk")
    var dialogue_affection: int = int(dialogue_village.affection["mira"])
    var dialogue_gold: int = dialogue_host.gold
    dialogue_village.set_dialogue_locale("es")
    _check("menta joven" in dialogue_village.act("talk", dialogue_spot), "first-shift Spanish localized text")
    _check(int(dialogue_village.affection["mira"]) == dialogue_affection and dialogue_host.gold == dialogue_gold, "locale replay cannot award social or currency")
    dialogue_village.set_dialogue_locale("fr")
    _check("young mint" in dialogue_village.act("talk", dialogue_spot), "unsupported locale falls back to English")
    for next_day_number in range(2, 6):
        dialogue_host.day = next_day_number
        dialogue_village.sync_schedule(true)
        dialogue_spot = dialogue_village.residents[0]["node"].global_position
        _check("treasured favorite" in dialogue_village.act("gift", dialogue_spot).to_lower(), "earned friendship by actual gift verb")
        dialogue_village.act("talk", dialogue_spot)
    _check(int(dialogue_village.affection["mira"]) >= 80, "trusted dialogue threshold earned through play")
    _check("quiet place" in dialogue_village.act("talk", dialogue_spot), "trusted colleague branch outranks first-shift")
    dialogue_village.set_dialogue_locale("es")
    _check("rincón tranquilo" in dialogue_village.act("talk", dialogue_spot), "trusted branch has Spanish translation")
    var dialogue_saved: Variant = JSON.parse_string(JSON.stringify(dialogue_village.save_state()))
    var dialogue_reload = load("res://scripts/village.gd").new()
    root.add_child(dialogue_reload)
    dialogue_reload.setup(dialogue_host)
    if dialogue_saved is Dictionary:
        dialogue_reload.load_state(dialogue_saved)
    dialogue_reload.set_dialogue_locale("es")
    _check("rincón tranquilo" in dialogue_reload.act("talk", dialogue_reload.residents[0]["node"].global_position), "earned branch survives save/load")
    _check(dialogue_reload.save_state() == dialogue_village.save_state(), "localized branch has no extra persisted side effects")
    _check(dialogue_host.gold == dialogue_gold, "dialogue branching cannot mint currency")
    for dialogue_resident in dialogue_reload.residents:
        var dialogue_id: String = str(dialogue_resident["id"])
        var rows: Array = dialogue_reload.life_data["dialogue_branches"].get(dialogue_id, [])
        _check(rows.size() == 2, "two authored branches per resident")
        for row in rows:
            _check(not str(row["text"]["en"]).is_empty() and not str(row["text"]["es"]).is_empty(), "both languages authored for each branch")
        dialogue_reload.memories[dialogue_id]["jobs"] = 1
        dialogue_reload.affection[dialogue_id] = 80
        # Test at a genuine scheduled work time, not this resident's rest day.
        dialogue_host.day = 2 if int(dialogue_reload._profile(dialogue_id).get("rest_day", -1)) == 0 else 1
        dialogue_host.minute_of_day = 600.0
        dialogue_reload.sync_schedule(true)
        var dialogue_line: String = dialogue_reload._conditional_dialogue(dialogue_resident, dialogue_reload._profile(dialogue_id), dialogue_id)
        _check(dialogue_line == str(rows[0]["text"]["es"]), "high branch reachable for every resident")
        dialogue_reload.affection[dialogue_id] = 0
        _check(dialogue_reload._conditional_dialogue(dialogue_resident, dialogue_reload._profile(dialogue_id), dialogue_id) == str(rows[1]["text"]["es"]), "low branch reachable for every resident")
        dialogue_reload.memories[dialogue_id]["jobs"] = 0
        _check(dialogue_reload._conditional_dialogue(dialogue_resident, dialogue_reload._profile(dialogue_id), dialogue_id).is_empty(), "unearned branch never leaks")
    dialogue_reload.queue_free()
    dialogue_village.queue_free()
    dialogue_host.queue_free()

    print("EVERBLOOM VILLAGE LIFE NATIVE ACCEPTANCE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
