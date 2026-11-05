extends SceneTree
## Run: godot --headless --path . --script res://tests/native_construction_cottage_contract.gd
const Cottage = preload("res://scripts/construction/solid_cottage_module.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, message: String) -> void:
    if not value:
        failures += 1
        push_error("COTTAGE FAIL: " + message)

func _run() -> void:
    var scene := Node3D.new()
    root.add_child(scene)
    var cottage := Node3D.new()
    cottage.set_script(Cottage)
    scene.add_child(cottage)
    await process_frame
    await physics_frame
    var expected := ["floor", "back_wall", "side_wall_-1.0", "side_wall_1.0", "front_pier_-1.0", "front_pier_1.0", "door_lintel", "roof_collision", "interior_partition_left"]
    for name in expected:
        var body := cottage.get_node_or_null(name) as StaticBody3D
        _check(body != null, "missing solid: " + name)
        if body != null:
            _check(body.collision_layer == 1, "incorrect layer: " + name)
            _check(body.get_node_or_null("CollisionShape3D") != null, "missing shape: " + name)
    var space := scene.get_world_3d().direct_space_state
    var wall := PhysicsRayQueryParameters3D.create(Vector3(2.5, 1.2, 4), Vector3(2.5, 1.2, 1), 1)
    var door := PhysicsRayQueryParameters3D.create(Vector3(0, 1.2, 4), Vector3(0, 1.2, 1), 1)
    var floor := PhysicsRayQueryParameters3D.create(Vector3(0, 2, 0), Vector3(0, -2, 0), 1)
    _check(not space.intersect_ray(wall).is_empty(), "player ray passes through front wall")
    _check(space.intersect_ray(door).is_empty(), "intended doorway is blocked")
    _check(not space.intersect_ray(floor).is_empty(), "floor missing")
    print("COTTAGE CONTRACT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
    quit(0 if failures == 0 else 1)
