extends SceneTree
# Run with: godot --headless --path . --script docs/innovation/emergence/visual_quality/pbr_shader_acceptance.gd
# Checks resource loading and uniform interface, not rendered appearance or FPS.
func _initialize() -> void:
    var path := "res://docs/innovation/emergence/visual_quality/foliage_pbr_bound.gdshader"
    var shader := load(path) as Shader
    if shader == null:
        push_error("E19: shader import/parse failed")
        quit(1)
        return
    var material := ShaderMaterial.new()
    material.shader = shader
    var required := ["leaf_albedo", "leaf_normal", "leaf_roughness", "wind_strength", "reduced_motion", "roughness_scale"]
    var present: Dictionary = {}
    for uniform_info in shader.get_shader_uniform_list():
        present[str(uniform_info["name"])] = true
    for name in required:
        if not present.has(name):
            push_error("E19: missing shader uniform " + name)
            quit(1)
            return
    material.set_shader_parameter("reduced_motion", true)
    material.set_shader_parameter("wind_strength", 0.0)
    material.set_shader_parameter("roughness_scale", 0.85)
    if material.get_shader_parameter("reduced_motion") != true:
        push_error("E19: reduced motion control failed")
        quit(1)
        return
    print("PASS E19 original leaf PBR shader import/uniform contract (render and FPS unverified)")
    quit(0)
