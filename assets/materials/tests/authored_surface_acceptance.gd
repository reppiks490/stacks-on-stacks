extends SceneTree
# Native Godot 4.x acceptance for the isolated authored-surface shader.
# This is not a screenshot, GPU frame-time measurement, or visual approval.
const SHADER_PATH := "res://assets/materials/authored_surface.gdshader"
const CHUNK_SIZE := 150.0
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("AUTHORED SURFACE FAIL: " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var shader := load(SHADER_PATH) as Shader
    check(shader != null, "shader resource loads")
    if shader != null:
        var material := ShaderMaterial.new()
        material.shader = shader
        check(material.shader == shader, "ShaderMaterial binds authored shader")
        var code := shader.code
        check(code.contains("MODEL_MATRIX * vec4(VERTEX, 1.0)"), "macro coordinates derive from world-space vertices")
        check(code.contains("NORMAL_MAP_DEPTH"), "normal intensity is configurable")
        check(code.contains("ROUGHNESS"), "authored roughness feeds PBR surface")
        check(code.contains("fwidth(phase_a)") and code.contains("fwidth(phase_b)"), "both rotated harmonic phases are derivative-filtered")
        check(code.contains("max_footprint"), "maximum rotated harmonic footprint drives attenuation")
        check(not code.contains("fwidth(macro_phase)"), "unrotated footprint cannot silently replace harmonic filtering")
        # A diagonal projected footprint can make a rotated harmonic vary faster
        # than either unrotated axis; the old filter would under-attenuate it.
        var pixel_dx := Vector2(0.7, -0.7)
        var pixel_dy := Vector2.ZERO
        var old_footprint: float = maxf(absf(pixel_dx.x) + absf(pixel_dy.x), absf(pixel_dx.y) + absf(pixel_dy.y))
        var rotated_axis := Vector2(0.8660254, -0.5)
        var rotated_footprint: float = absf(pixel_dx.dot(rotated_axis)) + absf(pixel_dy.dot(rotated_axis))
        check(rotated_footprint > old_footprint + 0.2, "negative control: rotated harmonic can exceed unrotated footprint")
        var old_fade := 1.0 - smoothstep(0.5, 1.5, old_footprint)
        var corrected_fade := 1.0 - smoothstep(0.5, 1.5, rotated_footprint)
        check(corrected_fade < old_fade, "rotated filtering suppresses the diagonal aliasing case")
        check(code.contains("smoothstep(0.5, 1.5"), "macro pigment fades under subpixel sampling")
        check(code.contains("vec2 phase_a") and code.contains("vec2 phase_b"), "rotated world-anchored pigment harmonics are present")
        for footprint in [0.0, 0.5, 1.0, 1.5, 2.0]:
            var fade := 1.0 - smoothstep(0.5, 1.5, footprint)
            check(fade >= 0.0 and fade <= 1.0, "pigment attenuation remains bounded")
            if footprint >= 1.5:
                check(is_zero_approx(fade), "subpixel pigment fades to zero")
        # Material acceptance must exercise actual uniform bindings rather than
        # accepting a shader solely because its source contains expected words.
        var declared_uniforms := {}
        for entry in shader.get_shader_uniform_list():
            declared_uniforms[String(entry.get("name", ""))] = int(entry.get("type", -1))
        for required_name in ["albedo_map", "normal_map", "roughness_map", "pigment", "uv_scale", "normal_strength", "roughness_floor", "roughness_ceiling", "macro_variation", "macro_scale"]:
            check(declared_uniforms.has(required_name), "shader exposes required uniform: " + required_name)
        material.set_shader_parameter("macro_variation", 0.045)
        material.set_shader_parameter("macro_scale", 0.035)
        material.set_shader_parameter("normal_strength", 0.7)
        check(is_equal_approx(float(material.get_shader_parameter("macro_variation")), 0.045), "macro variation binds to material")
        check(is_equal_approx(float(material.get_shader_parameter("macro_scale")), 0.035), "macro scale binds to material")
        check(is_equal_approx(float(material.get_shader_parameter("normal_strength")), 0.7), "normal strength binds to material")
        check(code.contains("texture(albedo_map"), "authored albedo is sampled")
        # Independent 150-unit chunks meet at the same WORLD coordinate even
        # though their local vertices and MODEL_MATRIX translations differ.
        # Compare both x and z borders, including a negative-coordinate origin.
        var scale := 0.035
        var samples := [0.0, 42.75, 75.0, 149.9]
        for origin_x in [-300.0, 0.0, 150.0, 450.0]:
            for z in samples:
                var left_local := Vector3(CHUNK_SIZE, 0.0, z)
                var right_local := Vector3(0.0, 0.0, z)
                var left_world := Transform3D(Basis.IDENTITY, Vector3(origin_x, 0.0, 0.0)) * left_local
                var right_world := Transform3D(Basis.IDENTITY, Vector3(origin_x + CHUNK_SIZE, 0.0, 0.0)) * right_local
                check(left_world.is_equal_approx(right_world), "x seam transforms agree at origin %s" % origin_x)
                var a := sin(left_world.x * scale) * cos(left_world.z * scale)
                var b := sin(right_world.x * scale) * cos(right_world.z * scale)
                check(is_equal_approx(a, b), "x seam pigment agrees at origin %s" % origin_x)
                check(is_equal_approx(_pigment(left_world), _pigment(right_world)), "x seam rotated pigment agrees at origin %s" % origin_x)
        for origin_z in [-150.0, 0.0, 300.0]:
            for x in samples:
                var near_local := Vector3(x, 0.0, CHUNK_SIZE)
                var far_local := Vector3(x, 0.0, 0.0)
                var near_world := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, origin_z)) * near_local
                var far_world := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, origin_z + CHUNK_SIZE)) * far_local
                check(near_world.is_equal_approx(far_world), "z seam transforms agree at origin %s" % origin_z)
                var a := sin(near_world.x * scale) * cos(near_world.z * scale)
                var b := sin(far_world.x * scale) * cos(far_world.z * scale)
                check(is_equal_approx(a, b), "z seam pigment agrees at origin %s" % origin_z)
                check(is_equal_approx(_pigment(near_world), _pigment(far_world)), "z seam rotated pigment agrees at origin %s" % origin_z)
        # A local-coordinate shader would reset the phase on the neighboring
        # chunk. This fixture must detect that incorrect implementation.
        var bad_x := sin(0.0) * cos(42.75 * scale)
        var good_x := sin(CHUNK_SIZE * scale) * cos(42.75 * scale)
        check(absf(good_x - bad_x) > 0.01, "negative control detects x-phase reset")
        var bad_z := sin(42.75 * scale) * cos(0.0)
        var good_z := sin(42.75 * scale) * cos(CHUNK_SIZE * scale)
        check(absf(good_z - bad_z) > 0.01, "negative control detects z-phase reset")
    print("AUTHORED SURFACE ACCEPTANCE: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)

# Mirrors the shader harmonics for independent seam and bounded-amplitude checks.
func _pigment(world: Vector3) -> float:
    var phase := Vector2(world.x, world.z) * 0.035
    var a := Vector2(phase.dot(Vector2(0.8660254, -0.5)), phase.dot(Vector2(0.5, 0.8660254)))
    var b := Vector2(phase.dot(Vector2(0.6, 0.8)), phase.dot(Vector2(-0.8, 0.6))) * 0.61
    return 0.65 * sin(a.x) * cos(a.y) + 0.35 * sin(b.x) * cos(b.y)
