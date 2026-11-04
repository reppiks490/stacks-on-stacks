extends SceneTree
## Native regression for the 150 m terrain tile mesh and physics contract.
## Run: godot --headless --path . --script res://tests/native_emergence_mesh_seam_test.gd
const WORLD = preload("res://scripts/continental_world.gd")
const SIDE := 150.0
const EPS := 0.001

func _initialize() -> void:
    var world = WORLD.new()
    var origins := [Vector3(75, 0, 75), Vector3(225, 0, 75), Vector3(75, 0, 225)]
    var meshes: Array = []
    for origin in origins:
        var mesh: ArrayMesh = world._terrain_mesh(origin)
        if mesh.get_surface_count() != 1:
            _fail("missing terrain surface")
            return
        var shape = mesh.create_trimesh_shape()
        if shape == null or shape.get_faces().size() == 0:
            _fail("terrain lacks triangle collision")
            return
        meshes.append(mesh)
    var a: Dictionary = _edge(meshes[0], origins[0], true, 150.0)
    var b: Dictionary = _edge(meshes[1], origins[1], true, 150.0)
    var c: Dictionary = _edge(meshes[0], origins[0], false, 150.0)
    var d: Dictionary = _edge(meshes[2], origins[2], false, 150.0)
    if a.size() != 25 or b.size() != 25 or c.size() != 25 or d.size() != 25:
        _fail("terrain boundary does not have 25 sampled vertices")
        return
    for key in a:
        if not b.has(key) or absf(float(a[key]) - float(b[key])) > EPS:
            _fail("east-west seam mismatch at %s" % key)
            return
    for key in c:
        if not d.has(key) or absf(float(c[key]) - float(d[key])) > EPS:
            _fail("north-south seam mismatch at %s" % key)
            return
    print("PASS native emergence: two neighboring seams, 25 samples each, triangle collision")
    world.free()
    quit(0)

func _edge(mesh: ArrayMesh, origin: Vector3, east_west: bool, boundary: float) -> Dictionary:
    var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var samples := {}
    for v in vertices:
        var global_x: float = origin.x + v.x
        var global_z: float = origin.z + v.z
        if absf((global_x if east_west else global_z) - boundary) < EPS:
            var along: float = global_z if east_west else global_x
            samples[snappedf(along, 0.001)] = v.y
    return samples

func _fail(message: String) -> void:
    push_error("FAIL native emergence: " + message)
    quit(1)
