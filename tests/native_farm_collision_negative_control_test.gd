extends SceneTree
## Farming-owned native collision negative-control regression.
## Run: godot --headless --path . --script res://tests/native_farm_collision_negative_control_test.gd
## This tests the isolated farm scene, not the complete world or player controller.
const FARM = preload("res://scripts/farm.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("FAIL: " + label)

func _run() -> void:
    var host := FarmHost.new()
    root.add_child(host)
    var farm := FARM.new()
    root.add_child(farm)
    farm.setup(host)
    _check(farm.beds.size() == 30, "exactly 30 existing beds")
    await physics_frame
    await physics_frame
    var space := farm.get_world_3d().direct_space_state
    for i in range(farm.beds.size()):
        var holder: Node3D = farm.beds[i]["holder"]
        var body := holder.get_node_or_null("SoilCollision") as StaticBody3D
        _check(body != null, "bed %d collision body exists" % i)
        if body == null:
            continue
        var shape := body.get_node_or_null("FurrowSurface") as CollisionShape3D
        _check(shape != null and shape.shape != null, "bed %d shape exists" % i)
        if shape == null or shape.shape == null:
            continue
        var center := holder.global_position
        var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 1.0, center + Vector3.DOWN * 1.0)
        query.collision_mask = 1
        var hit := space.intersect_ray(query)
        _check(hit.get("collider") == body, "bed %d ray contacts soil" % i)
        shape.set_deferred("disabled", true)
        await physics_frame
        hit = space.intersect_ray(query)
        _check(hit.is_empty(), "bed %d negative control: disabled collider must not hit" % i)
        shape.set_deferred("disabled", false)
        await physics_frame
        hit = space.intersect_ray(query)
        _check(hit.get("collider") == body, "bed %d re-enabled collider restores hit" % i)
    print("FARM COLLISION NEGATIVE CONTROL: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
    farm.queue_free()
    host.queue_free()
    quit(0 if failures == 0 else 1)

class FarmHost:
    extends Node
    var crop_definitions := {}
    func day_epoch() -> int:
        return 0
