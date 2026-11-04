extends SceneTree
## Emergence-owned native regression: terrain seam vertices, physics floor and outer grid mapping.
## Run: godot --headless --path . --script res://tests/native_emergence_boundary_physics_test.gd
const WorldScript = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)

func _run() -> void:
    var world: Node3D = WorldScript.new()
    root.add_child(world)
    _check(world.GRID_WIDTH == 32 and is_equal_approx(world.CHUNK_SIDE, 150.0), "continental grid dimensions changed")
    _check(world._cell_of(Vector2(-2400.0, -2400.0)) == Vector2i(0, 0), "minimum world corner misindexed")
    _check(world._cell_of(Vector2(2399.0, 2399.0)) == Vector2i(31, 31), "maximum world corner misindexed")
    var origins := [Vector3(-75, 0, -75), Vector3(75, 0, -75), Vector3(-75, 0, 75)]
    var meshes: Array[ArrayMesh] = []
    for origin in origins:
        var mesh: ArrayMesh = world._terrain_mesh(origin)
        meshes.append(mesh)
        _check(mesh.get_surface_count() == 1, "terrain mesh has no surface")
        var body := StaticBody3D.new()
        body.position = origin
        world.add_child(body)
        var collider := CollisionShape3D.new()
        collider.shape = mesh.create_trimesh_shape()
        body.add_child(collider)
    var left: PackedVector3Array = meshes[0].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var right: PackedVector3Array = meshes[1].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var seam_left: Array[float] = []
    var seam_right: Array[float] = []
    for vertex in left:
        if absf(vertex.x - 75.0) < 0.0001:
            seam_left.append(vertex.y)
    for vertex in right:
        if absf(vertex.x + 75.0) < 0.0001:
            seam_right.append(vertex.y)
    seam_left.sort()
    seam_right.sort()
    _check(seam_left.size() > 0 and seam_left == seam_right, "adjacent chunk seam heights disagree")
    await physics_frame
    await physics_frame
    var space := world.get_world_3d().direct_space_state
    for point in [Vector2(-75,-75), Vector2(0,-75), Vector2(75,-75), Vector2(-75,0)]:
        var expected: float = world._terrain_height(point.x, point.y)
        var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, expected+30, point.y), Vector3(point.x, expected-30, point.y))
        var hit := space.intersect_ray(query)
        _check(not hit.is_empty(), "missing physical floor at " + str(point))
        if not hit.is_empty():
            _check(absf(hit.position.y - expected) < 0.2, "floor/visual height mismatch at " + str(point))
    world.queue_free()
    if failures.is_empty():
        print("PASS native emergence terrain seam and physics floor")
        quit(0)
    else:
        print("FAIL native emergence terrain: ", failures)
        quit(1)
