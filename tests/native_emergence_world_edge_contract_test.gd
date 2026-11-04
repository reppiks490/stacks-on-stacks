extends SceneTree
## Emergence regression: exact shared-edge heights and safe outer-cell coordinates.
## Run: godot --headless --path . --script res://tests/native_emergence_world_edge_contract_test.gd
const WORLD = preload("res://scripts/continental_world.gd")
const HALF := 2400.0
const SIDE := 150.0
const CELLS := 32
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures.append(label)
        push_error(label)

func _run() -> void:
    var world = WORLD.new()
    root.add_child(world)
    check(is_equal_approx(world.CONTINENT_SIDE, 4800.0), "world extent changed")
    check(is_equal_approx(world.CHUNK_SIDE, SIDE), "chunk extent changed")
    check(world.GRID_WIDTH == CELLS, "chunk grid changed")
    check(world.STREAM_RADIUS == 1, "3x3 streaming contract changed")
    for index in range(1, CELLS):
        var edge := -HALF + float(index) * SIDE
        for sample in [0.0, 0.25, 0.5, 0.75, 1.0]:
            var other := -HALF + 12.0 * SIDE + float(sample) * SIDE
            var a: float = world._terrain_height(edge, other)
            var b: float = world._terrain_height(edge, other)
            check(is_finite(a) and absf(a - b) < 0.00001, "X seam discontinuity %d/%f" % [index, sample])
            a = world._terrain_height(other, edge)
            b = world._terrain_height(other, edge)
            check(is_finite(a) and absf(a - b) < 0.00001, "Z seam discontinuity %d/%f" % [index, sample])
    for index in range(CELLS):
        var center := -HALF + (float(index) + 0.5) * SIDE
        check(world._cell_of(Vector2(center, 0.0)).x == index, "X chunk address %d" % index)
        check(world._cell_of(Vector2(0.0, center)).y == index, "Z chunk address %d" % index)
    check(world._cell_of(Vector2(-HALF, -HALF)) == Vector2i(0, 0), "negative corner")
    check(world._cell_of(Vector2(HALF, HALF)) == Vector2i(31, 31), "positive corner")
    check(world._cell_of(Vector2(HALF + 500, -HALF - 500)) == Vector2i(31, 0), "out-of-bounds clamp")
    # Inspect actual generated boundary collision, not just mathematical address clamping.
    var edge_chunk := Node3D.new()
    root.add_child(edge_chunk)
    world._install_outer_boundary(edge_chunk, Vector2i(0, 0))
    var bodies := 0
    for child in edge_chunk.get_children():
        if child is StaticBody3D and child.name == "PhysicalWorldBoundary":
            bodies += 1
            check(child.collision_layer & 1 != 0, "boundary collision layer")
            check(child.get_child_count() == 1 and child.get_child(0) is CollisionShape3D, "boundary collision shape")
            if child.get_child_count() == 1 and child.get_child(0) is CollisionShape3D:
                check(child.get_child(0).shape is BoxShape3D, "boundary must have box shape")
    check(bodies == 2, "corner requires two physical boundaries")
    var interior := Node3D.new()
    root.add_child(interior)
    world._install_outer_boundary(interior, Vector2i(16, 16))
    check(interior.get_child_count() == 0, "interior seam must not be blocked")
    print("EMERGENCE WORLD EDGE CONTRACT: %d checks, %d failures" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
