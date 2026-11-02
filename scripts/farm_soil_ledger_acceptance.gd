extends SceneTree
## Native Godot F01 regression: 112 monotonic days, thirty beds, eight checkpoints.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("F01 SOIL ACCEPTANCE FAILED: " + message)

func _flags(epoch: int) -> Array:
    var result: Array = []
    for i in range(30):
        result.append((i + epoch) % 3 == 0)
    return result

func _run() -> void:
    var model = load("res://scripts/farm_soil_ledger.gd").new()
    var replay = load("res://scripts/farm_soil_ledger.gd").new()
    _check(model.balance_error() == 0, "initial four-element conservation")
    _check(model.save_state()["beds"].size() == 30, "thirty beds")
    _check(not model.act(0, "compost", 1)["ok"], "no action before first day")
    _check(not model.advance_day(2, 0, _flags(2))["ok"], "cannot skip day")
    _check(not model.advance_day(1, -1, _flags(1))["ok"], "negative rain denied")
    _check(not model.advance_day(1, 10, [true])["ok"], "invalid crop flags denied")
    _check(model.save_state() == replay.save_state(), "invalid calls atomic")

    for epoch in range(1, 113):
        var rain: int = 85 if epoch % 7 == 0 else (30 if epoch % 4 == 0 else 0)
        var flags: Array = _flags(epoch)
        var a: Dictionary = model.advance_day(epoch, rain, flags)
        var b: Dictionary = replay.advance_day(epoch, rain, flags)
        _check(bool(a.get("ok", false)) and bool(b.get("ok", false)), "daily step %d" % epoch)
        _check(model.balance_error() == 0 and replay.balance_error() == 0,
            "four-store conservation day %d" % epoch)
        var before_repeat: Dictionary = model.save_state()
        _check(not model.advance_day(epoch, rain, flags)["ok"], "duplicate day denied %d" % epoch)
        _check(model.save_state() == before_repeat, "duplicate day atomic %d" % epoch)

        var index: int = (epoch * 7) % 30
        var action: String = "compost" if epoch % 3 == 0 else ("leaf_mulch" if epoch % 3 == 1 else "cultivate")
        var care_a: Dictionary = model.act(index, action, epoch)
        var care_b: Dictionary = replay.act(index, action, epoch)
        _check(bool(care_a.get("ok", false)) and bool(care_b.get("ok", false)),
            "bounded soil action day %d" % epoch)
        var after_care: Dictionary = model.save_state()
        _check(not model.act(index, action, epoch)["ok"], "duplicate amendment denied %d" % epoch)
        _check(model.save_state() == after_care, "duplicate amendment atomic %d" % epoch)
        _check(model.balance_error() == 0, "amendment conservation day %d" % epoch)
        _check(model.save_state() == replay.save_state(), "deterministic replay day %d" % epoch)

        for i in range(30):
            var soil: Dictionary = model.status(i)
            _check(int(soil["n"]) >= 0 and int(soil["n"]) <= 1000 and
                int(soil["p"]) >= 0 and int(soil["p"]) <= 1000 and
                int(soil["k"]) >= 0 and int(soil["k"]) <= 1000 and
                int(soil["carbon"]) >= 0 and int(soil["carbon"]) <= 1000,
                "finite stores day %d bed %d" % [epoch, i])
            _check(int(soil["compaction"]) >= 0 and int(soil["compaction"]) <= 100 and
                int(soil["ph_tenths"]) >= 40 and int(soil["ph_tenths"]) <= 90,
                "bounded soil scores day %d bed %d" % [epoch, i])
        if epoch % 14 == 0:
            var checkpoint: Dictionary = model.save_state()
            var restored = load("res://scripts/farm_soil_ledger.gd").new()
            _check(restored.load_state(checkpoint), "seasonal restore %d" % epoch)
            _check(restored.save_state() == checkpoint, "nested roundtrip %d" % epoch)
            _check(restored.balance_error() == 0, "restored conservation %d" % epoch)
            checkpoint["beds"][0]["n"] = 999
            _check(model.save_state() == replay.save_state(), "deep-copy isolation %d" % epoch)

    _check(int(model.save_state()["last_epoch"]) == 112, "two 56-day years")
    var stable: Dictionary = model.save_state()
    var invalids: Array = []
    var corrupt: Dictionary = stable.duplicate(true)
    corrupt["beds"][0]["n"] = -1
    invalids.append(corrupt)
    corrupt = stable.duplicate(true)
    corrupt["beds"][0]["ph_tenths"] = 91
    invalids.append(corrupt)
    corrupt = stable.duplicate(true)
    corrupt["beds"][0]["last_action_epoch"] = 113
    invalids.append(corrupt)
    corrupt = stable.duplicate(true)
    corrupt["added"]["carbon"] = int(corrupt["added"]["carbon"]) + 1
    invalids.append(corrupt)
    corrupt = stable.duplicate(true)
    corrupt["beds"].pop_back()
    invalids.append(corrupt)
    corrupt = stable.duplicate(true)
    corrupt["uptake"]["n"] = "forged"
    invalids.append(corrupt)
    corrupt = stable.duplicate(true)
    corrupt["beds"][0]["texture"] = 3
    invalids.append(corrupt)
    corrupt = stable.duplicate(true)
    corrupt["schema"] = 2
    invalids.append(corrupt)
    for i in range(invalids.size()):
        _check(not model.load_state(invalids[i]), "invalid snapshot denied %d" % i)
        _check(model.save_state() == stable, "invalid snapshot atomic %d" % i)
    _check(not model.act(30, "compost", 112)["ok"], "invalid bed denied")
    _check(not model.act(0, "free_gold", 112)["ok"], "unknown action denied")
    _check(not model.advance_day(114, 0, _flags(114))["ok"], "skipped day denied")
    _check(model.save_state() == stable, "late invalid calls atomic")

    var planted = load("res://scripts/farm_soil_ledger.gd").new()
    var empty = load("res://scripts/farm_soil_ledger.gd").new()
    var full_flags: Array = []
    var none_flags: Array = []
    for i in range(30):
        full_flags.append(true)
        none_flags.append(false)
    _check(planted.advance_day(1, 0, full_flags)["ok"], "planted step")
    _check(empty.advance_day(1, 0, none_flags)["ok"], "unplanted step")
    _check(int(planted.status(0)["n"]) < int(empty.status(0)["n"]),
        "crop presence causes nutrient uptake")
    _check(planted.balance_error() == 0 and empty.balance_error() == 0,
        "causal control conservation")
    print("EVERBLOOM F01 SOIL NATIVE ACCEPTANCE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
