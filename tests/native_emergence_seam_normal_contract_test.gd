extends SceneTree
## Native seam contract: adjacent chunk meshes must share position and normal.
## Run: godot --headless --path . --script res://tests/native_emergence_seam_normal_contract_test.gd
const World = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures.append(description)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := World.new()
    root.add_child(world)
    var origins := [Vector3(-75.0, 0.0, -75.0), Vector3(75.0, 0.0, -75.0), Vector3(-75.0, 0.0, 75.0)]
    var maps: Array[Dictionary] = []
    for origin in origins:
        var mesh: ArrayMesh = world._terrain_mesh(origin)
        check(mesh.get_surface_count() > 0, "missing mesh surface")
        var arrays := mesh.surface_get_arrays(0)
        var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
        check(verts.size() == normals.size(), "vertex/normal count mismatch")
        var edge := {}
        for i in range(verts.size()):
            var p: Vector3 = verts[i] + origin
            if absf(p.x) < 0.0001 or absf(p.z) < 0.0001:
                var key := "%0.4f:%0.4f" % [p.x, p.z]
                edge[key] = {"height": p.y, "normal": normals[i]}
        maps.append(edge)
    for pair in [[0, 1], [0, 2]]:
        var common := 0
        for key in maps[pair[0]].keys():
            if not maps[pair[1]].has(key):
                continue
            common += 1
            var a: Dictionary = maps[pair[0]][key]
            var b: Dictionary = maps[pair[1]][key]
            check(absf(a.height - b.height) < 0.001, "seam height mismatch: " + key)
            check(a.normal.dot(b.normal) > 0.999, "seam shading normal mismatch: " + key)
        check(common >= 25, "insufficient common seam samples")
    print("EVERBLOOM_SEAM_NORMAL_CONTRACT checks=%d failures=%d" % [checks, failures.size()])
    for failure in failures:
        push_error(failure)
    quit(0 if failures.is_empty() else 1)
