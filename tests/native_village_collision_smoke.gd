extends SceneTree
# Run: godot --headless --path . --script res://tests/native_village_collision_smoke.gd
# Native physics acceptance fixture; not a substitute for integrated playable-scene evidence.
var actor: CharacterBody3D
var frames := 0
var failures := 0
var start_z := 0.0
var minimum_z := INF
var floor_contacts := 0
var wall_contacts := 0

func _initialize() -> void:
    call_deferred("_begin")

func _solid(name: String, position: Vector3, size: Vector3) -> void:
    var wall := StaticBody3D.new()
    wall.name = name
    wall.collision_layer = 1
    wall.collision_mask = 2
    wall.position = position
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    wall.add_child(shape)
    root.add_child(wall)

func _begin() -> void:
    _solid("Floor", Vector3(0, -0.5, 0), Vector3(20, 1, 20))
    _solid("Wall", Vector3(0, 1.0, -2), Vector3(8, 2, 0.4))
    actor = CharacterBody3D.new()
    actor.name = "NPCPhysicsProbe"
    actor.collision_layer = 2
    actor.collision_mask = 1 | 2
    actor.floor_snap_length = 0.3
    actor.position = Vector3(0, 0.05, 1)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.7
    collision.shape = capsule
    collision.position.y = 0.85
    actor.add_child(collision)
    root.add_child(actor)
    start_z = actor.position.z

func _physics_process(delta: float) -> void:
    if actor == null:
        return
    frames += 1
    actor.velocity = Vector3(0, actor.velocity.y - 24.0 * delta, -2.4)
    actor.move_and_slide()
    minimum_z = minf(minimum_z, actor.global_position.z)
    if actor.is_on_floor():
        floor_contacts += 1
    if actor.is_on_wall():
        wall_contacts += 1
    if actor.global_position.y < -0.2:
        failures += 1
        push_error("NPC fell through the floor at frame %d" % frames)
        quit(1)
        return
    if actor.global_position.z < -1.40:
        failures += 1
        push_error("NPC crossed the wall at frame %d" % frames)
        quit(1)
        return
    if frames >= 120:
        if actor.global_position.z >= start_z - 0.5:
            failures += 1
            push_error("NPC failed to advance toward wall")
        # The probe must actually reach the wall. Otherwise a broken solver
        # could pass by moving only the initial half metre without contact.
        if wall_contacts == 0 or minimum_z > -1.2:
            failures += 1
            push_error("NPC never contacted the blocking wall")
        if floor_contacts < 90:
            failures += 1
            push_error("NPC did not maintain stable floor contact")
        if not actor.is_on_floor():
            failures += 1
            push_error("NPC not grounded at frame 120")
        print("VILLAGE_PHYSICS_120_FRAME ", "PASS" if failures == 0 else "FAIL", " frames=", frames, " final=", actor.global_position, " wall_contacts=", wall_contacts, " floor_contacts=", floor_contacts)
        quit(0 if failures == 0 else 1)
    return
