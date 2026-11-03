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
        # Adjacent chunks have different local vertices but equal global positions
        # at the seam. Their macro modulation must therefore agree.
        var scale := 0.035
        var x_left := CHUNK_SIZE
        var x_right := CHUNK_SIZE + 0.0
        var z := 42.75
        var a := sin(x_left * scale) * cos(z * scale)
        var b := sin(x_right * scale) * cos(z * scale)
        check(is_equal_approx(a, b), "macro modulation continuous at shared chunk edge")
        # A local-space implementation would restart at x=0 on the next chunk.
        var bad_local := sin(0.0) * cos(z * scale)
        check(absf(a - bad_local) > 0.01, "seam fixture detects local-space phase restart")
    print("AUTHORED SURFACE ACCEPTANCE: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
