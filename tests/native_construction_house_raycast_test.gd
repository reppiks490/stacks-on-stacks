extends SceneTree
## Native regression for the real valley house assembled by scripts/valley.gd.
## Run: godot --headless --path . --script res://tests/native_construction_house_raycast_test.gd
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _expect_hit(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3, label: String) -> void:
    var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
    var hit := space.intersect_ray(query)
    if hit.is_empty():
        failures.append(label + ": expected structural collision")
    elif not (hit["collider"] is StaticBody3D):
        failures.append(label + ": collider is not StaticBody3D")

func _expect_clear(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3, label: String) -> void:
    var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
    var hit := space.intersect_ray(query)
    if not hit.is_empty():
        failures.append(label + ": intended doorway obstructed")

func _run() -> void:
    var valley_script: Script = load("res://scripts/valley.gd")
    if valley_script == null:
        push_error("Cannot load real valley script")
        quit(1)
        return
    var valley: Node3D = valley_script.new()
    root.add_child(valley)
    valley.setup(null)
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    # Existing first farmhouse: center (-23, 0, -14), width 7, depth 5.2.
    _expect_hit(space, Vector3(-23, 1.4, -14), Vector3(-27, 1.4, -14), "west exterior wall")
    _expect_hit(space, Vector3(-23, 1.4, -14), Vector3(-19, 1.4, -14), "east exterior wall")
    _expect_hit(space, Vector3(-23, 1.4, -14), Vector3(-23, 1.4, -18), "rear exterior wall")
    _expect_hit(space, Vector3(-20.5, 1.4, -10), Vector3(-20.5, 1.4, -13), "front solid pier")
    _expect_hit(space, Vector3(-23, 3.2, -10), Vector3(-23, 3.2, -13), "front lintel")
    _expect_clear(space, Vector3(-23, 1.4, -10), Vector3(-23, 1.4, -13), "front entrance")
    _expect_hit(space, Vector3(-23, 2.0, -14), Vector3(-23, -1.0, -14), "interior floor")
    if failures.is_empty():
        print("PASS: 7 real-house physics raycast assertions")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
