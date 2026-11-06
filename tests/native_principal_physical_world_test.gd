extends SceneTree
## Release-blocking native integration check for the ordinary playable scene.
## Run: godot --headless --path . --script tests/native_principal_physical_world_test.gd
## Does not mutate player saves or create content.
const LAUNCH = preload("res://scenes/main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var scene = LAUNCH.instantiate()
    root.add_child(scene)
    current_scene = scene
    for i in range(120):
        await physics_frame
    var hero = scene.get_node_or_null("Farmer")
    if not (hero is CharacterBody3D):
        failures.append("Ordinary launch must instantiate a CharacterBody3D Farmer")
    else:
        var hero_shape_count := 0
        for child in hero.get_children():
            if child is CollisionShape3D and child.shape != null and not child.disabled:
                hero_shape_count += 1
        if hero_shape_count == 0:
            failures.append("Farmer has no active collision shape")
        if not hero.is_on_floor():
            failures.append("Farmer is not grounded after 120 physics frames")
    var world := scene.get_world_3d().direct_space_state
    # House center is (-23,0,-14), width 7; cast through its center at torso height.
    _expect_hit(world, Vector3(-30, 2, -14), Vector3(-16, 2, -14), "farmhouse torso wall")
    # Second house center (-4,0,-15), width 8.
    _expect_hit(world, Vector3(-11, 2, -15), Vector3(3, 2, -15), "second house torso wall")
    # Shipping chest at (-5,0,-5), height 1.24.
    _expect_hit(world, Vector3(-8, 0.6, -5), Vector3(-2, 0.6, -5), "shipping chest")
    # Legacy homestead ground ends at x=72.5. Beyond it must be streamed
    # ground or a deliberate solid boundary. This only tests floor presence.
    for x in [74.0, 149.0, 151.0]:
        _expect_hit(world, Vector3(x, 10, 0), Vector3(x, -30, 0), "ground x=%s" % x)
    if failures.is_empty():
        print("PRINCIPAL_PHYSICAL_WORLD_PASS: 120 frames, hero, houses, chest, edge")
        quit(0)
    else:
        for message in failures:
            push_error("PRINCIPAL_PHYSICAL_WORLD_FAIL: " + message)
        quit(1)

func _expect_hit(space: PhysicsDirectSpaceState3D, origin: Vector3, target: Vector3, label: String) -> void:
    var query := PhysicsRayQueryParameters3D.create(origin, target)
    query.collision_mask = 0xFFFFFFFF
    var hit := space.intersect_ray(query)
    if hit.is_empty():
        failures.append("Missing physical collision: " + label)
