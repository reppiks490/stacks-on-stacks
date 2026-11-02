extends SceneTree
## V02/V07/V20 native acceptance: two full 56-day years and actual commute gating.
## This uses the real Village domain and authored catalog; it does not fake a job.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("V02 COMMUTE ACCEPTANCE FAILED: " + label)

func _run() -> void:
    var host = load("res://scripts/village_life_test_host.gd").new()
    root.add_child(host)
    var village = load("res://scripts/village.gd").new()
    root.add_child(village)
    village.setup(host)
    _check(village.residents.size() == 6, "six real residents loaded")
    var places: Dictionary = village.life_data.get("places", {})
    var minutes: Array = [360, 480, 600, 750, 900, 1020, 1110, 1300]
    var unique_ids: Dictionary = {}
    for resident in village.residents:
        var rid: String = str(resident["id"])
        _check(not unique_ids.has(rid), "unique persistent resident ID " + rid)
        unique_ids[rid] = true
        var profile: Dictionary = village._profile(rid)
        for key in ["workplace", "leisure", "rain_shelter"]:
            _check(places.has(str(profile.get(key, ""))), "known destination for " + rid + " " + key)
        var home: Vector3 = village._place_position(resident, "home")
        var workplace: Vector3 = village._place_position(resident, str(profile["workplace"]))
        _check(home.distance_to(workplace) <= 40.0, "bounded commute distance for " + rid)

    # 112 days, 8 daily instants, clear/rain alternation: one deterministic
    # destination per resident, all authored destinations physically reachable.
    for epoch in range(1, 113):
        host.year = 1 + int((epoch - 1) / 56)
        var within_year: int = (epoch - 1) % 56
        host.season_index = int(within_year / 14)
        host.day = (within_year % 14) + 1
        _check(host.day_epoch() == epoch, "monotonic epoch " + str(epoch))
        host.weather = "Rain" if epoch % 5 == 0 else "Clear"
        for minute in minutes:
            host.minute_of_day = float(minute)
            village.sync_schedule(true)
            for resident in village.residents:
                var rid: String = str(resident["id"])
                var target: String = village._place_for(resident)
                var place: String = str(resident["place"])
                _check(place == target, "single deterministic schedule destination " + rid)
                _check(place == "home" or places.has(place), "known schedule destination " + rid)
                _check(resident["node"].position.distance_to(village._place_position(resident, place)) < 0.01,
                    "authored destination coordinate reached " + rid)
                var profile: Dictionary = village._profile(rid)
                if village._is_rest_day(profile) and minute >= 540 and minute < 960:
                    _check(place != str(profile["workplace"]) or str(profile["workplace"]) == str(profile.get("leisure", "")),
                        "rest-day schedule excludes ordinary shift " + rid)

    # Reproduce real defect: destination label flips before the actor arrives.
    host.year = 1
    host.season_index = 0
    host.day = 1
    host.weather = "Clear"
    host.minute_of_day = 360.0
    village.sync_schedule(true)
    var mira: Dictionary = village.residents[0]
    var start: Vector3 = mira["node"].global_position
    host.minute_of_day = 600.0
    village.sync_schedule(false, 0.01)
    var midway: Vector3 = mira["node"].global_position
    var destination: Vector3 = village.to_global(village._place_position(mira, "herbal_garden"))
    _check(str(mira["place"]) == "herbal_garden", "work destination label assigned before arrival")
    _check(midway.distance_to(start) < 0.1 and midway.distance_to(destination) > 1.0,
        "resident is physically still commuting")
    var gold_before: int = host.gold
    var energy_before: float = host.energy
    var restoration_before: int = host.restoration
    var before: Dictionary = village.save_state()
    var rejected: String = village.act("job", midway)
    _check("still on their way" in rejected, "player receives actionable commute feedback")
    _check(host.gold == gold_before and is_equal_approx(host.energy, energy_before)
        and host.restoration == restoration_before, "commute rejection conserves economy")
    _check(village.save_state() == before, "commute rejection preserves social save state")

    village.sync_schedule(false, 0.2)
    _check(mira["node"].global_position.distance_to(destination) > 1.0,
        "partial commute remains outside work admission radius")
    _check("still on their way" in village.act("job", mira["node"].global_position),
        "partial commute cannot mint payment")
    village.sync_schedule(false, 5.0)
    _check(mira["node"].global_position.distance_to(destination) < 0.01,
        "commuter eventually reaches workplace")
    _check("Earned 24 petals" in village.act("job", mira["node"].global_position),
        "real arrival admits the original paid shift")
    _check(host.gold == gold_before + 24 and is_equal_approx(host.energy, energy_before - 12.0),
        "arrival charges exactly one energy debit and payment")
    _check("already helped" in village.act("job", mira["node"].global_position),
        "same-day repeated shift denied")
    _check(host.gold == gold_before + 24, "no repeated payment")

    var saved: Variant = JSON.parse_string(JSON.stringify(village.save_state()))
    _check(saved is Dictionary, "full social JSON roundtrip")
    var copy = load("res://scripts/village.gd").new()
    root.add_child(copy)
    copy.setup(host)
    if saved is Dictionary:
        copy.load_state(saved)
    _check(copy.save_state() == village.save_state(), "nested Village state preserved exactly")
    _check("already helped" in copy.act("job", copy.residents[0]["node"].global_position),
        "reload cannot repay same shift")
    _check(host.gold == gold_before + 24, "reload conserves petals")

    # Same season/day in the next 56-day year must be a distinct work epoch.
    host.year = 2
    host.season_index = 0
    host.day = 1
    host.minute_of_day = 360.0
    host.energy = 100.0
    copy.sync_schedule(true)
    host.minute_of_day = 600.0
    copy.sync_schedule(false, 0.01)
    _check("still on their way" in copy.act("job", copy.residents[0]["node"].global_position),
        "year-two commute still blocks premature payment")
    copy.sync_schedule(false, 5.0)
    _check("Earned 24 petals" in copy.act("job", copy.residents[0]["node"].global_position),
        "year-two arrived worker can complete a new legitimate shift")
    _check(host.gold == gold_before + 48, "two annual shifts total exactly 48 petals")
    _check(int(copy.last_job.get("mira", -1)) == 57, "work ledger records monotonic year-two epoch")
    var year_two_state: Variant = JSON.parse_string(JSON.stringify(copy.save_state()))
    _check(year_two_state is Dictionary and year_two_state == copy.save_state(),
        "year-two social JSON replay stable")

    # Schedule gating still wins even if the worker has reached the lunch location.
    host.day = 2
    host.minute_of_day = 750.0
    copy.sync_schedule(true)
    var lunch_spot: Vector3 = copy.residents[0]["node"].global_position
    var lunch_gold: int = host.gold
    _check("no work shift" in copy.act("job", lunch_spot), "lunch rejects employment")
    _check(host.gold == lunch_gold, "lunch cannot mint petals")
    print("EVERBLOOM V02 COMMUTE NATIVE ACCEPTANCE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
