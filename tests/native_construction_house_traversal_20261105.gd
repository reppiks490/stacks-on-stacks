extends SceneTree
# Construction collision acceptance: existing valley._house() real production geometry.
# Run: godot --headless --path . --script res://tests/native_construction_house_traversal_20261105.gd
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _probe(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, expected: bool, label: String) -> void:
    var query := PhysicsRayQueryParameters3D.create(a, b, 1)
    query.collide_with_bodies = true
    query.collide_with_areas = false
    var hit := space.intersect_ray(query)
    if (not hit.is_empty()) != expected:
        failures += 1
        push_error("FAIL " + label + " hit=" + str(not hit.is_empty()))
    else:
        print("PASS ", label)

func _run() -> void:
    var valley_script := load("res://scripts/valley.gd")
    if valley_script == null:
        push_error("FAIL missing production valley script")
        quit(1)
        return
    var valley := Node3D.new()
    valley.set_script(valley_script)
    root.add_child(valley)
    valley._house(Vector3.ZERO, Color.WHITE, Color.BROWN, 7.0)
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    # Wall must be solid at human height, doorway clear at human height.
    _probe(space, Vector3(-2.4, 1.4, 4), Vector3(-2.4, 1.4, 1), true, "front left wall")
    _probe(space, Vector3(2.4, 1.4, 4), Vector3(2.4, 1.4, 1), true, "front right wall")
    _probe(space, Vector3(0, 1.4, 4), Vector3(0, 1.4, 1), false, "open doorway")
    _probe(space, Vector3(0, 3.4, 4), Vector3(0, 3.4, 1), true, "door lintel")
    _probe(space, Vector3(-5, 1.4, 0), Vector3(-2, 1.4, 0), true, "left side wall")
    _probe(space, Vector3(5, 1.4, 0), Vector3(2, 1.4, 0), true, "right side wall")
    _probe(space, Vector3(0, 1.4, -4), Vector3(0, 1.4, -1), true, "rear wall")
    _probe(space, Vector3(0, 2, 0), Vector3(0, -2, 0), true, "floor grounding")
    _probe(space, Vector3(0, 6, 0), Vector3(0, 3.8, 0), true, "roof collision")
    print("CONSTRUCTION_HOUSE_TRAVERSAL failures=", failures)
    quit(1 if failures > 0 else 0)
