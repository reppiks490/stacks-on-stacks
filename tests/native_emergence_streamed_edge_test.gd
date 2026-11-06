extends SceneTree
# Native geometry/physics regression for the existing 32x32 continental contract.
# Run from the repository root with Godot 4.x:
# godot --headless --path . --script res://tests/native_emergence_streamed_edge_test.gd
const World = preload("res://scripts/continental_world.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if ok:
        print("PASS ", label)
    else:
        failures += 1
        push_error("FAIL " + label)

func add_cell(world: Node3D, key: Vector2i) -> Node3D:
    var chunk := Node3D.new()
    chunk.position = Vector3(-2400.0 + (float(key.x) + 0.5) * 150.0, 0.0,
        -2400.0 + (float(key.y) + 0.5) * 150.0)
    world.add_child(chunk)
    var body := StaticBody3D.new()
    body.collision_layer = 1
    chunk.add_child(body)
    var collider := CollisionShape3D.new()
    collider.shape = world._terrain_mesh(chunk.position).create_trimesh_shape()
    body.add_child(collider)
    world._install_outer_boundary(chunk, key)
    return chunk

func ray(world: Node3D, start: Vector3, end: Vector3) -> Dictionary:
    var q := PhysicsRayQueryParameters3D.create(start, end)
    q.collision_mask = 1
    return world.get_world_3d().direct_space_state.intersect_ray(q)

func floor_check(world: Node3D, x: float, z: float, label: String) -> void:
    var hit := ray(world, Vector3(x, 100, z), Vector3(x, -100, z))
    check(not hit.is_empty(), label + " has a physical floor")
    if not hit.is_empty():
        check(absf(float(hit["position"].y) - world._terrain_height(x, z)) < 0.5,
            label + " collision matches world-space height")

func _run() -> void:
    var world := World.new()
    root.add_child(world)
    check(world.GRID_WIDTH == 32 and is_equal_approx(world.CHUNK_SIDE, 150.0),
        "world dimensions unchanged")
    var a := add_cell(world, Vector2i(15, 15))
    var b := add_cell(world, Vector2i(16, 15))
    var edge := add_cell(world, Vector2i(0, 15))
    await physics_frame
    await physics_frame
    for x in [-0.2, 0.2]:
        for z in [-10.0, 0.0, 10.0]:
            floor_check(world, x, z, "interior seam (%s,%s)" % [x,z])
    floor_check(world, -2398.0, -10.0, "outer edge")
    var wall := ray(world, Vector3(-2397.0, 2.0, -10.0),
        Vector3(-2403.0, 2.0, -10.0))
    check(not wall.is_empty(), "outer perimeter has a horizontal physics barrier")
    var internal_wall := ray(world, Vector3(-1.0, 40.0, -10.0),
        Vector3(1.0, 40.0, -10.0))
    check(internal_wall.is_empty(), "internal chunk seam has no perimeter barrier")
    b.queue_free()
    await physics_frame
    check(ray(world, Vector3(1.0, 100.0, -10.0),
        Vector3(1.0, -100.0, -10.0)).is_empty(),
        "unloaded cell releases collision")
    b = add_cell(world, Vector2i(16, 15))
    await physics_frame
    await physics_frame
    floor_check(world, 1.0, -10.0, "reloaded seam")
    print("EMERGENCE STREAMED EDGE: ", "PASS" if failures == 0 else "FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
