extends SceneTree
## Run: godot --headless --path . --script res://tests/native_construction_collision_test.gd
## Native physics regression for the isolated solid-house repair.
const ValleyScript = preload("res://scripts/valley.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    root.name = "ConstructionPhysicsTest"
    get_root().add_child(root)
    var valley: Node3D = ValleyScript.new()
    root.add_child(valley)
    valley._land()
    valley._house(Vector3.ZERO, Color.WHITE, Color.DARK_RED, 7.0)
    for i in range(3):
        await physics_frame
    var space := root.get_world_3d().direct_space_state
    _expect_hit(space, Vector3(0, 1.3, 4.0), Vector3(0, 1.3, 2.4), false, "open doorway")
    _expect_hit(space, Vector3(2.0, 1.3, 4.0), Vector3(2.0, 1.3, 2.4), true, "front wall")
    _expect_hit(space, Vector3(-5.0, 1.3, 0), Vector3(-3.0, 1.3, 0), true, "side wall")
    _expect_hit(space, Vector3(0, 1.3, -4.0), Vector3(0, 1.3, -2.0), true, "rear wall")
    _expect_hit(space, Vector3(0, 2.8, 4.0), Vector3(0, 2.8, 2.4), true, "door lintel")
    _expect_hit(space, Vector3(0, 2.0, 0), Vector3(0, -1.0, 0), true, "interior floor")
    var bodies := root.find_children("HouseStructure", "StaticBody3D", true, false)
    if bodies.size() != 1:
        failures.append("expected one structural body; got %d" % bodies.size())
    else:
        var body: StaticBody3D = bodies[0]
        if body.collision_layer & 1 == 0:
            failures.append("structural body does not occupy world layer 1")
        if body.get_child_count() < 14:
            failures.append("missing expected paired visual/collision parts")
    root.queue_free()
    if failures.is_empty():
        print("PASS: construction doorway, walls, lintel, floor and structural layer")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        quit(1)

func _expect_hit(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3, expected: bool, label: String) -> void:
    var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
    var result := space.intersect_ray(query)
    if (not result.is_empty()) != expected:
        failures.append("%s: expected hit=%s; actual=%s" % [label, str(expected), str(not result.is_empty())])
