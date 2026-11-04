extends SceneTree
## Native physics acceptance for the six existing homestead/town houses.
## Run: godot --headless --path . --script res://tests/native_construction_wall_traversal_test.gd
var failures := 0
var checks := 0

func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("CONSTRUCTION PHYSICS FAILED: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _ray(space: PhysicsDirectSpaceState3D, origin: Vector3, target: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(origin, target)
    query.collision_mask = 1
    return space.intersect_ray(query)

func _run() -> void:
    var valley := load("res://scripts/valley.gd").new()
    root.add_child(valley)
    # setup() only calls host-independent scene builders; host is unused here.
    valley.setup(null)
    await physics_frame
    await physics_frame
    var space := root.world_3d.direct_space_state
    var houses := [
        Vector3(-23, 0, -14), Vector3(-4, 0, -15),
        Vector3(22, 0, 10), Vector3(34, 0, 12),
        Vector3(44, 0, 5), Vector3(35, 0, -7)
    ]
    for i in range(houses.size()):
        var p: Vector3 = houses[i]
        # Front wall at local +Z, opening at center. Rays travel horizontally.
        var wall := _ray(space, p + Vector3(2.0, 1.2, 4.0), p + Vector3(2.0, 1.2, 1.0))
        _check(not wall.is_empty(), "house %d front wall blocks entry" % i)
        var doorway := _ray(space, p + Vector3(0, 1.2, 4.0), p + Vector3(0, 1.2, 1.0))
        _check(doorway.is_empty(), "house %d center doorway is clear" % i)
        var back := _ray(space, p + Vector3(0, 1.2, 0), p + Vector3(0, 1.2, -4.0))
        _check(not back.is_empty(), "house %d rear wall blocks traversal" % i)
        var floor_hit := _ray(space, p + Vector3(0, 1.0, 0), p + Vector3(0, -2.0, 0))
        _check(not floor_hit.is_empty(), "house %d interior has solid floor" % i)
    print("CONSTRUCTION PHYSICS: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
