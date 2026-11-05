extends SceneTree
## Village physical traversal acceptance: an actual CharacterBody3D must not
## tunnel through an existing resident. Run with Godot --headless --path .
## --script res://tests/native_village_traversal_test.gd
## This is not an authored-mesh or desktop visual-quality acceptance.
var checks := 0
var failures := 0

func verify(condition: bool, detail: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("VILLAGE TRAVERSAL: " + detail)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var host = load("res://tests/village_test_host.gd").new()
    root.add_child(host)
    var village = load("res://scripts/village.gd").new()
    root.add_child(village)
    village.setup(host)
    verify(village.residents.size() == 6, "six original residents available")
    if village.residents.is_empty():
        quit(1)
        return
    # Move the whole village far from unrelated geometry while retaining
    # relative resident transforms and the real runtime collision bodies.
    village.position = Vector3(10000.0, 0.0, 10000.0)
    var resident: Node3D = village.residents[0]["node"]
    var obstacle := resident.get_node_or_null("ResidentObstacle") as StaticBody3D
    verify(obstacle != null, "runtime resident obstacle exists")
    if obstacle == null:
        quit(1)
        return
    var player := CharacterBody3D.new()
    player.name = "TraversalProbe"
    player.collision_layer = 2
    player.collision_mask = 1
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.65
    shape.shape = capsule
    shape.position.y = 0.83
    player.add_child(shape)
    village.add_child(player)
    player.global_position = obstacle.global_position + Vector3(0.0, -0.9, 3.0)
    await physics_frame
    await physics_frame
    var start_z := player.global_position.z
    var collided := false
    for frame in range(120):
        player.velocity = Vector3(0.0, 0.0, -2.0)
        player.move_and_slide()
        collided = collided or player.get_slide_collision_count() > 0
        await physics_frame
    var relative_z := player.global_position.z - obstacle.global_position.z
    verify(player.global_position.z < start_z - 0.5, "probe advanced toward resident")
    verify(relative_z > 0.5, "player did not cross resident physical body")
    verify(collided, "probe registered an actual slide collision")
    # Negative control ensures an unrelated obstruction cannot produce a false pass.
    obstacle.collision_layer = 0
    obstacle.collision_mask = 0
    player.global_position = obstacle.global_position + Vector3(0.0, -0.9, 3.0)
    player.velocity = Vector3.ZERO
    await physics_frame
    await physics_frame
    for frame in range(120):
        player.velocity = Vector3(0.0, 0.0, -2.0)
        player.move_and_slide()
        await physics_frame
    var open_relative_z := player.global_position.z - obstacle.global_position.z
    verify(open_relative_z < -0.5, "negative control crosses when collision disabled")
    print("VILLAGE TRAVERSAL: %d checks; %d failures; relative_z=%.3f" % [checks, failures, relative_z])
    quit(0 if failures == 0 else 1)
