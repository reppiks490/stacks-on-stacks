extends SceneTree
## Native physical admission for the six currently shipped residents.
## godot --headless --path . --script res://tests/native_village_npc_collision_test.gd
var checks := 0
var failures := 0

func verify(ok: bool, detail: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("VILLAGE NPC PHYSICS: " + detail)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var host = load("res://tests/village_test_host.gd").new()
    root.add_child(host)
    var village = load("res://scripts/village.gd").new()
    root.add_child(village)
    village.setup(host)
    verify(village.residents.size() == 6, "six original residents preserved")
    await physics_frame
    for resident in village.residents:
        var actor: Node3D = resident.get("node")
        var rid := str(resident.get("id", "unknown"))
        verify(actor != null, rid + " actor missing")
        if actor == null:
            continue
        var body := actor.get_node_or_null("ResidentObstacle") as StaticBody3D
        verify(body != null, rid + " missing physical obstacle")
        if body == null:
            continue
        verify(body.collision_layer & 1 != 0, rid + " does not collide on world layer")
        var shape := body.get_node_or_null("ResidentCollision") as CollisionShape3D
        verify(shape != null and shape.shape is CapsuleShape3D and not shape.disabled,
            rid + " has no enabled collision capsule")
        # Physics query verifies the obstacle is registered in the live world.
        var center := body.global_position
        var query := PhysicsRayQueryParameters3D.create(center + Vector3(0, 0, 2),
            center + Vector3(0, 0, -2), 1)
        var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
        verify(hit.get("collider") == body, rid + " is not physically raycastable")
    print("VILLAGE NPC PHYSICS: %d checks; %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
