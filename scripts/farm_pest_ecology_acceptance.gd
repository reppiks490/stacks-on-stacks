extends SceneTree
## F05 native 112-day causal counterfactual, deep save and bounded ecology acceptance.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("F05 PEST ECOLOGY FAILED: " + message)

func _model():
    return load("res://scripts/farm_pest_ecology.gd").new()

func _apply_pair(a, b, index: int, action: String, epoch: int) -> void:
    var x: Dictionary = a.act(index, action, epoch)
    var y: Dictionary = b.act(index, action, epoch)
    _check(x == y and bool(x.get("ok", false)), "replayed care %s at epoch %d" % [action, epoch])
    _check(a.save_state() == b.save_state(), "care transition deterministic %d" % epoch)
    var snapshot: Dictionary = a.save_state()
    _check(not a.act(index, action, epoch)["ok"], "duplicate care denied %d" % epoch)
    _check(a.save_state() == snapshot, "duplicate care atomic %d" % epoch)

func _run() -> void:
    var treated = _model()
    var replay = _model()
    var untreated = _model()
    var external_inventory: Dictionary = {"turnip_seed": 30, "leaf_mulch": 8, "pest_trap": 8, "petals": 120}
    _check(treated.save_state() == replay.save_state(), "same initial snapshot")
    _check(treated.save_state()["beds"].size() == 30, "thirty original planting beds")
    _check(not treated.advance_day(2, 30, 30)["ok"], "cannot skip epoch one")
    _check(not treated.register_crop(0, "turnip", 1)["ok"], "cannot register before day begins")
    _check(not treated.act(0, "mulch", 1)["ok"], "cannot act before day begins")
    _check(treated.save_state() == replay.save_state(), "invalid early actions atomic")
    var benefit_days: int = 0
    var end_treated: int = 0
    var end_control: int = 0
    for epoch in range(1, 113):
        var rain: int = (epoch * 13) % 101
        var heat: int = (epoch * 29) % 101
        var x: Dictionary = treated.advance_day(epoch, rain, heat)
        var y: Dictionary = replay.advance_day(epoch, rain, heat)
        var z: Dictionary = untreated.advance_day(epoch, rain, heat)
        _check(x == y and x["ok"] and z["ok"], "daily deterministic weather %d" % epoch)
        _check(treated.save_state() == replay.save_state(), "daily replay equality %d" % epoch)
        var before: Dictionary = treated.save_state()
        _check(not treated.advance_day(epoch, rain, heat)["ok"], "duplicate epoch rejected %d" % epoch)
        _check(treated.save_state() == before, "duplicate day preserves state %d" % epoch)
        if epoch == 1:
            for index in range(30):
                var a: Dictionary = treated.register_crop(index, "turnip", epoch)
                var b: Dictionary = replay.register_crop(index, "turnip", epoch)
                var c: Dictionary = untreated.register_crop(index, "turnip", epoch)
                _check(a == b and a["ok"] and c["ok"], "register bed %d" % index)
            _check(not treated.register_crop(0, "turnip", epoch)["ok"], "duplicate planting denied")
            _check(not treated.register_crop(0, "unknown", epoch)["ok"], "unknown crop denied")
        if epoch > 1 and epoch % 14 == 2:
            _apply_pair(treated, replay, 0, "mulch", epoch)
        if epoch > 1 and epoch % 14 == 3:
            _apply_pair(treated, replay, 0, "trap", epoch)
        if epoch > 1 and epoch % 14 == 4:
            _apply_pair(treated, replay, 0, "weed", epoch)
        if epoch > 1 and epoch % 14 == 5:
            _apply_pair(treated, replay, 0, "habitat", epoch)
        if epoch == 57:
            _check(x["year"] == 2 and x["season_index"] == 0, "56-day year rollover")
        if epoch == 40:
            var snap: Dictionary = treated.save_state()
            _check(not treated.clear_crop(0, epoch + 1)["ok"], "future clear denied")
            _check(treated.save_state() == snap, "future clear atomic")
            _check(not treated.act(30, "weed", epoch)["ok"], "out-of-range bed denied")
            _check(not treated.act(1, "poison", epoch)["ok"], "unsupported pesticide rejected")
            _check(not treated.advance_day(epoch + 1, -1, 20)["ok"], "negative rain rejected")
            _check(not treated.advance_day(epoch + 1, 20, 101)["ok"], "unbounded heat rejected")
            _check(treated.save_state() == snap, "invalid inputs leave state unchanged")
        for index in range(30):
            var state: Dictionary = treated.status(index)
            var control_state: Dictionary = untreated.status(index)
            _check(state["ok"] and control_state["ok"], "bed feedback exists %d/%d" % [epoch, index])
            _check(state["weeds"] >= 0 and state["weeds"] <= 100 and state["pests"] >= 0 and state["pests"] <= 100, "bounded pests and weeds")
            _check(state["stress"] >= 0 and state["stress"] <= 100 and state["habitat"] >= 0 and state["habitat"] <= 100, "bounded stress and habitat")
            _check(state["yield_basis_points"] >= 4000 and state["yield_basis_points"] <= 10000, "bounded yield forecast")
        var treatment: int = int(treated.status(0)["yield_basis_points"])
        var control: int = int(untreated.status(0)["yield_basis_points"])
        if epoch > 14 and treatment > control:
            benefit_days += 1
        if epoch == 112:
            end_treated = treatment
            end_control = control
        if epoch % 14 == 0:
            var checkpoint: Dictionary = treated.save_state()
            var restored = _model()
            _check(restored.load_state(checkpoint), "seasonal deep snapshot restores epoch %d" % epoch)
            _check(restored.save_state() == checkpoint, "seasonal snapshot equal epoch %d" % epoch)
            _check(restored.status(0) == treated.status(0), "seasonal UI forecast restored %d" % epoch)
            _check(not restored.advance_day(epoch, rain, heat)["ok"], "restored duplicate epoch rejected")
            var exposed: Dictionary = treated.save_state()
            exposed["beds"][0]["weeds"] = 999
            _check(treated.save_state() == checkpoint, "save_state returns deep copy")
        _check(treated.save_state() == replay.save_state(), "post-action replay epoch %d" % epoch)
    _check(benefit_days >= 28, "prevention causally improves yield on many matching-weather days")
    _check(end_treated > end_control, "prevention improves final two-year yield forecast")
    _check(not treated.save_state().has("inventory") and not treated.save_state().has("gold"), "no inventory or money authority")
    _check(external_inventory == {"turnip_seed": 30, "leaf_mulch": 8, "pest_trap": 8, "petals": 120}, "external economy untouched")
    _check(not treated.status(-1)["ok"] and not treated.status(30)["ok"], "invalid feedback bed rejected")
    var pristine: Dictionary = treated.save_state()
    var invalids: Array = []
    var bad: Dictionary
    bad = pristine.duplicate(true); bad["schema"] = 2; invalids.append(bad)
    bad = pristine.duplicate(true); bad["schema"] = true; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_epoch"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_epoch"] = 2000001; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"].pop_back(); invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0] = []; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["weeds"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["weeds"] = 1.5; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["pests"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["habitat"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["mulch_days"] = 15; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["trap_days"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["stress"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["last_action_epoch"] = 113; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["crop"] = "fiction"; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["crop"] = ""; bad["beds"][0]["stress"] = 1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["beds"][0]["unexpected"] = true; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bonus"] = 1; invalids.append(bad)
    for index in range(invalids.size()):
        _check(not treated.load_state(invalids[index]), "hostile nested snapshot rejected %d" % index)
        _check(treated.save_state() == pristine, "hostile load leaves authoritative state intact %d" % index)
    var json_string: String = JSON.stringify(pristine)
    var recovered = _model()
    _check(recovered.load_json(json_string), "JSON nested save roundtrip")
    _check(recovered.save_state() == pristine, "JSON roundtrip exact nested state")
    var fractional: Dictionary = pristine.duplicate(true)
    fractional["beds"][0]["weeds"] = 12.5
    _check(not recovered.load_json(JSON.stringify(fractional)), "fractional JSON values rejected")
    _check(not recovered.load_json("{malformed"), "malformed JSON rejected")
    _check(recovered.save_state() == pristine, "invalid JSON preserves prior state")
    _check(not recovered.advance_day(112, 50, 50)["ok"], "restored year-two replay denied")
    _check(recovered.advance_day(113, 50, 50)["ok"], "restored year-three replay allowed")
    print("EVERBLOOM F05 PEST ECOLOGY NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(1 if failures > 0 else 0)
