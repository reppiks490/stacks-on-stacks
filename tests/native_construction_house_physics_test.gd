extends SceneTree
# Native physics acceptance for the isolated solid-house candidate.
# Run: godot --headless --path . --script res://tests/native_construction_house_physics_test.gd
# This is NOT a substitute for a 120-frame game smoke or visual walkthrough.
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures.append(label)
        push_error("FAIL: " + label)
    else:
        print("PASS: " + label)

func _cast(world: World3D, start: Vector3, finish: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(start, finish)
    query.collision_mask = 1
    return world.direct_space_state.intersect_ray(query)

func _run() -> void:
    var host := Node3D.new()
    host.name = "ConstructionPhysicsAcceptance"
    root.add_child(host)
    var valley := Node3D.new()
    valley.name = "TheLivingValley"
    valley.set_script(load("res://scripts/valley.gd"))
    host.add_child(valley)
    valley.setup(host)
    await physics_frame
    await physics_frame
    var world := host.get_world_3d()
    # Existing farmhouse center (-23,0,-14), width 7, depth 5.2.
    # Front plane z=-11.4; front door centered x=-23, clear below y=2.5.
    var wall_hit := _cast(world, Vector3(-25.0, 1.2, -10.0), Vector3(-25.0, 1.2, -12.0))
    _check(not wall_hit.is_empty(), "front facade wall blocks player-height ray")
    var door_hit := _cast(world, Vector3(-23.0, 1.2, -10.0), Vector3(-23.0, 1.2, -12.0))
    _check(door_hit.is_empty(), "intended front doorway remains open")
    var side_hit := _cast(world, Vector3(-27.5, 1.2, -14.0), Vector3(-26.0, 1.2, -14.0))
    _check(not side_hit.is_empty(), "side wall blocks player-height ray")
    var floor_hit := _cast(world, Vector3(-23.0, 1.0, -14.0), Vector3(-23.0, -1.0, -14.0))
    _check(not floor_hit.is_empty(), "house floor has physics support")
    var roof_hit := _cast(world, Vector3(-23.0, 5.0, -14.0), Vector3(-23.0, 3.5, -14.0))
    _check(not roof_hit.is_empty(), "house ceiling has collision")
    print("CONSTRUCTION_PHYSICS_RESULT failures=", failures.size())
    quit(0 if failures.is_empty() else 1)
