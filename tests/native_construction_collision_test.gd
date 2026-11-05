extends SceneTree
## Run: godot --headless --path . --script res://tests/native_construction_collision_test.gd
## Checks actual generated farmhouse wall/floor physics and deliberate doorway.
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _ray(world: World3D, start: Vector3, end: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(start, end)
    query.collision_mask = 1
    return world.direct_space_state.intersect_ray(query)

func _expect_hit(world: World3D, start: Vector3, end: Vector3, label: String) -> void:
    if _ray(world, start, end).is_empty():
        failures.append("Missing collision: " + label)

func _expect_clear(world: World3D, start: Vector3, end: Vector3, label: String) -> void:
    if not _ray(world, start, end).is_empty():
        failures.append("Unexpected collision: " + label)

func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var valley := Node3D.new()
    valley.set_script(load("res://scripts/valley.gd"))
    root.add_child(valley)
    valley.setup(null)
    await physics_frame
    await physics_frame
    var world := root.get_world_3d()
    # Farmhouse center (-23,0,-14), width 7, depth 5.2.
    _expect_hit(world, Vector3(-23, 1.3, -19), Vector3(-23, 1.3, -14), "rear wall")
    _expect_hit(world, Vector3(-29, 1.3, -14), Vector3(-23, 1.3, -14), "left wall")
    _expect_hit(world, Vector3(-17, 1.3, -14), Vector3(-23, 1.3, -14), "right wall")
    _expect_hit(world, Vector3(-26, 1.3, -9), Vector3(-26, 1.3, -14), "front wall")
    _expect_clear(world, Vector3(-23, 1.3, -9), Vector3(-23, 1.3, -14), "doorway")
    _expect_hit(world, Vector3(-23, 4, -14), Vector3(-23, -2, -14), "interior floor")
    _expect_hit(world, Vector3(-23, 5, -14), Vector3(-23, 3.8, -14), "roof")
    if failures.is_empty():
        print("PASS: 7 construction collision/doorway ray tests")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
