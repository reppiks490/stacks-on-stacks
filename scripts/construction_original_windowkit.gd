extends RefCounted
## B16 original mullioned window frame geometry. Geometry only: no save or gameplay changes.
## Local XY facade plane; opening is centered. Z is frame depth.
## All dimensions are world units. Material and collision assigned by caller.

static func mullioned_window(width: float, height: float, depth: float, rail: float, sill_projection: float = 0.12) -> ArrayMesh:
    if not is_finite(width) or not is_finite(height) or not is_finite(depth) or not is_finite(rail) or not is_finite(sill_projection):
        return ArrayMesh.new()
    if width <= 0.4 or height <= 0.4 or depth <= 0.02 or rail <= 0.02 or rail * 3.0 >= min(width, height) or sill_projection < 0.0 or sill_projection > 0.5:
        return ArrayMesh.new()
    var s := SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    var half_w := width * 0.5
    var half_h := height * 0.5
    _cuboid(s, Vector3(-half_w + rail * 0.5, 0.0, 0.0), Vector3(rail, height, depth))
    _cuboid(s, Vector3(half_w - rail * 0.5, 0.0, 0.0), Vector3(rail, height, depth))
    _cuboid(s, Vector3(0.0, half_h - rail * 0.5, 0.0), Vector3(width, rail, depth))
    _cuboid(s, Vector3(0.0, -half_h + rail * 0.5, 0.0), Vector3(width, rail, depth))
    _cuboid(s, Vector3(0.0, 0.0, 0.0), Vector3(rail, height - rail * 2.0, depth))
    _cuboid(s, Vector3(0.0, 0.0, 0.0), Vector3(width - rail * 2.0, rail, depth))
    _cuboid(s, Vector3(0.0, -half_h - rail * 0.25, sill_projection * 0.5), Vector3(width + rail * 0.5, rail * 0.5, depth + sill_projection))
    s.generate_normals()
    return s.commit()

static func _cuboid(s: SurfaceTool, center: Vector3, size: Vector3) -> void:
    var h := size * 0.5
    var p := [
        center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z),
        center + Vector3(h.x, h.y, -h.z), center + Vector3(-h.x, h.y, -h.z),
        center + Vector3(-h.x, -h.y, h.z), center + Vector3(h.x, -h.y, h.z),
        center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z)
    ]
    for face in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]:
        for i in [0, 1, 2, 0, 2, 3]:
            s.add_vertex(p[face[i]])
