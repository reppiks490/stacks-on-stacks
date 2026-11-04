extends SceneTree
# Native headless regression for existing continental streamed terrain.
# Run: godot --headless --path . --script res://tests/native_emergence_terrain_continuity.gd
const World = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func _run() -> void:
    var world = World.new()
    root.add_child(world)
    # Do not call setup(): society/UI dependencies are unrelated to terrain physics.
    for cell in [Vector2i(0, 0), Vector2i(15, 15), Vector2i(16, 16), Vector2i(31, 31)]:
        var x = -2400.0 + float(cell.x + 1) * 150.0
        var z = -2400.0 + float(cell.y + 1) * 150.0
        for offset in [-50.0, 0.0, 50.0]:
            var left: float = world._terrain_height(x, z + offset)
            var right: float = world._terrain_height(x, z + offset)
            check(is_equal_approx(left, right), "X seam discontinuity %s" % cell)
            var top: float = world._terrain_height(x + offset, z)
            var bottom: float = world._terrain_height(x + offset, z)
            check(is_equal_approx(top, bottom), "Z seam discontinuity %s" % cell)
    var origin = Vector3(-75, 0, -75)
    var mesh: ArrayMesh = world._terrain_mesh(origin)
    check(mesh.get_surface_count() > 0, "terrain mesh empty")
    var shape = mesh.create_trimesh_shape()
    check(shape != null, "terrain physics trimesh missing")
    var terrain = StaticBody3D.new()
    var collider = CollisionShape3D.new()
    collider.shape = shape
    terrain.add_child(collider)
    world.add_child(terrain)
    await physics_frame
    await physics_frame
    var space = world.get_world_3d().direct_space_state
    for point in [Vector2(-60, -60), Vector2(0, 0), Vector2(60, 60)]:
        var ray = PhysicsRayQueryParameters3D.create(Vector3(point.x, 50, point.y), Vector3(point.x, -50, point.y))
        ray.collision_mask = 1
        var hit = space.intersect_ray(ray)
        check(not hit.is_empty(), "fall-through floor at %s" % point)
    var edge = Node3D.new()
    world.add_child(edge)
    world._install_outer_boundary(edge, Vector2i(0, 0))
    var boundaries = edge.get_children().filter(func(node): return node is StaticBody3D)
    check(boundaries.size() == 2, "corner cell must have two physical boundaries")
    for boundary in boundaries:
        check(boundary.collision_layer & 1 != 0, "outer wall lacks player collision layer")
        check(boundary.get_child_count() > 0 and boundary.get_child(0) is CollisionShape3D, "outer wall lacks shape")
    print("EMERGENCE_TERRAIN_TEST ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
    quit(0 if failures.is_empty() else 1)
