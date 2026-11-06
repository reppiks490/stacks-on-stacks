extends SceneTree
## Principal fail-closed native launch collision acceptance.
## Run with: godot --headless --path . --script tests/native_principal_launch_collision_test.gd
## This test intentionally fails until the ordinary launch is physically solid.
const LAUNCH = preload("res://scenes/main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene = LAUNCH.instantiate()
    root.add_child(scene)
    current_scene = scene
    for frame in range(120):
        await physics_frame
    var hero = scene.get_node_or_null("Farmer")
    if hero == null or not (hero is CharacterBody3D):
        failures.append("Ordinary launch has no CharacterBody3D Farmer")
    else:
        if not hero.is_on_floor():
            failures.append("Farmer not grounded after 120 physics frames")
    var space = scene.get_world_3d().direct_space_state
    # A ray through the center of the farmhouse at walking torso height
    # must encounter solid architecture; floor collision cannot satisfy it.
    var house_hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(
        Vector3(-30.0, 2.0, -14.0), Vector3(-16.0, 2.0, -14.0)))
    if house_hit.is_empty():
        failures.append("Farmhouse wall is intangible (torso-height ray missed)")
    # At the original 145-unit edge, a deliberate boundary or continuous
    # walkable terrain must prevent an unprotected fall. The far-side
    # downward ray is a minimal floor-continuity signal, not full streaming QA.
    var edge_hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(
        Vector3(74.0, 10.0, 0.0), Vector3(74.0, -30.0, 0.0)))
    if edge_hit.is_empty():
        failures.append("No walkable ground beyond legacy 145-unit floor edge")
    if failures.is_empty():
        print("PRINCIPAL_NATIVE_COLLISION_PASS: 120 frames, grounded, wall, edge")
        quit(0)
    else:
        for failure in failures:
            push_error("PRINCIPAL_NATIVE_COLLISION_FAIL: " + failure)
        quit(1)
