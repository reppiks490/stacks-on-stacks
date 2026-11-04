extends SceneTree
## Native headless physics regression for the real launch-scene house builder.
## Run: godot --headless --path . --script res://tests/native_construction_house_raycast_test.gd
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _hit(from: Vector3, to: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(from, to, 1)
    return root.world_3d.direct_space_state.intersect_ray(query)

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func _run() -> void:
    var valley_script: Script = load("res://scripts/valley.gd")
    var valley: Node3D = valley_script.new()
    root.add_child(valley)
    valley._house(Vector3.ZERO, Color.WHITE, Color.BROWN, 7.0)
    await physics_frame
    await physics_frame
    var bodies := valley.find_children("SolidHouse", "StaticBody3D", true, false)
    _expect(bodies.size() == 1, "Expected one physics-backed house")
    if bodies.size() == 1:
        var house: StaticBody3D = bodies[0]
        _expect(house.collision_layer & 1 != 0, "House must collide on player world layer")
        _expect(house.get_child_count() > 0, "House has no structural children")
    _expect(not _hit(Vector3(-5, 1.2, 0), Vector3(0, 1.2, 0)).is_empty(), "Left exterior wall is penetrable")
    _expect(not _hit(Vector3(5, 1.2, 0), Vector3(0, 1.2, 0)).is_empty(), "Right exterior wall is penetrable")
    _expect(not _hit(Vector3(0, 1.2, -4), Vector3(0, 1.2, 0)).is_empty(), "Back exterior wall is penetrable")
    _expect(not _hit(Vector3(2.5, 1.2, 4), Vector3(2.5, 1.2, 1)).is_empty(), "Front wall pier is penetrable")
    _expect(_hit(Vector3(0, 1.2, 4), Vector3(0, 1.2, 1)).is_empty(), "Intentional doorway is obstructed")
    _expect(not _hit(Vector3(0, 1, 0), Vector3(0, -1, 0)).is_empty(), "Floor has no physical support")
    _expect(not _hit(Vector3(0, 5, 0), Vector3(0, 3, 0)).is_empty(), "Ceiling is penetrable")
    if failures.is_empty():
        print("PASS: 7 structural raycast checks and house collision contract")
        quit(0)
    else:
        print("FAIL: ", failures.size(), " construction physics checks")
        quit(1)
