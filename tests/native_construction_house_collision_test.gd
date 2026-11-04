extends SceneTree
# Native physics regression for the existing launch-scene houses.
# Run: godot --headless --path . --script res://tests/native_construction_house_collision_test.gd
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures.append(label)
        push_error("FAIL: " + label)
    else:
        print("PASS: " + label)

func _cast(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(start, finish)
    query.collision_mask = 1
    return space.intersect_ray(query)

func _run() -> void:
    var valley_script: Script = load("res://scripts/valley.gd")
    _check(valley_script != null, "valley script loads")
    if valley_script == null:
        quit(1)
        return
    var valley: Node3D = valley_script.new()
    root.add_child(valley)
    valley.setup(null)
    for frame in range(4):
        await physics_frame
    var space := root.get_world_3d().direct_space_state
    var houses := valley.get_children().filter(func(node): return node is StaticBody3D and node.name == "SolidHouse")
    _check(houses.size() == 6, "all six launch houses have static collision bodies")
    for house in houses:
        var center: Vector3 = house.global_position
        var width: float = 7.0 if is_equal_approx(center.x, -23.0) else (8.0 if is_equal_approx(center.x, -4.0) else 6.0)
        var prefix := "house at " + str(center)
        var wall_hit := _cast(space, center + Vector3(0, 1.5, -4.0), center + Vector3(0, 1.5, -1.5))
        _check(wall_hit.get("collider") == house, prefix + " back wall blocks ray")
        var side_hit := _cast(space, center + Vector3(-width * 0.5 - 2.0, 1.5, 0), center + Vector3(-width * 0.5 + 1.0, 1.5, 0))
        _check(side_hit.get("collider") == house, prefix + " side wall blocks ray")
        var doorway_hit := _cast(space, center + Vector3(0, 1.4, 3.8), center + Vector3(0, 1.4, 1.5))
        _check(doorway_hit.is_empty(), prefix + " doorway stays traversable")
        var floor_hit := _cast(space, center + Vector3(0, 2.0, 0), center + Vector3(0, -0.8, 0))
        _check(not floor_hit.is_empty(), prefix + " interior floor catches downward ray")
    valley.queue_free()
    await process_frame
    print("CONSTRUCTION_NATIVE_COLLISION: " + ("PASS" if failures.is_empty() else "FAIL") + " (" + str(failures.size()) + " failures)")
    quit(0 if failures.is_empty() else 1)
