extends SceneTree
# Native physics oracle for the existing solid-house candidate.
# Run: godot --headless --path . --script res://tests/native_construction_wall_gate_20261106.gd
const Valley = preload("res://scripts/valley.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(label: String, expected_hit: bool, from: Vector3, to: Vector3, space: PhysicsDirectSpaceState3D) -> void:
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1
    var hit := space.intersect_ray(query)
    var found := not hit.is_empty()
    if found != expected_hit:
        failures += 1
        push_error("FAIL %s: expected_hit=%s actual_hit=%s" % [label, expected_hit, found])
    else:
        print("PASS ", label)

func _run() -> void:
    var root := Node3D.new()
    current_scene = root
    root.name = "ConstructionPhysicsGate"
    root.add_child(Valley.new())
    var valley := root.get_child(0)
    valley.setup(null)
    for i in range(3):
        await physics_frame
    var space := root.get_world_3d().direct_space_state
    # First farmhouse center (-23,0,-14), width 7, depth 5.2.
    # Rays at y=1.3 cannot hit the roof and must not mistake the floor for a wall.
    _check("rear wall", true, Vector3(-23,1.3,-18), Vector3(-23,1.3,-15), space)
    _check("left wall", true, Vector3(-28,1.3,-14), Vector3(-25,1.3,-14), space)
    _check("right wall", true, Vector3(-18,1.3,-14), Vector3(-21,1.3,-14), space)
    _check("front wall flank", true, Vector3(-25,1.3,-10), Vector3(-25,1.3,-13), space)
    _check("open doorway", false, Vector3(-23,1.3,-10), Vector3(-23,1.3,-13), space)
    _check("house floor", true, Vector3(-23,2,-14), Vector3(-23,-2,-14), space)
    _check("ground", true, Vector3(0,2,0), Vector3(0,-2,0), space)
    print("CONSTRUCTION_WALL_GATE failures=", failures)
    quit(1 if failures > 0 else 0)
