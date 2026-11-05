extends SceneTree
## Physics-space acceptance for the isolated Farming furrow collision implementation.
## Run: godot --headless --path . --script res://tests/native_farm_soil_raycast_test.gd
## This tests real ray intersections; it does not claim player wall traversal or art quality.

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)

func _run() -> void:
    var script: Script = load("res://scripts/farm.gd")
    if script == null:
        push_error("Cannot load farm script")
        quit(1)
        return
    var farm: Node3D = script.new()
    root.add_child(farm)
    farm.setup(Node.new())
    _check(farm.beds.size() == 30, "Expected exactly 30 beds")
    # Allow physics server to register newly created StaticBody3D instances.
    await physics_frame
    await physics_frame
    var space: PhysicsDirectSpaceState3D = farm.get_world_3d().direct_space_state
    var hits := 0
    var misses := 0
    for plot in farm.beds:
        var holder: Node3D = plot["holder"]
        var point: Vector3 = holder.global_position
        var query := PhysicsRayQueryParameters3D.create(
            point + Vector3(0.0, 3.0, 0.0),
            point + Vector3(0.0, -3.0, 0.0),
            1
        )
        var result: Dictionary = space.intersect_ray(query)
        if result.is_empty():
            misses += 1
            _check(false, "%s: downward ground ray missed soil" % holder.name)
            continue
        var collider: Object = result.get("collider")
        var expected: StaticBody3D = holder.get_node_or_null("SoilCollision")
        _check(collider == expected, "%s: ray hit unexpected body" % holder.name)
        if collider == expected:
            hits += 1
    _check(hits == 30, "All 30 beds must have physical ray hits")
    print("FARM_SOIL_RAYCAST_TEST beds=%d hits=%d misses=%d failures=%d" % [
        farm.beds.size(), hits, misses, failures.size()
    ])
    quit(0 if failures.is_empty() else 1)
