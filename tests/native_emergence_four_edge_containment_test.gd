extends SceneTree
## Native physics acceptance: all four outer world boundaries are solid.
## Run: godot --headless --path . --script res://tests/native_emergence_four_edge_containment_test.gd
const World = preload("res://scripts/continental_world.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, detail: String) -> void:
    if not ok:
        errors.append(detail)
        push_error(detail)

func _run() -> void:
    var world: Node3D = World.new()
    root.add_child(world)
    var cases := [
        {"cell": Vector2i(0, 16), "start": Vector3(-2395, 0, 75), "end": Vector3(-2405, 0, 75)},
        {"cell": Vector2i(31, 16), "start": Vector3(2395, 0, 75), "end": Vector3(2405, 0, 75)},
        {"cell": Vector2i(16, 0), "start": Vector3(75, 0, -2395), "end": Vector3(75, 0, -2405)},
        {"cell": Vector2i(16, 31), "start": Vector3(75, 0, 2395), "end": Vector3(75, 0, 2405)}
    ]
    for entry in cases:
        var key: Vector2i = entry["cell"]
        var chunk := Node3D.new()
        chunk.position = Vector3(-world.HALF + (key.x + 0.5) * world.CHUNK_SIDE, 0, -world.HALF + (key.y + 0.5) * world.CHUNK_SIDE)
        world.add_child(chunk)
        world._install_outer_boundary(chunk, key)
        _check(chunk.get_child_count() == 1, "expected one outer boundary for " + str(key))
    await physics_frame
    await physics_frame
    var space := world.get_world_3d().direct_space_state
    for entry in cases:
        var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(entry["start"], entry["end"]))
        _check(not hit.is_empty(), "missing physics containment: " + str(entry["cell"]))
        if not hit.is_empty():
            _check(hit.collider is StaticBody3D and hit.collider.name == "PhysicalWorldBoundary", "wrong collider at " + str(entry["cell"]))
    var interior := Node3D.new()
    world.add_child(interior)
    world._install_outer_boundary(interior, Vector2i(16, 16))
    _check(interior.get_child_count() == 0, "interior chunk incorrectly blocked")
    world.queue_free()
    if errors.is_empty():
        print("PASS: four physical world edges and interior clearance")
        quit(0)
    else:
        print("FAIL: ", errors)
        quit(1)
