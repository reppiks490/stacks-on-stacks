extends SceneTree
## Native regression for the existing continental terrain implementation.
## Run: godot --headless --path . --script res://tests/native_emergence_terrain_test.gd
## This is NOT a renderer, player-traversal, or FPS acceptance test.
const World = preload("res://scripts/continental_world.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + message)

func _run() -> void:
    var world = World.new()
    root.add_child(world)
    _check(world.GRID_WIDTH == 32, "32 cells per axis")
    _check(is_equal_approx(world.CHUNK_SIDE * world.GRID_WIDTH, world.CONTINENT_SIDE), "4800m world dimensions")
    _check(world.STREAM_RADIUS == 1, "3x3 streaming radius")
    _check(world._cell_of(Vector2(-2400.0, -2400.0)) == Vector2i(0, 0), "negative outer corner")
    _check(world._cell_of(Vector2(2399.9, 2399.9)) == Vector2i(31, 31), "positive outer corner")
    _check(world._cell_of(Vector2(-0.01, -0.01)) == Vector2i(15, 15), "negative origin side")
    _check(world._cell_of(Vector2(0.01, 0.01)) == Vector2i(16, 16), "positive origin side")
    for edge in [-2250.0, -150.0, 0.0, 150.0, 2250.0]:
        for cross in [-1800.0, -73.0, 0.0, 91.0, 1800.0]:
            var left = world._terrain_height(edge, cross)
            var right = world._terrain_height(edge, cross)
            _check(is_finite(left) and is_equal_approx(left, right), "finite shared X edge %s/%s" % [edge, cross])
            var north = world._terrain_height(cross, edge)
            var south = world._terrain_height(cross, edge)
            _check(is_finite(north) and is_equal_approx(north, south), "finite shared Z edge %s/%s" % [cross, edge])
    for cell in [Vector2i(0,0), Vector2i(15,15), Vector2i(16,16), Vector2i(31,31)]:
        var origin = Vector3(-world.HALF + (float(cell.x) + 0.5) * world.CHUNK_SIDE, 0.0,
            -world.HALF + (float(cell.y) + 0.5) * world.CHUNK_SIDE)
        var mesh = world._terrain_mesh(origin)
        _check(mesh != null and mesh.get_surface_count() > 0, "terrain mesh exists at " + str(cell))
        if mesh != null:
            var shape = mesh.create_trimesh_shape()
            _check(shape != null, "trimesh collision shape exists at " + str(cell))
    print("EMERGENCE TERRAIN TEST: %d checks; %d failures" % [checks, failures])
    world.queue_free()
    quit(0 if failures == 0 else 1)
