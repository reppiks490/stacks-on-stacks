extends SceneTree
# Native four-way streamed-terrain collision regression.
# Run: godot --headless --path . --script res://tests/native_emergence_fourway_seam_physics_test.gd
# This tests actual trimesh physics at a four-chunk junction, including a reload.
const World = preload("res://scripts/continental_world.gd")
const OFFSETS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if ok:
        print("PASS: ", message)
    else:
        failures += 1
        push_error("FAIL: " + message)

func _add_ground(world: Node3D, cell: Vector2i) -> StaticBody3D:
    var center := Vector3(float(cell.x) * 150.0 + 75.0, 0.0, float(cell.y) * 150.0 + 75.0)
    var body := StaticBody3D.new()
    body.name = "Terrain_%d_%d" % [cell.x, cell.y]
    body.collision_layer = 1
    body.collision_mask = 1
    body.position = center
    world.add_child(body)
    var shape := CollisionShape3D.new()
    shape.shape = world._terrain_mesh(center).create_trimesh_shape()
    body.add_child(shape)
    return body

func _ground_at(world: Node3D, x: float, z: float) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -80, z))
    query.collision_mask = 1
    return world.get_world_3d().direct_space_state.intersect_ray(query)

func _sample_junction(world: Node3D, label: String) -> void:
    var samples := [
        Vector2(-0.2, -0.2), Vector2(0.2, -0.2),
        Vector2(-0.2, 0.2), Vector2(0.2, 0.2)
    ]
    var heights: Array[float] = []
    for p in samples:
        var hit := _ground_at(world, p.x, p.y)
        _check(not hit.is_empty(), "%s: collision floor at (%s,%s)" % [label, p.x, p.y])
        if not hit.is_empty():
            heights.append(hit["position"].y)
            var expected: float = world._terrain_height(p.x, p.y)
            _check(absf(hit["position"].y - expected) < 0.25,
                "%s: physics height agrees with terrain at (%s,%s)" % [label, p.x, p.y])
    if heights.size() == 4:
        var minimum: float = heights.min()
        var maximum: float = heights.max()
        _check(maximum - minimum < 0.5, "%s: four-way collision junction has no height discontinuity" % label)

func _run() -> void:
    var world := World.new()
    root.add_child(world)
    var bodies: Dictionary = {}
    for cell in OFFSETS:
        bodies[cell] = _add_ground(world, cell)
    await physics_frame
    await physics_frame
    _sample_junction(world, "initial")
    var removed: StaticBody3D = bodies[Vector2i(0, 0)]
    removed.queue_free()
    await physics_frame
    var missing := _ground_at(world, 0.2, 0.2)
    _check(missing.is_empty(), "unloaded quadrant does not retain a ghost collider")
    bodies[Vector2i(0, 0)] = _add_ground(world, Vector2i(0, 0))
    await physics_frame
    await physics_frame
    _sample_junction(world, "reloaded")
    print("EMERGENCE FOUR-WAY PHYSICS: ", "PASS" if failures == 0 else "FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
