extends SceneTree
## Native terrain geometry/physics contract. Run:
## godot --headless --path . --script res://tests/native_emergence_mesh_collision_geometry_test.gd
const WORLD_SCRIPT = preload("res://scripts/continental_world.gd")
const EPS := 0.001
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("FAIL: " + label)
    else:
        print("PASS: " + label)

func _run() -> void:
    var world = WORLD_SCRIPT.new()
    root.add_child(world)
    _check(world.CONTINENT_SIDE == 4800.0, "world extent")
    _check(world.GRID_WIDTH == 32 and world.CHUNK_SIDE == 150.0, "chunk contract")
    _check(world.STREAM_RADIUS == 1, "3x3 streaming contract")
    for cell in [Vector2i(0, 0), Vector2i(15, 15), Vector2i(31, 31)]:
        var origin := Vector3(-2400.0 + (float(cell.x) + 0.5) * 150.0, 0.0,
            -2400.0 + (float(cell.y) + 0.5) * 150.0)
        var mesh: ArrayMesh = world._terrain_mesh(origin)
        _check(mesh.get_surface_count() > 0, "terrain mesh exists " + str(cell))
        var shape := mesh.create_trimesh_shape()
        _check(shape != null and shape is ConcavePolygonShape3D, "collision shape exists " + str(cell))
        if shape != null:
            _check(shape.get_faces().size() > 0, "collision triangles exist " + str(cell))
    for i in range(32):
        for j in range(32):
            var x := -2400.0 + float(i) * 150.0
            var z := -2400.0 + float(j) * 150.0
            var y := world._terrain_height(x, z)
            _check(is_finite(y), "finite terrain corner %d,%d" % [i,j])
    world.queue_free()
    print("EMERGENCE mesh collision geometry: %d failures" % failures)
    quit(1 if failures > 0 else 0)
