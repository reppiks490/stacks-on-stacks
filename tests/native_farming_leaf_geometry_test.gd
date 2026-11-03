extends SceneTree
# Run: godot --headless --path . --script res://tests/native_farming_leaf_geometry_test.gd
# Isolated asset test; does not modify save files or game state.
const SIDES_FOR_TEST := 8
const Leaf = preload("res://scripts/farming_visuals/leaf_blade_mesh.gd")

func _initialize() -> void:
    var good := Leaf.make_leaf(0.65, 0.12, 0.08, 11)
    assert(good.get_surface_count() == 1, "Valid leaf must have one surface")
    var arrays := good.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
    var pigments: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
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
        var back_idx := tri + int(vertices.size() / 2)
        var back: Vector3 = (vertices[back_idx + 1] - vertices[back_idx]).cross(vertices[back_idx + 2] - vertices[back_idx])
        assert(front.dot(back) < 0.0, "Backface winding must oppose frontface")
        assert(front.z > 0.0, "Upper lamina must face +Z for backface-culling and daylight")
        assert(back.z < 0.0, "Underside must face -Z")
        assert(vertices[back_idx].z < vertices[tri + 2].z + 0.01, "Underside must stay near upper lamina")

    assert(uvs.size() == vertices.size(), "UVs required per vertex")
    assert(pigments.size() == vertices.size(), "Vertex pigment required per vertex")
    var pigment_range := 0.0
    for pigment in pigments:
        assert(pigment.is_finite(), "Pigments must remain finite")
        assert(pigment.r >= 0.0 and pigment.g >= 0.0 and pigment.b >= 0.0, "Pigments cannot be negative")
        pigment_range = max(pigment_range, abs(pigment.g - pigments[0].g))
    assert(pigment_range > 0.01, "Anatomical vein/margin coloration must vary")
    assert(Leaf.leaf_material().vertex_color_use_as_albedo, "Material must consume mesh vertex pigments")
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
    assert(duplicate.surface_get_arrays(0)[Mesh.ARRAY_COLOR] == pigments, "Pigment generation must be deterministic")
    assert(Leaf.make_leaf(-1.0, 0.12, 0.08).get_surface_count() == 0, "Invalid dimensions must fail closed")
    assert(Leaf.make_leaf(0.65, INF, 0.08).get_surface_count() == 0, "Nonfinite dimensions must fail closed")
    assert(Leaf.make_leaf(0.65, 0.12, 1.0).get_surface_count() == 0, "Excessive curl must fail closed")
    # Compare the same authored vertex on each face, rather than unrelated
    # triangle corners. Front triangles emit [a,a+1,b] and underside emits
    # [b,a+1,a], so front slot 0 corresponds to underside slot 2.
    # Choose a ring with nonzero width and a central vs marginal blade point.
    var center_ring := 6
    var center_column := 4
    var margin_column := 0
    var center_front := (center_ring * SIDES_FOR_TEST + center_column) * 6
    var margin_front := (center_ring * SIDES_FOR_TEST + margin_column) * 6
    # The first half of the triangle stream is the upper lamina; the second
    # half contains matching underside triangles with reversed winding.
    # Keep the offset derived from the actual emitted mesh, not an undefined
    # local variable, so the native regression can execute.
    var half := int(vertices.size() / 2)
    var center_gap := vertices[center_front].distance_to(vertices[half + center_front + 2])
    var margin_gap := vertices[margin_front].distance_to(vertices[half + margin_front + 2])
    assert(center_gap > margin_gap, "Lamina should taper toward its margin")
    print("PASS native farming leaf geometry: winding, UV, finite bounds, deterministic seed, invalid inputs")
    quit(0)
