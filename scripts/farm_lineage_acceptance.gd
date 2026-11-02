extends SceneTree
## F12 native Godot acceptance; executes real domain GDScript in headless engine.
## godot --headless --path . --script res://scripts/farm_lineage_acceptance.gd
var checks: int = 0
var failures: int = 0
var model_script = preload("res://scripts/farm_herd_lineage.gd")

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("F12 NATIVE FAILED: " + message)

func _find(records: Array, id: String) -> Dictionary:
    for animal in records:
        if str(animal["id"]) == id:
            return animal
    return {}

func _replay(check_all: bool) -> String:
    var herd = model_script.new()
    _check(herd.state["animals"].size() == 9, "nine founder animals")
    _check(herd.state["last_epoch"] == 1, "monotonic initial day")
    var healthy: Dictionary = {"hen-001":90, "hen-002":90, "hen-003":95, "hen-010":92,
        "hen-011":95}
    var start: Dictionary = herd.save_state()
    _check(not herd.request_breeding("hen-001", "cow-005", 1, healthy)["ok"],
        "cross-species pairing rejected")
    _check(not herd.request_breeding("hen-001", "hen-002", 2, healthy)["ok"],
        "stale/future epoch rejected")
    _check(not herd.request_breeding("hen-001", "hen-002", 1,
        {"hen-001":69, "hen-002":90})["ok"], "low welfare rejected")
    _check(JSON.stringify(herd.save_state()) == JSON.stringify(start),
        "failed commands do not mutate state")
    _check(herd.request_breeding("hen-001", "hen-002", 1, healthy)["ok"],
        "initial compatible pairing accepted")
    _check(not herd.request_breeding("hen-001", "hen-002", 1, healthy)["ok"],
        "duplicate pregnancy rejected")
    _check(not herd.advance_day(1)["ok"], "duplicate day rejected")
    _check(not herd.advance_day(4)["ok"], "skipped day rejected")
    var unique_births: Dictionary = {}
    for epoch in range(2, 113):
        var report: Dictionary = herd.advance_day(epoch)
        _check(bool(report["ok"]), "exact one-day advance %d" % epoch)
        for id in report["births"]:
            _check(not unique_births.has(id), "birth identity unique %s" % id)
            unique_births[id] = true
        if epoch == 15:
            _check(report["births"] == ["hen-010"], "first birth after 14 days")
            var child: Dictionary = _find(herd.state["animals"], "hen-010")
            _check(child["mother"] == "hen-001" and child["father"] == "hen-002",
                "first-generation ancestry")
            _check(child["sex"] == "male" and child["age_days"] == 0,
                "newborn age and deterministic sex")
            _check(not herd.request_breeding("hen-001", "hen-010", epoch, healthy)["ok"],
                "parent-child pairing prohibited")
        if epoch == 29:
            _check(herd.request_breeding("hen-001", "hen-002", epoch, healthy)["ok"],
                "mother can breed after recovery")
        if epoch == 43:
            _check(report["births"] == ["hen-011"], "second independent birth")
        if epoch == 71:
            _check(not herd.request_breeding("hen-011", "hen-010", epoch, healthy)["ok"],
                "full siblings prohibited")
            _check(not herd.request_breeding("hen-001", "hen-010", epoch, healthy)["ok"],
                "adult child cannot breed with parent")
            _check(herd.request_breeding("hen-003", "hen-010", epoch, healthy)["ok"],
                "unrelated founder and mature descendant eligible")
        if epoch == 85:
            _check(report["births"] == ["hen-012"], "second-generation birth")
            var grandchild: Dictionary = _find(herd.state["animals"], "hen-012")
            _check(grandchild["generation"] == 2, "offspring generation incremented")
            _check(grandchild["mother"] == "hen-003" and grandchild["father"] == "hen-010",
                "second-generation lineage persisted")
        if epoch == 86:
            _check(not herd.request_breeding("hen-001", "hen-002", epoch, healthy)["ok"],
                "species housing capacity prevents conception")
        if epoch == 99:
            var sibling_attempt: Dictionary = herd.request_breeding("hen-011", "hen-010", epoch, healthy)
            _check(not sibling_attempt["ok"] and "shared ancestry" in sibling_attempt["message"],
                "mature siblings explicitly denied by ancestry gate")
        var hen_count: int = 0
        for animal in herd.state["animals"]:
            _check(animal["age_days"] == epoch - animal["birth_epoch"],
                "derived age consistent %s day %d" % [animal["id"], epoch])
            _check(animal["generation"] >= 0 and animal["generation"] <= 4,
                "generation finite")
            for trait_name in ["vigor", "temperament", "productivity"]:
                _check(animal["traits"][trait_name] >= 0 and animal["traits"][trait_name] <= 100,
                    "heritable trait_name bounded")
            if animal["species"] == "hen":
                hen_count += 1
        _check(hen_count <= 6 and herd.state["animals"].size() <= 18,
            "capacity invariant day %d" % epoch)
        if epoch % 14 == 0:
            var serialized: String = JSON.stringify(herd.save_state())
            var clone = model_script.new()
            _check(clone.load_json(serialized), "JSON roundtrip day %d" % epoch)
            _check(JSON.stringify(clone.save_state()) == serialized,
                "nested state byte-stable day %d" % epoch)
            _check(herd.load_state(clone.save_state()), "native snapshot restore %d" % epoch)
    _check(herd.state["total_births"] == 3, "exactly three hen births")
    _check(herd.state["next_serial"] == 13, "monotonic identity serial")
    if check_all:
        var good: String = JSON.stringify(herd.save_state())
        var attacks: Array = []
        var tampered: Dictionary = herd.save_state()
        tampered["animals"][0]["age_days"] = -1
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["animals"][9]["mother"] = "cow-004"
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["animals"][9]["traits"]["vigor"] = 999
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["animals"][9]["generation"] = 0
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["animals"][9]["father"] = "hen-010"
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["animals"][9]["sex"] = "unknown"
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["total_births"] = 900
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["next_serial"] = 10
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["animals"].append(tampered["animals"][0].duplicate(true))
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["animals"][0]["pregnancy"] = {"father_id":"hen-002", "due_epoch":999999}
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["last_epoch"] = -1
        attacks.append(tampered)
        tampered = herd.save_state()
        tampered["animals"][0]["traits"]["vigor"] = NAN
        attacks.append(tampered)
        for i in range(attacks.size()):
            _check(not herd.load_state(attacks[i]), "hostile nested state %d rejected" % i)
            _check(JSON.stringify(herd.save_state()) == good,
                "hostile state %d rejected atomically" % i)
        _check(not herd.load_json("{not valid JSON"), "malformed JSON rejected")
        _check(JSON.stringify(herd.save_state()) == good, "malformed JSON leaves state unchanged")
        _check(not herd.load_state([]), "wrong root type rejected")
        _check(JSON.stringify(herd.save_state()) == good, "wrong root does not mutate state")
        _check("generation 2" in herd.describe("hen-012"), "player-readable lineage feedback")
        _check("No animal" in herd.describe("unknown"), "unknown animal feedback")
    return JSON.stringify(herd.save_state())

func _run() -> void:
    var first: String = _replay(true)
    var second: String = _replay(false)
    _check(first == second, "112-day replay determinism")
    var other = model_script.new()
    var welfare: Dictionary = {"cow-004":90, "cow-005":90, "sheep-007":90, "sheep-008":90}
    _check(other.request_breeding("cow-004", "cow-005", 1, welfare)["ok"],
        "cow gestation accepted")
    _check(other.request_breeding("sheep-007", "sheep-008", 1, welfare)["ok"],
        "sheep gestation accepted")
    for epoch in range(2, 31):
        var report: Dictionary = other.advance_day(epoch)
        _check(report["ok"], "multi-species day %d" % epoch)
        if epoch == 22:
            _check(report["births"] == ["sheep-010"], "sheep 21-day gestation")
        if epoch == 29:
            _check(report["births"] == ["cow-011"], "cow 28-day gestation")
    _check(other.state["total_births"] == 2, "multi-species birth count")
    _check(other.load_json(JSON.stringify(other.save_state())),
        "multi-species nested save restored")
    print("F12 NATIVE HERD LINEAGE: %d assertions, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
