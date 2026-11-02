extends SceneTree
## F06 native two-year causal treatment, spatial quarantine and hostile persistence acceptance.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("F06 DISEASE FAILED: " + message)

func _model():
    return load("res://scripts/farm_disease_ecology.gd").new()

func _run() -> void:
    var treated = _model()
    var replay = _model()
    var control = _model()
    var inventory: Dictionary = {"turnip_seed": 30, "clean_water": 8, "plant_cover": 8, "herbal_tonic": 30, "petals": 100}
    _check(treated.save_state()["beds"].size() == 30, "preserve original thirty beds")
    _check(treated.save_state() == replay.save_state(), "initial state deterministic")
    _check(not treated.advance_day(2, 90, 10)["ok"], "skipped epoch rejected")
    _check(not treated.register_crop(0, "turnip", 1)["ok"], "early registration rejected")
    _check(not treated.act(0, "treat", 1)["ok"], "early treatment rejected")
    _check(treated.save_state() == replay.save_state(), "early errors atomic")
    var benefit_days: int = 0
    var treated_final: int = 0
    var control_final: int = 0
    for epoch in range(1, 113):
        var humidity: int = 90 if epoch <= 70 else 25
        var wind: int = (epoch * 19) % 101
        var a: Dictionary = treated.advance_day(epoch, humidity, wind)
        var b: Dictionary = replay.advance_day(epoch, humidity, wind)
        var c: Dictionary = control.advance_day(epoch, humidity, wind)
        _check(a == b and a["ok"] and c["ok"], "deterministic weather transition %d" % epoch)
        _check(treated.save_state() == replay.save_state(), "exact replay state %d" % epoch)
        var snapshot: Dictionary = treated.save_state()
        _check(not treated.advance_day(epoch, humidity, wind)["ok"], "duplicate day denied %d" % epoch)
        _check(treated.save_state() == snapshot, "duplicate day atomic %d" % epoch)
        if epoch == 1:
            _check(treated.register_crop(0, "turnip", epoch)["ok"], "plant treated bed")
            _check(replay.register_crop(0, "turnip", epoch)["ok"], "plant replay bed")
            _check(control.register_crop(0, "turnip", epoch)["ok"], "plant control bed")
            _check(not treated.register_crop(0, "turnip", epoch)["ok"], "duplicate planting rejected")
            _check(not treated.register_crop(29, "fake_crop", epoch)["ok"], "unknown crop rejected")
        if epoch >= 3 and epoch <= 70 and epoch % 5 == 3:
            var x: Dictionary = treated.act(0, "treat", epoch)
            var y: Dictionary = replay.act(0, "treat", epoch)
            _check(x == y and x["ok"], "treatment accepted only on infected crop %d" % epoch)
            _check(treated.save_state() == replay.save_state(), "treatment deterministic %d" % epoch)
            _check(x["infection"] == snapshot["beds"][0]["infection"], "treatment never instant-cures %d" % epoch)
            var after: Dictionary = treated.save_state()
            _check(not treated.act(0, "treat", epoch)["ok"], "duplicate treatment denied %d" % epoch)
            _check(treated.save_state() == after, "duplicate treatment atomic %d" % epoch)
        if epoch == 57:
            _check(a["year"] == 2 and a["season_index"] == 0, "56-day year rollover")
        if epoch == 40:
            var before: Dictionary = treated.save_state()
            _check(not treated.act(30, "sanitize", epoch)["ok"], "invalid bed denied")
            _check(not treated.act(0, "instant_cure", epoch)["ok"], "unsupported cure denied")
            _check(not treated.act(0, "treat", epoch + 1)["ok"], "future action denied")
            _check(not treated.advance_day(epoch + 1, -1, 10)["ok"], "negative humidity denied")
            _check(not treated.advance_day(epoch + 1, 80, 101)["ok"], "invalid wind denied")
            _check(treated.save_state() == before, "all invalid transitions atomic")
        for index in range(30):
            var state: Dictionary = treated.status(index)
            _check(state["ok"], "bed feedback %d/%d" % [epoch, index])
            _check(state["infection"] >= 0 and state["infection"] <= 100 and state["damage"] >= 0 and state["damage"] <= 100, "bounded disease and damage")
            _check(state["immunity"] >= 0 and state["immunity"] <= 100, "bounded immunity")
            _check(state["yield_basis_points"] >= 4000 and state["yield_basis_points"] <= 10000, "bounded projected yield")
        var treated_yield: int = int(treated.status(0)["yield_basis_points"])
        var control_yield: int = int(control.status(0)["yield_basis_points"])
        if epoch > 8 and treated_yield > control_yield:
            benefit_days += 1
        if epoch == 112:
            treated_final = treated_yield
            control_final = control_yield
        if epoch % 14 == 0:
            var saved: Dictionary = treated.save_state()
            var restored = _model()
            _check(restored.load_state(saved), "seasonal nested snapshot accepted %d" % epoch)
            _check(restored.save_state() == saved, "seasonal snapshot equal %d" % epoch)
            _check(restored.status(0) == treated.status(0), "seasonal player feedback restored %d" % epoch)
            _check(not restored.advance_day(epoch, humidity, wind)["ok"], "restored duplicate day denied")
            var exposed: Dictionary = treated.save_state()
            exposed["beds"][0]["infection"] = 100
            _check(treated.save_state() == saved, "deep copy isolation %d" % epoch)
        _check(treated.save_state() == replay.save_state(), "post-action replay %d" % epoch)
    _check(benefit_days >= 15, "multi-day treatment causes measurable benefit")
    _check(treated_final > control_final, "two-year care improves projected harvest")
    _check(inventory == {"turnip_seed": 30, "clean_water": 8, "plant_cover": 8, "herbal_tonic": 30, "petals": 100}, "external inventory and money never mutated")
    _check(not treated.save_state().has("inventory") and not treated.save_state().has("gold"), "no economic authority")
    _check(not treated.status(-1)["ok"] and not treated.status(30)["ok"], "invalid status requests rejected")

    ## Radius-1 transmission under dry conditions; quarantine blocks both directions.
    var exposed = _model()
    var isolated = _model()
    _check(exposed.advance_day(1, 25, 0)["ok"], "spatial fixture day 1")
    var seed: Dictionary = exposed.save_state()
    for index in [0, 1, 29]:
        seed["beds"][index]["crop"] = "turnip"
        seed["beds"][index]["immunity"] = 12
    seed["beds"][0]["infection"] = 72
    _check(exposed.load_state(seed) and isolated.load_state(seed), "bounded outbreak fixture loads")
    _check(isolated.act(0, "quarantine", 1)["ok"], "quarantine action accepted")
    _check(isolated.status(0)["infection"] == 72, "quarantine not instant cure")
    _check(exposed.advance_day(2, 25, 80)["ok"], "unquarantined spread")
    _check(isolated.advance_day(2, 25, 80)["ok"], "quarantined spread")
    _check(exposed.status(1)["infection"] > 0, "neighbor infected at Manhattan radius 1")
    _check(isolated.status(1)["infection"] == 0, "quarantine blocks neighboring transmission")
    _check(exposed.status(29)["infection"] == 0, "distant bed remains healthy")
    _check(not isolated.act(29, "treat", 2)["ok"], "healthy crop cannot be treated")
    _check(isolated.act(1, "sanitize", 2)["ok"], "sanitation available on healthy bed")
    _check(isolated.status(1)["infection"] == 0, "sanitation does not fabricate cure")

    var pristine: Dictionary = treated.save_state()
    var invalids: Array = []
    var bad: Dictionary
    bad = pristine.duplicate(true); bad["schema"] = 2; invalids.append(bad)
    bad = pristine.duplicate(true); bad["schema"] = true; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_epoch"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_epoch"] = 2000001; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"].pop_back(); invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0] = []; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["infection"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["infection"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["infection"] = 1.5; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["immunity"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["damage"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["sanitation_days"] = 15; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["quarantine_days"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["treatment_days"] = 15; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["last_action_epoch"] = 113; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["crop"] = "fiction"; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["crop"] = ""; bad["beds"][0]["infection"] = 1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["unexpected"] = true; invalids.append(bad)
    bad = pristine.duplicate(true); bad["unexpected"] = true; invalids.append(bad)
    for i in range(invalids.size()):
        _check(not treated.load_state(invalids[i]), "hostile snapshot rejected %d" % i)
        _check(treated.save_state() == pristine, "hostile snapshot atomic %d" % i)
    var recovered = _model()
    _check(recovered.load_json(JSON.stringify(pristine)), "JSON roundtrip accepted")
    _check(recovered.save_state() == pristine, "JSON nested state exactly restored")
    bad = pristine.duplicate(true); bad["beds"][0]["infection"] = 12.5
    _check(not recovered.load_json(JSON.stringify(bad)), "fractional JSON rejected")
    _check(not recovered.load_json("{malformed"), "invalid JSON rejected")
    _check(recovered.save_state() == pristine, "invalid JSON atomic")
    _check(not recovered.advance_day(112, 20, 20)["ok"], "restored duplicate day denied")
    _check(recovered.advance_day(113, 20, 20)["ok"], "restored year three advances")
    print("EVERBLOOM F06 DISEASE NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(1 if failures > 0 else 0)
