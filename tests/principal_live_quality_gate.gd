extends SceneTree
## Native, fail-closed acceptance of the ordinary Everbloom launch.
## Run: godot --headless --path . --script res://tests/principal_live_quality_gate.gd
## Does not write user saves, mutate player state or require external assets.
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _require(condition: bool, reason: String) -> void:
    if not condition:
        failures.append(reason)
        push_error("QUALITY BLOCKER: " + reason)

func _run() -> void:
    var main_path: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
    _require(main_path == "res://scenes/main.tscn", "Unexpected ordinary launch scene: " + main_path)
    var packed: PackedScene = load(main_path) as PackedScene
    _require(packed != null, "Main scene does not import")
    if packed == null:
        quit(1)
        return
    var game: Node = packed.instantiate()
    root.add_child(game)
    await process_frame
    await physics_frame
    var hero: Node = game.get_node_or_null("Farmer")
    _require(hero is CharacterBody3D, "Real launch lacks CharacterBody3D Farmer")
    var valley: Node = game.get_node_or_null("TheLivingValley")
    _require(valley != null, "Real launch lacks valley")
    if hero != null:
        var skeletons: Array[Node] = hero.find_children("*", "Skeleton3D", true, false)
        _require(not skeletons.is_empty(), "Farmer has no integrated rigged Skeleton3D")
        var animators: Array[Node] = hero.find_children("*", "AnimationPlayer", true, false)
        _require(not animators.is_empty(), "Farmer has no integrated AnimationPlayer")
    if valley != null:
        var colliders: Array[Node] = valley.find_children("*", "CollisionShape3D", true, false)
        _require(colliders.size() > 1, "Only terrain or no collisions found; solid buildings/props unproven")
    # Exercise the physics world, not merely count CollisionShape3D nodes.
    # Existing farmhouse center (-23,-14), house center (22,10), and
    # tree-free town area are deterministic in the ordinary valley setup.
    if valley != null:
        var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
        for target in [Vector3(-23.0, 2.0, -14.0), Vector3(22.0, 2.0, 10.0)]:
            var query := PhysicsRayQueryParameters3D.create(
                target + Vector3(-12.0, 0.0, 0.0),
                target + Vector3(12.0, 0.0, 0.0))
            query.collision_mask = 1
            var hit: Dictionary = space.intersect_ray(query)
            _require(not hit.is_empty(), "House wall has no tangible physics at " + str(target))
        # The advertised streamed world must support grounded travel outside
        # the old 145-unit starter plot, rather than expose a void.
        for point in [Vector3(73.0, 0.0, 0.0), Vector3(150.0, 0.0, 0.0)]:
            var ground_query := PhysicsRayQueryParameters3D.create(
                point + Vector3.UP * 20.0, point + Vector3.DOWN * 30.0)
            ground_query.collision_mask = 1
            var ground_hit: Dictionary = space.intersect_ray(ground_query)
            _require(not ground_hit.is_empty(), "Missing streamed terrain physics at " + str(point))
    for i in range(120):
        await physics_frame
    _require(is_instance_valid(game), "Main game freed during 120-frame smoke")
    print("PRINCIPAL LIVE QUALITY GATE: " + ("PASS" if failures.is_empty() else "BLOCKED: " + str(failures.size()) + " failures"))
    quit(0 if failures.is_empty() else 1)
