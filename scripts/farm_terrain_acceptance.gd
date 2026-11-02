extends SceneTree
## Native Godot 4.x F10 acceptance; not a simulated Python substitute.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("F10 TERRAIN FAILED: " + message)

func _model():
    return load("res://scripts/farm_terrain_zoning.gd").new()

func _conserved(s: Dictionary) -> bool:
    var count: Dictionary = {"free": 0, "bed": 0, "trail": 0,
        "field": 0, "path": 0, "building": 0}
    for c in s["cells"]:
        if not count.has(c["zone"]): return false
        count[c["zone"]] += 1
    var planned: int = 0
    for p in s["plans"]:
        planned += p["cells"].size()
    return count["bed"] == 30 and count["trail"] == 12 and (
        count["free"] + count["bed"] + count["trail"] + planned == 252) and (
        planned == count["field"] + count["path"] + count["building"])

func _run() -> void:
    var a = _model()
    var b = _model()
    var initial: Dictionary = a.save_state()
    _check(initial == b.save_state(), "deterministic initial state")
    _check(initial["cells"].size() == 252, "bounded 18 by 14 grid")
    _check(_conserved(initial), "30 protected beds and 12 trail cells")
    _check(not a.advance_day(2)["ok"], "skipped initial day denied")
    _check(not a.place_plan("field", [0, 1, 18], 1)["ok"], "no early planning")
    _check(a.save_state() == initial, "early rejection atomic")
    var field_shape: Array = [0, 1, 18]
    var path_shape: Array = [121]
    var building_shape: Array = [122, 140]
    var path_id: int = -1
    var building_id: int = -1
    var started: int = Time.get_ticks_usec()
    for epoch in range(1, 113):
        var day_a: Dictionary = a.advance_day(epoch)
        var day_b: Dictionary = b.advance_day(epoch)
        _check(day_a == day_b and day_a["ok"], "deterministic calendar %d" % epoch)
        _check(day_a["year"] == int((epoch - 1) / 56) + 1, "56-day year %d" % epoch)
        var before: Dictionary = a.save_state()
        _check(not a.advance_day(epoch)["ok"], "duplicate day rejected %d" % epoch)
        _check(a.save_state() == before, "duplicate day atomic %d" % epoch)
        if epoch == 1:
            _check(a.preview("field", field_shape, epoch)["ok"], "L-shaped field quote")
            _check(not a.preview("field", [19], epoch)["ok"], "fixed crop bed protected")
            _check(not a.preview("path", [12], epoch)["ok"], "permanent trail protected")
            _check(not a.preview("field", [0, 2], epoch)["ok"], "disconnected shape denied")
            _check(not a.preview("field", [0, 0], epoch)["ok"], "duplicate cell denied")
            _check(not a.preview("field", [0.5], epoch)["ok"], "fractional cell denied")
            _check(not a.preview("building", [13, 14], epoch)["ok"], "steep building denied")
            _check(not a.preview("path", [251], epoch)["ok"], "disconnected path denied")
            _check(not a.preview("field", [252], epoch)["ok"], "out of range denied")
            var f_a: Dictionary = a.place_plan("field", field_shape, epoch)
            var f_b: Dictionary = b.place_plan("field", field_shape, epoch)
            _check(f_a == f_b and f_a["ok"] and f_a["id"] == 31, "original irregular plough reservation")
            _check(not a.place_plan("field", field_shape, epoch)["ok"], "overlap denied")
            var p_a: Dictionary = a.place_plan("path", path_shape, epoch)
            var p_b: Dictionary = b.place_plan("path", path_shape, epoch)
            _check(p_a == p_b and p_a["ok"], "connected path plan")
            path_id = p_a["id"]
            var build_a: Dictionary = a.place_plan("building", building_shape, epoch)
            var build_b: Dictionary = b.place_plan("building", building_shape, epoch)
            _check(build_a == build_b and build_a["ok"], "path-dependent building plan")
            building_id = build_a["id"]
            _check(not a.preview("field", [122], epoch)["ok"], "field/building collision denied")
            before = a.save_state()
            _check(not a.cancel_plan(path_id, epoch)["ok"], "cannot orphan building")
            _check(a.save_state() == before, "orphan rejection atomic")
            var c_a: Dictionary = a.cancel_plan(building_id, epoch)
            var c_b: Dictionary = b.cancel_plan(building_id, epoch)
            _check(c_a == c_b and c_a["ok"], "cancel building without refund")
            c_a = a.cancel_plan(path_id, epoch)
            c_b = b.cancel_plan(path_id, epoch)
            _check(c_a == c_b and c_a["ok"], "cancel unused path")
            _check(not a.place_plan("path", path_shape, epoch)["ok"], "same-day replay denied")
        elif epoch == 2 or epoch == 57:
            var p_a: Dictionary = a.place_plan("path", path_shape, epoch)
            var p_b: Dictionary = b.place_plan("path", path_shape, epoch)
            _check(p_a == p_b and p_a["ok"], "new-day path reservation %d" % epoch)
            path_id = p_a["id"]
            var build_a: Dictionary = a.place_plan("building", building_shape, epoch)
            var build_b: Dictionary = b.place_plan("building", building_shape, epoch)
            _check(build_a == build_b and build_a["ok"], "new-day building reservation %d" % epoch)
            building_id = build_a["id"]
        elif epoch == 56:
            var c_a: Dictionary = a.cancel_plan(building_id, epoch)
            var c_b: Dictionary = b.cancel_plan(building_id, epoch)
            _check(c_a == c_b and c_a["ok"], "year-end building cancellation")
            c_a = a.cancel_plan(path_id, epoch)
            c_b = b.cancel_plan(path_id, epoch)
            _check(c_a == c_b and c_a["ok"], "year-end path cancellation")
        _check(_conserved(a.save_state()), "252-cell occupancy conserved %d" % epoch)
        _check(a.save_state() == b.save_state(), "two-year deterministic replay %d" % epoch)
        if epoch % 14 == 0:
            var snapshot: Dictionary = a.save_state()
            var restored = _model()
            _check(restored.load_state(snapshot), "deep save restored %d" % epoch)
            _check(restored.save_state() == snapshot, "deep save equality %d" % epoch)
            var json_restored = _model()
            _check(json_restored.load_json(JSON.stringify(snapshot)), "JSON restore %d" % epoch)
            _check(json_restored.save_state() == snapshot, "JSON equality %d" % epoch)
    _check(a.save_state()["epoch"] == 112, "112 monotonic days completed")
    _check(a.status()["counts"]["bed"] == 30, "original bed count unchanged")
    _check(a.status()["counts"]["field"] == 3, "irregular field footprint persisted")
    _check(a.status()["counts"]["path"] == 1, "connected path persisted")
    _check(a.status()["counts"]["building"] == 2, "building footprint persisted")
    _check(a.status()["plans"].size() == 3, "all three plans retained")
    var stable: Dictionary = a.save_state()
    var bad: Dictionary = stable.duplicate(true)
    bad["cells"][19]["zone"] = "free"
    _check(not a.load_state(bad), "protected bed erasure rejected")
    bad = stable.duplicate(true)
    bad["cells"][12]["ref"] = 5
    _check(not a.load_state(bad), "trail tampering rejected")
    bad = stable.duplicate(true)
    bad["cells"][0]["grade"] = 99
    _check(not a.load_state(bad), "grade forgery rejected")
    bad = stable.duplicate(true)
    bad["cells"][0] = null
    _check(not a.load_state(bad), "malformed nested cell rejected")
    bad = stable.duplicate(true)
    bad["plans"][0]["cells"] = [0, 18, 1]
    _check(not a.load_state(bad), "unordered shape rejected")
    bad = stable.duplicate(true)
    bad["plans"][1]["id"] = bad["plans"][0]["id"]
    _check(not a.load_state(bad), "duplicate plan ID rejected")
    bad = stable.duplicate(true)
    bad["cells"][121]["ref"] = 999
    _check(not a.load_state(bad), "ghost occupancy rejected")
    bad = stable.duplicate(true)
    bad["cells"][121]["changed"] = 1
    _check(not a.load_state(bad), "forged creation epoch rejected")
    bad = stable.duplicate(true)
    bad["extra"] = true
    _check(not a.load_state(bad), "unknown root field rejected")
    bad = stable.duplicate(true)
    bad["cells"][0]["grade"] = 0.5
    _check(not a.load_json(JSON.stringify(bad)), "fractional JSON grade rejected")
    _check(not a.load_json("{broken"), "malformed JSON rejected")
    _check(a.save_state() == stable, "all hostile loads atomic")
    _check(a.save_state() == b.save_state(), "final deterministic equality")
    _check(_conserved(a.save_state()), "final occupancy conservation")
    print("EVERBLOOM F10 TERRAIN BENCH: %d microseconds, CI host only" % (Time.get_ticks_usec() - started))
    print("EVERBLOOM F10 TERRAIN NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
