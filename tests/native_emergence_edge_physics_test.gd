extends SceneTree
## Native regression for the shipped continental terrain generator.
## Run: godot --headless --path . --script res://tests/native_emergence_edge_physics_test.gd
const World = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)

func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var world := World.new()
    root.add_child(world)
    _check(world.GRID_WIDTH == 32 and is_equal_approx(world.CHUNK_SIDE, 150.0), "World grid contract changed")
    _check(is_equal_approx(world.CONTINENT_SIDE, 4800.0), "World size changed")
    var left_key := Vector2i(16, 16)
    var right_key := Vector2i(17, 16)
    var left_origin := Vector3(-world.HALF + (left_key.x + 0.5) * world.CHUNK_SIDE, 0, -world.HALF + (left_key.y + 0.5) * world.CHUNK_SIDE)
    var right_origin := left_origin + Vector3(world.CHUNK_SIDE, 0, 0)
    var left_mesh: ArrayMesh = world._terrain_mesh(left_origin)
    var right_mesh: ArrayMesh = world._terrain_mesh(right_origin)
    _check(left_mesh.get_surface_count() > 0 and right_mesh.get_surface_count() > 0, "Terrain mesh missing")
    var left_vertices: PackedVector3Array = left_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var right_vertices: PackedVector3Array = right_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    for step in range(25):
        var z := -75.0 + step * 6.25
        var h_left := world._terrain_height(left_origin.x + 75.0, left_origin.z + z)
        var h_right := world._terrain_height(right_origin.x - 75.0, right_origin.z + z)
        _check(absf(h_left - h_right) < 0.0001, "Height seam at sample %d" % step)
        var found_left := false
        var found_right := false
        for vertex in left_vertices:
            if absf(vertex.x - 75.0) < 0.0001 and absf(vertex.z - z) < 0.0001 and absf(vertex.y - h_left) < 0.0001:
                found_left = true
                break
        for vertex in right_vertices:
            if absf(vertex.x + 75.0) < 0.0001 and absf(vertex.z - z) < 0.0001 and absf(vertex.y - h_right) < 0.0001:
                found_right = true
                break
        _check(found_left and found_right, "Actual mesh vertices disagree at seam sample %d" % step)
    for i in range(2):
        var mesh := left_mesh if i == 0 else right_mesh
        var origin := left_origin if i == 0 else right_origin
        var body := StaticBody3D.new()
        body.position = origin
        root.add_child(body)
        var shape := CollisionShape3D.new()
        shape.shape = mesh.create_trimesh_shape()
        body.add_child(shape)
    world._install_outer_boundary(root, Vector2i(0, 0))
    _check(root.get_node_or_null("PhysicalWorldBoundary") != null, "Outer boundary collision missing")
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    for offset in [-0.1, 0.0, 0.1]:
        var x := left_origin.x + 75.0 + offset
        var z := left_origin.z + 5.0
        var query := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -80, z))
        var hit := space.intersect_ray(query)
        _check(not hit.is_empty(), "No physics floor at seam offset %s" % str(offset))
        if not hit.is_empty():
            _check(absf(float(hit.position.y) - world._terrain_height(x,z)) < 1.0, "Floor physics height differs from terrain")
    root.queue_free()
    if failures.is_empty():
        print("PASS: 32x32 terrain, 25 shared-edge vertex samples, physics raycasts and outer boundary")
        quit(0)
    else:
        print("FAIL: %d terrain/physics assertions" % failures.size())
        quit(1)
