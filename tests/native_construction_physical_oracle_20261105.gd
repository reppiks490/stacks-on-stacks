extends SceneTree
# Run: godot --headless --path . --script res://tests/native_construction_physical_oracle_20261105.gd
# Exercises real house construction on the isolated solid-buildings candidate.
var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, description: String) -> void:
    assertions += 1
    if not condition:
        failures.append(description)
        push_error("FAIL: " + description)

func _cast(world: World3D, from: Vector3, to: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(from, to, 1)
    query.collide_with_bodies = true
    query.collide_with_areas = false
    return world.direct_space_state.intersect_ray(query)

func _run() -> void:
    var valley := Node3D.new()
    valley.set_script(load("res://scripts/valley.gd"))
    root.add_child(valley)
    valley.call("_house", Vector3.ZERO, Color.WHITE, Color.DARK_RED, 7.0)
    await physics_frame
    await physics_frame
    var world := valley.get_world_3d()
    var bodies := 0
    for child in valley.get_children():
        if child.name == "SolidHouse":
            for piece in child.get_children():
                if piece is StaticBody3D:
                    bodies += 1
                    _check(piece.collision_layer & 1 != 0, "structure missing player collision layer")
                    _check(piece.get_child_count() > 0 and piece.get_child(0) is CollisionShape3D, "structure missing collision shape")
    _check(bodies >= 8, "solid building not constructed")
    _check(not _cast(world, Vector3(0, 1.2, -4), Vector3(0, 1.2, -1)).is_empty(), "back wall penetrable")
    _check(not _cast(world, Vector3(4.5, 1.2, 0), Vector3(2.0, 1.2, 0)).is_empty(), "right wall penetrable")
    _check(not _cast(world, Vector3(-4.5, 1.2, 0), Vector3(-2.0, 1.2, 0)).is_empty(), "left wall penetrable")
    _check(not _cast(world, Vector3(2.3, 1.2, 4), Vector3(2.3, 1.2, 1)).is_empty(), "front wall penetrable")
    _check(_cast(world, Vector3(0, 1.2, 4), Vector3(0, 1.2, 1)).is_empty(), "doorway incorrectly blocked")
    _check(not _cast(world, Vector3(0, 3.3, 4), Vector3(0, 3.3, 1)).is_empty(), "door lintel missing")
    _check(not _cast(world, Vector3(0, 2, 0), Vector3(0, -2, 0)).is_empty(), "interior floor missing")
    _check(not _cast(world, Vector3(0, 6, 0), Vector3(0, 3, 0)).is_empty(), "roof collision missing")
    print("CONSTRUCTION PHYSICAL ORACLE assertions=", assertions, " failures=", failures.size())
    valley.queue_free()
    quit(0 if failures.is_empty() else 1)
