extends SceneTree
## Native headless terrain contract regression; no player saves or world setup mutated.
const World = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []
var assertions := 0

func check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures.append(message)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var world = World.new()
    root.add_child(world)
    check(world._cell_of(Vector2(-2399.0, -2399.0)) == Vector2i(0, 0), "southwest cell")
    check(world._cell_of(Vector2(2399.0, 2399.0)) == Vector2i(31, 31), "northeast cell")
    check(world._cell_of(Vector2(0.0, 0.0)) == Vector2i(16, 16), "origin cell")
    for edge_x in [-2250.0, -150.0, 0.0, 150.0, 2250.0]:
        for z in [-2390.0, -750.0, 0.0, 750.0, 2390.0]:
            var h = world._terrain_height(edge_x, z)
            check(is_finite(h), "nonfinite terrain height %s %s" % [edge_x, z])
            check(absf(world._terrain_height(edge_x, z) - world._terrain_height(edge_x, z)) < 0.00001, "nondeterministic seam height")
    var mesh: ArrayMesh = world._terrain_mesh(Vector3(-225.0, 0.0, 75.0))
    check(mesh.get_surface_count() == 1, "terrain surface absent")
    var trimesh = mesh.create_trimesh_shape()
    check(trimesh != null, "terrain physics trimesh absent")
    for key in [Vector2i(0,0), Vector2i(31,31), Vector2i(15,15)]:
        var chunk := Node3D.new()
        world.add_child(chunk)
        world._install_outer_boundary(chunk, key)
        var expected := 2 if key != Vector2i(15,15) else 0
        check(chunk.get_child_count() == expected, "incorrect outer boundary count for %s" % key)
        for body in chunk.get_children():
            check(body is StaticBody3D, "boundary lacks StaticBody3D")
            check(body.get_child_count() == 1 and body.get_child(0) is CollisionShape3D, "boundary lacks collision")
    print("EVERBLOOM_TERRAIN_NATIVE assertions=%d failures=%d" % [assertions, failures.size()])
    for failure in failures:
        push_error(failure)
    quit(1 if failures.size() > 0 else 0)
