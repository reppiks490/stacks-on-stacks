extends SceneTree
## Native physics oracle for the existing house shell. Run:
## godot --headless --path . --script res://tests/native_construction_door_wall_oracle_20261105.gd
## This is a collision regression, NOT an art-quality or hands-on playtest.
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _ray(from: Vector3, to: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1
    return root.get_world_3d().direct_space_state.intersect_ray(query)

func _check(label: String, passed: bool) -> void:
    if not passed:
        failures.append(label)
        push_error("FAIL: " + label)
    else:
        print("PASS: " + label)

func _run() -> void:
    var valley := Node3D.new()
    valley.set_script(load("res://scripts/valley.gd"))
    root.add_child(valley)
    valley._house(Vector3.ZERO, Color.WHITE, Color.DARK_RED, 7.0)
    await physics_frame
    await physics_frame
    # Front facade has a centered 1.5m doorway, with two solid wings.
    _check("front left wall blocks", not _ray(Vector3(-2.0, 1.4, 3.5), Vector3(-2.0, 1.4, 1.8)).is_empty())
    _check("front right wall blocks", not _ray(Vector3(2.0, 1.4, 3.5), Vector3(2.0, 1.4, 1.8)).is_empty())
    _check("center doorway is passable", _ray(Vector3(0.0, 1.4, 3.5), Vector3(0.0, 1.4, 1.8)).is_empty())
    _check("door header blocks", not _ray(Vector3(0.0, 3.2, 3.5), Vector3(0.0, 3.2, 1.8)).is_empty())
    _check("rear wall blocks", not _ray(Vector3(0.0, 1.4, -1.8), Vector3(0.0, 1.4, -3.5)).is_empty())
    _check("side wall blocks", not _ray(Vector3(2.7, 1.4, 0.0), Vector3(4.2, 1.4, 0.0)).is_empty())
    _check("floor supports downward ray", not _ray(Vector3(0.0, 1.5, 0.0), Vector3(0.0, -1.0, 0.0)).is_empty())
    var solids := 0
    for child in valley.get_children():
        if child is StaticBody3D:
            solids += 1
            _check("solid collision layer", child.collision_layer & 1 != 0)
            _check("solid has shape", child.get_child_count() > 0 and child.get_child(0) is CollisionShape3D)
    _check("structural bodies present", solids >= 7)
    valley.queue_free()
    if failures.is_empty():
        print("CONSTRUCTION_NATIVE_ORACLE_PASS")
        quit(0)
    else:
        print("CONSTRUCTION_NATIVE_ORACLE_FAIL: ", failures)
        quit(1)
