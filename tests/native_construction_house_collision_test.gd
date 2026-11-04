extends SceneTree
# Native Godot regression for ordinary launch-scene house collision.
# Run: godot --headless --path . --script res://tests/native_construction_house_collision_test.gd
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures.append(label)
        push_error(label)

func _ray(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
    return space.intersect_ray(query)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    _check(scene != null, "main scene must import")
    if scene == null:
        quit(1)
        return
    var game := scene.instantiate()
    root.add_child(game)
    for frame in range(120):
        await physics_frame
    var space := game.get_world_3d().direct_space_state
    var center := Vector3(-23, 0, -14)
    # Exterior front wall must block at shoulder height.
    _check(not _ray(space, center + Vector3(-2.3, 1.5, 4.0), center + Vector3(-2.3, 1.5, 1.0)).is_empty(), "front wall blocks")
    # The center doorway must remain open below the lintel.
    _check(_ray(space, center + Vector3(0, 1.4, 4.0), center + Vector3(0, 1.4, 1.0)).is_empty(), "doorway clear")
    # A ray inside the house must hit the side wall.
    _check(not _ray(space, center + Vector3(0, 1.5, 0), center + Vector3(5, 1.5, 0)).is_empty(), "side wall blocks")
    # The floor must have collision at the same height as its visible mesh.
    _check(not _ray(space, center + Vector3(0, 2, 0), center + Vector3(0, -2, 0)).is_empty(), "floor supports player")
    game.queue_free()
    if failures.is_empty():
        print("CONSTRUCTION HOUSE COLLISION PASS: 120 frames, walls/door/floor")
        quit(0)
    else:
        print("CONSTRUCTION HOUSE COLLISION FAIL: ", failures)
        quit(1)
