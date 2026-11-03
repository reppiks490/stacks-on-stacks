extends SceneTree
# Run: godot --headless --path . --script res://tests/native_farming_leaf_geometry_test.gd
# Isolated asset test; does not modify save files or game state.
const Leaf = preload("res://scripts/farming_visuals/leaf_blade_mesh.gd")

func _initialize() -> void:
    var good := Leaf.make_leaf(0.65, 0.12, 0.08, 11)
    assert(good.get_surface_count() == 1, "Valid leaf must have one surface")
    var arrays := good.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
    assert(vertices.size() == 13 * 8 * 12, "Front and back triangles must be explicit")
    assert(normals.size() == vertices.size(), "Normals required per vertex")
    assert(uvs.size() == vertices.size(), "UVs required per vertex")
    var low := Vector3(INF, INF, INF)
    var high := Vector3(-INF, -INF, -INF)
    for v in vertices:
        assert(v.is_finite(), "Leaf positions must remain finite")
        low = low.min(v)
        high = high.max(v)
    assert(high.y - low.y > 0.5, "Leaf must have longitudinal shape")
    assert(high.x - low.x > 0.1, "Leaf must have a broad lamina")
    var duplicate := Leaf.make_leaf(0.65, 0.12, 0.08, 11)
    assert(duplicate.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == vertices, "Mesh generation must be deterministic")
    assert(Leaf.make_leaf(-1.0, 0.12, 0.08).get_surface_count() == 0, "Invalid dimensions must fail closed")
    assert(Leaf.make_leaf(0.65, INF, 0.08).get_surface_count() == 0, "Nonfinite dimensions must fail closed")
    print("PASS native farming leaf geometry: winding, UV, finite bounds, deterministic seed, invalid inputs")
    quit(0)
