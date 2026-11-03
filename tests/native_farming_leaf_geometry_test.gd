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
    # Triangles at the petiole and distal tip must not collapse into zero-area geometry.
    # Explicit backfaces should have opposite winding and nonzero surface normals.
    for tri in range(0, vertices.size(), 3):
        var edge_a: Vector3 = vertices[tri + 1] - vertices[tri]
        var edge_b: Vector3 = vertices[tri + 2] - vertices[tri]
        assert(edge_a.cross(edge_b).length_squared() > 0.000000000001, "Degenerate leaf triangle")
    for tri in range(0, int(vertices.size() / 2), 3):
        var front: Vector3 = (vertices[tri + 1] - vertices[tri]).cross(vertices[tri + 2] - vertices[tri])
        var back_idx := tri + vertices.size() / 2
        var back: Vector3 = (vertices[back_idx + 1] - vertices[back_idx]).cross(vertices[back_idx + 2] - vertices[back_idx])
        assert(front.dot(back) < 0.0, "Backface winding must oppose frontface")
        assert(vertices[back_idx].z < vertices[tri + 2].z + 0.01, "Underside must stay near upper lamina")

    assert(uvs.size() == vertices.size(), "UVs required per vertex")
    var front_count := int(vertices.size() / 2)
    assert(vertices[front_count].z < vertices[2].z, "Underside must be offset from upper surface to avoid z-fighting")
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
