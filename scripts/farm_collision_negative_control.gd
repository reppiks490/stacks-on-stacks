extends SceneTree
## Negative-control farm collision acceptance: the oracle must fail when the
## expected soil collider is disabled. Isolated fixture, not assembled-game proof.
## godot --headless --path . --script scripts/farm_collision_negative_control.gd
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
        push_error("Expected 30 beds, found %d" % farm.beds.size())
        quit(1)
        return
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    var tested := 0
    for i in range(farm.beds.size()):
        var holder: Node3D = farm.beds[i]["holder"]
        var body: StaticBody3D = holder.get_node_or_null("SoilCollision")
        if body == null:
            failures.append("Bed %d has no soil body" % i)
            continue
        var shape: CollisionShape3D = body.get_node_or_null("FurrowSurface")
        if shape == null or shape.shape == null:
            failures.append("Bed %d has no soil shape" % i)
            continue
        var p := holder.global_position
        var ray := PhysicsRayQueryParameters3D.create(
            p + Vector3.UP * 2.0, p + Vector3.DOWN * 2.0)
        ray.collision_mask = 1
        var initial := space.intersect_ray(ray)
        if initial.is_empty() or initial.get("collider") != body:
            failures.append("Bed %d did not hit expected soil before mutation" % i)
            continue
        shape.set_deferred("disabled", true)
        await physics_frame
        var removed := space.intersect_ray(ray)
        if not removed.is_empty() and removed.get("collider") == body:
            failures.append("Bed %d still hits disabled collider" % i)
        shape.set_deferred("disabled", false)
        await physics_frame
        var restored := space.intersect_ray(ray)
        if restored.is_empty() or restored.get("collider") != body:
            failures.append("Bed %d collision failed to recover" % i)
        tested += 1
    if tested != 30:
        failures.append("Only %d/30 negative controls exercised" % tested)
    if failures.is_empty():
        print("FARM_COLLISION_NEGATIVE_CONTROL PASS: 30 remove/restore probes")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("FARM_COLLISION_NEGATIVE_CONTROL FAIL: %d failures" % failures.size())
        quit(1)
