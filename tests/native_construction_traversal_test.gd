extends SceneTree
## Run: godot --headless --path . --script res://tests/native_construction_traversal_test.gd
## CharacterBody3D movement regression: solid walls must stop the player,
## the intentional doorway must allow entry, and the interior floor must hold.
const ValleyScript = preload("res://scripts/valley.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var valley: Node3D = ValleyScript.new()
    root.add_child(valley)
    valley._land()
    valley._house(Vector3.ZERO, Color.WHITE, Color.DARK_RED, 7.0)
    await physics_frame
    await physics_frame
    var blocked := await _walk(root, Vector3(2.0, 1.0, 4.2), Vector3(0, 0, -3.0), 90)
    if blocked.z < 2.85:
        failures.append("front wall penetration: player z=%.3f" % blocked.z)
    var entered := await _walk(root, Vector3(0, 1.0, 4.2), Vector3(0, 0, -3.0), 90)
    if entered.z > 1.0:
        failures.append("doorway unexpectedly blocked: player z=%.3f" % entered.z)
    var grounded := await _walk(root, Vector3(0, 1.0, 0), Vector3.ZERO, 90)
    if grounded.y < 0.75 or grounded.y > 1.2:
        failures.append("interior floor failed to support player: y=%.3f" % grounded.y)
    root.queue_free()
    if failures.is_empty():
        print("PASS: CharacterBody3D wall blocking, doorway entry, floor grounding")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _walk(root: Node3D, start: Vector3, horizontal: Vector3, frames: int) -> Vector3:
    var player := CharacterBody3D.new()
    player.name = "TraversalProbe"
    player.collision_layer = 2
    player.collision_mask = 1
    player.position = start
    player.floor_snap_length = 0.2
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.8
    collider.shape = capsule
    player.add_child(collider)
    root.add_child(player)
    await physics_frame
    for frame in range(frames):
        player.velocity = Vector3(horizontal.x, player.velocity.y - 9.8 / 60.0, horizontal.z)
        player.move_and_slide()
        await physics_frame
    var result := player.position
    player.queue_free()
    await physics_frame
    return result
