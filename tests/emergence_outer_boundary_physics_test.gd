extends SceneTree
## Native physics regression: world perimeter is solid, interior chunk seams remain open.
## godot --headless --path . --script res://tests/emergence_outer_boundary_physics_test.gd
const WorldScript = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        push_error(label)

func _run() -> void:
    var world: Node3D = WorldScript.new()
    root.add_child(world)
    var cases := [
        {"key": Vector2i(0, 16), "start": Vector3(-2405, 0, 75), "end": Vector3(-2395, 0, 75), "hit": true},
        {"key": Vector2i(31, 16), "start": Vector3(2405, 0, 75), "end": Vector3(2395, 0, 75), "hit": true},
        {"key": Vector2i(16, 0), "start": Vector3(75, 0, -2405), "end": Vector3(75, 0, -2395), "hit": true},
        {"key": Vector2i(16, 31), "start": Vector3(75, 0, 2405), "end": Vector3(75, 0, 2395), "hit": true},
        {"key": Vector2i(17, 17), "start": Vector3(300, 0, 220), "end": Vector3(300, 0, 230), "hit": false}
    ]
    for item in cases:
        var chunk := Node3D.new()
        var key: Vector2i = item["key"]
        chunk.position = Vector3(-2400 + (key.x + 0.5) * 150, 0, -2400 + (key.y + 0.5) * 150)
        world.add_child(chunk)
        world._install_outer_boundary(chunk, key)
    await physics_frame
    await physics_frame
    var space := world.get_world_3d().direct_space_state
    for item in cases:
        var ray := PhysicsRayQueryParameters3D.create(item["start"], item["end"])
        ray.collision_mask = 1
        var found := not space.intersect_ray(ray).is_empty()
        _check(found == item["hit"], "Boundary case %s expected=%s actual=%s" % [item["key"], item["hit"], found])
    print("EMERGENCE_OUTER_BOUNDARY cases=", cases.size(), " failures=", failures.size())
    world.queue_free()
    quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
    call_deferred("_run")
