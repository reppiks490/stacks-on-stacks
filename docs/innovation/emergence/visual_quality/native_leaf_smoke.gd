extends SceneTree
## E19 native acceptance for the original, staged foliage candidate.
## Run after staging to PROJECT_ROOT/everbloom_leaf_candidate:
## godot --headless --path PROJECT_ROOT --script res://everbloom_leaf_candidate/native_leaf_smoke.gd
## A headless pass does NOT establish visual fidelity or desktop/mobile FPS.

const SCENE_PATH := "res://everbloom_leaf_candidate/leaf_candidate.tscn"
const MATERIAL_PATH := "res://everbloom_leaf_candidate/leaf_material.tres"
const FRAMES := 120

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene_resource := load(SCENE_PATH) as PackedScene
    if scene_resource == null:
        _fail("staged leaf scene could not be imported")
        return
    var material := load(MATERIAL_PATH) as ShaderMaterial
    if material == null or material.shader == null:
        _fail("staged ShaderMaterial or shader missing")
        return
    for key in ["leaf_albedo", "leaf_normal", "leaf_roughness"]:
        var texture := material.get_shader_parameter(key) as Texture2D
        if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
            _fail("missing or invalid PBR texture: " + key)
            return
    var instance := scene_resource.instantiate()
    root.add_child(instance)
    var blade := instance.get_node_or_null("Blade") as MeshInstance3D
    if blade == null or blade.mesh == null or blade.mesh.get_surface_count() < 1:
        _fail("staged leaf mesh failed to import")
        return
    if blade.material_override != material:
        _fail("staged leaf material binding mismatch")
        return
    var camera := Camera3D.new()
    camera.position = Vector3(0, 0.4, 3)
    camera.look_at(Vector3.ZERO)
    camera.current = true
    instance.add_child(camera)
    material.set_shader_parameter("reduced_motion", true)
    for frame in range(FRAMES):
        await process_frame
        if not is_instance_valid(instance) or not is_instance_valid(blade):
            _fail("leaf instance disappeared at frame " + str(frame))
            return
    if material.get_shader_parameter("reduced_motion") != true:
        _fail("reduced motion toggle did not persist")
        return
    material.set_shader_parameter("reduced_motion", false)
    print("PASS E19 native import, mesh, three PBR maps, 120 frames, reduced-motion toggle")
    print("UNVERIFIED: GPU shader compilation, screenshots, actual wind appearance, FPS, collision")
    instance.queue_free()
    quit(0)

func _fail(reason: String) -> void:
    push_error("FAIL E19 native foliage smoke: " + reason)
    quit(1)
