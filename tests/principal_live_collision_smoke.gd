extends SceneTree
## Native release gate for the actual configured startup scene.
## Run: godot --headless --path . --script res://tests/principal_live_collision_smoke.gd
## Intentionally fails on current non-solid buildings; never asserts visual quality.
const STARTUP := preload("res://scenes/main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := STARTUP.instantiate()
    get_root().add_child(root)
    await process_frame
    var hero = root.get("hero")
    if not (hero is CharacterBody3D):
        failures.append("Actual launch has no CharacterBody3D hero")
    var valley = root.get("valley")
    if not (valley is Node3D):
        failures.append("Actual launch has no valley node")
    for frame in range(120):
        await physics_frame
    if hero is CharacterBody3D:
        if not hero.is_on_floor():
            failures.append("Hero not grounded after 120 physics frames")
        if hero.global_position.y < -0.5:
            failures.append("Hero fell below expected ground")
    if valley is Node3D:
        var space := root.get_world_3d().direct_space_state
        # The front facade of the original farmhouse is at z=-11.4.
        # Cast horizontally at chest height; a solid building MUST block it.
        var query := PhysicsRayQueryParameters3D.create(
            Vector3(-23.0, 1.8, -7.0), Vector3(-23.0, 1.8, -17.0))
        var hit := space.intersect_ray(query)
        if hit.is_empty():
            failures.append("Farmhouse wall is intangible (horizontal collision ray missed)")
        # Floor support at the playable homestead spawn.
        var floor_query := PhysicsRayQueryParameters3D.create(
            Vector3(-15, 3, -7), Vector3(-15, -3, -7))
        if space.intersect_ray(floor_query).is_empty():
            failures.append("Spawn ground lacks collision")
    if failures.is_empty():
        print("PRINCIPAL NATIVE COLLISION SMOKE PASS (120 physics frames; limited probes only)")
    else:
        for failure in failures:
            push_error("PRINCIPAL RELEASE BLOCKER: " + failure)
        print("PRINCIPAL NATIVE COLLISION SMOKE BLOCKED: ", failures.size())
    root.queue_free()
    quit(0 if failures.is_empty() else 1)
