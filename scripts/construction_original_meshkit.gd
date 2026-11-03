extends RefCounted
## B16 original procedural architectural silhouette kit.
## Pure mesh factory: no save mutation, inventory changes, or gameplay activation.
## Local coordinates; caller owns material, collision and LOD decisions.

static func gabled_roof(width: float, depth: float, rise: float, overhang: float = 0.35) -> ArrayMesh:
    if not is_finite(width) or not is_finite(depth) or not is_finite(rise) or not is_finite(overhang):
        return ArrayMesh.new()
    if width <= 0.2 or depth <= 0.2 or rise <= 0.05 or overhang < 0.0 or overhang > 2.0:
        return ArrayMesh.new()
    var half_w: float = width * 0.5 + overhang
    var half_d: float = depth * 0.5 + overhang
    var ridge_front := Vector3(0.0, rise, half_d)
    var ridge_back := Vector3(0.0, rise, -half_d)
    var left_front := Vector3(-half_w, 0.0, half_d)
    var left_back := Vector3(-half_w, 0.0, -half_d)
    var right_front := Vector3(half_w, 0.0, half_d)
    var right_back := Vector3(half_w, 0.0, -half_d)
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    _quad(surface, left_front, ridge_front, ridge_back, left_back)
    _quad(surface, ridge_front, right_front, right_back, ridge_back)
    surface.generate_normals()
    return surface.commit()

static func tapered_beam(length: float, base_radius: float, top_radius: float, sides: int = 8) -> ArrayMesh:
    if not is_finite(length) or not is_finite(base_radius) or not is_finite(top_radius):
        return ArrayMesh.new()
    if length <= 0.1 or base_radius <= 0.01 or top_radius <= 0.01 or sides < 3 or sides > 32:
        return ArrayMesh.new()
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(sides):
        var a := TAU * float(i) / float(sides)
        var b := TAU * float(i + 1) / float(sides)
        var p0 := Vector3(cos(a) * base_radius, 0.0, sin(a) * base_radius)
        var p1 := Vector3(cos(b) * base_radius, 0.0, sin(b) * base_radius)
        var p2 := Vector3(cos(b) * top_radius, length, sin(b) * top_radius)
        var p3 := Vector3(cos(a) * top_radius, length, sin(a) * top_radius)
        _quad(surface, p0, p1, p2, p3)
    surface.generate_normals()
    return surface.commit()

static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    for vertex in [a, b, c, a, c, d]:
        surface.add_vertex(vertex)
