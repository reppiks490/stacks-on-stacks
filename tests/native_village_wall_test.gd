extends SceneTree
## Native Godot regression: scheduled villagers must not tunnel through solid walls.
## Run: godot --headless --path . --script res://tests/native_village_wall_test.gd
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _assert(value: bool, message: String) -> void:
    if not value:
        failures += 1
        push_error("VILLAGE WALL REGRESSION: " + message)

func _run() -> void:
    var host = load("res://tests/village_wall_clock_host.gd").new()
    root.add_child(host)
    var village = load("res://scripts/village.gd").new()
    root.add_child(village)
    village.setup(host)
    _assert(village.residents.size() > 0, "villagers loaded")
    if village.residents.is_empty():
        quit(1)
        return
    var resident: Dictionary = village.residents[0]
    var actor: AnimatableBody3D = resident["node"]
    # Override only this test's destination; do not mutate production catalogs.
    var home: Array = resident["home"]
    var origin := Vector3(float(home[0]), float(home[1]), float(home[2]))
    var barrier := StaticBody3D.new()
    barrier.name = "RegressionWall"
    barrier.collision_layer = 1
    barrier.collision_mask = 1
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(4.0, 3.0, 0.3)
    shape.shape = box
    barrier.add_child(shape)
    barrier.position = origin + Vector3(0, 1.5, -2.0)
    root.add_child(barrier)
    # Force a schedule destination beyond the wall along -Z.
    village.life_data["places"]["village_square"] = [
        origin.x, origin.y, origin.z - 5.0
    ]
    host.minute_of_day = 480
    actor.global_position = origin
    await process_frame
    await physics_frame
    # Village already moves on _physics_process: do not double-step it.
    for step in range(180):
        await physics_frame
    _assert(actor.global_position.z > origin.z - 1.55,
            "NPC crossed a solid wall: %s" % actor.global_position)
    _assert(actor.get_node_or_null("BodyEnvelope") is CollisionShape3D,
            "physical NPC envelope absent")
    print("EVERBLOOM VILLAGE WALL: failures=%d" % failures)
    quit(0 if failures == 0 else 1)
