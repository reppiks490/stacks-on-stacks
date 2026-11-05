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
        # Compare independently generated mesh edge vertices, not the height
        # function against itself. This catches chunk-origin and tessellation drift.
        for axis in [0, 1]:
            var neighbor_cell = cell + (Vector2i(1, 0) if axis == 0 else Vector2i(0, 1))
            if neighbor_cell.x >= world.GRID_WIDTH or neighbor_cell.y >= world.GRID_WIDTH:
                continue
            var neighbor_origin = origin + (Vector3(world.CHUNK_SIDE, 0, 0) if axis == 0 else Vector3(0, 0, world.CHUNK_SIDE))
            var other_mesh: ArrayMesh = world._terrain_mesh(neighbor_origin)
            var other_vertices: PackedVector3Array = other_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
            var seam_coordinate = world.CHUNK_SIDE * 0.5
            var first: Dictionary = {}
            var second: Dictionary = {}
            for v in vertices:
                var coordinate: float = v.x if axis == 0 else v.z
                if absf(coordinate - seam_coordinate) < EPS:
                    var along: float = v.z if axis == 0 else v.x
                    first[snappedf(along, 0.0001)] = v.y
            for v in other_vertices:
                var coordinate: float = v.x if axis == 0 else v.z
                if absf(coordinate + seam_coordinate) < EPS:
                    var along: float = v.z if axis == 0 else v.x
                    second[snappedf(along, 0.0001)] = v.y
            check(first.size() == 25 and second.size() == 25, "edge vertex count " + str(cell) + " axis " + str(axis))
            for along in first:
                check(second.has(along), "missing neighbor edge vertex " + str(along))
                if second.has(along):
                    check(absf(float(first[along]) - float(second[along])) < EPS, "mesh seam height " + str(cell) + " axis " + str(axis) + " at " + str(along))
    world.queue_free()
    if failures == 0:
        print("PASS: terrain extent, mesh creation, trimesh collision, neighbor mesh edge heights")
    quit(1 if failures > 0 else 0)
