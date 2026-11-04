extends SceneTree
## Farming-owned native CharacterBody3D ground-contact regression.
## This tests isolated bed geometry with a moving player-sized body, not the assembled map.
## Run: godot --headless --path . --script res://tests/native_farm_body_grounding_test.gd
const FARM = preload("res://scripts/farm.gd")
var failures := 0

class FarmHost:
    extends Node
    var crop_definitions := {}
    func day_epoch() -> int:
        return 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error("FAIL: " + message)

func _run() -> void:
    var host := FarmHost.new()
    root.add_child(host)
    var farm := FARM.new()
    root.add_child(farm)
    farm.setup(host)
    _check(farm.beds.size() == 30, "all existing planting beds remain present")
    await physics_frame
    await physics_frame
    for i in range(farm.beds.size()):
        var holder: Node3D = farm.beds[i]["holder"]
        var body := CharacterBody3D.new()
        body.collision_layer = 2
        body.collision_mask = 1
        var capsule := CollisionShape3D.new()
        var shape := CapsuleShape3D.new()
        shape.radius = 0.24
        shape.height = 1.7
        capsule.shape = shape
        body.add_child(capsule)
        root.add_child(body)
        body.global_position = holder.global_position + Vector3.UP * 2.0
        body.velocity = Vector3.DOWN * 5.0
        var grounded := false
        for step in range(75):
            body.velocity.y = -5.0
            body.move_and_slide()
            if body.is_on_floor():
                grounded = true
                break
            await physics_frame
        _check(grounded, "bed %d supports a moving CharacterBody3D" % i)
        _check(body.global_position.y > holder.global_position.y + 0.5,
            "bed %d player body did not fall through soil" % i)
        body.queue_free()
        await physics_frame
    print("FARM BODY GROUNDING: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
    farm.queue_free()
    host.queue_free()
    quit(0 if failures == 0 else 1)
