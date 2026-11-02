extends RefCounted
## F10 optional planning-only terrain domain; does not edit live farm or inventory.
const W := 18
const H := 14
const N := 252
const YEAR_DAYS := 56
const KINDS := ["field", "path", "building"]
const ROOT := ["schema", "epoch", "next_id", "cells", "plans"]
const CELL := ["zone", "ref", "grade", "changed"]
const PLAN := ["id", "kind", "cells", "epoch"]
var state: Dictionary = {}

func _init() -> void:
    var cells: Array = []
    for i in range(N):
        var x: int = i % W
        var y: int = int(i / W)
        var bed: bool = x <= 11 and y <= 9 and x % 2 == 1 and y % 2 == 1
        var trail: bool = x == 12 and y <= 11
        var zone: String = "bed" if bed else ("trail" if trail else "free")
        var ref: int = (int((y - 1) / 2) * 6 + int((x - 1) / 2) + 1) if bed else 0
        cells.append({"zone": zone, "ref": ref, "grade": _grade(i), "changed": -1})
    state = {"schema": 1, "epoch": 0, "next_id": 31, "cells": cells, "plans": []}

func _grade(i: int) -> int:
    var x: int = i % W
    var y: int = int(i / W)
    if (x <= 11 and y <= 9 and x % 2 == 1 and y % 2 == 1) or (x == 12 and y <= 11):
        return 0
    return (x * 7 + y * 11 + x * y * 3) % 26

func _keys(d: Dictionary, names: Array) -> bool:
    if d.size() != names.size():
        return false
    for key in names:
        if not d.has(key):
            return false
    return true

func _neighbors(i: int) -> Array:
    var x: int = i % W
    var y: int = int(i / W)
    var result: Array = []
    if x > 0: result.append(i - 1)
    if x < W - 1: result.append(i + 1)
    if y > 0: result.append(i - W)
    if y < H - 1: result.append(i + W)
    return result

func _shape(kind: String, shape: Variant, cells: Array) -> bool:
    if not kind in KINDS or typeof(shape) != TYPE_ARRAY:
        return false
    if shape.size() < (2 if kind == "building" else 1) or shape.size() > 12:
        return false
    var previous: int = -1
    var low: int = 100
    var high: int = 0
    for i in shape:
        if typeof(i) != TYPE_INT or i <= previous or i < 0 or i >= N:
            return false
        previous = i
        var grade: int = cells[i]["grade"]
        low = mini(low, grade)
        high = maxi(high, grade)
        if grade > (16 if kind == "building" else (18 if kind == "field" else 24)):
            return false
    if kind == "building" and high - low > 9:
        return false
    var visited: Dictionary = {shape[0]: true}
    var queue: Array = [shape[0]]
    var cursor: int = 0
    while cursor < queue.size():
        var current: int = queue[cursor]
        cursor += 1
        for neighbor in _neighbors(current):
            if neighbor in shape and not visited.has(neighbor):
                visited[neighbor] = true
                queue.append(neighbor)
    return visited.size() == shape.size()

func _access(s: Dictionary) -> Dictionary:
    var reached: Dictionary = {}
    var queue: Array = []
    for i in range(N):
        if s["cells"][i]["zone"] in ["bed", "trail"]:
            reached[i] = true
            queue.append(i)
    var cursor: int = 0
    while cursor < queue.size():
        var current: int = queue[cursor]
        cursor += 1
        for neighbor in _neighbors(current):
            if not reached.has(neighbor) and s["cells"][neighbor]["zone"] == "path":
                reached[neighbor] = true
                queue.append(neighbor)
    return reached

func _touches(s: Dictionary, shape: Array, reached: Dictionary, allow_bed: bool) -> bool:
    for i in shape:
        for neighbor in _neighbors(i):
            if neighbor in shape or not reached.has(neighbor):
                continue
            var zone: String = s["cells"][neighbor]["zone"]
            if zone in ["trail", "path"] or (allow_bed and zone == "bed"):
                return true
    return false

func _valid(value: Variant) -> bool:
    if typeof(value) != TYPE_DICTIONARY:
        return false
    var s: Dictionary = value
    if not _keys(s, ROOT):
        return false
    for key in ["schema", "epoch", "next_id"]:
        if typeof(s[key]) != TYPE_INT:
            return false
    if s["schema"] != 1 or s["epoch"] < 0 or s["epoch"] > 2000000:
        return false
    if s["next_id"] < 31 or s["next_id"] > 200000031:
        return false
    if typeof(s["cells"]) != TYPE_ARRAY or s["cells"].size() != N:
        return false
    if typeof(s["plans"]) != TYPE_ARRAY or s["plans"].size() > 100:
        return false
    # Validate cells before plan geometry, so malformed nested payloads never throw.
    for i in range(N):
        var raw: Variant = s["cells"][i]
        if typeof(raw) != TYPE_DICTIONARY or not _keys(raw, CELL):
            return false
        var c: Dictionary = raw
        if typeof(c["zone"]) != TYPE_STRING or not c["zone"] in ["free", "bed", "trail", "field", "path", "building"]:
            return false
        for key in ["ref", "grade", "changed"]:
            if typeof(c[key]) != TYPE_INT:
                return false
        if c["grade"] != _grade(i) or c["changed"] < -1 or c["changed"] > s["epoch"]:
            return false
    var claims: Dictionary = {}
    var plan_epochs: Dictionary = {}
    for raw_plan in s["plans"]:
        if typeof(raw_plan) != TYPE_DICTIONARY or not _keys(raw_plan, PLAN):
            return false
        var p: Dictionary = raw_plan
        if typeof(p["id"]) != TYPE_INT or typeof(p["epoch"]) != TYPE_INT or typeof(p["kind"]) != TYPE_STRING:
            return false
        if p["id"] < 31 or p["id"] >= s["next_id"] or plan_epochs.has(p["id"]):
            return false
        if p["epoch"] < 1 or p["epoch"] > s["epoch"] or not _shape(p["kind"], p["cells"], s["cells"]):
            return false
        plan_epochs[p["id"]] = p["epoch"]
        for i in p["cells"]:
            if claims.has(i):
                return false
            claims[i] = p["id"]
    var bed_count: int = 0
    var trail_count: int = 0
    for i in range(N):
        var c: Dictionary = s["cells"][i]
        var x: int = i % W
        var y: int = int(i / W)
        if x <= 11 and y <= 9 and x % 2 == 1 and y % 2 == 1:
            var expected: int = int((y - 1) / 2) * 6 + int((x - 1) / 2) + 1
            if c["zone"] != "bed" or c["ref"] != expected or c["changed"] != -1:
                return false
            bed_count += 1
        elif x == 12 and y <= 11:
            if c["zone"] != "trail" or c["ref"] != 0 or c["changed"] != -1:
                return false
            trail_count += 1
        elif claims.has(i):
            if not c["zone"] in KINDS or c["ref"] != claims[i] or c["changed"] != plan_epochs[claims[i]]:
                return false
        elif c["zone"] != "free" or c["ref"] != 0:
            return false
    if bed_count != 30 or trail_count != 12:
        return false
    var reached: Dictionary = _access(s)
    for raw_plan in s["plans"]:
        var p: Dictionary = raw_plan
        for i in p["cells"]:
            if s["cells"][i]["zone"] != p["kind"]:
                return false
            if p["kind"] == "path" and not reached.has(i):
                return false
        if p["kind"] != "path" and not _touches(s, p["cells"], reached, p["kind"] == "field"):
            return false
    return true

func save_state() -> Dictionary:
    return state.duplicate(true)

func load_state(value: Variant) -> bool:
    if not _valid(value):
        return false
    state = (value as Dictionary).duplicate(true)
    return true

func _integer(v: Variant) -> Variant:
    if typeof(v) == TYPE_FLOAT and not is_nan(v) and not is_inf(v):
        if v >= -1.0 and v <= 200000031.0 and floor(v) == v:
            return int(v)
    return v

func load_json(raw: String) -> bool:
    var parser := JSON.new()
    if parser.parse(raw) != OK or typeof(parser.data) != TYPE_DICTIONARY:
        return false
    var s: Dictionary = (parser.data as Dictionary).duplicate(true)
    for key in ["schema", "epoch", "next_id"]:
        if s.has(key): s[key] = _integer(s[key])
    if typeof(s.get("cells")) == TYPE_ARRAY:
        for c in s["cells"]:
            if typeof(c) == TYPE_DICTIONARY:
                for key in ["ref", "grade", "changed"]:
                    if c.has(key): c[key] = _integer(c[key])
    if typeof(s.get("plans")) == TYPE_ARRAY:
        for p in s["plans"]:
            if typeof(p) != TYPE_DICTIONARY: continue
            for key in ["id", "epoch"]:
                if p.has(key): p[key] = _integer(p[key])
            if typeof(p.get("cells")) == TYPE_ARRAY:
                for i in range(p["cells"].size()):
                    p["cells"][i] = _integer(p["cells"][i])
    return load_state(s)

func _reject(message: String) -> Dictionary:
    return {"ok": false, "message": message}

func advance_day(epoch: int) -> Dictionary:
    if epoch < 1 or epoch > 2000000 or epoch != state["epoch"] + 1:
        return _reject("Advance by exactly one monotonic 56-day-calendar epoch.")
    var next: Dictionary = save_state()
    next["epoch"] = epoch
    if not _valid(next):
        return _reject("Invalid calendar transition.")
    state = next
    return {"ok": true, "year": int((epoch - 1) / YEAR_DAYS) + 1,
        "day_of_year": (epoch - 1) % YEAR_DAYS + 1,
        "message": "Planning calendar advanced; live beds unchanged."}

func preview(kind: String, shape: Variant, epoch: int) -> Dictionary:
    if epoch < 1 or epoch != state["epoch"]:
        return _reject("Planning requires the current day.")
    if not _shape(kind, shape, state["cells"]):
        return _reject("Disconnected, invalid or excessively steep footprint.")
    var low: int = 100
    var high: int = 0
    for i in shape:
        var c: Dictionary = state["cells"][i]
        if c["zone"] != "free":
            return _reject("Protected bed, trail or plan overlap.")
        if c["changed"] == epoch:
            return _reject("Cell already changed today.")
        low = mini(low, c["grade"])
        high = maxi(high, c["grade"])
    if not _touches(state, shape, _access(state), kind == "field"):
        return _reject("Connect to an accessible bed or trail.")
    return {"ok": true, "kind": kind, "cells": shape.duplicate(),
        "slope_max": high, "grade_range": high - low,
        "message": "Clear planning proposal; final construction needs approval."}

func place_plan(kind: String, shape: Variant, epoch: int) -> Dictionary:
    var quote: Dictionary = preview(kind, shape, epoch)
    if not quote["ok"]:
        return quote
    if state["plans"].size() >= 100:
        return _reject("Plan capacity reached.")
    var next: Dictionary = save_state()
    var pid: int = next["next_id"]
    next["next_id"] = pid + 1
    next["plans"].append({"id": pid, "kind": kind, "cells": shape.duplicate(), "epoch": epoch})
    for i in shape:
        next["cells"][i]["zone"] = kind
        next["cells"][i]["ref"] = pid
        next["cells"][i]["changed"] = epoch
    if not _valid(next):
        return _reject("Placement conservation failed.")
    state = next
    return {"ok": true, "id": pid, "kind": kind,
        "message": "Reserved %d planning cells; no resources spent." % shape.size()}

func cancel_plan(pid: int, epoch: int) -> Dictionary:
    if epoch < 1 or epoch != state["epoch"]:
        return _reject("Cancellation requires the current day.")
    var next: Dictionary = save_state()
    var index: int = -1
    for i in range(next["plans"].size()):
        if next["plans"][i]["id"] == pid:
            index = i
            break
    if index < 0:
        return _reject("Unknown or already cancelled plan.")
    var p: Dictionary = next["plans"][index]
    for i in p["cells"]:
        next["cells"][i]["zone"] = "free"
        next["cells"][i]["ref"] = 0
        next["cells"][i]["changed"] = epoch
    next["plans"].remove_at(index)
    if not _valid(next):
        return _reject("Cannot remove a required access route.")
    state = next
    return {"ok": true, "id": pid, "message": "Plan cancelled; no resource refund."}

func status() -> Dictionary:
    var counts: Dictionary = {"free": 0, "bed": 0, "trail": 0,
        "field": 0, "path": 0, "building": 0}
    for c in state["cells"]:
        counts[c["zone"]] += 1
    return {"epoch": state["epoch"], "counts": counts,
        "plans": state["plans"].duplicate(true),
        "message": "%d protected beds, %d public trail cells, %d proposals." %
            [counts["bed"], counts["trail"], state["plans"].size()]}
