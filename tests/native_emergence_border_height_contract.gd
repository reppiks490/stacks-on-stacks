extends SceneTree
# Native Godot regression for the existing 32x32, 150m streamed terrain.
# Run: godot --headless --path . --script res://tests/native_emergence_border_height_contract.gd
const World = preload("res://scripts/continental_world.gd")
const EPS := 0.0005
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("FAIL: " + label)

func _run() -> void:
    var world = World.new()
    root.add_child(world)
    check(is_equal_approx(world.CHUNK_SIDE * world.GRID_WIDTH, world.CONTINENT_SIDE), "world extent")
    for cell in [Vector2i(0, 0), Vector2i(15, 15), Vector2i(16, 16), Vector2i(30, 30)]:
        var origin = Vector3(-world.HALF + (float(cell.x) + 0.5) * world.CHUNK_SIDE, 0.0, -world.HALF + (float(cell.y) + 0.5) * world.CHUNK_SIDE)
        var mesh: ArrayMesh = world._terrain_mesh(origin)
        check(mesh.get_surface_count() == 1, "terrain surface " + str(cell))
        var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
        check(vertices.size() > 0, "terrain vertices " + str(cell))
        var shape = mesh.create_trimesh_shape()
        check(shape != null, "terrain collision shape " + str(cell))
        for offset in [0.0, 37.5, 75.0, 112.5, 150.0]:
            var x = -world.HALF + float(cell.x + 1) * world.CHUNK_SIDE
            var z = -world.HALF + float(cell.y) * world.CHUNK_SIDE + offset
            if cell.x + 1 < world.GRID_WIDTH:
                var left = world._terrain_height(x, z)
                var right = world._terrain_height(x, z)
                check(absf(left - right) < EPS, "shared x seam " + str(cell) + " " + str(offset))
            var z_edge = -world.HALF + float(cell.y + 1) * world.CHUNK_SIDE
            var x_sample = -world.HALF + float(cell.x) * world.CHUNK_SIDE + offset
            if cell.y + 1 < world.GRID_WIDTH:
                check(absf(world._terrain_height(x_sample, z_edge) - world._terrain_height(x_sample, z_edge)) < EPS, "shared z seam " + str(cell))
    world.queue_free()
    if failures == 0:
        print("PASS: terrain extent, mesh creation, trimesh collision, deterministic sampled boundaries")
    quit(1 if failures > 0 else 0)
