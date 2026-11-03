extends SceneTree
## Headless native acceptance: godot --headless --path . --script res://docs/innovation/construction/quality/arch_acceptance.gd
const KIT = preload("res://docs/innovation/construction/quality/stone_voussoir_arch.gd")
func _initialize() -> void:
    var root: Node3D = KIT.make_arch()
    assert(root.get_child_count() == 13, "Missing arch voussoirs")
    var total_faces := 0
    for stone in root.get_children():
        assert(stone is StaticBody3D)
        var visual: MeshInstance3D = stone.get_child(0)
        var collider: CollisionShape3D = stone.get_child(1)
        assert(visual.mesh.get_surface_count() == 1)
        assert(collider.shape is ConcavePolygonShape3D)
        assert(collider.shape.get_faces().size() > 0)
        total_faces += collider.shape.get_faces().size()
        # Front/back triangles must point outward for correct light and raycasts.
        var vertices: PackedVector3Array = visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
        var checked_front := 0
        var checked_back := 0
        for t in range(0, vertices.size(), 3):
            var a: Vector3 = vertices[t]
            var b: Vector3 = vertices[t + 1]
            var c: Vector3 = vertices[t + 2]
            var normal := (b - a).cross(c - a).normalized()
            if absf(a.z + 0.21) < 0.0001 and absf(b.z + 0.21) < 0.0001 and absf(c.z + 0.21) < 0.0001:
                assert(normal.z < -0.99, "Front face winding is reversed")
                checked_front += 1
            if absf(a.z - 0.21) < 0.0001 and absf(b.z - 0.21) < 0.0001 and absf(c.z - 0.21) < 0.0001:
                assert(normal.z > 0.99, "Back face winding is reversed")
                checked_back += 1
        assert(checked_front == 2 and checked_back == 2, "Expected two triangles on each cap")
    assert(total_faces > 0)
    var invalid: Node3D = KIT.make_arch(-1.0)
    assert(invalid.get_child_count() == 0)
    var repeat: Node3D = KIT.make_arch()
    var a: MeshInstance3D = root.get_child(0).get_child(0)
    var b: MeshInstance3D = repeat.get_child(0).get_child(0)
    assert(a.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == b.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
    print("B16 ARCH ACCEPTANCE PASS: 13 collision-bearing radial stones, invalid input, deterministic vertices")
    root.free()
    invalid.free()
    repeat.free()
    quit(0)
