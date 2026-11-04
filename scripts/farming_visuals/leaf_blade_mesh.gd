extends RefCounted
## EVERBLOOM original botanical leaf mesh authoring utility.
## Visual candidate only: the existing farm renderer remains authoritative.
## Curved, tapered leaf blade with midrib, serrated margins and a real backface.
## No imported art, no new crop types, no save fields.
const RINGS := 13
const SIDES := 8

static func make_leaf(length: float, width: float, curl: float, seed: int = 0) -> ArrayMesh:
    var mesh := ArrayMesh.new()
    if not is_finite(length) or not is_finite(width) or not is_finite(curl):
        return mesh
    if length <= 0.02 or width <= 0.005 or length > 3.0 or width > 1.0 or abs(curl) > length * 0.75:
        return mesh
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var verts: Array[Vector3] = []
    var uvs: Array[Vector2] = []
    var pigments: Array[Color] = []
    var phase := float(posmod(seed, 97)) * 0.061
    var lateral_bend := sin(phase * 1.7) * 0.085 * width
    for i in range(RINGS + 1):
        var t := float(i) / float(RINGS)
        # Narrow petiole, broad middle, and a sharply tapered distal tip.
        # A finite lamina width at the endpoints prevents zero-area triangles and invalid tangents.
        # At this scale the 0.6% tip width remains visually pointed.
        var profile := max(0.006, pow(max(0.0, sin(PI * t)), 0.85) * (0.82 + 0.18 * t))
        for j in range(SIDES + 1):
            var s := float(j) / float(SIDES) * 2.0 - 1.0
            var edge := 1.0 + 0.035 * sin(t * 19.0 * PI + phase) * abs(s)
            # A subtle curved rachis and asymmetric lamina prevent ruler-straight silhouettes.
            var asymmetry := 1.0 + 0.09 * s * sin(PI * t + phase)
            var x := s * width * profile * edge * asymmetry + lateral_bend * t * t
            var y := length * t - 0.035 * length * profile * s * s
            var midrib := 0.11 * width * profile * (1.0 - abs(s))
            var cross_curve := -0.22 * width * profile * s * s
            # Raised primary vein, depressed margins, and a slightly recurved tip.
            var z := curl * t * t + midrib + cross_curve - 0.04 * length * pow(t, 6.0)
            z += sin(t * PI) * 0.025 * length * s
            verts.append(Vector3(x, y, z))
            uvs.append(Vector2((s + 1.0) * 0.5, t))
            # Authored vertex pigments follow vein anatomy and leaf exposure,
            # rather than uncorrelated random per-triangle colors.
            var vein := pow(max(0.0, 1.0 - abs(s) * 7.0), 2.0)
            var edge_fade := smoothstep(0.65, 1.0, abs(s))
            var longitudinal := sin(PI * t)
            var exposure := 0.96 + 0.04 * sin(phase + t * 8.0 + s * 2.0)
            var tint := Color(0.78, 0.92, 0.70).lerp(Color(1.02, 1.05, 0.83), vein * 0.55)
            tint = tint.lerp(Color(0.82, 0.84, 0.64), edge_fade * 0.18)
            tint *= exposure * (0.96 + 0.04 * longitudinal)
            pigments.append(tint)
    # Smooth vertex normals follow the curved lamina instead of each triangle's
    # individual plane. This removes triangulation-shaped specular bands without
    # changing mesh topology, UVs, pigments or crop/save contracts.
    var smooth_normals: Array[Vector3] = []
    for i in range(RINGS + 1):
        for j in range(SIDES + 1):
            var left := i * (SIDES + 1) + maxi(j - 1, 0)
            var right := i * (SIDES + 1) + mini(j + 1, SIDES)
            var down := maxi(i - 1, 0) * (SIDES + 1) + j
            var up := mini(i + 1, RINGS) * (SIDES + 1) + j
            var tangent_x := verts[right] - verts[left]
            var tangent_y := verts[up] - verts[down]
            var normal := tangent_x.cross(tangent_y).normalized()
            if normal.length_squared() < 0.5:
                normal = Vector3.FORWARD
            smooth_normals.append(normal)
    # Counterclockwise as viewed from +Z: upper lamina faces sunlight,
    # not the soil. Backface culling otherwise hides the upper surface.
    for i in range(RINGS):
        for j in range(SIDES):
            var a := i * (SIDES + 1) + j
            var b := a + SIDES + 1
            for idx in [a, a + 1, b, a + 1, b + 1, b]:
                surface.set_uv(uvs[idx])
                surface.set_color(pigments[idx])
                surface.set_normal(smooth_normals[idx])
                surface.add_vertex(verts[idx])
    # Separate the underside by a small physical lamina thickness. Coincident
    # front/back surfaces cause depth fighting and unstable shadow sampling.
    # This remains a thin botanical sheet, not a solid collision mesh.
    var underside_offset := min(0.0015, width * 0.012)
    # Taper lamina thickness toward the margins and tips. A uniform underside 
    # displacement exposes an unnatural open rim in grazing light. Retain a 
    # small nonzero thickness at boundaries to avoid coincident surfaces. 
    # Both faces use opposite winding for backface-culling and backlighting.
    for i in range(RINGS):
        for j in range(SIDES):
            var a := i * (SIDES + 1) + j
            var b := a + SIDES + 1
            for idx in [b, a + 1, a, b, b + 1, a + 1]:
                surface.set_uv(uvs[idx])
                surface.set_color(pigments[idx] * Color(0.83, 0.91, 0.77))
                surface.set_normal(-smooth_normals[idx])
                var uv := uvs[idx]
                var taper := 0.2 + 0.8 * sin(PI * uv.y) * (1.0 - pow(abs(uv.x * 2.0 - 1.0), 4.0))
                // Offset along the local lamina normal rather than global Z. On curled or
                // strongly cambered leaves a fixed Z displacement produces
                // inconsistent physical thickness and grazing-angle artifacts.
                surface.add_vertex(verts[idx] - smooth_normals[idx] * underside_offset * taper)
    surface.generate_tangents()
    surface.commit(mesh)
    return mesh

static func leaf_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.24, 0.42, 0.19)
    mat.roughness = 0.82
    mat.metallic = 0.0
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_BACK
    mat.subsurf_scatter_enabled = true
    mat.subsurf_scatter_strength = 0.16
    return mat
