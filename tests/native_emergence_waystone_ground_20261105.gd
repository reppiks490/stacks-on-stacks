extends SceneTree
## Emergence waystone grounding contract. Native test; does not modify saves.
const World = preload("res://scripts/continental_world.gd")
var failed: Array[String] = []
var checked: int = 0

func verify(ok: bool, message: String) -> void:
    checked += 1
    if not ok:
        failed.append(message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world = World.new()
    root.add_child(world)
    for hub in World.HUBS:
        var x: float = float(hub["x"])
        var z: float = float(hub["z"]) + 6.0
        var cell: Vector2i = world._cell_of(Vector2(x, z))
        var h: float = world._terrain_height(x, z)
        verify(is_finite(h), "invalid waystone height: %s" % hub["name"])
        verify(cell.x >= 0 and cell.x < 32 and cell.y >= 0 and cell.y < 32,
            "waystone outside chunk grid: %s" % hub["name"])
        verify(h + 1.05 > h, "waystone spawn below terrain: %s" % hub["name"])
    print("EVERBLOOM_WAYSTONE_GROUND assertions=%d failures=%d" % [checked, failed.size()])
    for failure in failed:
        push_error(failure)
    quit(1 if failed.size() else 0)
