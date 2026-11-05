extends SceneTree
# Native construction physics regression. Run:
# godot --headless --path . --script res://tests/native_construction_house_solid_test.gd
# Verifies a solid exterior and a traversable, intentionally open doorway.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    root.set_script(load("res://scripts/valley.gd"))
    get_root().add_child(root)
    root._house(Vector3.ZERO, Color.WHITE, Color.BROWN, 7.0)
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    var checks := [
        ["rear wall", Vector3(0, 1.2, -5), Vector3(0, 1.2, 0), true],
        ["left wall", Vector3(-5, 1.2, 0), Vector3(0, 1.2, 0), true],
        ["front wall", Vector3(2.2, 1.2, 5), Vector3(2.2, 1.2, 0), true],
        ["doorway", Vector3(0, 1.2, 5), Vector3(0, 1.2, 0), false],
        ["door lintel", Vector3(0, 3.0, 5), Vector3(0, 3.0, 0), true]
    ]
    var failures := 0
    for check in checks:
        var query := PhysicsRayQueryParameters3D.create(check[1], check[2])
        query.collision_mask = 1
        var hit := space.intersect_ray(query)
        var expected: bool = check[3]
        if (not hit.is_empty()) != expected:
            push_error("FAIL construction collision: %s expected_hit=%s actual_hit=%s" % [check[0], expected, not hit.is_empty()])
            failures += 1
        else:
            print("PASS construction collision: ", check[0])
    root.queue_free()
    if failures > 0:
        quit(1)
    else:
        print("PASS: five construction collision raycasts")
        quit(0)
