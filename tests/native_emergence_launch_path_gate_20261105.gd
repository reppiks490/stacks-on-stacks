extends SceneTree
## Emergence release gate: fail closed when the ordinary launch cannot reach
## the continental terrain. This is intentionally an integration test, not art.
const GameScript = preload("res://scripts/game.gd")
const ContinentalScript = preload("res://scripts/continental_world.gd")

func _initialize() -> void:
    var failures: Array[String] = []
    var project_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
    if project_scene != "res://scenes/main.tscn":
        failures.append("Unexpected launch scene: " + project_scene)
    var scene: PackedScene = load(project_scene)
    if scene == null:
        failures.append("Main scene cannot be loaded")
    else:
        var root: Node = scene.instantiate()
        if root == null:
            failures.append("Main scene cannot instantiate")
        else:
            var script: Script = root.get_script()
            if script == null:
                failures.append("Main scene root has no game script")
            elif script.resource_path != GameScript.resource_path:
                failures.append("Launch root does not use scripts/game.gd")
            root.free()
    var game_source: String = FileAccess.get_file_as_string("res://scripts/game.gd")
    if not game_source.contains("res://scripts/continental_world.gd"):
        failures.append("BLOCKER: ordinary game.gd launch never loads continental_world.gd; 4.8km terrain repairs cannot be seen by the player")
    var continent: Node3D = ContinentalScript.new()
    if continent.CONTINENT_SIDE != 4800.0 or continent.CHUNK_SIDE != 150.0 or continent.GRID_WIDTH != 32 or continent.STREAM_RADIUS != 1:
        failures.append("Continental stream geometry contract changed")
    for cell in [Vector2i(0,0), Vector2i(15,15), Vector2i(31,31)]:
        var center: Vector2 = Vector2(-2400.0 + (float(cell.x)+0.5)*150.0, -2400.0 + (float(cell.y)+0.5)*150.0)
        if continent._cell_of(center) != cell:
            failures.append("Cell mapping mismatch: " + str(cell))
    continent.free()
    if failures.is_empty():
        print("PASS: ordinary launch references continental streaming and chunk coordinate contract")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("FAIL: launch integration gate; ", failures.size(), " blocker(s)")
        quit(1)
