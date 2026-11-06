extends SceneTree
## Emergence-owned native regression for the existing continental terrain branch.
## Run: godot --headless --path . --script res://tests/emergence_terrain_seam_physics_test.gd
## This does not certify the ordinary main-scene launch or visual quality.
const WorldScript = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func _run() -> void:
    var world: Node3D = WorldScript.new()
    root.add_child(world)
    # Adjacent interior chunks with a non-flat shared edge at world X=300.
    var keys := [Vector2i(17, 17), Vector2i(18, 17)]
    for key in keys:
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
    await physics_frame
    await physics_frame
    var space := world.get_world_3d().direct_space_state
    for i in range(13):
        var z: float = 225.0 + float(i) * 12.5
        var expected: float = world._terrain_height(300.0, z)
        for offset in [-0.2, 0.2]:
            var x: float = 300.0 + offset
            var query := PhysicsRayQueryParameters3D.create(
                Vector3(x, 80.0, z), Vector3(x, -80.0, z))
            query.collision_mask = 1
            var hit: Dictionary = space.intersect_ray(query)
            _check(not hit.is_empty(), "Missing terrain collider at x=%s z=%s" % [x, z])
            if not hit.is_empty():
                _check(absf(float(hit.position.y) - expected) < 0.6,
                    "Collider/height mismatch at x=%s z=%s: %s vs %s" %
                    [x, z, hit.position.y, expected])
        var left: float = world._terrain_height(300.0 - 0.0001, z)
        var right: float = world._terrain_height(300.0 + 0.0001, z)
        _check(absf(left - right) < 0.01, "Discontinuous height at seam z=%s" % z)
    # A ray outside the two loaded chunks must not silently hit a fake infinite floor.
    var miss := PhysicsRayQueryParameters3D.create(
        Vector3(700.0, 80.0, 300.0), Vector3(700.0, -80.0, 300.0))
    _check(space.intersect_ray(miss).is_empty(), "Unexpected physics outside loaded chunks")
    print("EMERGENCE_TERRAIN_SEAM_PHYSICS checks=40+ failures=", failures.size())
    world.queue_free()
    quit(0 if failures.is_empty() else 1)
