extends SceneTree
## F03 native two-year crop physiology acceptance, including negative controls.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("F03 PHENOLOGY FAILED: " + message)

func _new_model():
    return load("res://scripts/farm_phenology.gd").new()

func _moisture(drought_bed: int = 3) -> Array:
    var values: Array = []
    for i in range(30):
        values.append(0 if i == drought_bed else 75)
    return values

func _temperature(epoch: int) -> int:
    var season: int = int(((epoch - 1) % 56) / 14)
    if season == 0:
        return 180
    if season == 1:
        return 240
    if season == 2:
        return 160
    return 20

func _run() -> void:
    var model = _new_model()
    var replay = _new_model()
    _check(model.save_state() == replay.save_state(), "identical initial state")
    _check(model.save_state()["beds"].size() == 30, "thirty beds retained")
    _check(not model.plant(0, "turnip", 1)["ok"], "no planting before first calendar day")
    _check(not model.advance_day(2, 180, _moisture())["ok"], "no skipped day")
    _check(not model.advance_day(1, 180, [75])["ok"], "reject incomplete moisture")
    var bad_moisture: Array = _moisture()
    bad_moisture[0] = "infinite"
    _check(not model.advance_day(1, 180, bad_moisture)["ok"], "reject forged moisture type")
    _check(model.save_state() == replay.save_state(), "rejections are atomic")

    for epoch in range(1, 113):
        var moisture: Array = _moisture()
        var temp: int = _temperature(epoch)
        var result_a: Dictionary = model.advance_day(epoch, temp, moisture)
        var result_b: Dictionary = replay.advance_day(epoch, temp, moisture)
        _check(bool(result_a.get("ok", false)) and bool(result_b.get("ok", false)),
            "monotonic daily step %d" % epoch)
        _check(model.save_state() == replay.save_state(), "deterministic replay %d" % epoch)
        var before_duplicate: Dictionary = model.save_state()
        _check(not model.advance_day(epoch, temp, moisture)["ok"], "duplicate epoch denied %d" % epoch)
        _check(model.save_state() == before_duplicate, "duplicate day atomic %d" % epoch)

        if epoch == 1:
            for crop_and_bed in [["turnip", 0], ["strawberry", 1], ["carrot", 3]]:
                var crop_id: String = crop_and_bed[0]
                var bed_index: int = crop_and_bed[1]
                var planted_a: Dictionary = model.plant(bed_index, crop_id, epoch)
                var planted_b: Dictionary = replay.plant(bed_index, crop_id, epoch)
                _check(bool(planted_a.get("ok", false)) and planted_a == planted_b,
                    "plant %s once" % crop_id)
            _check(not model.plant(0, "turnip", epoch)["ok"], "no duplicate seed action")
            _check(not model.plant(4, "melon", epoch)["ok"], "summer-only melon rejected in spring")
        if epoch == 5:
            _check(model.status(0)["stage"] == "mature", "turnip reached harvestable stage")
            var harvested_a: Dictionary = model.harvest(0, epoch)
            var harvested_b: Dictionary = replay.harvest(0, epoch)
            _check(bool(harvested_a.get("ok", false)) and harvested_a == harvested_b,
                "deterministic turnip harvest receipt")
            _check(int(harvested_a.get("units", 0)) == 2, "original turnip yield contract")
            _check(not model.harvest(0, epoch)["ok"], "no duplicate turnip harvest")
        if epoch == 8:
            _check(model.status(1)["stage"] == "mature", "strawberry maturity by thermal units")
            var berry_a: Dictionary = model.harvest(1, epoch)
            var berry_b: Dictionary = replay.harvest(1, epoch)
            _check(bool(berry_a.get("ok", false)) and berry_a == berry_b,
                "perennial harvest receipt deterministic")
            _check(model.status(1)["stage"] == "flowering", "strawberry enters regrowth")
            _check(not model.harvest(1, epoch)["ok"], "perennial harvest only once daily")
        if epoch == 29 or epoch == 43 or epoch == 85:
            _check(model.status(1)["stage"] == "dormant", "strawberry dormancy epoch %d" % epoch)
        if epoch == 57:
            _check(model.status(1)["stage"] != "dormant", "spring perennial reactivation")
        if epoch == 5:
            _check(model.status(3)["stage"] == "failed", "four-day drought causes failure")
        _check(model.save_state() == replay.save_state(), "post-action replay %d" % epoch)
        for i in range(30):
            var status: Dictionary = model.status(i)
            _check(bool(status["ok"]) and str(status["message"]) != "", "feedback bed %d day %d" % [i, epoch])
            _check(int(status["thermal_tenths"]) >= 0 and int(status["thermal_tenths"]) <= 20000,
                "bounded thermal units bed %d day %d" % [i, epoch])
            _check(int(status["stress_days"]) >= 0 and int(status["stress_days"]) <= 4,
                "bounded stress bed %d day %d" % [i, epoch])
        if epoch % 14 == 0:
            var checkpoint: Dictionary = model.save_state()
            var restored = _new_model()
            _check(restored.load_state(checkpoint), "seasonal restore epoch %d" % epoch)
            _check(restored.save_state() == checkpoint, "nested exact roundtrip epoch %d" % epoch)
            checkpoint["beds"][1]["thermal_tenths"] = 19999
            _check(model.save_state() == replay.save_state(), "deep-copy isolation epoch %d" % epoch)

    _check(int(model.save_state()["last_epoch"]) == 112, "two 56-day years")
    _check(int(model.save_state()["beds"][1]["dormancy_count"]) == 2,
        "one dormancy transition per year, not daily")
    var stable: Dictionary = model.save_state()
    var invalids: Array = []
    var bad: Dictionary = stable.duplicate(true)
    bad["schema"] = 2
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["stage"] = "teleport"
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["crop"] = "forged"
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["thermal_tenths"] = -1
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["last_action_epoch"] = 113
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["harvest_count"] = "unbounded"
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["dormancy_count"] = -1
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"].pop_back()
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["unapproved_extra"] = 1
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["last_epoch"] = "112"
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["stage"] = "dormant"
    invalids.append(bad)
    for i in range(invalids.size()):
        _check(not model.load_state(invalids[i]), "reject hostile nested snapshot %d" % i)
        _check(model.save_state() == stable, "hostile snapshot atomic %d" % i)
    _check(not model.harvest(0, 112)["ok"], "empty bed cannot multiply inventory")
    _check(not model.clear_failed(0, 112)["ok"], "empty bed cannot be cleared for rewards")
    _check(not model.advance_day(114, 180, _moisture())["ok"], "skipped day rejected after two years")
    _check(model.save_state() == stable, "late invalid calls atomic")

    var frost = _new_model()
    _check(frost.advance_day(1, 180, _moisture(-1))["ok"], "frost control initialized")
    _check(frost.plant(0, "turnip", 1)["ok"], "frost control planted")
    _check(frost.advance_day(2, -100, _moisture(-1))["ok"], "frost applied")
    _check(frost.status(0)["stage"] == "failed", "lethal frost causes failure")
    _check(frost.clear_failed(0, 2)["ok"], "player can clear failed crop")
    _check(not frost.plant(0, "turnip", 2)["ok"], "clear/plant same day blocked")
    _check(frost.advance_day(3, 180, _moisture(-1))["ok"], "frost control recovered day")
    _check(frost.plant(0, "turnip", 3)["ok"], "replant after recovery day")

    var heat = _new_model()
    _check(heat.advance_day(1, 180, _moisture(-1))["ok"], "heat control initialized")
    _check(heat.plant(0, "turnip", 1)["ok"], "heat control planted")
    _check(heat.advance_day(2, 450, _moisture(-1))["ok"], "heat day one")
    _check(heat.status(0)["stage"] != "failed", "heat does not instantly kill")
    _check(heat.advance_day(3, 450, _moisture(-1))["ok"], "heat day two")
    _check(heat.status(0)["stage"] == "failed", "persistent heat causes bounded failure")

    var winter = _new_model()
    for epoch in range(1, 44):
        _check(winter.advance_day(epoch, 20, _moisture(-1))["ok"], "winter setup day %d" % epoch)
    _check(winter.plant(0, "winterroot", 43)["ok"], "winterroot sowing in winter")
    _check(winter.advance_day(44, -50, _moisture(-1))["ok"], "winterroot cold day")
    _check(winter.status(0)["stage"] != "failed", "cold-tolerant winterroot survives")
    _check(not winter.plant(1, "turnip", 44)["ok"], "spring crop excluded from winter")

    print("EVERBLOOM F03 PHENOLOGY NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
