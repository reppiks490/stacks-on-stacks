extends SceneTree
## Native, read-only geometry regression for the existing continental implementation.
## Run: godot --headless --path . --script res://tests/native_emergence_seam_geometry_test.gd
const World = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures.append(message)
        push_error(message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world: Node3D = World.new()
    root.add_child(world)
    check(world._cell_of(Vector2(-2399.0, -2399.0)) == Vector2i(0, 0), "southwest cell")
    check(world._cell_of(Vector2(2399.0, 2399.0)) == Vector2i(31, 31), "northeast cell")
    check(world._cell_of(Vector2(0.0, 0.0)) == Vector2i(16, 16), "central cell")
    for cell in [Vector2i(0, 0), Vector2i(15, 15), Vector2i(16, 16), Vector2i(30, 30)]:
        var origin := Vector3(-2400.0 + (float(cell.x) + 0.5) * 150.0, 0.0, -2400.0 + (float(cell.y) + 0.5) * 150.0)
        var mesh: ArrayMesh = world._terrain_mesh(origin)
        check(mesh.get_surface_count() == 1, "terrain mesh surface %s" % cell)
        var collider := mesh.create_trimesh_shape()
        check(collider != null, "terrain trimesh collider %s" % cell)
        var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
        check(verts.size() > 0, "terrain triangles %s" % cell)
        for axis in range(2):
            var adjacent := origin + (Vector3(150, 0, 0) if axis == 0 else Vector3(0, 0, 150))
            var neighbor: ArrayMesh = world._terrain_mesh(adjacent)
            var neighbor_verts: PackedVector3Array = neighbor.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
            for sample in range(25):
                var coord := -75.0 + float(sample) * 6.25
                var edge := Vector3(75.0, 0, coord) if axis == 0 else Vector3(coord, 0, 75.0)
                var other := Vector3(-75.0, 0, coord) if axis == 0 else Vector3(coord, 0, -75.0)
                var expected := world._terrain_height(origin.x + edge.x, origin.z + edge.z)
                var match_a := false
                var match_b := false
                for vertex in verts:
                    if absf(vertex.x - edge.x) < 0.001 and absf(vertex.z - edge.z) < 0.001 and absf(vertex.y - expected) < 0.001:
                        match_a = true
                        break
                for vertex in neighbor_verts:
                    if absf(vertex.x - other.x) < 0.001 and absf(vertex.z - other.z) < 0.001 and absf(vertex.y - expected) < 0.001:
                        match_b = true
                        break
                check(match_a and match_b, "missing or mismatched seam vertex at %s axis %d sample %d" % [cell, axis, sample])
    print("EMERGENCE_SEAM_GEOMETRY: %d assertions, %d failures" % [assertions, failures.size()])
    world.queue_free()
    quit(0 if failures.is_empty() else 1)
