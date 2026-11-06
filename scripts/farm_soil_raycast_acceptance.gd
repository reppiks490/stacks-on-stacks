extends SceneTree
## Farming physical contact oracle: verify all 30 actual soil surfaces by raycast.
## Run: godot --headless --path . --script scripts/farm_soil_raycast_acceptance.gd
## Isolated farm fixture only; assembled-world seams and visual quality remain unverified.
const FarmScript = preload("res://scripts/farm.gd")
const BED_COUNT := 30
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var farm: Node3D = FarmScript.new()
    root.add_child(farm)
    farm.setup(null)
    await physics_frame
    if farm.beds.size() != BED_COUNT:
        push_error("Expected 30 beds, got %d" % farm.beds.size())
        quit(1)
        return
    var space := root.get_world_3d().direct_space_state
    var hits := 0
    for i in range(BED_COUNT):
        var holder: Node3D = farm.beds[i]["holder"]
        var collider: StaticBody3D = holder.get_node_or_null("SoilCollision")
        if collider == null:
            failures.append("Bed %d: no SoilCollision" % i)
            continue
        var shape: CollisionShape3D = collider.get_node_or_null("FurrowSurface")
        if shape == null or shape.disabled or shape.shape == null:
            failures.append("Bed %d: missing or disabled furrow shape" % i)
            continue
        if (collider.collision_layer & 1) == 0:
            failures.append("Bed %d: soil not on terrain collision layer" % i)
            continue
        for local in [Vector3.ZERO, Vector3(0.42, 0, 0.32), Vector3(-0.42, 0, -0.32)]:
            var point: Vector3 = holder.to_global(local)
            var query := PhysicsRayQueryParameters3D.create(
                point + Vector3.UP * 2.0, point + Vector3.DOWN * 2.0)
            query.collision_mask = 1
            query.collide_with_bodies = true
            query.collide_with_areas = false
            var hit: Dictionary = space.intersect_ray(query)
            if hit.is_empty():
                failures.append("Bed %d at %s: ray fell through soil" % [i, str(local)])
                continue
            if hit["collider"] != collider:
                failures.append("Bed %d at %s: hit wrong body %s" % [
                    i, str(local), str(hit["collider"])])
                continue
            if hit["normal"].y < 0.65:
                failures.append("Bed %d at %s: non-walkable normal %s" % [
                    i, str(local), str(hit["normal"])])
                continue
            if absf(float(hit["position"].y) - (holder.global_position.y + 0.1)) > 0.22:
                failures.append("Bed %d at %s: collision/visual height mismatch" % [
                    i, str(local)])
                continue
            hits += 1
    if failures.is_empty() and hits == 90:
        print("FARM_SOIL_RAYCAST PASS: 90/90 rays hit correct walkable bed bodies")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("FARM_SOIL_RAYCAST FAIL: %d valid, %d failures" % [hits, failures.size()])
        quit(1)
