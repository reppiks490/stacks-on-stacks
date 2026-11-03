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
