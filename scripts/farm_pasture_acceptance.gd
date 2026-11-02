extends SceneTree
## F13 native Godot acceptance: real GDScript transitions and 112-day conservation.
var checks: int = 0
var failures: int = 0
var domain_script = preload("res://scripts/farm_pasture_rotation.gd")

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("F13 NATIVE FAILED: " + message)

func _balances(model) -> void:
    var forage: int = 0
    var manure: int = 0
    var soil: int = 0
    for field in model.state["paddocks"]:
        _check(int(field["forage"]) >= 0 and int(field["forage"]) <= 20, "finite forage")
        _check(int(field["manure"]) >= 0 and int(field["manure"]) <= 20, "finite manure")
        _check(int(field["soil"]) >= 0 and int(field["soil"]) <= 100, "finite soil")
        forage += int(field["forage"])
        manure += int(field["manure"])
        soil += int(field["soil"])
    var ledger: Dictionary = model.state["ledger"]
    _check(forage == 36 + int(ledger["grown"]) - int(ledger["consumed"]),
        "forage conserved")
    _check(manure == int(ledger["deposited"]) - int(ledger["applied"]),
        "manure conserved")
    _check(int(ledger["deposited"]) == int(ledger["consumed"]),
        "grazing deposits one manure unit")
    _check(soil == 150 + int(ledger["soil_gained"]) - int(ledger["soil_lost"]),
        "soil finite-state ledger conserved")

func _replay(adversarial: bool) -> String:
    var pasture = domain_script.new()
    _check(pasture.state["paddocks"].size() == 3, "three isolated paddocks")
    _check(pasture.state["last_epoch"] == 1, "first monotonic epoch")
    _check("Paddock 1" in pasture.describe(), "readable player forecast")
    var before: String = JSON.stringify(pasture.save_state())
    _check(not pasture.move_to(0, 1)["ok"], "same-field move idempotent")
    _check(not pasture.move_to(3, 1)["ok"], "out-of-range paddock rejected")
    _check(not pasture.graze("unknown", 1)["ok"], "unknown animal rejected")
    _check(not pasture.graze("hen", 2)["ok"], "future day grazing rejected")
    _check(not pasture.advance_day(3, "Clear", "Spring")["ok"], "skipped day rejected")
    _check(JSON.stringify(pasture.save_state()) == before, "all rejected commands atomic")
    _check(pasture.graze("hen", 1)["ok"], "initial hen grazing")
    _check(not pasture.graze("hen", 1)["ok"], "same-day animal cannot graze twice")
    _check(pasture.graze("cow", 1)["ok"], "second animal grazes finite resource")
    _check(pasture.apply_manure(0, 1)["ok"], "manure converts into bounded soil")
    _check(not pasture.apply_manure(0, 1)["ok"], "same-day manure replay denied")
    _check(pasture.move_to(1, 1)["ok"], "player moves animals to another field")
    var after_move: String = JSON.stringify(pasture.save_state())
    _check(not pasture.move_to(2, 1)["ok"], "second move same day rejected")
    _check(JSON.stringify(pasture.save_state()) == after_move, "duplicate move atomic")
    _balances(pasture)
    for epoch in range(2, 113):
        var season: String = ["Spring", "Summer", "Autumn", "Winter"][int((epoch - 1) / 14) % 4]
        var weather: String = "Storm" if epoch % 23 == 0 else (
            "Drought" if epoch % 17 == 0 else ("Rain" if epoch % 9 == 0 else "Clear"))
        _check(pasture.advance_day(epoch, weather, season)["ok"],
            "monotonic daily step %d" % epoch)
        _check(not pasture.advance_day(epoch, weather, season)["ok"],
            "duplicate day %d rejected" % epoch)
        if epoch % 7 == 1:
            var target: int = int(epoch / 7) % 3
            _check(pasture.move_to(target, epoch)["ok"], "weekly rotational move %d" % epoch)
            _check(not pasture.move_to(target, epoch)["ok"], "duplicate weekly move denied")
        if season == "Winter" or weather == "Storm":
            var immutable: String = JSON.stringify(pasture.save_state())
            _check(not pasture.graze("hen", epoch)["ok"], "unsafe weather grazing denied")
            _check(JSON.stringify(pasture.save_state()) == immutable, "unsafe grazing atomic")
        else:
            for animal_id in ["hen", "cow"]:
                var result: Dictionary = pasture.graze(animal_id, epoch)
                if result["ok"]:
                    _check(not pasture.graze(animal_id, epoch)["ok"],
                        "one graze per animal per epoch")
            var active: int = int(pasture.state["active"])
            if int(pasture.state["paddocks"][active]["manure"]) >= 2:
                pasture.apply_manure(active, epoch)
        _balances(pasture)
        _check(pasture.state["last_epoch"] == epoch, "epoch persisted")
        if epoch % 14 == 0:
            var snapshot: String = JSON.stringify(pasture.save_state())
            var restored = domain_script.new()
            _check(restored.load_json(snapshot), "JSON restore at day %d" % epoch)
            _check(JSON.stringify(restored.save_state()) == snapshot,
                "nested JSON byte-stable at day %d" % epoch)
            _check(pasture.load_state(restored.save_state()), "state restore day %d" % epoch)
    _check(pasture.state["last_epoch"] == 112, "two complete 56-day years")
    if adversarial:
        var good: String = JSON.stringify(pasture.save_state())
        var attacks: Array = []
        var bad: Dictionary = pasture.save_state()
        bad["paddocks"][0]["forage"] = -1
        attacks.append(bad)
        bad = pasture.save_state()
        bad["paddocks"][0]["manure"] = 999
        attacks.append(bad)
        bad = pasture.save_state()
        bad["paddocks"][1]["soil"] = 101
        attacks.append(bad)
        bad = pasture.save_state()
        bad["ledger"]["consumed"] = int(bad["ledger"]["consumed"]) + 1
        attacks.append(bad)
        bad = pasture.save_state()
        bad["ledger"]["deposited"] = int(bad["ledger"]["deposited"]) + 1
        attacks.append(bad)
        bad = pasture.save_state()
        bad["ledger"]["soil_gained"] = int(bad["ledger"]["soil_gained"]) + 1
        attacks.append(bad)
        bad = pasture.save_state()
        bad["paddocks"].append(bad["paddocks"][0].duplicate(true))
        attacks.append(bad)
        bad = pasture.save_state()
        bad["last_grazed"]["hen"] = 99999
        attacks.append(bad)
        bad = pasture.save_state()
        bad["last_move_epoch"] = 99999
        attacks.append(bad)
        bad = pasture.save_state()
        bad["season"] = "Monsoon"
        attacks.append(bad)
        bad = pasture.save_state()
        bad["paddocks"][0]["last_amend_epoch"] = -2
        attacks.append(bad)
        bad = pasture.save_state()
        bad["paddocks"][0]["soil"] = NAN
        attacks.append(bad)
        for i in range(attacks.size()):
            _check(not pasture.load_state(attacks[i]), "hostile snapshot %d rejected" % i)
            _check(JSON.stringify(pasture.save_state()) == good,
                "hostile snapshot %d atomic" % i)
        _check(not pasture.load_json("{malformed"), "invalid JSON rejected")
        _check(JSON.stringify(pasture.save_state()) == good, "malformed JSON atomic")
        _check(not pasture.load_state([]), "wrong root rejected")
        _check(JSON.stringify(pasture.save_state()) == good, "wrong root atomic")
        _check(not pasture.advance_day(114, "Clear", "Spring")["ok"],
            "skipped third-year day denied")
        _check(JSON.stringify(pasture.save_state()) == good, "skipped epoch atomic")
    return JSON.stringify(pasture.save_state())

func _run() -> void:
    var first: String = _replay(true)
    var second: String = _replay(false)
    _check(first == second, "112-day pasture replay deterministic")
    print("F13 NATIVE ROTATIONAL PASTURE: %d assertions, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
