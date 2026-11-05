extends SceneTree
## Principal physical gameplay acceptance: exercise a moving collision body against
## the ordinary startup scene, not a ray-only or isolated mock.
## Run: godot --headless --path . --script res://tests/native_principal_body_traversal_20261105.gd
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("TRAVERSAL BLOCKER: " + message)

func _run() -> void:
    var startup := str(ProjectSettings.get_setting("application/run/main_scene", ""))
    var packed := load(startup) as PackedScene
    if packed == null:
        _assert(false, "Configured startup scene cannot load: " + startup)
        quit(1)
        return
    var scene := packed.instantiate()
    get_root().add_child(scene)
    current_scene = scene
    for frame in range(120):
        await physics_frame
    var hero := scene.get_node_or_null("Farmer") as CharacterBody3D
    _assert(hero != null, "Ordinary startup scene has no Farmer CharacterBody3D")
    if hero != null:
        _assert(hero.get_node_or_null("CollisionShape3D") != null or _has_collision(hero), "Farmer has no collision shape")
    # Exercise the physics solver with a real capsule against the existing farmhouse.
    var probe := CharacterBody3D.new()
    probe.name = "PrincipalCollisionProbe"
    probe.collision_layer = 0
    probe.collision_mask = 0x7fffffff
    var shape_node := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.75
    shape_node.shape = capsule
    shape_node.position.y = 0.91
    probe.add_child(shape_node)
    scene.add_child(probe)
    probe.global_position = Vector3(-29.0, 0.0, -14.0)
    await physics_frame
    var hit := probe.move_and_collide(Vector3(12, 0, 0), true)
    _assert(hit != null and absf(hit.get_normal().y) < 0.5, "Capsule traverses farmhouse or contacts floor instead of wall")
    if hit != null:
        _assert(hit.get_travel().x < 5.0, "Farmhouse collision only occurs after entering its footprint")
    # World edge: floor must exist or a physical boundary must stop forward motion.
    probe.global_position = Vector3(70, 0.0, 0)
    await physics_frame
    var edge_motion := probe.move_and_collide(Vector3(20, 0, 0), true)
    var space := scene.get_world_3d().direct_space_state
    var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(80, 4, 0), Vector3(80, -8, 0)))
    var has_edge_wall := edge_motion != null and absf(edge_motion.get_normal().y) < 0.5 and edge_motion.get_travel().x < 19.0
    var has_supported_ground := not ground.is_empty() and ground.get("normal", Vector3.ZERO).y > 0.7
    _assert(has_edge_wall or has_supported_ground, "No verified physical boundary wall or walkable streamed ground at x=80")
    # A floor ray alone cannot certify continuity: require support at both sides of the old 145-unit edge.
    var inside_ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(70, 4, 0), Vector3(70, -8, 0)))
    _assert(not inside_ground.is_empty() and inside_ground.get("normal", Vector3.ZERO).y > 0.7, "Walkable ground missing just inside original homestead boundary")
    # A floor collision must not masquerade as a blocking wall; horizontal probes start above the floor.
    _assert(not (edge_motion != null and absf(edge_motion.get_normal().y) >= 0.5 and not has_supported_ground), "Edge probe hit only a floor, not a boundary wall")
    # Release-quality visuals must be real mesh/rig assets in the ordinary startup hero.
    if hero != null:
        var rigged := _contains_skeleton(hero)
        _assert(rigged, "Ordinary Farmer has no Skeleton3D; primitive body is not an authored rigged character")
    probe.queue_free()
    scene.queue_free()
    await process_frame
    if failures.is_empty():
        print("PRINCIPAL BODY TRAVERSAL PASS (limited probes; streamed chunk, animation, save and visuals still require separate proof)")
        quit(0)
    else:
        print("PRINCIPAL BODY TRAVERSAL FAIL: %d defects" % failures.size())
        quit(1)

func _has_collision(body: Node) -> bool:
    for child in body.get_children():
        if child is CollisionShape3D and child.shape != null:
            return true
    return false

func _contains_skeleton(node: Node) -> bool:
    if node is Skeleton3D:
        return true
    for child in node.get_children():
        if _contains_skeleton(child):
            return true
    return false
