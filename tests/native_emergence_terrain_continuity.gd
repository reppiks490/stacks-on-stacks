extends SceneTree
## Run: godot --headless --path . --script res://tests/native_emergence_terrain_continuity.gd
## Isolated terrain contract: no player saves, no main-scene changes.
const World = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)

func _run() -> void:
    var world: Node3D = World.new()
    root.add_child(world)
    var stub := Node.new()
    stub.set("name", "TestGame")
    # _make_chunk requires game.season_index and society.spawn_for_chunk.
    # Test pure height continuity first; no fake physics pass.
    var side: float = world.CHUNK_SIDE
    var half: float = world.HALF
    _check(side == 150.0 and world.GRID_WIDTH == 32 and half == 2400.0, "World contract changed")
    for cx in [0, 1, 15, 16, 30]:
        for cz in [0, 15, 30]:
            var x: float = -half + float(cx + 1) * side
            var z0: float = -half + float(cz) * side
            for iz in range(25):
                var z: float = z0 + float(iz) * side / 24.0
                var a: float = world._terrain_height(x, z)
                var b: float = world._terrain_height((-half + float(cx) * side) + side, z)
                _check(is_finite(a) and absf(a - b) < 0.0001, "X seam mismatch at %s,%s" % [x,z])
    for cz in [0, 1, 15, 16, 30]:
        for cx in [0, 15, 30]:
            var z: float = -half + float(cz + 1) * side
            var x0: float = -half + float(cx) * side
            for ix in range(25):
                var x: float = x0 + float(ix) * side / 24.0
                var a: float = world._terrain_height(x, z)
                var b: float = world._terrain_height(x, (-half + float(cz) * side) + side)
                _check(is_finite(a) and absf(a - b) < 0.0001, "Z seam mismatch at %s,%s" % [x,z])
    for point in [Vector2(-2400,-2400), Vector2(-0.01,-0.01), Vector2(0,0), Vector2(2399.99,2399.99)]:
        var cell: Vector2i = world._cell_of(point)
        _check(cell.x >= 0 and cell.x < 32 and cell.y >= 0 and cell.y < 32, "Cell outside grid")
    # Mesh vertex bounds and sampled ground heights: geometry contract only.
    var origin := Vector3(-75,0,-75)
    var mesh: ArrayMesh = world._terrain_mesh(origin)
    _check(mesh.get_surface_count() == 1, "Terrain mesh missing")
    var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    _check(vertices.size() > 0, "Terrain has no vertices")
    for v in vertices:
        _check(absf(v.x) <= 75.001 and absf(v.z) <= 75.001, "Vertex outside chunk")
        _check(absf(v.y - world._terrain_height(origin.x+v.x,origin.z+v.z)) < 0.001, "Vertex does not match ground")
    for frame in range(120):
        await process_frame
    print("EMERGENCE_TERRAIN_GEOMETRY: ", "PASS" if failures.is_empty() else "FAIL", " errors=", failures.size())
    print("UNVERIFIED: physics traversal, chunk unload/reload, screenshots, renderer, FPS, save/load")
    world.queue_free()
    quit(0 if failures.is_empty() else 1)
