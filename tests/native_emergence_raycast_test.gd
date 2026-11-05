extends SceneTree
# Independent emergence regression: actual raycasts against loaded terrain and boundary.
# Run with: godot --headless --path . --script res://tests/native_emergence_raycast_test.gd
const World = preload("res://scripts/continental_world.gd")
var failed := false

func _initialize() -> void:
    call_deferred("_run")

func _assert(condition: bool, label: String) -> void:
    if not condition:
        failed = true
        push_error("FAIL " + label)

func _run() -> void:
    var world: Node3D = World.new()
    root.add_child(world)
    world._make_materials()
    # This deliberately avoids _make_chunk(), whose society/game hooks need the full scene.
    var origin := Vector3(75.0, 0.0, 75.0)
    var mesh := world._terrain_mesh(origin)
    var body := StaticBody3D.new()
    body.position = origin
    body.collision_layer = 1
    world.add_child(body)
    var collider := CollisionShape3D.new()
    collider.shape = mesh.create_trimesh_shape()
    body.add_child(collider)
    var edge := Node3D.new()
    edge.position = Vector3(-2325.0, 0.0, -2325.0)
    world.add_child(edge)
    world._install_outer_boundary(edge, Vector2i(0, 0))
    for i in range(3):
        await physics_frame
    var space := root.world_3d.direct_space_state
    for local in [Vector2(-60, -60), Vector2(0, 0), Vector2(60, 60)]:
        var x: float = origin.x + local.x
        var z: float = origin.z + local.y
        var expected: float = world._terrain_height(x, z)
        var ray := PhysicsRayQueryParameters3D.create(Vector3(x, expected + 50.0, z), Vector3(x, expected - 50.0, z))
        ray.collision_mask = 1
        var hit := space.intersect_ray(ray)
        _assert(not hit.is_empty(), "terrain ground ray at %s" % local)
        if not hit.is_empty():
            _assert(absf(hit.position.y - expected) < 0.35, "ground contact at %s" % local)
    var boundary_ray := PhysicsRayQueryParameters3D.create(Vector3(-2390, 2, -2325), Vector3(-2410, 2, -2325))
    boundary_ray.collision_mask = 1
    var boundary_hit := space.intersect_ray(boundary_ray)
    _assert(not boundary_hit.is_empty(), "outer world wall ray")
    for frame in range(120):
        await physics_frame
    print("EMERGENCE_RAYCAST_RESULT=", "FAIL" if failed else "PASS")
    quit(1 if failed else 0)
