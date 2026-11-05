extends SceneTree
# Native physics regression for outer-world containment and chunk ground.
# Run: godot --headless --path . --script res://tests/native_emergence_boundary_physics_test.gd
const World = preload("res://scripts/continental_world.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if condition:
        print("PASS: ", label)
    else:
        failures += 1
        push_error("FAIL: " + label)

func _run() -> void:
    var world = World.new()
    root.add_child(world)
    var chunk := Node3D.new()
    world.add_child(chunk)
    world._install_outer_boundary(chunk, Vector2i(0, 0))
    var bodies: Array[StaticBody3D] = []
    for child in chunk.get_children():
        if child is StaticBody3D:
            bodies.append(child)
    _check(bodies.size() == 2, "southwest corner has exactly two perimeter walls")
    for body in bodies:
        _check(body.collision_layer & 1 != 0, "perimeter collision layer includes player layer")
        var shape := body.get_child(0) as CollisionShape3D
        _check(shape != null and shape.shape is BoxShape3D, "perimeter has physical box collider")
    var inner := Node3D.new()
    world.add_child(inner)
    world._install_outer_boundary(inner, Vector2i(15, 15))
    _check(inner.get_child_count() == 0, "interior chunks have no blocking perimeter")
    var ground_mesh: ArrayMesh = world._terrain_mesh(Vector3(-2325.0, 0.0, -2325.0))
    var ground := StaticBody3D.new()
    chunk.add_child(ground)
    var ground_shape := CollisionShape3D.new()
    ground_shape.shape = ground_mesh.create_trimesh_shape()
    ground.add_child(ground_shape)
    # The test chunk is at the same world-space origin as the mesh samples.
    chunk.position = Vector3(-2325.0, 0.0, -2325.0)
    await physics_frame
    await physics_frame
    var state := world.get_world_3d().direct_space_state
    var center := chunk.global_position
    var floor_query := PhysicsRayQueryParameters3D.create(center + Vector3(0, 70, 0), center + Vector3(0, -70, 0))
    floor_query.collision_mask = 1
    var floor_hit := state.intersect_ray(floor_query)
    _check(not floor_hit.is_empty(), "terrain floor raycast has physical contact")
    var wall_query := PhysicsRayQueryParameters3D.create(center + Vector3(0, 4, 0), center + Vector3(-90, 4, 0))
    wall_query.collision_mask = 1
    var wall_hit := state.intersect_ray(wall_query)
    _check(not wall_hit.is_empty(), "west world boundary stops horizontal traversal")
    var south_query := PhysicsRayQueryParameters3D.create(center + Vector3(0, 4, 0), center + Vector3(0, 4, -90))
    south_query.collision_mask = 1
    var south_hit := state.intersect_ray(south_query)
    _check(not south_hit.is_empty(), "south world boundary stops horizontal traversal")
    print("EMERGENCE BOUNDARY PHYSICS: ", "PASS" if failures == 0 else "FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
