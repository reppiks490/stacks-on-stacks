extends SceneTree
# Run: godot --headless --path . --script res://tests/native_construction_house_collision_20261105.gd
# Tests actual valley setup, not a separate geometry fixture.
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _assert_case(ok: bool, label: String) -> void:
    if ok:
        print("PASS construction: ", label)
    else:
        failures += 1
        push_error("FAIL construction: " + label)

func _ray(from: Vector3, to: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1
    return root.get_world_3d().direct_space_state.intersect_ray(query)

func _run() -> void:
    var world := Node3D.new()
    world.name = "ConstructionNativeWorld"
    root.add_child(world)
    var valley := Node3D.new()
    valley.set_script(load("res://scripts/valley.gd"))
    world.add_child(valley)
    valley.setup(null)
    await physics_frame
    await physics_frame
    await physics_frame
    # House at (-23,0,-14), width 7, front wall z=-11.4.
    _assert_case(not _ray(Vector3(-23, 1.0, -17.9), Vector3(-23, 1.0, -16.0)).is_empty(), "rear wall blocks entry")
    _assert_case(not _ray(Vector3(-27.0, 1.0, -14), Vector3(-25.0, 1.0, -14)).is_empty(), "side wall blocks entry")
    _assert_case(_ray(Vector3(-23, 1.0, -10.7), Vector3(-23, 1.0, -12.0)).is_empty(), "front doorway clear")
    _assert_case(not _ray(Vector3(-23, 1.0, -10.7), Vector3(-23, 1.0, -12.0)).has("position"), "door opening not solid")
    _assert_case(not _ray(Vector3(-23, 3.3, -10.7), Vector3(-23, 3.3, -12.0)).is_empty(), "door lintel blocks passage above clearance")
    _assert_case(not _ray(Vector3(-23, 2.0, -14), Vector3(-23, -2.0, -14)).is_empty(), "interior ground supports player")
    print("Construction native assertions failed: ", failures)
    quit(1 if failures > 0 else 0)
