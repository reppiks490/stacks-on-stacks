extends SceneTree
# Native headless regression for the existing 32x32 streamed terrain.
# Run: godot --headless --path . --script res://tests/native_emergence_terrain_continuity_test.gd
const World = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)

func _run() -> void:
    var world = World.new()
    root.add_child(world)
    world._make_materials()
    _assert(is_equal_approx(world.CHUNK_SIDE * float(world.GRID_WIDTH), world.CONTINENT_SIDE), "World dimensions mismatch")
    var samples = [Vector2i(15, 15), Vector2i(16, 16), Vector2i(0, 0), Vector2i(31, 31)]
    for key in samples:
        var origin = Vector3(-world.HALF + (float(key.x) + 0.5) * world.CHUNK_SIDE, 0.0, -world.HALF + (float(key.y) + 0.5) * world.CHUNK_SIDE)
        var mesh = world._terrain_mesh(origin)
        _assert(mesh.get_surface_count() > 0, "Empty terrain mesh %s" % key)
        _assert(mesh.create_trimesh_shape() != null, "Missing terrain collider %s" % key)
    for x in [-2250.0, -75.0, 0.0, 75.0, 2250.0]:
        for z in [-2250.0, -75.0, 0.0, 75.0, 2250.0]:
            var h = world._terrain_height(x, z)
            _assert(is_finite(h), "Nonfinite height at %s,%s" % [x,z])
            _assert(absf(world._terrain_height(x,z) - world._terrain_height(x,z)) < 0.0001, "Nondeterministic terrain")
    # Actual adjacent mesh vertices must coincide at a shared boundary.
    var left_origin = Vector3(-75.0, 0.0, 75.0)
    var right_origin = Vector3(75.0, 0.0, 75.0)
    var left = world._terrain_mesh(left_origin).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var right = world._terrain_mesh(right_origin).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    for i in range(25):
        var z = -75.0 + float(i) * 6.25
        var expected = world._terrain_height(0.0, 75.0 + z)
        var l_found = false
        var r_found = false
        for v in left:
            if absf(v.x - 75.0) < 0.001 and absf(v.z-z)<0.001 and absf(v.y-expected)<0.001:
                l_found = true
                break
        for v in right:
            if absf(v.x + 75.0) < 0.001 and absf(v.z-z)<0.001 and absf(v.y-expected)<0.001:
                r_found = true
                break
        _assert(l_found and r_found, "Seam mismatch at z=%f" % z)
    _assert(world._cell_of(Vector2(-2399.0, -2399.0)) == Vector2i(0,0), "Negative world corner")
    _assert(world._cell_of(Vector2(2399.0, 2399.0)) == Vector2i(31,31), "Positive world corner")
    world.free()
    if failures.is_empty():
        print("PASS: terrain grid, deterministic height, mesh collider, 25 seam vertices and world corners")
        quit(0)
    else:
        print("FAIL: %d terrain regression assertions" % failures.size())
        quit(1)
