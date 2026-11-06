extends SceneTree
## Farm-owned native negative collision regression.
## Run: godot --headless --path . --script scripts/farm_soil_boundary_acceptance.gd
## This checks soil collision extents and underside; it does not validate world chunks.
const FarmScript = preload("res://scripts/farm.gd")
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
    await physics_frame
    if farm.beds.size() != 30:
        push_error("Expected exactly 30 existing beds")
        quit(1)
        return
    var space := root.get_world_3d().direct_space_state
    var assertions := 0
    for i in range(30):
        var holder: Node3D = farm.beds[i]["holder"]
        var body: StaticBody3D = holder.get_node_or_null("SoilCollision")
        if body == null:
            failures.append("Bed %d missing soil physics body" % i)
            continue
        # Positive near-corner hits: all points remain within the 1.48m mesh.
        for offset in [Vector3(0.65, 0, 0.65), Vector3(-0.65, 0, 0.65),
                Vector3(0.65, 0, -0.65), Vector3(-0.65, 0, -0.65)]:
            var p: Vector3 = holder.to_global(offset)
            var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5,
                p + Vector3.DOWN * 1.5)
            ray.collision_mask = 1
            var hit: Dictionary = space.intersect_ray(ray)
            assertions += 1
            if hit.is_empty() or hit.get("collider") != body:
                failures.append("Bed %d corner %s not solid" % [i, str(offset)])
        # Outside the soil footprint and between 1.8m-spaced beds must be empty.
        for offset in [Vector3(0.87, 0, 0), Vector3(0, 0, 0.87)]:
            var p: Vector3 = holder.to_global(offset)
            var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5,
                p + Vector3.DOWN * 1.5)
            ray.collision_mask = 1
            assertions += 1
            if not space.intersect_ray(ray).is_empty():
                failures.append("Bed %d outside footprint %s collides" % [i, str(offset)])
    if failures.is_empty():
        print("FARM_SOIL_BOUNDARY PASS: %d corner/outside collision checks" % assertions)
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("FARM_SOIL_BOUNDARY FAIL: %d checks, %d failures" % [assertions, failures.size()])
        quit(1)
