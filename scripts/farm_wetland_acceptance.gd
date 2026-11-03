extends SceneTree
## F15 native 112-day deterministic wetland ecology, fish ledger and hostile-save tests.
var checks: int = 0
var failures: int = 0
var domain_script = preload("res://scripts/farm_wetland_ecology.gd")

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("F15 NATIVE FAILED: " + message)

func _conservation(model) -> void:
    var ledger: Dictionary = model.state["ledger"]
    _check(model.state["sites"].size() == 3, "three wetland habitats")
    _check(int(ledger["founders"]) == 72, "72 founding fish")
    _check(int(ledger["budget"]) == 90, "finite stewardship budget")
    _check(int(ledger["spent"]) + int(ledger["remaining"]) == 90,
        "stewardship credits conserved")
    _check(int(ledger["remaining"]) >= 0, "credits never negative")
    var stock: int = 0
    for site in model.state["sites"]:
        var population: int = int(site["population"])
        stock += population
        _check(population >= 0 and population <= 50, "bounded fish stock")
        _check(int(site["habitat"]) >= 0 and int(site["habitat"]) <= 95,
            "bounded habitat condition")
        _check(int(site["temperature"]) >= -5 and int(site["temperature"]) <= 40,
            "bounded water temperature")
        _check(int(site["last_cast_epoch"]) <= int(model.state["epoch"]),
            "cast epoch never future")
    _check(stock == 72 + int(ledger["births"]) - int(ledger["deaths"]) - (
        int(ledger["caught"])), "founders + recruitment - deaths - catches = live fish")

func _climate(epoch: int) -> Dictionary:
    var season: String = ["Spring", "Summer", "Autumn", "Winter"][
        int((epoch - 1) / 14) % 4]
    var weather: String = "Storm" if epoch % 23 == 0 else (
        "Drought" if epoch % 17 == 0 else (
        "Rain" if epoch % 9 == 0 else (
        "Mist" if epoch % 11 == 0 else "Clear")))
    return {"season":season, "weather":weather}

func _causal_habitat() -> void:
    var improved = domain_script.new()
    var control = domain_script.new()
    _check(improved.steward(0, 1)["ok"], "player improves spawning habitat")
    for epoch in range(2, 31):
        _check(improved.advance_day(epoch, _climate(epoch)["season"], "Clear")["ok"],
            "improved wetland advances")
        _check(control.advance_day(epoch, _climate(epoch)["season"], "Clear")["ok"],
            "untreated wetland advances")
    _check(int(improved.state["sites"][0]["population"]) > int(
        control.state["sites"][0]["population"]),
        "restoration causally increases recruitment without instant fish grant")
    _check(int(improved.state["ledger"]["caught"]) == 0,
        "restoration does not create caught fish")
    _conservation(improved)
    _conservation(control)

func _replay(adversarial: bool) -> String:
    var model = domain_script.new()
    _check(int(model.state["epoch"]) == 1, "initial monotonic day epoch")
    _check(model.describe_site(0).contains("Glimmer Lake"),
        "player-readable site and fish information")
    _check(model.describe_site(-1).contains("Unknown"), "invalid site feedback")
    _check(model.forecast(0, 1)["ok"], "starter rod can inspect lake")
    _check(not model.forecast(-1, 1)["ok"], "invalid site denied")
    _check(not model.forecast(0, 4)["ok"], "unknown rod tier denied")
    _check(not model.forecast(2, 1)["eligible"], "marsh requires stronger rod")
    var initial: String = JSON.stringify(model.save_state())
    _check(not model.cast(0, 1, 2)["ok"], "future fishing denied")
    _check(not model.cast(2, 1, 1)["ok"], "underpowered rod denied")
    _check(not model.steward(3, 1)["ok"], "invalid stewardship denied")
    _check(not model.advance_day(3, "Spring", "Clear")["ok"],
        "skipped day denied")
    _check(not model.advance_day(2, "Winter", "Clear")["ok"],
        "invalid 56-day season denied")
    _check(not model.advance_day(2, "Spring", "Monsoon")["ok"],
        "invalid climate denied")
    _check(JSON.stringify(model.save_state()) == initial,
        "all rejected actions are atomic")
    _check(model.steward(0, 1)["ok"], "player restores lake spawning habitat")
    var before_cast: int = int(model.state["sites"][0]["population"])
    var result: Dictionary = model.cast(0, 1, 1)
    _check(result["ok"] and result["caught"], "starter lake catch succeeds")
    _check(int(model.state["sites"][0]["population"]) == before_cast - 1,
        "successful catch removes exactly one fish")
    _check(int(model.state["ledger"]["caught"]) == 1,
        "catch ledger records one fish")
    _check(result["message"].contains("no inventory credited"),
        "model cannot grant live inventory")
    _check(result["proposal_id"] == "f15:1:0",
        "deterministic proposal identity, not authority")
    var after_cast: String = JSON.stringify(model.save_state())
    _check(not model.cast(0, 3, 1)["ok"], "second same-day cast denied")
    _check(not model.steward(0, 1)["ok"], "second same-day restoration denied")
    _check(JSON.stringify(model.save_state()) == after_cast,
        "duplicate actions cannot mint resources")
    _conservation(model)
    for epoch in range(2, 113):
        var climate: Dictionary = _climate(epoch)
        _check(model.advance_day(epoch, climate["season"], climate["weather"])["ok"],
            "advance exact day %d" % epoch)
        var after_day: String = JSON.stringify(model.save_state())
        _check(not model.advance_day(epoch, climate["season"], climate["weather"])["ok"],
            "duplicate daily transition denied")
        _check(JSON.stringify(model.save_state()) == after_day,
            "duplicate daily transition atomic")
        if epoch % 14 == 0 and int(model.state["sites"][0]["habitat"]) < 95:
            _check(model.steward(0, epoch)["ok"], "stewardship advances habitat")
        if climate["season"] == "Winter":
            _check(not model.forecast(2, 3)["eligible"], "marsh winter closure")
            _check(not model.cast(2, 3, epoch)["ok"], "winter marsh cast denied")
        if epoch % 5 == 0:
            var forecast: Dictionary = model.forecast(0, 2)
            if forecast["eligible"]:
                var pre_stock: int = int(model.state["sites"][0]["population"])
                var pre_caught: int = int(model.state["ledger"]["caught"])
                var cast_result: Dictionary = model.cast(0, 2, epoch)
                _check(cast_result["ok"], "eligible model cast processed")
                var catch_count: int = 1 if cast_result["caught"] else 0
                _check(int(model.state["sites"][0]["population"]) == pre_stock - catch_count,
                    "model catch decrements actual stock only")
                _check(int(model.state["ledger"]["caught"]) == pre_caught + catch_count,
                    "catch ledger matches catch outcome")
                var after_attempt: String = JSON.stringify(model.save_state())
                _check(not model.cast(0, 2, epoch)["ok"], "repeat cast denied")
                _check(JSON.stringify(model.save_state()) == after_attempt,
                    "repeat cast cannot double debit")
        _conservation(model)
        if epoch % 14 == 0:
            var snapshot: String = JSON.stringify(model.save_state())
            var restored = domain_script.new()
            _check(restored.load_json(snapshot), "native JSON restore at epoch %d" % epoch)
            _check(JSON.stringify(restored.save_state()) == snapshot,
                "nested JSON roundtrip exactly matches")
            _check(model.load_state(restored.save_state()), "native dictionary restore")
            _check(int(model.state["epoch"]) == epoch, "epoch restored")
    _check(int(model.state["epoch"]) == 112, "two 56-day years completed")
    _check(int(model.state["ledger"]["caught"]) > 1, "viable multi-season gathering")
    if adversarial:
        var good: String = JSON.stringify(model.save_state())
        var attacks: Array = []
        var bad: Dictionary = model.save_state()
        bad["ledger"]["remaining"] += 1
        attacks.append(bad)
        bad = model.save_state()
        bad["ledger"]["caught"] += 1
        attacks.append(bad)
        bad = model.save_state()
        bad["ledger"]["births"] += 1
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][0]["population"] = 51
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][0]["population"] = -1
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][1]["habitat"] = 96
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][1]["temperature"] = 100
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][2]["last_cast_epoch"] = 113
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][2]["last_steward_epoch"] = 113
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"].append(bad["sites"][0].duplicate(true))
        attacks.append(bad)
        bad = model.save_state()
        bad["weather"] = "Monsoon"
        attacks.append(bad)
        bad = model.save_state()
        bad["season"] = "Winter"
        attacks.append(bad)
        bad = model.save_state()
        bad["version"] = 2
        attacks.append(bad)
        bad = model.save_state()
        bad["untrusted"] = true
        attacks.append(bad)
        bad = model.save_state()
        bad["ledger"]["spent"] = 1.5
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][0]["habitat"] = NAN
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][1]["population"] = true
        attacks.append(bad)
        for i in range(attacks.size()):
            _check(not model.load_state(attacks[i]), "hostile snapshot %d denied" % i)
            _check(JSON.stringify(model.save_state()) == good,
                "hostile snapshot %d leaves live model unchanged" % i)
        _check(not model.load_json("{broken"), "malformed JSON denied")
        _check(not model.load_state([]), "wrong root type denied")
        _check(JSON.stringify(model.save_state()) == good,
            "malformed payload cannot mutate valid snapshot")
    return JSON.stringify(model.save_state())

func _run() -> void:
    _causal_habitat()
    var first: String = _replay(true)
    var second: String = _replay(false)
    _check(first == second, "two complete deterministic runs match exactly")
    print("F15 NATIVE WETLAND ECOLOGY: %d assertions, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
