extends SceneTree
## Launch-scene construction collision oracle. Run:
## godot --headless --path . --script res://tests/construction/test_launch_house_wall_physics.gd
## A passing result requires the ordinary valley houses to be physically solid.
const ValleyScript = preload("res://scripts/valley.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var valley := Node3D.new()
    valley.set_script(ValleyScript)
    world.add_child(valley)
    valley.setup(null)
    # Allow Godot physics server to register newly created static bodies.
    await physics_frame
    await physics_frame
    var space := world.get_world_3d().direct_space_state
    # The existing farmhouse is centered (-23,0,-14), width 7, depth 5.2.
    # These rays start outside each facade at standing torso height.
    var cases := [
        ["farmhouse_front", Vector3(-23, 1.4, -9), Vector3(-23, 1.4, -15)],
        ["farmhouse_back", Vector3(-23, 1.4, -19), Vector3(-23, 1.4, -13)],
        ["farmhouse_left", Vector3(-28, 1.4, -14), Vector3(-22, 1.4, -14)],
        ["farmhouse_right", Vector3(-18, 1.4, -14), Vector3(-24, 1.4, -14)],
        ["town_front", Vector3(22, 1.4, 15), Vector3(22, 1.4, 9)]
    ]
    for sample in cases:
        var query := PhysicsRayQueryParameters3D.create(sample[1], sample[2])
        query.collision_mask = 1
        var hit := space.intersect_ray(query)
        if hit.is_empty():
            failures.append(str(sample[0]) + ": wall has no physics collision")
    if failures.is_empty():
        print("PASS: five launch-scene facade collision rays")
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
    world.queue_free()
    quit(0 if failures.is_empty() else 1)
