extends SceneTree
# Independent adversarial geometry audit. Does not mutate gameplay or saves.
# godot --headless --path . --script res://tests/native_emergence_seam_geometry_test.gd
const World = preload("res://scripts/continental_world.gd")
var failures := 0

func verify(condition: bool, message: String) -> void:
    if condition:
        print("PASS ", message)
    else:
        failures += 1
        push_error("FAIL " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := World.new()
    root.add_child(world)
    verify(is_equal_approx(world.CHUNK_SIDE * world.GRID_WIDTH, world.CONTINENT_SIDE), "32 chunks cover exactly 4800 units")
    verify(world.STREAM_RADIUS == 1, "3x3 streaming radius preserved")
    for i in range(1, world.GRID_WIDTH):
        var seam := -world.HALF + float(i) * world.CHUNK_SIDE
        for z in [-2399.0, -1500.0, -1.0, 0.0, 1500.0, 2399.0]:
            var left := world._terrain_height(seam - 0.001, z)
            var right := world._terrain_height(seam + 0.001, z)
            verify(absf(left - right) < 0.05, "X seam %d at Z %.1f continuous" % [i, z])
            var bottom := world._terrain_height(z, seam - 0.001)
            var top := world._terrain_height(z, seam + 0.001)
            verify(absf(bottom - top) < 0.05, "Z seam %d at X %.1f continuous" % [i, z])
    for x in [-2399.0, -2250.0, -0.001, 0.001, 2250.0, 2399.0]:
        for z in [-2399.0, -0.001, 0.001, 2399.0]:
            var cell := world._cell_of(Vector2(x, z))
            verify(cell.x >= 0 and cell.x < 32 and cell.y >= 0 and cell.y < 32, "valid cell at %.3f,%.3f" % [x,z])
    print("EMERGENCE SEAM GEOMETRY: ", "PASS" if failures == 0 else "FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
