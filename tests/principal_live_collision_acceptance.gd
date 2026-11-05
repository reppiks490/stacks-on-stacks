extends SceneTree
## Principal native regression for the actual ordinary main scene.
## Run: godot --headless --path . --script res://tests/principal_live_collision_acceptance.gd
## This deliberately fails if the ordinary launch loses solid legacy geometry.
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert_hit(space: PhysicsDirectSpaceState3D, origin: Vector3, target: Vector3, label: String) -> void:
    var query := PhysicsRayQueryParameters3D.create(origin, target)
    query.collision_mask = 1
    var hit := space.intersect_ray(query)
    if hit.is_empty():
        failures.append(label + ": ray passed through expected solid geometry")
    else:
        print("PASS ", label, " collider=", hit["collider"].name)

func _run() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        push_error("Cannot load ordinary main scene")
        quit(1)
        return
    var root := packed.instantiate()
    get_root().add_child(root)
    await process_frame
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    _assert_hit(space, Vector3(-23, 2, -20), Vector3(-23, 2, -10), "farmhouse wall")
    _assert_hit(space, Vector3(-4, 2, -21), Vector3(-4, 2, -9), "second farmhouse wall")
    _assert_hit(space, Vector3(22, 2, 5), Vector3(22, 2, 15), "town house wall")
    _assert_hit(space, Vector3(-5, 0.6, -8), Vector3(-5, 0.6, -3), "shipping chest")
    _assert_hit(space, Vector3(30, 0.6, -2), Vector3(30, 0.6, 2), "monument pedestal")
    _assert_hit(space, Vector3(0, 5, 0), Vector3(0, -3, 0), "legacy floor")
    _assert_hit(space, Vector3(69, 2, 0), Vector3(75, 2, 0), "east safety boundary")
    _assert_hit(space, Vector3(-69, 2, 0), Vector3(-75, 2, 0), "west safety boundary")
    _assert_hit(space, Vector3(0, 2, 69), Vector3(0, 2, 75), "south safety boundary")
    _assert_hit(space, Vector3(0, 2, -69), Vector3(0, 2, -75), "north safety boundary")
    root.queue_free()
    await process_frame
    if not failures.is_empty():
        for failure in failures:
            push_error("FAIL " + failure)
        quit(1)
    else:
        print("PASS principal live-scene collision acceptance (10 probes)")
        quit(0)
