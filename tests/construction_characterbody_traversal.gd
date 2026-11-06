extends SceneTree
# Native physics regression for the actual production valley house builder.
# Run: godot --headless --path . --script res://tests/construction_characterbody_traversal.gd
# This is a physics acceptance test, not visual-art acceptance.
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if condition:
        print("PASS ", label)
    else:
        failures += 1
        push_error("FAIL " + label)

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var valley := Node3D.new()
    valley.set_script(load("res://scripts/valley.gd"))
    world.add_child(valley)
    valley._house(Vector3.ZERO, Color.WHITE, Color.DARK_RED, 6.0)
    var house := valley.get_node("SolidHouse")
    _check(house != null, "production house instantiated")
    var actor := CharacterBody3D.new()
    actor.collision_layer = 2
    actor.collision_mask = 1
    var capsule := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.32
    shape.height = 1.8
    capsule.shape = shape
    actor.add_child(capsule)
    world.add_child(actor)
    await physics_frame
    await physics_frame

    # A horizontal sweep through a solid side wall must be obstructed.
    actor.global_position = Vector3(-4.2, 1.0, 0)
    await physics_frame
    var wall_hit := actor.move_and_collide(Vector3(3.2, 0, 0), true)
    _check(wall_hit != null, "CharacterBody3D cannot traverse exterior wall")

    # Doorway is centered on the +Z facade and must admit the same capsule.
    actor.global_position = Vector3(0, 1.0, 4.0)
    await physics_frame
    var door_hit := actor.move_and_collide(Vector3(0, 0, -3.0), true)
    _check(door_hit == null, "CharacterBody3D can enter unobstructed doorway")

    # A descending sweep inside the cottage must encounter its structural floor.
    actor.global_position = Vector3(0, 2.2, 0)
    await physics_frame
    var floor_hit := actor.move_and_collide(Vector3(0, -4.0, 0), true)
    _check(floor_hit != null, "CharacterBody3D cannot fall through house floor")
    if floor_hit != null:
        _check(floor_hit.get_normal().y > 0.8, "floor contact has upward normal")

    # The roof must also block entry from above.
    actor.global_position = Vector3(0, 6.5, 0)
    await physics_frame
    var roof_hit := actor.move_and_collide(Vector3(0, -5.0, 0), true)
    _check(roof_hit != null, "CharacterBody3D cannot fall through roof")
    if roof_hit != null:
        _check(roof_hit.get_normal().y > 0.8, "roof contact has upward normal")

    # A doorway clearance is not sufficient if the player is blocked by a
    # decorative invisible collision after entering the interior.
    actor.global_position = Vector3(0, 1.0, 3.0)
    await physics_frame
    var interior_hit := actor.move_and_collide(Vector3(0, 0, -4.0), true)
    _check(interior_hit == null, "CharacterBody3D can continue into cottage interior")

    print("CONSTRUCTION_CHARACTERBODY_TRAVERSAL failures=", failures)
    quit(0 if failures == 0 else 1)
