extends SceneTree
## F14 native Godot 112-day deterministic pollinator/ledger/save acceptance.
var checks: int = 0
var failures: int = 0
var domain_script = preload("res://scripts/farm_pollinator_network.gd")

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("F14 NATIVE FAILED: " + message)

func _bloom(level: int = 2) -> Array:
    var result: Array = []
    for i in range(30):
        result.append(level)
    return result

func _conservation(model) -> void:
    var ledger: Dictionary = model.state["ledger"]
    _check(int(ledger["budget"]) == 60, "fixed model budget")
    _check(int(ledger["spent"]) + int(ledger["remaining"]) == 60,
        "care budget conserved")
    _check(int(ledger["remaining"]) >= 0, "no negative care credits")
    var colony_total: int = 0
    _check(model.state["sites"].size() == 6, "six habitat nodes")
    _check(model.state["bloom"].size() == 30, "thirty crop bed inputs")
    for site in model.state["sites"]:
        var colony: int = int(site["colony"])
        colony_total += colony
        _check(colony >= 0 and colony <= 100, "bounded colony")
        _check(int(site["flowers"]) >= 0 and int(site["flowers"]) <= 5,
            "bounded flowering habitat")
        _check(int(site["nectar"]) >= 0 and int(site["nectar"]) <= 100,
            "bounded nectar")
        _check(int(site["shelter"]) >= 0 and int(site["shelter"]) <= 3,
            "bounded shelter")
    _check(colony_total == 72 + int(ledger["births"]) - int(ledger["deaths"]),
        "founders + births - deaths = living colony; migration conserved")

func _replay(adversarial: bool) -> String:
    var model = domain_script.new()
    _check(model.state["epoch"] == 1, "initial monotonic epoch")
    _check(model.describe_site(0).contains("Habitat 1"), "player-readable habitat feedback")
    _check(model.describe_site(-1).contains("Unknown"), "invalid site feedback")
    var initial: String = JSON.stringify(model.save_state())
    _check(not model.act(-1, "flower_patch", 1)["ok"], "invalid site rejected")
    _check(not model.act(0, "unknown", 1)["ok"], "unknown action rejected")
    _check(not model.act(0, "flower_patch", 2)["ok"], "future action rejected")
    _check(not model.advance_day(3, "Clear", "Spring", _bloom())["ok"],
        "skipped epoch rejected")
    _check(not model.advance_day(2, "Monsoon", "Spring", _bloom())["ok"],
        "unknown weather rejected")
    _check(not model.advance_day(2, "Clear", "Spring", [2])["ok"],
        "wrong bloom size rejected")
    _check(JSON.stringify(model.save_state()) == initial, "rejected actions atomic")
    var before: Dictionary = model.preview_yield(0, 100)
    _check(before["ok"] and int(before["bonus"]) >= 0, "finite baseline yield proposal")
    _check(model.act(0, "flower_patch", 1)["ok"], "player establishes flowers")
    var after: Dictionary = model.preview_yield(0, 100)
    _check(int(after["total"]) > int(before["total"]),
        "habitat improvement causally increases projected crop yield")
    _check(after["message"].contains("not granted"), "forecast never mints crops")
    var proposal_snapshot: String = JSON.stringify(model.save_state())
    _check(not model.act(0, "nesting", 1)["ok"], "same-site daily duplicate denied")
    _check(JSON.stringify(model.save_state()) == proposal_snapshot, "duplicate atomic")
    _check(model.act(1, "corridor", 1)["ok"], "player establishes corridor")
    _conservation(model)
    for epoch in range(2, 113):
        var season: String = ["Spring", "Summer", "Autumn", "Winter"][
            int((epoch - 1) / 14) % 4]
        var weather: String = "Storm" if epoch % 23 == 0 else (
            "Drought" if epoch % 17 == 0 else (
            "Rain" if epoch % 9 == 0 else "Clear"))
        var bloom: Array = _bloom()
        if epoch % 19 == 0:
            bloom[0] = 0
        _check(model.advance_day(epoch, weather, season, bloom)["ok"],
            "advance exactly one day %d" % epoch)
        var after_day: String = JSON.stringify(model.save_state())
        _check(not model.advance_day(epoch, weather, season, bloom)["ok"],
            "duplicate daily transition rejected")
        _check(JSON.stringify(model.save_state()) == after_day,
            "duplicate daily transition atomic")
        if epoch == 2:
            _check(model.act(0, "corridor", epoch)["ok"], "connect first habitat")
            _check(model.act(1, "flower_patch", epoch)["ok"], "establish second bloom")
        if epoch == 3:
            _check(model.act(0, "nesting", epoch)["ok"], "shelter protects colony")
            _check(model.act(1, "nesting", epoch)["ok"], "second shelter established")
        var proposal: Dictionary = model.preview_yield(0, 100)
        _check(proposal["ok"], "valid yield proposal")
        _check(int(proposal["total"]) >= 100 and int(proposal["total"]) <= 150,
            "bounded yield bonus")
        if epoch % 19 == 0 or season == "Winter" or weather == "Storm":
            _check(int(proposal["bonus"]) == 0, "no pollination without active flowers")
        _check(not model.preview_yield(30, 100)["ok"], "unknown bed denied")
        _check(not model.preview_yield(0, -1)["ok"], "negative base yield denied")
        _conservation(model)
        if epoch % 14 == 0:
            var snapshot: String = JSON.stringify(model.save_state())
            var restored = domain_script.new()
            _check(restored.load_json(snapshot), "nested JSON restoration at day %d" % epoch)
            _check(JSON.stringify(restored.save_state()) == snapshot,
                "byte-stable canonical JSON after restore")
            _check(model.load_state(restored.save_state()), "native save-state restore")
            _check(model.state["epoch"] == epoch, "epoch restored")
    _check(model.state["epoch"] == 112, "two complete 56-day years")
    _check(int(model.state["ledger"]["migrations"]) > 0,
        "corridors move existing pollinators without creating them")
    if adversarial:
        var good: String = JSON.stringify(model.save_state())
        var attacks: Array = []
        var bad: Dictionary = model.save_state()
        bad["ledger"]["remaining"] += 1
        attacks.append(bad)
        bad = model.save_state()
        bad["ledger"]["births"] += 1
        attacks.append(bad)
        bad = model.save_state()
        bad["ledger"]["deaths"] += 1
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][0]["colony"] = 101
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][0]["flowers"] = -1
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][1]["nectar"] = 101
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][1]["corridor"] = 1
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][2]["last_action_epoch"] = 113
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"][2]["shelter"] = 4
        attacks.append(bad)
        bad = model.save_state()
        bad["sites"].append(bad["sites"][0].duplicate(true))
        attacks.append(bad)
        bad = model.save_state()
        bad["bloom"][0] = 5
        attacks.append(bad)
        bad = model.save_state()
        bad["bloom"][1] = 1.5
        attacks.append(bad)
        bad = model.save_state()
        bad["bloom"][2] = NAN
        attacks.append(bad)
        bad = model.save_state()
        bad["weather"] = "Monsoon"
        attacks.append(bad)
        bad = model.save_state()
        bad["version"] = 2
        attacks.append(bad)
        bad = model.save_state()
        bad["untrusted"] = true
        attacks.append(bad)
        for i in range(attacks.size()):
            _check(not model.load_state(attacks[i]), "hostile snapshot %d rejected" % i)
            _check(JSON.stringify(model.save_state()) == good,
                "hostile snapshot %d leaves model unchanged" % i)
        _check(not model.load_json("{broken"), "malformed JSON denied")
        _check(not model.load_state([]), "wrong root denied")
        _check(JSON.stringify(model.save_state()) == good, "failed restores atomic")
        _check(not model.advance_day(114, "Clear", "Spring", _bloom())["ok"],
            "skipped third-year day denied")
        _check(JSON.stringify(model.save_state()) == good, "future epoch atomic")
        var budget_test = domain_script.new()
        for epoch in range(1, 40):
            for index in range(6):
                var site: Dictionary = budget_test.state["sites"][index]
                var action: String = "flower_patch" if int(site["flowers"]) < 5 else (
                    "nesting" if int(site["shelter"]) < 3 else "corridor")
                var prior: String = JSON.stringify(budget_test.save_state())
                var result: Dictionary = budget_test.act(index, action, epoch)
                if not result["ok"]:
                    _check(JSON.stringify(budget_test.save_state()) == prior,
                        "exhausted budget and full habitat reject atomically")
            _conservation(budget_test)
            if epoch < 39:
                _check(budget_test.advance_day(epoch + 1, "Clear", "Summer", _bloom())["ok"],
                    "budget stress advances epoch")
        _check(int(budget_test.state["ledger"]["remaining"]) >= 0,
            "long-run budget never negative")
    return JSON.stringify(model.save_state())

func _run() -> void:
    var first: String = _replay(true)
    var second: String = _replay(false)
    _check(first == second, "two-year replay deterministic")
    print("F14 NATIVE POLLINATOR NETWORK: %d assertions, %d failures" % [
        checks, failures])
    quit(1 if failures > 0 else 0)
