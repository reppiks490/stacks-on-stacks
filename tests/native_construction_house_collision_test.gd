extends SceneTree
# Native Godot regression for existing homestead cottages.
# Run: godot --headless --path . --script res://tests/native_construction_house_collision_test.gd
const Valley = preload("res://scripts/valley.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _assert_hit(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, expected: bool, label: String) -> void:
    var query := PhysicsRayQueryParameters3D.create(a, b)
    query.collision_mask = 1
    var hit := space.intersect_ray(query)
    var actual := not hit.is_empty()
    if actual != expected:
        failures += 1
        push_error("%s: expected hit=%s got=%s" % [label, expected, actual])

func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var valley := Valley.new()
    root.add_child(valley)
    # setup() requires game only for interactions, not geometry.
    valley.setup(null)
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    # Farmhouse center (-23,0,-14), width 7, depth 5.2.
    _assert_hit(space, Vector3(-23, 1.4, -19), Vector3(-23, 1.4, -15), true, "rear exterior wall")
    _assert_hit(space, Vector3(-28, 1.4, -14), Vector3(-25, 1.4, -14), true, "left exterior wall")
    _assert_hit(space, Vector3(-23, 1.4, -9), Vector3(-23, 1.4, -13), false, "front doorway clear")
    _assert_hit(space, Vector3(-23, 4.0, -14), Vector3(-23, -2.0, -14), true, "interior floor")
    print("CONSTRUCTION_HOUSE_COLLISION ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
    quit(0 if failures == 0 else 1)
