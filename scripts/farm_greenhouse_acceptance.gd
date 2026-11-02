extends SceneTree
## F08 actual native Godot 112-day greenhouse, power conservation and hostile save acceptance.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("F08 GREENHOUSE FAILED: " + message)

func _model():
    return load("res://scripts/farm_greenhouse_microclimate.gd").new()

func _conserved(snapshot: Dictionary) -> bool:
    return int(snapshot["energy_added"]) == int(snapshot["energy_spent"]) + int(snapshot["energy_available"])

func _run() -> void:
    var cared = _model()
    var replay = _model()
    _check(cared.save_state()["bays"].size() == 4, "four optional greenhouse bays; existing 30 outdoor beds untouched")
    _check(cared.save_state() == replay.save_state(), "deterministic initial greenhouse")
    _check(not cared.advance_day(2, 40, 60, false)["ok"], "skipped day rejected")
    _check(not cared.plant(0, "lettuce", 1)["ok"], "cannot plant before epoch begins")
    _check(not cared.credit_energy(1, 12)["ok"], "cannot credit before epoch begins")
    _check(cared.save_state() == replay.save_state(), "rejected early actions are atomic")
    var warm_growth_at_14: int = 0
    var passive_growth_at_14: int = 0
    var first_harvest: int = 0
    for epoch in range(1, 113):
        var season: int = int(((epoch - 1) % 56) / 14)
        var temperature: int = [90, 180, 90, 10][season]
        var sunlight: int = [65, 80, 55, 35][season]
        var rain: bool = epoch % 5 == 0
        var a: Dictionary = cared.advance_day(epoch, temperature, sunlight, rain)
        var b: Dictionary = replay.advance_day(epoch, temperature, sunlight, rain)
        _check(a == b and a["ok"], "deterministic climate result %d" % epoch)
        _check(cared.save_state() == replay.save_state(), "identical climate state %d" % epoch)
        _check(_conserved(cared.save_state()), "finite energy conserved %d" % epoch)
        var unchanged: Dictionary = cared.save_state()
        _check(not cared.advance_day(epoch, temperature, sunlight, rain)["ok"], "duplicate day denied %d" % epoch)
        _check(cared.save_state() == unchanged, "duplicate day atomic %d" % epoch)
        if epoch == 1:
            for bay in range(2):
                var x: Dictionary = cared.install(bay, epoch)
                var y: Dictionary = replay.install(bay, epoch)
                _check(x == y and x["ok"], "installed greenhouse bay %d" % bay)
                _check(x["material_required"]["glass"] == 8, "external construction debit specified")
                x = cared.plant(bay, "lettuce", epoch)
                y = replay.plant(bay, "lettuce", epoch)
                _check(x == y and x["ok"], "seeded greenhouse bay %d" % bay)
                _check(x["seed_required"] == "lettuce_seed", "external seed debit specified")
            _check(not cared.install(0, epoch)["ok"], "cannot duplicate greenhouse installation")
            _check(not cared.plant(0, "lettuce", epoch)["ok"], "cannot double plant")
            _check(not cared.plant(2, "unlicensed_crop", epoch)["ok"], "unknown crop rejected")
            _check(not cared.install(4, epoch)["ok"], "out-of-range installation rejected")
            var set_a: Dictionary = cared.set_controls(0, 1, true, true, epoch)
            var set_b: Dictionary = replay.set_controls(0, 1, true, true, epoch)
            _check(set_a == set_b and set_a["ok"], "heater lamps fan controls")
            _check(set_a["energy_per_day_requested"] == 6, "control daily energy contract exact")
            _check(not cared.set_controls(0, 0, false, false, epoch)["ok"], "duplicate control change rejected")
        var credit_a: Dictionary = cared.credit_energy(epoch, 12)
        var credit_b: Dictionary = replay.credit_energy(epoch, 12)
        _check(credit_a == credit_b and credit_a["ok"], "one external energy receipt %d" % epoch)
        unchanged = cared.save_state()
        _check(not cared.credit_energy(epoch, 12)["ok"], "duplicate energy credit denied %d" % epoch)
        _check(cared.save_state() == unchanged, "duplicate energy credit atomic %d" % epoch)
        _check(_conserved(cared.save_state()), "energy funding accounted %d" % epoch)
        if epoch == 14:
            warm_growth_at_14 = int(cared.status(0)["bay"]["gdd"])
            passive_growth_at_14 = int(cared.status(1)["bay"]["gdd"])
            _check(warm_growth_at_14 > passive_growth_at_14, "charged climate controls causally accelerate growth")
            _check(int(cared.save_state()["energy_spent"]) > 0, "heated growth costs finite power")
        if epoch == 30:
            var x: Dictionary = cared.harvest(0, epoch)
            var y: Dictionary = replay.harvest(0, epoch)
            _check(x == y and x["ok"], "mature greenhouse harvest proposal")
            if x["ok"]:
                first_harvest = int(x.get("quantity_proposed", 0))
                _check(first_harvest >= 1 and first_harvest <= 3, "finite bounded harvest proposal")
                _check(not cared.harvest(0, epoch)["ok"], "no duplicate harvest inventory proposal")
                x = cared.plant(0, "basil", epoch)
                y = replay.plant(0, "basil", epoch)
                _check(x == y and x["ok"], "replant after harvested bay cleared")
        if epoch % 14 == 0:
            var snapshot: Dictionary = cared.save_state()
            var restored = _model()
            _check(restored.load_state(snapshot), "nested state restored at day %d" % epoch)
            _check(restored.save_state() == snapshot, "exact nested state equality %d" % epoch)
            var json_restored = _model()
            _check(json_restored.load_json(JSON.stringify(snapshot)), "JSON roundtrip at day %d" % epoch)
            _check(json_restored.save_state() == snapshot, "JSON nested equality %d" % epoch)
            _check(_conserved(json_restored.save_state()), "JSON energy conservation %d" % epoch)
        _check(cared.save_state() == replay.save_state(), "full daily replay equality %d" % epoch)
    _check(warm_growth_at_14 > passive_growth_at_14, "early growth advantage persisted")
    _check(first_harvest > 0, "real proposed crop yield")
    _check(int(cared.save_state()["last_epoch"]) == 112, "two 56-day years completed")
    _check(_conserved(cared.save_state()), "final two-year finite energy conservation")
    var pristine: Dictionary = cared.save_state()
    var invalids: Array = []
    var bad: Dictionary
    bad = pristine.duplicate(true); bad["schema"] = 2; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_epoch"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_epoch"] = 2000001; invalids.append(bad)
    bad = pristine.duplicate(true); bad["energy_available"] += 1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["energy_spent"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["energy_added"] = 10000001; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_credit_epoch"] = 113; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"].pop_back(); invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0] = []; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["vent"] = 4; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["vent"] = 1.5; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["temp"] = 651; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["humidity"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["light"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["gdd"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["stress"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["stage"] = "invented"; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["crop"] = "invented"; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["heat"] = 1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["last_control"] = 113; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["last_plant"] = 113; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["harvest_count"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][2]["installed"] = true; bad["bays"][2]["crop"] = "lettuce"; invalids.append(bad)
    bad = pristine.duplicate(true); bad["bays"][0]["unexpected"] = 1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["unexpected"] = 1; invalids.append(bad)
    for i in range(invalids.size()):
        _check(not cared.load_state(invalids[i]), "hostile nested save rejected %d" % i)
        _check(cared.save_state() == pristine, "rejected nested save is atomic %d" % i)
    var json_restored = _model()
    _check(json_restored.load_json(JSON.stringify(pristine)), "final JSON valid")
    _check(json_restored.save_state() == pristine, "final JSON exact")
    bad = pristine.duplicate(true); bad["bays"][0]["humidity"] = 12.5
    _check(not json_restored.load_json(JSON.stringify(bad)), "fractional JSON rejected")
    _check(not json_restored.load_json("{broken"), "malformed JSON rejected")
    _check(json_restored.save_state() == pristine, "invalid JSON load atomic")
    _check(not cared.advance_day(112, 90, 50, false)["ok"], "restored duplicate day denied")
    _check(cared.advance_day(113, 90, 50, false)["ok"], "third year begins on fresh epoch")
    var no_power = _model()
    _check(no_power.advance_day(1, 10, 35, false)["ok"], "unpowered setup day")
    _check(no_power.install(0, 1)["ok"], "unpowered bay installed")
    _check(no_power.plant(0, "tomato", 1)["ok"], "unpowered crop seeded")
    _check(no_power.set_controls(0, 3, true, true, 1)["ok"], "unpowered requested controls")
    var powerless_step: Dictionary = no_power.advance_day(2, 10, 35, false)
    _check(powerless_step["ok"], "unpowered climate advances")
    _check(powerless_step["energy_spent"] == 0, "no power means no fabricated energy spend")
    _check(not powerless_step["bays"][0]["heater_active"] and not powerless_step["bays"][0]["lamps_active"], "unpowered controls do not operate")
    _check(_conserved(no_power.save_state()), "unpowered ledger conserved")
    _check(not no_power.advance_day(4, 10, 35, false)["ok"], "skipped year/day denied")
    _check(not no_power.advance_day(3, 501, 35, false)["ok"], "out-of-range temperature denied")
    _check(not no_power.advance_day(3, 10, 101, false)["ok"], "out-of-range sunlight denied")
    _check(not no_power.credit_energy(2, -10)["ok"], "negative energy denied")
    _check(not no_power.credit_energy(2, 1001)["ok"], "overlarge energy denied")
    _check(no_power.save_state()["last_epoch"] == 2, "invalid weather did not advance")
    print("EVERBLOOM F08 GREENHOUSE NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(1 if failures > 0 else 0)
