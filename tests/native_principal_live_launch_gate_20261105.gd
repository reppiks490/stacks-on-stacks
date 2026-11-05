extends SceneTree
## Principal release gate for the ACTUAL project.godot startup scene.
## Intentionally fails while ordinary launch still uses primitive hero / 145m valley.
## Run: godot --headless --path . --script res://tests/native_principal_live_launch_gate_20261105.gd
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_verify")

func _require(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error("LIVE-LAUNCH BLOCKER: " + message)

func _verify() -> void:
    var scene_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
    _require(scene_path == "res://scenes/main.tscn", "Unexpected startup scene; inspect actual launch path: " + scene_path)
    var packed := load(scene_path) as PackedScene
    if packed == null:
        _require(false, "Startup scene failed to load")
        quit(1)
        return
    var root := packed.instantiate()
    get_root().add_child(root)
    current_scene = root
    for frame in range(120):
        await process_frame
        await physics_frame
    var hero := root.get_node_or_null("Farmer") as CharacterBody3D
    _require(hero != null, "Ordinary launch did not instantiate Farmer CharacterBody3D")
    var world := root.get_node_or_null("TheLivingValley")
    _require(world != null, "Ordinary launch did not instantiate TheLivingValley")
    if hero != null:
        var skeletons := hero.find_children("*", "Skeleton3D", true, false)
        var skinned := hero.find_children("*", "MeshInstance3D", true, false)
        var animations := hero.find_children("*", "AnimationPlayer", true, false)
        var has_skinned_mesh := false
        for mesh in skinned:
            if mesh is MeshInstance3D and mesh.skin != null:
                has_skinned_mesh = true
        _require(not skeletons.is_empty(), "Live hero has no Skeleton3D; primitive-only avatar is not acceptable")
        _require(has_skinned_mesh, "Live hero has no skinned MeshInstance3D")
        _require(not animations.is_empty(), "Live hero has no AnimationPlayer")
        _require(hero.get_slide_collision_count() >= 0, "Hero physics API unavailable")
    if world != null:
        var floor_bodies := world.find_children("*", "StaticBody3D", true, false)
        _require(not floor_bodies.is_empty(), "World has no static terrain physics")
        var streamers := world.find_children("*", "Node3D", true, false)
        var found_32_grid := false
        for node in streamers:
            if node.has_method("chunk_for_position") or node.has_method("get_chunk_for_world_position"):
                found_32_grid = true
        _require(found_32_grid, "No discoverable chunk-streaming interface in ordinary world; verify 32x32x150 separately")
    root.queue_free()
    await process_frame
    if failures.is_empty():
        print("PRINCIPAL LIVE LAUNCH GATE PASS (structural only; screenshots/FPS/save tests still required)")
        quit(0)
    else:
        print("PRINCIPAL LIVE LAUNCH GATE FAIL: %d blockers" % failures.size())
        for failure in failures:
            print(" - " + failure)
        quit(1)
