extends SceneTree
## B16 winding/UV regression; requires native Godot execution before acceptance.
const KIT = preload("res://docs/innovation/construction/quality/stone_voussoir_arch.gd")
func _initialize() -> void:
    var arch: Node3D = KIT.make_arch()
    assert(arch.get_child_count() == KIT.SEGMENTS)
    for k in range(KIT.SEGMENTS):
        var mesh: ArrayMesh = arch.get_child(k).get_child(0).mesh
        var arrays: Array = mesh.surface_get_arrays(0)
        var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
        var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
        assert(verts.size() == 36 and uvs.size() == 36 and normals.size() == 36)
        var a0 := PI - float(k) * PI / float(KIT.SEGMENTS) - 0.012 / 1.15
        var a1 := PI - float(k + 1) * PI / float(KIT.SEGMENTS) + 0.012 / 1.15
        var mid := (a0 + a1) * 0.5
        var radial := Vector3(cos(mid), sin(mid), 0.0)
        var tangent := Vector3(-sin(mid), cos(mid), 0.0)
        var expected := [Vector3.FORWARD, Vector3.BACK, -radial, radial, tangent, -tangent]
        for face in range(6):
            for tri in range(2):
                var n := face * 6 + tri * 3
                var cross: Vector3 = (verts[n + 1] - verts[n]).cross(verts[n + 2] - verts[n])
                assert(cross.length() > 0.000001, "Degenerate mesh triangle")
                assert(cross.normalized().dot(expected[face]) > 0.01, "Inward-facing arch triangle")
                var area_uv := absf((uvs[n + 1] - uvs[n]).cross(uvs[n + 2] - uvs[n]))
                assert(area_uv > 0.000001, "Degenerate UV triangle")
                assert(normals[n].dot(expected[face]) > 0.01, "Inward vertex normal")
    print("B16 ARCH WINDING/UV PASS: all 13 voussoirs, 12 triangles each")
    arch.free()
    quit(0)
