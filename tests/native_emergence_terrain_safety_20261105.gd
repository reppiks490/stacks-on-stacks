extends SceneTree
# Native headless regression: Godot --headless --path . --script res://tests/native_emergence_terrain_safety_20261105.gd
func _initialize() -> void:
    var world_script = load("res://scripts/continental_world.gd")
    assert(world_script != null, "continental world script must parse")
    var world = world_script.new()
    assert(world.CONTINENT_SIDE == 4800.0)
    assert(world.CHUNK_SIDE == 150.0)
    assert(world.GRID_WIDTH == 32)
    assert(world.STREAM_RADIUS == 1)
    for cx in [0, 1, 15, 16, 30]:
        for cz in [0, 15, 30]:
            var edge_x = -2400.0 + float(cx + 1) * 150.0
            var edge_z = -2400.0 + float(cz) * 150.0
            var left = world._terrain_height(edge_x, edge_z)
            var right = world._terrain_height(edge_x, edge_z)
            assert(is_equal_approx(left, right), "shared world edge height must agree")
    assert(world._cell_of(Vector2(-2400.0, -2400.0)) == Vector2i(0, 0))
    assert(world._cell_of(Vector2(2399.9, 2399.9)) == Vector2i(31, 31))
    assert(world._cell_of(Vector2(0, 0)) == Vector2i(16, 16))
    print("PASS emergence terrain grid, bounds and shared world-height sampling")
    world.free()
    quit(0)
