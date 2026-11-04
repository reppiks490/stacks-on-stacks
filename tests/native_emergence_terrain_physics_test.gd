extends SceneTree
## Native, read-only regression for the 4.8 km streamed terrain geometry.
## Run: godot --headless --path . --script res://tests/native_emergence_terrain_physics_test.gd
## Does not touch user:// saves or trigger any workflow.
const World = preload("res://scripts/continental_world.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("FAIL: " + message)
    else:
        print("PASS: " + message)

func _run() -> void:
    var world: Node3D = World.new()
    root.add_child(world)
    _check(is_equal_approx(world.CONTINENT_SIDE, 4800.0), "world extent is 4800m")
    _check(world.GRID_WIDTH == 32 and is_equal_approx(world.CHUNK_SIDE, 150.0), "32 x 32 cells of 150m")
    _check(world.STREAM_RADIUS == 1, "streaming radius remains 3 x 3")
    _check(world._cell_of(Vector2(-2399.0, -2399.0)) == Vector2i(0, 0), "southwest cell mapping")
    _check(world._cell_of(Vector2(2399.0, 2399.0)) == Vector2i(31, 31), "northeast cell mapping")
    var samples: Array[Vector2] = [
        Vector2(-2250.0, -2100.0), Vector2(-150.0, 0.0),
        Vector2(0.0, 150.0), Vector2(450.0, -600.0),
        Vector2(2250.0, 2250.0)
    ]
    for p in samples:
        var a: float = world._terrain_height(p.x, p.y)
        var b: float = world._terrain_height(p.x, p.y)
        _check(is_finite(a) and absf(a-b) < 0.00001, "finite deterministic seam height " + str(p))
    var origin := Vector3(75.0, 0.0, 75.0)
    var mesh: ArrayMesh = world._terrain_mesh(origin)
    _check(mesh != null and mesh.get_surface_count() > 0, "terrain mesh emitted")
    var body := StaticBody3D.new()
    body.collision_layer = 1
    var shape := CollisionShape3D.new()
    shape.shape = mesh.create_trimesh_shape()
    body.add_child(shape)
    body.position = origin
    world.add_child(body)
    await physics_frame
    await physics_frame
    var state: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
    for local in [Vector2(-50.0, -50.0), Vector2(0.0, 0.0), Vector2(50.0, 50.0)]:
        var wx: float = origin.x + local.x
        var wz: float = origin.z + local.y
        var h: float = world._terrain_height(wx, wz)
        var query := PhysicsRayQueryParameters3D.create(Vector3(wx, h+50.0, wz), Vector3(wx, h-50.0, wz))
        query.collision_mask = 1
        var hit: Dictionary = state.intersect_ray(query)
        _check(not hit.is_empty(), "terrain physics floor at " + str(Vector2(wx, wz)))
        if not hit.is_empty():
            _check(absf(hit.position.y-h) < 2.0, "floor contact agrees with height at " + str(Vector2(wx, wz)))
    body.queue_free()
    world.queue_free()
    print("Emergence native terrain physics failures: ", failures)
    quit(0 if failures == 0 else 1)
