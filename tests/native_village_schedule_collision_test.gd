extends SceneTree
## Run: godot --headless --path . --script res://tests/native_village_schedule_collision_test.gd
## Regression for schedule teleport into walls and unsupported streamed chunks.
const Village = preload("res://scripts/village.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert_case(label: String, actual: bool, expected: bool) -> void:
    if actual != expected:
        failures.append("%s: expected %s got %s" % [label, expected, actual])

func _solid(parent: Node3D, name: String, at: Vector3, size: Vector3) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = name
    body.position = at
    body.collision_layer = 1
    body.collision_mask = 1
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    parent.add_child(body)
    return body

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var village := Village.new()
    world.add_child(village)
    _solid(world, "LoadedGround", Vector3(0, -0.5, 0), Vector3(12, 1, 12))
    var actor := CharacterBody3D.new()
    actor.collision_layer = 1
    actor.collision_mask = 1
    actor.position = Vector3(0, 0, 0)
    var collision := CollisionShape3D.new()
    collision.name = "ResidentBodyShape"
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.7
    collision.shape = capsule
    collision.position.y = 0.9
    actor.add_child(collision)
    village.add_child(actor)
    await physics_frame
    await physics_frame
    _assert_case("loaded flat floor accepted", village._safe_schedule_destination(actor, Vector3(2, 0, 0)), true)
    _assert_case("unloaded floor rejected", village._safe_schedule_destination(actor, Vector3(30, 0, 0)), false)
    _solid(world, "SolidBuilding", Vector3(4, 1, 0), Vector3(2, 2, 2))
    await physics_frame
    await physics_frame
    _assert_case("building volume rejected", village._safe_schedule_destination(actor, Vector3(4, 0, 0)), false)
    _assert_case("floor elevation mismatch rejected", village._safe_schedule_destination(actor, Vector3(2, 1.5, 0)), false)
    _assert_case("near-wall capsule overlap rejected", village._safe_schedule_destination(actor, Vector3(2.7, 0, 0)), false)
    _solid(world, "LowCeiling", Vector3(-2, 1.55, 0), Vector3(1.5, 0.3, 1.5))
    await physics_frame
    await physics_frame
    _assert_case("low ceiling rejected", village._safe_schedule_destination(actor, Vector3(-2, 0, 0)), false)
    var floor_body: StaticBody3D = world.get_node("LoadedGround")
    floor_body.queue_free()
    await physics_frame
    await physics_frame
    _assert_case("unloaded former floor rejected", village._safe_schedule_destination(actor, Vector3(2, 0, 0)), false)
    if failures.is_empty():
        print("PASS village schedule physics: 7 assertions")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
