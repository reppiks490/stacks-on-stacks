extends SceneTree
# Native headless regression for the actual continental terrain mesh and physics.
# Run: godot --headless --path . --script res://tests/native_emergence_chunk_contract_test.gd
const World = preload("res://scripts/continental_world.gd")
const EPS := 0.0005
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
    var world = World.new()
    root.add_child(world)
    _check(world.GRID_WIDTH == 32 and is_equal_approx(world.CHUNK_SIDE, 150.0), "32x32 150m architecture")
    _check(is_equal_approx(world.CONTINENT_SIDE, 4800.0), "4800m continent")
    for x in [-2250.0, -75.0, 75.0, 2250.0]:
        for z in [-2250.0, 0.0, 2250.0]:
            var a: float = world._terrain_height(x, z)
            var b: float = world._terrain_height(x, z)
            _check(is_finite(a) and absf(a - b) < EPS, "deterministic height %.1f %.1f" % [x,z])
    var left_origin := Vector3(-75.0, 0.0, 75.0)
    var right_origin := Vector3(75.0, 0.0, 75.0)
    var left: ArrayMesh = world._terrain_mesh(left_origin)
    var right: ArrayMesh = world._terrain_mesh(right_origin)
    _check(left.get_surface_count() == 1 and right.get_surface_count() == 1, "terrain surfaces exist")
    var l: Dictionary = _edge_samples(left, left_origin, 0.0)
    var r: Dictionary = _edge_samples(right, right_origin, 0.0)
    _check(l.size() == 25 and r.size() == 25, "shared boundary has 25 vertex samples")
    for key in l:
        _check(r.has(key), "matching edge coordinate " + str(key))
        if r.has(key):
            var la: Array = l[key]
            var ra: Array = r[key]
            _check(la[0].distance_to(ra[0]) < EPS, "seam position " + str(key))
            _check(la[1].distance_to(ra[1]) < EPS, "seam normal " + str(key))
    var collider: ConcavePolygonShape3D = left.create_trimesh_shape()
    _check(collider != null and collider.get_faces().size() > 0, "terrain has nonempty collision triangles")
    world.free()
    print("EMERGENCE CHUNK CONTRACT: ", "PASS" if failures == 0 else "FAIL %d" % failures)
    quit(0 if failures == 0 else 1)

func _edge_samples(mesh: ArrayMesh, origin: Vector3, boundary_x: float) -> Dictionary:
    var arrays: Array = mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var result: Dictionary = {}
    for i in range(vertices.size()):
        var point: Vector3 = vertices[i] + origin
        if absf(point.x - boundary_x) < EPS:
            result[snappedf(point.z, 0.001)] = [point, normals[i]]
    return result
