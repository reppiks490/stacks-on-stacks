extends RefCounted
## B16 isolated architectural prototype: radial stone arch with explicit collision.
## Geometry is authored from annular wedge sections, not stacked cube primitives.
## Coordinates: XY facade, Z depth; base spring line y=0, arch rises toward +Y.
## Caller supplies original/rights-verified stone materials and places support piers.
const SEGMENTS := 13

static func make_arch(inner_radius: float = 1.15, thickness: float = 0.34, depth: float = 0.42, joints: float = 0.012) -> Node3D:
    var root := Node3D.new()
    root.name = "StoneVoussoirArch"
    if not _valid(inner_radius, thickness, depth, joints):
        return root
    for k in range(SEGMENTS):
        var a0 := PI - float(k) * PI / float(SEGMENTS)
        var a1 := PI - float(k + 1) * PI / float(SEGMENTS)
        var inset := joints / maxf(inner_radius, 0.001)
        a0 -= inset
        a1 += inset
        var mesh := _wedge(inner_radius, inner_radius + thickness, a0, a1, depth)
        var stone := StaticBody3D.new()
        stone.name = "Voussoir_%02d" % k
        var display := MeshInstance3D.new()
        display.mesh = mesh
        stone.add_child(display)
        var collider := CollisionShape3D.new()
        collider.shape = mesh.create_trimesh_shape()
        stone.add_child(collider)
        root.add_child(stone)
    return root

static func _valid(r: float, t: float, d: float, joint: float) -> bool:
    return is_finite(r) and is_finite(t) and is_finite(d) and is_finite(joint) and r >= 0.5 and r <= 8.0 and t >= 0.12 and t <= r * 0.75 and d >= 0.15 and d <= 3.0 and joint >= 0.0 and joint < 0.025

static func _wedge(ri: float, ro: float, a0: float, a1: float, depth: float) -> ArrayMesh:
    var p := PackedVector3Array()
    for z in [-depth * 0.5, depth * 0.5]:
        for a in [a0, a1]:
            for r in [ri, ro]:
                p.append(Vector3(cos(a) * r, sin(a) * r, z))
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Face normals must point away from the stone volume. The previous implementation
    # never corrected winding despite its comment, leaving faces potentially inverted.
    var mid := (a0 + a1) * 0.5
    var radial := Vector3(cos(mid), sin(mid), 0.0)
    var tangent := Vector3(-sin(mid), cos(mid), 0.0)
    var quads := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    var outward := [Vector3.FORWARD, Vector3.BACK, -radial, radial, tangent, -tangent]
    for i in range(quads.size()):
        _face(surface, p, quads[i], outward[i])
    surface.generate_normals()
    surface.generate_tangents()
    return surface.commit()

static func _face(surface: SurfaceTool, p: PackedVector3Array, q: Array, expected: Vector3) -> void:
    var a: Vector3 = p[q[0]]
    var b: Vector3 = p[q[1]]
    var c: Vector3 = p[q[2]]
    var flip := (b - a).cross(c - a).dot(expected) < 0.0
    # Planar local UVs avoid zero-area UV triangles on radial end caps.
    var u_axis := (b - a).normalized()
    var v_axis := expected.cross(u_axis).normalized()
    var order := [[0, 1, 2], [0, 2, 3]]
    if flip:
        order = [[0, 2, 1], [0, 3, 2]]
    for tri in order:
        for index in tri:
            var v: Vector3 = p[q[index]]
            var delta := v - a
            surface.set_uv(Vector2(delta.dot(u_axis), delta.dot(v_axis)))
            surface.add_vertex(v)
