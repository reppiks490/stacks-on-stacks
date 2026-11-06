extends SceneTree
## Native release gate for the actual configured startup scene.
## Run: godot --headless --path . --script res://tests/principal_live_collision_smoke.gd
## Intentionally fails on current non-solid buildings; never asserts visual quality.
const STARTUP := preload("res://scenes/main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := STARTUP.instantiate()
    get_root().add_child(root)
    await process_frame
    var hero = root.get("hero")
    if not (hero is CharacterBody3D):
        failures.append("Actual launch has no CharacterBody3D hero")
    var valley = root.get("valley")
    if not (valley is Node3D):
        failures.append("Actual launch has no valley node")
    for frame in range(120):
        await physics_frame
    if hero is CharacterBody3D:
        if not hero.is_on_floor():
            failures.append("Hero not grounded after 120 physics frames")
        if hero.global_position.y < -0.5:
            failures.append("Hero fell below expected ground")
    # Release gate A: the live player must actually contain an authored, skinned
    # model and an animation controller, not merely a primitive visual shell.
    if hero is CharacterBody3D:
        var has_skin := false
        var has_skeleton := false
        var has_animation := false
        var pending: Array[Node] = [hero]
        while not pending.is_empty():
            var node: Node = pending.pop_back()
            if node is Skeleton3D:
                has_skeleton = true
            if node is MeshInstance3D and node.skin != null:
                has_skin = true
            if node is AnimationPlayer or node is AnimationTree:
                has_animation = true
            for child in node.get_children():
                pending.append(child)
        if not has_skeleton or not has_skin:
            failures.append("Live hero has no integrated skinned mesh + Skeleton3D")
        if not has_animation:
            failures.append("Live hero has no animation controller")
    if valley is Node3D:
        var space := root.get_world_3d().direct_space_state
        # The front facade of the original farmhouse is at z=-11.4.
        # Cast horizontally at chest height; a solid building MUST block it.
        var query := PhysicsRayQueryParameters3D.create(
            Vector3(-23.0, 1.8, -7.0), Vector3(-23.0, 1.8, -17.0))
        if hero is CollisionObject3D:
            query.exclude = [hero.get_rid()]
        var hit := space.intersect_ray(query)
        if hit.is_empty():
            failures.append("Farmhouse wall is intangible (horizontal collision ray missed)")
        else:
            var hit_point: Vector3 = hit.get("position", Vector3.ZERO)
            if hit_point.z > -11.0 or hit_point.z < -17.0:
                failures.append("Farmhouse probe hit unrelated geometry, not the building")
        # Door-only collision is insufficient: probe both side facades.
        for side_x in [-25.5, -20.5]:
            var side_query := PhysicsRayQueryParameters3D.create(
                Vector3(side_x, 1.8, -7.0), Vector3(side_x, 1.8, -17.0))
            if hero is CollisionObject3D:
                side_query.exclude = [hero.get_rid()]
            var side_hit := space.intersect_ray(side_query)
            if side_hit.is_empty():
                failures.append("Farmhouse side wall intangible at x=" + str(side_x))
            else:
                var side_position: Vector3 = side_hit.get("position", Vector3.ZERO)
                if side_position.z > -11.0 or side_position.z < -17.0:
                    failures.append("Side wall probe hit unrelated geometry at x=" + str(side_x))
        # A 145-unit-only floor is not the required 4.8 km traversable world.
        # These points lie immediately beyond its old +/-72.5 boundary.
        # Fail closed until streamed chunk collision is genuinely available.
        for edge_point in [Vector3(74.0, 4.0, 0.0), Vector3(-74.0, 4.0, 0.0), Vector3(0.0, 4.0, 74.0), Vector3(0.0, 4.0, -74.0)]:
            var edge_query := PhysicsRayQueryParameters3D.create(edge_point, edge_point + Vector3.DOWN * 10.0)
            if space.intersect_ray(edge_query).is_empty():
                failures.append("Missing walkable terrain collision beyond legacy map edge at " + str(edge_point))
        # Floor support at the playable homestead spawn.
        var floor_query := PhysicsRayQueryParameters3D.create(
            Vector3(-15, 3, -7), Vector3(-15, -3, -7))
        if space.intersect_ray(floor_query).is_empty():
            failures.append("Spawn ground lacks collision")
    if failures.is_empty():
        print("PRINCIPAL NATIVE COLLISION SMOKE PASS (120 physics frames; limited probes only)")
    else:
        for failure in failures:
            push_error("PRINCIPAL RELEASE BLOCKER: " + failure)
        print("PRINCIPAL NATIVE COLLISION SMOKE BLOCKED: ", failures.size())
    root.queue_free()
    quit(0 if failures.is_empty() else 1)
