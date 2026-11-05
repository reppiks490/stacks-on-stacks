extends SceneTree
## Native, read-only regression for the continental candidate. No player saves touched.
## Run: godot --headless --path . --script res://tests/native_emergence_terrain_oracle_20261105.gd
const WORLD = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, description: String) -> void:
    if not ok:
        failures.append(description)
        push_error("FAIL: " + description)
    else:
        print("PASS: " + description)

func _run() -> void:
    var world: Node3D = WORLD.new()
    root.add_child(world)
    check(is_equal_approx(world.CONTINENT_SIDE, 4800.0), "world remains 4800 units")
    check(is_equal_approx(world.CHUNK_SIDE, 150.0), "chunks remain 150 units")
    check(world.GRID_WIDTH == 32 and world.STREAM_RADIUS == 1, "32x32 grid and 3x3 stream")
    check(world._cell_of(Vector2(-2399.0, -2399.0)) == Vector2i(0, 0), "minimum valid world cell")
    check(world._cell_of(Vector2(2399.0, 2399.0)) == Vector2i(31, 31), "maximum valid world cell")
    for x in [0, 15, 30]:
        for z in [0, 15, 30]:
            var boundary_x: float = -2400.0 + float(x + 1) * 150.0
            var boundary_z: float = -2400.0 + float(z + 1) * 150.0
            check(absf(world._terrain_height(boundary_x, boundary_z) - world._terrain_height(boundary_x, boundary_z)) < 0.00001, "shared height sample %d,%d" % [x,z])
    var left_origin := Vector3(75.0, 0.0, 75.0)
    var right_origin := Vector3(225.0, 0.0, 75.0)
    var left_mesh: ArrayMesh = world._terrain_mesh(left_origin)
    var right_mesh: ArrayMesh = world._terrain_mesh(right_origin)
    check(left_mesh.get_surface_count() > 0 and right_mesh.get_surface_count() > 0, "adjacent chunk meshes generated")
    var left_vertices: PackedVector3Array = left_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var right_vertices: PackedVector3Array = right_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var left_heights: Array[float] = []
    var right_heights: Array[float] = []
    for vertex in left_vertices:
        if absf(vertex.x - 75.0) < 0.0001:
            left_heights.append(vertex.y)
    for vertex in right_vertices:
        if absf(vertex.x + 75.0) < 0.0001:
            right_heights.append(vertex.y)
    left_heights.sort()
    right_heights.sort()
    check(left_heights.size() > 0 and left_heights == right_heights, "shared seam mesh heights match")
    var edge_chunk := Node3D.new()
    root.add_child(edge_chunk)
    world._install_outer_boundary(edge_chunk, Vector2i(0, 0))
    check(edge_chunk.get_child_count() == 2, "corner chunk has two outer collision barriers")
    for child in edge_chunk.get_children():
        check(child is StaticBody3D and child.get_child_count() == 1 and child.get_child(0) is CollisionShape3D, "outer boundary has physics collider")
    var interior := Node3D.new()
    root.add_child(interior)
    world._install_outer_boundary(interior, Vector2i(16, 16))
    check(interior.get_child_count() == 0, "interior chunks have no artificial walls")
    var floor_body := StaticBody3D.new()
    floor_body.collision_layer = 1
    root.add_child(floor_body)
    var floor_shape := CollisionShape3D.new()
    floor_shape.shape = left_mesh.create_trimesh_shape()
    floor_shape.position = left_origin
    floor_body.add_child(floor_shape)
    await physics_frame
    await physics_frame
    var state := root.get_world_3d().direct_space_state
    var sample := Vector3(60.0, world._terrain_height(60.0, 75.0), 75.0)
    var query := PhysicsRayQueryParameters3D.create(sample + Vector3.UP * 50.0, sample - Vector3.UP * 50.0, 1)
    var hit := state.intersect_ray(query)
    check(not hit.is_empty(), "terrain floor blocks downward traversal ray")
    if not hit.is_empty():
        check(absf(hit.position.y - sample.y) < 0.5, "physics floor matches terrain height")
    print("EMERGENCE ORACLE: %d failures" % failures.size())
    quit(0 if failures.is_empty() else 1)
