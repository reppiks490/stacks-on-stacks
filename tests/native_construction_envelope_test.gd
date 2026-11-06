extends SceneTree
## Native structural coverage for the existing ordinary valley house.
## Run: godot --headless --path . --script res://tests/native_construction_envelope_test.gd
## Uses actual PhysicsDirectSpaceState3D rays, not mesh presence assertions.
const ValleyScript = preload("res://scripts/valley.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    get_root().add_child(world)
    var valley: Node3D = ValleyScript.new()
    world.add_child(valley)
    valley._land()
    valley._house(Vector3.ZERO, Color.WHITE, Color.DARK_RED, 7.0)
    await physics_frame
    await physics_frame
    var house := _house_body(valley)
    if house == null:
        failures.append("HouseStructure body missing")
    else:
        _check_envelope(world, house, "unrotated")
        house.rotation.y = PI / 3.0
        await physics_frame
        _check_envelope(world, house, "rotated")
    world.queue_free()
    if failures.is_empty():
        print("PASS: front/side/rear walls, doorway clearance, floor and overhead slab in both orientations")
        quit(0)
    for failure in failures:
        push_error("FAIL: " + failure)
    quit(1)

func _house_body(valley: Node3D) -> StaticBody3D:
    for child in valley.get_children():
        if child is StaticBody3D and child.name == "HouseStructure":
            return child
    return null

func _check_envelope(world: Node3D, house: StaticBody3D, label: String) -> void:
    # Ray origins and destinations are in house-local coordinates so that the
    # rotated case checks actual collision transforms rather than fixed axes.
    _expect_hit(world, house, Vector3(2.1, 1.3, 4.0), Vector3(2.1, 1.3, 1.6), label + " front wall")
    _expect_hit(world, house, Vector3(-4.5, 1.3, 0), Vector3(-2.6, 1.3, 0), label + " left wall")
    _expect_hit(world, house, Vector3(4.5, 1.3, 0), Vector3(2.6, 1.3, 0), label + " right wall")
    _expect_hit(world, house, Vector3(0, 1.3, -4.0), Vector3(0, 1.3, -1.6), label + " rear wall")
    _expect_clear(world, house, Vector3(0, 1.3, 4.0), Vector3(0, 1.3, 1.6), label + " doorway")
    _expect_hit(world, house, Vector3(0, 1.0, 0), Vector3(0, -0.6, 0), label + " floor")
    _expect_hit(world, house, Vector3(0, 3.5, 0), Vector3(0, 4.6, 0), label + " overhead slab")

func _ray(world: Node3D, house: StaticBody3D, start: Vector3, end: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(
        house.to_global(start), house.to_global(end), 1
    )
    return world.get_world_3d().direct_space_state.intersect_ray(query)

func _expect_hit(world: Node3D, house: StaticBody3D, start: Vector3, end: Vector3, label: String) -> void:
    var hit := _ray(world, house, start, end)
    if hit.is_empty() or hit.get("collider") != house:
        failures.append(label + ": missing house collision")

func _expect_clear(world: Node3D, house: StaticBody3D, start: Vector3, end: Vector3, label: String) -> void:
    var hit := _ray(world, house, start, end)
    if not hit.is_empty() and hit.get("collider") == house:
        failures.append(label + ": entrance obstructed")
