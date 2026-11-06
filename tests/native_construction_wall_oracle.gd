extends SceneTree
## Native physics regression for the actual scripts/valley.gd house assembly.
## Run: godot --headless --path . --script res://tests/native_construction_wall_oracle.gd
## Must fail if walls/floor lose collision or doorway becomes impassable.
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var valley_script: Script = load("res://scripts/valley.gd")
    if valley_script == null:
        push_error("Cannot load valley.gd")
        quit(1)
        return
    var valley: Node3D = valley_script.new()
    root.add_child(valley)
    valley._house(Vector3.ZERO, Color.WHITE, Color.DARK_RED, 7.0)
    await physics_frame
    await physics_frame
    var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
    _expect_hit(space, Vector3(0, 1.2, -4.0), Vector3(0, 1.2, -1.0), "rear wall")
    _expect_hit(space, Vector3(4.5, 1.2, 0), Vector3(2.0, 1.2, 0), "right wall")
    _expect_hit(space, Vector3(-4.5, 1.2, 0), Vector3(-2.0, 1.2, 0), "left wall")
    _expect_hit(space, Vector3(2.7, 1.2, 4.0), Vector3(2.7, 1.2, 1.0), "front wall")
    _expect_clear(space, Vector3(0, 1.2, 4.0), Vector3(0, 1.2, 1.0), "open doorway")
    _expect_hit(space, Vector3(0, 1.0, 0), Vector3(0, -1.0, 0), "floor")
    _expect_hit(space, Vector3(0, 5.5, 0), Vector3(0, 3.5, 0), "roof")
    if failures.is_empty():
        print("PASS: 7 native construction raycast checks")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(from, to, 1)
    query.collide_with_bodies = true
    query.collide_with_areas = false
    return space.intersect_ray(query)

func _expect_hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, label: String) -> void:
    if _ray(space, from, to).is_empty():
        failures.append("Missing structural collision: " + label)

func _expect_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, label: String) -> void:
    if not _ray(space, from, to).is_empty():
        failures.append("Unexpected collision obstructs " + label)
