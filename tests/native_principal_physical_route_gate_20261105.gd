extends SceneTree
## Principal physical acceptance for the ordinary Everbloom launch.
## Tests the assembled startup world, not a standalone geometry fixture.
## Run after import: godot --headless --path . --script res://tests/native_principal_physical_route_gate_20261105.gd
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)
        push_error("PHYSICAL ROUTE BLOCKER: " + reason)

func _run() -> void:
    var path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
    var packed := load(path) as PackedScene
    if packed == null:
        _check(false, "Cannot load configured startup scene: " + path)
        quit(1)
        return
    var root := packed.instantiate()
    get_root().add_child(root)
    current_scene = root
    for i in range(120):
        await physics_frame
    var world := root.get_node_or_null("TheLivingValley")
    var hero := root.get_node_or_null("Farmer") as CharacterBody3D
    _check(world != null, "Ordinary launch has no TheLivingValley")
    _check(hero != null, "Ordinary launch has no physics-driven Farmer")
    var space := root.get_world_3d().direct_space_state
    var terrain_mask := 0x7fffffff
    # Known existing house footprint: x=-23, z=-14, width=7, depth=5.2.
    # A horizontal ray through the wall must collide before crossing the house.
    var wall_query := PhysicsRayQueryParameters3D.create(Vector3(-29, 1.5, -14), Vector3(-17, 1.5, -14), terrain_mask)
    if hero != null:
        wall_query.exclude = [hero.get_rid()]
    var wall_hit := space.intersect_ray(wall_query)
    _check(not wall_hit.is_empty(), "Farmhouse wall is intangible: ray passes through occupied building footprint")
    if not wall_hit.is_empty():
        _check(float(wall_hit.position.x) < -25.0, "House wall collision occurs too far inside building")
    # Current valley must have walkable ground at the interior and safe outer-bound behavior.
    for sample in [Vector3(0, 4, 0), Vector3(60, 4, 60), Vector3(73, 4, 0)]:
        var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(sample, sample + Vector3.DOWN * 12.0, terrain_mask))
        _check(not floor_hit.is_empty(), "No ground or safe boundary collider at x=%.1f z=%.1f" % [sample.x, sample.z])
    # A point beyond the original 145-unit valley must be backed by streamed terrain
    # or an intentional physical boundary; silent empty space is not acceptable.
    var edge_start := Vector3(80, 3, 0)
    var edge_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(edge_start, edge_start + Vector3.DOWN * 12.0, terrain_mask))
    _check(not edge_hit.is_empty(), "World ends in an unprotected void beyond original 145-unit valley")
    root.queue_free()
    await process_frame
    if failures.is_empty():
        print("PRINCIPAL PHYSICAL ROUTE GATE PASS (ray probes only; avatar traversal, streaming and save tests still required)")
        quit(0)
    else:
        print("PRINCIPAL PHYSICAL ROUTE GATE FAIL: %d blockers" % failures.size())
        for failure in failures:
            print(" - " + failure)
        quit(1)
