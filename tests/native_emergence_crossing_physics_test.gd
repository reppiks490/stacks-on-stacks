extends SceneTree
## Real Godot physics regression for streamed terrain crossings and outer bounds.
## Run without Codex/workflows:
## godot --headless --path . --script res://tests/native_emergence_crossing_physics_test.gd
const WorldScript = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, description: String) -> void:
    if not condition:
        failures.append(description)
        push_error(description)

func install_floor(world: Node3D, key: Vector2i) -> void:
    var origin := Vector3(-world.HALF + (float(key.x) + 0.5) * world.CHUNK_SIDE, 0.0,
        -world.HALF + (float(key.y) + 0.5) * world.CHUNK_SIDE)
    var chunk := Node3D.new()
    chunk.position = origin
    chunk.name = "PhysicsChunk_%d_%d" % [key.x, key.y]
    world.add_child(chunk)
    var mesh: ArrayMesh = world._terrain_mesh(origin)
    var ground := MeshInstance3D.new()
    ground.mesh = mesh
    chunk.add_child(ground)
    var body := StaticBody3D.new()
    body.collision_layer = 1
    chunk.add_child(body)
    var shape := CollisionShape3D.new()
    shape.shape = mesh.create_trimesh_shape()
    body.add_child(shape)
    world._install_outer_boundary(chunk, key)

func ray_floor(world: Node3D, x: float, z: float, label: String) -> void:
    var expected: float = world._terrain_height(x, z)
    var query := PhysicsRayQueryParameters3D.create(
        Vector3(x, expected + 35.0, z), Vector3(x, expected - 35.0, z))
    query.collision_mask = 1
    var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
    check(not hit.is_empty(), "missing physical terrain: " + label)
    if not hit.is_empty():
        check(absf(hit.position.y - expected) < 0.7,
            "terrain collider mismatch: " + label + " hit=" + str(hit.position.y))

func _run() -> void:
    var world: Node3D = WorldScript.new()
    root.add_child(world)
    check(world.GRID_WIDTH == 32 and is_equal_approx(world.CHUNK_SIDE, 150.0),
        "32x32 / 150m world contract changed")
    # Exercise actual triangles and StaticBody collision on either side of a
    # chunk boundary. Also check a nonflat boundary away from the homestead.
    for key in [Vector2i(16, 16), Vector2i(17, 16), Vector2i(25, 20),
        Vector2i(26, 20), Vector2i(0, 0), Vector2i(31, 31)]:
        install_floor(world, key)
    await physics_frame
    await physics_frame
    for x in [149.5, 150.0, 150.5]:
        for z in [15.0, 30.0, 45.0]:
            ray_floor(world, x, z, "home crossing %.1f/%.1f" % [x, z])
    for x in [1499.5, 1500.0, 1500.5]:
        for z in [650.0, 670.0, 690.0]:
            ray_floor(world, x, z, "distant crossing %.1f/%.1f" % [x, z])
    for p in [Vector2(-2398.0, -2398.0), Vector2(2398.0, 2398.0)]:
        ray_floor(world, p.x, p.y, "outer terrain " + str(p))
    # Outer-edge barriers must block a horizontal ray at human height.
    var space := world.get_world_3d().direct_space_state
    for bounds in [
        [Vector3(-2395, 2, -2325), Vector3(-2405, 2, -2325)],
        [Vector3(2395, 2, 2325), Vector3(2405, 2, 2325)]
    ]:
        var q := PhysicsRayQueryParameters3D.create(bounds[0], bounds[1])
        q.collision_mask = 1
        var hit := space.intersect_ray(q)
        check(not hit.is_empty(), "outer boundary collider missing at " + str(bounds[0]))
        if not hit.is_empty():
            check(hit.collider.name == "PhysicalWorldBoundary",
                "outer boundary ray hit unexpected collider " + str(hit.collider.name))
    world.queue_free()
    if failures.is_empty():
        print("PASS: cross-chunk physics floors, distant seams and outer boundary rays")
        quit(0)
    else:
        print("FAIL: emergence crossing physics: ", failures)
        quit(1)
