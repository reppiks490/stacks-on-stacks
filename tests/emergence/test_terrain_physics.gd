extends SceneTree
## Native physics oracle for continental terrain; run with:
## godot --headless --path . --script res://tests/emergence/test_terrain_physics.gd
## Isolated test: no saves, gameplay state, or production scene edits.

const WorldScript = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func _run() -> void:
    var world: Node3D = WorldScript.new()
    root.add_child(world)
    var center := Vector2i(16, 16)
    var neighbor := Vector2i(17, 16)
    var first_origin := Vector3(-2400.0 + (float(center.x) + 0.5) * 150.0, 0.0, -2400.0 + (float(center.y) + 0.5) * 150.0)
    var next_origin := first_origin + Vector3(150.0, 0.0, 0.0)
    var seam_x := first_origin.x + 75.0
    for offset in [-75.0, -25.0, 0.0, 25.0, 75.0]:
        var z: float = first_origin.z + offset
        var a: float = world._terrain_height(first_origin.x + 75.0, z)
        var b: float = world._terrain_height(next_origin.x - 75.0, z)
        _assert(absf(a - b) < 0.001, "Discontinuous height across adjacent chunk boundary")
    for origin in [first_origin, next_origin]:
        var terrain := StaticBody3D.new()
        terrain.position = origin
        terrain.collision_layer = 1
        var collider := CollisionShape3D.new()
        collider.shape = world._terrain_mesh(origin).create_trimesh_shape()
        terrain.add_child(collider)
        world.add_child(terrain)
    var edge_chunk := Node3D.new()
    edge_chunk.position = Vector3(-2325.0, 0.0, first_origin.z)
    world.add_child(edge_chunk)
    world._install_outer_boundary(edge_chunk, Vector2i(0, 16))
    await physics_frame
    await physics_frame
    var space := world.get_world_3d().direct_space_state
    for offset in [-60.0, 0.0, 60.0]:
        var z: float = first_origin.z + offset
        var query := PhysicsRayQueryParameters3D.create(Vector3(seam_x, 100.0, z), Vector3(seam_x, -100.0, z))
        query.collision_mask = 1
        var hit := space.intersect_ray(query)
        _assert(not hit.is_empty(), "Missing physical ground at streamed seam z=%s" % z)
        if not hit.is_empty():
            _assert(absf(float(hit.position.y) - world._terrain_height(seam_x, z)) < 0.15, "Terrain collider diverges from height at seam")
    var wall_query := PhysicsRayQueryParameters3D.create(Vector3(-2380.0, 2.0, first_origin.z), Vector3(-2410.0, 2.0, first_origin.z))
    wall_query.collision_mask = 1
    var wall_hit := space.intersect_ray(wall_query)
    _assert(not wall_hit.is_empty(), "Outer world edge has no physical barrier")
    if not wall_hit.is_empty():
        _assert(wall_hit.collider is StaticBody3D, "Outer world boundary hit is not a physics body")
    world.queue_free()
    await process_frame
    if failures.is_empty():
        print("PASS: continental terrain seam, ground raycasts, and outer barrier physics")
        quit(0)
    else:
        print("FAIL: %d continental terrain checks" % failures.size())
        quit(1)
