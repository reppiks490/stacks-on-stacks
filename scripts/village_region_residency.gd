extends RefCounted
## V17: deterministic, engine-neutral resident admission for streamed settlements.
## Pure data adapter: no scene creation, economy mutation or player-save writes.
const GRID := 32
const CHUNK_SIZE := 150
const WORLD_SIZE := 4800
const MAX_ACTIVE_CHUNKS := 9
const MAX_RESIDENTS_PER_CHUNK := 24

static func valid_chunk(x: int, z: int) -> bool:
    return x >= 0 and z >= 0 and x < GRID and z < GRID

static func chunk_for_position(x: float, z: float) -> Vector2i:
    if not is_finite(x) or not is_finite(z):
        return Vector2i(-1, -1)
    if x < 0.0 or z < 0.0 or x >= WORLD_SIZE or z >= WORLD_SIZE:
        return Vector2i(-1, -1)
    return Vector2i(int(floor(x / CHUNK_SIZE)), int(floor(z / CHUNK_SIZE)))

static func neighborhood(center: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    if not valid_chunk(center.x, center.y):
        return result
    for z in range(maxi(0, center.y - 1), mini(GRID - 1, center.y + 1) + 1):
        for x in range(maxi(0, center.x - 1), mini(GRID - 1, center.x + 1) + 1):
            result.append(Vector2i(x, z))
    return result

static func validate_destinations(entries: Array) -> String:
    if entries.size() != 28:
        return "expected exactly 28 atlas destinations"
    var ids := {}
    for entry in entries:
        if not (entry is Dictionary):
            return "destination is not a dictionary"
        var rid: String = str(entry.get("id", ""))
        if rid.is_empty() or ids.has(rid):
            return "missing or duplicate destination id"
        ids[rid] = true
        var x: Variant = entry.get("x", null)
        var z: Variant = entry.get("z", null)
        if not (x is int or x is float) or not (z is int or z is float):
            return "destination has invalid coordinates"
        if chunk_for_position(float(x), float(z)) == Vector2i(-1, -1):
            return "destination outside continental bounds"
        if not entry.has("kind") or not str(entry["kind"]) in ["village", "town", "city", "kingdom", "landmark"]:
            return "destination kind unsupported"
    return ""

static func active_residents(entries: Array, center: Vector2i) -> Array:
    var result: Array = []
    var active := neighborhood(center)
    var seen := {}
    var per_chunk := {}
    for resident in entries:
        if not (resident is Dictionary):
            continue
        var rid: String = str(resident.get("id", ""))
        if rid.is_empty() or seen.has(rid):
            continue
        var x: Variant = resident.get("x", null)
        var z: Variant = resident.get("z", null)
        if not (x is int or x is float) or not (z is int or z is float):
            continue
        var chunk := chunk_for_position(float(x), float(z))
        if not active.has(chunk):
            continue
        var key := "%d:%d" % [chunk.x, chunk.y]
        if int(per_chunk.get(key, 0)) >= MAX_RESIDENTS_PER_CHUNK:
            continue
        per_chunk[key] = int(per_chunk.get(key, 0)) + 1
        seen[rid] = true
        result.append(resident.duplicate(true))
    return result

static func can_interact(last_epoch: Dictionary, resident_id: String, day_epoch: int) -> bool:
    if day_epoch < 1 or resident_id.is_empty():
        return false
    # Reject time regression: stale commands must never re-award interactions.
    var previous: Variant = last_epoch.get(resident_id, 0)
    if not (previous is int) or int(previous) < 0:
        return false
    return day_epoch > int(previous)

static func mark_interaction(last_epoch: Dictionary, resident_id: String, day_epoch: int) -> bool:
    if not can_interact(last_epoch, resident_id, day_epoch):
        return false
    last_epoch[resident_id] = day_epoch
    return true
