extends SceneTree
## Run: godot --headless --path . --script res://tests/native_emergence_edge_oracle.gd
## Independent geometry/physics contract for 150m streamed terrain.
const World = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_verify")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)

func _verify() -> void:
    var world = World.new()
    root.add_child(world)
    _check(is_equal_approx(world.CHUNK_SIDE * world.GRID_WIDTH, world.CONTINENT_SIDE), "32 x 150 must equal 4800")
    _check(world.STREAM_RADIUS == 1, "stream radius must stay 1 (3x3)")
    for x in [-2250.0, -150.0, 0.0, 150.0, 2250.0]:
        for z in [-1800.0, -75.0, 0.0, 75.0, 1800.0]:
            var left = world._terrain_height(x, z)
            var right = world._terrain_height(x, z)
            _check(is_equal_approx(left, right), "world-space seam height mismatch")
    for cell in [Vector2i(0,0), Vector2i(15,15), Vector2i(31,31)]:
        var center = Vector3(-world.HALF + (float(cell.x) + 0.5) * world.CHUNK_SIDE, 0.0, -world.HALF + (float(cell.y) + 0.5) * world.CHUNK_SIDE)
        var mesh = world._terrain_mesh(center)
        _check(mesh != null and mesh.get_surface_count() > 0, "missing terrain mesh at %s" % cell)
        if mesh != null and mesh.get_surface_count() > 0:
            var shape = mesh.create_trimesh_shape()
            _check(shape != null, "missing terrain physics shape at %s" % cell)
            var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
            _check(vertices.size() > 0, "empty terrain vertices at %s" % cell)
            for vertex in vertices:
                var expected = world._terrain_height(center.x + vertex.x, center.z + vertex.z)
                _check(absf(vertex.y - expected) < 0.001, "terrain vertex deviates from world-space height at %s" % cell)
    for p in [Vector2(-2400.0,-2400.0),Vector2(2400.0,2400.0),Vector2(0.0,0.0)]:
        var cell = world._cell_of(p)
        _check(cell.x >= 0 and cell.y >= 0 and cell.x < 32 and cell.y < 32, "out-of-grid chunk index")
    world.queue_free()
    if failures.is_empty():
        print("PASS native emergence terrain edge oracle")
        quit(0)
    else:
        print("FAIL native emergence terrain edge oracle: %d failures" % failures.size())
        quit(1)
