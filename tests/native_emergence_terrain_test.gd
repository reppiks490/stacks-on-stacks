extends SceneTree
# Run: godot --headless --path . --script res://tests/native_emergence_terrain_test.gd
# Exact source branch must include scripts/continental_world.gd.
const World = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        push_error("FAIL: " + label)

func _run() -> void:
    var world: Node3D = World.new()
    root.add_child(world)
    _check(is_equal_approx(world.CONTINENT_SIDE, 4800.0), "world width")
    _check(is_equal_approx(world.CHUNK_SIDE, 150.0), "chunk width")
    _check(world.GRID_WIDTH == 32 and world.STREAM_RADIUS == 1, "stream contract")
    # Neighboring 150m meshes must have identical world-space edge positions.
    for cx in [0, 7, 15, 16, 30]:
        for cz in [0, 15, 30]:
            var ox: float = -2400.0 + (float(cx) + 0.5) * 150.0
            var oz: float = -2400.0 + (float(cz) + 0.5) * 150.0
            for j in range(25):
                var z: float = oz - 75.0 + float(j) * 6.25
                var edge_x: float = ox + 75.0
                var a: float = world._terrain_height(edge_x, z)
                var b: float = world._terrain_height((ox + 150.0) - 75.0, z)
                _check(absf(a - b) < 0.00001, "east seam %d,%d,%d" % [cx, cz, j])
    _check(world._cell_of(Vector2(-2400.0, -2400.0)) == Vector2i(0, 0), "minimum cell")
    _check(world._cell_of(Vector2(2399.0, 2399.0)) == Vector2i(31, 31), "maximum cell")
    var edge := Node3D.new()
    world.add_child(edge)
    world._install_outer_boundary(edge, Vector2i(0, 0))
    var count: int = 0
    for child in edge.get_children():
        if child is StaticBody3D and child.get_node_or_null("CollisionShape3D") != null:
            count += 1
    _check(count == 2, "corner has two solid boundary walls")
    var middle := Node3D.new()
    world.add_child(middle)
    world._install_outer_boundary(middle, Vector2i(15, 15))
    _check(middle.get_child_count() == 0, "interior seam has no blocking wall")
    var mesh: ArrayMesh = world._terrain_mesh(Vector3(75, 0, 75))
    _check(mesh.get_surface_count() > 0, "terrain geometry emitted")
    var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
    _check(shape != null and shape.get_faces().size() > 0, "terrain physics triangles emitted")
    for frame in range(120):
        await physics_frame
    if failures.is_empty():
        print("PASS emergence terrain seam/boundary/physics/120-frame checks")
        quit(0)
    else:
        print("FAIL emergence terrain checks: ", failures.size())
        quit(1)
