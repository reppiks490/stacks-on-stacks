extends SceneTree
## Isolated renderer acceptance harness for original farming leaf geometry.
## Run with a real renderer (not --headless):
## godot --path . --script res://tests/visual_farming_leaf_capture.gd
## Writes user://farming_leaf_quality.png; does not touch saves or game scenes.
const Leaf = preload("res://scripts/farming_visuals/leaf_blade_mesh.gd")
const OUTPUT := "user://farming_leaf_quality.png"
var viewport: SubViewport
var frame_count := 0

func _initialize() -> void:
    call_deferred("_setup")

func _setup() -> void:
    viewport = SubViewport.new()
    viewport.size = Vector2i(1280, 720)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.transparent_bg = false
    root.add_child(viewport)
    var world := Node3D.new()
    viewport.add_child(world)
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.12, 0.16, 0.18)
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color(0.65, 0.72, 0.79)
    environment.environment.ambient_light_energy = 0.7
    world.add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
    sun.light_energy = 2.0
    world.add_child(sun)
    var camera := Camera3D.new()
    camera.position = Vector3(0.0, 0.4, 3.5)
    camera.look_at_from_position(camera.position, Vector3(0.0, 0.15, 0.0))
    camera.fov = 42.0
    camera.current = true
    world.add_child(camera)
    for i in range(3):
        var leaf := MeshInstance3D.new()
        leaf.mesh = Leaf.make_leaf(0.75, 0.17, 0.08 * float(i - 1), 11 + i * 9)
        leaf.material_override = Leaf.leaf_material()
        leaf.position = Vector3(float(i - 1) * 0.7, -0.3, 0.0)
        leaf.rotation_degrees = Vector3(0.0, float(i - 1) * 25.0, float(i - 1) * 8.0)
        world.add_child(leaf)
    process_frame.connect(_on_frame)

func _on_frame() -> void:
    frame_count += 1
    if frame_count < 8:
        return
    process_frame.disconnect(_on_frame)
    var image := viewport.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("No rendered image: renderer acceptance remains unverified")
        quit(2)
        return
    var error := image.save_png(OUTPUT)
    if error != OK:
        push_error("Could not save leaf capture: %s" % error_string(error))
        quit(3)
        return
    print("CAPTURE saved to: ", ProjectSettings.globalize_path(OUTPUT))
    print("Manual silhouette, shading, and culling review REQUIRED; capture is not visual acceptance.")
    quit(0)
