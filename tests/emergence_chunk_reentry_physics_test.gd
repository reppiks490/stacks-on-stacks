extends SceneTree
## Native negative regression: unloaded terrain must be absent, reloaded terrain solid.
## Run with the continental implementation branch checked out:
## godot --headless --path . --script res://tests/emergence_chunk_reentry_physics_test.gd
const WorldScript = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, description: String) -> void:
    if not value:
        failures.append(description)
        push_error(description)

func _install(world: Node3D, key: Vector2i) -> Node3D:
    var origin := Vector3(-2400.0 + (float(key.x) + 0.5) * 150.0, 0.0,
        -2400.0 + (float(key.y) + 0.5) * 150.0)
    var chunk := Node3D.new()
    chunk.position = origin
    world.add_child(chunk)
    var mesh: ArrayMesh = world._terrain_mesh(origin)
    var visible := MeshInstance3D.new()
    visible.mesh = mesh
    chunk.add_child(visible)
    var body := StaticBody3D.new()
    body.collision_layer = 1
    chunk.add_child(body)
    var collider := CollisionShape3D.new()
    collider.shape = mesh.create_trimesh_shape()
    body.add_child(collider)
    return chunk

func _probe(world: Node3D, x: float, z: float) -> Dictionary:
    var ray := PhysicsRayQueryParameters3D.create(
        Vector3(x, 90.0, z), Vector3(x, -90.0, z))
    ray.collision_mask = 1
    return world.get_world_3d().direct_space_state.intersect_ray(ray)

func _run() -> void:
    var world: Node3D = WorldScript.new()
    root.add_child(world)
    var left := _install(world, Vector2i(17, 17))
    var right := _install(world, Vector2i(18, 17))
    await physics_frame
    await physics_frame
    for x in [299.8, 300.2]:
        _check(not _probe(world, x, 250.0).is_empty(),
            "Initial floor missing at x=%s" % x)
    right.queue_free()
    await physics_frame
    await physics_frame
    _check(_probe(world, 300.2, 250.0).is_empty(),
        "Unloaded chunk retained a ghost floor")
    _check(not _probe(world, 299.8, 250.0).is_empty(),
        "Neighbor lost its floor during unload")
    right = _install(world, Vector2i(18, 17))
    await physics_frame
    await physics_frame
    for z in [230.0, 250.0, 280.0]:
        for x in [299.8, 300.2]:
            var hit := _probe(world, x, z)
            _check(not hit.is_empty(),
                "Reloaded seam has missing floor at x=%s z=%s" % [x, z])
            if not hit.is_empty():
                _check(absf(float(hit.position.y) - world._terrain_height(x, z)) < 0.7,
                    "Reloaded floor height mismatch at x=%s z=%s" % [x, z])
    print("EMERGENCE_CHUNK_REENTRY failures=", failures.size())
    left.queue_free()
    right.queue_free()
    world.queue_free()
    quit(0 if failures.is_empty() else 1)
