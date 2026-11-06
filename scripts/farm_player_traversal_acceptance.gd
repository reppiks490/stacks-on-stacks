extends SceneTree
## Farming lane: physical traversal regression for a planted bed.
## Native: godot --headless --path . --script scripts/farm_player_traversal_acceptance.gd
## Isolated fixture; NOT proof of ordinary assembled game or world boundary.
const FarmScript = preload("res://scripts/farm.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var farm: Node3D = FarmScript.new()
    root.add_child(farm)
    farm.setup(null)
    if farm.beds.size() != 30:
        push_error("Expected 30 beds")
        quit(1)
        return
    var holder: Node3D = farm.beds[0]["holder"]
    var surface: StaticBody3D = holder.get_node_or_null("SoilCollision")
    if surface == null:
        push_error("Missing soil collision")
        quit(1)
        return
    var player := CharacterBody3D.new()
    player.name = "TraversalProbe"
    player.collision_layer = 2
    player.collision_mask = 1
    player.floor_snap_length = 0.3
    player.position = holder.global_position + Vector3(0, 2.0, 0)
    var capsule := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.22
    shape.height = 1.2
    capsule.shape = shape
    player.add_child(capsule)
    root.add_child(player)
    await physics_frame
    var grounded := false
    var min_foot := INF
    for frame in range(120):
        player.velocity = Vector3(0, -6.0, 0)
        player.move_and_slide()
        var foot := player.global_position.y - shape.height * 0.5
        min_foot = minf(min_foot, foot)
        if player.is_on_floor():
            grounded = true
        await physics_frame
    if not grounded:
        failures.append("Player never registered farm floor during 120 physics frames")
    if min_foot < holder.global_position.y - 0.20:
        failures.append("Player penetrated beneath farm surface: foot=%.3f" % min_foot)
    if player.global_position.y < holder.global_position.y:
        failures.append("Player fell through the soil")
    if failures.is_empty():
        print("FARM_PLAYER_TRAVERSAL PASS: 120 frames, grounded, no floor penetration")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("FARM_PLAYER_TRAVERSAL FAIL: %d checks" % failures.size())
        quit(1)
