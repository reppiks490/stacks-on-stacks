extends SceneTree
## Native regression for Village-owned CharacterBody3D resident collision.
## Run: godot --headless --path . --script res://tests/native_village_collision_test.gd
## This checks actual physics bodies, not the final art-quality gate.
var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("VILLAGE COLLISION FAIL: " + description)

func _initialize() -> void:
    call_deferred("run_test")

func run_test() -> void:
    var host = load("res://tests/village_test_host.gd").new()
    root.add_child(host)
    var village = load("res://scripts/village.gd").new()
    root.add_child(village)
    village.setup(host)
    check(village.residents.size() == 6, "canonical residents instantiated")
    if village.residents.is_empty():
        quit(1)
        return
    var actor: Node3D = village.residents[0]["node"]
    check(actor is CharacterBody3D, "resident uses real CharacterBody3D")
    if not (actor is CharacterBody3D):
        quit(1)
        return
    var mover: CharacterBody3D = actor
    check(mover.collision_layer & 2 != 0, "resident collision layer enabled")
    check(mover.collision_mask & 1 != 0, "resident detects static world")
    var shape_count := 0
    for child in mover.get_children():
        if child is CollisionShape3D and child.shape != null:
            shape_count += 1
    check(shape_count > 0, "resident has an enabled physics shape")

    # Test in a distant isolated fixture to avoid existing village props.
    village.set_physics_process(false)
    var floor_body := StaticBody3D.new()
    floor_body.collision_layer = 1
    var floor_shape := CollisionShape3D.new()
    var ground := BoxShape3D.new()
    ground.size = Vector3(24, 1, 24)
    floor_shape.shape = ground
    floor_body.add_child(floor_shape)
    floor_body.position = Vector3(10000, -0.5, 10000)
    root.add_child(floor_body)
    var wall := StaticBody3D.new()
    wall.collision_layer = 1
    var wall_shape := CollisionShape3D.new()
    var block := BoxShape3D.new()
    block.size = Vector3(0.5, 3, 8)
    wall_shape.shape = block
    wall.add_child(wall_shape)
    wall.position = Vector3(10002, 1.5, 10000)
    root.add_child(wall)
    mover.global_position = Vector3(10000, 0.05, 10000)
    mover.velocity = Vector3.ZERO
    await physics_frame
    for frame in range(120):
        mover.velocity = Vector3(4, -2, 0)
        mover.move_and_slide()
        await physics_frame
    check(mover.global_position.x < 10001.45, "120-frame traversal cannot penetrate wall")
    check(mover.global_position.y > -0.1, "120-frame traversal cannot fall through floor")
    check(mover.is_on_floor(), "resident remains grounded")
    print("VILLAGE COLLISION: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
