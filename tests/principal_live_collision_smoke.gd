extends SceneTree
## Native, fail-closed test of the ordinary launched scene and Principal repair.
## Run: godot --headless --path . --script res://tests/principal_live_collision_smoke.gd
const MAIN = preload("res://scenes/main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        push_error("PRINCIPAL FAIL: " + label)

func _run() -> void:
    var world := MAIN.instantiate()
    root.add_child(world)
    await process_frame
    _check(world.has_node("HouseCollisionRepair"), "ordinary launch lacks collision adapter")
    _check(world.has_node("Farmer"), "ordinary launch lacks player")
    var repair := world.get_node_or_null("HouseCollisionRepair")
    var player := world.get_node_or_null("Farmer") as CharacterBody3D
    if player != null:
        _check(player.get_node_or_null("CollisionShape3D") != null or _has_collision_shape(player), "player has no collision shape")
    if repair != null:
        _check(repair.get_child_count() == 6, "expected six house colliders")
        for house in repair.get_children():
            _check(house is StaticBody3D, str(house.name) + " is not a StaticBody3D")
            _check(_has_collision_shape(house), str(house.name) + " lacks active collision shape")
    for i in range(120):
        await physics_frame
    if repair != null:
        var space := world.get_world_3d().direct_space_state
        for house in repair.get_children():
            if not house is StaticBody3D:
                continue
            var center: Vector3 = house.global_position
            var query := PhysicsRayQueryParameters3D.create(center + Vector3(0, 0, 9), center + Vector3(0, 0, -9))
            query.collision_mask = 1
            var hit := space.intersect_ray(query)
            _check(hit.get("collider") == house, str(house.name) + " is not physically raycast-solid")
    if player != null:
        _check(player.global_position.y > -3.0, "player fell through launch terrain")
    world.queue_free()
    await process_frame
    if failures.is_empty():
        print("PRINCIPAL PASS: ordinary launch, six house physics raycasts, grounded player, 120 physics frames")
        quit(0)
    else:
        print("PRINCIPAL FAIL: ", failures)
        quit(1)

func _has_collision_shape(body: Node) -> bool:
    for child in body.get_children():
        if child is CollisionShape3D and child.shape != null and not child.disabled:
            return true
    return false
